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
# - Sweep: PtpMacPortEthMac (PtpMacPort over a timing-mode EthMacTop) for
#   GMII and XGMII, with PtpRxTimestampAdapter oracles on the RX pins and, in
#   TX-observe mode, on the TX pins, both fed the same PHC tuple as the port.
#   Calibration latencies are zero, so in loopback the RX and TX captures of
#   one pin word are the same value.
# - Stimulus: A PHC model advances every cycle and applies RATE, SET, PHASE
#   and capture-abort commits either at cycles scheduled relative to a
#   frame's pin cycle (one before, on, one after, and mid-frame) or at random.
#   Tokened TX requests exercise every stream-shape rule, exhaustion with
#   completions held, PHY loss and forced abort; RX traffic is looped back or
#   injected (including XGMII lane-4 starts, runts, oversize and bad FCS).
# - Checks: Port captures equal the oracle captures bit for bit; captureValid
#   and capture.error follow section 4/3 of the contract for each commit
#   placement; every TX request completes exactly once with the specified
#   outcome and cookie; rejected TX frames never reach the pins; RX frames
#   are delivered with metadata, SOF and tId cleared or are counted as
#   dropped; drain finishes an admitted frame before drainIdle; forced abort
#   completes FLUSHED/WIRE_ERR/DISCARDED as specified, terminates a partial RX
#   delivery with EOFE, advances the generation and flushes stale requests.
# - Timing: Observations carry the PHC model's cycle; an oracle SOF seen at
#   cycle j was computed from the tuple of cycle j - 1.

from __future__ import annotations

import os

import cocotb
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES
from tests.ethernet.PtpCore.ptp_mac_port_test_utils import PortBench, port_frame


WRAPPER_PATH = "ethernet/PtpCore/wrappers/PtpMacPortEthMacWrapper.vhd"
PHY = os.environ.get("PHY_TYPE_G", "GMII")


async def _bench(dut, **kwargs) -> PortBench:
    bench = PortBench(dut, phy=PHY)
    await bench.start(**kwargs)
    return bench


async def _send_and_settle(bench: PortBench, frame: bytes, cookie: int, **kwargs) -> None:
    count = len(bench.obs.completions)
    await bench.send(frame, cookie, **kwargs)
    await bench.wait_for(lambda: len(bench.obs.completions) > count, what=f"completion {cookie:#x}")
    await bench.edge(40)


def _same_except_error(a, b) -> bool:
    return (a.timestamp, a.ticks, a.tick_phase, a.generation, a.increment, a.time_valid) == (
        b.timestamp, b.ticks, b.tick_phase, b.generation, b.increment, b.time_valid)


# --------------------------------------------------------------------------
# Capture alignment under PHC commits (section 2.4)
# --------------------------------------------------------------------------

@cocotb.test(timeout_time=3, timeout_unit="ms")
async def capture_alignment_under_commits(dut):
    bench = await _bench(dut)
    obs = bench.obs
    frame = port_frame(3, 100)

    # Calibrate the idle send-to-pin latency for this frame length
    start = bench.phc.cycle
    await _send_and_settle(bench, frame, 0x100)
    latency = obs.tx_oracle[0][0] - 1 - start

    cases = [(kind, off) for kind in ("RATE", "SET", "PHASE", "ABORT") for off in (-1, 0, 1)]
    # Mid-frame: well inside start..done (100 bytes is ~108 GMII cycles but
    # only ~14 XGMII words)
    mid = 50 if PHY == "GMII" else 6
    cases += [("SET", mid), ("ABORT", mid)]
    results = []
    for index, (kind, off) in enumerate(cases):
        start = bench.phc.cycle
        bench.phc.schedule[start + latency + off] = kind
        tx_before, rx_before = len(obs.tx_oracle), len(obs.rx_frames)
        await _send_and_settle(bench, frame, 0x200 + index)
        await bench.wait_for(lambda: len(obs.rx_frames) > rx_before, what="loopback delivery")
        tuple_cycle = obs.tx_oracle[tx_before][0] - 1
        commit_cycle = [c for c, k in bench.phc.events if k == kind][-1]
        assert commit_cycle - tuple_cycle == off, f"{kind}{off:+d} landed at {commit_cycle - tuple_cycle:+d}"
        results.append((kind, off, obs.completions[-1][1], obs.tx_oracle[tx_before][1], obs.rx_frames[-1],
                        bench.phc.generation))

    for kind, off, completion, oracle, rx, phc_gen in results:
        name = f"{kind}{off:+d}"
        changes_gen = kind in ("SET", "PHASE")
        tx_valid = not ((kind == "ABORT" and off >= 0) or (changes_gen and off > 0))
        rx_error = (kind == "ABORT" and off == 0) or (changes_gen and off > 0)
        assert completion.outcome == "SENT", name
        assert completion.capture_valid == int(tx_valid), f"{name}: captureValid {completion.capture_valid}"
        if tx_valid:
            assert completion.capture == oracle, f"{name}: TX capture differs from the TX tap"
        else:
            # An unusable capture reports the PHC generation at retirement
            assert completion.capture.generation == phc_gen, name
        assert rx["data"] == frame
        rx_capture = rx["meta"].capture
        assert _same_except_error(rx_capture, oracle), f"{name}: RX capture fields differ from the pin oracle"
        assert rx_capture.error == int(rx_error), f"{name}: RX capture.error {rx_capture.error}"
        assert oracle.error == int(kind == "ABORT" and off == 0), name

    # Where the RX adapter kept the frame, it agrees with the port as well
    by_ticks = {cap.ticks: cap for _, cap in obs.rx_oracle}
    for _, _, _, oracle, rx, _ in results:
        if oracle.ticks in by_ticks:
            assert _same_except_error(rx["meta"].capture, by_ticks[oracle.ticks])


