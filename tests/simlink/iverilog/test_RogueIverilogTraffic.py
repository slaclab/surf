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
# - Sweep: One RogueSvTrafficTb top (Stream0 throttled loopback, Stream1
#   direct/sustained loopback, Stream2 128-byte direct loopback, Memory0
#   AXI-Lite RAM, SideBand0 opcode/remote-data exchange) run under Icarus
#   with live pyzmq peers.
# - Stimulus: Build RogueSimLink.vpi, compile the TB with iverilog -g2012,
#   spawn one peer per active instance (stream/stream/stream/memory/
#   sideband), wait until every peer reports its ZeroMQ sockets are
#   connected, then run vvp.
# - Checks: vvp prints the RogueSvTrafficTb passed banner and exits 0, and
#   every peer exits 0 with byte-exact round-tripped frames/transactions. The
#   HDL top itself self-checks flop-equivalent timing, stall/gap coverage,
#   the sustained-rate bubble-free/SOF invariants, the AXI-Lite RAM's stalled
#   request stability, and the SideBand one-cycle opcode event; a hang is
#   caught by the TB's own watchdog well inside this test's process-level
#   timeouts.
# - Timing: Measured ~80000 edges/second on this host (a passing run
#   completes by edge ~21000, well under one second); WAIT_EDGES_G is set so
#   the watchdog trips after roughly 20 s of wall clock on a hang, safely
#   inside iverilog_test_utils.RUN_TIMEOUT_SECONDS. Skips when Icarus/libzmq
#   tools are absent or the local Icarus is older than MIN_IVERILOG_MAJOR.

import pytest

from tests.simlink.common.sv_traffic_scenario import run_sv_traffic
from tests.simlink.iverilog import iverilog_test_utils as iu
from tests.simlink.paths import sim_build_dir
from tests.simlink.ports import IVERILOG_TRAFFIC

pytestmark = pytest.mark.skipif(not iu.tools_available(), reason=iu.SKIP_REASON)

SIM_BUILD = sim_build_dir("iverilog", "RogueSvTraffic")
BASE_PORT = IVERILOG_TRAFFIC.port_pair(0).first
# ~80000 edges/second measured this session; a passing run completes by edge
# ~21000. 1_600_000 edges is ~20 s of wall clock on a hang.
WAIT_EDGES_G = 1_600_000


@pytest.fixture(scope="module", autouse=True)
def build_vpi_module():
    iu.build_vpi_module()


def test_iverilog_traffic_exchanges_stream_beats():
    vvp_path = iu.compile_tb(
        SIM_BUILD,
        {"BASE_PORT_G": BASE_PORT, "WAIT_EDGES_G": WAIT_EDGES_G},
    )

    def run_sim():
        return iu.run_tb(SIM_BUILD)

    run_sv_traffic(run_sim, BASE_PORT, SIM_BUILD / "peers")
    assert vvp_path.exists()
