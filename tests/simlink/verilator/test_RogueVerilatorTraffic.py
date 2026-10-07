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
#   AXI-Lite RAM, SideBand0 opcode/remote-data exchange) run under Verilator
#   with live pyzmq peers -- the same top and scenario the Icarus suite runs.
# - Stimulus: Build the TB and libRogueSimLinkDpi.so through ruckus (an
#   abi-check, then make build on simlink/test/sv with system_verilator.mk),
#   spawn one peer per active instance (stream/stream/stream/memory/
#   sideband), wait until every peer reports its ZeroMQ sockets are
#   connected, then launch the compiled binary through ruckus's tb target.
# - Checks: the binary prints the RogueSvTrafficTb passed banner and exits 0,
#   and every peer exits 0 with byte-exact round-tripped frames/transactions.
#   The HDL top itself self-checks flop-equivalent timing, stall/gap
#   coverage, the sustained-rate bubble-free/SOF invariants, the AXI-Lite
#   RAM's stalled request stability, and the SideBand one-cycle opcode
#   event; a hang is caught by the TB's own watchdog well inside this test's
#   process-level timeouts.
# - Timing: measured ~235000 edges/second on this host (a passing run
#   completes by edge ~69500 in well under a second); WAIT_EDGES_G is set so
#   the watchdog trips after roughly 20 s of wall clock on a hang, safely
#   inside verilator_test_utils.RUN_TIMEOUT_SECONDS. Skips when
#   Verilator/libzmq tools are absent or the local Verilator is older than
#   MIN_VERILATOR.

import pytest

from tests.simlink.common.sv_traffic_scenario import run_sv_traffic
from tests.simlink.paths import sim_build_dir
from tests.simlink.ports import VERILATOR_TRAFFIC
from tests.simlink.verilator import verilator_test_utils as vu

pytestmark = pytest.mark.skipif(not vu.tools_available(), reason=vu.SKIP_REASON)

SIM_BUILD = sim_build_dir("verilator", "RogueSvTraffic")
BASE_PORT = VERILATOR_TRAFFIC.port_pair(0).first
# ~235000 edges/second measured this session; a passing run completes by
# edge ~69500. 5_000_000 edges is ~21 s of wall clock on a hang.
WAIT_EDGES_G = 5_000_000


def test_verilator_traffic_exchanges_stream_beats():
    binary_path = vu.build_tb(
        SIM_BUILD,
        {"BASE_PORT_G": BASE_PORT, "WAIT_EDGES_G": WAIT_EDGES_G},
    )

    def run_sim():
        return vu.run_tb(SIM_BUILD)

    run_sv_traffic(run_sim, BASE_PORT, SIM_BUILD / "peers")
    assert binary_path.exists()
