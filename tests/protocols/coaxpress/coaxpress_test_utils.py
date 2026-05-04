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
from typing import Sequence, TypeVar

import cocotb
from cocotb.clock import Clock
from cocotb.handle import Immediate
from cocotb.triggers import RisingEdge, Timer

from tests.axi.utils import wait_sampled_ready


CXP_IDLE = 0xB53C3CBC
CXP_IDLE_K = 0x7
CXP_SOP = 0xFBFBFBFB
CXP_EOP = 0xFDFDFDFD
CXP_TRIG = 0x5C5C5C5C
CXP_MARKER = 0x7C7C7C7C
CXP_IO_ACK = 0xDCDCDCDC

# Spec-defined CoaXPress packet-class bytes. Keep benches on these names so
# future top-level coverage stays tied to the published packet classes.
CXP_PKT_STREAM_DATA = 0x01
CXP_PKT_IMAGE_HEADER = 0x01
CXP_PKT_IMAGE_LINE = 0x02
CXP_PKT_CTRL_ACK_NO_TAG = 0x03
CXP_ACK_SUCCESS = 0x01
CXP_ACK_SUCCESS_ALT = 0x04
CXP_PKT_CTRL_ACK_WITH_TAG = 0x06
CXP_PKT_EVENT = 0x07
CXP_PKT_EVENT_ACK = 0x08
CXP_PKT_HEARTBEAT = 0x09

# Low-speed symbol bytes used directly by the TX-side CoaXPress logic.
CXP_K28_1 = 0x3C
CXP_K28_2 = 0x5C
CXP_K28_4 = 0x9C
CXP_K28_5 = 0xBC
CXP_D21_5 = 0xB5

# CoaXPress-over-Fiber bridge control bytes.
CXPOF_IDLE = 0x07
CXPOF_SEQ = 0x9C
CXPOF_START = 0xFB
CXPOF_TERM = 0xFD
CXPOF_ERROR = 0xFE

CXPOF_SOP_CTRL_LOW_SPEED = 0x00
CXPOF_SOP_CTRL_HIGH_SPEED = 0x80
CXPOF_SOP_CTRL_HKP = 0x01
CXPOF_SOP_CTRL_UPDATE_BIT = 3
CXPOF_SOP_CTRL_LS_RATE_BIT = 1

CXPOF_RX_ERR_NONE = 0x0
CXPOF_RX_ERR_SEQ_MISMATCH = 0x1
CXPOF_RX_ERR_IDLE_ERROR = 0x2
CXPOF_RX_ERR_PAYLOAD_ABORT = 0x3
CXPOF_RX_ERR_BAD_CONTROL = 0x4
CXPOF_RX_ERR_OVERWRITE = 0x5
CXPOF_RX_ERR_HKP_MALFORMED = 0x6

CXP_CRC32_POLY = 0x04C11DB7


@dataclass
class AxisBeat:
    data: int
    keep: int
    last: int = 0
    user: int = 0


def repeat_byte(value: int) -> int:
    byte = value & 0xFF
    return byte | (byte << 8) | (byte << 16) | (byte << 24)


def word_to_bytes(word: int, *, byte_count: int = 4) -> list[int]:
    return [(word >> (8 * index)) & 0xFF for index in range(byte_count)]


def pack_bytes(payload: bytes, *, width_bytes: int) -> int:
    return int.from_bytes(payload.ljust(width_bytes, b"\x00"), "little")


def pack_u32_words_le(words: list[int]) -> bytes:
    return b"".join((word & 0xFFFFFFFF).to_bytes(4, "little") for word in words)


def unpack_kept_bytes(data: int, keep: int, *, width_bytes: int) -> bytes:
    lanes = word_to_bytes(data, byte_count=width_bytes)
    return bytes(byte for index, byte in enumerate(lanes) if (keep >> index) & 0x1)


def endian_swap32(word: int) -> int:
    return int.from_bytes((word & 0xFFFFFFFF).to_bytes(4, "little"), "big")


