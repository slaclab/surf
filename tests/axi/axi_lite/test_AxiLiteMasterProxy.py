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
# - Sweep: Keep one synchronous wrapper case covering one proxied write and
#   one proxied read.
# - Stimulus: Program the proxy command registers over the slave-side AXI-Lite
#   port and service the forwarded transactions with a cocotb AXI-Lite RAM.
# - Checks: The master-side RAM must observe the write, the status register
#   must return `done=1` and the read data on completion, and the slave-side
#   control path must remain usable for the follow-on read command.
# - Timing: Completion is polled through the real proxy status registers so
#   the test covers the request/ack handoff to `AxiLiteMaster` instead of a
#   combinational shell.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiLiteRam, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        self.ram = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axiRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axiClk, self.dut.axiRst)
        if self.ram is None:
            self.ram = AxiLiteRam(AxiLiteBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**16)

    async def wait_done(self):
        for _ in range(40):
            status = await self.axil.read_dword(0x04)
            if status & 0x1:
                return status
            await self.cycle(1)
        raise AssertionError("Timed out waiting for proxy done bit")


@cocotb.test()
async def write_then_read_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await tb.axil.write_dword(0x08, 0x0020)
    await tb.axil.write_dword(0x0C, 0x11223344)
    await tb.axil.write_dword(0x00, 0x0)
    write_status = await tb.wait_done()
    assert (write_status >> 1) & 0x3 == AxiResp.OKAY
    assert tb.ram.read(0x0020, 4) == b"\x44\x33\x22\x11"

    tb.ram.write(0x0024, b"\xAA\xBB\xCC\xDD")
    await tb.axil.write_dword(0x08, 0x0024)
    await tb.axil.write_dword(0x00, 0x1)
    read_status = await tb.wait_done()
    assert (read_status >> 1) & 0x3 == AxiResp.OKAY
    assert await tb.axil.read_dword(0x0C) == 0xDDCCBBAA


@pytest.mark.parametrize("parameters", [pytest.param({}, id="sync_active_high")])
def test_AxiLiteMasterProxy(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitemasterproxyipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/MasterAxiLiteIpIntegrator.vhd",
                "axi/axi-lite/ip_integrator/AxiLiteMasterProxyIpIntegrator.vhd",
            ],
        },
    )
