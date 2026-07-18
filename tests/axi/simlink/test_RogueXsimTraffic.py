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
#   peer's JSON shows only its own tag family with zero foreign tags.
# - Timing: The top uses bounded clock loops; each peer bounds recv with
#   RCVTIMEO; xsim is wall-clock bounded. Skips when Vivado tools are absent.

import json
import subprocess
import sys
import time

import pytest

from tests.axi.simlink import xsim_test_utils as xu
from tests.axi.simlink.rogue_tcp_peer import (
    memory_instance_transactions,
    sideband_instance_vectors,
    stream_instance_vectors,
)

HERE = xu.REPO_ROOT / "tests" / "axi" / "simlink"
TB_SOURCE = HERE / "RogueXsimTrafficTb.vhd"
SIM_BUILD = HERE / "sim_build_RogueXsimTraffic"
PEER = HERE / "rogue_tcp_peer.py"
VHDL_SOURCES = [*xu.MODEL_VHDL_SOURCES, TB_SOURCE]

pytestmark = pytest.mark.skipif(not xu.tools_available(), reason=xu.SKIP_REASON)

PEER_WAIT_SECONDS = 30
PEER_READY_SECONDS = 10

# Endpoint port map (single source of truth is shared with
# RogueXsimTrafficTb.vhd -- keep both in sync):
#   Stream   i -> 19740 + 2*i  (19740..19747)
#   Memory   i -> 19748 + 2*i  (19748..19751)
#   SideBand i -> 19752 + 2*i  (19752..19755)
STREAM_PEERS = [("stream-instance", i, 19740 + 2 * i) for i in range(4)]
MEMORY_PEERS = [("memory-instance", i, 19748 + 2 * i) for i in range(2)]
SIDEBAND_PEERS = [("sideband-instance", i, 19752 + 2 * i) for i in range(2)]


@pytest.fixture(scope="module", autouse=True)
def build_dpi_library():
    xu.build_dpi_library()


def _spawn_peers(specs, result_dir):
    result_dir.mkdir(parents=True, exist_ok=True)
    procs = []
    for mode, tag, port in specs:
        result_path = result_dir / f"{mode}_{tag}_{port}.json"
        ready_path = result_dir / f"{mode}_{tag}_{port}.ready"
        result_path.unlink(missing_ok=True)
        ready_path.unlink(missing_ok=True)
        procs.append((
            mode, tag, port, result_path, ready_path,
            subprocess.Popen(
                [sys.executable, str(PEER), "--mode", mode, "--tag", str(tag),
                 "--ready-file", str(ready_path),
                 str(port), str(result_path)],
                env=xu.xsim_run_env(),
            ),
        ))
    return procs


def _wait_for_peers_ready(procs):
    deadline = time.monotonic() + PEER_READY_SECONDS
    while time.monotonic() < deadline:
        failed = [
            (mode, tag, proc.returncode)
            for mode, tag, _, _, _, proc in procs
            if proc.poll() is not None
        ]
        if failed:
            raise AssertionError(f"peer exited before readiness: {failed}")
        if all(ready_path.exists() for _, _, _, _, ready_path, _ in procs):
            return
        time.sleep(0.01)
    pending = [
        (mode, tag, port)
        for mode, tag, port, _, ready_path, _ in procs
        if not ready_path.exists()
    ]
    raise TimeoutError(f"peers did not signal readiness within {PEER_READY_SECONDS}s: {pending}")


def _reap(procs):
    for _, _, _, _, _, proc in procs:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()


