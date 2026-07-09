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
# - Sweep: Keep one common-clock two-word mirror configuration so the first
#   pass proves the bridge contract without expanding to larger arrays.
# - Stimulus: Change the two input words over time while a cocotb AXI-Lite RAM
#   model observes the exported master port transactions.
# - Checks: The mapped AXI-Lite locations must eventually mirror the latest
#   input values at the configured addresses.
# - Timing: The bench polls the downstream RAM contents over several cycles so
#   it proves the DUT's real write propagation instead of assuming zero latency.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteRam

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.ram = None

        # This wrapper is pinned to the common-clock case, so keep the driving
        # edges truly aligned instead of starting same-period clocks separately.
        start_lockstep_clocks(dut.clk, dut.axilClk, period_ns=5.0)
        dut.rst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.input0.setimmediatevalue(0)
        dut.input1.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Hold the producer side and AXI-Lite side in reset together so the
        # first mirrored writes observed in RAM come from bench stimulus only.
        self.dut.rst.value = 1
        self.dut.axilRst.value = 1
        self.dut.input0.value = 0
        self.dut.input1.value = 0
        await self.cycle(4)
        self.dut.rst.value = 0
        self.dut.axilRst.value = 0
        await self.cycle(6)

    def start_agents(self):
        if self.ram is None:
            self.ram = AxiLiteRam(AxiLiteBus.from_prefix(self.dut, "M_AXI"), self.dut.axilClk, self.dut.axilRst, size=2**12)

    async def wait_for_word(self, address: int, value: int, *, limit_cycles: int = 40):
        # Poll the downstream RAM model until the bridge has issued the AXI-Lite
        # write sequence that mirrors the current input value.
        expected = value.to_bytes(4, "little")
        for _ in range(limit_cycles):
            if self.ram.read(address, 4) == expected:
                return
            await self.cycle(1)
        raise AssertionError(f"Timed out waiting for AXI-Lite mirror 0x{address:08X} -> 0x{value:08X}")


@cocotb.test()
async def mirrored_writes_follow_input_changes_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    # Both configured array entries should be mirrored into the exported master
    # address map once the DUT observes the input values.
    tb.dut.input0.value = 0x11223344
    tb.dut.input1.value = 0x55667788
    await tb.wait_for_word(0x10, 0x11223344)
    await tb.wait_for_word(0x20, 0x55667788)

    # Updating only one input should refresh only the corresponding mapped
    # AXI-Lite location while the other mirrored word stays intact.
    tb.dut.input1.value = 0x89ABCDEF
    await tb.wait_for_word(0x20, 0x89ABCDEF)

    assert tb.ram.read(0x10, 4) == b"\x44\x33\x22\x11"


@pytest.mark.parametrize("parameters", [pytest.param({}, id="common_clk_two_word")])
def test_SlvArraytoAxiLite(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.slvarraytoaxiliteipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["axi/bridge/ip_integrator/SlvArraytoAxiLiteIpIntegrator.vhd"]},
    )
