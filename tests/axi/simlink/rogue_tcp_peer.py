##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
#
# Rogue-TCP peer: a separate-process pyzmq client mirroring the stream
# 4-frame and memory 4/5-frame-request / 6-frame-response wire protocols
# implemented by the ported C model (axi/simlink/ghdl/RogueTcpStream.c and
# axi/simlink/ghdl/RogueTcpMemory.c). Always run this module as its own OS
# process (spawned via subprocess.Popen from a cocotb test) -- never call a
# blocking pyzmq method from inside a cocotb coroutine, which shares the
# GHDL/cocotb thread and would deadlock.
#
# This module doubles as a Rogue wire-protocol compatibility oracle:
# the codecs below are written against the ported C's actual framing, and
# any point where that framing disagrees with real rogue's TcpClient.cpp is
# documented explicitly in comments rather than silently reconciled.

import argparse
import json
import sys

import zmq

RCVTIMEO_MS = 30000


def _signal_ready(ready_file):
    if ready_file is not None:
        with open(ready_file, "w") as f:
            f.write("ready\n")


# ---------------------------------------------------------------------------
# Stream protocol (RogueTcpStream.c RogueTcpStreamSend/Recv): 4-frame
# message -- [flags (2B LE u16), chan (1B), err (1B), data (variable)].
# ---------------------------------------------------------------------------


def encode_stream_frame(flags, chan, err, data):
    return [
        int(flags).to_bytes(2, byteorder="little"),
        bytes([chan]),
        bytes([err]),
        bytes(data),
    ]


def decode_stream_frames(parts):
    if len(parts) != 4:
        raise ValueError(f"expected 4 stream frames, got {len(parts)}")
    if len(parts[0]) != 2 or len(parts[1]) != 1 or len(parts[2]) != 1:
        raise ValueError(f"bad stream frame sizes: {[len(p) for p in parts]}")
    return {
        "flags": int.from_bytes(parts[0], byteorder="little"),
        "chan": parts[1][0],
        "err": parts[2][0],
        "data_hex": parts[3].hex(),
    }


# Deterministic fixed vectors (no RNG). Well-formed stimulus only
# (contiguous data, proper-length frames) so the green baseline stays
# clear of the sparse-tKeep miscount and the 0-length/short-read memcpy.
STREAM_SEND_FRAMES = [
    {"flags": 0x0000, "chan": 0x00, "err": 0x00, "data": bytes(range(16))},
    {"flags": 0x0000, "chan": 0x00, "err": 0x00, "data": bytes([0xAA] * 8)},
]

# Frames the peer expects the DUT (driven by stream_round_trip_test's
# AxiStreamSource stimulus) to echo back. Module-level so that test imports
# this list as the single source of truth for what it must drive.
STREAM_EXPECT_FRAMES = [
    {"flags": 0x0000, "chan": 0x00, "err": 0x00, "data": bytes(range(16))},
    {"flags": 0x0000, "chan": 0x00, "err": 0x00, "data": bytes([0xAA] * 8)},
]


def stream_instance_vectors(tag):
    return (
        [{
            "flags": 0,
            "chan": 0,
            "err": 0,
            "data": bytes([0x10 + tag, 0x20 + tag, 0x30 + tag, 0x40 + tag]),
        }],
        [{
            "flags": 0,
            "chan": 0,
            "err": 0,
            "data": bytes([0x80 + tag, 0x90 + tag, 0xA0 + tag, 0xB0 + tag]),
        }],
    )


