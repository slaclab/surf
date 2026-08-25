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
# - Sweep: Run the common four-Stream/two-Memory/two-SideBand active topology
#   through the VCS VHPI leaves.
# - Stimulus: Reuse the same cocotb scenario and deterministic ZeroMQ peers as
#   GHDL, including tagged bidirectional traffic and a post-traffic reset.
# - Checks: Require all eight instances to exchange only their own tagged
#   traffic, complete Memory write/read transactions, and survive reset.
# - Timing: VHDL compilation, VCS elaboration, simulation, peer operations,
#   and cocotb traffic loops all have explicit bounds. The test is opt-in so
#   ordinary hosts do not attempt a proprietary license checkout.

import pytest

from tests.simlink.paths import (
    COMMON_HDL_TEST_SOURCE_DIR,
    VCS_HDL_TEST_SOURCE_DIR,
    sim_build_dir,
)
from tests.simlink.ports import VCS_MULTI
from tests.simlink.vcs import vcs_test_utils as vu

SIM_BUILD = sim_build_dir("vcs", "RogueVcsMultiInstance")
TOP = "RogueSimLinkVcsVpiBridge"
COCOTB_MODULE = "tests.simlink.common.simlink_multi_instance_cocotb"
VHDL_SOURCES = [
    *vu.MODEL_VHDL_SOURCES,
    COMMON_HDL_TEST_SOURCE_DIR / "RogueSimLinkMultiInstanceHarness.vhd",
]
VERILOG_SOURCES = [VCS_HDL_TEST_SOURCE_DIR / "RogueSimLinkVcsVpiBridge.sv"]

pytestmark = pytest.mark.skipif(not vu.tools_available(), reason=vu.SKIP_REASON)


def test_vcs_instances_exchange_isolated_traffic():
    stream_ports = VCS_MULTI.port_pair(0)
    memory_ports = VCS_MULTI.port_pair(4)
    sideband_ports = VCS_MULTI.port_pair(6)

    vu.build_vhpi_library()
    vu.compile_vhdl(VHDL_SOURCES, SIM_BUILD)
    output = vu.run_cocotb(
        TOP,
        COCOTB_MODULE,
        VERILOG_SOURCES,
        SIM_BUILD,
        extra_env={"SIMLINK_MULTI_BASE_PORT": stream_ports.first},
    )
    # Surface the captured build/elaboration/sim log so the runner's -s shows it
    # on success as well as failure.
    print(output)
    # Confirm each instance bound the port pair the registry assigned it. Match
    # only the distinctive "<first> & <second>" fragment, not the surrounding
    # banner prose or model-name prefix, so a diagnostic-wording change does not
    # break the test. (The common cocotb scenario already validates the traffic
    # and reset behavior; this is a targeted port-binding sanity check.)
    for pair in (stream_ports, memory_ports, sideband_ports):
        assert f"{pair.first} & {pair.second}" in output
