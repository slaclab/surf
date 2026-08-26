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
# - Sweep: Keep a single two-lane wrapper-focused case so the bench proves the
#   stable split path and sequence-header insertion without replaying the
#   broader legacy parameter sweep.
# - Stimulus: Send two wide input frames through the splitter and receive one
#   frame from each narrow output lane for each input frame.
# - Checks: Each output lane must prepend the expected `0x55/seq` header beat,
#   the payload bytes must be de-interleaved into the correct lane order, and
#   the sequence number must increment between successive input frames.
# - Timing: The bench drains both output sinks for every input frame so the
#   sequence counter is checked against accepted traffic, not queued source
#   intent alone.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())

        dut.axisRst.setimmediatevalue(1)

        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "S_AXIS"), dut.axisClk, dut.axisRst)
        self.sink0 = AxiStreamSink(AxiStreamBus.from_prefix(dut, "M0_AXIS"), dut.axisClk, dut.axisRst)
        self.sink1 = AxiStreamSink(AxiStreamBus.from_prefix(dut, "M1_AXIS"), dut.axisClk, dut.axisRst)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axisRst.value = 0
        await self.cycle(3)


@cocotb.test()
async def split_and_sequence_test(dut):
    tb = TB(dut)
    await tb.reset()

    first = AxiStreamFrame(b"\x10\x20\x11\x21")
    second = AxiStreamFrame(b"\x30\x40\x31\x41")
    first.tdest = second.tdest = 0x5A
    first.tid = second.tid = 0x11

    await tb.source.send(first)
    lane0_first = await tb.sink0.recv()
    lane1_first = await tb.sink1.recv()
    assert lane0_first.tdata == b"\x00\x55\x10\x11"
    assert lane1_first.tdata == b"\x00\x55\x20\x21"

    await tb.source.send(second)
    lane0_second = await tb.sink0.recv()
    lane1_second = await tb.sink1.recv()
    assert lane0_second.tdata == b"\x01\x55\x30\x31"
    assert lane1_second.tdata == b"\x01\x55\x40\x41"


@pytest.mark.parametrize("parameters", [pytest.param({}, id="two_lane_default")])
def test_AxiStreamSplitter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamsplitteripintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
