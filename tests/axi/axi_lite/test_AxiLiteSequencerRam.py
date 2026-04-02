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
# - Sweep: Keep one small inferred-RAM case with two programmed transactions.
# - Stimulus: Load one sequenced write command and one sequenced read command
#   through the slave-side AXI-Lite port, then start execution and let a
#   downstream AXI-Lite RAM service the requests.
# - Checks: The downstream target memory must see the write, the sequencer RAM
#   entry for the read transaction must be updated with the returned data, and
#   the completion/debug word at address zero must report the non-waiting done
#   marker.
# - Timing: The bench starts the sequence through the public register map and
#   then polls completion through that same map so the internal RAM latency and
#   `AxiLiteMaster` handshake both stay on the exercised path.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiLiteRam

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        self.ram = None

        cocotb.start_soon(Clock(dut.axilClk, 5.0, unit="ns").start())
        dut.axilRst.setimmediatevalue(1)
        dut.extStart.setimmediatevalue(0)
        dut.extSize.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axilRst.setimmediatevalue(1)
        self.dut.extStart.value = 0
        self.dut.extSize.value = 0
        await self.cycle(3)
        self.dut.axilRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axilClk, self.dut.axilRst)
        if self.ram is None:
            self.ram = AxiLiteRam(AxiLiteBus.from_prefix(self.dut, "M_AXI"), self.dut.axilClk, self.dut.axilRst, size=2**16)

    async def wait_done_marker(self):
        for _ in range(80):
            if await self.axil.read_dword(0x00) == 0xFFFFFFFF:
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for sequencer done marker")


@cocotb.test()
async def programmed_write_then_read_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await tb.axil.write_dword(0x08, 0xDEADBEEF)
    await tb.axil.write_dword(0x0C, 0x00000020)
    await tb.axil.write_dword(0x10, 0x00000000)
    await tb.axil.write_dword(0x14, 0x00000021)
    await tb.axil.write_dword(0x00, 0x00000002)

    await tb.wait_done_marker()

    assert tb.ram.read(0x20, 4) == b"\xEF\xBE\xAD\xDE"
    assert await tb.axil.read_dword(0x10) == 0xDEADBEEF
    assert await tb.axil.read_dword(0x14) == 0x00000021


@pytest.mark.parametrize("parameters", [pytest.param({}, id="two_step_inferred_ram")])
def test_AxiLiteSequencerRam(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitesequencerramipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/MasterAxiLiteIpIntegrator.vhd",
                "axi/axi-lite/ip_integrator/AxiLiteSequencerRamIpIntegrator.vhd",
            ],
        },
    )
