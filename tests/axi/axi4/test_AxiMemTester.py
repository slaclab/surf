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
# - Sweep: Keep the wrapper's default 32-bit address space so the DUT elaborates
#   on the same slice directions it uses in-tree while still proving the full
#   memory-tester state machine against a cocotb AXI RAM model.
# - Stimulus: Pulse the external `start` control, let the DUT drive a cocotb
#   AXI RAM model through its write/read phases, and observe the status bus.
# - Checks: `memReady` must assert, `memError` must remain low, and the AXI-Lite
#   status registers must report done without any response or data mismatch.
# - Timing: The bench waits on the DUT's exported ready/error flags instead of
#   assuming a fixed completion latency for the memory sweep.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiBus, AxiLiteBus, AxiLiteMaster, AxiRam, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        self.ram = None

        cocotb.start_soon(Clock(dut.axilClk, 5.0, unit="ns").start())
        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axilRst.setimmediatevalue(1)
        dut.axiRst.setimmediatevalue(1)
        dut.start.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Reset both the control plane and the AXI memory side before starting
        # the tester so the exported done/error state is entirely DUT-driven.
        self.dut.axilRst.value = 1
        self.dut.axiRst.value = 1
        self.dut.start.value = 0
        await self.cycle(4)
        self.dut.axilRst.value = 0
        self.dut.axiRst.value = 0
        await self.cycle(4)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(
                AxiLiteBus.from_prefix(self.dut, "S_AXI"),
                self.dut.axilClk,
                self.dut.axilRst,
            )
        if self.ram is None:
            self.ram = AxiRam(AxiBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**12)

    async def read_reg(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def wait_ready(self, timeout_cycles: int = 8000):
        # Keep `start` asserted until the tester reports completion so the DUT
        # runs through its intended busy/done handshake rather than a one-cycle pulse.
        self.dut.start.value = 1
        for _ in range(timeout_cycles):
            if int(self.dut.memReady.value):
                self.dut.start.value = 0
                await self.cycle(2)
                return
            assert int(self.dut.memError.value) == 0
            await self.cycle(1)
        raise AssertionError("Timed out waiting for AxiMemTester to assert memReady")


@cocotb.test()
async def single_window_memory_sweep_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await tb.wait_ready()

    status = await tb.read_reg(0x100)
    error = await tb.read_reg(0x104)
    config = await tb.read_reg(0x120)
    error_flags = await tb.read_reg(0x12C)

    assert int(dut.memReady.value) == 1
    assert int(dut.memError.value) == 0
    assert (status & 0x1) == 1
    assert ((status >> 2) & 0x1) == 0
    assert error == 0
    assert config == 32
    assert error_flags == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="default_address_window")])
def test_AxiMemTester(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.aximemtesteripintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiMemTesterIpIntegrator.vhd",
            ],
        },
    )
