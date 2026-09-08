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
# - Sweep: Both oscillator signs, large epochs, correction/asymmetry signs,
#   125/156.25 MHz PHCs, queue pressure, and bounded sequence wrap.
# - Stimulus: Independent rational-time worlds, random integer PHC commands,
#   reordered messages, generation changes, and retired TX completions.
# - Checks: Expose the rejected keyed/equal-rate counterexamples and verify
#   the proposed arithmetic, atomic queue, and lifecycle contracts.
# - Timing: These are Python reference-model tests, not PTP RTL validation;
#   watchdog ticks never follow stepped PHC time and TX keys remain reserved.

from fractions import Fraction
from dataclasses import replace
import random

import pytest

from tests.ethernet.PtpCore.ptp_reference import (
    AtomicCaptureQueue, Capture, KeyedJoin, MAX_SECONDS, NS, PhcCommand,
    PhcModel, Q16, Q32, RequestLedger, SnapshotMailbox, checked_signed, e2e, e2e_q16, estimate_rate,
    nearest, rate_addend,
)


@pytest.mark.parametrize("ppm", [-100, -10, 0, 10, 100])
@pytest.mark.parametrize("separation_ns", [10_000, 10_000_000, NS])
def test_unequal_rate_bootstrap(ppm, separation_ns):
    # Construct events from physical propagation, without using the E2E solver.
    rate = 1 + Fraction(ppm, 1_000_000)
    delay = Fraction(20)
    epoch = (1 << 46) * NS
    offset = -(1 << 45) * NS
    t1 = Fraction(epoch)
    t2 = (t1 + delay) * rate + offset
    t3 = (t1 + delay + separation_ns) * rate + offset
    t4 = t1 + 2 * delay + separation_ns
    naive, _ = e2e(t1, t2, t3, t4)
    assert naive == delay - (rate - 1) * separation_ns / 2
    if ppm > 0 and separation_ns >= 10_000_000:
        assert naive < 0  # A pre-servo nonnegative-delay filter deadlocks here.
    # A rate estimate uses Sync observations alone, independent of path-delay validity.
    ticks_a, ticks_b = (t1 + delay) * rate, (t1 + NS + delay) * rate
    ratio = estimate_rate(t1, t1 + NS, ticks_a, ticks_b)
    actual, measured_offset = e2e(t1, t2, t3, t4, local_elapsed=ratio * (t3 - t2))
    assert actual == delay
    assert measured_offset == t2 - (t1 + delay)


@pytest.mark.parametrize("asymmetry", [-7, 0, 11])
@pytest.mark.parametrize("correction", [-Fraction(7, 16), Fraction(13, 8)])
def test_corrections_and_rate_change(asymmetry, correction):
    t1 = Fraction(987654321 * NS)
    forward, reverse = 100 + asymmetry, 100 - asymmetry
    offset = 123456
    elapsed = Fraction(500_000)
    t2 = t1 + correction + forward + offset
    # Numerical PHC rate changes midway; the unsteered interval is unaffected.
    phc_elapsed = elapsed / 2 + elapsed / 2 * Fraction(100005, 100000)
    t3 = t2 + phc_elapsed
    t4 = t1 + correction + forward + elapsed + reverse + correction
    delay, error = e2e(t1, t2, t3, t4, correction, correction, elapsed, asymmetry)
    assert delay == 100
    assert error == offset
    assert e2e(t1, t2, t3, t4, correction, correction)[0] != delay