@cocotb.test(timeout_time=3, timeout_unit="ms")
async def rx_injected_captures_match_adapter(dut):
    bench = await _bench(dut)
    obs = bench.obs
    bench.phc.random_commits = True
    frames = [port_frame(10 + i, 64 + 13 * i) for i in range(12)]
    for i, frame in enumerate(frames):
        await bench.inject(frame, lane=4 * (i % 2) if PHY == "XGMII" else 0)
    await bench.wait_for(lambda: len(obs.rx_frames) == len(frames), what="deliveries")
    await bench.edge(20)
    bench.phc.random_commits = False

    assert [f["data"] for f in obs.rx_frames] == frames
    by_ticks = {cap.ticks: (cyc, cap) for cyc, cap in obs.rx_oracle}
    gen_changes = [c for c, k in bench.phc.events if k in ("SET", "PHASE")]
    matched = 0
    for rx in obs.rx_frames:
        capture = rx["meta"].capture
        assert rx["tids"] == {0} and rx["sof"][0] == 1 and rx["eofe"] == 0
        if capture.ticks in by_ticks:
            matched += 1
            oracle_cycle, oracle = by_ticks[capture.ticks]
            assert _same_except_error(capture, oracle)
            if capture.error and not oracle.error:
                assert any(c >= oracle_cycle for c in gen_changes), "error without a generation change"
            assert capture.error >= oracle.error
        else:
            # The adapter abandons a frame whose preamble saw a generation change
            assert gen_changes, "port capture with no adapter capture and no generation change"
    assert matched >= len(frames) // 2


# --------------------------------------------------------------------------
# TX admission, stream shape and completions (section 4)
# --------------------------------------------------------------------------

