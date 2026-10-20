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
#   (with and without abort); servo command acceptances and state changes;
#   consumer ready held high, held low, and toggled randomly mid-record.
# - Checks: A model logs every cycle's inputs and assigns record sequence
#   numbers in the RTL's trigger order. Each emitted record must equal the
#   words the model builds from its trigger cycle (servo status two cycles
#   after a command), apart from the dropped count, which must not decrease.
#   Frames are whole: SOF on the first word only, all keep bits, the type's
#   length. Under backpressure the missing sequence numbers must equal the
#   dropped counter, and inputs are never back-pressured (there is no ready
#   output to observe).
# - Timing: Inputs change after a rising edge; the monitor samples transfers
#   at the falling edge.

from __future__ import annotations

import random

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

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


def header(kind, cause, seq, s):
    return [
        1 | kind << 8 | TELEMETRY_ID << 16 | cause << 24 | (seq & 0xFFFFFFFF) << 32,
        s["servoState"] << 32 | s["phcTimeValid"] << 35 | s["portActive"] << 36 | s["linkReady"] << 37 |
        s["phcFault"] << 38,
        s["phcSeconds"],
        s["phcNanoseconds"] | s["phcFraction"] << 32,
        s["phcTicks"],
        s["phcRate"],
        s["phcGeneration"],
    ]


def phc_words(seq, cause, s):
    return header(PHC, cause, seq, s) + [s["phcIncrement"]]


