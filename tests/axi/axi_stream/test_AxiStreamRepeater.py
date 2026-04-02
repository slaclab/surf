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
# - Sweep: Keep one two-output case with ID overwrite enabled.
# - Stimulus: Send two short frames through the single input.
# - Checks: Both outputs must receive identical payloads, and the overwritten
#   `tid` must increment between the first and second frame.
# - Timing: The sinks run independently so the repeater has to hold data until
#   both outputs can accept the mirrored beat.

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
        self.sink0 = None
        self.sink1 = None

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())
        dut.axisRst.setimmediatevalue(1)

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
        if self.sink0 is None:
            self.sink0 = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M0_AXIS"), self.dut.axisClk, self.dut.axisRst)
        if self.sink1 is None:
            self.sink1 = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M1_AXIS"), self.dut.axisClk, self.dut.axisRst)


@cocotb.test()
async def mirrored_outputs_and_incrementing_tid_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await tb.source.send(AxiStreamFrame(b"\x10\x11\x12\x13"))
    await tb.source.send(AxiStreamFrame(b"\x20\x21\x22\x23"))

    rx00 = await tb.sink0.recv()
    rx01 = await tb.sink1.recv()
    rx10 = await tb.sink0.recv()
    rx11 = await tb.sink1.recv()

    assert rx00.tdata == rx01.tdata == b"\x10\x11\x12\x13"
    assert rx10.tdata == rx11.tdata == b"\x20\x21\x22\x23"
    assert rx00.tid == rx01.tid == 0
    assert rx10.tid == rx11.tid == 1


@pytest.mark.parametrize("parameters", [pytest.param({"INCR_AXIS_ID_G": "true"}, id="increment_id")])
def test_AxiStreamRepeater(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamrepeateripintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/axi-stream/ip_integrator/AxiStreamRepeaterIpIntegrator.vhd"],
        },
    )
