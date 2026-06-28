##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Use a two-input `AxiStreamBatcherEventBuilder` wrapper in INDEXED,
#   ROUTED, and one alternate routed table/transition-TDEST configuration.  This
#   keeps event-builder policy visible without building an exhaustive
#   source-count matrix.
# - Stimulus: Drive small AXI Stream frames on one or both inputs, program the
#   event-builder AXI-Lite bypass/timeout controls, and use transition TDEST
#   cases in routed modes.
# - Checks: Assert source-selection policy, TDEST remap, null/transition/timeout
#   counters, bypass/drop behavior, and the final batcher byte stream shape
#   through the shared leaf byte helpers.
# - Timing: Inputs are driven concurrently where the event builder requires all
#   active sources to be present, and timeout/bypass cases verify progress when
#   one source is absent or intentionally skipped.
# - Alignment check: With EnableAlignCheck=1, verify the builder stalls and flags
#   ErrorAlignDet on a tUserFirst mismatch, passes when aligned, ignores bypassed
#   channels, and that EnableAlignCheck survives a soft reset.

import os

import cocotb
import pytest
from cocotb.triggers import with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.batcher.batcher_test_utils import (
    AxisBeat,
    FlatAxisEndpoint,
    beats_to_bytes,
    cycle,
    expect_no_valid,
    expected_batched_bytes,
    payload_to_beats,
    recv_until_last_with_backpressure,
    recv_until_last,
    reset_batcher_dut,
    send_frame,
    send_frames_concurrently,
    start_batcher_clock,
    word_from_bytes,
)

DATA_CNT_BASE = 0x000
NULL_CNT_BASE = 0x100
TIMEOUT_DROP_CNT_BASE = 0x200
TRANS_CNT_ADDR = 0xFC0
TRANS_TDEST_ADDR = 0xFC4
BYPASS_ADDR = 0xFD0
ERROR_ALIGN_DET_ADDR = 0xFD4
TIMEOUT_ADDR = 0xFF0
STATUS_ADDR = 0xFF4
BLOWOFF_ADDR = 0xFF8
RST_ADDR = 0xFFC

# 0xFF8 control bits
BLOWOFF_BIT = 0x1
ENABLE_ALIGN_CHECK_BIT = 0x2
# 0xFFC reset strobes
SOFT_RST_BIT = 0x8


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.mode = os.environ.get("MODE_G", "INDEXED").strip("'").strip('"')
        self.route_mode = int(os.environ.get("ROUTE_MODE_G", "0"))
        self.trans_tdest = int(os.environ.get("TRANS_TDEST_G", "255"))
        self.source0 = FlatAxisEndpoint(dut, prefix="S0_AXIS")
        self.source1 = FlatAxisEndpoint(dut, prefix="S1_AXIS")
        self.sink = FlatAxisEndpoint(dut, prefix="M_AXIS")
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.axisClk, dut.axisRst)

        start_batcher_clock(dut)
        dut.axisRst.setimmediatevalue(1)
        dut.blowoffExt.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(0)
        self.source0.set_idle()
        self.source1.set_idle()

    async def reset(self):
        await reset_batcher_dut(self.dut)

    async def read(self, address: int) -> int:
        return await with_timeout(axil_read_u32(self.axil, address), 2, "us")

    async def write(self, address: int, value: int) -> None:
        await with_timeout(axil_write_u32(self.axil, address, value), 2, "us")

    def remapped_dest(self, index: int, original: int) -> int:
        if self.mode == "ROUTED":
            if index == 1:
                if self.route_mode == 0:
                    return 0x50 | (original & 0x0F)
                return 0xA0 | (original & 0x0C) | 0x03
            return original & 0xFF
        return index


def _frame(payload: bytes, *, dest: int, first_user: int, last_user: int):
    return (payload, dest, first_user, last_user)


def _null_beat(*, dest: int = 0) -> AxisBeat:
    return AxisBeat(
        data=word_from_bytes(b"\x00"),
        keep=0x01,
        last=1,
        dest=dest,
        user=0x01,
    )


