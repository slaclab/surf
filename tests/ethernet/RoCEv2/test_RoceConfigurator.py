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
# - Sweep: Keep one common-clock wrapper instance but cover two configuration
#   launches so the bench proves both the request/response datapath and the
#   rising-edge trigger on `metaDataIsSet`.
# - Stimulus: Program the wide metadata register over AXI-Lite, raise the set
#   bit, return one metadata response beat, then hold the set bit high long
#   enough to prove there is no duplicate request before clearing and setting
#   it again with a second payload.
# - Checks: Each rising edge of the set bit must emit exactly one request,
#   `metaDataIsReady` must raise only after the response arrives, and the wide
#   response register bank must read back the returned metadata word.
# - Timing: The bench waits on visible AXI Stream request beats and AXI-Lite
#   status reads instead of assuming a fixed latency through the state machine.

from __future__ import annotations

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.RoCEv2.roce_test_utils import axil_read_wide, axil_write_wide


WRAPPER_PATH = "ethernet/RoCEv2/wrappers/RoceConfiguratorWrapper.vhd"


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None

        cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())

        dut.rst.setimmediatevalue(1)
        dut.M_META_REQ_TREADY.setimmediatevalue(0)
        dut.S_META_RESP_TVALID.setimmediatevalue(0)
        dut.S_META_RESP_TDATA.setimmediatevalue(0)

    async def cycle(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.rst.value = 1
        await self.cycle(4)
        self.dut.rst.value = 0
        await self.cycle(2)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXIL"), self.dut.clk, self.dut.rst)

    async def wait_for_metadata_request(self, *, timeout_cycles: int = 64) -> int:
        self.dut.M_META_REQ_TREADY.value = 1
        for _ in range(timeout_cycles):
            await RisingEdge(self.dut.clk)
            await Timer(1, unit="ns")
            if int(self.dut.M_META_REQ_TVALID.value) == 1:
                value = int(self.dut.M_META_REQ_TDATA.value)
                await RisingEdge(self.dut.clk)
                await Timer(1, unit="ns")
                self.dut.M_META_REQ_TREADY.value = 0
                return value
        self.dut.M_META_REQ_TREADY.value = 0
        raise AssertionError("Timed out waiting for metadata request")


@cocotb.test()
async def roce_configurator_axil_to_metadata_stream_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()
    assert tb.axil is not None

    first_request = ((1 << 303) - 1) ^ 0x1234_5678_9ABC_DEF0_0123_4567
    first_response = ((1 << 276) - 1) ^ 0x0FED_CBA9_8765_4321

    # Program the outgoing metadata register bank and prove the request only
    # launches on the rising edge of `metaDataIsSet`.
    await axil_write_wide(tb.axil, 0xF04, first_request, total_bits=303)
    await axil_write_u32(tb.axil, 0xF00, 0x1)
    observed_request = await tb.wait_for_metadata_request()
    assert observed_request == first_request
    assert (await axil_read_u32(tb.axil, 0xF00) >> 1) & 0x1 == 0

    # Return one response beat and then confirm the ready flag and the
    # read-only response register bank update as expected.
    dut.S_META_RESP_TDATA.value = first_response
    dut.S_META_RESP_TVALID.value = 1
    while True:
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        if int(dut.S_META_RESP_TREADY.value) == 1:
            dut.S_META_RESP_TVALID.value = 0
            break

    await tb.cycle(2)
    assert (await axil_read_u32(tb.axil, 0xF00) >> 1) & 0x1 == 1
    assert await axil_read_wide(tb.axil, 0xF2C, total_bits=276) == first_response

    # Holding the set bit high must not emit another request until software
    # clears and re-asserts it.
    await tb.cycle(8)
    assert int(dut.M_META_REQ_TVALID.value) == 0

    second_request = 0x1357_9BDF_2468_ACE0_55AA_F00D
    await axil_write_u32(tb.axil, 0xF00, 0x0)
    await axil_write_wide(tb.axil, 0xF04, second_request, total_bits=303)
    await axil_write_u32(tb.axil, 0xF00, 0x1)
    assert await tb.wait_for_metadata_request() == second_request


@pytest.mark.parametrize("parameters", [pytest.param({}, id="roce_configurator_wrapper")])
def test_RoceConfigurator(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.roceconfiguratorwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": [WRAPPER_PATH]},
    )
