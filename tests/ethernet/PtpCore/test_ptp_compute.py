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
# - Sweep: Block/distributed synchronous RAM with four independent contexts.
# - Stimulus: Full signed128 boundaries, limb carries, seeded integer operands,
#   four queued clients, stalled reads/results, active/queued/held cancellation.
# - Checks: Python integer oracle for wrapped result, signed overflow, nearest
#   ties away and truncation remainder; word order, tags and slot ownership.
# - Timing: Manual 6.4 ns clock samples readiness before the transfer edge and
#   registered responses after TPD. Bound a job to 4608 clocks and a four-job
#   batch to 18432. No endpoint integration, area or timing-closure claim.

import random
import os

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import run_surf_vhdl_test

MASK = (1 << 128)-1
WORD_MASK = (1 << 32)-1
MINIMUM = -(1 << 127)
MAXIMUM = (1 << 127)-1
JOB_BOUND = 4608


def oracle(a, b, operation, rounding):
    remainder = 0
    if operation == 0:
        value = a+b
    elif operation == 1:
        value = a-b
    elif operation == 2:
        value = a*b
    elif operation == 4:
        value = a
    elif operation == 5:
        value = a << b
    elif operation == 6:
        magnitude = abs(a) >> b
        if rounding and b and (abs(a) >> (b-1)) & 1:
            magnitude += 1
        value = -magnitude if a < 0 else magnitude
    elif operation == 7:
        value = a-b
    elif b == 0:
        return 0, 0, True
    else:
        quotient, rem = divmod(abs(a), abs(b))
        remainder = -rem if a < 0 else rem
        if rounding and 2*rem >= abs(b):
            quotient += 1
        value = -quotient if (a < 0) != (b < 0) else quotient
    return value & MASK, remainder & MASK, not MINIMUM <= value <= MAXIMUM


class Bench:
    def __init__(self, dut):
        self.d = dut
        self.cycles = 0
        self.polarity = int(os.environ.get('POLARITY', '1'))

    async def edge(self, check_registered=False, **inputs):
        d = self.d
        before = (int(d.resultValid.value), int(d.readValid.value)) if check_registered else None
        d.clk.value = 0
        for name, value in inputs.items():
            getattr(d, name).value = (self.polarity if value else 1-self.polarity) if name == 'rst' else value
        await Timer(3.2, unit='ns')
        if check_registered:
            assert before == (int(d.resultValid.value), int(d.readValid.value)), 'valid changed before edge'
        accepted = (int(d.memReady.value), int(d.jobReady.value))
        d.clk.value = 1
        await Timer(3.2, unit='ns')
        self.cycles += 1
        return accepted

    async def reset(self):
        for name in ('clk', 'rst', 'cancel', 'retain', 'memValid', 'memWrite', 'memClient',
                     'memWord', 'memData', 'readReady', 'jobValid', 'jobClient',
                     'jobOperation', 'jobRound', 'jobTag', 'resultReady'):
            getattr(self.d, name).value = 0
        for name, value in (('jobSourceA', 0), ('jobSourceB', 1), ('jobTarget', 2),
                            ('jobRemainder', 3), ('jobShift', 0)):
            getattr(self.d, name).value = value
        await self.edge(rst=1)
        await self.edge(rst=0)
        assert int(self.d.resultValid.value) == 0
        assert int(self.d.readValid.value) == 0

    async def access(self, client, word, value=None):
        for _ in range(4*JOB_BOUND):
            ready, _ = await self.edge(memValid=1, memWrite=int(value is not None),
                                       memClient=client, memWord=word,
                                       memData=0 if value is None else value)
            if ready:
                break
        else:
            assert False, 'memory admission starved'
        await self.edge(memValid=0)

    async def operands(self, client, a, b):
        for word in range(8):
            value = a if word < 4 else b
            await self.access(client, word, (value >> (32*(word % 4))) & WORD_MASK)

    async def issue(self, client, operation, rounding=0, tag=0,
                    source_a=0, source_b=1, target=2, remainder=3, shift=0):
        for _ in range(8):
            _, ready = await self.edge(jobValid=1, jobClient=client,
                                       jobOperation=operation, jobRound=rounding, jobTag=tag,
                                       jobSourceA=source_a, jobSourceB=source_b,
                                       jobTarget=target, jobRemainder=remainder, jobShift=shift)
            if ready:
                accepted = self.cycles
                break
        else:
            assert False, 'loaded, free context did not accept job'
        await self.edge(jobValid=0)
        return accepted

    async def wait(self, mask, bound=JOB_BOUND):
        for _ in range(bound):
            if int(self.d.resultValid.value) & mask == mask:
                return
            await self.edge()
        assert False, 'arithmetic completion exceeded bound'

    async def word(self, client, word, stall=0):
        await self.access(client, word)
        for _ in range(4):
            if int(self.d.readValid.value):
                break
            await self.edge()
        assert int(self.d.readValid.value)
        observed = (int(self.d.readClient.value), int(self.d.readWord.value), int(self.d.readData.value))
        assert observed[:2] == (client, word)
        for _ in range(stall):
            await self.edge()
            assert int(self.d.readValid.value)
            assert observed == (int(self.d.readClient.value), int(self.d.readWord.value), int(self.d.readData.value))
        await self.edge(readReady=1)
        await self.edge(readReady=0)
        return observed[2]

    async def check(self, client, expected, tag):
        assert int(self.d.resultValid.value) & (1 << client)
        assert ((int(self.d.resultTag.value) >> (32*client)) & WORD_MASK) == tag
        assert bool(int(self.d.resultError.value) & (1 << client)) == expected[2]
        values = [await self.word(client, word, stall=2 if word == 8 else 0) for word in range(8, 16)]
        result = sum(value << (32*i) for i, value in enumerate(values[:4]))
        remainder = sum(value << (32*i) for i, value in enumerate(values[4:]))
        assert (result, remainder) == expected[:2], (client, hex(result), hex(remainder), expected)
        await self.edge(resultReady=1 << client)
        await self.edge(resultReady=0)
        assert not int(self.d.resultValid.value) & (1 << client)


