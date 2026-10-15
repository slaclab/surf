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
# - Sweep: Both zero calibration planes, each single zero and both nonzero;
#   full epochs/corrections, lane phases, per-capture increments and errors.
#   Each sweep runs with raw timestamps and normalized history words.
# - Stimulus: Integer timestamps and independent rational elapsed-time model.
# - Checks: Modulo signed128 forward/path delay, bounds, captured provenance,
#   immutable accepted operands and complete stalled-result stability.
# - Timing: The producer holds inputs through the bounded word upload; after
#   acknowledgement they are perturbed to check immutable RAM ownership.
#   Data-dependent exact arithmetic has an independently derived upper bound.
#   Cancellation/reset suppress upload, arithmetic and held publication.

from fractions import Fraction
import os
import random

import cocotb
from cocotb.triggers import Timer
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_reference import Q16, Q32, NS, nearest
from tests.ethernet.PtpCore.ptp_endpoint_reference import Q48, elapsed_master_q16

MASK = (1 << 128)-1
MASK64 = (1 << 64)-1
MIN128, MAX128 = -(1 << 127), (1 << 127)-1
INGRESS = int(os.environ.get("PTP_INGRESS", "475136"))
EGRESS = int(os.environ.get("PTP_EGRESS", "-229376"))
NORMALIZED = bool(int(os.environ.get("PTP_NORMALIZED", "0")))
OPERATIONS = 1+2*bool(INGRESS)+2*bool(EGRESS)
# Isolated service bound from 128 division iterations (at most 34 clocks each),
# setup/restoration, six products, timestamp sums, format shifts and publication.
# The per-client contention bound is checked separately by the compute fixture.
LATENCY = 3000+5000*(bool(INGRESS)+bool(EGRESS))
OUTPUTS = ("delayValue", "forwardValue", "resultError", "resultGeneration",
           "resultSyncSequence", "resultDelaySequence", "resultTicks",
           "resultRatio", "resultRatioValid", "resultIsDelay")


def signed(value, bits=128):
    return (value+(1 << (bits-1))) % (1 << bits)-(1 << (bits-1))


def timestamp(value, fraction=False):
    if fraction:
        sec, nsfrac = divmod(value, NS*Q16)
        assert 0 <= sec < 1 << 48
        return (sec << 48) | nsfrac
    sec, ns = divmod(value, NS)
    assert 0 <= sec < 1 << 48
    return (sec << 32) | ns


def unpack(value, fraction=False):
    if fraction:
        return (value >> 48)*NS*Q16+(value & ((1 << 48)-1))
    return ((value >> 32)*NS+(value & ((1 << 32)-1)))*Q16


def reference(values):
    """Model the published equations and their specified signed128 wrap."""
    if (not values["ratio"] or not values["syncIncrement"] or not values["txIncrement"]
            or values["syncGeneration"] != values["delayGeneration"]):
        return None
    rx = 8*values["syncTicks"]+values["syncPhase"]
    tx = 8*values["txTicks"]+values["txPhase"]
    product = (tx-rx)*values["ratio"]
    if not MIN128 <= product <= MAX128:
        return None
    elapsed = elapsed_master_q16(rx, tx, values["ratio"], INGRESS, EGRESS,
                                values["syncIncrement"], values["txIncrement"])
    t1 = unpack(values["syncRemote"])
    t2 = unpack(values["syncTime"], True)
    t4 = unpack(values["responseRemote"])
    c1 = signed(values["syncCorrection"])
    c4 = signed(values["responseCorrection"], 64)
    delay = nearest(Fraction(signed(t4-c4-t1-c1-elapsed), 2))
    return delay & MASK, (t2-t1-c1) & MASK, not 0 <= delay <= signed(values["maxPathDelay"], 64)


def sample(**overrides):
    values = dict(syncTime=timestamp((123*NS+4567)*Q16+13, True),
                  syncTicks=1000, syncPhase=0, syncIncrement=8*Q32,
                  syncRemote=timestamp(123*NS+1234), syncCorrection=0,
                  txTicks=2000, txPhase=4, txIncrement=8*Q32,
                  responseRemote=timestamp(123*NS+9438), responseCorrection=0,
                  ratio=8*Q48, maxPathDelay=1000000*Q16,
                  syncGeneration=0xABCDEF01, delayGeneration=0xABCDEF01,
                  syncSequence=0xFEED, delaySequence=0xCAFE)
    values.update(overrides)
    return values