def run_stream_peer(
    port,
    result_path,
    send_frames=None,
    expect_frames=None,
    ready_file=None,
):
    if send_frames is None:
        send_frames = STREAM_SEND_FRAMES
    if expect_frames is None:
        expect_frames = STREAM_EXPECT_FRAMES

    ctx = zmq.Context()
    push = ctx.socket(zmq.PUSH)
    pull = ctx.socket(zmq.PULL)
    # RCVTIMEO bounds every recv so a stuck peer never hangs CI.
    pull.setsockopt(zmq.RCVTIMEO, RCVTIMEO_MS)

    # RogueTcpStreamRestart binds PULL on `port`, PUSH on `port+1`; the peer
    # connects the mirror way round, as a CLIENT. Never send a
    # TcpBridgeProbe or any other readiness handshake -- the ported C's FSM
    # has no case for it and would hang. Rely on ZMQ's async connect plus
    # RCVTIMEO instead.
    push.connect(f"tcp://127.0.0.1:{port}")
    pull.connect(f"tcp://127.0.0.1:{port + 1}")
    _signal_ready(ready_file)

    sent = []
    received = []
    result = 0
    reason = ""

    try:
        for frame in send_frames:
            parts = encode_stream_frame(
                frame["flags"], frame["chan"], frame["err"], frame["data"]
            )
            push.send_multipart(parts)
            sent.append(
                {
                    "flags": frame["flags"],
                    "chan": frame["chan"],
                    "err": frame["err"],
                    "data_hex": frame["data"].hex(),
                }
            )

        for expected in expect_frames:
            try:
                parts = pull.recv_multipart()
            except zmq.error.Again:
                result = 1
                reason = "peer: TIMED OUT waiting for stream frame"
                break

            try:
                decoded = decode_stream_frames(parts)
            except ValueError as exc:
                result = 1
                reason = f"peer: {exc}"
                break

            received.append(decoded)
            if decoded["data_hex"] != expected["data"].hex():
                result = 1
                reason = f"peer: unexpected stream data, got {decoded!r}"
                break
    finally:
        # Unconditional result file -- written even on early timeout/
        # partial completion, so the cocotb coroutine always has readable
        # per-transaction diagnostics.
        with open(result_path, "w") as f:
            json.dump({"sent": sent, "received": received}, f, indent=2)

    if result == 0:
        print("peer: STREAM ROUND TRIP OK")
    else:
        print(reason)
    return result


def run_stream_recv_peer(port, result_path, ready_file=None):
    # Receive-only mode: no PUSH socket -- this peer never sends anything
    # into the DUT, it only observes what the DUT forwards out. Reuses
    # decode_stream_frames unchanged (no wire-format change), so a
    # sparse-tKeep stimulus is decoded exactly as the real stream protocol
    # frames it.
    ctx = zmq.Context()
    pull = ctx.socket(zmq.PULL)
    pull.setsockopt(zmq.RCVTIMEO, RCVTIMEO_MS)
    pull.connect(f"tcp://127.0.0.1:{port + 1}")
    _signal_ready(ready_file)

    received = []
    result = 0
    reason = ""

    try:
        try:
            parts = pull.recv_multipart()
        except zmq.error.Again:
            result = 1
            reason = "peer: TIMED OUT waiting for stream frame"
        else:
            try:
                received.append(decode_stream_frames(parts))
            except ValueError as exc:
                result = 1
                reason = f"peer: {exc}"
    finally:
        # Unconditional result file -- written even on timeout/decode
        # error, so the cocotb coroutine always has readable diagnostics.
        with open(result_path, "w") as f:
            json.dump({"received": received}, f, indent=2)

    if result == 0:
        print("peer: STREAM RECV OK")
    else:
        print(reason)
    return result


# ---------------------------------------------------------------------------
# Memory protocol (RogueTcpMemory.c RogueTcpMemoryRecv/Send): a request is
# 4 frames -- [id (4B LE), addr (8B LE), size (4B LE), type (4B LE)] -- with
# a 5th write-data frame appended for T_WRITE/T_POST; a response is always
# 6 frames -- [id, addr, size, type, data, result (4B)].
# ---------------------------------------------------------------------------

T_READ = 0x1
T_WRITE = 0x2
T_POST = 0x3

MEM_ID_FRAME = 0
MEM_ADDR_FRAME = 1
MEM_SIZE_FRAME = 2
MEM_TYPE_FRAME = 3
MEM_DATA_FRAME = 4
MEM_RESULT_FRAME = 5

MEM_READ_REQ_FRAMES = 4
MEM_WRITE_REQ_FRAMES = 5
MEM_RESP_FRAMES = 6
MEM_U32_BYTES = 4
MEM_ADDR_BYTES = 8
MEM_RESPONSE_HEADER_SIZES = (
    MEM_U32_BYTES,
    MEM_ADDR_BYTES,
    MEM_U32_BYTES,
    MEM_U32_BYTES,
    MEM_U32_BYTES,
)