@cocotb.test(timeout_time=3, timeout_unit="ms")
async def tx_stream_shape_rules(dut):
    bench = await _bench(dut)
    obs = bench.obs
    good = port_frame(20, 120)

    async def wire_count_after(coro) -> int:
        before = len(obs.tx_oracle)
        await coro
        await bench.edge(60)
        return len(obs.tx_oracle) - before

    # Identical payloads, different cookies
    await _send_and_settle(bench, good, 0xA1)
    await _send_and_settle(bench, good, 0xA2)
    # Declared length mismatch, out-of-range lengths, partial keep, EOFE on last
    assert await wire_count_after(_send_and_settle(bench, good, 0xB1, length=130)) == 0
    assert await wire_count_after(_send_and_settle(bench, port_frame(21, 15)[:15].ljust(16, b"\0"), 0xB2, length=15)) == 0
    assert await wire_count_after(_send_and_settle(bench, port_frame(22, 1519), 0xB3)) == 0
    assert await wire_count_after(_send_and_settle(bench, good, 0xB4, keep_override={2: 0x00FF})) == 0
    assert await wire_count_after(_send_and_settle(bench, good, 0xB5, eofe=1)) == 0
    # Stale generation
    assert await wire_count_after(_send_and_settle(bench, good, 0xB6, generation=bench.generation + 5)) == 0
    # No timestamp requested
    await _send_and_settle(bench, good, 0xC1, timestamp=0)
    # Beats with no SOF: consumed, counted, no completion
    rejected = bench.counters()["txRejected"]
    completions = len(obs.completions)
    await bench.send(good, 0xD1, sof=0)
    await bench.edge(40)
    assert len(obs.completions) == completions and bench.counters()["txRejected"] == rejected + 1
    # Nested SOF: the open frame is discarded, the new SOF is a new request
    count = len(obs.completions)
    await bench.send(good[:48], 0xE1, length=len(good), omit_last=True)
    await bench.send(good, 0xE2)
    await bench.wait_for(lambda: len(obs.completions) >= count + 2, what="nested SOF completions")
    # Missing EOF: ended after the declared length plus 64 bytes, drained to
    # the next SOF, which is admitted normally
    count = len(obs.completions)
    await bench.send(port_frame(23, 320), 0xF1, length=64, omit_last=True)
    await bench.send(good, 0xF2)
    await bench.wait_for(lambda: len(obs.completions) >= count + 2, what="missing EOF completions")
    await bench.edge(60)

    outcomes = {c.cookie: (c.outcome, c.capture_valid, c.generation) for _, c in obs.completions}
    assert outcomes[0xA1][:2] == ("SENT", 1) and outcomes[0xA2][:2] == ("SENT", 1)
    for cookie in (0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xE1, 0xF1):
        assert outcomes[cookie][0] == "DISCARDED", hex(cookie)
    assert outcomes[0xB6] == ("FLUSHED", 0, bench.generation + 5)
    assert outcomes[0xC1][:2] == ("SENT", 0)
    assert outcomes[0xE2][:2] == ("SENT", 1) and outcomes[0xF2][:2] == ("SENT", 1)
    assert len(obs.completions) == len(outcomes), "each request completes exactly once"
    sent = [c for _, c in obs.completions if c.outcome == "SENT"]
    assert len(obs.tx_oracle) == len(sent), "only SENT frames reach the pins"
    for (_, oracle), completion in zip(obs.tx_oracle, sent):
        if completion.capture_valid:
            assert completion.capture == oracle
    counters = bench.counters()
    assert counters["txSent"] == len(sent) and counters["txDiscarded"] == 7 and counters["txFlushed"] == 1
    assert int(dut.faults.value) == 0


@cocotb.test(timeout_time=3, timeout_unit="ms")
async def tx_exhaustion_holds_admission(dut):
    bench = await _bench(dut)
    obs = bench.obs
    dut.cmplReady.value = 0
    frames = [port_frame(30 + i, 64) for i in range(18)]

    async def send_all():
        for i, frame in enumerate(frames):
            await bench.send(frame, 0x300 + i)

    sender = cocotb.start_soon(send_all())
    await bench.edge(4000)
    # Sixteen entries are owned until their completions are accepted
    assert len(obs.tx_oracle) == 16, f"{len(obs.tx_oracle)} frames sent with completions held"
    assert int(dut.cmplValid.value) == 1
    dut.cmplReady.value = 1
    await sender
    await bench.wait_for(lambda: len(obs.completions) == len(frames), what="all completions")
    assert [c.cookie for _, c in obs.completions] == [0x300 + i for i in range(len(frames))]
    assert all(c.outcome == "SENT" for _, c in obs.completions)


@cocotb.test(timeout_time=3, timeout_unit="ms")
async def tx_phy_outcomes(dut):
    bench = await _bench(dut)
    obs = bench.obs
    frame = port_frame(40, 600)
    dut.phyReady.value = 0
    await _send_and_settle(bench, frame, 0x401)
    dut.phyReady.value = 1
    await bench.edge(40)
    # Link loss while the frame is on the pins
    count = len(obs.completions)
    sender = cocotb.start_soon(bench.send(frame, 0x402))
    await bench.wait_for(lambda: len(obs.tx_oracle) >= 1, what="frame on the pins")
    await bench.edge(20)
    dut.phyReady.value = 0
    await sender
    await bench.wait_for(lambda: len(obs.completions) > count, what="link-loss completion")
    dut.phyReady.value = 1
    await bench.edge(40)
    await _send_and_settle(bench, port_frame(41, 100), 0x403)

    outcomes = [(c.cookie, c.outcome) for _, c in obs.completions]
    assert outcomes == [(0x401, "DISCARDED"), (0x402, "WIRE_ERR"), (0x403, "SENT")]
    wire_err = obs.completions[1][1]
    if wire_err.capture_valid:
        assert wire_err.capture == obs.tx_oracle[0][1]


