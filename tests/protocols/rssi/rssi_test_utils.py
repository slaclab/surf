##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from __future__ import annotations

from dataclasses import dataclass

from cocotb.triggers import FallingEdge, Timer

RSSI_HEADER_SIZE = 8
RSSI_SYN_HEADER_SIZE = 24

RSSI_FLAG_SYN = 0x80
RSSI_FLAG_ACK = 0x40
RSSI_FLAG_EACK = 0x20
RSSI_FLAG_RST = 0x10
RSSI_FLAG_NULL = 0x08
RSSI_FLAG_BUSY = 0x01

RSSI_VERSION = 0x1

RSSI_CORE_VHDL_SOURCES = [
    "protocols/rssi/v1/rtl/RssiConnFsm.vhd",
    "protocols/rssi/v1/rtl/RssiMonitor.vhd",
    "protocols/rssi/v1/rtl/RssiRxFsm.vhd",
    "protocols/rssi/v1/rtl/RssiTxFsm.vhd",
    "protocols/rssi/v1/rtl/RssiCore.vhd",
]

RSSI_CORE_WRAPPER_VHDL_SOURCES = RSSI_CORE_VHDL_SOURCES + [
    "protocols/rssi/v1/rtl/RssiCoreWrapper.vhd",
]


@dataclass(frozen=True)
class RssiParams:
    # Defaults are ordinary valid negotiation values, not reset values.  Tests
    # override fields when they need to pin an exact SYN encoding.
    version: int = RSSI_VERSION
    chksum_en: int = 1
    max_outs_seg: int = 8
    max_seg_size: int = 1024
    retrans_tout: int = 1000
    cumul_ack_tout: int = 10
    null_seg_tout: int = 100
    max_retrans: int = 4
    max_cum_ack: int = 3
    max_outofseq: int = 0
    timeout_unit: int = 1
    connection_id: int = 0x1234_5678


@dataclass(frozen=True)
class RssiHeader:
    flags: int
    header_length: int
    sequence: int
    acknowledge: int
    checksum: int
    params: RssiParams | None = None

    @property
    def syn(self) -> bool:
        return bool(self.flags & RSSI_FLAG_SYN)

    @property
    def ack(self) -> bool:
        return bool(self.flags & RSSI_FLAG_ACK)

    @property
    def rst(self) -> bool:
        return bool(self.flags & RSSI_FLAG_RST)

    @property
    def nul(self) -> bool:
        return bool(self.flags & RSSI_FLAG_NULL)

    @property
    def busy(self) -> bool:
        return bool(self.flags & RSSI_FLAG_BUSY)


def ones_complement_checksum(data: bytes) -> int:
    # RSSI follows the RUDP/RFC 1151 style 16-bit one's-complement sum over the
    # header bytes in network order.  Folding after each add keeps the Python
    # model aligned with the hardware's carry behavior.
    if len(data) % 2:
        data += b"\x00"

    total = 0
    for index in range(0, len(data), 2):
        total += int.from_bytes(data[index : index + 2], "big")
        total = (total & 0xFFFF) + (total >> 16)

    total = (total & 0xFFFF) + (total >> 16)
    return (~total) & 0xFFFF


def checksum_is_valid(header: bytes) -> bool:
    # A header with its checksum field included validates when the folded sum is
    # all ones.  This is the receive-side check that `RssiChksum.check_o`
    # exposes after the module complements the accumulated sum.
    total = 0
    for index in range(0, len(header), 2):
        total += int.from_bytes(header[index : index + 2], "big")
        total = (total & 0xFFFF) + (total >> 16)
    total = (total & 0xFFFF) + (total >> 16)
    return total == 0xFFFF


def _u8(value: int) -> int:
    return value & 0xFF


def _u16(value: int) -> bytes:
    return (value & 0xFFFF).to_bytes(2, "big")


def _u32(value: int) -> bytes:
    return (value & 0xFFFF_FFFF).to_bytes(4, "big")


def _with_checksum(header: bytes, *, enable_checksum: bool = True) -> bytes:
    # Builders support zeroed checksum fields so header-format tests can compare
    # `RssiHeaderReg` output before `RssiTxFsm` appends the computed checksum.
    if not enable_checksum:
        return header
    checksum = ones_complement_checksum(header)
    return header[:-2] + _u16(checksum)


