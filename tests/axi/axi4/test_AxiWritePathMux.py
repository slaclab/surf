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
# - Sweep: Keep one stable two-source wrapper case with 32-bit data and one
#   beat per write so the bench focuses on mux ownership and response routing.
# - Stimulus: Launch single-beat writes from both slave ports into a shared
#   downstream AXI RAM model and then collect the routed write responses.
# - Checks: The downstream memory contents must match the source payloads, and
#   the accepted `AWID` values on the shared master port must encode the
#   source index that won the transfer.
# - Timing: The bench checks accepted downstream handshakes after each source
#   write so the DUT still steps through its internal address/data sequencing.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiRamWrite, AxiResp, AxiWriteBus

from tests.common.regression_utils import run_surf_vhdl_test


def logic_int(value) -> int:
    try:
        return int(value)
    except ValueError:
        return 0


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.aw_handshakes = []

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())

        dut.axiRst.setimmediatevalue(1)
        self.s0 = SourcePort(dut, "S0_AXI")
        self.s1 = SourcePort(dut, "S1_AXI")
        self.ram = None

        cocotb.start_soon(self._monitor_aw())

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Reset both the wrapper shims and the mux state machine before any
        # write-side arbitration or response routing is exercised.
        self.dut.axiRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.ram is None:
            self.ram = AxiRamWrite(AxiWriteBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**16)

    async def _monitor_aw(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if logic_int(self.dut.M_AXI_AWVALID.value) and logic_int(self.dut.M_AXI_AWREADY.value):
                self.aw_handshakes.append(
                    (
                        int(self.dut.M_AXI_AWADDR.value),
                        int(self.dut.M_AXI_AWID.value),
                    )
                )


class SourcePort:
    def __init__(self, dut, prefix):
        self.dut = dut
        self.prefix = prefix

        getattr(dut, f"{prefix}_AWID").setimmediatevalue(0)
        getattr(dut, f"{prefix}_AWADDR").setimmediatevalue(0)
        getattr(dut, f"{prefix}_AWLEN").setimmediatevalue(0)
        getattr(dut, f"{prefix}_AWSIZE").setimmediatevalue(2)
        getattr(dut, f"{prefix}_AWBURST").setimmediatevalue(1)
        getattr(dut, f"{prefix}_AWLOCK").setimmediatevalue(0)
        getattr(dut, f"{prefix}_AWCACHE").setimmediatevalue(0x3)
        getattr(dut, f"{prefix}_AWPROT").setimmediatevalue(0)
        getattr(dut, f"{prefix}_AWREGION").setimmediatevalue(0)
        getattr(dut, f"{prefix}_AWQOS").setimmediatevalue(0)
        getattr(dut, f"{prefix}_AWVALID").setimmediatevalue(0)
        getattr(dut, f"{prefix}_WID").setimmediatevalue(0)
        getattr(dut, f"{prefix}_WDATA").setimmediatevalue(0)
        getattr(dut, f"{prefix}_WSTRB").setimmediatevalue(0)
        getattr(dut, f"{prefix}_WLAST").setimmediatevalue(0)
        getattr(dut, f"{prefix}_WVALID").setimmediatevalue(0)
        getattr(dut, f"{prefix}_BREADY").setimmediatevalue(0)

    async def issue_write(self, address: int, payload: bytes):
        data = int.from_bytes(payload, "little")

        # Hold both address and data valid until the mux accepts them on the
        # selected source port, then wait for the routed response beat.
        getattr(self.dut, f"{self.prefix}_AWADDR").value = address
        getattr(self.dut, f"{self.prefix}_AWVALID").value = 1
        getattr(self.dut, f"{self.prefix}_WDATA").value = data
        getattr(self.dut, f"{self.prefix}_WSTRB").value = 0xF
        getattr(self.dut, f"{self.prefix}_WLAST").value = 1
        getattr(self.dut, f"{self.prefix}_WVALID").value = 1

        aw_done = False
        w_done = False
        while not (aw_done and w_done):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            aw_done = aw_done or (
                int(getattr(self.dut, f"{self.prefix}_AWVALID").value)
                and int(getattr(self.dut, f"{self.prefix}_AWREADY").value)
            )
            w_done = w_done or (
                int(getattr(self.dut, f"{self.prefix}_WVALID").value)
                and int(getattr(self.dut, f"{self.prefix}_WREADY").value)
            )
            if aw_done:
                getattr(self.dut, f"{self.prefix}_AWVALID").value = 0
            if w_done:
                getattr(self.dut, f"{self.prefix}_WVALID").value = 0

        getattr(self.dut, f"{self.prefix}_BREADY").value = 1
        while not logic_int(getattr(self.dut, f"{self.prefix}_BVALID").value):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

        resp = int(getattr(self.dut, f"{self.prefix}_BRESP").value)
        await RisingEdge(self.dut.axiClk)
        await Timer(1, unit="ns")
        getattr(self.dut, f"{self.prefix}_BREADY").value = 0
        return resp


@cocotb.test()
async def concurrent_write_route_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    resp0 = await tb.s0.issue_write(0x0010, b"\x10\x11\x12\x13")
    resp1 = await tb.s1.issue_write(0x0020, b"\x20\x21\x22\x23")
    await tb.cycle(1)

    assert resp0 == AxiResp.OKAY
    assert resp1 == AxiResp.OKAY
    assert tb.ram.read(0x0010, 4) == b"\x10\x11\x12\x13"
    assert tb.ram.read(0x0020, 4) == b"\x20\x21\x22\x23"

    observed = {(addr, bid & 0x1) for addr, bid in tb.aw_handshakes}
    assert (0x0010, 0) in observed
    assert (0x0020, 1) in observed


@cocotb.test()
async def sequential_response_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    resp1 = await tb.s1.issue_write(0x0030, b"\x31\x32\x33\x34")
    resp0 = await tb.s0.issue_write(0x0040, b"\x41\x42\x43\x44")

    assert resp1 == AxiResp.OKAY
    assert resp0 == AxiResp.OKAY
    assert tb.ram.read(0x0030, 4) == b"\x31\x32\x33\x34"
    assert tb.ram.read(0x0040, 4) == b"\x41\x42\x43\x44"


@pytest.mark.parametrize("parameters", [pytest.param({}, id="two_source_default")])
def test_AxiWritePathMux(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiwritepathmuxipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiWritePathMuxIpIntegrator.vhd",
            ],
        },
    )
