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
# - Sweep: Keep a two-lane simulation-enabled register wrapper so the bench can
#   exercise per-lane config and status counter visibility together.
# - Stimulus: Program polarity, bit-order, and user-delay registers over the
#   flattened AXI-Lite port, then pulse error and bit-slip status inputs.
# - Checks: Register readback and exported configuration outputs must match the
#   programmed values, and the status counters must increment for pulsed bits.
# - Timing: The bench waits several shared clock cycles after reset and after
#   each pulse so the AXI-Lite async bridge and status counters can settle.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import parameter_case, start_lockstep_clocks
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        start_lockstep_clocks(dut.deserClk, dut.S_AXI_ACLK, period_ns=5.0)
        dut.deserRst.setimmediatevalue(1)
        dut.S_AXI_ARESETN.setimmediatevalue(0)
        dut.errorDet.setimmediatevalue(0)
        dut.bitSlip.setimmediatevalue(0)
        dut.locked.setimmediatevalue(0b11)

    async def cycle(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.S_AXI_ACLK)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.deserRst.value = 1
        self.dut.S_AXI_ARESETN.value = 0
        await self.cycle(4)
        self.dut.deserRst.value = 0
        self.dut.S_AXI_ARESETN.value = 1
        await self.cycle(8)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(
                AxiLiteBus.from_prefix(self.dut, "S_AXI"),
                self.dut.S_AXI_ACLK,
                self.dut.S_AXI_ARESETN,
                reset_active_level=False,
            )


@cocotb.test()
async def low_speed_reg_visibility_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await axil_write_u32(tb.axil, 0x800, 1)
    await axil_write_u32(tb.axil, 0x814, 0b10)
    await axil_write_u32(tb.axil, 0x818, 0b01)
    await axil_write_u32(tb.axil, 0x500, 0x12)
    await axil_write_u32(tb.axil, 0x504, 0x34)
    await tb.cycle(4)

    assert int(dut.enUsrDlyCfgOut.value) == 1
    assert int(dut.polarityOut.value) == 0b10
    assert int(dut.bitOrderOut.value) == 0b01
    assert int(dut.lane0UsrDlyCfg.value) == 0x12
    assert int(dut.lane1UsrDlyCfg.value) == 0x34

    dut.errorDet.value = 0b01
    await tb.cycle(1)
    dut.errorDet.value = 0
    dut.bitSlip.value = 0b10
    await tb.cycle(1)
    dut.bitSlip.value = 0
    await tb.cycle(12)

    assert (await axil_read_u32(tb.axil, 0x10) & 0xFF) >= 1
    assert (await axil_read_u32(tb.axil, 0x0C) & 0xFF) >= 1


PARAMETER_SWEEP = [parameter_case("two_lane_simulation_reg_block")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4RxLiteLowSpeedReg(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4rxlitelowspeedregwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4RxLiteLowSpeedRegWrapper.vhd",
        extra_env=parameters,
    )
