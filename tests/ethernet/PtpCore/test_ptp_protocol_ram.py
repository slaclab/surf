#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: Distributed/block RAM for both production protocol tables.
# - Stimulus: Reordered pairs, ring wrap, capture phases, bounded searches with
#   held producers, time advancing across expiry and cancellation during scans.
# - Checks: Independent nearest-distance/physical-slot oracle; exact exchange
#   snapshots and 150 ns forward / 100.25 ns delay; no stale publication after
#   abort; acknowledgement only after search and whole-row replacement;
#   completed E2E publication cannot be starved by continuous rejected traffic;
#   concurrent RX/E2E rejections count twice one edge after detection;
#   pending increments survive logical cancellation; only system reset clears them;
#   word carries/borrows, modulo age, strict ties, and inclusive distance limits;
#   overlapping pair/history scans preserve both owners and bounded progress.
# - Timing: Raw ticks advance between events while ordinary pipeline clocks
#   continue. Internal ledger ready and RAM enable target cancellation and
#   concurrent traffic at lookup admission; payload/result oracles use public
#   interfaces. No alternate RTL, physical timing or resource-use claim.

from contextlib import asynccontextmanager

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    cancel_and_join_tasks, cocotb_filtered_env, cocotb_test_filter, run_surf_vhdl_test)
from tests.ethernet.PtpCore.ptp_master_test_utils import master_frame
from tests.ethernet.PtpCore.test_ptp_exchange import ExchangeBench, Q16
from tests.ethernet.PtpCore.test_ptp_port_samples import Bench, NS, capture_time, wire_time, MIN_ASSOCIATION_TICKS


@asynccontextmanager
async def history_bench(d, *, timeout=None, maximum=None, path_limit=None, first_tick=None, long_timers=False):
    b = ExchangeBench(d)
    d.capturePhase.value = 0
    d.wirePhase.value = 0
    try:
        await b.setup()
        if timeout is not None or maximum is not None or path_limit is not None or long_timers:
            if timeout is not None:
                await b.write(0x090, timeout)
            if maximum is not None:
                await b.write(0x098, maximum)
            if path_limit is not None:
                await b.write(0x0B8, path_limit)
            if long_timers:
                await b.write(0x088, (1 << 62)-1)
                await b.write(0x0A8, (1 << 62)-1)
            d.prepare.value = 1
            await b.wait()
            d.prepare.value = 0
            await b.wait_config()
            assert int(d.configValid.value)
            await b.pulse('applyConfig')
        if first_tick is None:
            await b.qualify()
        else:
            for seq in range(3):
                await b.sync(seq, first_tick+seq*125000000)
            assert b.payload()[4:] == (8 << 48, 1)
            assert b.counts() == (3, 0)
        yield b
    finally:
        if b.clock is not None:
            await cancel_and_join_tasks([b.clock])


async def phase_sync(b, seq, ticks, phase=0, interval=None):
    b.d.capturePhase.value = phase
    remote = ticks*8+phase-101
    await b.packet(master_frame(0, seq, remote, 49152, minor=b.minor, two_step=False, interval=interval),
                   ticks=ticks, local=(ticks*8+phase)*Q16+3260416)
    await b.result(seq, 150*Q16, ticks)
    await b.drain()
    b.d.capturePhase.value = 0


async def history_admission(b):
    # Observe the real ledger-to-protocol handshake, without deriving expected
    # nearest selection or arithmetic from the implementation.
    for _ in range(2*(4*45+22+8)):
        await RisingEdge(b.d.clk)
        admitted = int(b.d.u_dut.delayready.value)
        await Timer(1.1, unit='ns')
        if admitted:
            return
    assert False, 'ledger sample did not enter the history lookup'


