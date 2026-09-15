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
# - Sweep: Keep a three-case wrapper-focused sweep covering equal-width
#   pass-through, 2-byte to 4-byte upsize, and 4-byte to 2-byte downsize with
#   a staged asynchronous active-low reset case so the bench proves the stable
#   resize paths without replaying the broad legacy PRBS matrix.
# - Stimulus: Drive short and long AXI Stream frames with distinct `tid`,
#   `tdest`, and sideband values, stall the sink while a resized beat is
#   buffered, and assert reset after the staged path has visible state.
# - Checks: The received byte stream and metadata must match the source frame,
#   sideband values must stay aligned with the accepted output beats, and reset
#   must flush buffered output state in the staged resized cases.
# - Timing: Equal-width cases are checked as direct pass-through, resized cases
#   are checked with bounded waits under `PIPE_STAGES_G`, and reset is checked
#   as a bounded flush of the staged output path rather than an open-ended
#   drain.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import env_flag, env_sl, parameter_case, run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.slave_bytes = int(os.environ["SLAVE_DATA_BYTES_G"])
        self.master_bytes = int(os.environ["MASTER_DATA_BYTES_G"])
        self.side_band_width = int(os.environ["SIDE_BAND_WIDTH_G"])
        self.pipe_stages = int(os.environ["PIPE_STAGES_G"])
        self.reset_async = env_flag("RST_ASYNC_G", default=False)
        self.reset_active = env_sl("RST_POLARITY_G", default=1)
        self.source = None
        self.sink = None
        self.rx_sidebands = []

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())

        dut.axisRst.setimmediatevalue(self.reset_active_value())
        dut.S_AXIS_TVALID.setimmediatevalue(0)
        dut.S_AXIS_TDATA.setimmediatevalue(0)
        dut.S_AXIS_TKEEP.setimmediatevalue(0)
        dut.S_AXIS_TLAST.setimmediatevalue(0)
        dut.S_AXIS_TDEST.setimmediatevalue(0)
        dut.S_AXIS_TID.setimmediatevalue(0)
        dut.S_SIDE_BAND.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(0)

        # Lifetime monitor retained by the bench until cocotb ends the test.
        self._monitor_task = cocotb.start_soon(self._monitor_sideband())

    def reset_active_value(self) -> int:
        return self.reset_active

    def reset_inactive_value(self) -> int:
        return 1 - self.reset_active

    async def settle(self):
        await Timer(1, unit="ns")

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await self.settle()

    async def _monitor_sideband(self):
        """Lifetime agent: collect resized sidebands until the test ends."""
        while True:
            await RisingEdge(self.dut.axisClk)
            await self.settle()
            if int(self.dut.M_AXIS_TVALID.value) and int(self.dut.M_AXIS_TREADY.value):
                self.rx_sidebands.append(int(self.dut.M_SIDE_BAND.value))

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(self.reset_active_value())
        self.dut.M_AXIS_TREADY.value = 0
        self.dut.S_SIDE_BAND.value = 0
        await self.cycle(2)
        self.dut.axisRst.value = self.reset_active_value()
        await self.cycle(2)
        self.dut.axisRst.value = self.reset_inactive_value()
        await self.cycle(2)

    def start_agents(self):
        if self.source is None:
            self.source = AxiStreamSource(
                bus=AxiStreamBus.from_prefix(self.dut, "S_AXIS"),
                clock=self.dut.axisClk,
                reset=self.dut.axisRst,
                reset_active_level=bool(self.reset_active),
            )
        if self.sink is None:
            self.sink = AxiStreamSink(
                bus=AxiStreamBus.from_prefix(self.dut, "M_AXIS"),
                clock=self.dut.axisClk,
                reset=self.dut.axisRst,
                reset_active_level=bool(self.reset_active),
            )

    def output_snapshot(self):
        return (
            int(self.dut.M_AXIS_TVALID.value),
            int(self.dut.M_AXIS_TDATA.value),
            int(self.dut.M_AXIS_TKEEP.value),
            int(self.dut.M_AXIS_TLAST.value),
            int(self.dut.M_AXIS_TDEST.value),
            int(self.dut.M_AXIS_TID.value),
            int(self.dut.M_SIDE_BAND.value),
        )

    async def wait_for_output_valid(self, timeout_cycles=16):
        for _ in range(timeout_cycles):
            await self.settle()
            if int(self.dut.M_AXIS_TVALID.value):
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for resize output valid")

    async def wait_for_output_clear(self, timeout_cycles=16):
        for _ in range(timeout_cycles):
            await self.settle()
            if int(self.dut.M_AXIS_TVALID.value) == 0:
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for resize output clear")