@cocotb.test()
async def register_status_and_remap_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Pin down the management map before relying on counters later in the file.
    assert await tb.read(TRANS_TDEST_ADDR) == tb.trans_tdest
    assert await tb.read(STATUS_ADDR) == 0x02000002
    assert await tb.read(BYPASS_ADDR) == 0
    assert await tb.read(TIMEOUT_ADDR) == 0

    first = _frame(bytes(range(0x10, 0x15)), dest=0x03, first_user=0x21, last_user=0x81)
    second = _frame(bytes(range(0x20, 0x25)), dest=0x07, first_user=0x31, last_user=0x91)
    expected = [
        _frame(first[0], dest=tb.remapped_dest(0, first[1]), first_user=first[2], last_user=first[3]),
        _frame(second[0], dest=tb.remapped_dest(1, second[1]), first_user=second[2], last_user=second[3]),
    ]

    # Both channels must be valid together before the event builder can form a
    # complete event, so drive the two source coroutines concurrently.
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frames_concurrently(
        [
            (tb.source0, payload_to_beats(first[0], dest=first[1], first_user=first[2], last_user=first[3])),
            (tb.source1, payload_to_beats(second[0], dest=second[1], first_user=second[2], last_user=second[3])),
        ],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected)
    assert await tb.read(DATA_CNT_BASE + 0) == 1
    assert await tb.read(DATA_CNT_BASE + 4) == 1


@cocotb.test()
async def null_source_is_counted_and_not_forwarded_test(dut):
    tb = TB(dut)
    await tb.reset()

    data = _frame(bytes(range(0x30, 0x35)), dest=0x04, first_user=0x41, last_user=0xA1)
    expected = [
        _frame(data[0], dest=tb.remapped_dest(0, data[1]), first_user=data[2], last_user=data[3]),
    ]

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frames_concurrently(
        [
            (tb.source0, payload_to_beats(data[0], dest=data[1], first_user=data[2], last_user=data[3])),
            (tb.source1, [_null_beat(dest=0x05)]),
        ],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected)
    assert await tb.read(DATA_CNT_BASE + 0) == 1
    assert await tb.read(NULL_CNT_BASE + 4) == 1


@cocotb.test()
async def timeout_drops_missing_source_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.write(TIMEOUT_ADDR, 4)

    data = _frame(bytes(range(0x40, 0x45)), dest=0x06, first_user=0x51, last_user=0xB1)
    expected = [
        _frame(data[0], dest=tb.remapped_dest(0, data[1]), first_user=data[2], last_user=data[3]),
    ]

    # Only source 0 is present.  The timeout register should let the builder
    # emit source 0 and count source 1 as a timeout drop instead of deadlocking.
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source0,
        payload_to_beats(data[0], dest=data[1], first_user=data[2], last_user=data[3]),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected)
    assert await tb.read(DATA_CNT_BASE + 0) == 1
    assert await tb.read(TIMEOUT_DROP_CNT_BASE + 4) == 1

    recovery0 = _frame(bytes(range(0x48, 0x4D)), dest=0x07, first_user=0x59, last_user=0xB9)
    recovery1 = _frame(bytes(range(0x58, 0x5D)), dest=0x08, first_user=0x69, last_user=0xC9)
    expected = [
        _frame(recovery0[0], dest=tb.remapped_dest(0, recovery0[1]), first_user=recovery0[2], last_user=recovery0[3]),
        _frame(recovery1[0], dest=tb.remapped_dest(1, recovery1[1]), first_user=recovery1[2], last_user=recovery1[3]),
    ]

    # A later complete event should still be framed correctly after the timeout
    # event and should advance the underlying batcher sequence normally.
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frames_concurrently(
        [
            (tb.source0, payload_to_beats(recovery0[0], dest=recovery0[1], first_user=recovery0[2], last_user=recovery0[3])),
            (tb.source1, payload_to_beats(recovery1[0], dest=recovery1[1], first_user=recovery1[2], last_user=recovery1[3])),
        ],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected, seq=1)
    assert await tb.read(DATA_CNT_BASE + 0) == 2
    assert await tb.read(DATA_CNT_BASE + 4) == 1
    assert await tb.read(TIMEOUT_DROP_CNT_BASE + 4) == 1


