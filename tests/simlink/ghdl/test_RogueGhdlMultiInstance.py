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
# - Sweep: Run the shared four-Stream/two-Memory/two-SideBand active topology
#   through the GHDL VHPIDIRECT leaves.
# - Stimulus: The common cocotb scenario owns all tagged traffic and reset
#   sequencing; this file only builds and selects the GHDL backend.
# - Checks: The common scenario validates isolation and peer results.
# - Timing: The common scenario waits for peer readiness, then bounds the wait
#   for peer completion by wall clock.

from tests.simlink.ghdl.simlink_test_utils import run_simlink_ghdl_test
from tests.simlink.paths import (
    COMMON_HDL_TEST_SOURCE_DIR,
    GHDL_SOURCE_DIR,
    sim_build_dir,
)
from tests.simlink.ports import GHDL_MULTI

GHDL_DIR = GHDL_SOURCE_DIR
SIM_BUILD = sim_build_dir("ghdl", "RogueGhdlMultiInstance")
TOP = "roguesimlinkmultiinstanceharness"
COCOTB_MODULE = "tests.simlink.common.simlink_multi_instance_cocotb"


def test_rogue_ghdl_multi_instance_traffic():
    run_simlink_ghdl_test(
        test_file=__file__,
        module=COCOTB_MODULE,
        toplevel=TOP,
        vhdl_sources=[
            str(GHDL_DIR / "RogueTcpStream.vhd"),
            str(GHDL_DIR / "RogueTcpMemory.vhd"),
            str(GHDL_DIR / "RogueSideBand.vhd"),
            str(COMMON_HDL_TEST_SOURCE_DIR / "RogueSimLinkMultiInstanceHarness.vhd"),
        ],
        sim_build=SIM_BUILD,
        extra_env={
            "SIMLINK_MULTI_INSTANCE_RESULT_DIR": str(SIM_BUILD),
            "SIMLINK_MULTI_BASE_PORT": GHDL_MULTI.port_pair(0).first,
        },
    )
