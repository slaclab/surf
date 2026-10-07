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
# - Sweep: One RogueSvMemoryRelaunchTb top, compiled once with Verilator and
#   run twice as two separate process invocations of the same binary, bound
#   to the same TCP port pair, against one persistent Memory peer that stays
#   alive across both runs.
# - Stimulus: Build the relaunch TB and libRogueSimLinkDpi.so through ruckus
#   (an abi-check, then make build on simlink/test/sv with
#   system_verilator.mk), spawn the persistent peer, run the binary
#   for phase one (write id 1), signal continue, run the same binary again
#   as a fresh process for phase two (write id 2 queued while no simulator
#   owns the endpoint).
# - Checks: each invocation prints the RogueSvMemoryRelaunchTb passed banner
#   and its addr/value line and exits 0; the peer exits 0 with result ids
#   [1, 2] and matching addresses/values. The HDL top itself self-checks the
#   AW/W capture against its plusargs and polls for the peer's result file
#   before finishing, so a hang is caught by the TB's own watchdog well
#   inside this test's process-level timeouts.
# - Timing: A passing run completes by edge ~1020000 (each write handshake
#   itself takes only a handful of edges; the rest is the idle file-poll
#   loop, which Verilator races through at roughly 5000000 edges/second
#   with no socket data pending). Measured directly against a run with no
#   peer listening: the same idle rate holds all the way to a watchdog
#   fire, so WAIT_EDGES_G is set so the watchdog trips after roughly 30 s
#   of wall clock on a hang, safely inside
#   verilator_test_utils.RUN_TIMEOUT_SECONDS.

import pytest

from tests.simlink.common.sv_relaunch_scenario import SV_RELAUNCH_TOP, run_sv_relaunch
from tests.simlink.paths import sim_build_dir
from tests.simlink.ports import VERILATOR_RELAUNCH
from tests.simlink.verilator import verilator_test_utils as vu

pytestmark = pytest.mark.skipif(not vu.tools_available(), reason=vu.SKIP_REASON)

SIM_BUILD = sim_build_dir("verilator", "RogueSvMemoryRelaunch")
PORT_NUM = VERILATOR_RELAUNCH.port_pair(0).first
# ~5000000 edges/second measured this session for the idle file-poll loop
# (no VPI/DPI traffic pending); a passing run completes by edge ~1020000.
# 150_000_000 edges is ~30 s of wall clock on a hang.
WAIT_EDGES_G = 150_000_000


def test_verilator_persistent_peer_survives_relaunch():
    vu.build_tb(
        SIM_BUILD,
        {"PORT_NUM_G": PORT_NUM, "WAIT_EDGES_G": WAIT_EDGES_G},
        top=SV_RELAUNCH_TOP,
    )

    def run_sim(plusargs):
        return vu.run_tb(SIM_BUILD, top=SV_RELAUNCH_TOP, plusargs=plusargs)

    run_sv_relaunch(run_sim, PORT_NUM, SIM_BUILD)