def encode_mem_request(txn_id, addr, size, txn_type, write_data=b""):
    parts = [
        int(txn_id).to_bytes(MEM_U32_BYTES, byteorder="little"),
        int(addr).to_bytes(MEM_ADDR_BYTES, byteorder="little"),
        int(size).to_bytes(MEM_U32_BYTES, byteorder="little"),
        int(txn_type).to_bytes(MEM_U32_BYTES, byteorder="little"),
    ]
    if txn_type in (T_WRITE, T_POST):
        parts.append(bytes(write_data))
    return parts


def decode_mem_response(parts):
    if len(parts) != MEM_RESP_FRAMES:
        raise ValueError(
            f"expected {MEM_RESP_FRAMES} memory response frames, got {len(parts)}"
        )
    sizes = [
        len(parts[MEM_ID_FRAME]),
        len(parts[MEM_ADDR_FRAME]),
        len(parts[MEM_SIZE_FRAME]),
        len(parts[MEM_TYPE_FRAME]),
        len(parts[MEM_RESULT_FRAME]),
    ]
    if tuple(sizes) != MEM_RESPONSE_HEADER_SIZES:
        raise ValueError(f"bad memory response frame sizes: {sizes}")

    # NOTE -- intentional, documented divergence from real rogue:
    # the ported C (RogueTcpMemorySend) writes frame[MEM_RESULT_FRAME] as a raw
    # little-endian uint32 AXI resp code (0 == OKAY), copied straight from
    # the AXI-Lite BRESP/RRESP signal. Real rogue's TcpClient.cpp instead
    # treats the result frame as an ASCII status text field, textually compared
    # against a success literal -- against this ported-C model, that
    # textual comparison would fail on every transaction. This oracle
    # intentionally decodes the numeric form the ported C actually emits
    # rather than a rogue-faithful text comparison, and flags the
    # string-vs-binary mismatch as a scoping candidate instead of silently
    # accommodating it.
    result = int.from_bytes(parts[MEM_RESULT_FRAME], byteorder="little")

    return {
        "id": int.from_bytes(parts[MEM_ID_FRAME], byteorder="little"),
        "addr": int.from_bytes(parts[MEM_ADDR_FRAME], byteorder="little"),
        "size": int.from_bytes(parts[MEM_SIZE_FRAME], byteorder="little"),
        "type": int.from_bytes(parts[MEM_TYPE_FRAME], byteorder="little"),
        "data_hex": parts[MEM_DATA_FRAME].hex(),
        "result": result,
    }


# Deterministic write-then-read transactions (no RNG), word-sized
# (size=4) and 32-bit-aligned (well-formed only, never 0-length/short, so
# the uninitialized-read memcpy is not tripped). wstrb is fixed 0xF by the C
# FSM, so no strobe variation is needed.
MEM_TRANSACTIONS = [
    {"addr": 0x00000000, "size": 4, "write_data": bytes([0x01, 0x02, 0x03, 0x04])},
    {"addr": 0x00000010, "size": 4, "write_data": bytes([0xDE, 0xAD, 0xBE, 0xEF])},
]


def memory_instance_transactions(tag):
    return [{
        "addr": 0x00000100 + (tag * 0x10),
        "size": 4,
        "write_data": bytes([0x40 + tag, 0x50 + tag, 0x60 + tag, 0x70 + tag]),
    }]


