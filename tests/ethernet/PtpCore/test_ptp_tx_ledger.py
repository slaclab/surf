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
# - Sweep: Depths one/three/four, distributed/block RAM, two-bit sequence wrap.
# - Stimulus: Independent full-width payload patterns, reversed completions,
#   simultaneous inputs, stalls, raw-time expiry, duplicate/mutated records,
#   logical restart and physical/system reset at every scan phase.
# - Checks: Exact capture/response provenance, registered controls, bounded
#   handshakes, single-count retirement, unresolved ownership and safe reuse.
# - Timing: Manually driven 6.4 ns clock, checks after TPD. RAM rows are visited
#   every two clocks; one scan is 45*depth+2 clocks. Event sources hold their
#   complete records through ready. Raw time jumps accelerate quarantine only.

import cocotb
import pytest
from cocotb.triggers import Timer
from tests.common.regression_utils import (
    cocotb_filtered_env, cocotb_test_filter, env_int, run_surf_vhdl_test,
)

IDENTITY = int("001122fffe3344550001", 16)


class LedgerBench:
    def __init__(self, d, timeout=1000000):
        self.d = d
        self.now = 0
        self.depth = env_int('DEPTH_G', default=2)
        self.scan = 45*self.depth+2
        self.lifetime = env_int('PACKET_LIFETIME_G', default=10000)
        for name in ("clk", "rst", "restart", "macResetDone", "ticks", "generation", "domainNumber", "allocate",
                     "wireValid", "wireSequence", "wireDomain", "wireTicks", "wireGeneration", "wireError",
                     "wireTimestamp", "wireIncrement", "wirePhase", "wireTimeValid", "responseTimestamp", "responseCorrection",
                     "responseValid", "responseSequence", "responseDomain", "responseTicks", "responseGeneration", "sampleReady"):
            getattr(d, name).value = 0
        for name in ("identity", "wireIdentity", "responseIdentity"):
            getattr(d, name).value = IDENTITY
        d.timeout.value = timeout

    async def edge(self, **values):
        d = self.d
        outputs = ('allocateReady', 'wireReady', 'responseReady', 'responseAccepted', 'sampleValid')
        before = tuple(int(getattr(d, name).value) for name in outputs) if self.now else None
        d.clk.value = 0
        d.ticks.value = self.now
        for name, value in values.items():
            getattr(d, name).value = value
        await Timer(3.2, unit="ns")
        if before is not None:
            assert before == tuple(int(getattr(d, name).value) for name in outputs), "registered output changed between edges"
        d.clk.value = 1
        await Timer(3.2, unit="ns")
        self.now += 1

    async def idle(self, count=None):
        for _ in range(self.scan*2 if count is None else count):
            await self.edge()

    async def until(self, name):
        for _ in range(self.scan*3):
            if int(getattr(self.d, name).value):
                return
            await self.edge()
        assert False, f"{name} did not arrive within three scans"

    async def mac_reset(self):
        await self.edge(macResetDone=1, wireValid=0, responseValid=0, allocate=0, restart=0)
        assert int(self.d.ledgerStatus.value) == 3
        await self.edge(macResetDone=0)
        self.now += self.lifetime+1
        await self.idle()
        await self.until('allocateReady')

    async def start(self):
        await self.edge(rst=1)
        await self.edge(rst=0)
        assert not int(self.d.allocateReady.value)
        await self.mac_reset()

    async def allocate(self):
        await self.until('allocateReady')
        seq = int(self.d.allocateSequence.value)
        await self.edge(allocate=1)
        await self.edge(allocate=0)
        return seq

    async def submit(self, *, wire=None, response=None):
        """Hold each source independently through its registered ready edge."""
        pending = {}
        values = {}
        for lane, payload in (('wire', wire), ('response', response)):
            if payload is not None:
                pending[lane] = True
                values.update(payload)
                values[lane+'Valid'] = 1
        accepted = False
        for _ in range(self.scan*3):
            # These sources were inactive before the first edge, so a stale
            # ready pulse cannot acknowledge a newly presented record.
            transfers = [lane for lane in pending if not values and int(getattr(self.d, lane+'Ready').value)]
            await self.edge(**values)
            values = {}
            for lane in transfers:
                del pending[lane]
                values[lane+'Valid'] = 0
                if lane == 'response':
                    accepted = bool(int(self.d.responseAccepted.value))
            if not pending:
                await self.edge(**values)
                assert not int(self.d.responseAccepted.value), "response result did not pulse"
                return accepted
        assert False, "ledger input stalled beyond three scans"

    def occupancy(self):
        value = int(self.d.ledgerStatus.value)
        return (value >> 8) & 255, (value >> 16) & 255

    def payload(self):
        return {name: int(getattr(self.d, name).value) for name in (
            'sampleSequence', 'sampleTicks', 'sampleGeneration', 'sampleTimestamp',
            'sampleIncrement', 'samplePhase', 'sampleTimeValid', 'sampleCaptureGeneration',
            'sampleError', 'sampleRemoteTime', 'sampleCorrection', 'sampleResponseTicks')}


