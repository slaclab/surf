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
# - Sweep: A 512-entry FIFO (`FIFO_ADDR_WIDTH_G=9`) in the four MAC
#   configurations that change SsiFifo's structure: common versus independent
#   read clock (`PRIM_COMMON_CLK_G`, 4 ns write / 7 ns read when independent)
#   and `DROP_ERR_PKT_G` true (`VALID_THOLD_G=0`, store-and-forward with the
#   outbound EOFE filter and the PREVENT_LOCKUP monitor) versus false
#   (`VALID_THOLD_G=1`, cut-through).
# - DUT shape: EthMacRxFifoWrapper. The write side has no `TREADY`; overflow,
#   pause and `rxFifoDrop` are observed in the write clock domain.
# - Stimulus: Seeded random frames streamed one beat per write clock with the
#   read side stalled: back-to-back frames until the FIFO overflows mid-frame
#   (held stalled for 16x the PREVENT_LOCKUP timeout), a sequence sized from
#   that capacity so the next SOF is the first refused beat, frames larger
#   than the whole FIFO after a known good-frame history, frames marked EOFE
#   by the MAC, single long frames against several `pauseThresh` values
#   (including 0 and depth-2), and an overflow with `phyReady` low.
# - Checks: Accepted beats are compared exactly (data, keep, SOF, EOFE, last).
#   Frames before an overflow are intact, the overflowed frame is dropped or
#   delivered truncated with EOFE (pinned per configuration), frames refused
#   at SOF never appear, the next frame after the drain is intact, and
#   `rxFifoDrop`/`sAxisOverflow` pulse counts are exact. The pause flag must
#   assert at a constant offset from the programmed threshold. No lockup
#   self-reset may flush stored frames.
# - Timing: Status pulses and accepted beats are sampled on rising edges before
#   the registered `TPD_G` update. Each beat's write-clock sample index is
#   recorded so an overflow pulse identifies the exact dropped beat.
# - Known defect (not asserted): EthMacRxFifo leaves SsiFifo `mAxisDropFrame`
#   and `lockupRstEvent` open, so outbound EOFE drops and lockup resets are not
#   counted in `rxFifoDrop`. Tests check that those frames are dropped but
#   leave the count unasserted.
# - Known issues, gated by `RUN_KNOWN_ISSUE_TESTS=1` (each asserts the
#   correct behaviour and fails on this tree; promote to the default run with
#   its fix):
#   1. `rx_fifo_oversized_frame_history_known_issue_test` (DROP_ERR_PKT_G=true
#      nodes only): a frame larger than the FIFO is dropped whole or delivered
#      truncated depending on a stale last-frame FIFO entry
#      (SsiObFrameFilter.vhd:114/:131 reads `sTLastTUser` without a valid
#      qualifier; AxiStreamFifoV2.vhd:339 starts the read before tLast).
#      Correct: always delivered truncated with an EOFE terminator. Expected
#      failure: 0 frames delivered after an EOFE history.
#   2. `rx_fifo_pause_threshold_clamp_known_issue_test`: `pauseThresh` >=
#      depth-1 never pauses because the write count stops at depth-2
#      (EthMacRxFifo.vhd:170 clamp, FifoWrFsm.vhd:60 almost-full). Correct:
#      pause asserts once the FIFO is full. Expected failure: pause never seen.
# - Not covered: the bypass FIFO (`BYP_EN_G`), read-side reset alone, and
#   repeated-SOF framing errors (covered at the SsiFifo level).

from __future__ import annotations

import os
import random

import cocotb
import pytest
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import (
    cocotb_filtered_env,
    cocotb_test_filter_excluding,
    env_flag,
    env_int,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    sample_after_tpd,
    start_lockstep_clocks,
)
from tests.ethernet.EthMacCore.ethmac_line_models import StatusPulseCounter, describe_case, resolved_int
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    EmacBeat,
    FlatEmacEndpoint,
    cycle,
    frame_beats_from_bytes,
    start_clock,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxFifoWrapper.vhd"