def run_memory_peer(port, result_path, memory_transactions=None, ready_file=None):
    if memory_transactions is None:
        memory_transactions = MEM_TRANSACTIONS

    ctx = zmq.Context()
    push = ctx.socket(zmq.PUSH)
    pull = ctx.socket(zmq.PULL)
    # RCVTIMEO bounds every recv so a stuck peer never hangs CI.
    pull.setsockopt(zmq.RCVTIMEO, RCVTIMEO_MS)

    # RogueTcpMemoryRestart binds PULL on `port`, PUSH on `port+1`; the peer
    # connects the mirror way round, as a CLIENT. Never send a readiness
    # probe/handshake.
    push.connect(f"tcp://127.0.0.1:{port}")
    pull.connect(f"tcp://127.0.0.1:{port + 1}")
    _signal_ready(ready_file)

    transactions = []
    result = 0
    reason = ""
    txn_id = 0

    try:
        for txn in memory_transactions:
            # Write, then read back the same address/size and compare.
            for txn_type, write_data in (
                (T_WRITE, txn["write_data"]),
                (T_READ, b""),
            ):
                txn_id += 1
                request = encode_mem_request(
                    txn_id, txn["addr"], txn["size"], txn_type, write_data
                )
                push.send_multipart(request)

                try:
                    parts = pull.recv_multipart()
                except zmq.error.Again:
                    result = 1
                    reason = "peer: TIMED OUT waiting for memory response"
                    break

                try:
                    decoded = decode_mem_response(parts)
                except ValueError as exc:
                    result = 1
                    reason = f"peer: {exc}"
                    break

                transactions.append(
                    {
                        "type": txn_type,
                        "addr": txn["addr"],
                        "size": txn["size"],
                        "data_hex": decoded["data_hex"],
                        "resp": decoded["result"],
                    }
                )

                if decoded["result"] != 0:
                    result = 1
                    reason = f"peer: non-OKAY resp {decoded['result']} on txn {txn_id}"
                    break

                if txn_type == T_READ and decoded["data_hex"] != txn["write_data"].hex():
                    result = 1
                    reason = f"peer: read-back mismatch on txn {txn_id}, got {decoded!r}"
                    break

            if result != 0:
                break
    finally:
        # Unconditional result file -- written even on early timeout/
        # partial completion.
        with open(result_path, "w") as f:
            json.dump({"transactions": transactions}, f, indent=2)

    if result == 0:
        print("peer: MEMORY ROUND TRIP OK")
    else:
        print(reason)
    return result


# ---------------------------------------------------------------------------
# Side-band protocol (RogueSideBand.c RogueSideBandSend/Recv): a single 4-byte
# message -- [opCodeEn, opCode, remDataChanged, remData]. The two halves are
# independently flagged: byte 0 gates the opcode (byte 1), byte 2 gates the
# remData (byte 3). Unlike the stream/memory cores, the side-band C model binds
# PULL on port+1 and PUSH on port, so the peer connects the mirror of that.
# ---------------------------------------------------------------------------


def encode_sideband_frame(op_code_en, op_code, rem_data_changed, rem_data):
    return bytes([op_code_en & 0xFF, op_code & 0xFF, rem_data_changed & 0xFF, rem_data & 0xFF])


def decode_sideband_frame(msg):
    if len(msg) != 4:
        raise ValueError(f"expected 4-byte sideband frame, got {len(msg)}")
    return {
        "opCodeEn": msg[0],
        "opCode": msg[1],
        "remDataChanged": msg[2],
        "remData": msg[3],
    }


# Frames the peer pushes into the DUT (peer -> ZMQ -> DUT rx* outputs): an
# opcode frame that pulses rxOpCodeEn and latches rxOpCode, then a remData
# frame that latches rxRemData. Module-level so the test imports the expected
# rx* values as the single source of truth.
SIDEBAND_PEER_TO_DUT = [
    {"opCodeEn": 1, "opCode": 0xA5, "remDataChanged": 0, "remData": 0x00},
    {"opCodeEn": 0, "opCode": 0x00, "remDataChanged": 1, "remData": 0x3C},
]
SIDEBAND_RX_OPCODE = 0xA5
SIDEBAND_RX_REMDATA = 0x3C

# What the DUT should transmit back, driven by the cocotb tx* stimulus: an
# opcode 0x5A (txOpCodeEn strobe) then a remData change to 0xC3. Verified by
# opcode/remData presence flags rather than exact 4-byte tuples, because the C
# model carries the last txOpCode/txOpCodeEn forward on a remData-only send.
SIDEBAND_TX_OPCODE = 0x5A
SIDEBAND_TX_REMDATA = 0xC3


def sideband_instance_vectors(tag):
    peer_to_dut = [
        {"opCodeEn": 1, "opCode": 0x20 + tag, "remDataChanged": 0, "remData": 0},
        {"opCodeEn": 0, "opCode": 0, "remDataChanged": 1, "remData": 0x40 + tag},
    ]
    return peer_to_dut, 0x60 + tag, 0x70 + tag