def build_non_syn_header(
    *,
    flags: int,
    sequence: int,
    acknowledge: int,
    enable_checksum: bool = True,
) -> bytes:
    # Non-SYN RSSI headers are exactly one 64-bit word.  Bytes 4 and 5 are
    # reserved, and bytes 6 and 7 are the checksum placeholder.
    header = bytes(
        [
            _u8(flags),
            RSSI_HEADER_SIZE,
            _u8(sequence),
            _u8(acknowledge),
            0x00,
            0x00,
            0x00,
            0x00,
        ]
    )
    return _with_checksum(header, enable_checksum=enable_checksum)


def build_ack_header(
    *,
    sequence: int,
    acknowledge: int,
    busy: bool = False,
    enable_checksum: bool = True,
) -> bytes:
    flags = RSSI_FLAG_ACK | (RSSI_FLAG_BUSY if busy else 0)
    return build_non_syn_header(
        flags=flags,
        sequence=sequence,
        acknowledge=acknowledge,
        enable_checksum=enable_checksum,
    )


def build_data_header(
    *,
    sequence: int,
    acknowledge: int,
    ack: bool = True,
    busy: bool = False,
    enable_checksum: bool = True,
) -> bytes:
    flags = (RSSI_FLAG_ACK if ack else 0) | (RSSI_FLAG_BUSY if busy else 0)
    return build_non_syn_header(
        flags=flags,
        sequence=sequence,
        acknowledge=acknowledge,
        enable_checksum=enable_checksum,
    )


def build_null_header(
    *,
    sequence: int,
    acknowledge: int,
    ack: bool = True,
    busy: bool = False,
    enable_checksum: bool = True,
) -> bytes:
    flags = RSSI_FLAG_NULL | (RSSI_FLAG_ACK if ack else 0) | (RSSI_FLAG_BUSY if busy else 0)
    return build_non_syn_header(
        flags=flags,
        sequence=sequence,
        acknowledge=acknowledge,
        enable_checksum=enable_checksum,
    )


def build_rst_header(
    *,
    sequence: int,
    acknowledge: int,
    busy: bool = False,
    enable_checksum: bool = True,
) -> bytes:
    flags = RSSI_FLAG_RST | (RSSI_FLAG_BUSY if busy else 0)
    return build_non_syn_header(
        flags=flags,
        sequence=sequence,
        acknowledge=acknowledge,
        enable_checksum=enable_checksum,
    )


def build_syn_header(
    *,
    sequence: int,
    acknowledge: int,
    ack: bool = False,
    params: RssiParams = RssiParams(),
    enable_checksum: bool = True,
) -> bytes:
    # SYN adds two more 64-bit words of negotiation parameters.  The byte order
    # here is protocol/network order; the RTL stream path byte-swaps separately.
    flags = RSSI_FLAG_SYN | (RSSI_FLAG_ACK if ack else 0)
    word0 = bytes(
        [
            flags,
            RSSI_SYN_HEADER_SIZE,
            _u8(sequence),
            _u8(acknowledge),
            ((params.version & 0xF) << 4) | 0x08 | ((params.chksum_en & 0x1) << 2),
            _u8(params.max_outs_seg),
        ]
    ) + _u16(params.max_seg_size)
    word1 = (
        _u16(params.retrans_tout)
        + _u16(params.cumul_ack_tout)
        + _u16(params.null_seg_tout)
        + bytes([_u8(params.max_retrans), _u8(params.max_cum_ack)])
    )
    word2 = (
        bytes([_u8(params.max_outofseq), _u8(params.timeout_unit)])
        + _u32(params.connection_id)
        + b"\x00\x00"
    )
    return _with_checksum(word0 + word1 + word2, enable_checksum=enable_checksum)


def build_data_frame(
    payload: bytes,
    *,
    sequence: int,
    acknowledge: int,
    ack: bool = True,
    busy: bool = False,
    enable_checksum: bool = True,
) -> bytes:
    return build_data_header(
        sequence=sequence,
        acknowledge=acknowledge,
        ack=ack,
        busy=busy,
        enable_checksum=enable_checksum,
    ) + payload


