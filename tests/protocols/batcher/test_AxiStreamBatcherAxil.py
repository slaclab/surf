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
# - Sweep: Use the `AxiStreamBatcherAxil` wrapper in V2 mode with common and
#   independent AXI-Lite/stream clocks, matching the control-surface targets.
# - Stimulus: Program the runtime threshold, max-subframe, max-clock-gap,
#   `softRst`, and `blowoff` registers through a cocotb AXI-Lite master while
#   driving flat AXI Stream subframes through the wrapped batcher.
# - Checks: Register reset values and readback must match the RTL/PyRogue map,
#   and control writes must change stream-side termination or drop/reset behavior
#   without re-proving every batcher payload byte beyond the leaf helper model.
# - Timing: The common-clock case keeps readback strict, while the async case
#   waits for the expected register value through the CDC bridge before using
#   writes to steer stream-side behavior.

import os

import cocotb
import pytest
from cocotb.clock import Clock
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
    recv_beats,
    recv_until_last,
    reset_batcher_dut,
    send_frame,
    start_batcher_clock,
)

SUPER_FRAME_BYTE_THRESHOLD_ADDR = 0x00
MAX_SUB_FRAMES_ADDR = 0x04
MAX_CLK_GAP_ADDR = 0x08
STATUS_ADDR = 0x0C
BLOWOFF_ADDR = 0xF8
SOFT_RST_ADDR = 0xFC


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.common_clock = os.environ.get("COMMON_CLOCK_G", "True").lower() == "true"
        self.source = FlatAxisEndpoint(dut, prefix="S_AXIS")
        self.sink = FlatAxisEndpoint(dut, prefix="M_AXIS")

        start_batcher_clock(dut)
        dut.axisRst.setimmediatevalue(1)
        dut.axilClkIn.setimmediatevalue(0)
        dut.axilRstIn.setimmediatevalue(1)
        if self.common_clock:
            self.axil_clk = dut.axisClk
            self.axil_rst = dut.axisRst
        else:
            cocotb.start_soon(Clock(dut.axilClkIn, 7.0, unit="ns").start())
            self.axil_clk = dut.axilClkIn
            self.axil_rst = dut.axilRstIn
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), self.axil_clk, self.axil_rst)

        dut.M_AXIS_TREADY.setimmediatevalue(0)
        self.source.set_idle()

    async def reset(self):
        if self.common_clock:
            await reset_batcher_dut(self.dut)
        else:
            self.dut.axisRst.setimmediatevalue(1)
            self.dut.axilRstIn.setimmediatevalue(1)
            await cycle(self.dut.axisClk, 8)
            await cycle(self.dut.axilClkIn, 8)
            self.dut.axisRst.value = 0
            await cycle(self.dut.axisClk, 16)
            self.dut.axilRstIn.value = 0
            await cycle(self.dut.axisClk, 64)
            await cycle(self.dut.axilClkIn, 64)

    async def read(self, address: int) -> int:
        return await with_timeout(axil_read_u32(self.axil, address), 2, "us")

    async def read_eventually(self, address: int, expected: int) -> None:
        # The async bridge can return reset/CDC-latency responses before the
        # target register response reaches the AXI-Lite side.
        observed = []
        for _ in range(8):
            observed.append(await self.read(address))
            if observed[-1] == expected:
                return
            await cycle(self.axil_clk, 4)
        raise AssertionError(
            f"AXI-Lite readback at 0x{address:02X} never reached "
            f"0x{expected:08X}; observed {observed}"
        )

    async def write(self, address: int, value: int) -> None:
        await with_timeout(axil_write_u32(self.axil, address, value), 2, "us")
        if not self.common_clock:
            await cycle(self.dut.axisClk, 16)


@cocotb.test()
async def register_reset_and_readback_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The reset values mirror `AxiStreamBatcherAxil` generics and the PyRogue
    # register map.  Status bit 0 is idle and bits 27:24 report VERSION_G.
    if tb.common_clock:
        assert await tb.read(SUPER_FRAME_BYTE_THRESHOLD_ADDR) == 8192
        assert await tb.read(MAX_SUB_FRAMES_ADDR) == 32
        assert await tb.read(MAX_CLK_GAP_ADDR) == 256
        assert await tb.read(STATUS_ADDR) == 0x02000001
    else:
        await tb.read_eventually(SUPER_FRAME_BYTE_THRESHOLD_ADDR, 8192)
        await tb.read_eventually(MAX_SUB_FRAMES_ADDR, 32)
        await tb.read_eventually(MAX_CLK_GAP_ADDR, 256)
        await tb.read_eventually(STATUS_ADDR, 0x02000001)

    # Write/readback checks keep the control register map pinned before the
    # stream-side tests rely on these fields to steer termination behavior.
    await tb.write(SUPER_FRAME_BYTE_THRESHOLD_ADDR, 24)
    await tb.write(MAX_SUB_FRAMES_ADDR, 2)
    await tb.write(MAX_CLK_GAP_ADDR, 5)
    if tb.common_clock:
        assert await tb.read(SUPER_FRAME_BYTE_THRESHOLD_ADDR) == 24
        assert await tb.read(MAX_SUB_FRAMES_ADDR) == 2
        assert await tb.read(MAX_CLK_GAP_ADDR) == 5
    else:
        await tb.read_eventually(SUPER_FRAME_BYTE_THRESHOLD_ADDR, 24)
        await tb.read_eventually(MAX_SUB_FRAMES_ADDR, 2)
        await tb.read_eventually(MAX_CLK_GAP_ADDR, 5)


