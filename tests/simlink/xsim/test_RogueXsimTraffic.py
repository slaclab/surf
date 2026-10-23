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
# - Sweep: One eight-instance top (4 Stream, 2 Memory, 2 SideBand) run under
#   the real Vivado xsim mixed-language/DPI flow with live peers.
# - Stimulus: Launch one rogue_tcp_peer.py per instance, wait until every peer
#   reports that its ZeroMQ sockets are configured and connect() has been
#   issued, then start xsim. The top retains a fixed settle delay for the
#   asynchronous ZeroMQ handshake before exchanging tagged traffic.
# - Checks: xsim prints the success banner, every peer exits 0, and each
#   peer's JSON shows only its own tag family with zero foreign tags, then the
#   top pulses reset again and runs on before reporting success.
# - Timing: The top uses bounded clock loops; each peer bounds recv with
#   RCVTIMEO; xsim is wall-clock bounded. Skips when Vivado tools are absent.

import pytest

from tests.simlink.common.peer_orchestration import (
    spawn_peer_group,
    terminate_peers,
    wait_for_peers_ready,
)
from tests.simlink.common.simlink_multi_scenario import (
    multi_instance_peer_specs,
    validate_multi_instance_peer_result,
)
from tests.simlink.paths import XSIM_HDL_TEST_SOURCE_DIR, sim_build_dir
from tests.simlink.ports import XSIM_TRAFFIC
from tests.simlink.xsim import xsim_test_utils as xu

TB_SOURCE = XSIM_HDL_TEST_SOURCE_DIR / "RogueXsimTrafficTb.vhd"
SIM_BUILD = sim_build_dir("xsim", "RogueXsimTraffic")
VHDL_SOURCES = [*xu.MODEL_VHDL_SOURCES, TB_SOURCE]

pytestmark = pytest.mark.skipif(not xu.tools_available(), reason=xu.SKIP_REASON)

PEER_WAIT_SECONDS = 30
PEER_READY_SECONDS = 10

# Endpoint allocation mirrored by RogueXsimTrafficTb.vhd. The Python ranges
# participate in the suite-wide collision check; keep the HDL constants in
# sync when this allocation changes:
#   Stream   i -> 19740 + 2*i  (19740..19747)
#   Memory   i -> 19748 + 2*i  (19748..19751)
#   SideBand i -> 19752 + 2*i  (19752..19755)
PEER_SPECS = multi_instance_peer_specs(XSIM_TRAFFIC.port_pair(0).first)


@pytest.fixture(scope="module", autouse=True)
def build_dpi_library():
    xu.build_dpi_library()


def test_xsim_instances_exchange_isolated_traffic():
    result_dir = SIM_BUILD / "peers"
    # Elaborate first, then spawn peers just before the run. Wait for every
    # ready file so Python startup and socket configuration are deterministic;
    # the HDL settle delay covers the asynchronous connect handshake after the
    # model binds. This also keeps xvlog/xvhdl/xelab outside RCVTIMEO.
    xu.compile_and_elaborate("RogueXsimTrafficTb", VHDL_SOURCES, SIM_BUILD)
    peers = spawn_peer_group(
        PEER_SPECS,
        result_dir,
        ready=True,
        env=xu.xsim_run_env(),
    )
    try:
        wait_for_peers_ready(peers, PEER_READY_SECONDS)
        result = xu.run_elaborated("RogueXsimTrafficTb", SIM_BUILD)
        output = result.stdout + result.stderr
        print(output)
        if "Rogue xsim traffic test passed" not in output:
            # Append every peer's JSON so a banner miss is diagnosable.
            dumps = []
            for peer in peers:
                if peer.result_path.exists():
                    dumps.append(
                        f"{peer.result_path.name}:\n{peer.result_path.read_text()}"
                    )
            raise AssertionError(output + "\n\n" + "\n\n".join(dumps))

        for peer in peers:
            rc = peer.wait(PEER_WAIT_SECONDS)
            assert rc == 0, f"{peer.mode} peer tag {peer.tag} exited {rc}"
            validate_multi_instance_peer_result(
                peer.mode, peer.tag, peer.read_result()
            )
    finally:
        terminate_peers(peers)