@cocotb.test()
async def arithmetic(d):
    bench = Bench(d)
    await bench.reset()
    rng = random.Random(158832)
    pairs = [(0, 0), (1, 0), (MINIMUM, -1), (MINIMUM, 1), (MINIMUM, MINIMUM),
             (MAXIMUM, 1), (MAXIMUM, 2), (MAXIMUM, MAXIMUM), (0, MINIMUM),
             (1, MINIMUM), (-1, MINIMUM), (3, 2), (-3, 2), (3, -2), (-3, -2),
             ((1 << 96)-1, (1 << 64)-1), (-(1 << 96)+1, (1 << 32)+1),
             ((1 << 126)-1, 1 << 126), (1 << 100, 1 << 50), (7, -3)]
    pairs += [(rng.randrange(MINIMUM, MAXIMUM+1), rng.randrange(MINIMUM, MAXIMUM+1)) for _ in range(12)]
    # Small divisors make long runs of successful subtraction and quotient-word
    # carries; random full-width divisors alone rarely exercise those paths.
    pairs += [(MAXIMUM, divisor) for divisor in (1, 2, 3, (1 << 32)-1, (1 << 64)+1)]
    maximum = [0]*4
    for operation in range(4):
        for index, (a, b) in enumerate(pairs):
            for rounding in ((0, 1) if operation == 3 else (0,)):
                client = index % 4
                tag = (operation << 16) | (index << 1) | rounding
                await bench.operands(client, a, b)
                accepted = await bench.issue(client, operation, rounding, tag)
                await bench.wait(1 << client)
                maximum[operation] = max(maximum[operation], bench.cycles-accepted)
                expected = oracle(a, b, operation, rounding)
                try:
                    await bench.check(client, expected, tag)
                except AssertionError as error:
                    raise AssertionError((operation, a, b, rounding)) from error
    d._log.info('Observed maximum admission-to-valid clocks (add/sub/mul/div): %s', maximum)


