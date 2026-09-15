##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Deterministic SimLink wire codecs and shared protocol vectors."""


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
        raise ValueError(f"bad stream frame sizes: {[len(part) for part in parts]}")
    return {
        "flags": int.from_bytes(parts[0], byteorder="little"),
        "chan": parts[1][0],
        "err": parts[2][0],
        "data_hex": parts[3].hex(),
    }


STREAM_SEND_FRAMES = [
    {"flags": 0, "chan": 0, "err": 0, "data": bytes(range(16))},
    {"flags": 0, "chan": 0, "err": 0, "data": bytes([0xAA] * 8)},
    {"flags": 0, "chan": 0, "err": 0, "data": bytes(range(96))},
]
STREAM_EXPECT_FRAMES = [dict(frame) for frame in STREAM_SEND_FRAMES]


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


T_READ = 0x1
T_WRITE = 0x2
T_POST = 0x3
T_VERIFY = 0x4
T_PROBE = 0xFFFFFFFE

MEM_ID_FRAME = 0
MEM_ADDR_FRAME = 1
MEM_SIZE_FRAME = 2
MEM_TYPE_FRAME = 3
MEM_DATA_FRAME = 4
MEM_RESULT_FRAME = 5
MEM_RESP_FRAMES = 6
MEM_U32_BYTES = 4
MEM_ADDR_BYTES = 8
MEM_RESPONSE_FIXED_FRAME_SIZES = (
    MEM_U32_BYTES,
    MEM_ADDR_BYTES,
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
    fixed_sizes = tuple(
        len(parts[index])
        for index in (MEM_ID_FRAME, MEM_ADDR_FRAME, MEM_SIZE_FRAME, MEM_TYPE_FRAME)
    )
    if fixed_sizes != MEM_RESPONSE_FIXED_FRAME_SIZES:
        raise ValueError(f"bad memory response fixed-frame sizes: {fixed_sizes}")

    txn_type = int.from_bytes(parts[MEM_TYPE_FRAME], byteorder="little")
    if txn_type == T_PROBE:
        if parts[MEM_RESULT_FRAME] != b"OK":
            raise ValueError(
                f"bad memory readiness result: {parts[MEM_RESULT_FRAME]!r}"
            )
        result = "OK"
    else:
        if len(parts[MEM_RESULT_FRAME]) != MEM_U32_BYTES:
            raise ValueError(
                f"bad memory response result size: {len(parts[MEM_RESULT_FRAME])}"
            )
        result = int.from_bytes(parts[MEM_RESULT_FRAME], byteorder="little")

    return {
        "id": int.from_bytes(parts[MEM_ID_FRAME], byteorder="little"),
        "addr": int.from_bytes(parts[MEM_ADDR_FRAME], byteorder="little"),
        "size": int.from_bytes(parts[MEM_SIZE_FRAME], byteorder="little"),
        "type": txn_type,
        "data_hex": parts[MEM_DATA_FRAME].hex(),
        "result": result,
    }


MEM_TRANSACTIONS = [
    {"addr": 0x00000000, "size": 4, "write_data": bytes([1, 2, 3, 4])},
    {"addr": 0x00000010, "size": 4, "write_data": bytes([0xDE, 0xAD, 0xBE, 0xEF])},
]


def memory_instance_transactions(tag):
    return [{
        "addr": 0x00000100 + (tag * 0x10),
        "size": 4,
        "write_data": bytes([0x40 + tag, 0x50 + tag, 0x60 + tag, 0x70 + tag]),
    }]


def encode_sideband_frame(op_code_en, op_code, rem_data_changed, rem_data):
    return bytes([
        op_code_en & 0xFF,
        op_code & 0xFF,
        rem_data_changed & 0xFF,
        rem_data & 0xFF,
    ])


def decode_sideband_frame(message):
    if len(message) != 4:
        raise ValueError(f"expected 4-byte sideband frame, got {len(message)}")
    return {
        "opCodeEn": message[0],
        "opCode": message[1],
        "remDataChanged": message[2],
        "remData": message[3],
    }


SIDEBAND_PEER_TO_DUT = [
    {"opCodeEn": 1, "opCode": 0xA5, "remDataChanged": 0, "remData": 0},
    {"opCodeEn": 0, "opCode": 0, "remDataChanged": 1, "remData": 0x3C},
]
SIDEBAND_RX_OPCODE = 0xA5
SIDEBAND_RX_REMDATA = 0x3C
SIDEBAND_TX_OPCODE = 0x5A
SIDEBAND_TX_REMDATA = 0xC3


def sideband_instance_vectors(tag):
    peer_to_dut = [
        {"opCodeEn": 1, "opCode": 0x20 + tag, "remDataChanged": 0, "remData": 0},
        {"opCodeEn": 0, "opCode": 0, "remDataChanged": 1, "remData": 0x40 + tag},
    ]
    return peer_to_dut, 0x60 + tag, 0x70 + tag