class TB:
    def __init__(self, dut):
        self.d = dut

    async def edge(self, check_registered=False, ready_name="inputReady", **values):
        before = int(self.d.resultValid.value) if check_registered else None
        self.d.clk.value = 0
        for name, value in values.items():
            getattr(self.d, name).value = value
        await Timer(3.2, unit="ns")
        if check_registered:
            assert int(self.d.resultValid.value) == before, "result valid changed between edges"
        ready = int(getattr(self.d, ready_name).value)
        self.d.clk.value = 1
        await Timer(3.2, unit="ns")
        return ready

    async def reset(self):
        for name in ("clk", "cancel", "inputValid", "resultReady", "normalizedValid",
                     "normalizedWord", "normalizedData", *sample()):
            getattr(self.d, name).value = 0
        await self.edge(rst=1)
        await self.edge(rst=0)

    async def submit(self, values):
        if NORMALIZED:
            # Independent equations for the history stream. The same output
            # oracle below covers calibration, wraps and per-capture increments.
            corrected = (unpack(values["syncRemote"])+signed(values["syncCorrection"])) & MASK
            forward = (unpack(values["syncTime"], True)-corrected) & MASK
            for word in range(8):
                value = forward if word < 4 else corrected
                for _ in range(8):
                    if await self.edge(ready_name="normalizedReady", inputValid=0,
                                       normalizedValid=1, normalizedWord=word,
                                       normalizedData=(value >> (32*(word % 4))) & 0xFFFFFFFF):
                        break
                else:
                    assert False, "normalized history upload did not acknowledge"
            await self.edge(normalizedValid=0)
        for _ in range(2*56+4):
            if await self.edge(inputValid=1, resultReady=0, **values):
                break
        else:
            assert False, "word upload did not acknowledge the held sample"

    async def complete(self, values):
        await self.submit(values)
        latency = 0
        while not int(self.d.resultValid.value):
            assert latency < LATENCY+1, "E2E completion timeout"
            # Perturb all input payload after its accepting edge; the engine
            # must retain every field, including generation/sequence metadata.
            await self.edge(inputValid=0, **{name: 0 for name in sample()})
            latency += 1
        expected = reference(values)
        if expected is None:
            assert int(self.d.resultError.value)
            assert int(self.d.forwardValue.value) == 0
            assert int(self.d.delayValue.value) == 0
        else:
            assert 0 < latency <= LATENCY
            delay, forward, error = expected
            assert int(self.d.delayValue.value) == delay
            assert int(self.d.forwardValue.value) == forward
            assert bool(self.d.resultError.value) == error
            assert int(self.d.resultGeneration.value) == values["delayGeneration"]
            assert int(self.d.resultSyncSequence.value) == values["syncSequence"]
            assert int(self.d.resultDelaySequence.value) == values["delaySequence"]
            assert int(self.d.resultTicks.value) == values["txTicks"]
            assert int(self.d.resultRatio.value) == values["ratio"]
            assert int(self.d.resultRatioValid.value)
            assert int(self.d.resultIsDelay.value)
        held = tuple(int(getattr(self.d, name).value) for name in OUTPUTS)
        for _ in range(3):
            await self.edge(inputValid=1)
            assert int(self.d.resultValid.value)
            assert not int(self.d.inputReady.value)
            assert tuple(int(getattr(self.d, name).value) for name in OUTPUTS) == held
        await self.edge(inputValid=0, resultReady=1)
        assert not int(self.d.resultValid.value)
        return latency