@cocotb.test()
async def ownership_and_scheduling(d):
    bench = Bench(d)
    await bench.reset()
    # Neither stale RAM nor seven loaded words can constitute a fresh operand pair.
    for word in range(7):
        await bench.access(0, word, WORD_MASK)
    _, ready = await bench.edge(jobValid=1, jobClient=0)
    assert not ready
    await bench.edge(jobValid=0)
    await bench.access(0, 7, 0)
    await bench.edge(cancel=1)
    _, ready = await bench.edge(cancel=0, jobValid=1)
    assert not ready
    await bench.edge(jobValid=0)

    jobs = [(MAXIMUM, 3, 3, 1), (MINIMUM, -1, 3, 0),
            ((1 << 80)+3, 9, 2, 0), (MAXIMUM, 1, 0, 0)]
    for client, (a, b, _, _) in enumerate(jobs):
        await bench.operands(client, a, b)
    starts = []
    for client, (_, _, operation, rounding) in enumerate(jobs):
        starts.append(await bench.issue(client, operation, rounding, 0x12340000+client))
    # Pending/active operands cannot be overwritten and a second job cannot
    # replace a descriptor. There are no result consumers during the batch.
    mem, job = await bench.edge(memValid=1, memWrite=1, memClient=0, memWord=0,
                                memData=0, jobValid=1, jobClient=1)
    assert (mem, job) == (0, 0)
    await bench.edge(memValid=0, jobValid=0)
    await bench.wait(15, bound=4*JOB_BOUND)
    assert bench.cycles-min(starts) < 4*JOB_BOUND
    assert int(d.resultError.value) == 0b1010
    # Completed words and a stalled response remain immutable.
    await bench.access(0, 8)
    await bench.edge()
    assert int(d.readValid.value)
    retained = int(d.readData.value)
    for _ in range(4):
        ready, _ = await bench.edge(memValid=1, memWrite=1, memClient=0, memWord=0, memData=0)
        assert not ready
        assert int(d.resultValid.value) == 15
        assert int(d.readData.value) == retained
    await bench.edge(memValid=0, readReady=1)
    await bench.edge(readReady=0)
    for client in (3, 1, 2, 0):
        a, b, operation, rounding = jobs[client]
        await bench.check(client, oracle(a, b, operation, rounding), 0x12340000+client)

    # A held read from a completed context must not stop another client's job.
    for client in (0, 1):
        await bench.operands(client, 5, 2)
    await bench.issue(0, 0, tag=10)
    await bench.wait(1)
    await bench.access(0, 8)
    await bench.edge()
    retained = int(d.readData.value)
    await bench.issue(1, 3, tag=11)
    await bench.wait(3)
    assert int(d.readValid.value) and int(d.readData.value) == retained
    await bench.edge(readReady=1)
    await bench.edge(readReady=0)
    await bench.check(0, oracle(5, 2, 0, 0), 10)
    await bench.check(1, oracle(5, 2, 3, 0), 11)

    # Result acknowledgement is an ordinary ready/valid transfer even with an
    # outstanding read. That read remains stable and blocks reuse of its slot.
    await bench.operands(0, 123, 456)
    await bench.issue(0, 0, tag=12)
    await bench.wait(1)
    await bench.access(0, 8)
    await bench.edge(resultReady=1)
    assert int(d.resultValid.value) == 0
    assert int(d.readValid.value) and int(d.readData.value) == 579
    ready, _ = await bench.edge(resultReady=0, memValid=1, memWrite=1,
                                memClient=0, memWord=0, memData=0)
    assert not ready
    await bench.edge(memValid=0, readReady=1)
    await bench.edge(readReady=0)
    await bench.operands(0, 4, 5)
    await bench.issue(0, 0, tag=13)
    await bench.wait(1)
    await bench.check(0, oracle(4, 5, 0, 0), 13)

    # Continuous word traffic cannot starve queued work. Keep the fourth slot
    # writable while three jobs run; require progress within a full batch bound.
    for client in range(3):
        await bench.operands(client, 100+client, 7)
    for client in range(3):
        await bench.issue(client, 3, 1, tag=100+client)
    transfers = 0
    for _ in range(3*JOB_BOUND):
        ready, _ = await bench.edge(memValid=1, memWrite=1, memClient=3,
                                    memWord=transfers % 8, memData=transfers)
        transfers += ready
        if int(d.resultValid.value) == 7:
            break
    else:
        assert False, 'continuous memory traffic starved computation'
    await bench.edge(memValid=0)
    assert transfers >= 2, 'computation starved memory traffic'
    for client in range(3):
        await bench.check(client, oracle(100+client, 7, 3, 1), 100+client)


