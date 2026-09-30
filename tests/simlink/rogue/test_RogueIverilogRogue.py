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
# - Sweep: One RogueSvRogueTb with Memory0, Stream0 and SideBand0 under
#   Icarus Verilog.
# - Stimulus: The three production Rogue clients (rogue_memory_client.py,
#   rogue_stream_client.py, rogue_sideband_client.py, unchanged) started under
#   SIMLINK_ROGUE_PYTHON before vvp; the DUT drives the HDL-first Stream frame
#   and SideBand event.
# - Checks: The DUT's own HDL-side word0/rx checks fire on any mismatch, and
#   sv_rogue_scenario.py asserts the same JSON contracts the GHDL real-Rogue
#   tests assert for each client.
# - Timing: Measured this top's idle-loop edge rate and set WAIT_EDGES_G for
#   about 60 s of wall-clock watchdog margin, below RUN_TIMEOUT_SECONDS.

import pytest

from tests.simlink.iverilog import iverilog_test_utils as iu
from tests.simlink.paths import sim_build_dir
from tests.simlink.ports import IVERILOG_ROGUE
from tests.simlink.rogue.sv_rogue_scenario import check_rogue_python, run_sv_rogue, SV_ROGUE_TOP

pytestmark = pytest.mark.skipif(not iu.tools_available(), reason=iu.SKIP_REASON)

SIM_BUILD = sim_build_dir("rogue", "RogueIverilogRogue")
BASE_PORT = IVERILOG_ROGUE.port_pair(0).first
WAIT_EDGES_G = 6_000_000


def test_iverilog_real_rogue_contract():
    rogue_python = check_rogue_python()

    iu.build_vpi_module()
    iu.compile_tb(
        SIM_BUILD,
        {"BASE_PORT_G": BASE_PORT, "WAIT_EDGES_G": WAIT_EDGES_G},
        top=SV_ROGUE_TOP,
    )

    def run_sim(plusargs):
        return iu.run_tb(SIM_BUILD, top=SV_ROGUE_TOP, plusargs=plusargs)

    run_sv_rogue(run_sim, BASE_PORT, SIM_BUILD, rogue_python)