KNOWN_ISSUE_SKIP = os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1"
# Known issue 1 needs the outbound EOFE filter, so cut-through nodes exclude
# it (an exclusion filter never forces a skipped test to run).
DROP_ERR_ONLY_TESTS = ("rx_fifo_oversized_frame_history_known_issue_test",)
KNOWN_ISSUE_TESTS = (
    "rx_fifo_oversized_frame_history_known_issue_test",
    "rx_fifo_pause_threshold_clamp_known_issue_test",
)
SEED = int(os.environ.get("ETHMAC_RX_FIFO_SEED", "20261017"))
# Frame length used for back-to-back fills; chosen so the first overflow of
# every configuration lands mid-frame (asserted below).
FILL_FRAME_BEATS = 37


class AcceptedFrameMonitor:
    """Collect beats accepted on a flattened EMAC master port.

    Samples on the read clock's rising edge before the registered update, so a
    beat is recorded exactly when `TVALID` and `TREADY` are both high.
    """

    def __init__(self, clk, endpoint: FlatEmacEndpoint, ready_signal):
        self.clk = clk
        self.endpoint = endpoint
        self.ready = ready_signal
        self.frames: list[list[EmacBeat]] = []
        self.partial: list[EmacBeat] = []
        self.beats = 0
        self.task = cocotb.start_soon(self._run())

    def clear(self) -> None:
        self.frames = []
        self.partial = []
        self.beats = 0

    async def _run(self) -> None:
        """Lifetime agent: record accepted output beats until the test ends."""
        while True:
            await RisingEdge(self.clk)
            if resolved_int(self.endpoint._sig("TValid")) and resolved_int(self.ready):
                beat = self.endpoint.snapshot()
                self.beats += 1
                self.partial.append(beat)
                if beat.last:
                    self.frames.append(self.partial)
                    self.partial = []