@cocotb.test()
async def output_backpressure_holds_complete_event_test(dut):
    tb = TB(dut)
    await tb.reset()

    first = _frame(bytes(range(0x90, 0x95)), dest=0x0B, first_user=0x24, last_user=0x84)
    second = _frame(bytes(range(0xA0, 0xA5)), dest=0x0C, first_user=0x34, last_user=0x94)
    expected = [
        _frame(first[0], dest=tb.remapped_dest(0, first[1]), first_user=first[2], last_user=first[3]),
        _frame(second[0], dest=tb.remapped_dest(1, second[1]), first_user=second[2], last_user=second[3]),
    ]

    # Hold each output beat while both sources have contributed to the event.
    # The shared helper asserts that TVALID-side fields stay stable under
    # backpressure before accepting the beat.
    rx_task = cocotb.start_soon(
        recv_until_last_with_backpressure(tb.sink, clk=dut.axisClk, hold_cycles=3)
    )
    await send_frames_concurrently(
        [
            (tb.source0, payload_to_beats(first[0], dest=first[1], first_user=first[2], last_user=first[3])),
            (tb.source1, payload_to_beats(second[0], dest=second[1], first_user=second[2], last_user=second[3])),
        ],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 5, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected)
    assert await tb.read(DATA_CNT_BASE + 0) == 1
    assert await tb.read(DATA_CNT_BASE + 4) == 1


@cocotb.test()
async def blowoff_drops_inputs_and_recovers_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.write(BLOWOFF_ADDR, 1)
    await cycle(dut.axisClk, 4)
    assert int(dut.blowoffInt.value) == 1

    dropped0 = bytes(range(0xB0, 0xB5))
    dropped1 = bytes(range(0xC0, 0xC5))
    await send_frames_concurrently(
        [
            (tb.source0, payload_to_beats(dropped0, dest=0x0D, first_user=0x44, last_user=0xA4)),
            (tb.source1, payload_to_beats(dropped1, dest=0x0E, first_user=0x54, last_user=0xB4)),
        ],
        clk=dut.axisClk,
    )
    await expect_no_valid(tb.sink, clk=dut.axisClk, cycles=12)
    assert await tb.read(DATA_CNT_BASE + 0) == 0
    assert await tb.read(DATA_CNT_BASE + 4) == 0

    await tb.write(BLOWOFF_ADDR, 0)
    await cycle(dut.axisClk, 4)
    assert int(dut.blowoffInt.value) == 0

    recovery0 = _frame(bytes(range(0xD0, 0xD5)), dest=0x0F, first_user=0x64, last_user=0xC4)
    recovery1 = _frame(bytes(range(0xE0, 0xE5)), dest=0x10, first_user=0x74, last_user=0xD4)
    expected = [
        _frame(recovery0[0], dest=tb.remapped_dest(0, recovery0[1]), first_user=recovery0[2], last_user=recovery0[3]),
        _frame(recovery1[0], dest=tb.remapped_dest(1, recovery1[1]), first_user=recovery1[2], last_user=recovery1[3]),
    ]

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frames_concurrently(
        [
            (tb.source0, payload_to_beats(recovery0[0], dest=recovery0[1], first_user=recovery0[2], last_user=recovery0[3])),
            (tb.source1, payload_to_beats(recovery1[0], dest=recovery1[1], first_user=recovery1[2], last_user=recovery1[3])),
        ],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected, seq=0)


@cocotb.test()
async def bypass_skips_source_and_recovers_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.write(BYPASS_ADDR, 0b10)
    await cycle(dut.axisClk, 4)

    data = _frame(bytes(range(0x50, 0x55)), dest=0x08, first_user=0x61, last_user=0xC1)
    expected = [
        _frame(data[0], dest=tb.remapped_dest(0, data[1]), first_user=data[2], last_user=data[3]),
    ]

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source0,
        payload_to_beats(data[0], dest=data[1], first_user=data[2], last_user=data[3]),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected)
    assert await tb.read(DATA_CNT_BASE + 0) == 1
    assert await tb.read(DATA_CNT_BASE + 4) == 0

    await tb.write(BYPASS_ADDR, 0)
    await cycle(dut.axisClk, 4)

    recovery0 = _frame(bytes(range(0x60, 0x65)), dest=0x09, first_user=0x71, last_user=0xD1)
    recovery1 = _frame(bytes(range(0x70, 0x75)), dest=0x0A, first_user=0x81, last_user=0xE1)
    expected = [
        _frame(recovery0[0], dest=tb.remapped_dest(0, recovery0[1]), first_user=recovery0[2], last_user=recovery0[3]),
        _frame(recovery1[0], dest=tb.remapped_dest(1, recovery1[1]), first_user=recovery1[2], last_user=recovery1[3]),
    ]

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frames_concurrently(
        [
            (tb.source0, payload_to_beats(recovery0[0], dest=recovery0[1], first_user=recovery0[2], last_user=recovery0[3])),
            (tb.source1, payload_to_beats(recovery1[0], dest=recovery1[1], first_user=recovery1[2], last_user=recovery1[3])),
        ],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected, seq=0)


