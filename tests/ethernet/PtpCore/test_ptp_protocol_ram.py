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
#   concurrent RX/E2E rejections count twice and only system reset clears them.
# - Timing: Raw ticks advance between events while ordinary pipeline clocks
#   continue. Internal ledger ready is observed only to target cancellation and
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
async def history_bench(d, *, timeout=None, maximum=None, path_limit=None):
    b = ExchangeBench(d)
    d.capturePhase.value = 0
    d.wirePhase.value = 0
    try:
        await b.setup()
        if timeout is not None or maximum is not None or path_limit is not None:
            if timeout is not None:
                await b.write(0x090, timeout)
            if maximum is not None:
                await b.write(0x098, maximum)
            if path_limit is not None:
                await b.write(0x0B8, path_limit)
            d.prepare.value = 1
            await b.wait()
            d.prepare.value = 0
            await b.wait_config()
            assert int(d.configValid.value)
            await b.pulse('applyConfig')
        await b.qualify()
        yield b
    finally:
        if b.clock is not None:
            await cancel_and_join_tasks([b.clock])


async def phase_sync(b, seq, ticks, phase=0):
    b.d.capturePhase.value = phase
    remote = ticks*8+phase-101
    await b.packet(master_frame(0, seq, remote, 49152, minor=b.minor, two_step=False),
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
    # Admission, all four read/check pairs, and the final publication boundary.
    for phase in range(9):
        async with history_bench(d) as b:
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
        previous = before
        # An unsupported message consumes one RX slot each ready edge, without
        # pairing or Announce storage. Keep capture provenance valid and stable.
        d.rxKind.value = 15
        d.rxValid.value = 1
        for _ in range(16000):
            await RisingEdge(d.clk)
            accepted += int(d.rxReady.value)
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
        await b.wait(4)
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


@pytest.mark.parametrize('memory', ['distributed', 'block'])
@pytest.mark.parametrize('scenario', ['history_selection', 'history_cancellation', 'history_publication_priority',
                                    'pair_cancellation_and_expiry', 'concurrent_rejections'])
def test_protocol_ram(memory, scenario):
    run_surf_vhdl_test(
        test_file=__file__, toplevel='surf.ptpprotocolenginewrapper',
        parameters={'HISTORY_MEMORY_TYPE_G': memory, 'PAIR_MEMORY_TYPE_G': memory,
                    'PACKET_LIFETIME_G': 2*MIN_ASSOCIATION_TICKS},
        extra_env=cocotb_filtered_env({}, cocotb_test_filter(scenario)))