class RxFifoBench:
    def __init__(self, dut):
        self.dut = dut
        self.common = env_flag("PRIM_COMMON_CLK_G", default=False)
        self.drop_err = env_flag("DROP_ERR_PKT_G", default=True)
        self.depth = 2 ** env_int("FIFO_ADDR_WIDTH_G", default=11)
        self.wclk = dut.sClk
        self.rclk = dut.mPrimClk
        # Common-clock builds need truly shared edges; otherwise use a read
        # clock that is not a harmonic of the write clock.
        if self.common:
            self._clock_task = start_lockstep_clocks(dut.sClk, dut.mPrimClk, period_ns=4.0)
        else:
            start_clock(dut.sClk, period_ns=4.0)
            start_clock(dut.mPrimClk, period_ns=7.0)
        dut.sRst.setimmediatevalue(1)
        dut.mPrimRst.setimmediatevalue(1)
        dut.phyReady.setimmediatevalue(1)
        dut.pauseThresh.setimmediatevalue(0xFFFF)
        dut.mAxisTReady.setimmediatevalue(0)
        self.source = FlatEmacEndpoint(dut, prefix="sAxis")
        self.sink = FlatEmacEndpoint(dut, prefix="mAxis")
        self.source.set_idle()
        self.status = StatusPulseCounter(
            dut.sClk,
            {"pause": dut.sAxisPause, "overflow": dut.sAxisOverflow, "drop": dut.rxFifoDrop},
        )
        self.out = AcceptedFrameMonitor(dut.mPrimClk, self.sink, dut.mAxisTReady)
        self.rng = random.Random(SEED)
        self.case = f"common={self.common} drop_err={self.drop_err}"
        dut._log.info(f"RX FIFO flow bench seed={SEED} {self.case} depth={self.depth}")

    async def reset(self, *, pause_thresh: int = 0xFFFF, phy_ready: int = 1) -> None:
        # Hold both domains in reset, check the pause flag reports busy while
        # the FIFO is in reset, then release and clear the Python monitors.
        self.dut.mAxisTReady.value = 0
        self.source.set_idle()
        self.dut.pauseThresh.value = pause_thresh
        self.dut.phyReady.value = phy_ready
        self.dut.sRst.value = 1
        self.dut.mPrimRst.value = 1
        await cycle(self.wclk, 6)
        await cycle(self.rclk, 6)
        await RisingEdge(self.wclk)
        # Baseline: AxiStreamFifoV2 drives pause high while sAxisRst is high.
        assert resolved_int(self.dut.sAxisPause) == 1, "pause must read busy during reset"
        await cycle(self.wclk, 1)
        self.dut.sRst.value = 0
        self.dut.mPrimRst.value = 0
        # Allow the FIFO flags and the PREVENT_LOCKUP settle counter (16 write
        # clocks) to leave their reset values.
        await cycle(self.wclk, 24)
        await cycle(self.rclk, 4)
        self.out.clear()

    def make_frame(self, beats: int, *, eofe: int = 0) -> list[EmacBeat]:
        # A short last beat exercises TKEEP; the length stays within `beats`.
        length = beats * 16 - self.rng.randrange(0, 12)
        data = bytes(self.rng.getrandbits(8) for _ in range(length))
        frame = frame_beats_from_bytes(data, eofe=eofe)
        assert len(frame) == beats
        return frame

    async def stream(self, frames: list[list[EmacBeat]]) -> list[list[int]]:
        """Drive frames back to back, one beat per write clock.

        Returns the write-clock sample index of every beat. The wrapper ties
        `sAxisTReady` high, so every beat is sampled on the next edge.
        """
        sample_cycles = []
        for frame in frames:
            frame_cycles = []
            for beat in frame:
                await sample_after_tpd(self.wclk)
                self.source.drive(beat)
                frame_cycles.append(self.status.cycle + 1)
            sample_cycles.append(frame_cycles)
        await sample_after_tpd(self.wclk)
        self.source.set_idle()
        return sample_cycles

    async def release_and_drain(self, *, expect_frames: int, timeout_cycles: int = 4000, quiet_cycles: int = 64) -> None:
        # Open the read side and wait until the expected frames have arrived
        # and the output has then stayed idle long enough to expose extras.
        # `quiet_cycles=0` returns as soon as the frames have arrived.
        await sample_after_tpd(self.rclk)
        self.dut.mAxisTReady.value = 1
        quiet = 0
        for _ in range(timeout_cycles):
            await RisingEdge(self.rclk)
            if len(self.out.frames) >= expect_frames and (quiet_cycles == 0 or not self.out.partial):
                quiet += 1
                if quiet >= quiet_cycles:
                    return
            else:
                quiet = 0
        raise AssertionError(
            f"{self.case}: expected {expect_frames} frames, got {len(self.out.frames)} "
            f"(+{len(self.out.partial)} partial beats) seed={SEED}"
        )

    def count_between(self, name: str, start: int, end: int | None = None) -> int:
        return sum(1 for c in self.status.cycles[name] if c >= start and (end is None or c <= end))


def assert_frame(observed: list[EmacBeat], expected: list[EmacBeat], context: str) -> None:
    assert len(observed) == len(expected), f"{context}: {len(observed)} beats observed, {len(expected)} expected"
    for index, (obs, exp) in enumerate(zip(observed, expected, strict=True)):
        assert obs == exp, f"{context} beat {index}: observed={obs} expected={exp}"


def beat_index_at_cycle(sample_cycles: list[list[int]], cycle_index: int) -> tuple[int, int, int]:
    """(global beat index, frame index, beat-in-frame) of the beat sampled at `cycle_index`."""
    global_index = 0
    for frame_index, frame_cycles in enumerate(sample_cycles):
        for beat_index, beat_cycle in enumerate(frame_cycles):
            if beat_cycle == cycle_index:
                return global_index, frame_index, beat_index
            global_index += 1
    raise AssertionError(f"no beat was sampled at write cycle {cycle_index}")


