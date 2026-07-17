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
#   the real Vivado xsim mixed-language/DPI flow with live peers. (Stream +
#   Memory for now; SideBand added in a later task.)
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

# Endpoint port map (single source of truth is shared with
# RogueXsimTrafficTb.vhd -- keep both in sync):
#   Stream i -> 19740 + 2*i  (19740..19747)
#   Memory i -> 19748 + 2*i  (19748..19751)
STREAM_PEERS = [("stream", i, 19740 + 2 * i) for i in range(4)]
MEMORY_PEERS = [("memory", i, 19748 + 2 * i) for i in range(2)]


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
    # Elaborate first, then spawn peers just before the run: the peers'
    # RCVTIMEO budget must cover only the short simulation, not the
    # multi-second xvlog/xvhdl/xelab flow (during which a peer would otherwise
    # time out and exit, wedging the DUT's synchronous ZMQ send).
    xu.compile_and_elaborate("RogueXsimTrafficTb", VHDL_SOURCES, SIM_BUILD)
    procs = _spawn_peers(STREAM_PEERS + MEMORY_PEERS, result_dir)
    try:
        result = xu.run_elaborated("RogueXsimTrafficTb", SIM_BUILD)
        output = result.stdout + result.stderr
        if "Rogue xsim traffic test passed" not in output:
            # Append every peer's JSON so a banner miss is diagnosable.
            dumps = []
            for _, _, _, result_path, _ in procs:
                if result_path.exists():
                    dumps.append(f"{result_path.name}:\n{result_path.read_text()}")
            raise AssertionError(output + "\n\n" + "\n\n".join(dumps))

        for mode, tag, port, result_path, proc in procs:
            rc = proc.wait(timeout=PEER_WAIT_SECONDS)
            assert rc == 0, f"{mode} peer tag {tag} exited {rc}"
            observed = json.loads(result_path.read_text())
            if mode == "stream":
                own = bytes([(0x80 + tag) & 0xFF] * 4).hex()
                for frame in observed["received"]:
                    assert frame["data_hex"] == own, (tag, frame)
            else:
                # Memory: every txn OKAY, and the read-back data equals this
                # tag's write vector -- itself the cross-instance isolation
                # check, since a foreign instance's data would differ.
                txns = observed["transactions"]
                assert txns, (tag, observed)
                for txn in txns:
                    assert txn["resp"] == 0, (tag, txn)
                own = bytes([0x40 + tag, 0x50 + tag, 0x60 + tag, 0x70 + tag]).hex()
                reads = [t for t in txns if t["type"] == 0x1]
                assert reads, (tag, observed)
                for txn in reads:
                    assert txn["data_hex"] == own, (tag, txn)
    finally:
        _reap(procs)
