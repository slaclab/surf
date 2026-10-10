#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: 2019/2008-compatible multicast master headers, one-/two-step Sync,
#   Delay_Resp before/after TX observation, overflow in every correction operand.
# - Stimulus: Source-backed packets and one-field response mutations; independent
#   master timestamps at 1 Hz Sync / 0.5 Hz Announce. No DUT-derived master clock.
# - Checks: Independent literal byte anchors through the real RX frontend;
#   real protocol/ledger/E2E exact forward=150 ns and delay=100.25 ns, provenance,
#   stalled results, rejection, no resurrection, and fresh-exchange recovery.
# - Timing: The protocol fixture advances raw ticks between events, skipping
#   idle seconds while preserving timestamp/interval values. Pipeline clocks
#   still run normally. No PHC, servo, physical-MAC or profile-conformance claim.
# - Authority: 1588-2019 9.5.7, 11.2/11.3.2, 13.2/13.3/Table 42, 13.5--13.8,
#   Annex F. Retiring overflow exchanges is explicit local receiver policy.

import os

import cocotb
import pytest

from tests.common.regression_utils import cocotb_filtered_env, cocotb_test_filter, run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_master_test_utils import master_frame, LOCAL
from tests.ethernet.PtpCore.test_ptp_port_samples import Bench, capture_time
from tests.ethernet.PtpCore.test_ptp_rx_rtl import Bench as RxBench
from tests.ethernet.PtpCore.test_ptp_specification import decoded_header

Q16 = 65536
HZ = 125000000
OVERFLOW = 0x7fffffffffffffff


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def master_headers(d):
    b = RxBench(d)
    await b.reset()
    await b.wait(messageReady=0)
    # Complete independent common/body byte anchors. These values are not
    # calculated by the encoder or the RX reference model.
    golden = {
        0: '0012002c00000200000000000000000000000000'
           '001122fffe33445500011234000000000000000000000000',
        8: '0812002c00000000000000000000c00000000000'
           '001122fffe33445500011234000000000000002a075bcd15',
        9: '0912003600000000ffffffffffffc00000000000'
           '001122fffe33445500011234000000000000002a075bcd15'
           '020000fffe0000010001',
        11: '0b12004000000000000000000000000000000000'
            '001122fffe33445500011234000100000000000000000000'
            '00000080f8feffff80001122fffe3344550000a0',
    }
    for minor in (0, 1):
        for kind in (0, 8, 9, 11):
            remote = 42123456789 if kind in (8, 9) else 0
            correction = {0: 0, 8: 49152, 9: -16384, 11: 0}[kind]
            packet = master_frame(kind, 0x1234, remote, correction, minor=minor, two_step=True)
            expected = bytearray.fromhex(golden[kind])
            expected[1] = minor << 4 | 2
            expected[32] = {0: 0, 8: 2, 9: 3, 11: 5}[kind] if minor == 0 else 0
            expected = (bytes.fromhex('011b1900000000112233445588f7')+expected).ljust(60, b'\x00')
            assert packet == expected, (kind, minor, packet.hex(), expected.hex())
            await b.direct(packet)
            await b.wait()
            assert int(d.messageValid.value)
            header = decoded_header(int(d.messageData.value))
            assert header == dict(kind=kind, minor=minor, transport=0, domain=0,
                                  length={0: 44, 8: 44, 9: 54, 11: 64}[kind],
                                  flags=512 if kind == 0 else 0, correction=correction,
                                  source=0x001122fffe3344550001, sequence=0x1234,
                                  destination=0x011b19000000, control=expected[46],
                                  interval=1 if kind == 11 else 0,
                                  body=expected[48:14+header['length']].ljust(30, b'\x00'))
            await b.wait(1, messageReady=1)
            await b.wait(messageReady=0)