async def fill_until_overflow(bench: RxFifoBench, frames: list[list[EmacBeat]]) -> tuple[list[list[int]], int, int, int]:
    """Stream `frames` with the read side stalled; return the first dropped beat.

    `sAxisOverflow` is the registered SsiIbFrameFilter flag, so a pulse seen at
    sample index N reports the beat sampled at N-1.
    """
    start = bench.status.cycle
    sample_cycles = await bench.stream(frames)
    await cycle(bench.wclk, 4)
    overflow_cycles = [c for c in bench.status.cycles["overflow"] if c > start]
    assert overflow_cycles, f"{bench.case}: FIFO never overflowed seed={SEED}"
    first_dropped, frame_index, beat_in_frame = beat_index_at_cycle(sample_cycles, overflow_cycles[0] - 1)
    return sample_cycles, first_dropped, frame_index, beat_in_frame


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def rx_fifo_inbound_overflow_test(dut):
    bench = RxFifoBench(dut)

    # Phase A, mid-frame overflow: back-to-back frames with the read side
    # stalled until the FIFO overflows inside a frame. The remaining frames
    # arrive while SsiIbFrameFilter waits for space to insert the EOFE
    # terminator (INSERT_EOFE_S), so they are dropped whole.
    await bench.reset(pause_thresh=0x40)
    stall_start = bench.status.cycle
    frame_count = (bench.depth + 64) // FILL_FRAME_BEATS + 3
    frames = [bench.make_frame(FILL_FRAME_BEATS) for _ in range(frame_count)]
    _, capacity, k, stored = await fill_until_overflow(bench, frames)
    total_beats = frame_count * FILL_FRAME_BEATS
    dut._log.info(f"{bench.case}: first dropped beat {capacity} (frame {k} beat {stored})")
    assert stored > 0, f"{bench.case}: overflow landed on an SOF; change FILL_FRAME_BEATS"
    assert frame_count - k >= 3, "the fill must leave at least two whole frames to drop"

    # PREVENT_LOCKUP guard: hold the saturated FIFO stalled for 16x the
    # 16-cycle lockup timeout. A self-reset would flush the stored frames, so
    # the intact delivery below proves it did not fire. It cannot: writes stop
    # at almost-full (count depth-2), so SsiFifo's `fifoFull` (count depth-1)
    # never asserts, and almost-full forces `fifoInFrame` so the FIFO output
    # stays valid.
    await cycle(bench.wclk, 256)

    # Inbound accounting: every dropped beat pulses overflow, and each frame
    # that lost beats (the truncated one and every later one) pulses
    # `rxFifoDrop` exactly once, on its last beat.
    assert bench.count_between("overflow", stall_start) == total_beats - capacity, bench.case
    assert bench.count_between("drop", stall_start) == frame_count - k, bench.case

    # Drain: frames written before the overflow arrive intact.
    expected_frames = k + (0 if bench.drop_err else 1)
    await bench.release_and_drain(expect_frames=expected_frames)
    observed = bench.out.frames
    assert len(observed) == expected_frames, f"{bench.case}: {len(observed)} frames delivered"
    for index in range(k):
        assert_frame(observed[index], frames[index], f"{bench.case} {describe_case(SEED, index, 'pre-overflow')}")
    if not bench.drop_err:
        # Cut-through: the truncated frame is delivered with its stored beats
        # and one terminator beat carrying EOFE. The terminator repeats the
        # previous beat's data, which carries no meaning and is not asserted.
        truncated = observed[k]
        context = f"{bench.case} {describe_case(SEED, k, 'truncated')}"
        assert len(truncated) == stored + 1, f"{context}: {len(truncated)} beats"
        assert_frame(truncated[:stored], frames[k][:stored], context)
        terminator = truncated[-1]
        assert (terminator.last, terminator.eofe, terminator.sof) == (1, 1, 0), f"{context}: terminator={terminator}"
    # With DROP_ERR_PKT_G the truncated frame is removed by the outbound EOFE
    # filter. That outbound drop is not counted (known defect), so the drop
    # count above holds only the inbound pulses.

    # Phase B, overflow at SOF: frames whose total length equals the capacity
    # found above, so the last stored beat ends a frame and the probe frame's
    # SOF is the first beat that cannot be stored.
    await bench.reset(pause_thresh=0x40)
    stall_start = bench.status.cycle
    full, remainder = divmod(capacity, FILL_FRAME_BEATS)
    frames = [bench.make_frame(FILL_FRAME_BEATS) for _ in range(full)]
    if remainder:
        frames.append(bench.make_frame(remainder))
    probe = bench.make_frame(5)
    _, first_dropped, probe_index, beat_in_frame = await fill_until_overflow(bench, frames + [probe])
    assert (first_dropped, probe_index, beat_in_frame) == (capacity, len(frames), 0), (
        f"{bench.case}: overflow at beat {first_dropped} (frame {probe_index} beat {beat_in_frame}), "
        f"expected the probe SOF at beat {capacity}"
    )
    await cycle(bench.wclk, 16)

    # A frame refused at SOF is discarded whole in every configuration: one
    # drop pulse, one overflow pulse per probe beat, nothing delivered.
    assert bench.count_between("drop", stall_start) == 1, bench.case
    assert bench.count_between("overflow", stall_start) == len(probe), bench.case
    await bench.release_and_drain(expect_frames=len(frames))
    assert len(bench.out.frames) == len(frames), f"{bench.case}: probe frame leaked"
    for index, frame in enumerate(frames):
        assert_frame(bench.out.frames[index], frame, f"{bench.case} {describe_case(SEED, index, 'before SOF overflow')}")

    # Recovery: a frame sent after the FIFO drains passes intact and is not
    # counted.
    bench.out.clear()
    recovery_start = bench.status.cycle
    recovery = bench.make_frame(9)
    await bench.stream([recovery])
    await bench.release_and_drain(expect_frames=1)
    assert_frame(bench.out.frames[0], recovery, f"{bench.case} recovery frame")
    assert bench.count_between("drop", recovery_start) == 0
    assert bench.count_between("overflow", recovery_start) == 0


