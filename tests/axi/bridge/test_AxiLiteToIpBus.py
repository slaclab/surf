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
# - Sweep: Keep one 32-bit AXI-Lite case.
# - Stimulus: Issue one aligned write, one aligned read, and one misaligned
#   read while a tiny IPBus model responds after a short delay.
# - Checks: The bridge must convert byte addresses to word addresses, assert
#   the proper write flag, return the IPBus read data, and surface misaligned
#   accesses as `SLVERR`.
# - Timing: The model holds `ipbAck` low for a couple of cycles so the bridge's
#   explicit wait state is exercised.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axi = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.ipbRdata.setimmediatevalue(0)
        dut.ipbAck.setimmediatevalue(0)
        dut.ipbErr.setimmediatevalue(0)
        # Lifetime IPbus protocol peer retained by the bench.
        self._ipb_task = cocotb.start_soon(self._ipb_model())

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
        if self.axi is None:
            self.axi = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axiClk, self.dut.axiRst)

    async def _ipb_model(self):
        """Lifetime agent: serve IPbus requests until the test ends."""
        pending = None
        delay = 0
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            self.dut.ipbAck.value = 0
            if pending is None and int(self.dut.ipbStrobe.value):
                pending = {
                    "addr": int(self.dut.ipbAddr.value),
                    "write": int(self.dut.ipbWrite.value),
                    "wdata": int(self.dut.ipbWdata.value),
                }
                delay = 2
            elif pending is not None:
                delay -= 1
                if delay == 0:
                    self.dut.ipbRdata.value = 0xA5A50000 | pending["addr"]
                    self.dut.ipbErr.value = 0
                    self.dut.ipbAck.value = 1
                    pending = None


@cocotb.test()
async def aligned_and_misaligned_access_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    write_resp = await tb.axi.write(0x20, b"\x78\x56\x34\x12")
    assert write_resp.resp == AxiResp.OKAY
    assert int(dut.ipbAddr.value) == 0x08
    assert int(dut.ipbWdata.value) == 0x12345678
    assert int(dut.ipbWrite.value) == 1

    read_data = await tb.axi.read(0x24, 4)
    assert bytes(read_data.data) == (0xA5A50009).to_bytes(4, "little")
    assert read_data.resp == AxiResp.OKAY

    bad_read = await tb.axi.read(0x22, 4)
    assert bad_read.resp == AxiResp.SLVERR


@pytest.mark.parametrize("parameters", [pytest.param({}, id="aligned_word_bridge")])
def test_AxiLiteToIpBus(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitetoipbusipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/bridge/ip_integrator/AxiLiteToIpBusIpIntegrator.vhd"],
        },
    )
