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
# - Sweep: Keep one inferred-BRAM 64-bit AXI slave configuration.
# - Stimulus: Drive one multi-beat aligned write/read round trip, then apply a
#   sparse byte overwrite inside the same cache line.
# - Checks: Full reads must return the written bytes exactly, sparse writes
#   must honor byte enables, and AXI responses must stay `OKAY`.
# - Timing: The test uses the real AXI handshakes through the flat wrapper so
#   address, data, and response channels are exercised end-to-end from cocotb.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiBus, AxiMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.master = None

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

    def start_master(self):
        if self.master is None:
            self.master = AxiMaster(AxiBus.from_prefix(self.dut, "S_AXI"), self.dut.axiClk, self.dut.axiRst)


@cocotb.test()
async def burst_and_sparse_overwrite_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_master()

    base_addr = 0x0020
    payload = bytes(range(0x10, 0x10 + 24))

    write_resp = await tb.master.write(base_addr, payload, awid=0x3)
    read_resp = await tb.master.read(base_addr, len(payload), arid=0x4)

    assert write_resp.resp == AxiResp.OKAY
    assert read_resp.resp == AxiResp.OKAY
    assert bytes(read_resp) == payload

    patch_addr = base_addr + 9
    patch_bytes = b"\xAA\xBB\xCC"
    patch_resp = await tb.master.write(patch_addr, patch_bytes, awid=0x5)
    patched = await tb.master.read(base_addr, len(payload), arid=0x6)

    expected = bytearray(payload)
    expected[9:12] = patch_bytes

    assert patch_resp.resp == AxiResp.OKAY
    assert patched.resp == AxiResp.OKAY
    assert bytes(patched) == bytes(expected)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="inferred_bram")])
def test_AxiRam(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiramipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiRamIpIntegrator.vhd",
            ],
        },
    )
