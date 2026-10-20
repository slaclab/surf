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
# - Sweep: PtpMacPortEthMac with PtpMacPortRxAdapter and PtpMacPortTxAdapter,
#   GMII and XGMII, nonzero ingress/egress calibration, with the passive
#   PtpRxTimestampTap/PtpTxTimestampTap observing the same pins as oracles.
# - Stimulus: Injected Sync, Follow_Up, Delay_Resp and Announce frames (with
#   TLVs, minimum and both maximum-length boundaries, XGMII lane-4 starts),
#   non-PTP, bad-CRC and runt frames; PHC RATE/SET/PHASE/abort commits placed
#   at random points in about half the frames' wire windows;
#   Delay_Req frames with distinct identities through the TX adapter, record
#   backpressure that exhausts the adapter table, PHY loss at admission, and
#   minimum-gap bursts of minimum- and maximum-size frames at the configured
#   RX table depth.
# - Checks: With a steady PHC the adapter RX and TX record streams equal the
#   tap streams bit for bit, including capture increment and error. Under
#   commits every adapter record equals a tap record, except a usable
#   adapter-only record whose preamble saw a step (the tap abandons those);
#   a tap-only RX record needs a generation change after its capture, and a differing TX
#   record must be an error with the same identity across a commit. Records
#   are never lost under backpressure; a frame that never reaches the wire
#   yields no record and frees its slot. Line-rate bursts lose no frame.
# - Timing: Observations carry the PHC model's cycle, sampled 2 ns after the
#   edge; the tuple is driven 1 ns after each edge.

from __future__ import annotations

import os
import random

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES
from tests.ethernet.PtpCore.ptp_mac_port_test_utils import PhcModel, fcs
from tests.ethernet.PtpCore.ptp_rx_test_utils import frame as ptp_message
from tests.ethernet.PtpCore.ptp_wire_utils import xgmii_words

PHY = os.environ.get("PHY_TYPE_G", "GMII")
WRAPPERS = ["ethernet/PtpCore/wrappers/PtpMacPortAdapterWrapper.vhd"]
TABLE_DEPTH = int(os.environ.get("TX_TABLE_DEPTH_G", 4))
RX_TABLE_DEPTH = int(os.environ.get("RX_TABLE_DEPTH_G", 0)) or {"GMII": 5, "XGMII": 21}[PHY]

# toSlv(PtpRxMessageType) field widths from the MSB, then increment and error.
FIELDS = [("timestamp", 96), ("ticks", 64), ("tickPhase", 3), ("generation", 32), ("timeValid", 1),
          ("rxEpoch", 32), ("destination", 48), ("identity", 80), ("sequence", 16), ("domain", 8),
          ("messageType", 4), ("minor", 4), ("transportSpecific", 4), ("length", 16), ("flags", 16),
          ("correction", 64), ("control", 8), ("logInterval", 8), ("body", 240),
          ("increment", 64), ("error", 1)]


def decode(value: int) -> dict:
    out = {}
    shift = sum(width for _, width in FIELDS)
    for name, width in FIELDS:
        shift -= width
        out[name] = (value >> shift) & ((1 << width) - 1)
    return out


def differences(port: int, tap: int, ignore=()) -> dict:
    p, t = decode(port), decode(tap)
    return {name: (p[name], t[name]) for name in p if p[name] != t[name] and name not in ignore}


def same_streams(port, tap, ignore=()):
    assert len(port) == len(tap), ([decode(v)["sequence"] for _, v in port], [decode(v)["sequence"] for _, v in tap],
                                   [differences(p, t, ignore) for (_, p), (_, t) in zip(port, tap)][:2])
    for (_, p), (_, t) in zip(port, tap):
        assert not differences(p, t, ignore), (decode(t)["sequence"], differences(p, t, ignore))


def delay_req(sequence: int, domain: int, identity: int) -> bytes:
    """The engine's fixed 58-byte untagged Delay_Req."""
    ptp = bytearray(44)
    ptp[0] = 0x01
    ptp[1] = 0x12
    ptp[2:4] = (44).to_bytes(2, "big")
    ptp[4] = domain
    ptp[20:30] = identity.to_bytes(10, "big")
    ptp[30:32] = sequence.to_bytes(2, "big")
    ptp[32] = 0x01
    ptp[33] = 0x7F
    return bytes.fromhex("011b19000000" "554433221100" "88f7") + bytes(ptp)