def reverse_bits(value: int, width: int) -> int:
    result = 0
    for bit in range(width):
        if value & (1 << bit):
            result |= 1 << (width - 1 - bit)
    return result


def _crc_byte_lookup(byte_value: int, *, poly: int = CXP_CRC32_POLY) -> int:
    crc = (byte_value & 0xFF) << 24
    for _ in range(8):
        if crc & 0x80000000:
            crc = ((crc << 1) & 0xFFFFFFFF) ^ poly
        else:
            crc = (crc << 1) & 0xFFFFFFFF
    return crc


def cxp_crc_word(words: Sequence[int]) -> int:
    # Mirrors the CoaXPressConfig/CoaXPressRxLane CRC convention: initialize the
    # CRC to all ones, bit-reverse each byte before lookup, bit-reverse each final
    # CRC byte, then endian-swap the driven 32-bit word.
    crc = 0xFFFFFFFF
    for word in words:
        for byte_index in range(4):
            byte_value = (word >> (8 * byte_index)) & 0xFF
            byte_xor = ((crc >> 24) & 0xFF) ^ reverse_bits(byte_value, 8)
            crc = ((crc << 8) & 0xFFFFFFFF) ^ _crc_byte_lookup(byte_xor)

    ret = 0
    for byte_index in range(4):
        ret |= reverse_bits((crc >> (8 * byte_index)) & 0xFF, 8) << (8 * byte_index)
    return endian_swap32(ret)


def pack_words(words: list[int], *, word_bits: int = 32) -> int:
    mask = (1 << word_bits) - 1
    value = 0
    for index, word in enumerate(words):
        value |= (word & mask) << (index * word_bits)
    return value


def keep_for_words(word_count: int) -> int:
    return (1 << (4 * word_count)) - 1


def lane_keep_mask(indices: list[int]) -> int:
    keep = 0
    for index in indices:
        keep |= 0xF << (4 * index)
    return keep


def start_clock(signal, *, period_ns: float = 5.0) -> None:
    cocotb.start_soon(Clock(signal, period_ns, unit="ns").start())


def set_initial_values(dut, values: dict[str, int]) -> None:
    for signal_name, value in values.items():
        getattr(dut, signal_name).value = Immediate(value)


async def cycle(clk, count: int = 1) -> None:
    for _ in range(count):
        await RisingEdge(clk)
        await Timer(1, unit="ns")


async def reset_signals(dut, *, clk, reset_names: tuple[str, ...], assert_cycles: int = 4, release_cycles: int = 2) -> None:
    for reset_name in reset_names:
        getattr(dut, reset_name).value = Immediate(1)
    await cycle(clk, assert_cycles)
    for reset_name in reset_names:
        getattr(dut, reset_name).value = 0
    await cycle(clk, release_cycles)


async def reset_dut(dut, *, clk_name: str = "rxClk", reset_names: tuple[str, ...] = ("rxRst",)) -> None:
    clk = getattr(dut, clk_name)
    await reset_signals(dut, clk=clk, reset_names=reset_names)


def pulse_snapshot(dut, *, valid_name: str, field_names: tuple[str, ...]) -> dict[str, int] | None:
    if int(getattr(dut, valid_name).value) == 0:
        return None
    return {field_name: int(getattr(dut, field_name).value) for field_name in field_names}


def append_snapshot_if_valid(
    target: list[dict[str, int]],
    dut,
    *,
    valid_name: str,
    field_names: tuple[str, ...],
) -> None:
    snapshot = pulse_snapshot(dut, valid_name=valid_name, field_names=field_names)
    if snapshot is not None:
        target.append(snapshot)


