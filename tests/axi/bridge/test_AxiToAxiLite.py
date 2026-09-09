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
# - Sweep: Keep one 64-bit AXI to 32-bit AXI-Lite wrapper case because the
#   bridge logic itself is fixed-width and the key behavior is data mapping.
# - Stimulus: Issue aligned 32-bit writes on both halves of the 64-bit AXI
#   data bus, then read back eight bytes over AXI from the same addresses.
# - Checks: The downstream AXI-Lite RAM must store the selected 32-bit word,
#   each AXI read must return the AXI-Lite data replicated across both 32-bit
#   lanes, and the AXI write/read responses must complete successfully.
# - Timing: The bench runs write then read handshakes through the real bridge
#   so ID capture and replicated read data are checked on accepted transfers.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiBus, AxiLiteBus, AxiLiteRam, AxiMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())

        dut.axiRst.setimmediatevalue(1)
        self.axi = None
        self.axil_ram = None

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axiClk)

    async def reset(self):
        # Hold reset across the bridge and both shim layers before issuing the
        # first AXI request so captured IDs and replicated read data start clean.
        self.dut.axiRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.axi is None:
            self.axi = AxiMaster(AxiBus.from_prefix(self.dut, "S_AXI"), self.dut.axiClk, self.dut.axiRst)
        if self.axil_ram is None:
            self.axil_ram = AxiLiteRam(AxiLiteBus.from_prefix(self.dut, "M_AXIL"), self.dut.axiClk, self.dut.axiRst, size=2**16)


@cocotb.test()
async def low_and_high_lane_mapping_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    low_resp = await tb.axi.write(0x0020, b"\x11\x22\x33\x44", awid=0x5)
    high_resp = await tb.axi.write(0x0024, b"\xAA\xBB\xCC\xDD", awid=0x6)

    low_read = await tb.axi.read(0x0020, 8, arid=0x9)
    high_read = await tb.axi.read(0x0024, 4, arid=0xA)

    assert low_resp.resp == AxiResp.OKAY
    assert high_resp.resp == AxiResp.OKAY
    assert tb.axil_ram.read(0x0020, 4) == b"\x11\x22\x33\x44"
    assert tb.axil_ram.read(0x0024, 4) == b"\xAA\xBB\xCC\xDD"
    assert bytes(low_read) == b"\x11\x22\x33\x44" * 2
    assert bytes(high_read) == b"\xAA\xBB\xCC\xDD"
    assert low_read.resp == AxiResp.OKAY
    assert high_read.resp == AxiResp.OKAY


@pytest.mark.parametrize("parameters", [pytest.param({}, id="axi64_to_axil32")])
def test_AxiToAxiLite(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axitoaxiliteipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd",
                "axi/bridge/ip_integrator/AxiToAxiLiteIpIntegrator.vhd",
            ],
        },
    )
