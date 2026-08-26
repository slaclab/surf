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
# - Sweep: Keep one narrow trailer-width case with no extra pipeline stages.
# - Stimulus: Send one primary frame followed by one trailer frame.
# - Checks: The sink-visible output bytes must be the primary payload followed
#   by the trailer payload as one frame.
# - Timing: The trailer is supplied on its own stream so the DUT must toggle
#   between the two input channels before asserting the final `tLast`.

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
        self.trailer = None
        self.sink = None

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
        if self.trailer is None:
            self.trailer = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_TRAILER_AXIS"), self.dut.axisClk, self.dut.axisRst)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)


@cocotb.test()
async def primary_plus_trailer_frame_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    send_main = cocotb.start_soon(tb.source.send(AxiStreamFrame(b"\x10\x11\x12\x13")))
    await tb.trailer.send(AxiStreamFrame(b"\xAA\xBB"))
    await send_main

    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == b"\x10\x11\x12\x13\xAA\xBB"


@pytest.mark.parametrize("parameters", [pytest.param({}, id="append_two_byte_trailer")])
def test_AxiStreamTrailerAppend(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamtrailerappendipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
