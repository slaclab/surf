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
# - Sweep: Keep one stable common-clock wrapper and focus this bench on the
#   AXI-Lite control and status surface that is unique to the integrated FIFO.
# - Stimulus: Read the baked-in configuration registers, then program the
#   pause-threshold register through multiple values while the datapath stays
#   idle.
# - Checks: The exposed version, geometry, and count registers must match the
#   wrapper constants, the writable pause-threshold register must retain each
#   programmed value, and the idle-path status outputs must stay non-erroring.
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
        await self.cycle(16)

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
async def integrated_fifo_register_map_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_axil()

    assert (await tb.read_reg(0x00) & 0xF) == 1
    assert await tb.read_reg(0x04) == 0
    assert (await tb.read_reg(0x0C) & 0xF) == 0xF
    assert ((await tb.read_reg(0x0C) >> 8) & 0x3) == 1
    assert ((await tb.read_reg(0x10) >> 8) & 0xFF) == 8
    assert ((await tb.read_reg(0x10) >> 16) & 0xFF) == 4
    assert ((await tb.read_reg(0x10) >> 24) & 0xFF) == 16
    assert ((await tb.read_reg(0x14) >> 24) & 0xFF) == 4
    assert (await tb.read_reg(0x18) & 0xFF) == 8
    assert ((await tb.read_reg(0x18) >> 8) & 0xFF) == 12
    assert ((await tb.read_reg(0x18) >> 16) & 0xFFFF) == 16
    queue_counts = await tb.read_reg(0x1C)
    wr_buff_cnt = (queue_counts >> 16) & 0xFFFF
    assert (queue_counts & 0xFFFF) == 0
    # The integrated FIFO comes out of reset with the read queue empty and the
    # write queue preloaded close to full. The exact exposed count depends on
    # the queue's FWFT accounting and when the control plane samples it.
    assert 8 < wr_buff_cnt < 0x10
    assert await tb.read_reg(0x24) == 8


@cocotb.test()
async def pause_threshold_programming_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_axil()

    initial_status = await tb.read_reg(0x20)
    initial_pause_cnt = initial_status & 0xFFFF
    assert initial_pause_cnt >= 1
    assert ((initial_status >> 16) & 0x1) == 0

    for value, expected_pause in ((1, 0), (None, 1), (0, 0)):
        if value is None:
            queue_counts = await tb.read_reg(0x1C)
            value = (queue_counts >> 16) & 0xFFFF
        await tb.write_reg(0x24, value)
        await tb.cycle(4)
        assert await tb.read_reg(0x24) == value
        status = await tb.read_reg(0x20)
        assert ((status >> 16) & 0x1) == expected_pause
        assert int(dut.sAxisPause.value) == expected_pause

    final_status = await tb.read_reg(0x20)
    assert (final_status & 0xFFFF) >= initial_pause_cnt + 1
    assert ((final_status >> 16) & 0x1) == 0
    assert int(dut.sAxisOverflow.value) == 0
    assert int(dut.sAxisIdle.value) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="integrated_fifo_control_surface")])
def test_AxiStreamDmaV2Fifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2fifoipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaV2FifoIpIntegrator.vhd",
            ],
        },
    )