class Bench:
    def __init__(self, d):
        self.d = d
        self.period = 8.0 if PHY == "GMII" else 6.4
        self.phc = PhcModel(d, increment_ns=self.period)
        self.rx = {"port": [], "tap": []}
        self.tx = {"port": [], "tap": []}

    async def start(self):
        d = self.d
        cocotb.start_soon(Clock(d.clk, self.period, unit="ns").start())
        d.rst.setimmediatevalue(1)
        d.phyReady.setimmediatevalue(1)
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(d, "axil"), d.clk, d.rst)
        for name in ("rxFlush", "sAxisTValid", "sAxisTData", "sAxisTKeep", "sAxisTLast", "sAxisSof",
                     "injGmiiRxd", "injGmiiRxDv", "injGmiiRxEr"):
            getattr(d, name).setimmediatevalue(0)
        d.rxReady.setimmediatevalue(1)
        d.txReady.setimmediatevalue(1)
        d.rxInject.setimmediatevalue(1)
        d.injXgmiiRxd.setimmediatevalue(0x0707070707070707)
        d.injXgmiiRxc.setimmediatevalue(0xFF)
        self.phc.drive()
        cocotb.start_soon(self._phc_driver())
        for _ in range(6):
            await RisingEdge(d.clk)
        d.rst.value = 0
        cocotb.start_soon(self._monitor())
        for _ in range(16):
            await self.edge()
            if int(d.admissionOpen.value):
                return
        raise AssertionError("admission did not open")

    async def _phc_driver(self):
        while True:
            await RisingEdge(self.d.clk)
            await Timer(1, unit="ns")
            self.phc.advance()
            self.phc.drive()

    async def _monitor(self):
        d = self.d
        while True:
            await RisingEdge(d.clk)
            await Timer(2, unit="ns")
            cycle = self.phc.cycle
            for path, valid, data, ready, store in (
                    ("port", d.portRxValid, d.portRxData, d.rxReady, self.rx),
                    ("tap", d.tapRxValid, d.tapRxData, d.rxReady, self.rx),
                    ("port", d.portTxValid, d.portTxData, d.txReady, self.tx),
                    ("tap", d.tapTxValid, d.tapTxData, d.txReady, self.tx)):
                if int(valid.value) and int(ready.value):
                    store[path].append((cycle, int(data.value)))
            # Abort also marks generation changes; overflow would lose records.
            assert not int(d.portRxOverflow.value), "adapter RX queue overflowed"

    async def edge(self, count=1):
        for _ in range(count):
            await RisingEdge(self.d.clk)
            await Timer(1, unit="ns")

    async def inject(self, raw: bytes, *, corrupt=False, lane=0):
        d = self.d
        if PHY == "GMII":
            check = fcs(raw)
            if corrupt:
                check = bytes((check[0] ^ 1,)) + check[1:]
            for octet in [0x55]*7 + [0xD5] + list(raw + check):
                d.injGmiiRxDv.value = 1
                d.injGmiiRxd.value = octet
                await self.edge()
            d.injGmiiRxDv.value = 0
            d.injGmiiRxd.value = 0
            await self.edge(12)
        else:
            for data, ctrl in xgmii_words(raw, lane=lane, corrupt_crc=corrupt):
                d.injXgmiiRxd.value = data
                d.injXgmiiRxc.value = ctrl
                await self.edge()
            d.injXgmiiRxd.value = 0x0707070707070707
            d.injXgmiiRxc.value = 0xFF
            await self.edge(2)

    async def inject_back_to_back(self, frames):
        """Frames at the minimum 12-byte IFG; XGMII starts on lane 0 or 4."""
        d = self.d
        if PHY == "GMII":
            for raw in frames:
                await self.inject(raw)
            return
        stream = []
        for raw in frames:
            stream += [(7, 1)] * (-len(stream) % 4)
            stream += [(0xfb, 1)] + [(0x55, 0)] * 6 + [(0xd5, 0)]
            stream += [(byte, 0) for byte in raw + fcs(raw)] + [(0xfd, 1)] + [(7, 1)] * 11
        stream += [(7, 1)] * (-len(stream) % 8)
        for n in range(0, len(stream), 8):
            d.injXgmiiRxd.value = sum(byte << (8 * i) for i, (byte, _) in enumerate(stream[n:n+8]))
            d.injXgmiiRxc.value = sum(ctrl << i for i, (_, ctrl) in enumerate(stream[n:n+8]))
            await self.edge()
        d.injXgmiiRxd.value = 0x0707070707070707
        d.injXgmiiRxc.value = 0xFF

    async def read(self, offset):
        result = await with_timeout(self.axil.read(offset, 4), 50, "us")
        assert result.resp == AxiResp.OKAY, (hex(offset), result.resp)
        return int.from_bytes(result.data, "little")

    async def write(self, offset, value):
        result = await with_timeout(self.axil.write(offset, value.to_bytes(4, "little")), 50, "us")
        return result.resp

    async def send(self, raw: bytes, timeout=20000):
        d = self.d
        offsets = list(range(0, len(raw), 16))
        for index, offset in enumerate(offsets):
            chunk = raw[offset:offset+16]
            d.sAxisTValid.value = 1
            d.sAxisTData.value = int.from_bytes(chunk.ljust(16, b"\x00"), "little")
            d.sAxisTKeep.value = (1 << len(chunk)) - 1
            d.sAxisTLast.value = int(index == len(offsets)-1)
            d.sAxisSof.value = int(index == 0)
            for _ in range(timeout):
                await self.edge()
                if int(d.sAxisTReady.value):
                    break
            else:
                raise AssertionError("Delay_Req beat stalled")
        d.sAxisTValid.value = 0
        d.sAxisTLast.value = 0
        d.sAxisSof.value = 0

    async def wait_for(self, predicate, cycles=40000, what="condition"):
        for _ in range(cycles):
            if predicate():
                return
            await self.edge()
        raise AssertionError(f"timed out waiting for {what}")

    def steps(self):
        return [cycle for cycle, kind in self.phc.events if kind in ("SET", "PHASE")]

    def commits(self):
        return [cycle for cycle, kind in self.phc.events if kind in ("SET", "PHASE", "ABORT")]