async def oversized_frame_run(bench: RxFifoBench, *, history_eofe: int, thresh: int):
    """Stream one frame longer than the FIFO after a known history.

    After a reset the last-frame FIFO reads slot 0, which reset does not
    clear. One short frame (good or EOFE) is written first so the stale entry
    the oversized frame sees is known. Returns the frame, the stored beat
    count, whether pause was seen, and a failure context.
    """
    await bench.reset()
    bench.dut.mAxisTReady.value = 1
    await bench.stream([bench.make_frame(2, eofe=history_eofe)])
    await cycle(bench.rclk, 32)

    # One frame longer than the whole FIFO, with the read side stalled.
    await bench.reset(pause_thresh=thresh)
    start = bench.status.cycle
    giant = bench.make_frame(bench.depth + 48)
    _, first_dropped, _, stored = await fill_until_overflow(bench, [giant])
    await cycle(bench.wclk, 16)
    context = f"{bench.case} oversized history_eofe={history_eofe} thresh={thresh:#x} seed={SEED}"
    paused = bench.count_between("pause", start + 1) > 0

    overflow = bench.count_between("overflow", start)
    if bench.drop_err:
        # Almost-full forces the FIFO to start reading the incomplete frame,
        # which frees a few entries, so the filter inserts the EOFE terminator
        # and blows off the tail without further overflow pulses
        # (SsiIbFrameFilter BLOWOFF_S).
        assert 1 <= overflow < len(giant) - first_dropped, f"{context}: overflow pulses={overflow}"
    else:
        # Cut-through already moved the frame head downstream, so no space
        # frees during the stall and every dropped beat pulses overflow.
        assert overflow == len(giant) - first_dropped, f"{context}: overflow pulses={overflow}"
    assert bench.count_between("drop", start) == 1, context
    return giant, stored, paused, context