@cocotb.test()
async def cancellation(d):
    bench = Bench(d)
    await bench.reset()
    # Interrupt before scratch setup, mid-word arithmetic, a late divide, and
    # held completion. Reload a different, smaller epoch of operand data each time.
    for delay in (0, 1, 25, 100, 1300, 5000, JOB_BOUND):
        await bench.operands(0, MAXIMUM, 3)
        await bench.operands(1, 13, -7)
        await bench.operands(2, 12345, 89)
        await bench.issue(0, 3, 1, tag=0xA000+delay)
        await bench.issue(1, 2, tag=0xB000+delay)
        await bench.issue(2, 3, tag=0xC000+delay)
        for _ in range(delay):
            await bench.edge()
        # In early cases context 0 is active and 2 queued; late cases exercise
        # completed cancellation. Context 1 must survive both.
        await bench.edge(check_registered=True, cancel=5, resultReady=5)
        assert int(d.resultValid.value) & 5 == 0
        _, ready = await bench.edge(cancel=0, resultReady=0, jobValid=1, jobClient=0)
        assert not ready, 'cancel failed to invalidate operand ownership'
        await bench.edge(jobValid=0)
        await bench.wait(2)
        await bench.check(1, oracle(13, -7, 2, 0), 0xB000+delay)
        await bench.operands(0, -17, 4)
        await bench.issue(0, 3, 1, tag=delay)
        await bench.wait(1)
        await bench.check(0, oracle(-17, 4, 3, 1), delay)
        assert int(d.resultValid.value) == 0

    # Cancel pending RAM reads and held responses without publishing stale data.
    for delay in (0, 1, 4):
        await bench.operands(3, 111, 222)
        await bench.issue(3, 0, tag=33)
        await bench.wait(8)
        await bench.access(3, 8)
        for _ in range(delay):
            await bench.edge()
        await bench.edge(check_registered=True, cancel=8, readReady=1)
        assert not int(d.readValid.value)
        assert not int(d.resultValid.value)
        await bench.edge(cancel=0, readReady=0)
        for _ in range(4):
            await bench.edge()
            assert not int(d.readValid.value)

    # Cancellation around result-word writes and final valid publication for
    # the shorter operations must also retire partial data before slot reuse.
    for operation in (0, 1, 2):
        for delay in (0, 1, 10, 24, 25, 26, 193, 195, 196):
            await bench.operands(2, MINIMUM, MAXIMUM)
            await bench.issue(2, operation, tag=66)
            for _ in range(delay):
                await bench.edge()
            await bench.edge(check_registered=True, cancel=4, resultReady=4)
            assert not int(d.resultValid.value)
            await bench.edge(cancel=0, resultReady=0)
            await bench.operands(2, -19, 8)
            await bench.issue(2, operation, tag=77)
            await bench.wait(4)
            await bench.check(2, oracle(-19, 8, operation, 0), 77)

    # Reset interrupts an active job and a pending descriptor, retaining no
    # operand validity even though physical RAM still contains previous values.
    for client in (0, 1):
        await bench.operands(client, MAXIMUM, 7)
    for client in (0, 1):
        await bench.issue(client, 3, tag=44+client)
    await bench.edge(check_registered=True, rst=1)
    await bench.reset()
    _, ready = await bench.edge(jobValid=1, jobClient=0)
    assert not ready
    await bench.edge(jobValid=0)
    await bench.operands(0, 7, 3)
    await bench.issue(0, 3, 1, tag=55)
    await bench.wait(1)
    await bench.check(0, oracle(7, 3, 3, 1), 55)


