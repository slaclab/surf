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
#   the real Vivado xsim mixed-language/DPI flow with live peers. (Stream only
#   for now; Memory/SideBand added in later tasks.)
# - Stimulus: Launch one rogue_tcp_peer.py per instance (each --tag i) before
#   xsim starts; the top holds off outbound traffic for a fixed settle delay
#   so peers are connected and draining, then exchanges a tagged family per
#   instance.
# - Checks: xsim prints the success banner, every peer exits 0, and each
#   peer's JSON shows only its own tag family with zero foreign tags.
# - Timing: The top uses bounded clock loops; each peer bounds recv with
#   RCVTIMEO; xsim is wall-clock bounded. Skips when Vivado tools are absent.

import json
import subprocess
import sys

import pytest

from tests.axi.simlink import xsim_test_utils as xu

HERE = xu.REPO_ROOT / "tests" / "axi" / "simlink"
TB_SOURCE = HERE / "RogueXsimTrafficTb.vhd"
SIM_BUILD = HERE / "sim_build_RogueXsimTraffic"
PEER = HERE / "rogue_tcp_peer.py"
VHDL_SOURCES = [*xu.MODEL_VHDL_SOURCES, TB_SOURCE]

pytestmark = pytest.mark.skipif(not xu.tools_available(), reason=xu.SKIP_REASON)

PEER_WAIT_SECONDS = 30

STREAM_PEERS = [("stream", i, 19740 + 2 * i) for i in range(4)]


@pytest.fixture(scope="module", autouse=True)
def build_dpi_library():
    xu.build_dpi_library()


def _spawn_peers(specs, result_dir):
    result_dir.mkdir(parents=True, exist_ok=True)
    procs = []
    for mode, tag, port in specs:
        result_path = result_dir / f"{mode}_{tag}_{port}.json"
        procs.append((
            mode, tag, port, result_path,
            subprocess.Popen(
                [sys.executable, str(PEER), "--mode", mode, "--tag", str(tag),
                 str(port), str(result_path)],
                env=xu.xsim_run_env(),
            ),
        ))
    return procs


def _reap(procs):
    for _, _, _, _, proc in procs:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()


def test_xsim_stream_instances_exchange_isolated_traffic():
    result_dir = SIM_BUILD / "peers"
    procs = _spawn_peers(STREAM_PEERS, result_dir)
    try:
        result = xu.run_top("RogueXsimTrafficTb", VHDL_SOURCES, SIM_BUILD)
        output = result.stdout + result.stderr
        assert "Rogue xsim traffic test passed" in output, output

        for mode, tag, port, result_path, proc in procs:
            rc = proc.wait(timeout=PEER_WAIT_SECONDS)
            assert rc == 0, f"{mode} peer tag {tag} exited {rc}"
            observed = json.loads(result_path.read_text())
            own = bytes([(0x80 + tag) & 0xFF] * 4).hex()
            for frame in observed["received"]:
                assert frame["data_hex"] == own, (tag, frame)
    finally:
        _reap(procs)