async def expect_truncated_delivery(bench: RxFifoBench, giant, stored: int, context: str) -> None:
    # The oversized frame arrives as its stored beats plus one EOFE
    # terminator; anything else (nothing, or more frames) fails.
    try:
        await bench.release_and_drain(expect_frames=1, timeout_cycles=2000)
    except AssertionError as error:
        raise AssertionError(f"{context}: oversized frame not delivered ({error})") from None
    assert len(bench.out.frames) == 1, f"{context}: {len(bench.out.frames)} frames delivered"
    truncated = bench.out.frames[0]
    assert len(truncated) == stored + 1, f"{context}: {len(truncated)} beats, {stored} stored"
    assert_frame(truncated[:stored], giant[:stored], context)
    assert (truncated[-1].last, truncated[-1].eofe) == (1, 1), f"{context}: terminator={truncated[-1]}"


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def rx_fifo_oversized_frame_test(dut):
    bench = RxFifoBench(dut)

    # After a good-frame history the oversized frame is delivered truncated
    # with an EOFE terminator in both modes. The write count tops out at
    # depth-2 (writes stop at almost-full), so a depth-2 threshold pauses.
    # The EOFE-history case is known issue 1 and the >= depth-1 threshold is
    # known issue 2; neither is asserted here.
    giant, stored, paused, context = await oversized_frame_run(bench, history_eofe=0, thresh=bench.depth - 2)
    assert paused, f"{context}: pause never seen with the FIFO saturated"
    await expect_truncated_delivery(bench, giant, stored, context)


@cocotb.test(skip=KNOWN_ISSUE_SKIP, timeout_time=2, timeout_unit="ms")
async def rx_fifo_oversized_frame_history_known_issue_test(dut):
    # Known issue 1 (DROP_ERR_PKT_G=true only). Correct behaviour: the outcome
    # for an oversized frame does not depend on earlier traffic; it is
    # delivered truncated with an EOFE terminator. On this tree the head is
    # read before the frame's tLast is written (AxiStreamFifoV2 forces
    # `fifoInFrame` at almost-full) and SsiObFrameFilter takes its EOFE
    # look-ahead from the empty last-frame FIFO's stale output, so after an
    # EOFE history the whole frame is dropped. Expected failure: "0 frames
    # delivered" for history_eofe=1.
    bench = RxFifoBench(dut)
    for history_eofe in (0, 1):
        giant, stored, _, context = await oversized_frame_run(bench, history_eofe=history_eofe, thresh=0xFFFF)
        await expect_truncated_delivery(bench, giant, stored, context)