@cocotb.test()
async def persistent_workspace(d):
    bench = Bench(d)
    await bench.reset()
    # Copy, compare and both format shifts cover signed minimum and overflow,
    # cross-word shifts, zero shift and nearest ties away independently.
    for operation in (4, 5, 6, 7):
        for a in (MINIMUM, MAXIMUM, -(1 << 96)-3, -3, 0, 3, (1 << 64)+1):
            for amount in ((0, 1, 16, 30, 32, 35, 62, 127) if operation in (5, 6) else (1,)):
                b = MAXIMUM if a < 0 else MINIMUM
                await bench.operands(0, a, b)
                await bench.issue(0, operation, rounding=1, shift=amount, tag=amount)
                await bench.wait(1)
                if operation == 7:
                    assert bool(int(d.resultLess.value) & 1) == (a < b)
                    assert bool(int(d.resultEqual.value) & 1) == (a == b)
                await bench.check(0, oracle(a, amount if operation in (5, 6) else b, operation, 1), amount)

    # Destinations become authoritative sources after acknowledgement. No data
    # is read back or reloaded between multiply, add, copy and in-place divide.
    await bench.operands(1, 13, 7)
    await bench.issue(1, 2, target=12, remainder=15)
    await bench.wait(2)
    await bench.edge(resultReady=2)
    await bench.edge(resultReady=0)
    await bench.issue(1, 0, source_a=12, source_b=1, target=12, remainder=15)
    await bench.wait(2)
    await bench.edge(resultReady=2)
    await bench.edge(resultReady=0)
    await bench.issue(1, 4, source_a=12, target=9, remainder=15)
    await bench.wait(2)
    await bench.edge(resultReady=2)
    await bench.edge(resultReady=0)
    await bench.issue(1, 3, source_a=9, source_b=1, target=9, remainder=15)
    await bench.wait(2)
    words = [await bench.word(1, 36+i) for i in range(4)]
    assert sum(word << (32*i) for i, word in enumerate(words)) == 14
    await bench.edge(resultReady=2)
    await bench.edge(resultReady=0)
    # Persistent data is still readable without a live completion descriptor.
    assert await bench.word(1, 48) == 98
    await bench.edge(cancel=2)
    await bench.edge(cancel=0)
    _, ready = await bench.edge(jobValid=1, jobClient=1)
    assert not ready, 'cancellation retained a persistent source'
    await bench.edge(jobValid=0)

    # A held owner-zero response cannot prevent owner-three word publication.
    for client in (0, 3):
        await bench.operands(client, 31+client, 1)
    await bench.access(0, 0)
    await bench.edge()
    await bench.access(3, 0)
    await bench.edge()
    assert int(d.readValid.value) and int(d.readData.value) == 31
    await bench.edge(readReady=1)
    await bench.edge(readReady=0)
    assert int(d.readValid.value) and int(d.readClient.value) == 3
    assert int(d.readData.value) == 34
    await bench.edge(readReady=1)
    await bench.edge(readReady=0)


@cocotb.test()
async def retained_cancellation(d):
    bench = Bench(d)
    await bench.reset()
    # Servo's committed frequency is separate from the candidate destination.
    # Sweep active, finish, held completion and read cancellation; a PHC owner
    # continues to completion while the servo releases its descriptor.
    for delay in (0, 1, 12, 22, 23, 24, 25, 26, 27, 50, JOB_BOUND):
        await bench.operands(2, 123, 456)
        for word in range(4):
            await bench.access(2, 40+word, 789 if word == 0 else 0)
        await bench.operands(3, MAXIMUM, 3)
        await bench.issue(2, 0, target=11, remainder=15)
        await bench.issue(3, 3, tag=99)
        for _ in range(delay):
            await bench.edge()
        completed = bool(int(d.resultValid.value) & 4)
        await bench.edge(cancel=4, retain=4)
        await bench.edge(cancel=0, retain=0)
        assert not int(d.resultValid.value) & 4
        if not completed:
            for _ in range(3):
                ready, _ = await bench.edge(memValid=1, memWrite=0, memClient=2, memWord=44)
                assert not ready, 'partial destination survived retained cancellation'
            await bench.edge(memValid=0)
        await bench.wait(8)
        await bench.check(3, oracle(MAXIMUM, 3, 3, 0), 99)
        assert await bench.word(2, 40) == 789
        await bench.issue(2, 4, source_a=10, tag=77)
        await bench.wait(4)
        await bench.check(2, (789, 0, False), 77)
        # Both pending and held reads can be canceled without invalidating the
        # committed slot, and without delivering their stale responses later.
        await bench.access(2, 40)
        await bench.edge(cancel=4, retain=4)
        await bench.edge(cancel=0, retain=0)
        assert not int(d.readValid.value)
        assert await bench.word(2, 40) == 789


@pytest.mark.parametrize('memory_type,polarity,async_reset',
                         [('block', 1, False), ('distributed', 0, True)])
def test_ptp_compute(memory_type, polarity, async_reset):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.PtpComputeWrapper',
                      parameters={'MEMORY_TYPE_G': memory_type, 'RST_POLARITY_G': f"'{polarity}'",
                                  'RST_ASYNC_G': async_reset}, extra_env={'POLARITY': polarity})
