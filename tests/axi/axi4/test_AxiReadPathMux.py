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
# - Sweep: Keep one stable two-source wrapper case with 32-bit data so the
#   bench proves the queue-selected mux behavior without broad AXI matrix work.
# - Stimulus: Launch reads from both slave ports into a shared downstream AXI
#   RAM model, including overlapping requests from the two sources.
# - Checks: Each source must receive the data for its own address, and the
#   downstream `ARID` values observed on accepted requests must encode the
#   selected source index.
# - Timing: The two reads are started concurrently so the mux has to arbitrate
#   accepted address traffic instead of only forwarding isolated requests.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiRamRead, AxiReadBus

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.ar_handshakes = []

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())

        dut.axiRst.setimmediatevalue(1)
        self.s0 = SourcePort(dut, "S0_AXI")
        self.s1 = SourcePort(dut, "S1_AXI")
        self.ram = None

        cocotb.start_soon(self._monitor_ar())

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Hold reset long enough for the shim layers and the DUT state machine
        # to return to the idle arbitration state before launching traffic.
        self.dut.axiRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.ram is None:
            self.ram = AxiRamRead(AxiReadBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**16)

    async def _monitor_ar(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if int(self.dut.M_AXI_ARVALID.value) and int(self.dut.M_AXI_ARREADY.value):
                self.ar_handshakes.append(
                    (
                        int(self.dut.M_AXI_ARADDR.value),
                        int(self.dut.M_AXI_ARID.value),
                    )
                )


class SourcePort:
    def __init__(self, dut, prefix):
        self.dut = dut
        self.prefix = prefix

        getattr(dut, f"{prefix}_ARID").setimmediatevalue(0)
        getattr(dut, f"{prefix}_ARADDR").setimmediatevalue(0)
        getattr(dut, f"{prefix}_ARLEN").setimmediatevalue(0)
        getattr(dut, f"{prefix}_ARSIZE").setimmediatevalue(2)
        getattr(dut, f"{prefix}_ARBURST").setimmediatevalue(1)
        getattr(dut, f"{prefix}_ARLOCK").setimmediatevalue(0)
        getattr(dut, f"{prefix}_ARCACHE").setimmediatevalue(0x3)
        getattr(dut, f"{prefix}_ARPROT").setimmediatevalue(0)
        getattr(dut, f"{prefix}_ARREGION").setimmediatevalue(0)
        getattr(dut, f"{prefix}_ARQOS").setimmediatevalue(0)
        getattr(dut, f"{prefix}_ARVALID").setimmediatevalue(0)
        getattr(dut, f"{prefix}_RREADY").setimmediatevalue(0)

    async def issue_read(self, address: int) -> bytes:
        # Drive one single-beat read until the mux accepts the address and then
        # consume the routed data beat from the selected source port.
        getattr(self.dut, f"{self.prefix}_ARADDR").value = address
        getattr(self.dut, f"{self.prefix}_ARVALID").value = 1

        while not int(getattr(self.dut, f"{self.prefix}_ARREADY").value):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

        await RisingEdge(self.dut.axiClk)
        await Timer(1, unit="ns")
        getattr(self.dut, f"{self.prefix}_ARVALID").value = 0
        getattr(self.dut, f"{self.prefix}_RREADY").value = 1

        while not logic_int(getattr(self.dut, f"{self.prefix}_RVALID").value):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

        data = int(getattr(self.dut, f"{self.prefix}_RDATA").value).to_bytes(4, "little")
        assert int(getattr(self.dut, f"{self.prefix}_RRESP").value) == 0
        assert int(getattr(self.dut, f"{self.prefix}_RLAST").value) == 1

        await RisingEdge(self.dut.axiClk)
        await Timer(1, unit="ns")
        getattr(self.dut, f"{self.prefix}_RREADY").value = 0
        return data


def logic_int(value) -> int:
    try:
        return int(value)
    except ValueError:
        return 0


@cocotb.test()
async def concurrent_route_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    tb.ram.write(0x0010, b"\x11\x22\x33\x44")
    tb.ram.write(0x0020, b"\xAA\xBB\xCC\xDD")

    read0 = cocotb.start_soon(tb.s0.issue_read(0x0010))
    read1 = cocotb.start_soon(tb.s1.issue_read(0x0020))

    resp0 = await read0
    resp1 = await read1

    assert resp0 == b"\x11\x22\x33\x44"
    assert resp1 == b"\xAA\xBB\xCC\xDD"

    observed = {(addr, rid & 0x1) for addr, rid in tb.ar_handshakes}
    assert (0x0010, 0) in observed
    assert (0x0020, 1) in observed


@cocotb.test()
async def sequential_source_id_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    tb.ram.write(0x0030, b"\x01\x02\x03\x04")
    tb.ram.write(0x0040, b"\x05\x06\x07\x08")

    resp1 = await tb.s1.issue_read(0x0040)
    resp0 = await tb.s0.issue_read(0x0030)

    assert resp1 == b"\x05\x06\x07\x08"
    assert resp0 == b"\x01\x02\x03\x04"
    assert (0x0040, 1) in {(addr, rid & 0x1) for addr, rid in tb.ar_handshakes}
    assert (0x0030, 0) in {(addr, rid & 0x1) for addr, rid in tb.ar_handshakes}


@pytest.mark.parametrize("parameters", [pytest.param({}, id="two_source_default")])
def test_AxiReadPathMux(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axireadpathmuxipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiReadPathMuxIpIntegrator.vhd",
            ],
        },
    )