@pytest.mark.parametrize("rate", [125_000_000, 156_250_000])
def test_phc_against_scalar_oracle(rate):
    rng = random.Random(rate)
    phc = PhcModel(rate)
    expected = Fraction(0)
    applied_rate = 0
    for index in range(4000):
        command = None
        if index % 113 == 0:
            command = PhcCommand("set", ((1 << 40) * NS + NS - 2) * Q32 + rng.randrange(Q32), phc.generation)
        elif index % 47 == 0:
            command = PhcCommand("phase", rng.randrange(-10000, 10000) * Q16, phc.generation)
        elif index % 19 == 0:
            command = PhcCommand("rate", rate_addend(phc.nominal, rng.randrange(-100000, 100000) * Q16), phc.generation)
        before = expected
        expected += Fraction(phc.nominal + applied_rate, Q32)
        if command:
            assert phc.submit(command)
            with pytest.raises(RuntimeError):
                phc.submit(command)
            if command.kind == "set":
                expected = Fraction(command.value, Q32)
            elif command.kind == "phase":
                expected += Fraction(command.value, Q16)
            else:
                applied_rate = command.value
        capture, pps = phc.tick()
        assert Fraction(phc.time_q32, Q32) == expected
        discontinuity = command and command.kind in ("phase", "set")
        assert pps == (not discontinuity and expected // NS > before // NS)
        assert (capture is None) == bool(discontinuity)
        assert 0 <= phc.nanoseconds < NS and 0 <= phc.fraction < Q32
        assert phc.ticks == index + 1


def test_generation_reset_and_wide_commit_delta():
    phc = PhcModel(125_000_000)
    old_generation = phc.generation
    delta = (1 << 40) * NS * Q16
    phc.submit(PhcCommand("phase", delta, phc.generation))
    assert phc.tick() == (None, False)
    assert phc.time_q32 == (1 << 40) * NS * Q32 + 8 * Q32
    assert not phc.submit(PhcCommand("phase", delta, old_generation))
    phc.submit(PhcCommand("valid", 1, phc.generation))
    phc.tick()
    assert phc.valid
    phc.submit(PhcCommand("phase", -delta, phc.generation))
    phc.tick(reset=True)
    assert phc.time_q32 == 0 and not phc.valid and phc.pending is None
    assert phc.ticks == 3


def test_boundaries_and_fixed_point_units():
    for value, expected in [(Fraction(1, 2), 1), (Fraction(-1, 2), -1),
                            (Fraction(3, 2), 2), (Fraction(-3, 2), -2)]:
        assert nearest(value) == expected
    assert abs(Fraction(nearest(Fraction(32, 5) * Q32), Q32) - Fraction(32, 5)) < Fraction(1, Q32)
    assert rate_addend(8 * Q32, 100000 * Q16) == nearest(Fraction(8 * Q32, 10000))
    with pytest.raises(OverflowError):
        checked_signed(1 << 127, 128)
    phc = PhcModel(125_000_000)
    with pytest.raises(ValueError):
        phc.submit(PhcCommand("rate", -phc.nominal, phc.generation))
    phc.submit(PhcCommand("set", MAX_SECONDS * NS * Q32 - 1, phc.generation))
    phc.tick()
    with pytest.raises(OverflowError):
        phc.tick()


def test_keyed_counterexample_and_atomic_alternative():
    key = (0, 0, 1, 42)
    bad_a, good_b = Capture(key, 0, Fraction(100), valid=False), Capture(key, 1, Fraction(200))
    keyed = KeyedJoin()
    # The header-only tap sees no coding error and has no FCS checker. Its
    # event-valid bit is true even though the independent oracle knows FCS is bad.
    keyed.event(replace(bad_a, valid=True))
    keyed.frame(key, 1)
    event, delivered_wire_id = keyed.match(key)
    assert event.wire_id != delivered_wire_id
    keyed.event(good_b)  # Detection now would be too late to retract a committed sample.
    atomic = AtomicCaptureQueue()
    atomic.edge(bad_a)
    atomic.edge(good_b)
    assert atomic.edge(ready=True) == good_b
    assert atomic.edge(ready=True) is None


@pytest.mark.parametrize("depth", [1, 2, 4])
def test_atomic_overflow_and_generation(depth):
    queue = AtomicCaptureQueue(depth=depth)
    for wire_id in range(depth):
        queue.edge(Capture((wire_id,), wire_id, Fraction(wire_id)))
    # A full queue flushes even when ready arrives on the overflow edge.
    assert queue.edge(Capture((9,), 9, Fraction(9)), ready=True) is None
    assert queue.overflows == 1 and not queue.entries
    queue.edge(Capture((10,), 10, Fraction(10), generation=0))
    assert not queue.entries
    fresh = Capture((11,), 11, Fraction(11), generation=queue.generation)
    queue.edge(fresh)
    assert queue.edge(ready=True) == fresh
    queue.edge(fresh)
    assert queue.edge(ready=True, flush=True) is None


def test_tx_retirement_early_response_and_wrap():
    ledger = RequestLedger(lifetime=100, sequence_bits=2)
    seq = ledger.allocate(0)
    assert not ledger.response(seq, 50)  # RX can precede delivery of the TX event.
    assert ledger.wire(seq, 25)
    ledger.reap(125)
    assert seq in ledger.requests  # Equality is still inside quarantine.
    ledger.reap(126)
    assert seq not in ledger.requests
    pending = ledger.allocate(130)
    ledger.restart()
    assert not ledger.response(pending, 1000)
    ledger.reap(10000)
    assert pending in ledger.requests  # No wire completion: pause is unbounded.
    assert not ledger.wire(pending, 11000)
    ledger.reap(11101)
    assert pending not in ledger.requests
    for _ in range(4):
        sequence = ledger.allocate(12000)
        ledger.wire(sequence, 12000)
        ledger.retire(sequence)
    with pytest.raises(RuntimeError, match="wire keys exhausted"):
        ledger.allocate(12001)


def test_uncompleted_tx_slots_remain_bounded():
    ledger = RequestLedger(outstanding_depth=2)
    for _ in range(2):
        ledger.retire(ledger.allocate(0))
    ledger.restart()
    with pytest.raises(RuntimeError, match="outstanding requests full"):
        ledger.allocate(100000)


def test_stale_response_cannot_match_after_restart():
    ledger = RequestLedger(lifetime=100, sequence_bits=2)
    old = ledger.allocate(0)
    ledger.wire(old, 10)
    ledger.restart()
    new = ledger.allocate(11)
    assert new != old and not ledger.response(old, 12)
    assert not ledger.response(new, 1000)
    assert not ledger.wire(new, 20)  # Stored response is outside its capture-time age bound.


@pytest.mark.parametrize("period", [Fraction(8), Fraction(32, 5)])
def test_fixed_point_delay_against_rational_world(period):
    rng = random.Random(48016)
    for _ in range(1000):
        t1 = rng.randrange(1 << 90)
        correction = rng.randrange(-(1 << 63), 1 << 63)
        c_delay = rng.randrange(-(1 << 63), 1 << 63)
        offset = rng.randrange(-(1 << 88), 1 << 88)
        delay = rng.randrange(100 * Q16)
        ticks = rng.randrange(1, 200_000_000)
        ratio = period * (1 + Fraction(rng.randrange(-100, 101), 1_000_000))
        t2 = t1 + correction + delay + offset
        t4 = nearest(t1 + correction + 2 * delay + ticks * ratio * Q16 + c_delay)
        actual_delay, actual_offset = e2e_q16(t1, t2, t4, correction, c_delay,
                                             ticks, nearest(ratio * (1 << 48)))
        assert abs(actual_delay - delay) <= 1  # At most one Q16 ns LSB.
        assert abs(actual_offset - offset) <= 1
    with pytest.raises(ValueError):
        e2e_q16(0, 0, 0, 0, 0, -1, 1 << 48)


def test_snapshot_reset_cancels_old_completion():
    mailbox = SnapshotMailbox()
    old_token = mailbox.request()
    with pytest.raises(RuntimeError):
        mailbox.request()
    # Either reset side must cancel the transaction. CDC implementation must
    # establish this shared reset-session state before accepting new requests.
    mailbox.reset()
    new_token = mailbox.request()
    assert mailbox.complete(old_token, (123, 456, 789)) is None
    assert mailbox.complete(new_token, (124, 0, 1)) == (124, 0, 1)
    assert mailbox.complete(new_token, (124, 0, 1)) is None
