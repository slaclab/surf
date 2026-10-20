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
# - Stimulus: PtpTelemetry through a flat-port wrapper. Random PHC, measurement,
#   exchange, command and servo values; PHC second rollovers, discontinuity,
#   generation, timeValid, link/port and fault events; measurement transfers
#   (with and without abort); servo command acceptances and state changes,
#   including changes during a command's capture; consumer ready held high,
#   held low, and toggled randomly mid-record.
# - Checks: A cycle model of the capture buffers, sequence numbers, drop
#   counting, event coalescing and serializer, built from the record format,
#   must produce the DUT's output word, SOF and last on every cycle, and its
#   dropped count. Frames are whole with all keep bits. Measurements and servo
#   commands drop only while their buffers are busy; PHC events and servo state
#   changes coalesce instead of dropping. Inputs are never back-pressured
#   (there is no ready output to observe).
# - Timing: Inputs change and outputs are compared 2 ns after a rising edge,
#   after the registered outputs settle.

from __future__ import annotations

import random

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test

TELEMETRY_ID = 5
PHC, MEAS, SERVO = 1, 2, 3
LENGTH = {PHC: 8, MEAS: 27, SERVO: 19}
WIDTHS = {
    "phcSeconds": 48, "phcNanoseconds": 32, "phcFraction": 32, "phcTicks": 64, "phcRate": 64,
    "phcIncrement": 64, "phcGeneration": 32, "phcTimeValid": 1, "phcDiscontinuity": 1, "phcFault": 1,
    "portActive": 1, "linkReady": 1,
    "measValid": 1, "measReady": 1, "measAbort": 1, "measIsDelay": 1, "measGeneration": 32,
    "measTicks": 64, "measSyncSequence": 16, "measDelaySequence": 16, "measForward": 128,
    "measDelay": 128, "measRatio": 64, "measRatioValid": 1,
    "exT1": 80, "exT2": 96, "exT3": 96, "exT4": 80, "exSyncCorrection": 128, "exDelayCorrection": 64,
    "exGeneration": 32, "exSyncSequence": 16, "exDelaySequence": 16,
    "cmdValid": 1, "cmdReady": 1, "cmdKind": 3, "cmdGeneration": 32, "cmdSetSeconds": 48,
    "cmdSetNanoseconds": 32, "cmdSetFraction": 32, "cmdPhaseSeconds": 64, "cmdPhaseFraction": 64,
    "cmdRate": 64, "cmdValue": 1,
    "servoState": 3, "servoFilteredDelay": 128, "servoOffset": 128, "servoRatePpb": 64,
    "servoFilterCount": 3, "servoRejected": 32,
}
STROBES = ("phcDiscontinuity", "measValid", "measAbort", "cmdValid")


def low(value, bits=64):
    return value & ((1 << bits) - 1)


def header(kind, cause, seq, s, dropped=0):
    return [
        1 | kind << 8 | TELEMETRY_ID << 16 | cause << 24 | (seq & 0xFFFFFFFF) << 32,
        dropped | s["servoState"] << 32 | s["phcTimeValid"] << 35 | s["portActive"] << 36 | s["linkReady"] << 37 |
        s["phcFault"] << 38,
        s["phcSeconds"],
        s["phcNanoseconds"] | s["phcFraction"] << 32,
        s["phcTicks"],
        s["phcRate"],
        s["phcGeneration"],
    ]


def phc_words(seq, cause, s, dropped=0):
    return header(PHC, cause, seq, s, dropped) + [s["phcIncrement"]]


def meas_words(seq, s, dropped=0):
    return header(MEAS, s["measIsDelay"], seq, s, dropped) + [
        s["measIsDelay"] | s["measRatioValid"] << 1 | s["measSyncSequence"] << 16 | s["measDelaySequence"] << 32,
        s["measGeneration"], s["measTicks"],
        low(s["measForward"]), s["measForward"] >> 64,
        low(s["measDelay"]), s["measDelay"] >> 64,
        s["measRatio"],
        low(s["exT1"]), s["exT1"] >> 64, low(s["exT2"]), s["exT2"] >> 64,
        low(s["exT3"]), s["exT3"] >> 64, low(s["exT4"]), s["exT4"] >> 64,
        low(s["exSyncCorrection"]), s["exSyncCorrection"] >> 64, s["exDelayCorrection"],
        s["exSyncSequence"] | s["exDelaySequence"] << 16 | s["exGeneration"] << 32,
    ]


