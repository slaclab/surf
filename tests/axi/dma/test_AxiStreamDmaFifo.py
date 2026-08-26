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
# - Sweep: Keep one narrow AXI-Lite-only wrapper around the integrated v1 DMA
#   FIFO so the first pass validates its software-visible control surface.
# - Stimulus: Read the fixed configuration words, then program `online` and the
#   software cache field through AXI-Lite.
# - Checks: The configuration fields must match the wrapper constants and the
#   writable control fields must retain the new values.
# - Timing: The bench leaves several cycles after each write so the DUT's
#   internal register path, not zero-delay sampling, determines visibility.

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
async def fifo_register_surface_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    assert (await tb.read_reg(0x00) & 0xF) == 1
    assert ((await tb.read_reg(0xC0) >> 24) & 0xFF) == 4
    assert ((await tb.read_reg(0xC4) >> 16) & 0xFF) == 4

    await tb.write_reg(0x00, (1 << 4) | (0xA << 16))
    await tb.cycle(4)

    assert ((await tb.read_reg(0x00)) >> 4) & 0x1 == 1
    assert ((await tb.read_reg(0x00)) >> 16) & 0xF == 0xA


@pytest.mark.parametrize("parameters", [pytest.param({}, id="fifo_control_surface")])
def test_AxiStreamDmaFifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmafifoipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/dma/ip_integrator/AxiStreamDmaFifoIpIntegrator.vhd",
            ],
        },
    )
