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
# - Sweep: Keep one single-lane descriptor-engine wrapper and limit the first
#   pass to the stable AXI-Lite programming and exported status/config surface.
# - Stimulus: Program the descriptor manager over AXI-Lite, updating the cache,
#   online, acknowledge, and enable controls, then sample the exported outputs.
# - Checks: The version and geometry registers must match the wrapper, and the
#   exported cache, online, acknowledge, and pause outputs must reflect the
#   programmed control state in idle operation.
# - Timing: The bench leaves several cycles after each AXI-Lite write so the
#   DUT's own register and synchronizer paths settle before each check.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.dmaWrDescReqValid.setimmediatevalue(0)
        dut.dmaWrDescReqId.setimmediatevalue(0)
        dut.dmaWrDescReqDest.setimmediatevalue(0)
        dut.dmaWrDescRetValid.setimmediatevalue(0)
        dut.dmaWrDescRetBuffId.setimmediatevalue(0)
        dut.dmaWrDescRetFirstUser.setimmediatevalue(0)
        dut.dmaWrDescRetLastUser.setimmediatevalue(0)
        dut.dmaWrDescRetSize.setimmediatevalue(0)
        dut.dmaWrDescRetContinue.setimmediatevalue(0)
        dut.dmaWrDescRetResult.setimmediatevalue(0)
        dut.dmaWrDescRetDest.setimmediatevalue(0)
        dut.dmaWrDescRetId.setimmediatevalue(0)
        dut.dmaRdDescAck.setimmediatevalue(0)
        dut.dmaRdDescRetValid.setimmediatevalue(0)
        dut.dmaRdDescRetBuffId.setimmediatevalue(0)
        dut.dmaRdDescRetResult.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axiClk)

    async def reset(self):
        self.dut.axiRst.value = 1
        await self.cycle(4)
        self.dut.axiRst.value = 0
        await self.cycle(20)

    def start_axil(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axiClk, self.dut.axiRst)

    async def read_reg(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def write_reg(self, address: int, value: int):
        txn = await self.axil.write(address, value.to_bytes(4, "little"))
        assert txn.resp == AxiResp.OKAY

@cocotb.test()
async def programmed_descriptor_register_surface_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_axil()

    ident = await tb.read_reg(0x000)
    chan_config = await tb.read_reg(0x034)
    assert ((ident >> 16) & 0x1) == 1
    assert ((ident >> 24) & 0xFF) == 5
    assert (chan_config & 0xFF) == 1

    await tb.write_reg(0x03C, 0x00000F3C)
    await tb.write_reg(0x02C, 0x1)
    await tb.write_reg(0x030, 0x1)
    await tb.write_reg(0x000, 0x1)
    await tb.cycle(8)

    assert int(dut.online.value) == 1
    assert int(dut.acknowledge.value) == 0
    assert int(dut.axiRdCache.value) == 0x0
    assert int(dut.axiWrCache.value) == 0xF
    assert int(dut.buffGrpPause.value) == 0
    assert (await tb.read_reg(0x02C) & 0x1) == 1
    assert (await tb.read_reg(0x03C) & 0xFFF) == 0xF0C


@pytest.mark.parametrize("parameters", [pytest.param({}, id="single_lane_descriptor")])
def test_AxiStreamDmaV2Desc(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2descipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaV2DescIpIntegrator.vhd",
            ],
        },
    )