async def selected_exchange(b, request, sync, wire_tick, wire_phase=0):
    seq, tick, phase = sync
    for _ in range(16000):
        if int(b.d.measurementValid.value):
            break
        await b.wait()
    assert int(b.d.measurementValid.value), 'history search did not publish'
    assert int(b.d.measurementDelayValid.value)
    assert int(b.d.measurementSequence.value) == seq
    assert int(b.d.measurementDelaySeq.value) == request
    assert int(b.d.measurementTicks.value) == wire_tick
    assert int(b.d.measurementGeneration.value) == b.generation
    assert int(b.d.measurementForward.value) == 150*Q16
    assert int(b.d.measurementDelay.value) == 100*Q16+Q16//4

    await b.pulse('snapshotCapture')
    values = [await b.read(a, w) for a, w in
              ((0x160, 12), (0x170, 12), (0x180, 12), (0x190, 12), (0x1a0, 16), (0x1b0, 8))]
    assert values == [wire_time(tick*8+phase-101),
                      capture_time((tick*8+phase)*Q16+3260416),
                      capture_time((wire_tick*8+wire_phase)*Q16+3260416),
                      wire_time(wire_tick*8+wire_phase+100), 49152, (1 << 64)-16384]
    held = b.payload(), int(b.d.measurementDelay.value)
    await b.wait(7)
    assert held == (b.payload(), int(b.d.measurementDelay.value))
    await b.drain()


@cocotb.test(timeout_time=5, timeout_unit='ms')
async def history_selection(d):
    for scenario, offset, tx_phase in (
            ('before', 140, 0), ('after', 160, 0), ('tie', 150, 0),
            ('wrapped_tie', 50, 0), ('rx_phase', 150, 0), ('tx_phase', 50, 7),
            ('age', 50, 0), ('maximum', 150, 0), ('concurrent', 50, 0)):
        async with history_bench(d, timeout=MIN_ASSOCIATION_TICKS if scenario == 'age' else None,
                                 maximum=20 if scenario == 'maximum' else None) as b:
            base = b.last_sync_tick
            phase = 7 if scenario == 'rx_phase' else 0
            await phase_sync(b, 3, base+100, phase)
            await phase_sync(b, 4, base+200)
            await phase_sync(b, 5, base+300)
            # Three qualification samples then three appends wrap slots 0/1.
            rows = [(4, base+200, 0), (5, base+300, 0), (2, base, 0), (3, base+100, phase)]
            request = await b.request()
            wire_tick = base+offset
            await b.wire(request, wire_tick, tx_phase)
            if scenario == 'age':
                # The oldest Sync is stale, while the later-born ledger key
                # and the three newer Syncs remain within the inclusive limit.
                b.now = base+MIN_ASSOCIATION_TICKS-9
            response = master_frame(9, request, wire_tick*8+tx_phase+100, -16384, minor=b.minor)
            await b.packet(response, ticks=b.now+10)
            if scenario == 'maximum':
                before = b.counts()
                await b.no_delay()
                assert b.counts() == (before[0], before[1]+1)
                continue

            # Python min is stable, so equal distances retain physical order.
            eligible = [row for row in rows if scenario != 'age' or b.now-row[1] <= MIN_ASSOCIATION_TICKS]
            selected = min(eligible, key=lambda row: abs((row[1]-wire_tick)*8+row[2]-tx_phase))
            if scenario == 'concurrent':
                await history_admission(b)
                pending = cocotb.start_soon(phase_sync(b, 6, base+400))
                try:
                    await b.wait(6)
                    assert not pending.done(), 'append bypassed history ownership'
                    await pending
                finally:
                    await cancel_and_join_tasks([pending])
            await selected_exchange(b, request, selected, wire_tick, tx_phase)


