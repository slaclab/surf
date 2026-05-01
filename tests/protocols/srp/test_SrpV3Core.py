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
# - Sweep: Keep one direct `SrpV3Core` wrapper smoke case while functional
#   SRPv3Core behavior is exercised transitively through the `SrpV3Axi` matrix.
# - Stimulus: Reset the wrapper with all exposed SRP, read-data, and stream
#   inputs held idle.
# - Checks: The direct wrapper must elaborate, leave downstream request and
#   write-output strobes idle after reset, and keep the response stream idle.
# - Timing: The bench samples after multiple post-reset clock edges so reset
#   release and wrapper resize pipelines have time to settle.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.srp.srp_test_utils import FlatSrpAxis


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 10.0, unit="ns").start())
        self.axis = FlatSrpAxis(dut, clk=dut.AXIS_ACLK)
        self.read_axis = FlatSrpAxis(dut, clk=dut.AXIS_ACLK, source_prefix="RD_AXIS", sink_prefix="WR_AXIS")

    async def reset(self):
        # Hold every exposed stimulus side idle so this direct-core smoke is
        # only checking reset/elaboration behavior, not a duplicated AXI matrix.
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        self.axis.init_source()
        self.axis.init_sink()
        self.read_axis.init_source(prefix="RD_AXIS")
        self.read_axis.init_sink(prefix="WR_AXIS")
        self.dut.SRP_ACK_DONE.setimmediatevalue(0)
        self.dut.SRP_ACK_RESP.setimmediatevalue(0)
        for _ in range(80):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(32):
            await RisingEdge(self.dut.AXIS_ACLK)


@cocotb.test()
async def srpv3_core_reset_idle_smoke_test(dut):
    tb = TB(dut)
    await tb.reset()

    assert int(dut.SRP_REQ_REQUEST.value) == 0
    assert int(dut.M_AXIS_TVALID.value) == 0
    assert int(dut.WR_AXIS_TVALID.value) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="direct_core_reset_idle")])
def test_SrpV3Core(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.srpv3corewrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/srp/wrappers/SrpV3CoreWrapper.vhd"]},
    )