@cocotb.test()
async def routed_transition_frame_preempts_event_test(dut):
    tb = TB(dut)
    await tb.reset()
    if tb.mode != "ROUTED":
        return

    transition = _frame(bytes(range(0x80, 0x85)), dest=tb.trans_tdest, first_user=0x91, last_user=0xF1)
    blocked = AxisBeat(
        data=word_from_bytes(bytes(range(0x90, 0x98))),
        keep=0xFF,
        last=1,
        dest=0x01,
        user=0xA1,
    )
    expected = [
        _frame(transition[0], dest=tb.trans_tdest, first_user=transition[2], last_user=transition[3]),
    ]

    # Hold source 1 valid to prove the transition path selects only the source
    # with TRANS_TDEST_G and skips the other input for this event.
    tb.source1.drive(blocked)
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source0,
        payload_to_beats(transition[0], dest=transition[1], first_user=transition[2], last_user=transition[3]),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")
    tb.source1.set_idle()

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected)
    assert await tb.read(TRANS_CNT_ADDR) == 1
    assert await tb.read(DATA_CNT_BASE + 0) == 0
    assert await tb.read(DATA_CNT_BASE + 4) == 0


@cocotb.test()
async def enable_align_check_survives_soft_reset_test(dut):
    tb = TB(dut)
    await tb.reset()

    # EnableAlignCheck is persistent configuration and must be preserved across a
    # soft reset, like the bypass/timeout/blowoff settings.
    await tb.write(BLOWOFF_ADDR, ENABLE_ALIGN_CHECK_BIT)
    assert await tb.read(BLOWOFF_ADDR) == ENABLE_ALIGN_CHECK_BIT

    await tb.write(RST_ADDR, SOFT_RST_BIT)
    await cycle(dut.axisClk, 6)

    assert await tb.read(BLOWOFF_ADDR) == ENABLE_ALIGN_CHECK_BIT
    assert await tb.read(ERROR_ALIGN_DET_ADDR) == 0


@cocotb.test()
async def align_check_passes_when_first_user_matches_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.write(BLOWOFF_ADDR, ENABLE_ALIGN_CHECK_BIT)

    # Identical tUserFirst on both inputs satisfies the check, so the event is
    # built normally and nothing is flagged.
    first = _frame(bytes(range(0x10, 0x15)), dest=0x03, first_user=0x42, last_user=0x81)
    second = _frame(bytes(range(0x20, 0x25)), dest=0x07, first_user=0x42, last_user=0x91)
    expected = [
        _frame(first[0], dest=tb.remapped_dest(0, first[1]), first_user=first[2], last_user=first[3]),
        _frame(second[0], dest=tb.remapped_dest(1, second[1]), first_user=second[2], last_user=second[3]),
    ]

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frames_concurrently(
        [
            (tb.source0, payload_to_beats(first[0], dest=first[1], first_user=first[2], last_user=first[3])),
            (tb.source1, payload_to_beats(second[0], dest=second[1], first_user=second[2], last_user=second[3])),
        ],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected)
    assert await tb.read(ERROR_ALIGN_DET_ADDR) == 0
    assert await tb.read(DATA_CNT_BASE + 0) == 1
    assert await tb.read(DATA_CNT_BASE + 4) == 1


