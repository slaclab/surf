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
# - Sweep: Keep a single-channel register-path wrapper around the integrated DMA
#   block so the bench can validate the descriptor-manager configuration surface
#   without driving the currently open read-engine data path.
# - Stimulus: Read the default identification registers, then program `online`,
#   `acknowledge`, `intEnable`, and `enable` through AXI-Lite.
# - Checks: The version fields must match the embedded descriptor manager, the
#   exported one-bit status outputs must mirror the written register values, and
#   the buffer-group pause vector must stay clear in the idle state.
# - Timing: The bench leaves several real clock cycles after each write so the
#   integrated register path and status exports settle through the DUT itself.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axiRst.value = 1
        await self.cycle(4)
        self.dut.axiRst.value = 0
        await self.cycle(6)

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
async def integrated_descriptor_register_path_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_axil()

    ident = await tb.read_reg(0x000)
    chan_config = await tb.read_reg(0x034)

    assert ((ident >> 16) & 0x1) == 1
    assert ((ident >> 24) & 0xFF) == 5
    assert (chan_config & 0xFF) == 1

    await tb.write_reg(0x02C, 0x1)
    await tb.write_reg(0x030, 0x1)
    await tb.write_reg(0x004, 0x1)
    await tb.write_reg(0x000, 0x1)
    await tb.cycle(6)

    assert int(dut.online.value) == 1
    assert int(dut.acknowledge.value) == 0
    assert int(dut.interrupt.value) == 0
    assert int(dut.buffGrpPause.value) == 0
    assert (await tb.read_reg(0x02C) & 0x1) == 1
    assert (await tb.read_reg(0x004) & 0x1) == 1


@pytest.mark.parametrize("parameters", [pytest.param({}, id="single_channel_reg_path")])
def test_AxiStreamDmaV2(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2ipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/dma/ip_integrator/AxiStreamDmaV2IpIntegrator.vhd",
            ],
        },
    )
