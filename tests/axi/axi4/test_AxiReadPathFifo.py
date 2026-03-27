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
# - Sweep: Keep one 32-bit asynchronous-wrapper configuration with the default
#   FIFO shaping so the first pass proves request/response preservation rather
#   than a broad generic matrix.
# - Stimulus: Launch two single-beat reads through the single source-side AXI
#   port into a downstream AXI RAM model one after the other.
# - Checks: The returned data, response code, and `RID` field must match the
#   downstream memory contents and the request IDs driven at the source port.
# - Timing: The bench keeps the source and destination clocks lockstep-aligned
#   but independent signals, then waits on the DUT's real handshake edges for
#   each request/response pair.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiRamRead, AxiReadBus

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.ram = None

        # Use shared edges so the asynchronous wrapper stays on a stable first
        # pass while still traversing the DUT's own dual-clock plumbing.
        start_lockstep_clocks(dut.sAxiClk, dut.mAxiClk, period_ns=5.0)
        dut.sAxiRst.setimmediatevalue(1)
        dut.mAxiRst.setimmediatevalue(1)

        for name, value in {
            "S_AXI_ARID": 0,
            "S_AXI_ARADDR": 0,
            "S_AXI_ARLEN": 0,
            "S_AXI_ARSIZE": 2,
            "S_AXI_ARBURST": 1,
            "S_AXI_ARLOCK": 0,
            "S_AXI_ARCACHE": 0x3,
            "S_AXI_ARPROT": 0,
            "S_AXI_ARVALID": 0,
            "S_AXI_RREADY": 0,
        }.items():
            getattr(dut, name).setimmediatevalue(value)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.sAxiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Hold both domains in reset long enough for the FIFO pointers and the
        # AXI shim layers to return to a known idle state.
        self.dut.sAxiRst.value = 1
        self.dut.mAxiRst.value = 1
        self.dut.S_AXI_ARVALID.value = 0
        self.dut.S_AXI_RREADY.value = 0
        await self.cycle(4)
        self.dut.sAxiRst.value = 0
        self.dut.mAxiRst.value = 0
        await self.cycle(4)

    def start_ram(self):
        if self.ram is None:
            self.ram = AxiRamRead(
                AxiReadBus.from_prefix(self.dut, "M_AXI"),
                self.dut.mAxiClk,
                self.dut.mAxiRst,
                size=2**16,
            )

    async def issue_read(self, *, address: int, rid: int) -> tuple[int, int, int]:
        # Hold the address request until the source-side interface accepts it,
        # then wait for the matching response beat to return through the FIFO.
        self.dut.S_AXI_ARADDR.value = address
        self.dut.S_AXI_ARID.value = rid
        self.dut.S_AXI_ARVALID.value = 1

        while not int(self.dut.S_AXI_ARREADY.value):
            await self.cycle(1)

        await self.cycle(1)
        self.dut.S_AXI_ARVALID.value = 0
        self.dut.S_AXI_RREADY.value = 1

        while not int(self.dut.S_AXI_RVALID.value):
            await self.cycle(1)

        data = int(self.dut.S_AXI_RDATA.value)
        resp = int(self.dut.S_AXI_RRESP.value)
        observed_rid = int(self.dut.S_AXI_RID.value)
        assert int(self.dut.S_AXI_RLAST.value) == 1

        await self.cycle(1)
        self.dut.S_AXI_RREADY.value = 0
        return data, resp, observed_rid


@cocotb.test()
async def sequential_single_beat_reads_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_ram()

    tb.ram.write(0x0040, b"\x11\x22\x33\x44")
    tb.ram.write(0x0080, b"\xAA\xBB\xCC\xDD")

    first_data, first_resp, first_rid = await tb.issue_read(address=0x0040, rid=0x5)
    second_data, second_resp, second_rid = await tb.issue_read(address=0x0080, rid=0xA)

    assert first_data == 0x44332211
    assert first_resp == 0
    assert first_rid == 0x5

    assert second_data == 0xDDCCBBAA
    assert second_resp == 0
    assert second_rid == 0xA


@pytest.mark.parametrize("parameters", [pytest.param({}, id="single_read_lane")])
def test_AxiReadPathFifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axireadpathfifoipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiReadPathFifoIpIntegrator.vhd",
            ],
        },
    )
