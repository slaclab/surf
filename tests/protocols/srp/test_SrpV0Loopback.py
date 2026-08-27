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
# - Sweep: Exercise the SRPv0 AXI-Lite loopback wrapper that connects
#   `AxiLiteSrpV0` to `SrpV0AxiLite` and an AXI-Lite RAM backend.
# - Stimulus: Use a cocotb AXI-Lite master, matching the existing tests/axi
#   helper style, to issue aligned writes and reads through the SRPv0 stream.
# - Checks: Returned read data must match the written RAM contents across
#   several addresses, proving both SRPv0 bridge directions and the stream
#   framing between them.
# - Timing: AXI-Lite transactions wait on the real bus handshakes, and a few
#   idle cycles are inserted after reset and each write/read pair.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.S_AXI_ACLK, 8.0, unit="ns").start())
        dut.S_AXI_ARESETN.setimmediatevalue(0)
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.S_AXI_ACLK, dut.S_AXI_ARESETN, reset_active_level=False)

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.S_AXI_ACLK)

    async def reset(self):
        # The wrapper uses the standard active-low AXI-Lite reset exposed by
        # the IP-integrator shim.
        self.dut.S_AXI_ARESETN.value = 0
        await self.cycle(12)
        self.dut.S_AXI_ARESETN.value = 1
        await self.cycle(12)


@cocotb.test()
async def srpv0_axilite_loopback_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Drive several aligned addresses so the test proves that the old SRPv0
    # address packing survives the bridge-to-bridge stream path.
    expected = {
        0x000: 0x10203040,
        0x004: 0x55667788,
        0x040: 0xA5A55A5A,
        0x100: 0xCAFEBABE,
    }
    for address, value in expected.items():
        await axil_write_u32(tb.axil, address, value)
        await tb.cycle(2)

    for address, value in expected.items():
        assert await axil_read_u32(tb.axil, address) == value
        await tb.cycle(2)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="srpv0_axilite_loopback")])
def test_SrpV0Loopback(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.srpv0loopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/srp/wrappers/SrpV0LoopbackWrapper.vhd"]},
    )
