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
# - Sweep: Keep one common-clock case with a short refresh interval so the
#   frame counter can be observed in a small bounded simulation.
# - Stimulus: Rely on the wrapper's default short refresh interval and default
#   `rateLimit=2`, send three frames in one refresh window, wait for the
#   counter reset interval, then send a fourth.
# - Checks: The first two frames must pass, the third frame must be dropped
#   when backpressure mode is disabled, and the fourth frame must pass after
#   the timer rolls over.
# - Timing: The test relies on the DUT's own refresh timer instead of manually
#   forcing downstream pause, so the counter reset logic is exercised.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = None
        self.sink = None

        start_lockstep_clocks(dut.axisClk, dut.axilClk, period_ns=5.0)
        dut.axisRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.M_AXIS_PAUSE.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(1)
        self.dut.axilRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axisRst.value = 0
        self.dut.axilRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.axisClk, self.dut.axisRst)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)


@cocotb.test()
async def one_frame_per_refresh_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await tb.source.send(AxiStreamFrame(b"\x11\x12\x13\x14"))
    await tb.source.send(AxiStreamFrame(b"\x21\x22\x23\x24"))
    await tb.source.send(AxiStreamFrame(b"\x31\x32\x33\x34"))
    rx0 = await tb.sink.recv()
    rx1 = await tb.sink.recv()
    assert rx0.tdata == b"\x11\x12\x13\x14"
    assert rx1.tdata == b"\x21\x22\x23\x24"

    await tb.cycle(12)
    await tb.source.send(AxiStreamFrame(b"\x41\x42\x43\x44"))
    rx2 = await tb.sink.recv()
    assert rx2.tdata == b"\x41\x42\x43\x44"
    assert tb.sink.empty()


@pytest.mark.parametrize("parameters", [pytest.param({}, id="common_clk_short_refresh")])
def test_AxiStreamFrameRateLimiter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamframeratelimiteripintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