@cocotb.test()
async def lifecycle(d):
    tb = LedgerBench(d)
    await tb.start()
    first = await tb.allocate()
    assert tb.occupancy() == (1, 1)
    tick = tb.now
    assert await tb.submit(response=dict(responseSequence=first, responseTicks=tick+1))
    await tb.submit(wire=dict(wireSequence=first, wireTicks=tick))
    assert tb.occupancy() == (1, 0)
    await tb.until('sampleValid')
    assert int(d.sampleSequence.value) == first
    assert int(d.sampleTicks.value) == tick
    await tb.edge(restart=1, sampleReady=1, generation=1)
    assert not int(d.sampleValid.value)
    await tb.edge(restart=0, sampleReady=0)
    second = await tb.allocate()
    tb.now += 1000001
    await tb.idle()
    assert tb.occupancy() == (1, 1), "timeout released an unknown wire fate"
    assert int(d.timeoutCount.value) == 1
    await tb.edge(restart=1, generation=2)
    await tb.edge(restart=0)
    await tb.submit(wire=dict(wireSequence=second, wireTicks=tb.now, wireGeneration=1))
    assert not int(d.sampleValid.value)
    tb.now += tb.lifetime+1
    await tb.idle()
    assert tb.occupancy() == (0, 0)
    seen = []
    for _ in range(8):
        seq = await tb.allocate()
        seen.append(seq)
        tick = tb.now
        assert await tb.submit(wire=dict(wireSequence=seq, wireTicks=tick, wireGeneration=2),
                               response=dict(responseSequence=seq, responseTicks=tick+1, responseGeneration=2))
        await tb.until('sampleValid')
        assert int(d.sampleSequence.value) == seq
        await tb.edge(sampleReady=1)
        await tb.edge(sampleReady=0)
        tb.now += tb.lifetime+1
        await tb.idle()
    assert len(set(seen)) == 4
    await tb.allocate()
    await tb.allocate()
    await tb.mac_reset()
    assert tb.occupancy() == (0, 0)


@cocotb.test()
async def counter_batches(d):
    tb = LedgerBench(d)
    await tb.start()
    for _ in range(tb.depth):
        await tb.allocate()
    tb.now += 1000001
    await tb.idle()
    assert int(d.timeoutCount.value) == tb.depth
    assert int(d.rejectedCount.value) == 0
    assert tb.occupancy() == (tb.depth, tb.depth)
    await tb.edge(restart=1)
    await tb.edge(restart=0)
    await tb.idle()
    assert int(d.timeoutCount.value) == tb.depth
    await tb.mac_reset()
    assert int(d.timeoutCount.value) == tb.depth

    sequences = [await tb.allocate() for _ in range(tb.depth)]
    wire_ticks = []
    for seq in sequences:
        wire_ticks.append(tb.now)
        await tb.submit(wire=dict(wireSequence=seq, wireTicks=tb.now))
    response = None if tb.depth == 1 else dict(responseSequence=sequences[1], responseTicks=wire_ticks[1]-1)
    accepted = await tb.submit(wire=dict(wireSequence=sequences[0], wireTicks=tb.now), response=response)
    expected = 1 if tb.depth == 1 else 2
    assert int(d.rejectedCount.value) == expected
    assert accepted == (tb.depth > 1)
    assert not int(d.sampleValid.value)
    await tb.mac_reset()
    assert int(d.rejectedCount.value) == expected

    seq = await tb.allocate()
    assert not await tb.submit(wire=dict(wireSequence=seq, wireTicks=tb.now, wireError=1),
                               response=dict(responseSequence=seq, responseTicks=tb.now+1))
    assert int(d.rejectedCount.value) == expected+1
    await tb.edge(restart=1)
    await tb.edge(restart=0)
    assert int(d.rejectedCount.value) == expected+1
    await tb.edge(rst=1)
    assert int(d.rejectedCount.value) == 0
    assert int(d.timeoutCount.value) == 0
    assert not int(d.sampleValid.value)


