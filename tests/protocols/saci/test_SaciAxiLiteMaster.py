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
# - Sweep: Exercise the default single-chip SACI bridge window.
# - Stimulus: After reset, issue AXI-Lite writes and reads across the legacy
#   swept address set.
# - Checks: Readback data must match the value written at each address.
# - Timing: Transactions wait for normal AXI-Lite completion and follow reset.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.S_AXI_ACLK, 8.0, unit="ns").start())
        self.axil_master = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
            clock=dut.S_AXI_ACLK,
            reset=dut.S_AXI_ARESETN,
            reset_active_level=False,
        )

    async def reset(self):
        self.dut.S_AXI_ARESETN.setimmediatevalue(0)
        for _ in range(2):
            await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 0
        for _ in range(2):
            await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 1
        for _ in range(2):
            await RisingEdge(self.dut.S_AXI_ACLK)


@cocotb.test()
async def saci_axi_lite_master_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()
    await Timer(10, unit="us")
    for offset_high in range(17):
        for offset_low in range(0, 0xF, 4):
            high = 0 if offset_high == 0 else (1 << (offset_high + 3))
            address = high | offset_low
            test_data = address.to_bytes(length=4, byteorder="little")
            write_event = tb.axil_master.init_write(address, test_data)
            await write_event.wait()
            read_event = tb.axil_master.init_read(address, 4)
            await read_event.wait()
            assert read_event.data.data == test_data


PARAMETER_SWEEP = [pytest.param({}, id="default_configuration")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SaciAxiLiteMaster(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.saciaxilitemasterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/saci/saci1/wrappers/SaciAxiLiteMasterWrapper.vhd"]},
    )
