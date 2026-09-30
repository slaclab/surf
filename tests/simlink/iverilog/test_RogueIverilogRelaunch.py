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
# - Sweep: One RogueSvMemoryRelaunchTb top run twice as two separate vvp
#   invocations bound to the same TCP port pair, against one persistent
#   Memory peer that stays alive across both runs.
# - Stimulus: Build RogueSimLink.vpi, compile the relaunch TB with
#   iverilog -g2012, spawn the persistent peer, run vvp for phase one
#   (write id 1), signal continue, run a fresh vvp for phase two (write
#   id 2 queued while no simulator owns the endpoint).
# - Checks: each vvp invocation prints the RogueSvMemoryRelaunchTb passed
#   banner and its addr/value line and exits 0; the peer exits 0 with
#   result ids [1, 2] and matching addresses/values. The HDL top itself
#   self-checks the AW/W capture against its plusargs and polls for the
#   peer's result file before finishing, so a hang is caught by the TB's
#   own watchdog well inside this test's process-level timeouts.
# - Timing: Measured ~210000 edges/second on this host for this one-leaf
#   top (lighter than the five-instance traffic top); a passing run
#   completes by edge ~44300 in well under a second. WAIT_EDGES_G is set
#   so the watchdog trips after roughly 30 s of wall clock on a hang,
#   safely inside iverilog_test_utils.RUN_TIMEOUT_SECONDS.

import pytest

from tests.simlink.common.sv_relaunch_scenario import SV_RELAUNCH_TOP, run_sv_relaunch
from tests.simlink.iverilog import iverilog_test_utils as iu
from tests.simlink.paths import sim_build_dir
from tests.simlink.ports import IVERILOG_RELAUNCH

pytestmark = pytest.mark.skipif(not iu.tools_available(), reason=iu.SKIP_REASON)

SIM_BUILD = sim_build_dir("iverilog", "RogueSvMemoryRelaunch")
PORT_NUM = IVERILOG_RELAUNCH.port_pair(0).first
# ~210000 edges/second measured this session; a passing run completes by
# edge ~44300. 6_300_000 edges is ~30 s of wall clock on a hang.
WAIT_EDGES_G = 6_300_000


@pytest.fixture(scope="module", autouse=True)
def build_vpi_module():
    iu.build_vpi_module()


def test_iverilog_persistent_peer_survives_relaunch():
    iu.compile_tb(
        SIM_BUILD,
        {"PORT_NUM_G": PORT_NUM, "WAIT_EDGES_G": WAIT_EDGES_G},
        top=SV_RELAUNCH_TOP,
    )

    def run_sim(plusargs):
        return iu.run_tb(SIM_BUILD, top=SV_RELAUNCH_TOP, plusargs=plusargs)

    run_sv_relaunch(run_sim, PORT_NUM, SIM_BUILD)