PREAMBLE_CYCLES = 8 if PHY == "GMII" else 2


def maybe_commit(b, rng, window, probability=0.5):
    # Some frames get one commit somewhere in their wire window.
    if rng.random() < probability:
        b.phc.schedule[b.phc.cycle + rng.randrange(2, window)] = rng.choice(("RATE", "SET", "PHASE", "ABORT"))


async def bench_for(d) -> Bench:
    b = Bench(d)
    await b.start()
    return b


def rx_frames():
    big = ptp_message(0, 40)
    frames = [
        (ptp_message(0, 1), {}),
        (ptp_message(8, 2), {}),
        (ptp_message(9, 3), {}),
        (ptp_message(11, 4), {}),
        (ptp_message(11, 5, tlvs=bytes.fromhex("000300026162")), {}),
        (ptp_message(0, 6, two_step=False), {"lane": 4}),
        (big.ljust(1514, b"\x00"), {}),          # 1518 bytes with FCS: largest accepted.
        (ptp_message(0, 41).ljust(1515, b"\x00"), {}),   # One byte over MAX_FRAME_G.
        (ptp_message(9, 7)[:12] + b"\x08\x00" + ptp_message(9, 7)[14:], {}),  # Not PTP.
        (ptp_message(8, 8), {"corrupt": True}),
        (ptp_message(0, 9)[:50], {}),             # Runt.
        (ptp_message(9, 10), {"lane": 4}),
    ]
    return frames


@cocotb.test(timeout_time=4, timeout_unit="ms")
async def rx_records_match_tap(d):
    b = await bench_for(d)
    for raw, options in rx_frames():
        lane = options.get("lane", 0) if PHY == "XGMII" else 0
        await b.inject(raw, corrupt=options.get("corrupt", False), lane=lane)
    await b.edge(400)
    counters = int(d.counters.value)
    assert sum(counters >> 32*i & 0xFFFFFFFF for i in range(3)) == len(rx_frames()), "port lost a frame"
    assert len(b.rx["tap"]) == 8, [decode(v)["sequence"] for _, v in b.rx["tap"]]
    same_streams(b.rx["port"], b.rx["tap"])
    port, tap = int(d.portRxCounters.value), int(d.tapRxCounters.value)
    assert port & 0xFFFFFFFF == tap & 0xFFFFFFFF == 8
    # The MAC drops what never reaches the shared frontend (bad CRC, runt).
    assert (port >> 32) & 0xFFFFFFFF < (tap >> 32) & 0xFFFFFFFF
    assert not int(d.tapRxAbort.value)