def servo_words(seq, cause, s, command, dropped=0):
    c = command or {k: 0 for k in WIDTHS}
    return header(SERVO, cause, seq, s, dropped) + [
        c["cmdKind"] | c["cmdValue"] << 3 | c["cmdGeneration"] << 32,
        c["cmdRate"], c["cmdPhaseSeconds"], c["cmdPhaseFraction"], c["cmdSetSeconds"],
        c["cmdSetNanoseconds"] | c["cmdSetFraction"] << 32,
        low(s["servoOffset"]), s["servoOffset"] >> 64,
        low(s["servoFilteredDelay"]), s["servoFilteredDelay"] >> 64,
        s["servoRatePpb"],
        s["servoState"] | s["servoFilterCount"] << 4 | s["servoRejected"] << 32,
    ]


class TelemetryModel:
    """Cycle model of PtpTelemetry: state after each edge, from that cycle's inputs."""

    def __init__(self):
        self.started = False
        self.last = None
        self.seq = 0
        self.dropped = 0
        self.arm = 0                # servoArm bits: 2 = "10", 1 = "01"
        self.phcDefer = 0
        self.stateDefer = False
        self.buf = {k: {"pending": False} for k in (PHC, SERVO)}
        self.meas = [{"pending": False}, {"pending": False}]
        self.measNext = 0
        self.measSlot = 0
        self.state = None
        self.word = 0
        self.master = None          # (data, last, sof) or None

    def words(self, kind):
        if kind == MEAS:
            b = self.meas[self.measSlot]
            return meas_words(b["seq"], b["sample"], self.dropped)
        b = self.buf[kind]
        if kind == PHC:
            return phc_words(b["seq"], b["cause"], b["sample"], self.dropped)
        return servo_words(b["seq"], b["cause"], b["sample"], b["command"], self.dropped)

    def claim(self, busy):
        self.seq = (self.seq + 1) & 0xFFFFFFFF
        if busy:
            self.dropped = min(self.dropped + 1, 0xFFFFFFFF)
        return not busy

    def step(self, cur, ready):
        """One edge. Busy checks and words use the state before the edge."""
        pending = {k: b["pending"] for k, b in self.buf.items()}
        measPending = [b["pending"] for b in self.meas]
        arm = self.arm

        # Serializer
        if ready:
            self.master = None
        if self.master is None:
            if self.state is None:
                if pending[PHC]:
                    self.state = PHC
                elif measPending[self.measNext]:
                    self.state = MEAS
                    self.measSlot = self.measNext
                elif pending[SERVO] and arm == 0:
                    self.state = SERVO
                self.word = 0
            if self.state is not None:
                # Buffers and the dropped count are still those before the edge.
                data = self.words(self.state)[self.word]
                last = self.word == LENGTH[self.state] - 1
                self.master = (data, last, self.word == 0)
                if last:
                    if self.state == MEAS:
                        self.meas[self.measSlot]["pending"] = False
                        self.measNext = 1 - self.measSlot
                    else:
                        self.buf[self.state]["pending"] = False
                    self.state = None
                    self.word = 0
                else:
                    self.word += 1

        # PHC events, coalescing while the buffer is busy
        prev = self.last
        cause = 0
        if self.started:
            cause = (int(cur["phcSeconds"] != prev["phcSeconds"]) | cur["phcDiscontinuity"] << 1 |
                     int(cur["phcGeneration"] != prev["phcGeneration"]) << 2 |
                     int(cur["phcTimeValid"] != prev["phcTimeValid"]) << 3 |
                     int(cur["portActive"] != prev["portActive"] or cur["linkReady"] != prev["linkReady"]) << 4 |
                     int(cur["phcFault"] and not prev["phcFault"]) << 5)
        cause |= self.phcDefer
        if cause:
            if pending[PHC]:
                self.phcDefer = cause
            else:
                self.claim(False)
                self.phcDefer = 0
                self.buf[PHC] = {"pending": True, "seq": self.seq, "cause": cause, "sample": dict(cur)}

        # Measurements: two buffers, oldest sent first; drop while both are busy
        if cur["measValid"] and cur["measReady"] and not cur["measAbort"]:
            if self.claim(measPending[0] and measPending[1]):
                slot = 1 if measPending[0] else 0
                if not measPending[1 - slot]:
                    self.measNext = slot
                self.meas[slot] = {"pending": True, "seq": self.seq, "sample": dict(cur)}

        # Servo: arm, commands (drop while busy), state changes (coalesce)
        self.arm = (arm >> 1) & 1
        servo = self.buf[SERVO]
        if arm == 1:
            servo["sample"] = dict(cur)
        if cur["cmdValid"] and cur["cmdReady"] and cur["cmdKind"] != 3:
            if self.claim(pending[SERVO]):
                self.buf[SERVO] = servo = {"pending": True, "seq": self.seq, "cause": 1, "command": dict(cur),
                                           "sample": None}
                self.arm = 2
        if (self.started and cur["servoState"] != prev["servoState"]) or self.stateDefer:
            if arm != 0 or self.arm != 0:
                servo["cause"] |= 2
                self.stateDefer = False
            elif pending[SERVO]:
                self.stateDefer = True
            else:
                self.claim(False)
                self.stateDefer = False
                self.buf[SERVO] = {"pending": True, "seq": self.seq, "cause": 2, "command": None,
                                   "sample": dict(cur)}

        self.started = True
        self.last = dict(cur)


