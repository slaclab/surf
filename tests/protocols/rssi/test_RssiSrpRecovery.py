##############################################################################
## This file is part of 'SLAC Firmware Standard Library'. It is subject to
## the license terms in the LICENSE.txt file found in the top-level directory
## of this distribution and at:
## https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of the 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the terms
## contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Purpose: Check the first SRP request after reconnect with replies outstanding,
#   queues filled by host BUSY alone, and an unterminated incoming frame.
# - DUT: Production RssiCoreWrapper (V2/FULL CRC), SrpV3AxiLite and async FIFOs;
#   inferred memories, window eight, 1024-byte segments, one local SRP route.
# - Stimulus: Python wire peer and AXI-Lite responder; clocks 156.25/125 MHz,
#   microsecond RSSI timer units. BUSY and withheld ACKs fill the TX window;
#   a separate case holds AXI to fill the request path with complete reads.
#   Explicit host RST disconnects. No global reset or output drain on reconnect.
# - Checks: Wire checksums/CRC, SRP boundaries, AXI addresses, exact first reply.
#   Old traffic is retained; a disconnected response may be incomplete. Rogue
#   scheduling and reset onset are outside this test boundary.
# - Ownership: Bench owns/cancels lifetime tasks; finite operations are awaited.

import os
import zlib

import pytest

import cocotb
from cocotb.queue import Queue
from cocotb.triggers import Event, FallingEdge, RisingEdge

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import (
    RssiParams, build_syn_header, build_ack_header, build_data_header,
    build_non_syn_header, checksum_is_valid, parse_header,
)
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint, SsiBeat, cycle, send_contiguous_frame, start_clock,
)
from tests.protocols.srp.srp_test_utils import SrpV3Request


def packetize(payload, *, eof=True):
    header = (0x8000000000000222).to_bytes(8, 'little')
    padded = payload + bytes((-len(payload)) % 8)
    tail = (int(eof) << 8 | ((len(payload)-1) % 8+1) << 16).to_bytes(4, 'little')
    body = header + padded + tail
    return body + zlib.crc32(body).to_bytes(4, 'big')