@cocotb.test(timeout_time=5, timeout_unit='ms')
async def history_cancellation(d):
    # Initial reads, shared-ALU admission/word boundaries, ABS and retirement.
    # Wrap the ring for ALU cases so its first physical row lies after TX.
    for phase in (*range(9), 9, 11, 13, 16, 19, 22, 25):
        async with history_bench(d) as b:
            if phase >= 9:
                await phase_sync(b, 3, b.last_sync_tick+200)
                await phase_sync(b, 4, b.last_sync_tick+300)
            request = await b.request()
            tick = b.last_sync_tick+100
            await b.wire(request, tick)
            await b.packet(b.response(request, tick), ticks=b.now+10)
            await history_admission(b)
            await b.wait(phase)
            if phase % 2:
                b.generation = 0xA5C381E0+phase
                d.generation.value = b.generation
                await b.wait(4)
            else:
                await b.pulse('rxAbort')
            await b.no_delay()
            await b.sync(100+phase, b.now+100)
            if phase == 1:
                # Qualify a new generation with high bits set, then verify its
                # packed history/capture provenance through a complete exchange.
                await b.sync(120, b.now+125000000)
                await b.sync(121, b.now+125000000)
                request = await b.request()
                tick = b.last_sync_tick+100
                await b.wire(request, tick)
                await b.packet(b.response(request, tick), ticks=b.now+10)
                await selected_exchange(b, request, (121, b.last_sync_tick, 0), tick)


@cocotb.test(timeout_time=5, timeout_unit='ms')
async def history_publication_priority(d):
    async with history_bench(d) as b:
        request = await b.request()
        tick = b.last_sync_tick+100
        await b.wire(request, tick)
        await b.packet(b.response(request, tick), ticks=b.now+10)

        async def rejected_traffic():
            # No idle edge between offers. Rejected packets do not write a
            # pairing row, so there is no RAM-write bubble for publication.
            for seq in range(200):
                await b.send(0, 1000+seq, source=0)
            assert False, 'completed exchange was starved by rejected Sync traffic'

        pending = cocotb.start_soon(rejected_traffic())
        try:
            for _ in range(16000):
                if int(d.measurementValid.value):
                    break
                await b.wait()
            assert int(d.measurementValid.value), 'E2E publication did not preempt the next scan'
            assert not pending.done()
            assert b.counts()[1] > 0, 'fixture must overlap E2E work with rejected traffic'
        finally:
            await cancel_and_join_tasks([pending])
            d.rxValid.value = 0
        await selected_exchange(b, request, (2, b.last_sync_tick, 0), tick)


@cocotb.test(timeout_time=5, timeout_unit='ms')
async def concurrent_rejections(d):
    """Propagation sampling: count RX handshakes at edges and diagnostics after TPD."""
    # The independent exchange model gives 100.25 ns; a 50 ns cap rejects it.
    async with history_bench(d, path_limit=50*Q16) as b:
        request = await b.request()
        tick = b.last_sync_tick+100
        await b.wire(request, tick)
        await b.packet(b.response(request, tick), ticks=b.now+10)
        await history_admission(b)
        before = b.counts()[1]
        accepted = 0
        pending_rx = 0
        previous = before
        # An unsupported message consumes one RX slot each ready edge, without
        # pairing or Announce storage. Keep capture provenance valid and stable.
        d.rxKind.value = 15
        d.rxValid.value = 1
        for _ in range(16000):
            await RisingEdge(d.clk)
            # Diagnostics retire the preceding edge's registered events.
            accepted += pending_rx
            pending_rx = int(d.rxReady.value)
            await Timer(1.1, unit='ns')
            count = b.counts()[1]
            if count > before+accepted:
                assert count == before+accepted+1
                assert count-previous == 2, 'RX and E2E must count on the same edge'
                break
            assert count == before+accepted
            previous = count
        else:
            assert False, 'bounded E2E rejection did not retire'
        d.rxValid.value = 0
        # A final RX event is still in the diagnostic pipeline. A logical
        # abort on its retirement edge must neither lose nor double-count it.
        d.rxAbort.value = 1
        await b.wait(1)
        d.rxAbort.value = 0
        count += pending_rx
        await b.wait(3)
        assert b.counts()[1] == count
        assert not int(d.measurementValid.value)
        for cause in ('restart', 'regRst', 'rxAbort'):
            await b.pulse(cause)
            assert b.counts()[1] == count, cause
        # Reset wins even while rejected traffic is offered.
        d.rxValid.value = 1
        d.rst.value = 1
        await b.wait(3)
        assert b.counts()[1] == 0
        d.rxValid.value = 0
        d.rst.value = 0
        await b.wait(3)
        assert b.counts()[1] == 0


