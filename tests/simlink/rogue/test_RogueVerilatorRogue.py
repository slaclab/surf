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
# - Sweep: One RogueSvRogueTb with Memory0, Stream0 and SideBand0 built with
#   `verilator --binary --timing`.
# - Stimulus: The TB and libRogueSimLinkDpi.so are built through ruckus (an
#   abi-check, then make build on simlink/test/sv with system_verilator.mk)
#   and the compiled binary is launched through ruckus's tb target. The
#   three production Rogue clients (rogue_memory_client.py,
#   rogue_stream_client.py, rogue_sideband_client.py, unchanged) start under
#   SIMLINK_ROGUE_PYTHON before the compiled binary; the DUT drives the
#   HDL-first Stream frame and SideBand event.
# - Checks: The DUT's own HDL-side word0/rx checks fire on any mismatch, and
#   sv_rogue_scenario.py asserts the same JSON contracts the GHDL real-Rogue
#   tests assert for each client.
# - Timing: Measured this top's idle-loop edge rate and set WAIT_EDGES_G for
#   about 60 s of wall-clock watchdog margin, below RUN_TIMEOUT_SECONDS.

import pytest

from tests.simlink.paths import sim_build_dir
from tests.simlink.ports import VERILATOR_ROGUE
from tests.simlink.rogue.sv_rogue_scenario import check_rogue_python, run_sv_rogue, SV_ROGUE_TOP
from tests.simlink.verilator import verilator_test_utils as vu

pytestmark = pytest.mark.skipif(not vu.tools_available(), reason=vu.SKIP_REASON)

SIM_BUILD = sim_build_dir("rogue", "RogueVerilatorRogue")
BASE_PORT = VERILATOR_ROGUE.port_pair(0).first
WAIT_EDGES_G = 18_000_000


def test_verilator_real_rogue_contract():
    rogue_python = check_rogue_python()

    vu.build_tb(
        SIM_BUILD,
        {"BASE_PORT_G": BASE_PORT, "WAIT_EDGES_G": WAIT_EDGES_G},
        top=SV_ROGUE_TOP,
    )

    def run_sim(plusargs):
        return vu.run_tb(SIM_BUILD, top=SV_ROGUE_TOP, plusargs=plusargs)

    run_sv_rogue(run_sim, BASE_PORT, SIM_BUILD, rogue_python)
