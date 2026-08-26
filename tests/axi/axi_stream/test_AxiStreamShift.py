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
# - Sweep: Keep one stable zero-shift command case on the active datapath.
# - Stimulus: Assert `axiStart`, set `axiShiftCnt=0`, and send one short frame.
# - Checks: The output frame must match the input bytes and metadata, proving
#   the shift state machine starts, drains the frame, and returns idle cleanly.
# - Timing: The transfer is started through the public control pins rather than
#   through a bypass generic, so the bench still exercises the packet gating.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = None
        self.sink = None

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())
        dut.axisRst.setimmediatevalue(1)
        dut.axiStart.setimmediatevalue(0)
        dut.axiShiftDir.setimmediatevalue(0)
        dut.axiShiftCnt.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(1)
        self.dut.axiStart.value = 0
        self.dut.axiShiftCnt.value = 0
        await self.cycle(3)
        self.dut.axisRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.axisClk, self.dut.axisRst)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)


@cocotb.test()
async def zero_shift_packet_transfer_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    frame = AxiStreamFrame(b"\x10\x11\x12\x13\x14")
    frame.tid = 0x12
    frame.tdest = 0x34
    tb.dut.axiStart.value = 1
    await tb.cycle(1)
    await tb.source.send(frame)
    tb.dut.axiStart.value = 0

    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == frame.tdata
    assert rx_frame.tid == frame.tid
    assert rx_frame.tdest == frame.tdest


@pytest.mark.parametrize("parameters", [pytest.param({}, id="zero_shift_command")])
def test_AxiStreamShift(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamshiftipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