class ExchangeBench(Bench):
    def __init__(self, d):
        super().__init__(d)
        self.wire_ticks = {}
        self.minor = int(os.environ.get('MINOR', '1'))
        self.two_step = os.environ.get('TWO_STEP', '1') == '1'
        d.txReady.value = 0
        d.wireValid.value = 0
        d.snapshotCapture.value = 0
        d.rxBodyTail.value = 0
        d.rxLogInterval.value = 0

    async def setup(self):
        await self.start()
        await self.write(0x008, self.minor << 8, 4)
        await self.write(0x080, HZ)
        await self.write(0x098, 2*HZ)
        await self.configure(min_span=1000000, timeout=3*HZ)
        # configure() uses short fallback timers: use ordinary seconds here.
        await self.write(0x0A0, HZ//2)
        await self.write(0x088, 3*HZ)
        await self.write(0x0A8, 4*HZ)
        self.d.prepare.value = 1
        await self.wait()
        self.d.prepare.value = 0
        assert int(self.d.configValid.value)
        await self.pulse('applyConfig')
        self.now = 10000
        self.d.ticks.value = self.now
        await self.wait(3)

    async def packet(self, packet, *, ticks=None, local=None, generation=None):
        # Flat transaction ABI only. Byte validation is separately exercised
        # by master_headers; this adapter is not an independent parser oracle.
        self.d.rxLogInterval.value = packet[47]
        self.d.rxBodyTail.value = int.from_bytes(packet[58:78].ljust(20, b'\x00'), 'big')
        await self.send(packet[14] & 15, int.from_bytes(packet[44:46], 'big'),
                        correction=int.from_bytes(packet[22:30], 'big', signed=True),
                        timestamp=int.from_bytes(packet[48:58], 'big'), flags=int.from_bytes(packet[20:22], 'big'),
                        control=packet[46], source=int.from_bytes(packet[34:44], 'big'),
                        domain=packet[18], ticks=ticks, local=local, generation=generation)

    async def sync(self, seq, ticks, *, two_step=None):
        two_step = self.two_step if two_step is None else two_step
        # Master departure=ticks*8-100.25, PHC arrival=ticks*8+49.75.
        # Forward = 150 ns; fractional timestamp rides in correctionField.
        self.last_sync_tick = ticks
        self.last_sync_seq = seq
        remote = ticks*8-101
        await self.packet(master_frame(0, seq, 0 if two_step else remote,
                                       0 if two_step else 49152, minor=self.minor, two_step=two_step),
                          ticks=ticks, local=ticks*8*Q16+3260416)
        if two_step:
            await self.no_result()
            await self.packet(master_frame(8, seq, remote, 49152, minor=self.minor))
        result = await self.result(seq, 9830400, ticks)
        assert not int(self.d.measurementDelayValid.value)
        await self.drain()
        return result

    async def qualify(self):
        for i in range(3):
            ticks = 20000+i*HZ
            if i % 2 == 0:
                await self.packet(master_frame(11, i//2, minor=self.minor), ticks=ticks-100)
            result = await self.sync(i, ticks)
        assert result[4:] == (8 << 48, 1), result
        assert self.counts() == (3, 0)

    async def request(self):
        for _ in range(30):
            if int(self.d.txValid.value):
                break
            await self.wait()
        assert int(self.d.txValid.value), 'no Delay_Req after rate qualification'
        packet = bytearray()
        for beat in range(8):
            assert int(self.d.txValid.value)
            data = int(self.d.txData.value)
            assert (int(self.d.txKeep.value), int(self.d.txSof.value), int(self.d.txLast.value),
                    int(self.d.txEofe.value)) == (3 if beat == 7 else 255, int(beat == 0), int(beat == 7), 0)
            packet.extend(data.to_bytes(8, 'little')[:2 if beat == 7 else 8])
            self.d.txReady.value = 1
            await self.wait()
            self.d.txReady.value = 0
        assert packet[:14] == bytes.fromhex('011b1900000002000000000188f7')
        assert packet[14:20] == bytes((1, self.minor << 4 | 2, 0, 44, 0, 0))
        assert packet[20:34] == bytes(14)
        assert packet[34:44] == LOCAL
        assert packet[46:] == bytes((1 if self.minor == 0 else 0, 127))+bytes(10)
        return int.from_bytes(packet[44:46], 'big')

    async def wire(self, seq, ticks):
        self.wire_ticks[seq] = ticks
        self.d.wireSequence.value = seq
        self.d.wireTicks.value = ticks
        self.d.wireTime.value = capture_time(ticks*8*Q16+3260416)
        self.d.wireGeneration.value = self.generation
        self.now = max(self.now, ticks)
        self.d.ticks.value = self.now
        await self.pulse('wireValid')

    def response(self, seq, ticks, **kwargs):
        # Corrected master receipt=ticks*8+100.25 ns. A negative quarter-ns
        # correction recovers the fraction omitted by the integer timestamp.
        return master_frame(9, seq, ticks*8+100, -16384, minor=self.minor, **kwargs)

    async def read(self, address, width=4):
        result = await self.axil.read(address, width)
        assert int(result.resp) == 0
        return int.from_bytes(result.data, 'little')

    async def delay_result(self, seq):
        for _ in range(1500):
            if int(self.d.measurementValid.value):
                break
            await self.wait()
        assert int(self.d.measurementValid.value), 'no accepted E2E sample'
        assert int(self.d.measurementDelayValid.value)
        assert int(self.d.measurementDelaySeq.value) == seq
        await self.pulse('snapshotCapture')
        values = [await self.read(a, w) for a, w in ((0x160, 12), (0x170, 12), (0x180, 12), (0x190, 12), (0x1a0, 16), (0x1b0, 8))]
        sync_ns = self.last_sync_tick*8-101
        resp_ns = self.wire_ticks[seq]*8+100
        assert values == [(sync_ns//1000000000 << 32) | (sync_ns % 1000000000),
                          capture_time(self.last_sync_tick*8*Q16+3260416),
                          capture_time(self.wire_ticks[seq]*8*Q16+3260416),
                          (resp_ns//1000000000 << 32) | (resp_ns % 1000000000),
                          49152, (1 << 64)-16384]
        assert int(self.d.measurementSequence.value) == self.last_sync_seq
        assert int(self.d.measurementTicks.value) == self.wire_ticks[seq]
        assert int(self.d.measurementDelay.value) == 6569984  # 100.25 ns.
        assert int(self.d.measurementForward.value) == 9830400  # 150 ns.
        assert int(self.d.measurementGeneration.value) == self.generation
        held = self.payload(), int(self.d.measurementDelay.value)
        await self.wait(7)
        assert held == (self.payload(), int(self.d.measurementDelay.value))
        await self.drain()

    async def no_delay(self):
        before = int(self.d.delayCount.value)
        # Covers the complete serialized E2E latency, not just RX admission.
        for _ in range(1500):
            await self.wait()
            assert not int(self.d.measurementValid.value), 'rejected response published a measurement'
        assert int(self.d.delayCount.value) == before

    async def next_request(self, sync_seq):
        await self.sync(sync_seq, self.last_sync_tick+HZ)
        await self.wait(20)
        if not int(self.d.txValid.value):
            # Keep 1 Hz Sync while awaiting the existing request jitter.
            await self.sync(sync_seq+1000, self.last_sync_tick+HZ)
        return await self.request()


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def ordinary_master(d):
    b = ExchangeBench(d)
    await b.setup()
    try:
        await b.qualify()
        for response_first in (False, True):
            seq = await b.request() if not response_first else await b.next_request(3)
            ticks = b.now+100
            if not response_first:
                await b.wire(seq, ticks)
            await b.packet(b.response(seq, ticks), ticks=ticks+100)
            if response_first:
                await b.no_delay()
                await b.wire(seq, ticks)
            await b.delay_result(seq)
        assert int(d.delayCount.value) == 2
        assert b.counts()[1] == 0
    finally:
        b.stop()


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def response_association(d):
    b = ExchangeBench(d)
    await b.setup()
    try:
        await b.qualify()
        accepted = 0
        for response_first in (False, True):
            # Required requester members/sequence (9.5.7), configured source
            # and domain policy, then local capture-generation provenance.
            for field in ('requester clock', 'requester port', 'sequence',
                          'source clock', 'source port', 'domain', 'generation'):
                seq = await b.request() if accepted == 0 else await b.next_request(10+accepted)
                ticks = b.now+100
                valid = b.response(seq, ticks)
                packet = bytearray(valid)
                mutations = {'requester clock': (58, b'\x80'), 'requester port': (67, b'\x02'),
                             'sequence': (44, ((seq+1) & 65535).to_bytes(2, 'big')),
                             'source clock': (34, b'\x80'), 'source port': (43, b'\x02'),
                             'domain': (18, b'\x01')}
                if field != 'generation':
                    offset, replacement = mutations[field]
                    packet[offset:offset+len(replacement)] = replacement
                if not response_first:
                    await b.wire(seq, ticks)
                await b.packet(packet, ticks=ticks+100, generation=int(field == 'generation'))
                if response_first:
                    await b.wire(seq, ticks)
                await b.no_delay()
                # A valid response for the SAME outstanding request must still
                # work. Do not reset or allocate a replacement to hide damage.
                await b.packet(valid, ticks=ticks+100)
                await b.delay_result(seq)
                accepted += 1
                assert int(d.delayCount.value) == accepted, field
                await b.packet(valid, ticks=ticks+200)
                await b.no_delay()
        assert accepted == 14
    finally:
        b.stop()


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def sync_overflow(d):
    b = Bench(d)
    await b.start()
    try:
        # Overflow first/second, in Sync/Follow_Up, plus a one-step exchange.
        for kind, follow_first, two_step in ((0, False, False), (0, False, True),
                                            (0, True, True), (8, False, True), (8, True, True)):
            await b.pulse('restart')
            count, rejected = b.counts()
            seq = 100
            packets = [(0, OVERFLOW if kind == 0 else 0), (8, OVERFLOW if kind == 8 else 0)]
            if follow_first:
                packets.reverse()
            if not two_step:
                packets = packets[:1]
            for message, correction in packets:
                await b.send(message, seq, 1000, correction, two_step=two_step, control=0)
                await b.no_result()
            # A later finite copy cannot resurrect the poisoned sequence.
            await b.send(0, seq, 1000, two_step=two_step, control=0)
            await b.no_result()
            if two_step:
                await b.send(8, seq, 1000, control=0)
                await b.no_result()
            assert b.counts()[0] == count
            assert b.counts()[1] > rejected
            # Unrelated next exchange, including -1, remains a finite correction.
            await b.send(0, seq+1, 2000, -1, control=0)
            await b.result(seq+1, 123*Q16+8)
            await b.drain()
    finally:
        b.stop()


@cocotb.test(timeout_time=1, timeout_unit='ms')
async def response_overflow(d):
    b = ExchangeBench(d)
    await b.setup()
    try:
        await b.qualify()
        for response_first in (False, True):
            seq = await b.request() if not response_first else await b.next_request(5)
            ticks = b.now+100
            if not response_first:
                await b.wire(seq, ticks)
            packet = bytearray(b.response(seq, ticks))
            packet[22:30] = OVERFLOW.to_bytes(8, 'big')
            # An overflow response must not update the minimum request interval.
            packet[47] = 10
            await b.packet(packet, ticks=ticks+100)
            await b.no_delay()
            # Invalidating the exchange must defeat a later finite response,
            # even if the original overflow would fail E2E range checks anyway.
            await b.packet(b.response(seq, ticks), ticks=ticks+100)
            if response_first:
                assert (int(d.ledgerStatus.value) >> 16) & 255, 'lost unresolved TX ownership'
                await b.wire(seq, ticks)
            await b.no_delay()
            fresh = await b.next_request(4 if not response_first else 6)
            fresh_ticks = b.now+100
            await b.wire(fresh, fresh_ticks)
            await b.packet(b.response(fresh, fresh_ticks), ticks=fresh_ticks+100)
            await b.delay_result(fresh)
        assert int(d.delayCount.value) == 2
    finally:
        b.stop()


def test_master_headers():
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptprxfrontendwrapper',
                      parameters={'PHY_TYPE_G': 'DIRECT', 'FIFO_DEPTH_G': 4},
                      extra_env=cocotb_filtered_env({'PHY_TYPE_G': 'DIRECT', 'FIFO_DEPTH_G': 4},
                                                   cocotb_test_filter('master_headers')))


@pytest.mark.parametrize('minor', [0, 1], ids=['2008', '2019'])
@pytest.mark.parametrize('two_step', [False, True], ids=['one-step', 'two-step'])
def test_ordinary_master(minor, two_step):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpportwrapper',
                      extra_env=cocotb_filtered_env({'MINOR': minor, 'TWO_STEP': int(two_step)},
                                                   cocotb_test_filter('ordinary_master')))


@pytest.mark.parametrize('scenario', ['sync_overflow', 'response_overflow', 'response_association'])
def test_exchange_rejection(scenario):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpportwrapper',
                      extra_env=cocotb_filtered_env({}, cocotb_test_filter(scenario)))