@cocotb.test(timeout_time=8, timeout_unit="ms")
async def rx_records_under_phc_commits(d):
    b = await bench_for(d)
    rng = random.Random(1588)
    window = 100 if PHY == "GMII" else 20
    for i in range(60):
        kind = rng.choice((0, 8, 9, 11))
        maybe_commit(b, rng, window, probability=0.35)
        await b.inject(ptp_message(kind, 100+i), lane=4*(i % 2) if PHY == "XGMII" else 0)
        await b.edge(30)
    await b.edge(400)
    assert len(b.steps()) >= 4, "too few steps to exercise invalidation"
    port = {decode(v)["sequence"]: v for _, v in b.rx["port"]}
    tap = {decode(v)["sequence"]: (c, v) for c, v in b.rx["tap"]}
    d._log.info("RX records: port %d, tap %d, steps %d", len(port), len(tap), len(b.steps()))
    assert len(port) >= 10, "commit density left too few records to compare"
    for sequence, value in port.items():
        if sequence not in tap:
            # The tap abandons a frame whose preamble saw a generation change;
            # the port captures at the pin in the new generation and keeps it.
            capture = decode(value)
            assert not capture["error"], f"adapter-only unusable record {sequence}"
            assert any(capture["ticks"]-PREAMBLE_CYCLES <= step <= capture["ticks"] for step in b.steps()), \
                f"adapter-only record {sequence} without a preamble step"
            continue
        assert tap[sequence][1] == value, (sequence, differences(value, tap[sequence][1]))
    for sequence, (cycle, value) in tap.items():
        if sequence not in port:
            # Store-and-forward delivers after the tap; a step in between makes
            # the port's capture stale for the shared frontend.
            capture = decode(value)["ticks"]
            assert any(capture <= step <= cycle+2000 for step in b.steps()), f"lost record {sequence}"


@cocotb.test(timeout_time=4, timeout_unit="ms")
async def tx_records_match_tap(d):
    b = await bench_for(d)
    rng = random.Random(9)
    for i in range(10):
        await b.send(delay_req(1000+i, rng.randrange(128), rng.getrandbits(80)))
        await b.edge(150)
    await b.wait_for(lambda: len(b.tx["port"]) == 10 and len(b.tx["tap"]) == 10, what="10 TX records")
    assert [v for _, v in b.tx["port"]] == [v for _, v in b.tx["tap"]]
    record = decode(b.tx["port"][0][1])
    assert record["messageType"] == 1 and record["sequence"] == 1000 and record["error"] == 0
    assert not int(d.tapTxAbort.value)


@cocotb.test(timeout_time=8, timeout_unit="ms")
async def tx_records_under_phc_commits(d):
    b = await bench_for(d)
    rng = random.Random(77)
    window = 120 if PHY == "GMII" else 40
    for i in range(30):
        maybe_commit(b, rng, window)
        await b.send(delay_req(2000+i, 4, 0x0123456789ABCDEF0011))
        await b.edge(60)
    await b.wait_for(lambda: len(b.tx["port"]) == 30 and len(b.tx["tap"]) == 30, what="30 TX records")
    differing = 0
    for (cycle, port), (_, tap) in zip(b.tx["port"], b.tx["tap"]):
        if port == tap:
            continue
        differing += 1
        p, t = decode(port), decode(tap)
        assert p["error"] == 1, f"differing usable capture {p['sequence']}"
        assert (p["sequence"], p["domain"], p["identity"]) == (t["sequence"], t["domain"], t["identity"])
        start = t["ticks"]
        assert any(start <= event <= cycle for event in b.commits()), f"no commit explains {p['sequence']}"
    assert 0 < differing < 30, differing
    d._log.info("TX records differing only by an invalid capture: %d", differing)


@cocotb.test(timeout_time=4, timeout_unit="ms")
async def tx_backpressure_holds_slots(d):
    b = await bench_for(d)
    d.txReady.value = 0
    # One completed record waits in the output register, freeing its slot;
    # the table then fills and the next SOF is not accepted.
    held = TABLE_DEPTH+1
    for i in range(held):
        await b.send(delay_req(3000+i, 0, 7))
    d.sAxisTValid.value = 1
    d.sAxisSof.value = 1
    raw = delay_req(3000+held, 0, 7)
    d.sAxisTData.value = int.from_bytes(raw[:16], "little")
    d.sAxisTKeep.value = 0xFFFF
    for _ in range(600):
        await b.edge()
        assert not int(d.sAxisTReady.value), "adapter admitted a request without a free slot"
    d.sAxisTValid.value = 0
    d.sAxisSof.value = 0
    d.txReady.value = 1
    await b.send(raw)
    await b.wait_for(lambda: len(b.tx["port"]) == held+1, what="all held records")
    assert [decode(v)["sequence"] for _, v in b.tx["port"]] == list(range(3000, 3001+held))