# --------------------------------------------------------------------------
# RX dispositions (section 3)
# --------------------------------------------------------------------------

@cocotb.test(timeout_time=3, timeout_unit="ms")
async def rx_dispositions(dut):
    bench = await _bench(dut)
    obs = bench.obs
    runt = port_frame(50, 40)
    good = port_frame(51, 1518)
    long1 = port_frame(52, 1519)
    long2 = port_frame(53, 1520)
    bad = port_frame(54, 200)
    after = port_frame(55, 64)
    for frame in (runt, good, long1, long2):
        await bench.inject(frame)
    await bench.inject(bad, fcs_bytes=b"\x00\x11\x22\x33")
    await bench.inject(after)
    await bench.wait_for(lambda: len(obs.rx_frames) == 2, what="deliveries")
    await bench.edge(200)
    assert [f["data"] for f in obs.rx_frames] == [good, after]
    assert [f["meta"].frame_length for f in obs.rx_frames] == [1518, 64]
    counters = bench.counters()
    assert counters["rxDelivered"] == 2 and counters["rxDropped"] == 4
    assert int(dut.drainIdle.value) == 1, "every RX token was released"


@cocotb.test(timeout_time=3, timeout_unit="ms")
async def rx_table_exhaustion(dut):
    bench = await _bench(dut)
    obs = bench.obs
    dut.mAxisTReady.value = 0
    frames = [port_frame(60 + i, 64) for i in range(20)]
    for frame in frames:
        await bench.inject(frame)
    await bench.edge(100)
    dropped = bench.counters()["rxDropped"]
    assert dropped == 4, f"frames beyond the table are suppressed at the importer, dropped={dropped}"
    dut.mAxisTReady.value = 1
    await bench.wait_for(lambda: len(obs.rx_frames) == 16, what="16 deliveries")
    await bench.edge(100)
    assert [f["data"] for f in obs.rx_frames] == frames[:16]
    assert bench.counters()["rxDelivered"] == 16


# --------------------------------------------------------------------------
# Lifecycle: generation, drain and forced abort (section 6)
# --------------------------------------------------------------------------

@cocotb.test(timeout_time=3, timeout_unit="ms")
async def lifecycle_open_and_drain(dut):
    bench = await _bench(dut, open_admission=False)
    obs = bench.obs
    assert bench.generation == 0 and int(dut.admissionOpen.value) == 0
    # Closed: TX SOF is held off; RX frames are suppressed and counted
    dut.txGeneration.value = 0
    sender = cocotb.start_soon(bench.send(port_frame(70, 64), 0x700, generation=0))
    await bench.edge(200)
    assert int(dut.sAxisTReady.value) == 0 and not obs.completions
    await bench.inject(port_frame(71, 64))
    await bench.edge(50)
    assert bench.counters()["rxDropped"] == 1 and not obs.rx_frames
    # Open: generation leaves its reset value; the waiting request is now stale
    await bench.open()
    assert bench.generation == 1
    await sender
    await bench.wait_for(lambda: obs.completions, what="stale completion")
    assert obs.completions[0][1].outcome == "FLUSHED" and obs.completions[0][1].generation == 0

    # Drain with a half-presented frame: it finishes; new SOFs wait
    async def raise_drain():
        dut.drainRequest.value = 1
        await bench.edge(4)
        assert int(dut.admissionOpen.value) == 0

    count = len(obs.completions)
    await bench.send(port_frame(72, 200), 0x701, pause_after=3, pause_cycles=50, pause_hook=raise_drain)
    await bench.wait_for(lambda: len(obs.completions) > count, what="drained frame completion")
    assert obs.completions[-1][1].outcome == "SENT"
    await bench.wait_for(lambda: int(dut.drainIdle.value) == 1, what="drainIdle")
    blocked = cocotb.start_soon(bench.send(port_frame(73, 64), 0x702))
    await bench.edge(200)
    assert len(obs.completions) == count + 1, "no admission while draining"
    dut.drainRequest.value = 0
    await blocked
    await bench.wait_for(lambda: len(obs.completions) == count + 2, what="post-drain completion")
    assert obs.completions[-1][1].outcome == "SENT" and bench.generation == 1


