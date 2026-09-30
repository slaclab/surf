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
# - Sweep: Four Stream, two Memory, and two SideBand leaves in one Icarus
#   top, on eight adjacent port pairs (IVERILOG_MULTI).
# - Stimulus: Eight tagged pyzmq peers exchange their own tagged frames with
#   the DUT; the DUT drives and checks each instance's tagged vector in HDL,
#   then re-pulses reset and runs a spurious-traffic guard window.
# - Checks: vvp prints the RogueSvMultiInstanceTb passed banner and exits 0;
#   every peer exits 0 and passes validate_multi_instance_peer_result(). The
#   HDL top's own per-tag $fatal checks catch cross-instance isolation
#   failures; a hang is caught by the TB's own watchdog well inside this
#   test's process-level timeouts.
# - Timing: Measured ~48000 edges/second on this host for this top's idle
#   guard-window loop (isolated by temporarily inflating GUARD_EDGES_C to
#   2,000,000 edges: 2,000,638 edges completed in 41.6 s); a passing run
#   with peers attached completes by edge ~2500. WAIT_EDGES_G is set so the
#   watchdog trips after roughly 20 s of wall clock on a hang, safely inside
#   iverilog_test_utils.RUN_TIMEOUT_SECONDS.

import pytest

from tests.simlink.common.sv_multi_scenario import run_sv_multi, SV_MULTI_TOP
from tests.simlink.iverilog import iverilog_test_utils as iu
from tests.simlink.paths import sim_build_dir
from tests.simlink.ports import IVERILOG_MULTI

pytestmark = pytest.mark.skipif(not iu.tools_available(), reason=iu.SKIP_REASON)

SIM_BUILD = sim_build_dir("iverilog", "RogueSvMultiInstance")
BASE_PORT = IVERILOG_MULTI.port_pair(0).first
# ~48000 edges/second measured this session (idle guard-window loop); a
# passing run completes by edge ~2500. 1_000_000 edges is ~21 s of wall
# clock on a hang.
WAIT_EDGES_G = 1_000_000


@pytest.fixture(scope="module", autouse=True)
def build_vpi_module():
    iu.build_vpi_module()


def test_iverilog_multi_instance_isolation():
    iu.compile_tb(
        SIM_BUILD,
        {"BASE_PORT_G": BASE_PORT, "WAIT_EDGES_G": WAIT_EDGES_G},
        top=SV_MULTI_TOP,
    )

    def run_sim():
        return iu.run_tb(SIM_BUILD, top=SV_MULTI_TOP)

    run_sv_multi(run_sim, BASE_PORT, SIM_BUILD / "peers")
