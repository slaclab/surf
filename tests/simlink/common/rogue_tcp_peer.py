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
# Rogue-TCP peer: a separate-process pyzmq client for the Stream, Memory, and
# SideBand wire protocols implemented by the shared SimLink cores. Always run
# this module as its own OS
# process (spawned via subprocess.Popen from a cocotb test) -- never call a
# blocking pyzmq method from inside a cocotb coroutine, which shares the
# GHDL/cocotb thread and would deadlock.
#
# Wire codecs and deterministic vectors live in simlink_protocol.py so tests
# can import the protocol oracle without importing this executable peer.

import argparse
import json
import os
import sys
import time

import zmq
from zmq.utils.monitor import recv_monitor_message

try:
    from tests.simlink.common.simlink_protocol import (
        decode_mem_response,
        decode_sideband_frame,
        decode_stream_frames,
        encode_mem_request,
        encode_sideband_frame,
        encode_stream_frame,
        memory_instance_transactions,
        MEM_TRANSACTIONS,
        sideband_instance_vectors,
        SIDEBAND_PEER_TO_DUT,
        SIDEBAND_TX_OPCODE,
        SIDEBAND_TX_REMDATA,
        stream_instance_vectors,
        STREAM_EXPECT_FRAMES,
        STREAM_SEND_FRAMES,
        T_READ,
        T_WRITE,
    )
    from tests.simlink.common.zmq_sockets import make_socket
except ModuleNotFoundError as exc:
    # Fall back to the sibling modules whenever anything under the `tests`
    # package is unreachable, not only the top-level name. A site-packages
    # directory that ships its own top-level `tests` package (envyaml does)
    # shadows this repo's, so the failure surfaces as `tests.simlink` rather
    # than `tests` and the narrower check re-raised instead of falling back.
    if (exc.name or "").split(".")[0] != "tests":
        raise
    from zmq_sockets import make_socket  # noqa: E402
    from simlink_protocol import (  # noqa: E402
        decode_mem_response,
        decode_sideband_frame,
        decode_stream_frames,
        encode_mem_request,
        encode_sideband_frame,
        encode_stream_frame,
        memory_instance_transactions,
        MEM_TRANSACTIONS,
        sideband_instance_vectors,
        SIDEBAND_PEER_TO_DUT,
        SIDEBAND_TX_OPCODE,
        SIDEBAND_TX_REMDATA,
        stream_instance_vectors,
        STREAM_EXPECT_FRAMES,
        STREAM_SEND_FRAMES,
        T_READ,
        T_WRITE,
    )

RCVTIMEO_MS = int(os.environ.get("SIMLINK_PEER_RCVTIMEO_MS", "30000"))
# Bounded wait for the peer's PUSH pipe to establish before the first send, so
# ZMQ's slow-joiner behavior cannot silently drop the inbound frame. Generous
# by default because the model binds only after the sim subprocess starts (well
# after the peer signals ready); env-overridable like the RCVTIMEO budget.
CONNECT_TIMEOUT_MS = int(
    os.environ.get("SIMLINK_PEER_CONNECT_TIMEOUT_MS", "30000")
)


def _peer_socket(context, socket_type):
    # No endpoint/timeout here: the peer binds these sockets itself and its
    # receives are already bounded by the cocotb-side harness timeout.
    return make_socket(context, socket_type)


def _close_peer(context, *sockets):
    for socket in sockets:
        socket.close(linger=0)
    context.destroy(linger=0)


def _signal_ready(ready_file):
    if ready_file is not None:
        with open(ready_file, "w") as f:
            f.write("ready\n")


