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
# - Sweep: Production SECOND (signed128 Q16 nanoseconds) and positive80 variable
#   division, each with two contending owners and both quotient rounding modes.
# - Stimulus: Signed extrema, exact ties and adjacent values, zero divisors,
#   sustained contention, asymmetric held responses, resets and seeded randomness.
# - Checks: Independent integer quotient/error/truncation-remainder oracle,
#   immutable admitted operands, stable registered responses, round-robin fairness,
#   bounded progress and owner-local cancellation with no stale completions.
# - Timing: Cancel on every work/publication cycle and held completion; exclude
#   reset/cancel edges from transfers. Bounds are local service checks, not the
#   complete endpoint association proof or hardware timing qualification.

import os
import random

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import run_surf_vhdl_test

MASK = (1 << 128) - 1
MINIMUM = -(1 << 127)
MAXIMUM = (1 << 127) - 1
MAX_DIVISOR = (1 << 80) - 1
SECOND = 1_000_000_000 << 16
SERVICE_BOUND = 132


def oracle(transaction, variable):
    """Exact arithmetic independent of the restoring RTL implementation."""
    dividend, divisor, rounded = transaction
    if divisor == 0:
        return 0, 0, 1
    magnitude, remainder = divmod(abs(dividend), divisor)
    signed_remainder = -remainder if dividend < 0 else remainder
    if rounded and remainder * 2 >= divisor:
        magnitude += 1
    quotient = -magnitude if dividend < 0 else magnitude
    return (quotient & MASK, 0 if variable else signed_remainder & MASK,
            int(not MINIMUM <= quotient <= MAXIMUM))


class Bench:
    def __init__(self, dut):
        self.d = dut
        self.variable = os.environ["VARIABLE_SERVICE"] == "1"
        self.cycle = 0
        self.pending = [None, None]
        self.outstanding = [None, None]
        self.held = [None, None]
        self.waiting = [0, 0]
        self.accepts = []
        self.responses = []
        self.completed = [0, 0]
        self.latencies = set()
        for name in ("clk", "rst", "cancel", "inputValid", "resultReady",
                     "roundNearest", "operandA", "operandB"):
            getattr(dut, name).value = 0

    async def tick(self, ready=3, cancel=0, reset=False):
        d = self.d
        before = tuple(int(getattr(d, name).value) for name in
                       ("resultValid", "resultValue", "resultRemainder", "resultError")) if self.cycle else None
        d.clk.value = 0
        # SECOND ignores operandB; normalize only the expected transaction.
        if not self.variable:
            self.pending = [(item[0], SECOND, item[2]) if item else None
                            for item in self.pending]
        d.rst.value = int(reset)
        d.cancel.value = cancel
        d.resultReady.value = ready
        d.inputValid.value = sum((self.pending[i] is not None) << i for i in range(2))
        d.operandA.value = sum(((self.pending[i][0] if self.pending[i] else 0) & MASK)
                               << (128*i) for i in range(2))
        d.operandB.value = sum((self.pending[i][1] if self.pending[i] else 0)
                               << (80*i) for i in range(2))
        d.roundNearest.value = sum((self.pending[i][2] if self.pending[i] else 0)
                                   << i for i in range(2))
        await Timer(4, unit="ns")
        if before is not None:
            assert before == tuple(int(getattr(d, name).value) for name in
                                   ("resultValid", "resultValue", "resultRemainder", "resultError")), "response changed before edge"
        in_ready, out_valid = int(d.inputReady.value), int(d.resultValid.value)
        for owner in range(2):
            bit = 1 << owner
            if reset or cancel & bit:
                if not reset:
                    assert not in_ready & bit, (self.cycle, owner, "cancel admission")
                self.pending[owner] = None
                self.outstanding[owner] = None
                self.held[owner] = None
                self.waiting[owner] = 0
                continue
            if out_valid & bit:
                assert self.outstanding[owner] is not None, (self.cycle, owner, "stale response")
                transaction, accepted_cycle, seen = self.outstanding[owner]
                payload = ((int(d.resultValue.value) >> (128*owner)) & MASK,
                           (int(d.resultRemainder.value) >> (128*owner)) & MASK,
                           (int(d.resultError.value) >> owner) & 1)
                assert payload == oracle(transaction, self.variable), (self.cycle, owner, transaction, payload)
                if self.held[owner] is not None:
                    assert self.held[owner] == payload, (self.cycle, owner, "unstable response")
                if not seen:
                    latency = self.cycle - accepted_cycle - 1
                    assert 0 < latency <= SERVICE_BOUND, (self.cycle, owner, latency)
                    self.latencies.add(latency)
                    self.responses.append((self.cycle, owner))
                    self.outstanding[owner] = (transaction, accepted_cycle, True)
                if ready & bit:
                    self.outstanding[owner] = None
                    self.held[owner] = None
                    self.completed[owner] += 1
                else:
                    self.held[owner] = payload
            else:
                assert self.held[owner] is None, (self.cycle, owner, "lost held response")
            if self.pending[owner] is not None and self.outstanding[owner] is None:
                self.waiting[owner] += 1
                # One active service plus arbitration/publication turnaround.
                assert self.waiting[owner] <= SERVICE_BOUND, (
                    self.cycle, owner, "eligible request starved", self.waiting)
            else:
                self.waiting[owner] = 0
            if in_ready & bit and self.pending[owner] is not None:
                assert self.outstanding[owner] is None, (self.cycle, owner, "double admission")
                self.outstanding[owner] = (self.pending[owner], self.cycle, False)
                self.pending[owner] = None
                self.waiting[owner] = 0
                self.accepts.append((self.cycle, owner))
        d.clk.value = 1
        await Timer(4, unit="ns")
        if reset:
            assert not int(d.resultValid.value)
        else:
            assert not int(d.resultValid.value) & cancel
        self.cycle += 1

    async def idle(self, cycles=1, **kwargs):
        for _ in range(cycles):
            await self.tick(**kwargs)

    async def drain(self):
        for _ in range(400):
            if self.pending == [None, None] and self.outstanding == [None, None]:
                return
            await self.tick()
        raise AssertionError("drain exceeded two complete divider services")


