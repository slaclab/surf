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
# - Sweep: Keep one 32-bit tap configuration with a single tapped destination.
# - Stimulus: Send one tapped frame and one pass-through frame, then inject one
#   replacement frame back through the tap input.
# - Checks: The tapped destination must appear on the tap output, the other
#   destination must continue to the main output, and the injected frame must
#   reappear on the main output stream.
# - Timing: The test uses the real de-mux/mux pair so both extraction and
#   reinsertion path handshakes are exercised.

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
        self.tap_source = None
        self.main_sink = None
        self.tap_sink = None

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
        if self.tap_source is None:
            self.tap_source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "TS_AXIS"), self.dut.axisClk, self.dut.axisRst)
        if self.main_sink is None:
            self.main_sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)
        if self.tap_sink is None:
            self.tap_sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "TM_AXIS"), self.dut.axisClk, self.dut.axisRst)


@cocotb.test()
async def tap_extract_and_reinsert_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    tapped = AxiStreamFrame(b"\x01\x02\x03\x04")
    tapped.tdest = 5
    normal = AxiStreamFrame(b"\x10\x11\x12\x13")
    normal.tdest = 1
    inserted = AxiStreamFrame(b"\xAA\xBB\xCC\xDD")
    inserted.tdest = 5

    await tb.source.send(tapped)
    await tb.source.send(normal)
    await tb.tap_source.send(inserted)

    rx_tap = await tb.tap_sink.recv()
    rx_main_0 = await tb.main_sink.recv()
    rx_main_1 = await tb.main_sink.recv()

    assert rx_tap.tdata == tapped.tdata
    assert rx_tap.tdest == 5
    assert rx_main_0.tdata == inserted.tdata
    assert rx_main_0.tdest == 5
    assert rx_main_1.tdata == normal.tdata
    assert rx_main_1.tdest == 1


@pytest.mark.parametrize("parameters", [pytest.param({}, id="tap_dest_5")])
def test_AxiStreamTap(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamtapipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/axi-stream/ip_integrator/AxiStreamTapIpIntegrator.vhd"],
        },
    )