def _await_push_connected(push, timeout_ms=CONNECT_TIMEOUT_MS):
    """Block (bounded) until `push` reports ZMQ_EVENT_CONNECTED, so the first
    send is not dropped by ZMQ's slow-joiner behavior. MUST be called AFTER
    _signal_ready(): the model binds only once the orchestrator starts the sim,
    which waits on the ready file, so the connection can form only after this
    peer has signaled. Returns True on CONNECTED; raises TimeoutError on
    timeout (callers treat it as a hard failure)."""
    monitor = push.get_monitor_socket(zmq.EVENT_CONNECTED)
    try:
        deadline = time.monotonic() + timeout_ms / 1000.0
        while time.monotonic() < deadline:
            remaining_ms = int((deadline - time.monotonic()) * 1000)
            if remaining_ms <= 0:
                break
            if monitor.poll(timeout=min(remaining_ms, 200)):
                recv_monitor_message(monitor)
                return True
        raise TimeoutError(f"peer PUSH did not connect within {timeout_ms} ms")
    finally:
        push.disable_monitor()
        monitor.close(linger=0)


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
    push = _peer_socket(ctx, zmq.PUSH)
    pull = _peer_socket(ctx, zmq.PULL)
    # RCVTIMEO bounds every recv so a stuck peer never hangs CI.
    pull.setsockopt(zmq.RCVTIMEO, RCVTIMEO_MS)

    # RogueTcpStreamStartTransport binds PULL on `port`, PUSH on `port+1`; the peer
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
        _await_push_connected(push)
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
    except TimeoutError as exc:
        result = 1
        reason = f"peer: {exc}"
    finally:
        # Unconditional result file -- written even on early timeout/
        # partial completion, so the cocotb coroutine always has readable
        # per-transaction diagnostics.
        try:
            with open(result_path, "w") as f:
                json.dump({"sent": sent, "received": received}, f, indent=2)
        finally:
            _close_peer(ctx, push, pull)

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
    pull = _peer_socket(ctx, zmq.PULL)
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
        try:
            with open(result_path, "w") as f:
                json.dump({"received": received}, f, indent=2)
        finally:
            _close_peer(ctx, pull)

    if result == 0:
        print("peer: STREAM RECV OK")
    else:
        print(reason)
    return result


def run_memory_peer(port, result_path, memory_transactions=None, ready_file=None):
    if memory_transactions is None:
        memory_transactions = MEM_TRANSACTIONS

    ctx = zmq.Context()
    push = _peer_socket(ctx, zmq.PUSH)
    pull = _peer_socket(ctx, zmq.PULL)
    # RCVTIMEO bounds every recv so a stuck peer never hangs CI.
    pull.setsockopt(zmq.RCVTIMEO, RCVTIMEO_MS)

    # RogueTcpMemoryStartTransport binds PULL on `port`, PUSH on `port+1`; the peer
    # connects the mirror way round, as a client.
    push.connect(f"tcp://127.0.0.1:{port}")
    pull.connect(f"tcp://127.0.0.1:{port + 1}")
    _signal_ready(ready_file)

    transactions = []
    result = 0
    reason = ""
    txn_id = 0

    try:
        _await_push_connected(push)
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
    except TimeoutError as exc:
        result = 1
        reason = f"peer: {exc}"
    finally:
        # Unconditional result file -- written even on early timeout/
        # partial completion.
        try:
            with open(result_path, "w") as f:
                json.dump({"transactions": transactions}, f, indent=2)
        finally:
            _close_peer(ctx, push, pull)

    if result == 0:
        print("peer: MEMORY ROUND TRIP OK")
    else:
        print(reason)
    return result


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
    push = _peer_socket(ctx, zmq.PUSH)
    pull = _peer_socket(ctx, zmq.PULL)
    # RCVTIMEO bounds every recv so a stuck peer never hangs CI.
    pull.setsockopt(zmq.RCVTIMEO, RCVTIMEO_MS)

    # RogueSideBandStartTransport binds PULL on `port+1`, PUSH on `port` (the mirror
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
        _await_push_connected(push)
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
    except TimeoutError as exc:
        result = 1
        reason = f"peer: {exc}"
    finally:
        # Unconditional result file -- written even on early timeout/partial
        # completion, so the cocotb coroutine always has readable diagnostics.
        try:
            with open(result_path, "w") as f:
                json.dump({"sent": sent, "received": received}, f, indent=2)
        finally:
            _close_peer(ctx, push, pull)

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
