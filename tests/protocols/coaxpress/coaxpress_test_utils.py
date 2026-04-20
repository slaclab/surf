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

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


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
CXP_PKT_EVENT_ACK = 0x07
CXP_PKT_HEARTBEAT = 0x09

# CoaXPress-over-Fiber bridge control bytes.
CXPOF_IDLE = 0x07
CXPOF_SEQ = 0x9C
CXPOF_START = 0xFB
CXPOF_TERM = 0xFD
CXPOF_ERROR = 0xFE


@dataclass
class AxisBeat:
    data: int
    keep: int
    last: int = 0
    user: int = 0


def repeat_byte(value: int) -> int:
    byte = value & 0xFF
    return byte | (byte << 8) | (byte << 16) | (byte << 24)


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


async def cycle(clk, count: int = 1) -> None:
    for _ in range(count):
        await RisingEdge(clk)
        await Timer(1, unit="ns")


async def reset_dut(dut, *, clk_name: str = "rxClk", reset_names: tuple[str, ...] = ("rxRst",)) -> None:
    clk = getattr(dut, clk_name)
    for reset_name in reset_names:
        getattr(dut, reset_name).setimmediatevalue(1)
    await cycle(clk, 4)
    for reset_name in reset_names:
        getattr(dut, reset_name).value = 0
    await cycle(clk, 2)


def pulse_snapshot(dut, *, valid_name: str, field_names: tuple[str, ...]) -> dict[str, int] | None:
    if int(getattr(dut, valid_name).value) == 0:
        return None
    return {field_name: int(getattr(dut, field_name).value) for field_name in field_names}


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