@cocotb.test(skip=KNOWN_ISSUE_SKIP, timeout_time=2, timeout_unit="ms")
async def rx_fifo_pause_threshold_clamp_known_issue_test(dut):
    # Known issue 2. Correct behaviour: a `pauseThresh` at or above the clamp
    # (EthMacRxFifo clamps any value >= depth-1 to depth-1) still pauses once
    # the FIFO is full. On this tree the write count never exceeds depth-2
    # because writes stop at almost-full, so depth-1 is unreachable and the
    # pause flag never asserts while the FIFO overflows; with
    # FIFO_ADDR_WIDTH_G=9 this includes the default `pauseThresh` (562).
    # Expected failure: "pause never seen" for every threshold.
    bench = RxFifoBench(dut)
    missing = []
    for thresh in (bench.depth - 1, 562, 0xFFFF):
        _, _, paused, context = await oversized_frame_run(bench, history_eofe=0, thresh=thresh)
        if not paused:
            missing.append(thresh)
        await bench.release_and_drain(expect_frames=1, timeout_cycles=2000)
    assert not missing, f"{bench.case}: pause never seen with the FIFO saturated for pauseThresh {[hex(t) for t in missing]}"


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def rx_fifo_outbound_eofe_test(dut):
    bench = RxFifoBench(dut)
    await bench.reset(pause_thresh=0xFFFF)
    start = bench.status.cycle

    # Mix good frames with frames the MAC marked EOFE (CRC error), including a
    # single-beat EOFE frame, and drain with the read side always ready.
    plan = [0, 1, 0, 0, 1, 1, 0, 1, 0]
    lengths = [4, 6, 1, 5, 1, 7, 4, 3, 2]
    frames = [bench.make_frame(n, eofe=e) for n, e in zip(lengths, plan, strict=True)]
    bench.dut.mAxisTReady.value = 1
    await bench.stream(frames)
    expected = [f for f, e in zip(frames, plan, strict=True) if not (bench.drop_err and e)]
    await bench.release_and_drain(expect_frames=len(expected))
    assert len(bench.out.frames) == len(expected), f"{bench.case}: {len(bench.out.frames)} frames delivered"
    for index, (obs, exp) in enumerate(zip(bench.out.frames, expected, strict=True)):
        # DROP_ERR_PKT_G=false delivers EOFE frames unchanged, flag included.
        assert_frame(obs, exp, f"{bench.case} {describe_case(SEED, index, 'eofe mix')}")

    # Nothing overflowed. A delivered EOFE frame is not a FIFO drop. With
    # DROP_ERR_PKT_G=true the outbound EOFE drops are not counted because of
    # the known open `mAxisDropFrame` defect, so the count stays unasserted.
    assert bench.count_between("overflow", start) == 0
    if not bench.drop_err:
        assert bench.count_between("drop", start) == 0


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def rx_fifo_pause_threshold_test(dut):
    bench = RxFifoBench(dut)

    # Baseline: `pauseThresh=0` holds pause high with an empty FIFO because
    # AxiStreamFifoV2 compares `fifoWrCount >= fifoPauseThresh`.
    await bench.reset(pause_thresh=0)
    start = bench.status.cycle
    await cycle(bench.wclk, 32)
    assert bench.count_between("pause", start + 1) == bench.status.cycle - start

    offsets = {}
    for thresh in (8, 100, 300):
        # One long frame streams into the stalled FIFO; record how many beats
        # had been sampled when the pause flag was first seen high.
        await bench.reset(pause_thresh=thresh)
        start = bench.status.cycle
        frame = bench.make_frame(thresh + 48)
        sample_cycles = await bench.stream([frame])
        pause_cycles = [c for c in bench.status.cycles["pause"] if c > start]
        assert pause_cycles, f"{bench.case}: pause never asserted for thresh={thresh}"
        offsets[thresh] = sum(1 for c in sample_cycles[0] if c <= pause_cycles[0]) - thresh
        assert bench.count_between("overflow", start) == 0

        # Pause stays high while the occupancy is above the threshold, then
        # clears once the read side drains the frame intact.
        await RisingEdge(bench.wclk)
        assert resolved_int(dut.sAxisPause) == 1
        await bench.release_and_drain(expect_frames=1, quiet_cycles=16)
        assert_frame(bench.out.frames[0], frame, f"{bench.case} thresh={thresh}")
        await RisingEdge(bench.wclk)
        assert resolved_int(dut.sAxisPause) == 0, f"pause stuck after drain thresh={thresh}"

    # The flag compares the registered write count with the threshold, so the
    # beats-in-flight offset must not depend on the threshold. The offset is
    # the pipeline latency plus any words already moved past the counted FIFO
    # (larger in cut-through and independent-clock builds).
    dut._log.info(f"{bench.case}: pause offsets beyond threshold {offsets}")
    assert len(set(offsets.values())) == 1, f"{bench.case}: offsets differ {offsets}"
    assert 0 <= next(iter(offsets.values())) <= 48, f"{bench.case}: offsets {offsets}"


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def rx_fifo_phy_ready_test(dut):
    bench = RxFifoBench(dut)

    # Overflow the FIFO while `phyReady` is low.
    await bench.reset(pause_thresh=0x10, phy_ready=0)
    start = bench.status.cycle
    frame_count = (bench.depth + 64) // FILL_FRAME_BEATS + 3
    frames = [bench.make_frame(FILL_FRAME_BEATS) for _ in range(frame_count)]
    _, _, k, _ = await fill_until_overflow(bench, frames)
    await cycle(bench.wclk, 16)
    low_end = bench.status.cycle

    # Baseline (EthMacRxFifo comb reset on `phyReady='0'`): the register that
    # holds the pause threshold and the drop strobe is held at its reset value,
    # so the programmed threshold is ignored (forced to depth-1) and drops are
    # not counted, although the data path keeps storing and dropping frames.
    # Pause is checked only until shortly before the FIFO fills: whether a
    # depth-1 threshold pauses a full FIFO is known issue 2.
    filled = min(c for c in bench.status.cycles["overflow"] if c > start) - 16
    assert bench.count_between("pause", start + 1, filled) == 0, bench.case
    assert bench.count_between("drop", start + 1, low_end) == 0, bench.case
    assert bench.count_between("overflow", start + 1, low_end) > 0, bench.case

    # Raising `phyReady` with the FIFO still full re-applies the threshold and
    # re-enables drop counting for the next refused frame.
    await sample_after_tpd(bench.wclk)
    dut.phyReady.value = 1
    await cycle(bench.wclk, 4)
    await RisingEdge(bench.wclk)
    assert resolved_int(dut.sAxisPause) == 1, bench.case
    high_start = bench.status.cycle
    await bench.stream([bench.make_frame(3)])
    await cycle(bench.wclk, 8)
    assert bench.count_between("drop", high_start) == 1, bench.case

    # The data path was never reset: the frames stored while `phyReady` was low
    # are still delivered. The first three are enough to prove it; the next
    # test's reset discards the rest.
    await bench.release_and_drain(expect_frames=3, quiet_cycles=0)
    for index in range(3):
        assert_frame(bench.out.frames[index], frames[index], f"{bench.case} {describe_case(SEED, index, 'phyReady low')}")
    assert k > 3, bench.case