@cocotb.test()
async def capture_storage(d):
    tb = LedgerBench(d)
    await tb.start()
    generation = 0x12345678
    await tb.edge(generation=generation, wireGeneration=generation, responseGeneration=generation)
    for batch in range(3):
        sequences = [await tb.allocate() for _ in range(tb.depth)]
        for index in reversed(range(tb.depth)):
            seq = sequences[index]
            pattern = batch*tb.depth+index
            timestamp = ((0x987654321000+pattern) << 48) | ((123456789+pattern) << 16) | (0xffff-pattern)
            increment = 0xfedcba9876543200+pattern
            remote = ((0xabcdef001000+pattern) << 32) | (987654321-pattern)
            correction = (-(1 << 60)+pattern) & ((1 << 64)-1)
            tick = tb.now
            wire = dict(wireSequence=seq, wireTicks=tick, wireTimestamp=timestamp,
                        wireIncrement=increment, wirePhase=pattern % 8, wireTimeValid=pattern % 2)
            response = dict(responseSequence=seq, responseTicks=tick+1, responseTimestamp=remote,
                            responseCorrection=correction)
            if pattern % 3 == 0:
                await tb.submit(wire=wire)
                assert await tb.submit(response=response)
            elif pattern % 3 == 1:
                assert await tb.submit(response=response)
                await tb.submit(wire=wire)
            else:
                assert await tb.submit(wire=wire, response=response)
            await tb.until('sampleValid')
            expected = dict(sampleSequence=seq, sampleTicks=tick, sampleGeneration=generation,
                            sampleTimestamp=timestamp, sampleIncrement=increment, samplePhase=pattern % 8,
                            sampleTimeValid=pattern % 2, sampleCaptureGeneration=generation, sampleError=0,
                            sampleRemoteTime=remote, sampleCorrection=correction, sampleResponseTicks=tick+1)
            assert tb.payload() == expected
            await tb.submit(wire=dict(wireSequence=seq, wireTicks=tb.now, wireTimestamp=0, wireIncrement=0,
                                      wirePhase=0, wireTimeValid=0))
            assert tb.payload() == expected, "duplicate changed an already published sample"
            await tb.idle()
            assert tb.payload() == expected and int(d.sampleValid.value)
            await tb.edge(sampleReady=1)
            await tb.edge(sampleReady=0)
        tb.now += tb.lifetime+1
        await tb.idle()

    # An output stall cannot block incoming records for other RAM rows. Check
    # every field again while completed rows wait for their output turn.
    await tb.mac_reset()
    sequences = [await tb.allocate() for _ in range(tb.depth)]
    # Keep valid asserted between consecutive records, as the real tap FIFO
    # does. Change each record only after its own ready/valid transfer.
    for index in reversed(range(tb.depth)):
        values = dict(wireValid=1, wireSequence=sequences[index], wireTicks=tb.now,
                      wireTimestamp=(1 << 94)+index, wireIncrement=(1 << 63)+index,
                      responseValid=1, responseSequence=sequences[index], responseTicks=tb.now)
        await tb.edge(**values)
        for _ in range(tb.scan*3):
            if int(d.wireReady.value) and int(d.responseReady.value):
                await tb.edge()
                assert int(d.responseAccepted.value)
                break
            await tb.edge()
        else:
            assert False, 'continuous sources did not transfer'
    await tb.edge(wireValid=0, responseValid=0)
    observed = set()
    for _ in range(tb.depth):
        await tb.until('sampleValid')
        seq = int(d.sampleSequence.value)
        index = sequences.index(seq)
        assert seq not in observed
        observed.add(seq)
        assert int(d.sampleTimestamp.value) == (1 << 94)+index
        assert int(d.sampleIncrement.value) == (1 << 63)+index
        await tb.edge(sampleReady=1)
        await tb.edge(sampleReady=0)
    assert observed == set(sequences)