@cocotb.test()
async def arithmetic_and_progress(d):
    tb = Bench(d)
    await tb.tick(reset=True)
    # All signs, extremes, ties, below/above ties, and the full positive80 domain.
    divisors = (0, 1, 2, 3, MAX_DIVISOR) if tb.variable else (SECOND,)
    vectors = [(a, b, rounding)
               for a in (MINIMUM, MAXIMUM, -3, -1, 0, 1, 3)
               for b in divisors
               for rounding in (0, 1)]
    for divisor in ((4, 10, 1 << 79, MAX_DIVISOR - 1) if tb.variable else (SECOND,)):
        for delta in (-1, 0, 1):
            for sign in (-1, 1):
                vectors.append((sign * (5*divisor + divisor//2 + delta), divisor, 1))
    # Saturate both queues so simultaneous contention is exercised repeatedly.
    for index in range(0, len(vectors), 2):
        tb.pending = vectors[index:index+2]
        if len(tb.pending) == 1:
            tb.pending.append(None)
        await tb.drain()
    assert tb.completed[0] and tb.completed[1]

    # Both queues stay eligible; round-robin grants must alternate.
    await tb.tick(reset=True)
    start = len(tb.accepts)
    for _ in range(1600):
        for owner in range(2):
            if tb.pending[owner] is None:
                tb.pending[owner] = (MINIMUM + owner, 7, owner)
        await tb.tick()
    grants = tb.accepts[start:]
    assert len(grants) >= 12
    assert [owner for _, owner in grants] == [i % 2 for i in range(len(grants))]
    assert max(b[0] - a[0] for a, b in zip(grants, grants[1:])) <= SERVICE_BOUND
    await tb.drain()

    # A held owner0 result must not block repeated owner1 work. The blocked
    # owner also presents another request, exercising eligibility filtering.
    await tb.tick(reset=True)
    tb.pending[0] = (MINIMUM, 3, 1)
    await tb.idle(140, ready=2)
    assert tb.held[0] is not None
    tb.pending[0] = (MAXIMUM, 5, 1)
    before = tb.completed[1]
    for cycle in range(800):
        if tb.pending[1] is None:
            tb.pending[1] = (cycle - 400, 7, cycle % 2)
        await tb.tick(ready=2)
    assert tb.completed[1] - before >= 5
    assert tb.held[0] is not None
    await tb.drain()

    d._log.info("Measured response latencies: %s", sorted(tb.latencies))


@cocotb.test()
async def cancel_reset_and_random_contention(d):
    tb = Bench(d)
    await tb.tick(reset=True)
    # Every cycle of an active operation, including finish/publication, plus a
    # held response. Alternate victims so both cancellation bits are exercised.
    for delay in range(132):
        victim = delay % 2
        peer = 1 - victim
        await tb.tick(reset=True)
        tb.pending[victim] = (MINIMUM, 3, 1)
        await tb.tick(ready=0)
        assert tb.outstanding[victim] is not None
        tb.pending[peer] = (MAXIMUM, MAX_DIVISOR, 1)
        await tb.idle(delay, ready=0)
        completed_before = tb.completed[peer]
        await tb.tick(cancel=1 << victim, ready=0)
        await tb.drain()
        assert tb.completed[peer] == completed_before + 1
        await tb.idle(2)
    # Reset must discard simultaneous held and active state; fresh work must
    # not inherit a completion or owner from the previous epoch.
    await tb.tick(reset=True)
    tb.pending[0] = (11, 2, 1)
    await tb.idle(140, ready=0)
    tb.pending[1] = (-11, 2, 1)
    await tb.idle(12, ready=0)
    await tb.tick(reset=True)
    await tb.idle(140)
    tb.pending = [(17, 2, 1), (-17, 2, 1)]
    await tb.drain()

    rng = random.Random(0xD1A1DE)
    before = tb.completed.copy()
    for cycle in range(16000):
        cancel = sum((rng.randrange(601) == 0) << owner for owner in range(2))
        ready = sum((rng.randrange(4) != 0) << owner for owner in range(2))
        # Prolonged asymmetric stalls exceed several normal service intervals.
        if cycle % 1800 < 600:
            ready &= ~(1 << ((cycle // 1800) % 2))
        for owner in range(2):
            if tb.pending[owner] is None:
                divisor = rng.choice((0, 1, 2, 3, MAX_DIVISOR,
                                      rng.randrange(1, MAX_DIVISOR + 1)))
                tb.pending[owner] = (rng.randrange(MINIMUM, MAXIMUM + 1),
                                     divisor, rng.randrange(2))
        await tb.tick(ready=ready, cancel=cancel, reset=cycle in (5100, 10200))
    await tb.drain()
    assert all(tb.completed[i] - before[i] > 25 for i in range(2)), tb.completed
    d._log.info("Completed random phase responses per owner: %s",
                [tb.completed[i] - before[i] for i in range(2)])


@pytest.mark.parametrize("variable", (False, True), ids=("second", "variable"))
def test_ptp_arithmetic_services(variable):
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.PtpArithmeticServiceWrapper",
        extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpArithmeticServiceWrapper.vhd"]},
        parameters={"VARIABLE_G": variable},
        extra_env={"VARIABLE_SERVICE": str(int(variable))})
