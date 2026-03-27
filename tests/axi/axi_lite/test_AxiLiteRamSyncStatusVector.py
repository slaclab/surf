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
# - Sweep: Keep one small four-bit common-clock wrapper so the bench proves the
#   synchronized status export and RAM-backed counter visibility together.
# - Stimulus: Pulse selected `statusIn` bits, then sample `statusOut` and the
#   low counter bytes through the flattened AXI-Lite port.
# - Checks: The synchronized status vector must reflect the live inputs and the
#   per-bit counters stored behind AXI-Lite must increment for the pulsed bits.
# - Timing: The bench leaves several shared clock cycles after each pulse so
#   the synchronizer and RAM writer can settle through the DUT itself.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None

        start_lockstep_clocks(dut.wrClk, dut.axilClk, period_ns=5.0)
        dut.wrRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.statusIn.setimmediatevalue(0)
        dut.cntRstIn.setimmediatevalue(0)
        dut.rollOverEnIn.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.wrRst.value = 1
        self.dut.axilRst.value = 1
        await self.cycle(4)
        self.dut.wrRst.value = 0
        self.dut.axilRst.value = 0
        await self.cycle(8)

    def start_axil(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axilClk, self.dut.axilRst)

    async def read_reg(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")


@cocotb.test()
async def status_and_counter_visibility_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_axil()

    # Toggle two bits on different cycles so the counter writer sees distinct
    # events and the synchronized live-status output has to update as well.
    dut.statusIn.value = 0b0001
    await tb.cycle(1)
    dut.statusIn.value = 0b0010
    await tb.cycle(1)
    dut.statusIn.value = 0
    await tb.cycle(12)

    assert int(dut.statusOut.value) == 0
    assert (await tb.read_reg(0x0) & 0xFF) >= 1
    assert (await tb.read_reg(0x4) & 0xFF) >= 1


@pytest.mark.parametrize("parameters", [pytest.param({}, id="small_common_clk_status_vector")])
def test_AxiLiteRamSyncStatusVector(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiliteramsyncstatusvectoripintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/AxiLiteRamSyncStatusVectorIpIntegrator.vhd",
            ],
        },
    )