@cocotb.test(timeout_time=5, timeout_unit='ms')
async def pair_cancellation_and_expiry(d):
    b = Bench(d)
    d.capturePhase.value = 0
    d.wirePhase.value = 0
    pending = None
    try:
        await b.start()
        for phase in range(1, 12):
            await b.pulse('restart')
            await b.send(8, 100, NS)
            await b.wait()  # Drain the previous whole-row write.
            pending = cocotb.start_soon(b.send(0, 100, NS, two_step=True))
            await b.wait(phase)
            assert not pending.done(), 'scan acknowledged before cancellation fixture'
            assert not int(d.measurementValid.value)
            await cancel_and_join_tasks([pending])
            pending = None
            d.rxValid.value = 0
            await b.pulse('rxAbort')
            # Same key must have neither the old Follow_Up nor its mode flags.
            await b.send(0, 100, NS)
            await b.result(100, 123*Q16+7)
            await b.drain()

        await b.configure(timeout=MIN_ASSOCIATION_TICKS)
        await b.send(8, 200, NS)
        born = b.now
        b.now = born+MIN_ASSOCIATION_TICKS-10
        pending = cocotb.start_soon(b.send(0, 200, NS))
        await b.wait(4)
        b.now += 1
        d.ticks.value = b.now
        # Snapshot age was exactly the inclusive limit: a one-step Sync still
        # conflicts with that retained Follow_Up, even if time advances mid-scan.
        before = b.counts()
        await pending
        pending = None
        await b.no_result()
        assert b.counts() == (before[0], before[1]+1)
        # At the next scan admission the association has expired and is reusable.
        await b.send(0, 200, NS)
        await b.result(200, 123*Q16+7)
        await b.drain()
    finally:
        tasks = [task for task in (pending, b.clock) if task is not None]
        await cancel_and_join_tasks(tasks)


@cocotb.test(timeout_time=5, timeout_unit='ms')
async def scan_word_boundaries(d):
    # Borrow across Q3 word 0, tick word 0 and the unsigned timestamp MSB.
    # Physical slot 0 is one eighth-tick after TX, slot 3 one eighth before:
    # the tie must select slot 0 even though its signed difference is negative.
    for base in ((1 << 29)-100, (1 << 32)-100, (1 << 63)-100, (1 << 64)-1000):
        async with history_bench(d, maximum=1, first_tick=base-250000000) as b:
            await phase_sync(b, 3, base+99, 7)
            await phase_sync(b, 4, base+100, 1)
            request = await b.request()
            await b.wire(request, base+100)
            await b.packet(b.response(request, base+100), ticks=b.now+10)
            await selected_exchange(b, request, (4, base+100, 1), base+100)

    # Keep a very old qualified history under explicitly enlarged timers. This
    # exercises the high Q3 word and an exact maximum-separation boundary; the
    # TX completion itself is current and within the normal ledger lifetime.
    separation = 1 << 61
    for extra in (0, 1):
        async with history_bench(d, timeout=(1 << 62)-1, maximum=separation, long_timers=True) as b:
            tick = b.last_sync_tick+100
            await phase_sync(b, 3, tick, interval=127)
            request = await b.request()
            wire_tick = tick+separation+extra
            await b.wire(request, wire_tick)
            await b.packet(b.response(request, wire_tick), ticks=b.now+10)
            before = b.counts()
            if extra:
                await b.no_delay()
                assert b.counts() == (before[0], before[1]+1)
            else:
                await selected_exchange(b, request, (3, tick, 0), wire_tick)