@cocotb.test(timeout_time=4, timeout_unit="ms")
async def tx_unsent_frame_frees_slot(d):
    b = await bench_for(d)
    d.phyReady.value = 0
    for i in range(TABLE_DEPTH+1):
        await b.send(delay_req(4000+i, 0, 9))
    await b.edge(400)
    assert not b.tx["port"] and not b.tx["tap"], "a frame that never left produced a record"
    d.phyReady.value = 1
    await b.edge(100)
    await b.send(delay_req(4100, 0, 9))
    await b.wait_for(lambda: len(b.tx["port"]) == 1 and len(b.tx["tap"]) == 1, what="post-recovery record")
    # The tap's observer advanced its flush epoch on PHY loss; the adapter
    # publishes zero (section 11.2) and the ledger does not read it.
    same_streams(b.tx["port"], b.tx["tap"], ignore=("rxEpoch",))


@cocotb.test(timeout_time=8, timeout_unit="ms")
async def rx_line_rate_bursts(d):
    """Back-to-back bursts at the minimum gap: no frame may be dropped."""
    b = await bench_for(d)
    sent = 0
    other = ptp_message(9, 0)[:12] + b"\x08\x00" + ptp_message(9, 0)[14:]
    for i in range(12):
        await b.inject(ptp_message((0, 8, 9, 11)[i % 4], 500+i), lane=4*(i % 2) if PHY == "XGMII" else 0)
        await b.inject(other)
        sent += 1
    for i in range(6):
        await b.inject(ptp_message(0, 600+i).ljust(1514, b"\x00"))
        sent += 1
    await b.wait_for(lambda: len(b.rx["port"]) == sent, cycles=20000, what=f"{sent} burst records")
    counters = int(d.counters.value)
    dropped, lost = (counters >> 32) & 0xFFFFFFFF, (counters >> 64) & 0xFFFFFFFF
    d._log.info("RX table depth %d: dropped %d lost %d", RX_TABLE_DEPTH, dropped, lost)
    assert dropped == 0 and lost == 0, (dropped, lost)
    same_streams(b.rx["port"], b.rx["tap"])


@cocotb.test(timeout_time=8, timeout_unit="ms")
async def rx_max_then_min_burst(d):
    """Minimum frames at the minimum IFG behind a maximum one: none are lost.

    The adapter drains the store-and-forward port at the frontend's 8 bytes
    per cycle, held only by the frontend's frameReady, so the frames arriving
    while a maximum frame drains set the PHY's RX table depth. Entries also
    release while new frames start, which moves the offered token.
    """
    b = await bench_for(d)
    # Minimum-length frames (60 bytes before FCS) after a maximum one, then a
    # second maximum frame and more minimum frames behind it.
    frames = [ptp_message(0, 700).ljust(1514, b"\x00")]
    frames += [ptp_message((0, 8)[i % 2], 701+i) for i in range(30)]
    frames += [ptp_message(0, 800).ljust(1514, b"\x00")]
    frames += [ptp_message((0, 8)[i % 2], 801+i) for i in range(30)]
    sent = len(frames)
    await b.inject_back_to_back(frames)
    await b.edge(3000)
    counters = int(d.counters.value)
    delivered, dropped, lost = (counters >> 32*i & 0xFFFFFFFF for i in range(3))
    d._log.info("RX table depth %d: delivered %d dropped %d lost %d", RX_TABLE_DEPTH, delivered, dropped, lost)
    # A token protocol fault discards a frame without counting it.
    assert delivered + dropped + lost == sent, (delivered, dropped, lost)
    assert len(b.rx["port"]) == delivered
    assert dropped == 0 and lost == 0, (dropped, lost)
    same_streams(b.rx["port"], b.rx["tap"])


