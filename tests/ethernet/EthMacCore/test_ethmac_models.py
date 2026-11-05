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
# - Sweep: Simulator-free known-answer and negative checks for the independent
#   checksum helpers, top scoreboard and ready/valid stall checker.
# - Stimulus: Fixed checksum/FCS vectors, reversed and missing RX deliveries,
#   error-marked or unterminated TX frames, partial output and stalled beats
#   with each field changed independently.
# - Checks: Valid controls pass; each deliberately corrupted observation must
#   fail its corresponding assertion. Overflow may delete but never reorder.
# - Timing: No simulator or clocks; sampled edge sequences are explicit.

from dataclasses import replace
from types import SimpleNamespace

import pytest

from tests.ethernet.EthMacCore.ethmac_line_models import LineFrame, build_udp_segment, fcs_bytes
from tests.ethernet.EthMacCore.ethmac_test_utils import EmacBeat, EmacStallChecker, build_pause_frame, internet_checksum
from tests.ethernet.EthMacCore.test_EthMacTopScoreboard import (
    STREAM_TX_PRIM,
    TopBench,
    TopConfig,
    padded_line_frame,
)


def test_checksum_known_answers():
    # RFC 1071 example: folded sum DDF2, complement 220D.
    assert internet_checksum(bytes.fromhex("0001f203f4f5f6f7")) == 0x220D
    # Odd octet is the high byte of a final zero-padded word: 0102 + 0300.
    assert internet_checksum(bytes.fromhex("010203")) == 0xFBFD
    assert internet_checksum(bytes.fromhex("450000730000400040110000c0a80001c0a800c7")) == 0xB861
    # CRC-32/ISO-HDLC standard check string, Ethernet least-significant octet first.
    assert fcs_bytes(b"123456789") == bytes.fromhex("2639f4cb")


def test_udp_computed_zero_and_explicit_disabled():
    args = dict(src_ip="0.0.0.0", dst_ip="0.0.0.0", src_port=1, dst_port=2, payload=bytes.fromhex("ffd7"))
    # Pseudoheader 0011+000A, UDP 0001+0002+000A, payload FFD7 sum to FFFF.
    assert build_udp_segment(**args) == bytes.fromhex("00010002000affffffd7")
    assert build_udp_segment(**args, checksum=0) == bytes.fromhex("00010002000a0000ffd7")


@pytest.fixture
def bench(monkeypatch):
    monkeypatch.setenv("PHY_TYPE_G", "XGMII")
    cfg = replace(TopConfig.from_env(), seed=1, drop_err=True, fifo_addr_width=11, byp_en=True, jumbo_frames=False)
    result = TopBench(SimpleNamespace(pauseTime=SimpleNamespace(value=16)), cfg)
    result.line_tx = SimpleNamespace(frames=[], frame_pending=False)
    return result


def deliver(bench, exp):
    bench._check_delivery(exp.deliver, exp.frame, exp.eofe, True)


def test_rx_order_per_destination(bench):
    first, _ = bench._new_rx(kind="good", length=64)
    bypass, _ = bench._new_rx(kind="bypass", length=64)
    second, _ = bench._new_rx(kind="good", length=64)
    # Independent destinations may progress at different rates.
    for exp in (bypass, first, second):
        deliver(bench, exp)
    bench.assert_clean()


@pytest.mark.parametrize("overflow", [False, True])
def test_rx_reordering_rejected(bench, overflow):
    bench.cfg.fifo_addr_width = 9 if overflow else 11
    first, _ = bench._new_rx(kind="good", length=64)
    second, _ = bench._new_rx(kind="good", length=64)
    deliver(bench, second)
    deliver(bench, first)
    with pytest.raises(AssertionError, match="out of order"):
        bench.assert_clean()


def test_rx_overflow_allows_missing_prefix(bench):
    bench.cfg.fifo_addr_width = 9
    bench._new_rx(kind="good", length=64)
    survivor, _ = bench._new_rx(kind="good", length=64)
    deliver(bench, survivor)
    bench.assert_clean()
    assert bench.lost_rx() == 1


@pytest.mark.parametrize("pause", [False, True])
@pytest.mark.parametrize("fault", [None, "error", "unterminated"])
def test_line_error_and_termination(bench, pause, fault):
    frame = build_pause_frame(16) if pause else padded_line_frame("XGMII", bench._new_tx(STREAM_TX_PRIM).frame)
    bench.line_tx.frames = [LineFrame(raw=b"", frame=frame, fcs_ok=True, preamble_ok=True,
                                     error=fault == "error", start_cycle=1, end_cycle=10, ifg=None,
                                     terminated=fault != "unterminated")]
    bench.check_line()
    if fault:
        with pytest.raises(AssertionError, match="error=.*terminated="):
            bench.assert_clean()
    else:
        bench.assert_clean()


@pytest.mark.parametrize("phy", [False, True])
def test_partial_frame_rejected(bench, phy):
    if phy:
        bench.line_tx.frame_pending = True
    else:
        bench.open_beats["prim"].append((b"partial", 1, 0))
    with pytest.raises(AssertionError, match="unfinished"):
        bench.assert_clean()


@pytest.mark.parametrize("field", ["data", "keep", "last", "dest", "sof", "frag", "eofe", "iperr", "tcperr", "udperr", "valid"])
def test_stall_checker_detects_changed_beat(field):
    checker = EmacStallChecker()
    beat = EmacBeat(data=123, keep=0xFFFF, last=1)
    checker.sample(valid=1, ready=0, beat=beat)
    changed = beat if field == "valid" else replace(beat, **{field: getattr(beat, field) ^ 1})
    with pytest.raises(AssertionError, match="stalled EMAC beat changed"):
        checker.sample(valid=int(field != "valid"), ready=1, beat=changed)


def test_stall_acceptance_and_reset():
    checker = EmacStallChecker()
    beat = EmacBeat(data=1, keep=1, last=1)
    checker.sample(valid=1, ready=0, beat=beat)
    checker.sample(valid=1, ready=0, beat=replace(beat))
    checker.sample(valid=1, ready=1, beat=replace(beat))
    checker.sample(valid=0, ready=0, beat=None)
    checker.sample(valid=1, ready=0, beat=beat)
    checker.sample(valid=0, ready=0, beat=None, reset=True)
    checker.sample(valid=1, ready=1, beat=replace(beat, data=2))
