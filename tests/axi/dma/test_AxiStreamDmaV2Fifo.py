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
# - Sweep: Keep one stable common-clock wrapper instance and limit the first
#   pass to the AXI-Lite control/status surface while the integrated read path
#   remains coupled to the separate open `AxiStreamDmaV2Read` issue.
# - Stimulus: Read the baked-in configuration registers, update the pause
#   threshold register, and sample the exported stream-control flags while idle.
# - Checks: The exposed version/config words must match the wrapper constants,
#   the writable pause-threshold register must retain the programmed value, and
#   the idle-path status outputs must stay non-erroring.
# - Timing: The bench leaves several clock cycles after each AXI-Lite access so
#   the DUT settles through its own register and synchronizer paths.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None

        start_lockstep_clocks(dut.axiClk, dut.axilClk, period_ns=5.0)
        dut.axiRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.axiReady.setimmediatevalue(1)
        dut.M_AXIS_TREADY.setimmediatevalue(1)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axiRst.value = 1
        self.dut.axilRst.value = 1
        self.dut.axiReady.value = 1
        await self.cycle(6)
        self.dut.axiRst.value = 0
        self.dut.axilRst.value = 0
        await self.cycle(12)

    def start_axil(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axilClk, self.dut.axilRst)

    async def read_reg(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def write_reg(self, address: int, value: int):
        txn = await self.axil.write(address, value.to_bytes(4, "little"))
        assert txn.resp == AxiResp.OKAY


@cocotb.test()
async def idle_register_surface_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_axil()

    assert (await tb.read_reg(0x00) & 0xF) == 1
    assert ((await tb.read_reg(0x10) >> 8) & 0xFF) == 8
    assert ((await tb.read_reg(0x10) >> 16) & 0xFF) == 4
    assert ((await tb.read_reg(0x10) >> 24) & 0xFF) == 16
    assert await tb.read_reg(0x24) == 8

    await tb.write_reg(0x24, 1)
    await tb.cycle(4)

    assert await tb.read_reg(0x24) == 1
    assert int(dut.sAxisPause.value) == 0
    assert int(dut.sAxisOverflow.value) == 0
    assert int(dut.sAxisIdle.value) == 0
    assert ((await tb.read_reg(0x20) >> 16) & 0x1) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="idle_control_surface")])
def test_AxiStreamDmaV2Fifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2fifoipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/SlaveAxiStreamIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/MasterAxiStreamIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaV2FifoIpIntegrator.vhd",
            ],
        },
    )