@cocotb.test()
async def cancellation(d):
    tb = LedgerBench(d)
    await tb.start()
    # Sweep a complete scan period, including read, update, acknowledgement and
    # allocation phases. Any early publication is held until the cancellation.
    for abort in ('restart', 'macResetDone', 'rst'):
        for delay in range(tb.scan+1):
            await tb.mac_reset()
            seq = await tb.allocate()
            tick = tb.now
            await tb.edge(wireValid=1, wireSequence=seq, wireTicks=tick, wireTimestamp=(1 << 95)+delay,
                          responseValid=1, responseSequence=seq, responseTicks=tick)
            for phase in range(delay+1):
                wire_taken = int(d.wireValid.value) and int(d.wireReady.value)
                response_taken = int(d.responseValid.value) and int(d.responseReady.value)
                await tb.edge(**({abort: 1} if phase == delay else {}))
                if wire_taken:
                    d.wireValid.value = 0
                if response_taken:
                    d.responseValid.value = 0
            assert not int(d.sampleValid.value)
            # Logical cancellation may withdraw the response, but the physical
            # completion source must still drain its owned record through ready.
            d.responseValid.value = 0
            if abort != 'restart':
                d.wireValid.value = 0
            await tb.edge(**{abort: 0})
            if int(d.wireValid.value):
                await tb.until('wireReady')
                await tb.edge()
                await tb.edge(wireValid=0)
            await tb.idle()
            assert not int(d.sampleValid.value), "stale RAM result survived cancellation"
            if abort == 'restart':
                assert tb.occupancy() == (1, 0), "logical reset lost the physical completion"
    await tb.mac_reset()
    seq = await tb.allocate()
    assert await tb.submit(wire=dict(wireSequence=seq, wireTicks=tb.now, wireTimestamp=0x123456789abcdef),
                           response=dict(responseSequence=seq, responseTicks=tb.now))
    await tb.until('sampleValid')
    assert int(d.sampleTimestamp.value) == 0x123456789abcdef


@cocotb.test()
async def slot_reuse(d):
    tb = LedgerBench(d)
    await tb.start()
    first = await tb.allocate()
    assert await tb.submit(wire=dict(wireSequence=first, wireTicks=tb.now, wireTimestamp=0x123456789),
                           response=dict(responseSequence=first, responseTicks=tb.now))
    await tb.until('sampleValid')
    expected = tb.payload()
    tb.now += tb.lifetime+1
    await tb.idle()
    assert tb.occupancy() == (0, 0)
    second = await tb.allocate()
    assert second != first
    assert await tb.submit(wire=dict(wireSequence=second, wireTicks=tb.now, wireTimestamp=0xfedcba987),
                           response=dict(responseSequence=second, responseTicks=tb.now))
    assert tb.payload() == expected, "reused RAM row corrupted stalled output"
    await tb.edge(sampleReady=1)
    await tb.edge(sampleReady=0)
    await tb.until('sampleValid')
    assert int(d.sampleTimestamp.value) == 0xfedcba987
    assert int(d.sampleSequence.value) == second


@cocotb.test()
async def keys_and_duplicates(d):
    tb = LedgerBench(d)
    await tb.start()
    sequences = [await tb.allocate() for _ in range(4)]
    assert set(sequences) == {0, 1, 2, 3}
    # Three unresolved keys survive sequence wrap. Only the physically known
    # fourth key can be reclaimed, so searching must find that exact sequence.
    await tb.submit(wire=dict(wireSequence=2, wireTicks=tb.now))
    await tb.edge(restart=1)
    await tb.edge(restart=0)
    tb.now += tb.lifetime+1
    await tb.idle()
    assert tb.occupancy() == (3, 3)
    new_identity = 0xfedcba98765432108001
    await tb.edge(identity=new_identity, domainNumber=0xa5)
    seq = await tb.allocate()
    assert seq == 2
    tick = tb.now
    # The new row's complete identity/domain and generation are required.
    response = dict(responseSequence=seq, responseTicks=tick+1, responseTimestamp=0x12345678,
                    responseIdentity=new_identity, responseDomain=0xa5)
    assert not await tb.submit(response=dict(response, responseIdentity=IDENTITY))
    assert not await tb.submit(response=dict(response, responseDomain=0))
    assert not await tb.submit(response=dict(response, responseGeneration=1))
    await tb.edge(responseGeneration=0)
    assert await tb.submit(response=response)
    assert not await tb.submit(response=dict(response, responseTicks=tick+20))
    assert int(d.rejectedCount.value) == 0, 'identical repeat poisoned the exchange'
    assert not await tb.submit(response=dict(response, responseTimestamp=0x12345679))
    assert int(d.rejectedCount.value) == 1, 'conflicting repeat did not retire'
    await tb.submit(wire=dict(wireSequence=seq, wireTicks=tb.now, wireIdentity=new_identity, wireDomain=0xa5))
    assert not int(d.sampleValid.value)
    assert tb.occupancy() == (4, 3)
    # Existing entries still match their original allocation identity, even
    # after the active configuration changes to a different identity/domain.
    await tb.submit(wire=dict(wireSequence=0, wireTicks=tb.now, wireIdentity=IDENTITY, wireDomain=0))
    assert tb.occupancy()[1] == 2


