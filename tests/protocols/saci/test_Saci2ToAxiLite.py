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
# - Sweep: Exercise the default single-chip SACI2 bridge window plus one bad
#   unmapped address.
# - Stimulus: Write the mapped address space, read it back, then probe an
#   invalid address.
# - Checks: Valid accesses return `OKAY` and bad accesses return an error code.
# - Timing: Transactions occur sequentially after reset and startup delay.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

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
async def saci2_to_axi_lite_window_test(dut):
    tb = TB(dut)
    await tb.reset()
    await Timer(10, unit="us")
    for offset_high in range(17):
        for offset_low in range(0, 0xF, 4):
            high = 0 if offset_high == 0 else (1 << (offset_high + 3))
            address = high | offset_low
            test_data = address.to_bytes(length=4, byteorder="little")
            write_rsp = await tb.axil_master.write(address, test_data)
            assert write_rsp.resp == AxiResp.OKAY
            read_rsp = await tb.axil_master.read(address, 4)
            assert read_rsp.resp == AxiResp.OKAY
            assert read_rsp.data == test_data

    bad_address = 0x0010_0000
    bad_data = (0xFFFF_FFFF).to_bytes(length=4, byteorder="little")
    write_rsp = await tb.axil_master.write(bad_address, bad_data)
    assert write_rsp.resp != AxiResp.OKAY
    read_rsp = await tb.axil_master.read(bad_address, 4)
    assert read_rsp.resp != AxiResp.OKAY


PARAMETER_SWEEP = [pytest.param({}, id="default_configuration")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Saci2ToAxiLite(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.saci2toaxilitewrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/saci/saci2/wrappers/Saci2ToAxiLiteWrapper.vhd"]},
    )