@cocotb.test()
async def corrected_exchange(d):
    tb = TB(d)
    await tb.reset()
    rng = random.Random(1588)
    # Retain the original independent epoch/rate/correction sweep in every
    # elaborated calibration configuration.
    for index in range(24):
        ppm = (-100, 0, 100)[index % 3]
        ratio = nearest(Fraction(32, 5)/(1+Fraction(ppm, 1000000))*Q48)
        rx_inc = nearest(Fraction(32, 5)*Q32)
        tx_inc = nearest(Fraction(32, 5)*(1+Fraction(77, 1000000))*Q32)
        rx, tx = 8000+4*(index % 2), 8*1563500+4*((index+1) % 2)
        elapsed = elapsed_master_q16(rx, tx, ratio, INGRESS, EGRESS, rx_inc, tx_inc)
        remote1 = (1 << 39)*NS+1234
        correction1 = rng.randrange(-100*Q16, 100*Q16)
        correction4 = rng.randrange(-100*Q16, 100*Q16)
        wanted_delay = (-10, 100, 2000000)[index % 3]*Q16
        remote4 = nearest(Fraction(remote1*Q16+correction1+correction4+elapsed+2*wanted_delay, Q16))
        local2 = ((1 << 40)*NS+4567)*Q16+13
        await tb.complete(sample(syncTime=timestamp(local2, True), syncTicks=rx//8, syncPhase=rx % 8,
                                 syncIncrement=rx_inc, syncRemote=timestamp(remote1), syncCorrection=correction1 & MASK,
                                 txTicks=tx//8, txPhase=tx % 8, txIncrement=tx_inc, responseRemote=timestamp(remote4),
                                 responseCorrection=correction4 & MASK64, ratio=ratio))

    # Full epochs, signed128 correction wraps and negative/positive half ties
    # exercise the regrouped corrected-Sync sum before the final rounding.
    epoch = ((1 << 48)-1)*NS
    for correction in (MIN128, MIN128+1, MAX128, MAX128-1, -3, -1, 0, 1, 3):
        for c4 in (-(1 << 63), (1 << 63)-1):
            await tb.complete(sample(syncTime=timestamp((epoch+NS-1)*Q16+Q16-1, True),
                                     syncRemote=timestamp(epoch+NS-2), responseRemote=timestamp(0),
                                     syncCorrection=correction & MASK, responseCorrection=c4 & MASK64,
                                     syncTicks=MASK64, txTicks=MASK64-1, syncPhase=7, txPhase=0))
    # Each plane uses its own increment, including tiny divisors and the full
    # unsigned64 range. Reverse tick order remains a signed elapsed interval.
    for rx_inc, tx_inc in ((1, MASK64), (MASK64, 1), (MASK64, MASK64)):
        await tb.complete(sample(syncIncrement=rx_inc, txIncrement=tx_inc,
                                 syncTicks=2000, txTicks=1000, ratio=MASK64))
    # Exact max-path acceptance and adjacent rejection are checked after the
    # shared accumulator, with both positive and negative rounding half ties.
    for numerator in (-3, -1, 0, 1, 3, 2*123456-1, 2*123456, 2*123456+1):
        values = sample()
        elapsed = elapsed_master_q16(8000, 16004, values["ratio"], INGRESS, EGRESS,
                                    values["syncIncrement"], values["txIncrement"])
        values["syncCorrection"] = ((9438-1234)*Q16-elapsed-numerator) & MASK
        values["maxPathDelay"] = 123456
        await tb.complete(values)
    # Admission guards apply even when calibration is statically bypassed.
    for overrides in ({"ratio": 0}, {"syncIncrement": 0}, {"txIncrement": 0},
                      {"delayGeneration": 0xABCDEF00}):
        assert await tb.complete(sample(**overrides)) == 0
    # The elapsed product can exceed signed128 before its Q16 rounding.
    for rx, tx in ((0, MASK64), (MASK64, 0)):
        assert 0 < await tb.complete(sample(syncTicks=rx, txTicks=tx, ratio=MASK64)) < LATENCY
    d._log.info("E2E enabled operations=%d, successful latency=%d clocks", OPERATIONS, LATENCY)


@cocotb.test()
async def cancellation_and_reset(d):
    tb = TB(d)
    await tb.reset()
    values = sample()
    # Reach each math completion, every new finalization state, the publication
    # edge and a held valid. Cancellation/reset wins over simultaneous ready.
    offsets = {0, 1, 50, LATENCY}
    offsets.update((200, 500, 1000, 2000, LATENCY-1))
    for control in ("cancel", "rst"):
        for offset in sorted(offsets):
            await tb.submit(values)
            for _ in range(offset):
                await tb.edge(inputValid=0)
            await tb.edge(check_registered=True, inputValid=0, resultReady=1, **{control: 1})
            assert not int(d.resultValid.value), (control, offset)
            await tb.edge(**{control: 0})
            # An old Math response must not revive the canceled exchange.
            for _ in range(140):
                await tb.edge()
                assert not int(d.resultValid.value), (control, offset)
        await tb.complete(values)


@pytest.mark.parametrize("normalized", [False, True], ids=["raw", "normalized"])
@pytest.mark.parametrize("ingress,egress", [
    pytest.param(0, 0, id="zero"),
    pytest.param(475136, 0, id="ingress"),
    pytest.param(0, -229376, id="egress"),
    pytest.param(475136, -229376, id="both"),
])
def test_ptp_e2e(ingress, egress, normalized):
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptpe2ewrapper",
                      extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpE2eWrapper.vhd"]}, parameters={
        "INGRESS_LATENCY_G": format(ingress & MASK64, "064b"),
        "EGRESS_LATENCY_G": format(egress & MASK64, "064b"),
        "NORMALIZED_SYNC_G": normalized},
        extra_env={"PTP_INGRESS": ingress, "PTP_EGRESS": egress, "PTP_NORMALIZED": int(normalized)},
        sim_build_key=f"tests/sim_build/ethernet/PtpCore/test_ptp_e2e.{ingress}.{egress}.{normalized}")
