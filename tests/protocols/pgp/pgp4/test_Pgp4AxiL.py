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
# - Sweep: Keep one single-VC common-clock register wrapper with the default
#   writable monitor surface enabled.
# - Stimulus: Read the capability register, then write the control register
#   fields that drive TX disable, flow-control disable, loopback, and resets.
# - Checks: Readback must match the written values and the wrapper-exported
#   control outputs must reflect the programmed register state.
# - Timing: The bench leaves several AXI-Lite clock cycles after reset and each
#   transaction so the synchronized register outputs settle cleanly.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        cocotb.start_soon(Clock(dut.S_AXI_ACLK, 5.0, unit="ns").start())

    async def cycle(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.S_AXI_ACLK)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.S_AXI_ARESETN.setimmediatevalue(0)
        await self.cycle(4)
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
async def pgp4_axil_register_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    capabilities = await axil_read_u32(tb.axil, 0x004)
    assert (capabilities & 0x1) == 0x1
    assert ((capabilities >> 8) & 0xFF) == 1

    await axil_write_u32(tb.axil, 0x008, 0x13579BDF)
    assert await axil_read_u32(tb.axil, 0x008) == 0x13579BDF

    await axil_write_u32(tb.axil, 0x00C, 0x7D)
    await tb.cycle(4)

    assert int(dut.txDisableOut.value) == 1
    assert int(dut.flowCntlDisOut.value) == 1
    assert int(dut.resetTxOut.value) == 1
    assert int(dut.resetRxOut.value) == 1
    assert int(dut.loopbackOut.value) == 0b101


PARAMETER_SWEEP = [parameter_case("single_vc_common_clock_axil")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4AxiL(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4axildirectwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4AxiLDirectWrapper.vhd",
        extra_env=parameters,
    )
