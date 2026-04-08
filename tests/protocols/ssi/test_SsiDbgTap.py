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
from tests.protocols.ssi.ssi_test_utils import SsiBeat, cycle, send_contiguous_frame, setup_flat_ssi_testbench


@cocotb.test()
async def accepted_handshake_smoke_test(dut):
    keep = 0x3

    # Even for a smoke bench, start from a clean reset and explicit idle
    # values so the accepted traffic is easy to reason about.
    bench = await setup_flat_ssi_testbench(
        dut,
        source_prefix="axis",
        initial_values={"axisTReady": 1},
    )
    source = bench.source
    assert source is not None

    # Send one short frame while the external ready input is high.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x0011, keep=keep, last=0, dest=0x1, sof=1),
            SsiBeat(data=0x0022, keep=keep, last=1, dest=0x1),
        ],
        clk=bench.clk,
    )

    # Toggle the observed ready signal to show the tap tolerates changing flow
    # control between frames.
    dut.axisTReady.value = 0
    await cycle(bench.clk, 2)
    dut.axisTReady.value = 1

    # Then send a longer frame after re-enabling ready. The smoke check here is
    # simply that the DUT keeps consuming accepted handshakes without hanging.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x0033, keep=keep, last=0, dest=0x2, sof=1),
            SsiBeat(data=0x0044, keep=keep, last=0, dest=0x2),
            SsiBeat(data=0x0055, keep=keep, last=1, dest=0x2),
        ],
        clk=bench.clk,
    )

    # Leave the simulation running briefly so any latent protocol error has a
    # chance to surface before the test exits.
    await cycle(bench.clk, 6)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="traffic_smoke")])
def test_SsiDbgTap(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssidbgtapwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiDbgTapWrapper.vhd"]},
    )