class Bench:
    def __init__(self, dut):
        self.dut, self.clk = dut, dut.ethClk
        self.source = FlatSsiEndpoint(dut, prefix='rx')
        self.sink = FlatSsiEndpoint(dut, prefix='tx')
        self.queue = Queue()
        self.frames, self.requests, self.replies, self.addresses = [], [], [], []
        self.auto_ack, self.busy, self.axil_enabled = False, False, True
        self.peer_seq, self.ack = 0, 0
        self.tasks = []

    async def start(self):
        self.source.set_idle()
        for name, value in dict(ethRst=1, axilRst=1, txTReady=1, arReady=1,
                                rValid=0, rData=0, rResp=0).items():
            getattr(self.dut, name).value = value
        start_clock(self.clk, period_ns=6.4)
        start_clock(self.dut.axilClk, period_ns=8)
        await cycle(self.clk, 16)
        self.dut.ethRst.value = 0
        self.dut.axilRst.value = 0
        await cycle(self.clk, 32)
        self.tasks = [cocotb.start_soon(coro()) for coro in
                      (self.drive, self.monitor, self.respond)]

    def enqueue(self, data):
        done = Event()
        self.queue.put_nowait((data, done))
        return done

    async def send(self, data):
        await self.enqueue(data).wait()

    async def drive(self):
        """Lifetime agent: serialized wire driver, owned and canceled by Bench."""
        while True:
            data, done = await self.queue.get()
            assert len(data) % 8 == 0
            beats = [SsiBeat(int.from_bytes(data[i:i+8], 'little'), 255,
                             int(i+8 == len(data)), sof=int(i == 0))
                     for i in range(0, len(data), 8)]
            await send_contiguous_frame(self.source, beats, clk=self.clk)
            done.set()

    async def monitor(self):
        """Lifetime agent: record every accepted beat until Bench.stop()."""
        frame = []
        while True:
            await RisingEdge(self.clk)
            for prefix, record in [('req', self.requests), ('rep', self.replies)]:
                if int(getattr(self.dut, prefix+'TValid').value) and int(getattr(self.dut, prefix+'TReady').value):
                    record.append(FlatSsiEndpoint(self.dut, prefix=prefix).snapshot())
            if int(self.dut.txTValid.value) and int(self.dut.txTReady.value):
                beat = self.sink.snapshot()
                assert beat.sof == int(not frame), 'Bad transport SOF'
                assert not beat.eofe, 'Transport EOFE'
                frame.append(beat)
                if beat.last:
                    raw = b''.join(b.data.to_bytes(8, 'little')[:b.keep.bit_count()] for b in frame)
                    header = parse_header(raw)
                    assert checksum_is_valid(raw[:header.header_length])
                    self.frames.append((header, raw[header.header_length:]))
                    if self.auto_ack and not header.syn and not header.rst and (len(raw) > 8 or header.nul):
                        if header.sequence == (self.ack+1) % 256:
                            self.ack = header.sequence
                        self.enqueue(build_ack_header(sequence=self.peer_seq,
                                                      acknowledge=self.ack, busy=self.busy))
                    frame = []

    async def respond(self):
        """Lifetime agent: single-outstanding AXI responder owned by Bench."""
        pending = None
        while True:
            await RisingEdge(self.dut.axilClk)
            if int(self.dut.rValid.value) and int(self.dut.rReady.value):
                pending = None
            if int(self.dut.arValid.value) and int(self.dut.arReady.value):
                assert pending is None
                pending = int(self.dut.arAddr.value)
                self.addresses.append(pending)
            await FallingEdge(self.dut.axilClk)
            self.dut.arReady.value = int(pending is None)
            self.dut.rValid.value = int(pending is not None and self.axil_enabled)
            self.dut.rData.value = 0 if pending is None else pending ^ 0xA5A50000

    async def until(self, predicate, label, cycles=2000):
        for _ in range(cycles):
            if predicate():
                return
            await cycle(self.clk)
        raise AssertionError(f'Timeout: {label}; status={int(self.dut.status.value):03x}, '
                             f'wire={len(self.frames)}, req={len(self.requests)}, '
                             f'rep={len(self.replies)}, AXI={len(self.addresses)}')

    async def connect(self, seq):
        self.auto_ack, self.busy = False, False
        start = len(self.frames)
        params = RssiParams(max_outs_seg=8, max_seg_size=1024, retrans_tout=1000,
                            cumul_ack_tout=2, null_seg_tout=10000, max_retrans=16,
                            max_cum_ack=2, timeout_unit=6)
        await self.send(build_syn_header(sequence=seq, acknowledge=0, params=params))
        await self.until(lambda: any(h.syn and h.ack for h, _ in self.frames[start:]), 'SYN+ACK')
        header = next(h for h, _ in self.frames[start:] if h.syn and h.ack)
        assert header.acknowledge == seq
        assert header.params.max_seg_size == 1024
        self.ack, self.peer_seq = header.sequence, (seq+1) % 256
        await self.send(build_ack_header(sequence=self.peer_seq, acknowledge=self.ack))
        await self.until(lambda: int(self.dut.connected.value), 'connection open')
        self.auto_ack = True

    async def disconnect(self, *, flags=0x50):
        self.auto_ack = False
        await self.send(build_non_syn_header(flags=flags, sequence=self.peer_seq,
                                             acknowledge=self.ack))
        await self.until(lambda: not int(self.dut.connected.value), 'connection closed')
        await cycle(self.clk, 96)

    async def request(self, tid, *, byte_count=4, partial=False):
        request = SrpV3Request(opcode=0, tid=tid, address=0x1000+tid*4, byte_count=byte_count)
        payload = b''.join(word.to_bytes(4, 'little') for word in request.response_header)
        if partial:
            payload = payload[:16]
        await self.send(build_data_header(sequence=self.peer_seq, acknowledge=self.ack,
                                         busy=self.busy) + packetize(payload, eof=not partial))
        self.peer_seq = (self.peer_seq+1) % 256
        return request

    def response_words(self, start, tid):
        for header, payload in self.frames[start:]:
            if not payload or header.syn:
                continue
            assert len(payload) >= 24 and len(payload) % 8 == 0
            assert payload[0] == 0x22, 'Expected Packetizer V2 FULL'
            if not (payload[7] & 0x80 and payload[-7] & 1):
                continue  # Incomplete old frame stays recorded.
            assert zlib.crc32(payload[:-4]) == int.from_bytes(payload[-4:], 'big'), 'Reply CRC'
            count = payload[-6]
            data = payload[8:-16] + payload[-16:-8][:count]
            words = [int.from_bytes(data[i:i+4], 'little') for i in range(0, len(data), 4)]
            if len(words) > 1 and words[1] == tid:
                return words
        return None

    async def probe(self, tid, *, cycles=2000):
        start = len(self.frames)
        request = await self.request(tid)
        await self.until(lambda: self.response_words(start, tid) is not None, f'first SRP reply tid={tid}', cycles=cycles)
        assert self.response_words(start, tid) == request.response_header + [request.address ^ 0xA5A50000, 0]
        assert request.address in self.addresses
        self.dut._log.info('PROBE tid=%d: AXI read and exact wire reply OK', tid)

    def stop(self):
        for task in self.tasks:
            task.cancel()