async def send_rx_word(
    dut,
    *,
    data: int,
    data_k: int,
    clk,
    link_up: int = 1,
    capture: list[dict[str, int]] | None = None,
    valid_name: str | None = None,
    field_names: tuple[str, ...] = (),
) -> None:
    dut.rxLinkUp.value = link_up
    dut.rxData.value = data
    dut.rxDataK.value = data_k
    await RisingEdge(clk)
    await Timer(1, unit="ns")
    if capture is not None and valid_name is not None:
        snapshot = pulse_snapshot(dut, valid_name=valid_name, field_names=field_names)
        if snapshot is not None:
            capture.append(snapshot)


async def send_axis_payload(
    dut,
    *,
    clk,
    prefix: str,
    payload: bytes,
    width_bytes: int,
    tuser: int = 0,
) -> None:
    getattr(dut, f"{prefix}_TVALID").value = 1
    getattr(dut, f"{prefix}_TDATA").value = pack_bytes(payload, width_bytes=width_bytes)
    getattr(dut, f"{prefix}_TKEEP").value = (1 << len(payload)) - 1
    getattr(dut, f"{prefix}_TLAST").value = 1
    getattr(dut, f"{prefix}_TUSER").value = tuser
    await wait_sampled_ready(
        getattr(dut, f"{prefix}_TREADY"),
        clk=clk,
    )
    getattr(dut, f"{prefix}_TVALID").value = 0
    getattr(dut, f"{prefix}_TDATA").value = 0
    getattr(dut, f"{prefix}_TKEEP").value = 0
    getattr(dut, f"{prefix}_TLAST").value = 0
    getattr(dut, f"{prefix}_TUSER").value = 0


async def collect_stream_bytes(
    dut,
    *,
    clk,
    valid_name: str,
    data_name: str,
    count: int,
    timeout_cycles: int,
    ready_name: str | None = None,
) -> bytes:
    payload = bytearray()
    if ready_name is not None:
        getattr(dut, ready_name).value = 1
    for _ in range(timeout_cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if int(getattr(dut, valid_name).value) == 1:
            payload.append(int(getattr(dut, data_name).value))
            if len(payload) >= count:
                return bytes(payload)
    raise AssertionError(f"Timed out waiting for {count} bytes on {data_name}")


_T = TypeVar("_T")


def find_subsequence(sequence: Sequence[_T], expected: Sequence[_T]) -> int | None:
    for start in range(len(sequence) - len(expected) + 1):
        if list(sequence[start : start + len(expected)]) == list(expected):
            return start
    return None


async def send_axis_beats_no_ready(
    dut,
    *,
    beats: list[AxisBeat],
    clk,
    prefix: str = "sAxis",
    capture: list[dict[str, int]] | None = None,
    valid_name: str | None = None,
    field_names: tuple[str, ...] = (),
) -> None:
    getattr(dut, f"{prefix}TValid").value = 0
    getattr(dut, f"{prefix}TData").value = 0
    getattr(dut, f"{prefix}TKeep").value = 0
    getattr(dut, f"{prefix}TLast").value = 0
    for beat in beats:
        getattr(dut, f"{prefix}TValid").value = 1
        getattr(dut, f"{prefix}TData").value = beat.data
        getattr(dut, f"{prefix}TKeep").value = beat.keep
        getattr(dut, f"{prefix}TLast").value = beat.last
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if capture is not None and valid_name is not None:
            snapshot = pulse_snapshot(dut, valid_name=valid_name, field_names=field_names)
            if snapshot is not None:
                capture.append(snapshot)
    getattr(dut, f"{prefix}TValid").value = 0
    getattr(dut, f"{prefix}TData").value = 0
    getattr(dut, f"{prefix}TKeep").value = 0
    getattr(dut, f"{prefix}TLast").value = 0


async def collect_pulses(
    dut,
    *,
    clk,
    cycles: int,
    valid_name: str,
    field_names: tuple[str, ...],
) -> list[dict[str, int]]:
    observed: list[dict[str, int]] = []
    for _ in range(cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        snapshot = pulse_snapshot(dut, valid_name=valid_name, field_names=field_names)
        if snapshot is not None:
            observed.append(snapshot)
    return observed