class Bench:
    def __init__(self, dut, seed):
        self.dut = dut
        self.rng = random.Random(seed)
        self.cur = {name: 0 for name in WIDTHS}
        self.ready = 1
        self.model = TelemetryModel()
        self.frames = []
        self.words = []
        self.cycle = 0

    async def start(self):
        d = self.dut
        cocotb.start_soon(Clock(d.clk, 8, unit="ns").start())
        d.rst.value = 1
        d.outReady.value = 1
        self.apply()
        for _ in range(4):
            await RisingEdge(d.clk)
        await Timer(1, unit="ns")
        d.rst.value = 0

    def apply(self):
        for name, value in self.cur.items():
            getattr(self.dut, name).value = value
        self.dut.outReady.value = self.ready

    async def step(self, **changes):
        """Drive one cycle, then compare the DUT with the model after the edge.

        Values persist and strobes last one cycle.
        """
        d = self.dut
        for name in STROBES:
            self.cur[name] = 0
        self.cur.update(changes)
        self.apply()
        # A word transfers on this edge if it is presented with ready.
        if int(d.outValid.value) and self.ready:
            assert int(d.outKeep.value) == 0xFF
            sof, last = int(d.outSof.value), int(d.outLast.value)
            assert bool(sof) == (not self.words), "SOF must mark exactly the first word"
            self.words.append(int(d.outData.value))
            if last:
                kind = (self.words[0] >> 8) & 0xFF
                assert len(self.words) == LENGTH[kind], (kind, len(self.words))
                self.frames.append(self.words)
                self.words = []
        self.model.step(self.cur, self.ready)
        await RisingEdge(d.clk)
        # Registered outputs settle TPD_G (1 ns) after the edge.
        await Timer(2, unit="ns")
        self.cycle += 1
        want = self.model.master
        got = None
        if int(d.outValid.value):
            got = (int(d.outData.value), bool(int(d.outLast.value)), bool(int(d.outSof.value)))
        assert got == want, (self.cycle, got and hex(got[0]), want and hex(want[0]))
        assert int(d.dropped.value) == self.model.dropped, (self.cycle, int(d.dropped.value), self.model.dropped)

    async def idle(self, count):
        for _ in range(count):
            await self.step()

    def random_fields(self, prefix):
        """Random values for every non-strobe input named with prefix."""
        return {k: self.rng.getrandbits(w) for k, w in WIDTHS.items()
                if k.startswith(prefix) and k not in STROBES and k not in ("measReady", "cmdReady")}

    def kinds(self):
        return [(f[0] >> 8) & 0xFF for f in self.frames]


async def bench_for(dut, seed=1):
    b = Bench(dut, seed)
    b.cur.update(b.random_fields("phc"))
    b.cur["phcDiscontinuity"] = 0
    b.cur.update(phcTimeValid=1, portActive=1, linkReady=1, measReady=1, cmdReady=1, phcFault=0)
    b.cur.update(b.random_fields("servo"))
    await b.start()
    await b.idle(4)
    return b