@cocotb.test()
async def frame_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    frames = [
        (AxiStreamFrame(b"\x11"), 0x1),
        (AxiStreamFrame(bytes(range(1, tb.slave_bytes + 2))), 0x2),
        (AxiStreamFrame(bytes((0x80 + i) & 0xFF for i in range((2 * max(tb.slave_bytes, tb.master_bytes)) + 1))), (1 << tb.side_band_width) - 1),
    ]

    expected_sidebands = []
    for index, (frame, sideband) in enumerate(frames, start=1):
        frame.tid = index
        frame.tdest = 0x40 + index
        dut.S_SIDE_BAND.value = sideband
        await tb.source.send(frame)
        rx_frame = await tb.sink.recv()
        assert rx_frame.tdata == frame.tdata
        assert rx_frame.tid == frame.tid
        assert rx_frame.tdest == frame.tdest
        beats = (len(frame.tdata) + tb.master_bytes - 1) // tb.master_bytes
        expected_sidebands.extend([sideband] * max(1, beats))

    await tb.cycle(1)
    assert tb.rx_sidebands == expected_sidebands
    assert tb.sink.empty()


@cocotb.test()
async def backpressure_and_reset_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    frame = AxiStreamFrame(bytes((0x30 + i) & 0xFF for i in range(max(tb.slave_bytes, tb.master_bytes) + 1)))
    frame.tid = 0x12
    frame.tdest = 0x34
    dut.S_SIDE_BAND.value = max(1, (1 << tb.side_band_width) - 1)
    tb.dut.M_AXIS_TREADY.value = 0

    send_task = cocotb.start_soon(tb.source.send(frame))
    await tb.wait_for_output_valid(timeout_cycles=tb.pipe_stages + 12)

    if tb.slave_bytes == tb.master_bytes and tb.pipe_stages == 0:
        tb.dut.M_AXIS_TREADY.value = 1
        await send_task
        await tb.wait_for_output_clear(timeout_cycles=4)
    else:
        await send_task
        tb.dut.axisRst.value = tb.reset_active_value()
        await tb.wait_for_output_clear(timeout_cycles=tb.pipe_stages + 8)
        assert int(tb.dut.M_AXIS_TVALID.value) == 0
        assert int(tb.dut.M_SIDE_BAND.value) == 0

        tb.dut.axisRst.value = tb.reset_inactive_value()
        tb.dut.M_AXIS_TREADY.value = 1
        await tb.cycle(2)


PARAMETER_SWEEP = [
    parameter_case(
        "equal_width_sync",
        SLAVE_DATA_BYTES_G="4",
        MASTER_DATA_BYTES_G="4",
        SIDE_BAND_WIDTH_G="3",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "upsize_sync",
        SLAVE_DATA_BYTES_G="2",
        MASTER_DATA_BYTES_G="4",
        SIDE_BAND_WIDTH_G="2",
        PIPE_STAGES_G="1",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "downsize_async_active_low",
        SLAVE_DATA_BYTES_G="4",
        MASTER_DATA_BYTES_G="2",
        SIDE_BAND_WIDTH_G="2",
        PIPE_STAGES_G="1",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiStreamResize(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamresizeipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
