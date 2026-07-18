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
# - Sweep: Each instance index used by the xsim traffic top (Stream 0-3,
#   Memory 0-1, SideBand 0-1) fed to the peer's per-tag vector helpers.
# - Stimulus: Call the pure helper functions directly; no simulator, no ZMQ.
# - Checks: Each helper returns the exact byte/address/opcode values the tag
#   scheme mandates, distinct tags never collide, and the test-only ready-file
#   handshake reports success or an early peer exit deterministically.
# - Timing: None -- pure functions.

import pytest

from tests.axi.simlink import rogue_tcp_peer
from tests.axi.simlink.rogue_tcp_peer import (
    memory_instance_transactions,
    sideband_instance_vectors,
    stream_instance_vectors,
)
from tests.axi.simlink.test_RogueXsimTraffic import _wait_for_peers_ready


class _FakeProcess:
    def __init__(self, returncode=None):
        self.returncode = returncode

    def poll(self):
        return self.returncode


def test_stream_payloads_match_scheme():
    for i in range(4):
        peer_to_dut, dut_to_peer = stream_instance_vectors(i)
        assert peer_to_dut[0]["data"] == bytes([0x10 + i, 0x20 + i, 0x30 + i, 0x40 + i])
        assert dut_to_peer[0]["data"] == bytes([0x80 + i, 0x90 + i, 0xA0 + i, 0xB0 + i])


def test_memory_txn_matches_scheme():
    for i in range(2):
        txn = memory_instance_transactions(i)[0]
        assert txn["addr"] == 0x100 + (0x10 * i)
        assert txn["size"] == 4
        assert txn["write_data"] == bytes([0x40 + i, 0x50 + i, 0x60 + i, 0x70 + i])


def test_sideband_vectors_match_scheme():
    for i in range(2):
        frames, tx_opcode, tx_remdata = sideband_instance_vectors(i)
        assert frames[0] == {"opCodeEn": 1, "opCode": 0x20 + i, "remDataChanged": 0, "remData": 0x00}
        assert frames[1] == {"opCodeEn": 0, "opCode": 0x00, "remDataChanged": 1, "remData": 0x40 + i}
        assert tx_opcode == 0x60 + i
        assert tx_remdata == 0x70 + i


def test_distinct_tags_do_not_collide():
    assert stream_instance_vectors(0) != stream_instance_vectors(1)
    assert memory_instance_transactions(0) != memory_instance_transactions(1)
    assert sideband_instance_vectors(0) != sideband_instance_vectors(1)


def test_argparse_dispatches_instance_tag(monkeypatch, tmp_path):
    observed = {}

    def fake_run(port, result_path, send_frames, expect_frames, ready_file=None):
        observed.update(
            port=port,
            result_path=result_path,
            send_frames=send_frames,
            expect_frames=expect_frames,
            ready_file=ready_file,
        )
        return 0

    result_path = tmp_path / "stream.json"
    ready_path = tmp_path / "stream.ready"
    monkeypatch.setattr(rogue_tcp_peer, "run_stream_peer", fake_run)
    assert rogue_tcp_peer.main([
        "--mode", "stream-instance", "--tag", "2",
        "--ready-file", str(ready_path), "19740", str(result_path),
    ]) == 0
    assert observed["port"] == 19740
    assert observed["result_path"] == str(result_path)
    assert observed["ready_file"] == str(ready_path)
    assert (observed["send_frames"], observed["expect_frames"]) == stream_instance_vectors(2)


def test_ready_file_is_written_after_socket_setup_hook(tmp_path):
    ready_path = tmp_path / "peer.ready"
    rogue_tcp_peer._signal_ready(ready_path)
    assert ready_path.read_text() == "ready\n"


def test_orchestrator_accepts_ready_peer(tmp_path):
    ready_path = tmp_path / "peer.ready"
    ready_path.write_text("ready\n")
    procs = [("stream-instance", 0, 19740, tmp_path / "result.json", ready_path, _FakeProcess())]
    _wait_for_peers_ready(procs)


def test_orchestrator_rejects_peer_exit_before_ready(tmp_path):
    procs = [(
        "stream-instance",
        0,
        19740,
        tmp_path / "result.json",
        tmp_path / "missing.ready",
        _FakeProcess(returncode=3),
    )]
    with pytest.raises(AssertionError, match="peer exited before readiness"):
        _wait_for_peers_ready(procs)
