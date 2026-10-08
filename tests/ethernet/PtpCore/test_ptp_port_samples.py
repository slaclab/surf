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
# - Sweep: Real PtpProtocolEngine with explicit validated records and 125 MHz nominal rate.
# - Stimulus: One-/two-step equivalents, signed/fractional corrections, large
#   epochs, malformed timestamps/flags, mixed-mode collisions, wrap and expiry.
# - Checks: Exact independent Q16 forward arithmetic, sequence/capture provenance,
#   completion/rejection counts, rate qualification and bounded slot reuse.
# - Timing: Measurement stalls and rate-engine busy block RX; registered payload
#   holds until consumption or documented abort. Reset, generation, RX abort,
#   overflow and configuration application cancel pending work. No PHY model here.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test, sample_after_tpd
from tests.ethernet.PtpCore.ptp_reference import NS, Q16

SOURCE = int.from_bytes(bytes.fromhex('001122fffe3344550001'), 'big')


def wire_time(ns):
    seconds, nanoseconds = divmod(ns, NS)
    return seconds << 32 | nanoseconds


def capture_time(q16):
    seconds, nsfrac = divmod(q16, NS*Q16)
    return seconds << 48 | nsfrac


class Bench:
    def __init__(self, d):
        self.d = d
        self.clock = None
        self.now = 100
        self.generation = 0
        for name in ('clk', 'rst', 'regRst', 'restart', 'prepare', 'applyConfig',
                     'ticks', 'generation', 'rxAbort', 'rxOverflow', 'rxValid',
                     'rxKind', 'rxFlags', 'rxControl', 'rxSequence', 'rxDomain',
                     'rxSource', 'rxTimestamp', 'rxCorrection', 'captureTime',
                     'captureTicks', 'captureGeneration', 'measurementReady'):
            getattr(d, name).value = 0
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(d, 'axil'), d.clk, d.rst)

    async def wait(self, cycles=1):
        for _ in range(cycles):
            await sample_after_tpd(self.d.clk, propagation_time=1.1)

    async def write(self, address, value, width=8):
        result = await self.axil.write(address, value.to_bytes(width, 'little'))
        assert result.resp == AxiResp.OKAY

    async def configure(self, min_span=1000000, timeout=100000, source=SOURCE):
        await self.write(0x020, source, 12)
        await self.write(0x088, 10000000)
        await self.write(0x090, timeout)
        await self.write(0x0A0, min_span)
        await self.write(0x0A8, 1000000)
        self.d.prepare.value = 1
        await self.wait()
        self.d.prepare.value = 0
        assert int(self.d.configValid.value)
        await self.pulse('applyConfig')

    async def start(self):
        self.clock = cocotb.start_soon(Clock(self.d.clk, 8, unit='ns').start())
        self.d.rst.value = 1
        await self.wait(3)
        self.d.rst.value = 0
        await self.wait(3)
        await self.configure()

    async def pulse(self, name):
        # Called after TPD settling. A held measurement and abort must not
        # change during this deliberate between-edge control transition.
        held = (int(self.d.measurementValid.value), int(self.d.measurementAbort.value), self.payload())
        getattr(self.d, name).value = 1
        if held[0]:
            await Timer(1, unit='ns')
            assert held == (int(self.d.measurementValid.value), int(self.d.measurementAbort.value), self.payload())
        await self.wait()
        getattr(self.d, name).value = 0
        await self.wait(3)

    def counts(self):
        return int(self.d.syncCount.value), int(self.d.rejectedCount.value)

    async def send(self, kind, seq, remote=0, correction=0, *, two_step=False,
                   local=None, ticks=None, timestamp=None, flags=None, control=None,
                   source=SOURCE, domain=0, generation=None):
        """Propagation sampling: sample RX ready at the edge, then wait past TPD_G."""
        self.now += 10
        ticks = self.now if ticks is None else ticks
        self.now = max(self.now, ticks)
        local = remote*Q16+123*Q16+7 if local is None else local
        inputs = dict(ticks=self.now, rxKind=kind, rxSequence=seq,
                      rxTimestamp=wire_time(remote) if timestamp is None else timestamp,
                      rxCorrection=correction & ((1 << 64)-1),
                      rxFlags=(0x200 if kind == 0 and two_step else 0) if flags is None else flags,
                      rxControl=(0 if kind == 0 else 2) if control is None else control,
                      rxSource=source, rxDomain=domain, captureTicks=ticks,
                      captureGeneration=self.generation if generation is None else generation,
                      captureTime=capture_time(local), rxValid=1)
        for name, value in inputs.items():
            getattr(self.d, name).value = value
        for _ in range(400):
            await RisingEdge(self.d.clk)
            accepted = int(self.d.rxReady.value)
            await Timer(1.1, unit='ns')
            if accepted:
                self.d.rxValid.value = 0
                return
        assert False, 'RX transaction did not complete'

    def payload(self):
        return tuple(int(getattr(self.d, name).value) for name in
                     ('measurementForward', 'measurementTicks', 'measurementSequence',
                      'measurementGeneration', 'measurementRatio', 'ratioValid'))

    async def result(self, seq, expected, ticks=None):
        for _ in range(300):
            if int(self.d.measurementValid.value):
                break
            await self.wait()
        assert int(self.d.measurementValid.value), 'Sync did not publish a measurement'
        got = self.payload()
        assert got[0] == expected % (1 << 128), (got, expected)
        assert got[2:4] == (seq, self.generation), got
        if ticks is not None:
            assert got[1] == ticks
        return got

    async def drain(self):
        self.d.measurementReady.value = 1
        await self.wait()
        self.d.measurementReady.value = 0
        await self.wait()
        assert not int(self.d.measurementValid.value)

    async def no_result(self):
        await self.wait(4)
        assert not int(self.d.measurementValid.value)

    def stop(self):
        self.clock.cancel()


