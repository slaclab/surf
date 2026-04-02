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
# - Sweep: Keep one 32-bit bridge instance into a 32-bit AXI-Lite RAM.
# - Stimulus: Drive one IPBus write, one IPBus read, and one invalid-address
#   request directly on the IPBus side.
# - Checks: The downstream AXI-Lite RAM must observe byte-address conversion,
#   the readback data must return through the bridge, and out-of-range IPBus
#   addresses must assert `ipbErr`.
# - Timing: The IPBus driver waits on the bridge-generated ack so the test
#   covers the request/response state machine.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteRam

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.ram = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.ipbAddr.setimmediatevalue(0)
        dut.ipbWdata.setimmediatevalue(0)
        dut.ipbStrobe.setimmediatevalue(0)
        dut.ipbWrite.setimmediatevalue(0)

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
        if self.ram is None:
            self.ram = AxiLiteRam(AxiLiteBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**16)

    async def ipb_request(self, *, address: int, write: bool, data: int = 0):
        self.dut.ipbAddr.value = address
        self.dut.ipbWdata.value = data
        self.dut.ipbWrite.value = int(write)
        self.dut.ipbStrobe.value = 1
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if int(self.dut.ipbAck.value):
                break
        result = (int(self.dut.ipbRdata.value), int(self.dut.ipbErr.value))
        self.dut.ipbStrobe.value = 0
        self.dut.ipbWrite.value = 0
        await self.cycle(1)
        return result


@cocotb.test()
async def ipbus_to_axil_translation_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    _, write_err = await tb.ipb_request(address=0x00000008, write=True, data=0xCAFEBABE)
    read_data, read_err = await tb.ipb_request(address=0x00000008, write=False)
    _, bad_err = await tb.ipb_request(address=0x80000000, write=False)

    assert write_err == 0
    assert read_err == 0
    assert bad_err == 1
    assert tb.ram.read(0x20, 4) == b"\xBE\xBA\xFE\xCA"
    assert read_data == 0xCAFEBABE


@pytest.mark.parametrize("parameters", [pytest.param({}, id="ipbus_word_bridge")])
def test_IpBusToAxiLite(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ipbustoaxiliteipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/bridge/ip_integrator/IpBusToAxiLiteIpIntegrator.vhd"],
        },
    )
