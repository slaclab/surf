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
# - Sweep: Keep one same-clock two-byte SSI path because the debug tap exposes
#   no functional outputs and this first pass is limited to traffic smoke.
# - Stimulus: Drive one accepted multi-beat frame and then a second frame while
#   toggling the external ready input that the tap observes.
# - Checks: The module must elaborate, reset, and consume accepted handshakes
#   without simulation errors or deadlock under changing ready conditions.
# - Timing: The bench advances the shared clock explicitly and holds stimulus
#   only on accepted beat boundaries.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import FlatSsiEndpoint, SsiBeat, cycle, reset_dut, send_contiguous_frame, start_clock


@cocotb.test()
async def accepted_handshake_smoke_test(dut):
    keep = 0x3

    start_clock(dut.axisClk)
    source = FlatSsiEndpoint(dut, prefix="axis")
    dut.axisRst.setimmediatevalue(1)
    source.set_idle()
    dut.axisTReady.setimmediatevalue(1)
    await reset_dut(dut)

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x0011, keep=keep, last=0, dest=0x1, sof=1),
            SsiBeat(data=0x0022, keep=keep, last=1, dest=0x1),
        ],
        clk=dut.axisClk,
    )

    dut.axisTReady.value = 0
    await cycle(dut.axisClk, 2)
    dut.axisTReady.value = 1

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x0033, keep=keep, last=0, dest=0x2, sof=1),
            SsiBeat(data=0x0044, keep=keep, last=0, dest=0x2),
            SsiBeat(data=0x0055, keep=keep, last=1, dest=0x2),
        ],
        clk=dut.axisClk,
    )

    await cycle(dut.axisClk, 6)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="traffic_smoke")])
def test_SsiDbgTap(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssidbgtapwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiDbgTapWrapper.vhd"]},
    )