@cocotb.test()
async def exact_mode_equivalence(d):
    b = Bench(d)
    await b.start()
    try:
        # Include both second-boundary directions, every seconds bit and the
        # full signed correction range. Expected values use Python integers.
        vectors = [(42*NS, -Q16-17), (42*NS+NS-1, 2*Q16+7),
                   ((1 << 40)*NS+NS-1, -Q16//2), (((1 << 48)-1)*NS, Q16//2),
                   (42*NS, -(1 << 63)), (42*NS, (1 << 63)-1)]
        for remote, correction in vectors:
            local = remote*Q16+55*Q16+123
            expected = local-remote*Q16-correction
            results = []
            for two_step, follow_first in ((False, False), (True, False), (True, True)):
                await b.pulse('restart')
                count, rejected = b.counts()
                # Deliberately split the total, including cancellation of two
                # large signed operands. Widening must happen before addition.
                sync_correction = correction//2 if two_step else correction
                follow_correction = correction-sync_correction
                if follow_first:
                    await b.send(8, 7, remote, follow_correction)
                await b.send(0, 7, remote, sync_correction, two_step=two_step,
                             local=local, ticks=b.now+100,
                             timestamp=(123 << 32 | NS) if two_step else None)
                capture_ticks = b.now
                if two_step and not follow_first:
                    await b.no_result()
                    await b.send(8, 7, remote, follow_correction)
                got = await b.result(7, expected, capture_ticks)
                results.append(got[0])
                assert b.counts() == (count+1, rejected)
                # Hold a published result, including across AXI-only reset.
                await b.wait(5)
                assert b.payload() == got and int(d.measurementValid.value)
                await b.pulse('regRst')
                assert b.payload() == got and int(d.measurementValid.value)
                await b.drain()
                await b.no_result()
            assert len(set(results)) == 1
        # Two-step sum may exceed signed64, while each wire field remains valid.
        await b.pulse('restart')
        for correction in ((1 << 63)-1, -(1 << 63)):
            await b.pulse('restart')
            await b.send(0, 9, 0, correction, two_step=True, local=100*Q16)
            await b.send(8, 9, NS, correction)
            await b.result(9, 100*Q16-NS*Q16-2*correction)
            await b.drain()
    finally:
        b.stop()


@cocotb.test()
async def collisions_and_policy(d):
    b = Bench(d)
    await b.start()
    try:
        # Follow_Up first + one-step retires the key; subsequent traffic cannot
        # revive it, even by switching back to two-step.
        before, rejected = b.counts()
        await b.send(8, 1, NS)
        await b.send(0, 1, NS)
        assert b.counts() == (before, rejected+1)
        await b.send(0, 1, two_step=True)
        await b.send(8, 1, NS)
        await b.no_result()
        assert b.counts()[0] == before

        # Invalid one-step timestamps must be rejected before touching a live
        # Follow_Up or two-step Sync association. The valid mate still completes.
        for first in (0, 8):
            for ns in (NS, NS+1, 0xffffffff):
                await b.pulse('restart')
                before, rejected = b.counts()
                await b.send(first, 2, NS, two_step=True, local=2*NS*Q16)
                await b.send(0, 2, timestamp=(1 << 32 | ns))
                assert b.counts() == (before, rejected+1)
                await b.send(8 if first == 0 else 0, 2, NS, two_step=True, local=2*NS*Q16)
                await b.result(2, NS*Q16)
                await b.drain()

        # Post-publication Follow_Up (identical or conflicting) is counted but
        # cannot change the accepted one-step history or publish again.
        await b.pulse('restart')
        before, rejected = b.counts()
        await b.send(0, 3, NS-1, -17, local=NS*Q16)
        await b.result(3, Q16+17)
        await b.drain()
        for remote, correction in ((NS-1, -17), (9*NS, 123)):
            await b.send(8, 3, remote, correction)
            rejected += 1
            assert b.counts() == (before+1, rejected)
            await b.no_result()
        for two_step, remote, correction in ((False, NS-1, -17), (False, 2*NS, 0), (True, 2*NS, 0)):
            await b.send(0, 3, remote, correction, two_step=two_step)
            rejected += 1
            assert b.counts() == (before+1, rejected)
            await b.no_result()

        # A different physical Sync, even with a different step mode, retires
        # an incomplete two-step association before its Follow_Up arrives.
        await b.pulse('restart')
        before, rejected = b.counts()
        await b.send(0, 4, two_step=True)
        await b.send(0, 4, NS)
        await b.send(8, 4, NS)
        await b.no_result()
        assert b.counts() == (before, rejected+1)

        # Preserve exact flag, control, domain and configured-source policy.
        for kwargs in ({'flags': 1}, {'flags': 0x201}, {'flags': 0x400},
                       {'control': 1}, {'domain': 1}, {'source': SOURCE+1},
                       {'generation': 1}):
            await b.pulse('restart')
            before, rejected = b.counts()
            await b.send(0, 5, NS, **kwargs)
            await b.no_result()
            assert b.counts() == (before, rejected+1), kwargs
            await b.send(0, 5, NS)
            await b.result(5, 123*Q16+7)
            await b.drain()
    finally:
        b.stop()


@cocotb.test()
async def capacity_chronology_and_cancellation(d):
    b = Bench(d)
    await b.start()
    try:
        # Full partial table refuses new keys, but completing one entry makes
        # room. Alternate modes through sequence wrap without a global restart.
        before, rejected = b.counts()
        for seq in range(4):
            await b.send(8, seq, (seq+1)*NS)
        await b.send(0, 10, 10*NS)
        assert b.counts() == (before, rejected+1)
        await b.send(0, 0, two_step=True, local=2*NS*Q16)
        await b.result(0, NS*Q16)
        await b.drain()
        await b.send(0, 10, 10*NS)
        await b.result(10, 123*Q16+7)
        await b.drain()
        assert b.counts() == (before+2, rejected+1)
        for i, seq in enumerate((65534, 65535, 0, 1, 2, 3, 4, 5)):
            # Clear old partial keys only at the start of the wrap fixture.
            if i == 0:
                await b.pulse('restart')
            remote = (i+20)*NS
            await b.send(0, seq, remote, two_step=bool(i % 2))
            if i % 2:
                await b.send(8, seq, remote)
            await b.result(seq, 123*Q16+7)
            await b.drain()
        # Replays on retained keys and nonmonotonic new keys cannot publish.
        before, rejected = b.counts()
        await b.send(0, 5, 27*NS)
        await b.send(0, 6, 20*NS)
        await b.no_result()
        assert b.counts() == (before, rejected+2)
        await b.send(0, 7, 28*NS, ticks=1)
        await b.no_result()
        assert b.counts() == (before, rejected+3)

        # Expiry of unmatched Follow_Up removes its mode conflict; a fresh
        # one-step on that key can then complete. Expired captures still fail.
        await b.configure(timeout=3000)
        await b.send(8, 20, NS)
        b.now += 3001
        d.ticks.value = b.now
        await b.wait()
        await b.send(0, 20, NS)
        await b.result(20, 123*Q16+7)
        await b.drain()
        before, rejected = b.counts()
        await b.send(0, 21, 2*NS, ticks=b.now-3001)
        assert b.counts() == (before, rejected+1)

        # A result stalls RX and retains every published field. A queued
        # Follow_Up cannot consume or alter that one-step until ready returns.
        await b.configure()
        await b.send(0, 30, NS)
        held = await b.result(30, 123*Q16+7)
        follow = cocotb.start_soon(b.send(8, 30, 9*NS, 17))
        await b.wait(8)
        assert not follow.done() and not int(d.rxReady.value)
        assert b.payload() == held and int(d.measurementValid.value)
        await b.drain()
        await follow
        await b.no_result()

        # Flush partial and held samples at the public cancellation boundary.
        for cause in ('restart', 'rxAbort', 'rxOverflow', 'applyConfig', 'source', 'generation', 'rst'):
            await b.pulse('restart')
            await b.send(8, 40, NS)
            await b.send(0, 41, 2*NS)
            await b.result(41, 123*Q16+7)
            if cause == 'source':
                await b.configure(source=SOURCE+1)
            elif cause == 'generation':
                held = b.payload()
                b.generation += 1
                d.generation.value = b.generation
                await Timer(1, unit='ns')
                assert b.payload() == held and int(d.measurementValid.value)
                await b.wait(4)
            else:
                await b.pulse(cause)
            assert not int(d.measurementValid.value), cause
            if cause == 'rst':
                await b.configure()
            await b.send(0, 40, NS, source=SOURCE+1 if cause == 'source' else SOURCE)
            await b.result(40, 123*Q16+7)
            await b.drain()
            if cause == 'source':
                await b.configure()

        # Two qualified intervals establish exactly 8 ns/raw-cycle, regardless
        # of alternating modes. RX remains closed while division is busy.
        await b.configure(min_span=100)
        for i in range(3):
            ticks = b.now+1000
            remote = ticks*8
            await b.send(0, 50+i, remote, two_step=bool(i % 2), ticks=ticks)
            if i % 2:
                await b.send(8, 50+i, remote)
            if i:
                assert not int(d.rxReady.value), 'rate work did not retain RX ownership'
            got = await b.result(50+i, 123*Q16+7, ticks)
            if i == 2:
                assert got[4:] == (8 << 48, 1), got
            await b.drain()
        # Offer a new one-step record during division. It must remain pending
        # until both the engine and the held measurement relinquish capacity.
        await b.send(0, 53, (b.now+1000)*8, ticks=b.now+1000)
        queued = cocotb.start_soon(b.send(0, 54, (b.now+1000)*8, ticks=b.now+1000))
        await b.wait(10)
        assert not queued.done() and not int(d.rxReady.value)
        await b.result(53, 123*Q16+7)
        await b.drain()
        await queued
        await b.result(54, 123*Q16+7)
        await b.drain()
        # Cancel an in-flight divide, then restart with a fresh one-step anchor.
        await b.send(0, 55, (b.now+1000)*8, ticks=b.now+1000)
        assert not int(d.rxReady.value)
        await b.pulse('rxAbort')
        await b.wait(150)
        await b.no_result()
        await b.send(0, 56, 100*NS)
        await b.result(56, 123*Q16+7)
        await b.drain()
    finally:
        b.stop()


def test_ptp_port_samples():
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpportwrapper')