@cocotb.test(timeout_time=200, timeout_unit='us')
async def outstanding_replies_reconnect(dut):
    tb = Bench(dut)
    await tb.start()
    try:
        await tb.connect(0x20)
        await tb.probe(10)
        tb.auto_ack, tb.busy = False, True
        start = len(tb.frames)
        for tid in range(100, 116):
            await tb.request(tid)
            seq = (tb.peer_seq-1) % 256
            await tb.until(lambda: any(h.ack and h.acknowledge == seq for h, _ in tb.frames[start:]), 'request ACK')
        await tb.until(lambda: len([p for h, p in tb.frames[start:] if p and not h.syn]) >= 8, 'TX window fills')
        dut._log.info('PRIMED: BUSY peer, eight unacknowledged replies, more requests outstanding')
        await tb.disconnect()
        await tb.connect(0x60)
        await tb.probe(1)
        await tb.probe(2)
    finally:
        tb.stop()


@cocotb.test(timeout_time=100, timeout_unit='us')
async def partial_request_reconnect(dut):
    tb = Bench(dut)
    await tb.start()
    try:
        await tb.connect(0x20)
        await tb.probe(10)
        start = len(tb.requests)
        frames = len(tb.frames)
        await tb.request(200, partial=True)
        seq = (tb.peer_seq-1) % 256
        await tb.until(lambda: any(h.ack and h.acknowledge == seq for h, _ in tb.frames[frames:]), 'partial packet ACK')
        await tb.until(lambda: len(tb.requests) == start+2, 'both partial beats reach SRP')
        assert tb.requests[start].sof
        assert not any(b.last or b.eofe for b in tb.requests[start:])
        await tb.disconnect()
        await cycle(tb.clk, 1024)
        terminated = any(b.last and b.eofe for b in tb.requests[start:])
        dut._log.info('PARTIAL: link-down EOFE delivered=%s, accepted beats=%s',
                      terminated, tb.requests[start:])
        await tb.connect(0xA0)
        failures = []
        for tid in (3, 4):
            try:
                await tb.probe(tid)
            except AssertionError as error:
                dut._log.error('PROBE tid=%d failed: %s; AXI addresses=%s', tid, error, tb.addresses)
                failures.append(str(error))
        assert terminated and not failures, f'EOFE delivered={terminated}; {failures}'
    finally:
        tb.stop()


@cocotb.test(timeout_time=200, timeout_unit='us')
async def blocked_axi_burst_reconnect(dut):
    tb = Bench(dut)
    await tb.start()
    try:
        await tb.connect(0x20)
        await tb.probe(10)
        tb.axil_enabled = False
        tb.busy = True
        start = len(tb.frames)
        frame_cursor = start
        last_ack = (tb.peer_seq-1) % 256
        stalled = False
        for tid in range(1000, 1300):
            for _ in range(500):
                for header, _ in tb.frames[frame_cursor:]:
                    if header.ack and 0 < (header.acknowledge-last_ack) % 256 < 128:
                        last_ack = header.acknowledge
                frame_cursor = len(tb.frames)
                if (tb.peer_seq-last_ack-1) % 256 < 8:
                    break
                await cycle(tb.clk)
            else:
                stalled = True
                break
            await tb.request(tid)
        assert stalled, 'Did not fill request path with blocked AXI response'
        assert int(dut.reqTValid.value) and not int(dut.reqTReady.value), 'No SRP input backpressure'
        dut._log.info('BLOCKED: %d complete read requests sent; SRP input paused; '
                      'last accepted request beat last=%d', tid-1000, tb.requests[-1].last)
        await tb.disconnect()
        await tb.connect(0x60)
        tb.axil_enabled = True
        failures = []
        for tid in (20, 21):
            try:
                await tb.probe(tid, cycles=10000)
            except AssertionError as error:
                dut._log.error('BLOCKED PROBE tid=%d: %s; AXI reached=%s',
                               tid, error, 0x1000+tid*4 in tb.addresses)
                failures.append(str(error))
        assert not failures, failures
    finally:
        tb.stop()


