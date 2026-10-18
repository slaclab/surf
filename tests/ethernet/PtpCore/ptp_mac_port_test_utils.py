##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Bench for the PtpMacPortEthMac timing-port composition.

PhcModel drives the PHC tuple every cycle (time advancing by the increment,
ticks, generation, timeValid and captureAbort) into the port and both
passive-adapter oracles. PortBench decodes the packed completion, RX
metadata and oracle captures, drives tokened TX requests and records every
observation with the monitor's cycle index.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import random
import zlib

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.ethernet.EthMacCore.ethmac_test_utils import build_ethernet_frame


NS_PER_SECOND = 1_000_000_000
Q32 = 1 << 32
CAPTURE_BITS = 261
OUTCOMES = {0: "SENT", 1: "WIRE_ERR", 2: "DISCARDED", 3: "FLUSHED"}
COUNTER_NAMES = ["rxDelivered", "rxDropped", "rxLost", "txSent", "txWireError", "txDiscarded", "txFlushed", "txRejected"]


def port_frame(seed: int, length: int, dst: int = 0x5A0102030405) -> bytes:
    return build_ethernet_frame(
        dst_mac=dst,
        src_mac=0x660102030405,
        eth_type=0x88F7,
        payload=bytes(((seed * 7 + index) & 0xFF) for index in range(length - 14)),
    )


def fcs(frame: bytes) -> bytes:
    return zlib.crc32(frame).to_bytes(4, "little")


@dataclass(frozen=True)
class Capture:
    timestamp: int
    ticks: int
    tick_phase: int
    generation: int
    increment: int
    time_valid: int
    error: int

    @classmethod
    def decode(cls, value: int) -> "Capture":
        return cls(
            timestamp=(value >> 165) & ((1 << 96) - 1),
            ticks=(value >> 101) & ((1 << 64) - 1),
            tick_phase=(value >> 98) & 0x7,
            generation=(value >> 66) & 0xFFFFFFFF,
            increment=(value >> 2) & ((1 << 64) - 1),
            time_valid=(value >> 1) & 1,
            error=value & 1,
        )


@dataclass(frozen=True)
class Completion:
    cookie: int
    outcome: str
    capture_valid: int
    capture: Capture
    generation: int

    @classmethod
    def decode(cls, value: int) -> "Completion":
        return cls(
            cookie=(value >> 280) & 0xFFFFFFFF,
            outcome=OUTCOMES[(value >> 278) & 0x3],
            capture_valid=(value >> 277) & 1,
            capture=Capture.decode((value >> 16) & ((1 << CAPTURE_BITS) - 1)),
            generation=value & 0xFFFF,
        )


@dataclass(frozen=True)
class RxMeta:
    capture: Capture
    frame_length: int
    generation: int

    @classmethod
    def decode(cls, value: int) -> "RxMeta":
        return cls(
            capture=Capture.decode((value >> 32) & ((1 << CAPTURE_BITS) - 1)),
            frame_length=(value >> 16) & 0xFFFF,
            generation=value & 0xFFFF,
        )


class PhcModel:
    """PHC tuple driven 1 ns after each edge, i.e. standing for that cycle."""

    def __init__(self, dut, *, increment_ns: float, seed: int = 1):
        self.dut = dut
        self.total = (1_700_000_000 * NS_PER_SECOND + 123_456) * Q32
        self.increment = int(increment_ns * Q32)
        self.generation = 1
        self.ticks = 0
        self.time_valid = 1
        self.abort_next = 0
        self.rng = random.Random(seed)
        # (cycle, kind) for every commit and capture abort that took effect
        self.events: list[tuple[int, str]] = []
        self.random_commits = False
        # Scheduled commits: values standing from that cycle are post-commit
        self.schedule: dict[int, str] = {}
        self.cycle = 0

    def drive(self) -> None:
        dut = self.dut
        ns_total, frac = divmod(self.total, Q32)
        seconds, ns = divmod(ns_total, NS_PER_SECOND)
        dut.phcSeconds.value = seconds
        dut.phcNanoseconds.value = ns
        dut.phcFraction.value = frac
        dut.phcGeneration.value = self.generation
        dut.phcTicks.value = self.ticks
        dut.phcIncrement.value = self.increment
        dut.phcTimeValid.value = self.time_valid
        dut.captureAbort.value = self.abort_next

    def advance(self) -> None:
        # Values for the next cycle; random commits model RATE, SET, PHASE
        # and capture inhibition landing on arbitrary edges
        self.cycle += 1
        self.ticks += 1
        self.total += self.increment
        self.abort_next = 0
        kind = self.schedule.pop(self.cycle, None)
        if kind is not None:
            self.commit(kind)
        if self.random_commits:
            roll = self.rng.random()
            if roll < 0.03:
                self.increment += self.rng.choice([-1, 1]) * self.rng.randrange(1, 1 << 20)
                self.events.append((self.cycle, "RATE"))
            elif roll < 0.05:
                self.total += self.rng.randrange(1, 1 << 40)
                self.generation += 1
                self.events.append((self.cycle, "SET"))
            elif roll < 0.07:
                self.total -= self.rng.randrange(1, 1 << 30)
                self.generation += 1
                self.events.append((self.cycle, "PHASE"))
            elif roll < 0.09:
                self.abort_next = 1
                self.events.append((self.cycle, "ABORT"))

    def commit(self, kind: str) -> None:
        # RATE keeps the generation; SET and PHASE step time and advance it;
        # ABORT is a one-cycle capture inhibit
        if kind == "RATE":
            self.increment += 1 << 18
        elif kind == "SET":
            self.total += 37 * NS_PER_SECOND * Q32 + (12345 << 16)
            self.generation += 1
        elif kind == "PHASE":
            self.total -= 987_654 << 20
            self.generation += 1
        elif kind == "ABORT":
            self.abort_next = 1
        self.events.append((self.cycle, kind))