PARAMETER_SWEEP = [
    parameter_case("common_drop_err", PRIM_COMMON_CLK_G="true", DROP_ERR_PKT_G="true", FIFO_ADDR_WIDTH_G="9"),
    parameter_case("common_keep_err", PRIM_COMMON_CLK_G="true", DROP_ERR_PKT_G="false", FIFO_ADDR_WIDTH_G="9"),
    parameter_case("async_drop_err", PRIM_COMMON_CLK_G="false", DROP_ERR_PKT_G="true", FIFO_ADDR_WIDTH_G="9"),
    parameter_case("async_keep_err", PRIM_COMMON_CLK_G="false", DROP_ERR_PKT_G="false", FIFO_ADDR_WIDTH_G="9"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacRxFifoFlow(parameters):
    # cocotb 2.1 runs a skipped entrypoint whenever COCOTB_TEST_FILTER matches
    # it, so any filter must exclude the known-issue tests unless the gate is
    # set, and cut-through nodes always exclude the DROP_ERR_PKT_G-only one.
    excluded = KNOWN_ISSUE_TESTS if KNOWN_ISSUE_SKIP else ()
    if parameters["DROP_ERR_PKT_G"] == "false":
        excluded = tuple(dict.fromkeys(excluded + DROP_ERR_ONLY_TESTS))
    extra_env = dict(parameters)
    if excluded:
        extra_env = cocotb_filtered_env(extra_env, cocotb_test_filter_excluding(*excluded))
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxfifowrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=extra_env,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
