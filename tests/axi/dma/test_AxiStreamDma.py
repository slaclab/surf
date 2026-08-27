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
# - Sweep: Keep one single-slot AXI-Lite wrapper around the integrated v1 DMA
#   block and limit the first pass to its top-level register path.
# - Stimulus: Read the default control words, then program the stable control
#   fields that do not require active DMA stream plumbing: maximum RX size,
#   online, acknowledge, and cache-control.
# - Checks: The writable bits must retain their programmed values and the
#   exported one-bit outputs must mirror the wrapper-visible status fields.
# - Timing: The bench waits several cycles after writes so the integrated
#   register path settles through the DUT instead of assuming same-cycle echo.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axiClk)

    async def reset(self):
        self.dut.axiRst.value = 1
        await self.cycle(4)
        self.dut.axiRst.value = 0
        await self.cycle(6)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axiClk, self.dut.axiRst)

    async def read_reg(self, address: int) -> int:
        return await axil_read_u32(self.axil, address)

    async def write_reg(self, address: int, value: int):
        await axil_write_u32(self.axil, address, value)


@cocotb.test()
async def top_level_register_surface_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    assert await tb.read_reg(0x00) == 0
    assert await tb.read_reg(0x18) == 0

    await tb.write_reg(0x14, 0x1234)
    await tb.write_reg(0x18, 0x3)
    await tb.write_reg(0x20, 0xA)
    await tb.cycle(4)

    assert (await tb.read_reg(0x14) & 0x00FFFFFF) == 0x1234
    assert (await tb.read_reg(0x18) & 0x3) == 0x3
    assert (await tb.read_reg(0x20) & 0xF) == 0xA
    assert int(dut.online.value) == 1
    assert int(dut.acknowledge.value) == 1


@pytest.mark.parametrize("parameters", [pytest.param({}, id="top_level_reg_surface")])
def test_AxiStreamDma(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmaipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/dma/ip_integrator/AxiStreamDmaIpIntegrator.vhd",
            ],
        },
    )