@cocotb.test(timeout_time=400, timeout_unit='us')
async def busy_host_burst_reconnect(dut):
    tb = Bench(dut)
    await tb.start()
    try:
        await tb.connect(0x20)
        await tb.probe(10)
        tb.auto_ack, tb.busy = False, True
        start = len(tb.frames)
        cursor = start
        last_ack = (tb.peer_seq-1) % 256
        stalled = False
        for tid in range(1000, 1900):
            for _ in range(500):
                for header, _ in tb.frames[cursor:]:
                    if header.ack and 0 < (header.acknowledge-last_ack) % 256 < 128:
                        last_ack = header.acknowledge
                cursor = len(tb.frames)
                if (tb.peer_seq-last_ack-1) % 256 < 8:
                    break
                await cycle(tb.clk)
            else:
                stalled = True
                break
            await tb.request(tid)
            if tid % 100 == 0:
                dut._log.info('HOST BUSY: sent=%d AXI=%d req=%d rep=%d status=%03x',
                              tid-999, len(tb.addresses), len(tb.requests), len(tb.replies),
                              int(dut.status.value))
        assert stalled, 'Host BUSY did not fill request/response path'
        assert tb.axil_enabled, 'AXI response must remain enabled throughout this scenario'
        assert int(dut.reqTValid.value) and not int(dut.reqTReady.value)
        await cycle(tb.clk, 500)
        # RSSI need not repeat an unchanged ACK. Check the last actual header
        # and local BUSY status rather than requiring periodic status packets.
        headers = [h for h, _ in tb.frames[start:] if h.ack]
        assert headers and headers[-1].acknowledge == last_ack, 'ACK advanced after apparent stall'
        dut._log.info('HOST BUSY STALLED: sent=%d AXI=%d ACK=%02x lastWireBUSY=%s localBUSY=%d status=%03x',
                      tid-1000, len(tb.addresses), last_ack, headers[-1].busy,
                      (int(dut.status.value) >> 7) & 1, int(dut.status.value))
        # Host-side reset is explicit: this tests recovery, not Rogue's retry timer.
        await tb.disconnect(flags=0x11)
        await tb.connect(0x60)
        # Send the first and second fresh requests in order. Once the second
        # reply arrives, an absent first reply cannot be blamed on old backlog.
        frames = len(tb.frames)
        probes = [await tb.request(tid) for tid in (30, 31)]
        await tb.until(lambda: tb.response_words(frames, 31) is not None,
                       'second post-reconnect reply', cycles=20000)
        for request in probes:
            words = tb.response_words(frames, request.tid)
            dut._log.info('HOST BUSY PROBE tid=%d: reply=%s AXI=%s', request.tid,
                          words is not None, request.address in tb.addresses)
        for request in probes:
            assert tb.response_words(frames, request.tid) == request.response_header + [request.address ^ 0xA5A50000, 0]
            assert request.address in tb.addresses
    finally:
        tb.stop()


@pytest.mark.parametrize('case', [
    'outstanding_replies_reconnect',
    pytest.param('busy_host_burst_reconnect', marks=pytest.mark.skipif(
        os.getenv('RUN_RSSI_EXTENDED_TESTS') != '1',
        reason='Extended FIFO-filling burst/reconnect test: host receive stall, no AXI stall; '
               'see docs/plans/rssi-rx-keepalive/README.md.')),
    'partial_request_reconnect',
    pytest.param('blocked_axi_burst_reconnect', marks=pytest.mark.skipif(
        os.getenv('RUN_RSSI_EXTENDED_TESTS') != '1',
        reason='Extended FIFO-filling burst/reconnect test; see docs/plans/rssi-rx-keepalive/README.md.')),
])
def test_RssiSrpRecovery(case):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.rssisrprecoverywrapper',
                       extra_env={'COCOTB_TESTCASE': case})
