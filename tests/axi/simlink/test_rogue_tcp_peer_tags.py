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
#   scheme in the plan mandates, and distinct tags never collide.
# - Timing: None -- pure functions.

from tests.axi.simlink.rogue_tcp_peer import (
    stream_peer_to_dut_payload,
    stream_dut_to_peer_payload,
    memory_txn_for_tag,
    sideband_peer_to_dut,
    sideband_expect_for_tag,
)


def test_stream_payloads_match_scheme():
    for i in range(4):
        assert stream_peer_to_dut_payload(i) == bytes([0x10 + i] * 4)
        assert stream_dut_to_peer_payload(i) == bytes([0x80 + i] * 4)


def test_memory_txn_matches_scheme():
    for i in range(2):
        txn = memory_txn_for_tag(i)
        assert txn["addr"] == 0x100 + (0x10 * i)
        assert txn["size"] == 4
        assert txn["write_data"] == bytes([0x40 + i, 0x50 + i, 0x60 + i, 0x70 + i])


def test_sideband_vectors_match_scheme():
    for i in range(2):
        frames = sideband_peer_to_dut(i)
        assert frames[0] == {"opCodeEn": 1, "opCode": 0x20 + i, "remDataChanged": 0, "remData": 0x00}
        assert frames[1] == {"opCodeEn": 0, "opCode": 0x00, "remDataChanged": 1, "remData": 0x40 + i}
        assert sideband_expect_for_tag(i) == {"opCode": 0x60 + i, "remData": 0x70 + i}


def test_distinct_tags_do_not_collide():
    assert stream_dut_to_peer_payload(0) != stream_dut_to_peer_payload(1)
    assert memory_txn_for_tag(0)["addr"] != memory_txn_for_tag(1)["addr"]
    assert sideband_expect_for_tag(0) != sideband_expect_for_tag(1)
