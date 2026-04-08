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
# - Sweep: Keep one same-width wrapper case with super-frame termination after
#   two sub-frames.
# - Stimulus: Send two short input frames back-to-back and let the concat block
#   merge them into one super-frame.
# - Checks: The sink-visible output bytes must be the concatenation of both
#   payloads, and the DUT must return to the idle state after the merged frame.
# - Timing: The threshold inputs are driven explicitly so the super-frame end
#   comes from the DUT's own sub-frame accounting rather than a trivial flush.

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
        dut.forceTerm.setimmediatevalue(0)
        dut.superFrameByteThreshold.setimmediatevalue(0)
        dut.maxSubFrames.setimmediatevalue(2)
        dut.maxClkGap.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axisRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.axisClk, self.dut.axisRst)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)


@cocotb.test()
async def two_subframes_merge_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await tb.source.send(AxiStreamFrame(b"\x10\x11\x12\x13"))
    await tb.source.send(AxiStreamFrame(b"\x20\x21\x22\x23"))
    rx_frame = await tb.sink.recv()

    assert rx_frame.tdata == b"\x10\x11\x12\x13\x20\x21\x22\x23"
    await tb.cycle(2)
    assert int(tb.dut.idle.value) == 1


@pytest.mark.parametrize("parameters", [pytest.param({}, id="two_subframe_merge")])
def test_AxiStreamConcat(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamconcatipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/axi-stream/ip_integrator/AxiStreamConcatIpIntegrator.vhd"],
        },
    )
