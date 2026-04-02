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
# - Sweep: Keep one single-slot AXI4 monitor wrapper and focus the first pass
#   on its stable AXI-Lite configuration/debug surface.
# - Stimulus: Reset the wrapper and read the reused monitor's config/debug
#   words for the write/read channel pair it exposes.
# - Checks: The configuration word must advertise a 4-byte data path and the
#   debug word must report two monitored channels for the single AXI slot.
# - Timing: The bench waits a short post-reset settling window before software
#   reads the monitor shadow RAM.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32
from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None

        start_lockstep_clocks(dut.axiClk, dut.axilClk, period_ns=5.0)
        dut.axiRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.wrValid.setimmediatevalue(0)
        dut.wrLast.setimmediatevalue(0)
        dut.wrReady.setimmediatevalue(0)
        dut.wrStrb.setimmediatevalue(0)
        dut.rdValid.setimmediatevalue(0)
        dut.rdLast.setimmediatevalue(0)
        dut.rdReady.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axiRst.value = 1
        self.dut.axilRst.value = 1
        await self.cycle(4)
        self.dut.axiRst.value = 0
        self.dut.axilRst.value = 0
        await self.cycle(6)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axilClk, self.dut.axilRst)

    async def read_reg(self, address: int) -> int:
        return await axil_read_u32(self.axil, address)


@cocotb.test()
async def config_and_debug_register_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await tb.cycle(16)

    config = await tb.read_reg(0x00)
    debug = await tb.read_reg(0x3C)

    assert (config >> 24) & 0xFF == 4
    assert config & 0x1 == 1
    assert debug & 0xFF == 2


@pytest.mark.parametrize("parameters", [pytest.param({}, id="single_slot_observed_channels")])
def test_AxiMonAxiL(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.aximonaxilipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiMonAxiLIpIntegrator.vhd",
            ],
        },
    )
