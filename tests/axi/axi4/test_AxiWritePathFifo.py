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
# - Sweep: Keep one 32-bit asynchronous-wrapper configuration so the first
#   pass proves write-side address/data/response preservation through the FIFO.
# - Stimulus: Launch two single-beat writes into the source-side AXI port and
#   let a downstream AXI RAM model consume the shared master-side traffic.
# - Checks: The downstream memory contents, response code, and returned `BID`
#   must match the written payloads and source IDs.
# - Timing: The bench waits on the DUT's independent address, data, and
#   response handshakes instead of assuming same-cycle FIFO forwarding.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiRamWrite, AxiResp, AxiWriteBus

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.ram = None

        # Drive the source and destination write clocks from one coroutine so
        # the first-pass bench stays deterministic while still using both ports.
        start_lockstep_clocks(dut.sAxiClk, dut.mAxiClk, period_ns=5.0)
        dut.sAxiRst.setimmediatevalue(1)
        dut.mAxiRst.setimmediatevalue(1)

        for name, value in {
            "S_AXI_AWID": 0,
            "S_AXI_AWADDR": 0,
            "S_AXI_AWLEN": 0,
            "S_AXI_AWSIZE": 2,
            "S_AXI_AWBURST": 1,
            "S_AXI_AWLOCK": 0,
            "S_AXI_AWCACHE": 0x3,
            "S_AXI_AWPROT": 0,
            "S_AXI_AWVALID": 0,
            "S_AXI_WID": 0,
            "S_AXI_WDATA": 0,
            "S_AXI_WSTRB": 0,
            "S_AXI_WLAST": 0,
            "S_AXI_WVALID": 0,
            "S_AXI_BREADY": 0,
        }.items():
            getattr(dut, name).setimmediatevalue(value)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.sAxiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Reset both domains and return the source-side handshake pins to idle
        # before launching any write transaction into the FIFO wrapper.
        self.dut.sAxiRst.value = 1
        self.dut.mAxiRst.value = 1
        self.dut.S_AXI_AWVALID.value = 0
        self.dut.S_AXI_WVALID.value = 0
        self.dut.S_AXI_BREADY.value = 0
        await self.cycle(4)
        self.dut.sAxiRst.value = 0
        self.dut.mAxiRst.value = 0
        await self.cycle(4)

    def start_ram(self):
        if self.ram is None:
            self.ram = AxiRamWrite(
                AxiWriteBus.from_prefix(self.dut, "M_AXI"),
                self.dut.mAxiClk,
                self.dut.mAxiRst,
                size=2**16,
            )

    async def issue_write(self, *, address: int, payload: bytes, wid: int) -> tuple[int, int]:
        data = int.from_bytes(payload, "little")

        # Keep address and data valid until both source-side handshakes fire,
        # then wait for the routed response to return through the FIFO.
        self.dut.S_AXI_AWADDR.value = address
        self.dut.S_AXI_AWID.value = wid
        self.dut.S_AXI_AWVALID.value = 1
        self.dut.S_AXI_WID.value = wid
        self.dut.S_AXI_WDATA.value = data
        self.dut.S_AXI_WSTRB.value = 0xF
        self.dut.S_AXI_WLAST.value = 1
        self.dut.S_AXI_WVALID.value = 1

        aw_done = False
        w_done = False
        while not (aw_done and w_done):
            await self.cycle(1)
            aw_done = aw_done or (
                int(self.dut.S_AXI_AWVALID.value) and int(self.dut.S_AXI_AWREADY.value)
            )
            w_done = w_done or (
                int(self.dut.S_AXI_WVALID.value) and int(self.dut.S_AXI_WREADY.value)
            )
            if aw_done:
                self.dut.S_AXI_AWVALID.value = 0
            if w_done:
                self.dut.S_AXI_WVALID.value = 0

        self.dut.S_AXI_BREADY.value = 1
        while not int(self.dut.S_AXI_BVALID.value):
            await self.cycle(1)

        resp = int(self.dut.S_AXI_BRESP.value)
        bid = int(self.dut.S_AXI_BID.value)
        await self.cycle(1)
        self.dut.S_AXI_BREADY.value = 0
        return resp, bid

@cocotb.test()
async def routed_write_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_ram()

    first_resp, first_bid = await tb.issue_write(address=0x0020, payload=b"\x10\x11\x12\x13", wid=0x3)
    second_resp, second_bid = await tb.issue_write(address=0x0030, payload=b"\x20\x21\x22\x23", wid=0x6)
    await tb.cycle(2)

    assert first_resp == AxiResp.OKAY
    assert first_bid == 0x3
    assert second_resp == AxiResp.OKAY
    assert second_bid == 0x6
    assert tb.ram.read(0x0020, 4) == b"\x10\x11\x12\x13"
    assert tb.ram.read(0x0030, 4) == b"\x20\x21\x22\x23"
    assert int(dut.writePause.value) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="single_write_lane")])
def test_AxiWritePathFifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiwritepathfifoipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiWritePathFifoIpIntegrator.vhd",
            ],
        },
    )