@cocotb.test(timeout_time=3, timeout_unit="ms")
async def forced_abort(dut):
    bench = await _bench(dut)
    obs = bench.obs
    gen = bench.generation
    dut.mAxisTReady.value = 0
    dut.cmplReady.value = 0
    big = port_frame(80, 1400)

    # RX: frames stored behind a stalled controller, one partly delivered
    for i in range(3):
        await bench.inject(port_frame(81 + i, 300))
    dut.mAxisTReady.value = 1
    await bench.edge(1)
    dut.mAxisTReady.value = 0

    # TX: one long frame on the pins, two short frames queued behind it, one
    # half-presented at the controller; all are offered before the long frame
    # reaches the pins (store-and-forward in the port and the checksum cache)
    sender = cocotb.start_soon(_tx_queue(bench, big))
    await bench.wait_for(lambda: len(obs.tx_oracle) >= 1, what="first frame on the pins")
    await bench.edge(10)
    dut.abortRequest.value = 1
    await bench.wait_for(lambda: int(dut.cancelRequest.value) == 1, what="cancelRequest")
    # The controller's cancellation duties: finish its open TX frame with
    # EOFE (the queue coroutine does this when it sees cancelRequest) and
    # consume the port's partial-RX terminator
    dut.mAxisTReady.value = 1
    await sender
    await bench.edge(10)
    dut.cancelAck.value = 1
    await bench.wait_for(lambda: int(dut.abortDone.value) == 1, what="abortDone")
    assert bench.generation == gen + 1
    assert int(dut.cancelRequest.value) == 0
    # Completions held through the abort are delivered normally
    dut.cmplReady.value = 1
    await bench.wait_for(lambda: len(obs.completions) == 4, what="abort completions")
    dut.abortRequest.value = 0
    dut.cancelAck.value = 0
    await bench.edge(10)

    outcomes = {c.cookie: c for _, c in obs.completions}
    assert outcomes[0x801].outcome == "WIRE_ERR", "the frame on the pins ends through its done"
    assert outcomes[0x802].outcome == "FLUSHED" and outcomes[0x803].outcome == "FLUSHED"
    assert outcomes[0x804].outcome == "DISCARDED", "the controller-terminated frame"
    assert all(c.generation == gen for c in outcomes.values())
    rx = obs.rx_frames
    assert len(rx) == 1 and rx[0]["eofe"] == 1, "the partial RX frame ends with EOFE and nothing follows"
    assert int(dut.drainIdle.value) == 1

    # Reopen needs a rising openAdmission; a request built before the abort
    # is flushed and new ones are sent
    assert int(dut.admissionOpen.value) == 0
    dut.openAdmission.value = 0
    await bench.edge(2)
    await bench.open()
    await _send_and_settle(bench, port_frame(90, 64), 0x901, generation=gen)
    await _send_and_settle(bench, port_frame(91, 64), 0x902)
    assert obs.completions[-2][1].outcome == "FLUSHED" and obs.completions[-2][1].generation == gen
    assert obs.completions[-1][1].outcome == "SENT" and obs.completions[-1][1].generation == gen + 1
    await bench.inject(port_frame(92, 64))
    await bench.wait_for(lambda: len(obs.rx_frames) == 2, what="post-abort delivery")
    assert obs.rx_frames[-1]["meta"].generation == gen + 1 and obs.rx_frames[-1]["eofe"] == 0
    assert int(dut.faults.value) == 0


async def _tx_queue(bench: PortBench, big: bytes) -> None:
    dut = bench.dut
    await bench.send(big, 0x801)
    await bench.send(port_frame(84, 64), 0x802)
    await bench.send(port_frame(85, 64), 0x803)

    async def wait_cancel():
        await bench.wait_for(lambda: int(dut.cancelRequest.value) == 1, what="cancelRequest")

    # Half-present the fourth, then terminate it with EOFE on cancel
    await bench.send(big[:64], 0x804, length=len(big), eofe=1, pause_after=1, pause_cycles=0,
                     pause_hook=wait_cancel)


PARAMETER_SWEEP = [
    parameter_case("gmii", PHY_TYPE_G="GMII"),
    parameter_case("xgmii", PHY_TYPE_G="XGMII"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_ptp_mac_port(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ptpmacportethmacwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