def run_sideband_peer(
    port,
    result_path,
    peer_to_dut=None,
    tx_opcode=None,
    tx_remdata=None,
    ready_file=None,
):
    if peer_to_dut is None:
        peer_to_dut = SIDEBAND_PEER_TO_DUT
    if tx_opcode is None:
        tx_opcode = SIDEBAND_TX_OPCODE
    if tx_remdata is None:
        tx_remdata = SIDEBAND_TX_REMDATA

    ctx = zmq.Context()
    push = ctx.socket(zmq.PUSH)
    pull = ctx.socket(zmq.PULL)
    # RCVTIMEO bounds every recv so a stuck peer never hangs CI.
    pull.setsockopt(zmq.RCVTIMEO, RCVTIMEO_MS)

    # RogueSideBandRestart binds PULL on `port+1`, PUSH on `port` (the mirror
    # of the stream/memory cores); the peer connects the opposite way as a
    # CLIENT: PUSH -> port+1 feeds the DUT's PULL, PULL <- port drains the
    # DUT's PUSH. Never send a readiness handshake -- rely on ZMQ's async
    # connect plus RCVTIMEO.
    push.connect(f"tcp://127.0.0.1:{port + 1}")
    pull.connect(f"tcp://127.0.0.1:{port}")
    _signal_ready(ready_file)

    sent = []
    received = []
    result = 0
    reason = ""

    try:
        # Push the opcode + remData frames the DUT should surface on rx*.
        for frame in peer_to_dut:
            push.send(
                encode_sideband_frame(
                    frame["opCodeEn"], frame["opCode"], frame["remDataChanged"], frame["remData"]
                )
            )
            sent.append(frame)

        # Collect the DUT's transmitted frames (driven by cocotb tx*) until
        # both an opcode and a remData change have been observed, or timeout.
        got_opcode = None
        got_remdata = None
        while got_opcode is None or got_remdata is None:
            try:
                msg = pull.recv()
            except zmq.error.Again:
                result = 1
                reason = "peer: TIMED OUT waiting for sideband frame"
                break

            try:
                decoded = decode_sideband_frame(msg)
            except ValueError as exc:
                result = 1
                reason = f"peer: {exc}"
                break

            received.append(decoded)
            if decoded["opCodeEn"] == 1 and got_opcode is None:
                got_opcode = decoded["opCode"]
            if decoded["remDataChanged"] == 1 and got_remdata is None:
                got_remdata = decoded["remData"]

        if result == 0 and got_opcode != tx_opcode:
            result = 1
            reason = f"peer: unexpected tx opcode, got {got_opcode!r}"
        elif result == 0 and got_remdata != tx_remdata:
            result = 1
            reason = f"peer: unexpected tx remData, got {got_remdata!r}"
    finally:
        # Unconditional result file -- written even on early timeout/partial
        # completion, so the cocotb coroutine always has readable diagnostics.
        with open(result_path, "w") as f:
            json.dump({"sent": sent, "received": received}, f, indent=2)

    if result == 0:
        print("peer: SIDEBAND ROUND TRIP OK")
    else:
        print(reason)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description="Rogue-TCP protocol peer")
    parser.add_argument(
        "--mode",
        choices=[
            "stream",
            "stream-recv",
            "memory",
            "sideband",
            "stream-instance",
            "memory-instance",
            "sideband-instance",
        ],
        required=True,
    )
    parser.add_argument("--tag", type=int, default=0)
    parser.add_argument("--ready-file")
    parser.add_argument("port", type=int)
    parser.add_argument("result_path")
    args = parser.parse_args(argv)

    if args.mode == "stream":
        return run_stream_peer(args.port, args.result_path, ready_file=args.ready_file)

    if args.mode == "stream-recv":
        return run_stream_recv_peer(args.port, args.result_path, ready_file=args.ready_file)

    if args.mode == "memory":
        return run_memory_peer(args.port, args.result_path, ready_file=args.ready_file)

    if args.mode == "stream-instance":
        send_frames, expect_frames = stream_instance_vectors(args.tag)
        return run_stream_peer(
            args.port,
            args.result_path,
            send_frames,
            expect_frames,
            ready_file=args.ready_file,
        )

    if args.mode == "memory-instance":
        return run_memory_peer(
            args.port,
            args.result_path,
            memory_instance_transactions(args.tag),
            ready_file=args.ready_file,
        )

    if args.mode == "sideband-instance":
        peer_to_dut, tx_opcode, tx_remdata = sideband_instance_vectors(args.tag)
        return run_sideband_peer(
            args.port,
            args.result_path,
            peer_to_dut,
            tx_opcode,
            tx_remdata,
            ready_file=args.ready_file,
        )

    return run_sideband_peer(args.port, args.result_path, ready_file=args.ready_file)


if __name__ == "__main__":
    sys.exit(main())
