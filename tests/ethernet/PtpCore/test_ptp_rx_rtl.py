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
# - Sweep: Direct normalized input, GMII, XGMII lanes 0/4, depth 1/4,
#   synchronous active-high and asynchronous active-low reset, signed latency.
# - Stimulus: Independent Python wire encoders, malformed/FCS-bad duplicates,
#   minimum-gap traffic, record pressure, reset/generation during reception.
# - Checks: Every cycle compares the RTL queue, record fields and abort priority
#   with the bounded reference model; physical tests also require whole-frame
#   acceptance and independently calculate the SOF timestamp and byte phase.
# - Timing: Drive before the rising edge and inspect transfer/abort before TPD;
#   compare registered state afterward. A watchdog bounds every cocotb test.

from fractions import Fraction
import os
import random
import zlib

import cocotb
from cocotb.triggers import Timer
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_rx_reference import RxFrontend, RxBeat, RxStamp
from tests.ethernet.PtpCore.ptp_rx_test_utils import frame, beats, unpack_time, pack_record
from tests.ethernet.PtpCore.ptp_wire_utils import xgmii_words, IDLE


def integer(signal):
    return int(signal.value)




class Bench:
    def __init__(self, dut):
        self.dut = dut
        self.depth = int(os.environ["FIFO_DEPTH_G"])
        self.mode = os.environ["PHY_TYPE_G"]
        self.polarity = int(os.environ.get("POLARITY", "1"))
        self.latency = int(os.environ.get("LATENCY_Q16", "0"))
        self.model = RxFrontend(depth=self.depth)
        self.half_period = 4 if self.mode == "GMII" else 3.2
        self.cycle = 0
        self.received = []
        self.aborts = 0
        self.increment = round((8 if self.mode == "GMII" else 6.4) * (1 << 32))
        # Exercise large seconds and nanosecond carry independently of PHC RTL.
        self.base = (((1 << 40) * 1_000_000_000 + 999999990) << 32)
        for name, value in dict(clk=0, rst=1-self.polarity, rxFlush=0, phyReady=1,
                                generation=0, timeValid=0, messageReady=1, directPhase=0).items():
            getattr(dut, name).value = value

    async def step(self, **inputs):
        d = self.dut
        d.clk.value = 0
        q32 = self.base + self.cycle * self.increment
        seconds, nsfrac = divmod(q32, 1_000_000_000 << 32)
        defaults = dict(xgmiiRxd=IDLE, xgmiiRxc=255, gmiiRxDv=0, gmiiRxEr=0,
                        directValid=0, phcSeconds=seconds, phcNanoseconds=nsfrac >> 32,
                        phcFraction=nsfrac & 0xffffffff, phcIncrement=self.increment, tickCount=self.cycle)
        defaults.update(inputs)
        for name, value in defaults.items():
            getattr(d, name).value = value
        await Timer(self.half_period, unit="ns")
        in_reset = integer(d.rst) == self.polarity
        if in_reset:
            self.model = RxFrontend(depth=self.depth)
            expected = None
            assert integer(d.rxAbort)
        else:
            # Read the old head before calling the reference edge. The valid
            # interface can be cancelled only by its explicit same-edge abort.
            assert integer(d.messageValid) == bool(self.model.entries), self.cycle
            if self.model.entries:
                assert integer(d.messageData) == pack_record(self.model.entries[0]), self.cycle
            beat = None
            if integer(d.normValid):
                keep = integer(d.normKeep)
                assert keep & (keep+1) == 0
                stamp = None
                if integer(d.normSof):
                    stamp = RxStamp(unpack_time(integer(d.normTime)), integer(d.normTicks),
                                    integer(d.normGeneration), bool(integer(d.normTimeValid)), integer(d.normPhase))
                beat = RxBeat(integer(d.normData).to_bytes(8, "little")[:keep.bit_count()],
                              bool(integer(d.normSof)), bool(integer(d.normLast)),
                              bool(integer(d.normError) or (stamp is not None and integer(d.normCaptureError))), stamp)
            expected = self.model.edge(beat, ready=bool(integer(d.messageReady)),
                                       restart=bool(integer(d.rxFlush) or not integer(d.phyReady)),
                                       generation=integer(d.generation))
            assert integer(d.rxAbort) == self.model.abort, self.cycle
            actual_transfer = integer(d.messageValid) and integer(d.messageReady) and not integer(d.rxAbort)
            assert bool(actual_transfer) == (expected is not None), self.cycle
            self.aborts += integer(d.rxAbort)
        if expected is not None:
            self.received.append(expected)
        d.clk.value = 1
        await Timer(self.half_period, unit="ns")
        assert integer(d.rxEpoch) == self.model.rx_epoch, self.cycle
        assert integer(d.acceptedCount) == self.model.counters["accepted"], self.cycle
        assert integer(d.overflowCount) == self.model.counters["overflow"], self.cycle
        self.cycle += 1

    async def reset(self):
        await self.step(rst=self.polarity)
        await self.step(rst=self.polarity)
        await self.step(rst=1-self.polarity)

    async def wait(self, count=4, **kwargs):
        for _ in range(count):
            await self.step(**kwargs)

    async def direct(self, raw, width=8, corrupt=False, flush_at=None, error_at=None):
        for i, beat in enumerate(beats(raw, width=width, corrupt=corrupt)):
            await self.step(directValid=1, directData=int.from_bytes(beat.data, "little"),
                            directKeep=(1 << len(beat.data))-1, directSof=int(beat.sof),
                            directLast=int(beat.eof), directError=int(i == error_at), rxFlush=int(i == flush_at))
        await self.step(rxFlush=0)

    async def physical(self, raw, lane=0, corrupt=False, mutation=None, flush_at=None, generation_at=None):
        start = self.cycle
        if self.mode == "XGMII":
            words = xgmii_words(raw, lane=lane, corrupt_crc=corrupt)
            if mutation == "preamble":
                data, ctrl = words[0]
                words[0] = (data ^ (1 << (8*(lane+1))), ctrl)
            elif mutation == "error":
                data, ctrl = words[3]
                words[3] = ((data & ~255) | 0xfe, ctrl | 1)
            elif mutation == "lane":
                # Move /S/ to illegal lane 1 while keeping the rest malformed.
                data, ctrl = words[0]
                words[0] = ((data & ~65535) | 0xfb07, (ctrl & ~1) | 3)
            for i, (data, ctrl) in enumerate(words):
                extra = {"generation": integer(self.dut.generation)+1} if i == generation_at else {}
                await self.step(xgmiiRxd=data, xgmiiRxc=ctrl, rxFlush=int(i == flush_at), **extra)
            point_cycles = Fraction(lane+8, 8)
        else:
            fcs = zlib.crc32(raw).to_bytes(4, "little")
            if corrupt:
                fcs = bytes((fcs[0] ^ 1,)) + fcs[1:]
            wire = bytearray(b"\x55" * 7 + b"\xd5" + raw + fcs)
            if mutation == "preamble":
                wire[3] ^= 1
            for i, byte in enumerate(wire):
                extra = {"generation": integer(self.dut.generation)+1} if i == generation_at else {}
                await self.step(gmiiRxDv=1, gmiiRxd=byte, gmiiRxEr=int(mutation == "error" and i == 20),
                                rxFlush=int(i == flush_at), **extra)
            await self.wait(12, rxFlush=0)
            point_cycles = Fraction(8)
        await self.wait(3, rxFlush=0)
        # Quantize at the capture boundary, after fractional lane advance and
        # signed calibration. The RTL uses the active increment, not 0.8 ns.
        point_q32 = self.base + (start + point_cycles) * self.increment - (self.latency << 16)
        expected_q16 = int(point_q32 // 65536)
        return Fraction(expected_q16, 65536), start + int(point_cycles), int(point_cycles % 1 * 8)


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def rx_contract(dut):
    bench = Bench(dut)
    await bench.reset()
    mode = bench.mode
    send = bench.direct if mode == "DIRECT" else bench.physical
    # Directed complete records and malformed copies, independent of the
    # normalized-beat scoreboard, ensure the adapter cannot silently drop all.
    for kind in (0, 8, 9, 11):
        for lane in ((0, 4) if mode == "XGMII" else (0,)):
            before = len(bench.received)
            kwargs = {"lane": lane} if mode != "DIRECT" else {}
            expected = await send(frame(kind=kind), **kwargs)
            await bench.wait()
            assert len(bench.received) == before+1
            got = bench.received[-1]
            assert got.key[0] == kind and got.correction == -17
            if expected is not None:
                assert (got.stamp.time, got.stamp.ticks, got.stamp.tick_phase) == expected
    before = len(bench.received)
    await send(frame(minor=0))
    await bench.wait()
    assert len(bench.received) == before+1 and bench.received[-1].minor_version == 0
    for offset, value in ((12, 0xf7), (15, 0x13), (15, 0x22), (14, 1), (17, 43)):
        raw = bytearray(frame())
        raw[offset] = value
        before = len(bench.received)
        await send(raw)
        await bench.wait()
        assert len(bench.received) == before
    for mutation in ("preamble", "error", "lane") if mode == "XGMII" else (("preamble", "error") if mode == "GMII" else ()):
        before = len(bench.received)
        await send(frame(), mutation=mutation)
        assert len(bench.received) == before
    before = len(bench.received)
    await send(frame(marker=1), corrupt=True)
    assert len(bench.received) == before
    expected = await send(frame(marker=2))
    await bench.wait()
    assert len(bench.received) == before+1 and int.from_bytes(bench.received[-1].body[:10], "big") == 2

    if mode != "DIRECT":
        # Force normalization at a second boundary with an independent PHC
        # input driver. XGMII +7.25 ns calibration borrows; GMII -3.5 ns carries.
        saved_base = bench.base
        for ns in (0, 999999999):
            point_cycle = bench.cycle + (1 if mode == "XGMII" else 8)
            bench.base = (((1 << 40)*1_000_000_000 + ns) << 32) - point_cycle*bench.increment
            expected = await send(frame(), **({"lane": 4} if mode == "XGMII" else {}))
            got = bench.received[-1]
            assert (got.stamp.time, got.stamp.ticks, got.stamp.tick_phase) == expected
        if mode == "XGMII":
            # At epoch zero, a calibrated negative time is rejected, never
            # wrapped into a plausible 48-bit seconds timestamp.
            bench.base = -bench.cycle*bench.increment
            before = len(bench.received)
            await send(frame(), lane=0)
            assert len(bench.received) == before
        bench.base = saved_base

    # Full-before-edge overflow invalidates the visible head; a retained MAC
    # packet is never an input to this interface. Then prove clean recovery.
    dut.messageReady.value = 0
    for i in range(bench.depth+1):
        await send(frame(marker=i+10))
    assert not bench.model.entries and integer(dut.overflowCount) == 1
    dut.messageReady.value = 1
    await send(frame(marker=20))
    await bench.wait()
    assert int.from_bytes(bench.received[-1].body[:10], "big") == 20
    before = len(bench.received)
    await send(frame(), flush_at=3 if mode != "GMII" else 20)
    await bench.wait()
    assert len(bench.received) == before
    if mode != "DIRECT":
        await send(frame(), generation_at=3 if mode == "XGMII" else 20)
        assert len(bench.received) == before
        # Non-nominal PHC increment must scale the XGMII lane offset.
        bench.increment += 12345
        expected = await send(frame(), **({"lane": 4} if mode == "XGMII" else {}))
        got = bench.received[-1]
        assert (got.stamp.time, got.stamp.ticks, got.stamp.tick_phase) == expected

    # Every final position, TLV boundaries and maximum supported length.
    for pad in range(8):
        before = len(bench.received)
        await send(frame(tlvs=bytes.fromhex("1234000056780002abcd")) + bytes(pad))
        await bench.wait()
        assert len(bench.received) == before+1
    for raw in (frame(tlvs=b"\x00\x01"), frame(tlvs=bytes.fromhex("00010008abcd")), frame()[:59], frame()+bytes(1455)):
        before = len(bench.received)
        await send(raw)
        await bench.wait()
        assert len(bench.received) == before
    await send(frame(kind=11, tlvs=b"\x12\x34" + (1432).to_bytes(2, "big") + bytes(1432)))
    await bench.wait()
    assert bench.received[-1].message_length == 1500

    if mode == "DIRECT":
        # Exact collision: full before the EOF edge even though ready is high.
        dut.messageReady.value = 0
        await bench.direct(frame(marker=700))
        for i, beat in enumerate(beats(frame(marker=701))):
            await bench.step(directValid=1, directData=int.from_bytes(beat.data, "little"),
                             directKeep=(1 << len(beat.data))-1, directSof=int(beat.sof),
                             directLast=int(beat.eof), directError=0, messageReady=int(beat.eof))
        assert not bench.model.entries and bench.model.abort
        # Empty termination after an exact multiple of the physical group.
        before = len(bench.received)
        for beat in beats(frame(marker=702)):
            await bench.step(directValid=1, directData=int.from_bytes(beat.data, "little"),
                             directKeep=255, directSof=int(beat.sof), directLast=0, directError=0)
        await bench.step(directValid=1, directKeep=0, directSof=0, directLast=1)
        await bench.wait()
        assert len(bench.received) == before+1
        # Saturating parser state cannot wrap an unterminated oversize frame
        # into a new short, CRC-valid one. Recovery requires a fresh SOF.
        await bench.step(directValid=1, directKeep=255, directSof=1, directLast=0, directData=0)
        for _ in range(2100):
            await bench.step(directValid=1, directKeep=255, directSof=0, directLast=0, directData=0)
        await bench.step(directValid=1, directKeep=0, directLast=1)
        await bench.wait()
        assert len(bench.received) == before+1
        # Generation/reset changes at the completed-frame boundary have
        # priority over both publication and a ready consumer.
        for action in ("generation", "rst"):
            before = len(bench.received)
            for beat in beats(frame()):
                extra = {}
                if beat.eof:
                    extra[action] = integer(dut.generation)+1 if action == "generation" else bench.polarity
                await bench.step(directValid=1, directData=int.from_bytes(beat.data, "little"), directKeep=255,
                                 directSof=int(beat.sof), directLast=int(beat.eof), **extra)
            await bench.step(rst=1-bench.polarity)
            await bench.wait()
            assert len(bench.received) == before

    if mode == "XGMII":
        # A continuous stream with exactly twelve non-data byte slots between
        # frames exercises lane 0/4 alternation without helper-inserted waits.
        symbols = []
        starts = []
        for index in range(32):
            starts.append(len(symbols))
            raw = frame(marker=800+index)
            symbols += [(0xfb, 1)] + [(0x55, 0)]*6 + [(0xd5, 0)]
            symbols += [(b, 0) for b in raw + zlib.crc32(raw).to_bytes(4, "little")]
            symbols += [(0xfd, 1)] + [(7, 1)]*11
        symbols += [(7, 1)] * (-len(symbols) % 8)
        before = len(bench.received)
        start_cycle = bench.cycle
        for pos in range(0, len(symbols), 8):
            word = symbols[pos:pos+8]
            await bench.step(xgmiiRxd=sum(b << (8*i) for i, (b, _) in enumerate(word)),
                             xgmiiRxc=sum(c << i for i, (_, c) in enumerate(word)))
        await bench.wait()
        assert len(bench.received) == before+32
        for index, got in enumerate(bench.received[before:]):
            point = Fraction(starts[index]+8, 8)
            assert got.stamp.ticks == start_cycle+int(point)
            assert got.stamp.tick_phase == int(point % 1 * 8)
            assert int.from_bytes(got.body[:10], "big") == 800+index

    if mode != "DIRECT":
        # Suppress capture on the start/preamble/SOF and final pipeline edges.
        for cut in ((0, 1, 2, 9, 10) if mode == "XGMII" else (0, 7, 8, 71, 72)):
            before = len(bench.received)
            if mode == "GMII" and cut == 72:
                # EOF is the first dv-low cycle, driven explicitly here.
                wire = b"\x55"*7 + b"\xd5" + frame()
                wire += zlib.crc32(frame()).to_bytes(4, "little")
                for byte in wire:
                    await bench.step(gmiiRxDv=1, gmiiRxd=byte)
                await bench.step(rxFlush=1)
                await bench.wait(rxFlush=0)
            else:
                await send(frame(), flush_at=cut)
            assert len(bench.received) == before
        # A link outage is a frontend abort while the PHC input keeps moving.
        before = len(bench.received)
        await bench.step(phyReady=0)
        await send(frame())
        assert len(bench.received) == before
        await bench.step(phyReady=1)
        await send(frame())
        assert len(bench.received) == before+1

    # Deterministic mixed records under pressure; the per-cycle oracle checks
    # all output identities and fields, not merely the final accepted count.
    rng = random.Random(1588)
    for index in range(80):
        dut.messageReady.value = int(rng.randrange(3) != 0)
        await send(frame(kind=(0, 8, 9, 11)[index % 4], marker=index), corrupt=index % 7 == 0,
                   **({"lane": 4*(index % 2)} if mode == "XGMII" else {}))
    dut.messageReady.value = 1
    await bench.wait(bench.depth+3)
    await bench.reset()
    await send(frame(marker=123))
    await bench.wait()
    assert int.from_bytes(bench.received[-1].body[:10], "big") == 123


@pytest.mark.parametrize("mode,depth,polarity,async_reset,latency", [
    ("DIRECT", 1, 1, False, 0),
    ("XGMII", 4, 1, False, 475136),  # +7.25 ns ingress subtraction
    ("GMII", 4, 0, True, -229376),  # -3.5 ns, active-low async reset
])
def test_ptp_rx_rtl(mode, depth, polarity, async_reset, latency):
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.ptprxfrontendwrapper",
        parameters={"PHY_TYPE_G": mode, "FIFO_DEPTH_G": depth,
                    "RST_POLARITY_G": f"'{polarity}'", "RST_ASYNC_G": async_reset,
                    "INGRESS_LATENCY_G": format(latency & ((1 << 64)-1), "064b")},
        extra_env={"PHY_TYPE_G": mode, "FIFO_DEPTH_G": depth, "POLARITY": polarity, "LATENCY_Q16": latency},
    )