@cocotb.test(timeout_time=5, timeout_unit='ms')
async def pair_word_boundaries(d):
    b = Bench(d)
    d.capturePhase.value = 0
    d.wirePhase.value = 0
    try:
        await b.start()
        for base in ((1 << 32)-100, (1 << 63)-100, (1 << 64)-100):
            await b.pulse('restart')
            b.now = base
            d.ticks.value = b.now
            await b.send(8, 200, NS)
            born = b.now
            # The third case crosses tick wrap. Ages remain modulo 64, whereas
            # oldest-row ordering is the existing ordinary unsigned ordering.
            b.now = (born+MIN_ASSOCIATION_TICKS-10) % (1 << 64)
            before = b.counts()
            await b.send(0, 200, NS)
            await b.no_result()
            assert b.counts() == (before[0], before[1]+1)
            await b.send(0, 200, NS)
            await b.result(200, 123*Q16+7)
            await b.drain()

        # Fill complete rows across a 32-bit carry, then require the oldest
        # complete row to be reclaimed, preserving all three newer keys.
        await b.pulse('restart')
        b.now = (1 << 32)-25
        d.ticks.value = b.now
        for seq in range(4):
            await b.send(0, seq, NS+80*seq)
            await b.result(seq, 123*Q16+7)
            await b.drain()
        await b.send(0, 4, NS+320)
        await b.result(4, 123*Q16+7)
        await b.drain()
        for seq in (1, 2, 3, 4):
            before = b.counts()
            await b.send(0, seq, NS+80*seq)
            await b.no_result()
            assert b.counts() == (before[0], before[1]+1)
        await b.send(0, 0, NS+400)
        await b.result(0, 123*Q16+7)
        await b.drain()
    finally:
        await cancel_and_join_tasks([b.clock])


@cocotb.test(timeout_time=5, timeout_unit='ms')
async def scan_overlap(d):
    for cancel in (False, True):
        async with history_bench(d) as b:
            request = await b.request()
            tick = b.last_sync_tick+100
            await b.wire(request, tick)
            await b.packet(b.response(request, tick), ticks=b.now+10)
            # Start a pair lookup before the ledger publishes its joined sample.
            # Observe read enables only to prove that this stimulus exercised two
            # admitted scans; expected results still come from public interfaces.
            remote = b.now*8+1000
            pending = cocotb.start_soon(b.send(8, 123, remote))
            seen_pair_read = False
            try:
                for _ in range(2*(4*45+22+8)):
                    await RisingEdge(d.clk)
                    admitted = int(d.u_dut.delayready.value)
                    seen_pair_read |= bool(int(d.u_dut.u_pairram.enb.value))
                    await Timer(1.1, unit='ns')
                    if admitted:
                        assert seen_pair_read and not pending.done(), 'fixture missed concurrent scans'
                        break
                else:
                    assert False, 'history did not enter during pair scan'
                if cancel:
                    await b.wait(10)
                    assert not pending.done(), 'pair finished before the overlap cancellation'
                    await cancel_and_join_tasks([pending])
                    d.rxValid.value = 0
                    await b.pulse('restart')
                    await b.no_delay()
                else:
                    await pending
            finally:
                await cancel_and_join_tasks([pending])
            if not cancel:
                await selected_exchange(b, request, (2, b.last_sync_tick, 0), tick)
            # Normal completion retains Follow_Up. Restart clears it, allowing a
            # fresh one-step Sync with the same key instead of a mode conflict.
            await b.send(0, 123, remote, two_step=not cancel)
            await b.result(123, 123*Q16+7)
            await b.drain()


@pytest.mark.parametrize('memory', ['distributed', 'block'])
@pytest.mark.parametrize('scenario', ['history_selection', 'history_cancellation', 'history_publication_priority',
                                    'pair_cancellation_and_expiry', 'concurrent_rejections',
                                    'scan_word_boundaries', 'pair_word_boundaries', 'scan_overlap'])
def test_protocol_ram(memory, scenario):
    run_surf_vhdl_test(
        test_file=__file__, toplevel='surf.ptpprotocolenginewrapper',
        extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpProtocolEngineWrapper.vhd"]},
        parameters={'HISTORY_MEMORY_TYPE_G': memory, 'PAIR_MEMORY_TYPE_G': memory,
                    'PACKET_LIFETIME_G': 2*MIN_ASSOCIATION_TICKS},
        extra_env=cocotb_filtered_env({}, cocotb_test_filter(scenario)))