def test_xsim_instances_exchange_isolated_traffic():
    result_dir = SIM_BUILD / "peers"
    # Elaborate first, then spawn peers just before the run. Wait for every
    # ready file so Python startup and socket configuration are deterministic;
    # the HDL settle delay covers the asynchronous connect handshake after the
    # model binds. This also keeps xvlog/xvhdl/xelab outside RCVTIMEO.
    xu.compile_and_elaborate("RogueXsimTrafficTb", VHDL_SOURCES, SIM_BUILD)
    procs = _spawn_peers(STREAM_PEERS + MEMORY_PEERS + SIDEBAND_PEERS, result_dir)
    try:
        _wait_for_peers_ready(procs)
        result = xu.run_elaborated("RogueXsimTrafficTb", SIM_BUILD)
        output = result.stdout + result.stderr
        if "Rogue xsim traffic test passed" not in output:
            # Append every peer's JSON so a banner miss is diagnosable.
            dumps = []
            for _, _, _, result_path, _, _ in procs:
                if result_path.exists():
                    dumps.append(f"{result_path.name}:\n{result_path.read_text()}")
            raise AssertionError(output + "\n\n" + "\n\n".join(dumps))

        for mode, tag, port, result_path, _, proc in procs:
            rc = proc.wait(timeout=PEER_WAIT_SECONDS)
            assert rc == 0, f"{mode} peer tag {tag} exited {rc}"
            observed = json.loads(result_path.read_text())
            if mode == "stream-instance":
                # Explicit foreign-tag rejection: every received frame must
                # carry this instance's own tag (0x80+tag)*4 and nothing else.
                # The peer's stream_frame_is_foreign() already rejects any
                # 0x80+j (j != tag) at the source (forcing rc != 0, caught by
                # the rc == 0 assertion above); requiring == own here is the
                # same isolation guarantee restated on the received data.
                own = stream_instance_vectors(tag)[1][0]["data"].hex()
                for frame in observed["received"]:
                    assert frame["data_hex"] == own, (tag, frame)
            elif mode == "memory-instance":
                # Memory: every txn OKAY, and the read-back data equals this
                # tag's write vector -- itself the cross-instance isolation
                # check, since a foreign instance's data would differ.
                txns = observed["transactions"]
                assert txns, (tag, observed)
                for txn in txns:
                    assert txn["resp"] == 0, (tag, txn)
                own = memory_instance_transactions(tag)[0]["write_data"].hex()
                reads = [t for t in txns if t["type"] == 0x1]
                assert reads, (tag, observed)
                for txn in reads:
                    assert txn["data_hex"] == own, (tag, txn)
                # Explicit foreign-tag rejection: no transaction may carry
                # another memory instance's write vector. A write txn may have
                # an empty data_hex, so allow "" or own; forbid any other
                # instance's payload outright (the two memory tags are 0..1).
                foreign_hex = {
                    bytes([0x40 + j, 0x50 + j, 0x60 + j, 0x70 + j]).hex()
                    for j in range(2) if j != tag
                }
                for txn in txns:
                    assert txn["data_hex"] in ("", own), (tag, txn)
                    assert txn["data_hex"] not in foreign_hex, (tag, txn)
            elif mode == "sideband-instance":
                # SideBand: the peer's received frames are the DUT's tx values
                # echoed back -- an opcode 0x60+tag and a remData 0x70+tag. A
                # foreign instance would surface a different tag, so requiring
                # this instance's exact opcode/remData is the isolation check.
                received = observed["received"]
                _, own_opcode, own_remdata = sideband_instance_vectors(tag)
                assert any(
                    f["opCodeEn"] == 1 and f["opCode"] == own_opcode
                    for f in received
                ), (tag, observed)
                assert any(
                    f["remDataChanged"] == 1 and f["remData"] == own_remdata
                    for f in received
                ), (tag, observed)
                # Explicit foreign-tag rejection: no received frame may carry
                # another sideband instance's opcode or remData. The two
                # sideband tags are 0..1, so a foreign frame would surface
                # opCode 0x60+j or remData 0x70+j for j != tag.
                for j in range(2):
                    if j == tag:
                        continue
                    assert not any(
                        f["opCodeEn"] == 1 and f["opCode"] == 0x60 + j
                        for f in received
                    ), (tag, j, observed)
                    assert not any(
                        f["remDataChanged"] == 1 and f["remData"] == 0x70 + j
                        for f in received
                    ), (tag, j, observed)
            else:
                raise AssertionError(f"unknown peer mode {mode}")
    finally:
        _reap(procs)