async def random_traffic(b, cycles, spacing, gap=0):
    """Random events, about four per spacing cycles; gap idles after each."""
    for _ in range(cycles):
        r = b.rng.random()*spacing
        if r < 1:
            await b.step(**b.random_fields("phc"))
        elif r < 2:
            await b.step(measValid=1, **b.random_fields("meas"), **b.random_fields("ex"))
        elif r < 3:
            # Status settles in the second cycle after acceptance; a state
            # change may land anywhere around it.
            await b.step(cmdValid=1, **b.random_fields("cmd"))
            await b.idle(1)
            servo = b.random_fields("servo")
            servo["servoState"] = b.rng.choice((b.cur["servoState"], servo["servoState"] % 6))
            await b.step(**servo)
            await b.idle(1)
        elif r < 3.5:
            await b.step(servoState=(b.cur["servoState"]+1) % 6)
        elif r < 3.8:
            await b.step(phcDiscontinuity=1)
        elif r < 4:
            await b.step(linkReady=1-b.cur["linkReady"])
        else:
            await b.step()
            continue
        await b.idle(gap)


@cocotb.test(timeout_time=5, timeout_unit="ms")
async def records_match_model(dut):
    """Spaced triggers of every kind, consumer always ready: nothing is lost."""
    b = await bench_for(dut, seed=11)
    await random_traffic(b, 600, spacing=4, gap=40)
    # Also an aborted measurement (no record) and a generation/timeValid/fault event.
    await b.step(measValid=1, measAbort=1)
    await b.idle(40)
    await b.step(phcGeneration=b.cur["phcGeneration"]+1, phcTimeValid=0, phcFault=1)
    await b.idle(60)
    assert not b.words and b.model.dropped == 0
    assert set(b.kinds()) == {PHC, MEAS, SERVO} and len(b.frames) > 20, (set(b.kinds()), len(b.frames))


@cocotb.test(timeout_time=5, timeout_unit="ms")
async def servo_state_change_joins_capture(dut):
    """A state change while a command is being captured joins that record."""
    b = await bench_for(dut, seed=12)
    await b.step(cmdValid=1, **{**b.random_fields("cmd"), "cmdKind": 2})
    await b.step(servoState=(b.cur["servoState"]+2) % 6)
    await b.idle(40)
    assert len(b.frames) == 1
    frame = b.frames[0]
    assert (frame[0] >> 24) & 0xFF == 0b11 and frame[18] & 7 == b.cur["servoState"]


@cocotb.test(timeout_time=5, timeout_unit="ms")
async def events_coalesce_while_busy(dut):
    """PHC events and servo state changes behind a busy buffer make one record."""
    b = await bench_for(dut, seed=14)
    # Three PHC events and two state changes within one record time.
    await b.step(phcSeconds=b.cur["phcSeconds"]+1)
    await b.step(phcDiscontinuity=1)
    await b.step(linkReady=1-b.cur["linkReady"])
    await b.step(servoState=(b.cur["servoState"]+1) % 6)
    await b.step(servoState=(b.cur["servoState"]+1) % 6)
    await b.idle(80)
    causes = [(f[0] >> 24) & 0xFF for f in b.frames]
    assert b.kinds() == [PHC, SERVO, PHC, SERVO] and causes == [0b1, 0b10, 0b10010, 0b10], (b.kinds(), causes)
    assert b.model.dropped == 0 and int(dut.dropped.value) == 0


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def backpressure_drops_whole_records(dut):
    """A stalled or slow consumer loses measurements and commands, counted; events coalesce."""
    b = await bench_for(dut, seed=13)
    # Held low: one PHC record and two measurements wait; further measurements
    # drop, and the PHC events behind the waiting record coalesce into one.
    b.ready = 0
    for _ in range(4):
        await b.step(phcSeconds=b.cur["phcSeconds"]+1)
        await b.step(measValid=1, **b.random_fields("meas"))
        await b.idle(3)
    assert int(dut.outValid.value) and not b.frames
    b.ready = 1
    await b.idle(120)
    # PHC outranks measurements, so the coalesced PHC record precedes the second.
    assert b.kinds() == [PHC, MEAS, PHC, MEAS] and b.model.dropped == 2, (b.kinds(), b.model.dropped)
    sequences = [f[0] >> 32 for f in b.frames]
    assert sequences == [1, 2, 6, 3], sequences
    # Random ready, mid-record included, under dense traffic.
    for _ in range(4000):
        b.ready = int(b.rng.random() < 0.4)
        await random_traffic(b, 1, spacing=12)
    b.ready = 1
    await b.idle(200)
    assert not b.words and b.model.dropped > 3 and len(b.frames) > 50, (b.model.dropped, len(b.frames))


def test_ptp_telemetry():
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.ptptelemetrywrapper",
        extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpTelemetryWrapper.vhd"]},
        parameters={"TELEMETRY_ID_G": TELEMETRY_ID},
    )


if __name__ == "__main__":
    pytest.main([__file__])