@cocotb.test(timeout_time=8, timeout_unit="ms")
async def rx_start_meets_release(d):
    """A wire start sampled on the edge whose release lowers the offered token.

    A maximum frame takes entry 0; a short frame starts while it drains, at
    gaps swept across the cycle its last beat is accepted. The leaf echoes the
    token it sampled, which the coincident release has already superseded.
    """
    b = await bench_for(d)
    rx = d.u_port.u_port.u_rx
    coincident = 0

    async def watch():
        # A start becomes visible in the cycle the release's counter does.
        nonlocal coincident
        while True:
            await RisingEdge(d.clk)
            await Timer(2, unit="ns")
            coincident += int(rx.ramwrite.value) & int(rx.incdelivered.value)
    cocotb.start_soon(watch())
    # The long frame is still draining when the short one starts; gaps sweep
    # the measured alignment (XGMII 207 cycles, GMII 40) by six either way.
    length, gaps = (1514, range(201, 214)) if PHY == "XGMII" else (300, range(34, 47))
    for gap in gaps:
        await b.inject_back_to_back([ptp_message(0, 1000+gap).ljust(length, b"\x00")])
        await b.edge(gap)
        await b.inject_back_to_back([ptp_message(8, 2000+gap)])
        await b.edge(300)
    counters = int(d.counters.value)
    delivered, dropped, lost = (counters >> 32*i & 0xFFFFFFFF for i in range(3))
    # A faulted start is discarded uncounted and allocates no entry.
    assert (delivered, dropped, lost) == (2*len(gaps), 0, 0), (delivered, dropped, lost)
    assert coincident, "no start coincided with a release"
    same_streams(b.rx["port"], b.rx["tap"])


@cocotb.test(timeout_time=8, timeout_unit="ms")
async def port_bank_reports_port_state(d):
    """The AXI-Lite bank mirrors capability, status, occupancy and counters."""
    b = await bench_for(d)
    phy = 1 if PHY == "GMII" else 2
    assert await b.read(0x000) == 0x01 | phy << 8 | 1 << 12 | 1 << 16 | 8 << 24
    assert await b.read(0x004) == TABLE_DEPTH | RX_TABLE_DEPTH << 8 | 1518 << 16
    assert await b.read(0x008) == 32
    status = await b.read(0x010)
    assert status & 0x1 and status >> 16 != 0, hex(status)
    assert await b.read(0x014) == 0
    assert await b.read(0x018) == 0x1
    assert await b.read(0x020) == 0

    # A maximum frame and minimum frames behind it occupy several RX entries.
    frames = [ptp_message(0, 300).ljust(1514, b"\x00")]
    frames += [ptp_message((0, 8)[i % 2], 301+i) for i in range(6)]
    await b.inject_back_to_back(frames)
    await b.inject(ptp_message(8, 400), corrupt=True)
    await b.edge(400)
    occupancy = await b.read(0x020)
    tx_now, tx_peak, rx_now, rx_peak = (occupancy >> 8*i & 0xFF for i in range(4))
    assert tx_now == tx_peak == rx_now == 0, hex(occupancy)
    assert 2 <= rx_peak <= RX_TABLE_DEPTH, hex(occupancy)
    assert await b.write(0x024, 1) == AxiResp.OKAY
    assert await b.read(0x020) == 0

    # The adapter holds one record; the port holds the later completions,
    # whose entries stay owned until accepted.
    d.txReady.value = 0
    for sequence in range(3):
        await b.send(delay_req(sequence, 0, 0x1122))
    await b.edge(600)
    assert (await b.read(0x020)) & 0xFF == 2
    d.txReady.value = 1
    await b.edge(40)
    occupancy = await b.read(0x020)
    assert occupancy & 0xFF == 0 and 2 <= occupancy >> 8 & 0xFF <= TABLE_DEPTH, hex(occupancy)

    counters = int(d.counters.value)
    for index in range(8):
        assert await b.read(0x040 + 4*index) == counters >> 32*index & 0xFFFFFFFF, index
    assert counters & 0xFFFFFFFF == len(frames) and counters >> 32 & 0xFFFFFFFF == 1
    assert counters >> 96 & 0xFFFFFFFF == 3

    # Unmapped offsets and read-only registers refuse writes.
    assert (await with_timeout(b.axil.read(0x100, 4), 50, "us")).resp != AxiResp.OKAY
    assert await b.write(0x040, 0) != AxiResp.OKAY


PARAMETER_SWEEP = [
    parameter_case("gmii", PHY_TYPE_G="GMII"),
    parameter_case("xgmii", PHY_TYPE_G="XGMII"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_ptp_mac_port_adapters(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ptpmacportadapterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + WRAPPERS},
    )