@cocotb.test()
async def align_check_blocks_on_first_user_mismatch_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.write(BLOWOFF_ADDR, ENABLE_ALIGN_CHECK_BIT)

    # Mismatched tUserFirst (0x21 vs 0x99): with the check enabled the builder
    # must stall and flag the offending channel rather than forward data.  Both
    # single-beat frames are held valid so the heads stay misaligned.
    blocked0 = payload_to_beats(bytes(range(0x30, 0x35)), dest=0x03, first_user=0x21, last_user=0x81)
    blocked1 = payload_to_beats(bytes(range(0x40, 0x45)), dest=0x07, first_user=0x99, last_user=0x91)
    tb.source0.drive(blocked0[0])
    tb.source1.drive(blocked1[0])
    await cycle(dut.axisClk, 6)

    # No event is forwarded; channel 1 (compared against the channel 0 reference)
    # is flagged while channel 0 stays clear.
    await expect_no_valid(tb.sink, clk=dut.axisClk, cycles=12)
    assert await tb.read(ERROR_ALIGN_DET_ADDR) == 0b10
    assert await tb.read(DATA_CNT_BASE + 0) == 0
    assert await tb.read(DATA_CNT_BASE + 4) == 0

    # Documented recovery: blowoff flushes the stalled pipeline, then resume.  The
    # blowoff 1->0 edge issues a soft reset that must NOT drop EnableAlignCheck.
    await tb.write(BLOWOFF_ADDR, BLOWOFF_BIT | ENABLE_ALIGN_CHECK_BIT)
    await cycle(dut.axisClk, 4)
    tb.source0.set_idle()
    tb.source1.set_idle()
    await cycle(dut.axisClk, 4)
    await tb.write(BLOWOFF_ADDR, ENABLE_ALIGN_CHECK_BIT)
    await cycle(dut.axisClk, 4)

    assert await tb.read(BLOWOFF_ADDR) == ENABLE_ALIGN_CHECK_BIT
    assert await tb.read(ERROR_ALIGN_DET_ADDR) == 0

    # An aligned event now flows normally with the check still enabled.
    recovery0 = _frame(bytes(range(0xD0, 0xD5)), dest=0x0F, first_user=0x55, last_user=0xC4)
    recovery1 = _frame(bytes(range(0xE0, 0xE5)), dest=0x10, first_user=0x55, last_user=0xD4)
    expected = [
        _frame(recovery0[0], dest=tb.remapped_dest(0, recovery0[1]), first_user=recovery0[2], last_user=recovery0[3]),
        _frame(recovery1[0], dest=tb.remapped_dest(1, recovery1[1]), first_user=recovery1[2], last_user=recovery1[3]),
    ]

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frames_concurrently(
        [
            (tb.source0, payload_to_beats(recovery0[0], dest=recovery0[1], first_user=recovery0[2], last_user=recovery0[3])),
            (tb.source1, payload_to_beats(recovery1[0], dest=recovery1[1], first_user=recovery1[2], last_user=recovery1[3])),
        ],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected, seq=0)
    assert await tb.read(ERROR_ALIGN_DET_ADDR) == 0
    assert await tb.read(DATA_CNT_BASE + 0) == 1
    assert await tb.read(DATA_CNT_BASE + 4) == 1


@cocotb.test()
async def align_check_ignores_bypassed_source_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Bypass source 1, then enable the alignment check.  A bypassed channel must
    # not contribute to the misalignment flag even though its idle tUserFirst
    # differs from the active channel, otherwise the flow would deadlock.
    await tb.write(BYPASS_ADDR, 0b10)
    await tb.write(BLOWOFF_ADDR, ENABLE_ALIGN_CHECK_BIT)
    await cycle(dut.axisClk, 4)

    data = _frame(bytes(range(0x50, 0x55)), dest=0x08, first_user=0x61, last_user=0xC1)
    expected = [
        _frame(data[0], dest=tb.remapped_dest(0, data[1]), first_user=data[2], last_user=data[3]),
    ]

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source0,
        payload_to_beats(data[0], dest=data[1], first_user=data[2], last_user=data[3]),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes(expected)
    assert await tb.read(ERROR_ALIGN_DET_ADDR) == 0
    assert await tb.read(DATA_CNT_BASE + 0) == 1
    assert await tb.read(DATA_CNT_BASE + 4) == 0


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param(
            {
                "VERSION_G": 2,
                "MODE_G": "INDEXED",
                "ROUTE_MODE_G": 0,
                "TRANS_TDEST_G": 255,
                "INPUT_PIPE_STAGES_G": 0,
                "OUTPUT_PIPE_STAGES_G": 1,
            },
            id="indexed_v2_2src",
        ),
        pytest.param(
            {
                "VERSION_G": 2,
                "MODE_G": "ROUTED",
                "ROUTE_MODE_G": 0,
                "TRANS_TDEST_G": 255,
                "INPUT_PIPE_STAGES_G": 0,
                "OUTPUT_PIPE_STAGES_G": 1,
            },
            id="routed_v2_2src",
        ),
        pytest.param(
            {
                "VERSION_G": 2,
                "MODE_G": "ROUTED",
                "ROUTE_MODE_G": 1,
                "TRANS_TDEST_G": 165,
                "INPUT_PIPE_STAGES_G": 0,
                "OUTPUT_PIPE_STAGES_G": 1,
            },
            id="routed_alt_route_trans",
        ),
    ],
)
def test_AxiStreamBatcherEventBuilder(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreambatchereventbuilderwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "protocols/batcher/wrappers/AxiStreamBatcherEventBuilderWrapper.vhd",
            ],
        },
    )