@dataclass
class Observed:
    cycle: int = 0
    completions: list[tuple[int, Completion]] = field(default_factory=list)
    rx_frames: list[dict] = field(default_factory=list)
    rx_oracle: list[tuple[int, Capture]] = field(default_factory=list)
    tx_oracle: list[tuple[int, Capture]] = field(default_factory=list)


class PortBench:
    def __init__(self, dut, *, phy: str):
        self.dut = dut
        self.phy = phy
        self.clk = dut.clk
        period = 8.0 if phy == "GMII" else 6.4
        self.period = period
        self.phc = PhcModel(dut, increment_ns=period)
        self.obs = Observed()
        self._beats: list[tuple[bytes, int, int, int]] = []
        self._meta: RxMeta | None = None

    async def start(self, *, open_admission: bool = True) -> None:
        dut = self.dut
        cocotb.start_soon(Clock(self.clk, self.period, unit="ns").start())
        dut.rst.setimmediatevalue(1)
        dut.phyReady.setimmediatevalue(1)
        for name in ("openAdmission", "drainRequest", "abortRequest", "cancelAck", "sAxisTValid",
                     "sAxisTLast", "sAxisSof", "sAxisEofe", "txTimestamp", "rxInject", "injGmiiRxDv",
                     "injGmiiRxEr"):
            getattr(dut, name).setimmediatevalue(0)
        for name in ("sAxisTData", "sAxisTKeep", "txCookie", "txFrameLength", "txGeneration", "injGmiiRxd"):
            getattr(dut, name).setimmediatevalue(0)
        dut.injXgmiiRxd.setimmediatevalue(0x0707070707070707)
        dut.injXgmiiRxc.setimmediatevalue(0xFF)
        dut.cmplReady.setimmediatevalue(1)
        dut.mAxisTReady.setimmediatevalue(1)
        self.phc.drive()
        cocotb.start_soon(self._phc_driver())
        await self.edge(6)
        dut.rst.value = 0
        await self.edge(4)
        cocotb.start_soon(self._monitor())
        if open_admission:
            await self.open()

    async def _phc_driver(self) -> None:
        while True:
            await RisingEdge(self.clk)
            await Timer(1, unit="ns")
            self.phc.advance()
            self.phc.drive()

    async def edge(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.clk)
            await Timer(1, unit="ns")

    async def open(self) -> None:
        self.dut.openAdmission.value = 1
        for _ in range(16):
            await self.edge()
            if int(self.dut.admissionOpen.value):
                return
        raise AssertionError("admission did not open")

    @property
    def generation(self) -> int:
        return int(self.dut.generation.value)

    def counters(self) -> dict[str, int]:
        value = int(self.dut.counters.value)
        return {name: (value >> (32 * i)) & 0xFFFFFFFF for i, name in enumerate(COUNTER_NAMES)}

    async def _monitor(self) -> None:
        dut = self.dut
        obs = self.obs
        while True:
            await RisingEdge(self.clk)
            await Timer(2, unit="ns")
            # One timeline with the PHC model: a registered output seen now
            # was computed from the tuple of cycle (cyc - 1)
            cyc = self.phc.cycle
            obs.cycle = cyc
            if int(dut.cmplValid.value) and int(dut.cmplReady.value):
                obs.completions.append((cyc, Completion.decode(int(dut.cmplData.value))))
            if int(dut.rxOracleSof.value):
                obs.rx_oracle.append((cyc, Capture.decode(int(dut.rxOracleCapture.value))))
            if int(dut.txOracleSof.value):
                obs.tx_oracle.append((cyc, Capture.decode(int(dut.txOracleCapture.value))))
            if int(dut.mAxisTValid.value) and int(dut.mAxisTReady.value):
                keep = int(dut.mAxisTKeep.value)
                data = int(dut.mAxisTData.value).to_bytes(16, "little")
                if not self._beats:
                    self._meta = RxMeta.decode(int(dut.rxMeta.value))
                self._beats.append((bytes(data[i] for i in range(16) if (keep >> i) & 1),
                                    int(dut.mAxisTId.value), int(dut.mAxisSof.value), int(dut.mAxisEofe.value)))
                if int(dut.mAxisTLast.value):
                    beats = self._beats
                    self._beats = []
                    obs.rx_frames.append({
                        "cycle": cyc,
                        "data": b"".join(b[0] for b in beats),
                        "tids": {b[1] for b in beats},
                        "sof": [b[2] for b in beats],
                        "eofe": beats[-1][3],
                        "meta": self._meta,
                    })

    async def send(self, frame: bytes, cookie: int, *, timestamp: int = 1, length: int | None = None,
                   generation: int | None = None, eofe: int = 0, keep_override: dict | None = None,
                   omit_last: bool = False, sof: int = 1, pause_after: int | None = None,
                   pause_cycles: int = 0, pause_hook=None) -> None:
        dut = self.dut
        dut.txCookie.value = cookie
        dut.txTimestamp.value = timestamp
        dut.txFrameLength.value = len(frame) if length is None else length
        dut.txGeneration.value = self.generation if generation is None else generation
        offsets = list(range(0, len(frame), 16))
        for index, offset in enumerate(offsets):
            chunk = frame[offset : offset + 16]
            last = index == len(offsets) - 1
            dut.sAxisTValid.value = 1
            dut.sAxisTData.value = int.from_bytes(chunk.ljust(16, b"\x00"), "little")
            keep = (1 << len(chunk)) - 1
            if keep_override and index in keep_override:
                keep = keep_override[index]
            dut.sAxisTKeep.value = keep
            dut.sAxisTLast.value = 1 if (last and not omit_last) else 0
            dut.sAxisSof.value = sof if index == 0 else 0
            dut.sAxisEofe.value = eofe if last else 0
            while True:
                await RisingEdge(self.clk)
                await Timer(1, unit="ns")
                if int(dut.sAxisTReady.value) == 1:
                    break
            if pause_after is not None and index == pause_after:
                dut.sAxisTValid.value = 0
                if pause_hook is not None:
                    await pause_hook()
                await self.edge(pause_cycles)
        dut.sAxisTValid.value = 0
        dut.sAxisTLast.value = 0
        dut.sAxisSof.value = 0
        dut.sAxisEofe.value = 0

    async def wait_for(self, predicate, *, cycles: int = 20000, what: str = "condition") -> None:
        for _ in range(cycles):
            if predicate():
                return
            await self.edge()
        raise AssertionError(f"timed out waiting for {what}")

    # RX injection -----------------------------------------------------------
    async def inject(self, frame: bytes, *, fcs_bytes: bytes | None = None, lane: int = 0,
                     preamble_ok: bool = True) -> None:
        dut = self.dut
        body = frame + (fcs(frame) if fcs_bytes is None else fcs_bytes)
        dut.rxInject.value = 1
        if self.phy == "GMII":
            octets = [0x55] * 7 + [0xD5] + list(body)
            for octet in octets:
                dut.injGmiiRxDv.value = 1
                dut.injGmiiRxd.value = octet
                await self.edge()
            dut.injGmiiRxDv.value = 0
            dut.injGmiiRxd.value = 0
            await self.edge(12)
        else:
            stream = [(0x07, 1)] * lane + [(0xFB, 1)] + [(0x55, 0)] * 6 + [(0xD5, 0)]
            stream += [(b, 0) for b in body] + [(0xFD, 1)] + [(0x07, 1)] * 12
            stream += [(0x07, 1)] * (-len(stream) % 8)
            for base in range(0, len(stream), 8):
                data = 0
                ctrl = 0
                for i, (octet, c) in enumerate(stream[base : base + 8]):
                    data |= octet << (8 * i)
                    ctrl |= c << i
                dut.injXgmiiRxd.value = data
                dut.injXgmiiRxc.value = ctrl
                await self.edge()
            dut.injXgmiiRxd.value = 0x0707070707070707
            dut.injXgmiiRxc.value = 0xFF
            await self.edge(2)