def meas_words(seq, s):
    return header(MEAS, s["measIsDelay"], seq, s) + [
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


def servo_words(seq, cause, s, command):
    c = command or {k: 0 for k in WIDTHS}
    return header(SERVO, cause, seq, s) + [
        c["cmdKind"] | c["cmdValue"] << 3 | c["cmdGeneration"] << 32,
        c["cmdRate"], c["cmdPhaseSeconds"], c["cmdPhaseFraction"], c["cmdSetSeconds"],
        c["cmdSetNanoseconds"] | c["cmdSetFraction"] << 32,
        low(s["servoOffset"]), s["servoOffset"] >> 64,
        low(s["servoFilteredDelay"]), s["servoFilteredDelay"] >> 64,
        s["servoRatePpb"],
        s["servoState"] | s["servoFilterCount"] << 4 | s["servoRejected"] << 32,
    ]


class Bench:
    def __init__(self, dut, seed):
        self.dut = dut
        self.rng = random.Random(seed)
        self.cur = {name: 0 for name in WIDTHS}
        self.ready = 1
        self.history = []
        self.frames = []
        self.words = []

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
        cocotb.start_soon(self.monitor())

    def apply(self):
        for name, value in self.cur.items():
            getattr(self.dut, name).value = value
        self.dut.outReady.value = self.ready

    async def step(self, **changes):
        """Drive one cycle: values persist, strobes last one cycle."""
        for name in STROBES:
            self.cur[name] = 0
        self.cur.update(changes)
        self.apply()
        self.history.append(dict(self.cur))
        await RisingEdge(self.dut.clk)
        await Timer(1, unit="ns")

    async def idle(self, count):
        for _ in range(count):
            await self.step()

    async def monitor(self):
        d = self.dut
        while True:
            await FallingEdge(d.clk)
            if int(d.outValid.value) and int(d.outReady.value):
                assert int(d.outKeep.value) == 0xFF
                sof, last = int(d.outSof.value), int(d.outLast.value)
                assert bool(sof) == (not self.words), "SOF must mark exactly the first word"
                self.words.append(int(d.outData.value))
                if last:
                    self.frames.append(self.words)
                    self.words = []

    def random_fields(self, prefix):
        """Random values for every non-strobe input named with prefix."""
        return {k: self.rng.getrandbits(w) for k, w in WIDTHS.items()
                if k.startswith(prefix) and k not in STROBES and k not in ("measReady", "cmdReady")}

    def expected(self):
        """Records by sequence number, built from the logged cycles."""
        out = {}
        seq = 0
        h = self.history
        for n in range(1, len(h)):
            cur, prev = h[n], h[n-1]
            cause = (int(cur["phcSeconds"] != prev["phcSeconds"]) | cur["phcDiscontinuity"] << 1 |
                     int(cur["phcGeneration"] != prev["phcGeneration"]) << 2 |
                     int(cur["phcTimeValid"] != prev["phcTimeValid"]) << 3 |
                     int(cur["portActive"] != prev["portActive"] or cur["linkReady"] != prev["linkReady"]) << 4 |
                     int(cur["phcFault"] and not prev["phcFault"]) << 5)
            if cause:
                seq += 1
                out[seq] = phc_words(seq, cause, cur)
            if cur["measValid"] and cur["measReady"] and not cur["measAbort"]:
                seq += 1
                out[seq] = meas_words(seq, cur)
            if cur["cmdValid"] and cur["cmdReady"]:
                seq += 1
                if n+2 < len(h):
                    out[seq] = servo_words(seq, 1, h[n+2], cur)
            if cur["servoState"] != prev["servoState"]:
                seq += 1
                out[seq] = servo_words(seq, 2, cur, None)
        return out, seq

    def check(self, allow_drops):
        expected, triggers = self.expected()
        assert not self.words, "a frame was left incomplete"
        seen = []
        last_drops = 0
        for frame in self.frames:
            kind = (frame[0] >> 8) & 0xFF
            seq = frame[0] >> 32
            assert len(frame) == LENGTH[kind], (kind, len(frame))
            drops = frame[1] & 0xFFFFFFFF
            assert drops >= last_drops
            last_drops = drops
            want = list(expected[seq])
            got = list(frame)
            got[1] &= ~0xFFFFFFFF
            assert got == want, (seq, kind, [(i, hex(g), hex(w)) for i, (g, w) in enumerate(zip(got, want)) if g != w])
            seen.append(seq)
        missing = triggers - len(seen)
        assert int(self.dut.dropped.value) == missing, (int(self.dut.dropped.value), missing)
        if not allow_drops:
            assert missing == 0
        assert len(set(seen)) == len(seen)
        return seen, missing


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
            # Status settles in the second cycle after acceptance; the state is
            # held so no change falls inside the capture window.
            await b.step(cmdValid=1, **b.random_fields("cmd"))
            await b.idle(1)
            await b.step(**{**b.random_fields("servo"), "servoState": b.cur["servoState"]})
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
    seen, missing = b.check(allow_drops=False)
    kinds = {(f[0] >> 8) & 0xFF for f in b.frames}
    assert kinds == {PHC, MEAS, SERVO} and len(seen) > 20, (kinds, len(seen))


@cocotb.test(timeout_time=5, timeout_unit="ms")
async def servo_state_change_joins_capture(dut):
    """A state change while a command is being captured joins that record."""
    b = await bench_for(dut, seed=12)
    await b.step(cmdValid=1, **b.random_fields("cmd"))
    await b.step(servoState=(b.cur["servoState"]+2) % 6)
    await b.idle(40)
    assert len(b.frames) == 1
    frame = b.frames[0]
    assert (frame[0] >> 24) & 0xFF == 0b11 and frame[18] & 7 == b.cur["servoState"]
    assert int(dut.dropped.value) == 0


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def backpressure_drops_whole_records(dut):
    """A stalled or slow consumer loses whole records, counted and visible as gaps."""
    b = await bench_for(dut, seed=13)
    # Held low: one record per type waits; the rest of each type is dropped.
    b.ready = 0
    for _ in range(4):
        await b.step(phcSeconds=b.cur["phcSeconds"]+1)
        await b.step(measValid=1, **b.random_fields("meas"))
        await b.idle(3)
    assert int(dut.outValid.value) and not b.frames
    b.ready = 1
    await b.idle(120)
    seen, missing = b.check(allow_drops=True)
    assert len(seen) == 2 and missing == 6, (seen, missing)
    # Random ready, mid-record included, under dense traffic.
    for _ in range(4000):
        b.ready = int(b.rng.random() < 0.4)
        await random_traffic(b, 1, spacing=12)
    b.ready = 1
    await b.idle(200)
    seen, missing = b.check(allow_drops=True)
    assert missing > 0 and len(seen) > 50, (len(seen), missing)


def test_ptp_telemetry():
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.ptptelemetrywrapper",
        extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpTelemetryWrapper.vhd"]},
        parameters={"TELEMETRY_ID_G": TELEMETRY_ID},
    )


if __name__ == "__main__":
    pytest.main([__file__])