def parse_header(frame: bytes) -> RssiHeader:
    # Keep parsing deliberately strict so helper misuse fails at the protocol
    # boundary instead of producing misleading test expectations.
    if len(frame) < RSSI_HEADER_SIZE:
        raise ValueError("RSSI frame is shorter than the fixed header")

    flags = frame[0]
    header_length = frame[1]
    if flags & RSSI_FLAG_SYN:
        if header_length != RSSI_SYN_HEADER_SIZE or len(frame) < RSSI_SYN_HEADER_SIZE:
            raise ValueError("Malformed RSSI SYN header length")
        checksum = int.from_bytes(frame[22:24], "big")
        params = RssiParams(
            version=(frame[4] >> 4) & 0xF,
            chksum_en=(frame[4] >> 2) & 0x1,
            max_outs_seg=frame[5],
            max_seg_size=int.from_bytes(frame[6:8], "big"),
            retrans_tout=int.from_bytes(frame[8:10], "big"),
            cumul_ack_tout=int.from_bytes(frame[10:12], "big"),
            null_seg_tout=int.from_bytes(frame[12:14], "big"),
            max_retrans=frame[14],
            max_cum_ack=frame[15],
            max_outofseq=frame[16],
            timeout_unit=frame[17],
            connection_id=int.from_bytes(frame[18:22], "big"),
        )
    else:
        if header_length != RSSI_HEADER_SIZE:
            raise ValueError("Malformed RSSI non-SYN header length")
        checksum = int.from_bytes(frame[6:8], "big")
        params = None

    return RssiHeader(
        flags=flags,
        header_length=header_length,
        sequence=frame[2],
        acknowledge=frame[3],
        checksum=checksum,
        params=params,
    )


def header_words(header: bytes) -> list[int]:
    # Direct `RssiHeaderReg` output is compared as big-endian 64-bit protocol
    # words.  Later stream-facing tests can byte-swap at the AXI Stream layer.
    if len(header) % 8:
        raise ValueError("RSSI headers are expected to be 64-bit aligned")
    return [int.from_bytes(header[index : index + 8], "big") for index in range(0, len(header), 8)]


def stream_word_from_header_word(header_word: int) -> int:
    # `RssiRxFsm` applies `endianSwap64()` to the incoming 64-bit stream word
    # before decoding it.  Drive the byte-reversed value on the flattened SSI
    # port so the internal protocol word matches `header_words()`.
    return int.from_bytes(header_word.to_bytes(8, "big")[::-1], "big")


def stream_words_from_header(header: bytes) -> list[int]:
    return [stream_word_from_header_word(word) for word in header_words(header)]


def protocol_bytes_from_stream_word(word: int) -> bytes:
    # RSSI transport headers are byte-swapped onto the 64-bit AXI Stream data
    # bus.  Reverse the stream word before parsing it as protocol-order bytes.
    return word.to_bytes(8, "big")[::-1]


def stream_word_from_protocol_bytes(protocol_bytes: bytes) -> int:
    if len(protocol_bytes) != 8:
        raise ValueError("RSSI stream words must be exactly 8 bytes")
    return int.from_bytes(protocol_bytes[::-1], "big")


def format_transport_frame(beats) -> str:
    header = parse_header(protocol_bytes_from_stream_word(beats[0].data))
    return (
        f"flags=0x{header.flags:02x}, seq={header.sequence}, "
        f"ack={header.acknowledge}, beats={[f'0x{beat.data:016x}' for beat in beats]}"
    )


async def recv_matching_transport_frame(
    endpoint,
    *,
    clk,
    match,
    timeout_cycles: int = 512,
):
    beats = []
    seen = []
    for _ in range(timeout_cycles):
        await FallingEdge(clk)
        await Timer(1, unit="ns")
        if int(endpoint._sig("TValid").value) == 1 and int(endpoint._sig("TReady").value) == 1:
            beat = endpoint.snapshot()
            if not beats and beat.sof != 1:
                continue
            beats.append(beat)
            if beat.last == 1:
                try:
                    header = parse_header(protocol_bytes_from_stream_word(beats[0].data))
                except ValueError:
                    seen.append(f"malformed beats={[f'0x{item.data:016x}' for item in beats]}")
                else:
                    seen.append(format_transport_frame(beats))
                    if match(header, beats):
                        return beats
                beats = []
    raise AssertionError(f"Timed out waiting for matching {endpoint.prefix} frame; seen={seen}")


async def recv_transport_data_frame(
    endpoint,
    *,
    clk,
    timeout_cycles: int = 512,
):
    return await recv_matching_transport_frame(
        endpoint,
        clk=clk,
        match=lambda header, beats: not header.syn and not header.nul and len(beats) > 1,
        timeout_cycles=timeout_cycles,
    )


def header_without_checksum(header: bytes) -> bytes:
    # Checksum-generation tests need the same header content with only the final
    # checksum field cleared.
    parsed = parse_header(header)
    if parsed.syn:
        return header[:22] + b"\x00\x00"
    return header[:6] + b"\x00\x00"
