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
# - Sweep: Keep one two-stream, two-event timer case.
# - Stimulus: Start the timer over AXI-Lite, then generate two short frames on
#   each monitored stream with deterministic timing.
# - Checks: The exported timestamp registers must report the configured stream
#   and event counts plus nonzero SOF/EOF samples in the expected slots.
# - Timing: Shared lockstep clocks keep the AXI-Lite CDC stable while still
#   exercising the async bridge inside the DUT.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None

        start_lockstep_clocks(dut.axisClk, dut.axilClk, period_ns=5.0)
        dut.axisRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.S0_AXIS_TVALID.setimmediatevalue(0)
        dut.S0_AXIS_TDATA.setimmediatevalue(0)
        dut.S0_AXIS_TKEEP.setimmediatevalue(0xF)
        dut.S0_AXIS_TLAST.setimmediatevalue(0)
        dut.S0_AXIS_TREADY.setimmediatevalue(1)
        dut.S1_AXIS_TVALID.setimmediatevalue(0)
        dut.S1_AXIS_TDATA.setimmediatevalue(0)
        dut.S1_AXIS_TKEEP.setimmediatevalue(0xF)
        dut.S1_AXIS_TLAST.setimmediatevalue(0)
        dut.S1_AXIS_TREADY.setimmediatevalue(1)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(1)
        self.dut.axilRst.setimmediatevalue(1)
        await self.cycle(4)
        self.dut.axisRst.value = 0
        self.dut.axilRst.value = 0
        await self.cycle(4)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axilClk, self.dut.axilRst)

    async def send_single_beat(self, prefix: str, data: int):
        getattr(self.dut, f"{prefix}_TVALID").value = 1
        getattr(self.dut, f"{prefix}_TDATA").value = data
        getattr(self.dut, f"{prefix}_TLAST").value = 1
        await self.cycle(1)
        getattr(self.dut, f"{prefix}_TVALID").value = 0
        getattr(self.dut, f"{prefix}_TLAST").value = 0


@cocotb.test()
async def timer_register_capture_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await tb.axil.write_dword(0x0, 1)
    await tb.cycle(2)
    await tb.send_single_beat("S0_AXIS", 0x11)
    await tb.cycle(2)
    await tb.send_single_beat("S1_AXIS", 0x22)
    await tb.cycle(2)
    await tb.send_single_beat("S0_AXIS", 0x33)
    await tb.cycle(2)
    await tb.send_single_beat("S1_AXIS", 0x44)
    await tb.cycle(4)

    assert await tb.axil.read_dword(0x4) == 2
    assert await tb.axil.read_dword(0x8) == 2
    assert await tb.axil.read_dword(0xC) > 0
    assert await tb.axil.read_dword(0x10) > 0
    assert await tb.axil.read_dword(0x14) > 0
    assert await tb.axil.read_dword(0x18) > 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="two_stream_two_event")])
def test_AxiStreamTimer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamtimeripintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/axi-stream/ip_integrator/AxiStreamTimerIpIntegrator.vhd"],
        },
    )