@cocotb.test()
async def deferred_duplicate(d):
    tb = LedgerBench(d)
    await tb.start()
    for lane in ('wire', 'response'):
        await tb.mac_reset()
        first = await tb.allocate()
        second = await tb.allocate()
        for seq in (first, second):
            assert await tb.submit(wire=dict(wireSequence=seq, wireTicks=tb.now),
                                   response=dict(responseSequence=seq, responseTicks=tb.now, responseTimestamp=0))
        assert int(d.sampleSequence.value) == first and int(d.sampleValid.value)
        # submit() returned just after START with both lanes idle. Present a
        # duplicate after that boundary while releasing the preceding output.
        # The second row must wait until this new record can retire it.
        values = (dict(wireValid=1, wireSequence=second, wireTicks=tb.now) if lane == 'wire' else
                  dict(responseValid=1, responseSequence=second, responseTimestamp=1))
        await tb.edge(sampleReady=1, **values)
        for _ in range(tb.scan*3):
            assert not int(d.sampleValid.value), 'sample bypassed an unscanned duplicate'
            if int(getattr(d, lane+'Ready').value):
                await tb.edge()
                assert not int(d.responseAccepted.value)
                break
            await tb.edge()
        else:
            assert False, 'pending duplicate did not drain'
        await tb.edge(wireValid=0, responseValid=0, sampleReady=0)
        await tb.idle()
        assert not int(d.sampleValid.value)
    assert int(d.rejectedCount.value) == 2


def test_ptp_tx_ledger():
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptptxledgerwrapper", parameters={"PACKET_LIFETIME_G": 10000},
                      extra_env=cocotb_filtered_env({}, cocotb_test_filter('lifecycle')))


@pytest.mark.parametrize('depth', [1, 4], ids=['one', 'four'])
def test_ptp_tx_ledger_counters(depth):
    parameters = {'PACKET_LIFETIME_G': 10000, 'DEPTH_G': depth, 'SEQUENCE_BITS_G': 3}
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptptxledgerwrapper", parameters=parameters,
                      extra_env=cocotb_filtered_env(parameters, cocotb_test_filter('counter_batches')))


@pytest.mark.parametrize('depth,memory_type', [(1, 'distributed'), (3, 'distributed'), (4, 'distributed'), (4, 'block')],
                         ids=['one-lut', 'three-lut', 'four-lut', 'four-block'])
def test_ptp_tx_ledger_storage(depth, memory_type):
    parameters = {'PACKET_LIFETIME_G': 10000, 'DEPTH_G': depth, 'SEQUENCE_BITS_G': 3, 'MEMORY_TYPE_G': memory_type}
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptptxledgerwrapper", parameters=parameters,
                      extra_env=cocotb_filtered_env(parameters, cocotb_test_filter('capture_storage')))


def test_ptp_tx_ledger_cancellation():
    parameters = {'PACKET_LIFETIME_G': 10000, 'DEPTH_G': 4, 'SEQUENCE_BITS_G': 3}
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptptxledgerwrapper", parameters=parameters,
                      extra_env=cocotb_filtered_env(parameters, cocotb_test_filter('cancellation')))


def test_ptp_tx_ledger_slot_reuse():
    parameters = {'PACKET_LIFETIME_G': 10000, 'DEPTH_G': 1, 'SEQUENCE_BITS_G': 3}
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptptxledgerwrapper", parameters=parameters,
                      extra_env=cocotb_filtered_env(parameters, cocotb_test_filter('slot_reuse')))


def test_ptp_tx_ledger_keys():
    parameters = {'PACKET_LIFETIME_G': 10000, 'DEPTH_G': 4, 'SEQUENCE_BITS_G': 2}
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptptxledgerwrapper", parameters=parameters,
                      extra_env=cocotb_filtered_env(parameters, cocotb_test_filter('keys_and_duplicates')))


def test_ptp_tx_ledger_deferred_duplicate():
    parameters = {'PACKET_LIFETIME_G': 10000, 'DEPTH_G': 4, 'SEQUENCE_BITS_G': 3}
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptptxledgerwrapper", parameters=parameters,
                      extra_env=cocotb_filtered_env(parameters, cocotb_test_filter('deferred_duplicate')))