@cocotb.test()
async def max_subframe_register_controls_termination_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A register write to MaxSubFrames should be enough to make the wrapper
    # combine two leaf subframes into one superframe.
    await tb.write(SUPER_FRAME_BYTE_THRESHOLD_ADDR, 0)
    await tb.write(MAX_SUB_FRAMES_ADDR, 2)
    await tb.write(MAX_CLK_GAP_ADDR, 256)

    first = (bytes(range(0x10, 0x18)), 0x1, 0x21, 0x81)
    second = (bytes(range(0x20, 0x25)), 0x2, 0x31, 0x91)

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    for payload, dest, first_user, last_user in (first, second):
        await send_frame(
            tb.source,
            payload_to_beats(
                payload,
                dest=dest,
                first_user=first_user,
                last_user=last_user,
            ),
            clk=dut.axisClk,
        )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes([first, second])
    assert rx_beats[-1].last == 1


@cocotb.test()
async def threshold_and_gap_registers_control_termination_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Use the AXI-Lite register path to exercise the two other termination
    # families without duplicating all of the leaf byte grammar assertions.
    await tb.write(MAX_SUB_FRAMES_ADDR, 8)
    await tb.write(MAX_CLK_GAP_ADDR, 0)
    await tb.write(SUPER_FRAME_BYTE_THRESHOLD_ADDR, 24)

    threshold_frame = (bytes(range(0x40, 0x48)), 0x3, 0x41, 0xA1)
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source,
        payload_to_beats(
            threshold_frame[0],
            dest=threshold_frame[1],
            first_user=threshold_frame[2],
            last_user=threshold_frame[3],
        ),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")
    assert beats_to_bytes(rx_beats) == expected_batched_bytes([threshold_frame])

    await tb.write(SUPER_FRAME_BYTE_THRESHOLD_ADDR, 0)
    await tb.write(MAX_CLK_GAP_ADDR, 3)

    gap_frame = (bytes(range(0x50, 0x55)), 0x4, 0x51, 0xB1)
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source,
        payload_to_beats(
            gap_frame[0],
            dest=gap_frame[1],
            first_user=gap_frame[2],
            last_user=gap_frame[3],
        ),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")
    assert beats_to_bytes(rx_beats) == expected_batched_bytes([gap_frame], seq=1)


@cocotb.test()
async def soft_reset_discards_pending_superframe_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.write(MAX_SUB_FRAMES_ADDR, 8)
    await tb.write(MAX_CLK_GAP_ADDR, 256)

    # Start, but do not finish, a subframe.  The soft reset register should
    # return the stream path to idle before the next valid frame is accepted.
    partial = AxisBeat(
        data=int.from_bytes(bytes(range(0x60, 0x68)), "little"),
        keep=0xFF,
        last=0,
        dest=0x5,
        user=0x12,
    )
    await tb.source.send(partial, clk=dut.axisClk)
    partial_rx = await with_timeout(recv_beats(tb.sink, clk=dut.axisClk, count=1), 2, "us")
    assert partial_rx[0].last == 0

    await tb.write(SOFT_RST_ADDR, 1)
    await cycle(dut.axisClk, 4)
    assert int(dut.idle.value) == 1

    await tb.write(MAX_SUB_FRAMES_ADDR, 1)
    recovery = (bytes(range(0x70, 0x75)), 0x6, 0x61, 0xC1)
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source,
        payload_to_beats(
            recovery[0],
            dest=recovery[1],
            first_user=recovery[2],
            last_user=recovery[3],
        ),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")
    assert beats_to_bytes(rx_beats) == expected_batched_bytes([recovery])


@cocotb.test()
async def blowoff_drops_accepted_input_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.write(MAX_SUB_FRAMES_ADDR, 1)
    await tb.write(BLOWOFF_ADDR, 1)

    # Blowoff should keep accepting inbound stream beats while resetting the
    # batcher path, so accepted traffic must not create a malformed output frame.
    dropped = bytes(range(0x80, 0x85))
    await send_frame(
        tb.source,
        payload_to_beats(dropped, dest=0x7, first_user=0x71, last_user=0xD1),
        clk=dut.axisClk,
    )
    await expect_no_valid(tb.sink, clk=dut.axisClk, cycles=12)

    await tb.write(BLOWOFF_ADDR, 0)
    await cycle(dut.axisClk, 4)

    recovery = (bytes(range(0x90, 0x95)), 0x1, 0x81, 0xE1)
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source,
        payload_to_beats(
            recovery[0],
            dest=recovery[1],
            first_user=recovery[2],
            last_user=recovery[3],
        ),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")
    assert beats_to_bytes(rx_beats) == expected_batched_bytes([recovery])


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param(
            {
                "VERSION_G": 2,
                "DATA_BYTES_G": 8,
                "COMMON_CLOCK_G": True,
                "INPUT_PIPE_STAGES_G": 0,
                "OUTPUT_PIPE_STAGES_G": 1,
            },
            id="v2_8byte_common_clock",
        ),
        pytest.param(
            {
                "VERSION_G": 2,
                "DATA_BYTES_G": 8,
                "COMMON_CLOCK_G": False,
                "INPUT_PIPE_STAGES_G": 0,
                "OUTPUT_PIPE_STAGES_G": 1,
            },
            id="v2_8byte_async_axil",
        ),
    ],
)
def test_AxiStreamBatcherAxil(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreambatcheraxilwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "protocols/batcher/wrappers/AxiStreamBatcherAxilWrapper.vhd",
            ],
        },
    )
