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
# - Sweep: One XGMII EthMacTop build through EthMacTopPhyWrapper with the
#   10G quantum (`PAUSE_512BITS_G=8`), a 512-entry RX FIFO, common primary
#   clock, `DROP_ERR_PKT_G` and the RX filter instantiated (`FILT_EN_G`, with
#   `filtEnable=0` so only `dropOnPause` can drop). The stage-level pause
#   arithmetic is in test_EthMacTxPauseTiming; this file checks that the
#   pause paths are wired end to end through the PHY pins.
# - Stimulus: IEEE 802.3 pause frames (good and bad FCS) on the XGMII receive
#   pins followed by one queued primary TX frame; received traffic with the
#   primary sink stalled until the RX FIFO pause starts local pause frames;
#   and frames that arrive while that pause is asserted with `dropOnPause`.
# - Checks: TX start on the XGMII transmit pins moves by exactly
#   `delta(value) * 8` cycles between pause values; a bad-FCS pause frame does
#   not hold TX; pause frames are consumed (never delivered); `rxPauseCnt`
#   pulses once per good pause frame; generated pause frames carry
#   `pauseTime` with a good FCS, repeat every `(pauseTime >> 1) * 8 + 5`
#   cycles, match `txPauseCnt` one for one and stop once the FIFO drains;
#   frames received while paused with `dropOnPause` are discarded.
# - Timing: Status pulses and the transmit monitor count the same ethClk
#   edges from the same timestep, so pulse-to-start delays are exact cycles.
#   Stimulus is always driven after the sampled edge (`sample_after_tpd`).
# - Baseline: frames discarded by `dropOnPause` are not counted in
#   `rxFifoDropCnt` (EthMacRxFilter has no status output).
# - Known issue (`RUN_KNOWN_ISSUE_TESTS=1`; promote to the default run with its
#   fix): 14. `top_no_pause_frame_after_reset_known_issue_test` asserts that no
#   pause frame leaves after reset with an empty RX FIFO. On this tree the RX
#   FIFO pause flag reads busy in reset (AxiStreamFifoV2.vhd:217, write count
#   reset to all ones at FifoWrFsm.vhd:83), FlowCtrl forwards it as
#   `clientPause` (EthMacTop.vhd:192) and EthMacTxPause sends one pause frame.
#   Expected failure: one pause frame and one `txPauseCnt` pulse after reset.
#   The default benches tolerate that frame without requiring it.

from __future__ import annotations

import os
import random

import cocotb
import pytest
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import (
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    sample_after_tpd,
    start_lockstep_clocks,
)
from tests.ethernet.EthMacCore.ethmac_line_models import (
    StatusPulseCounter,
    XgmiiDriver,
    XgmiiMonitor,
    random_frame,
    resolved_int,
    xgmii_words,
)
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    build_pause_frame,
    cycle,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
    payload_from_beats,
    send_contiguous_frame,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTopPhyWrapper.vhd"
KNOWN_ISSUE_SKIP = os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1"
SEED = int(os.environ.get("ETHMAC_TOP_PAUSE_SEED", "802"))
QUANTUM = 8
PAUSE_FRAME_CYCLES = 5
LOCAL_MAC = 0x020000000010


class OutputFrameLog:
    """Record frames accepted on the primary outbound stream."""

    def __init__(self, clk, endpoint: FlatEmacEndpoint, ready_signal):
        self.clk = clk
        self.endpoint = endpoint
        self.ready = ready_signal
        self.frames: list[bytes] = []
        self._beats = []
        self.task = cocotb.start_soon(self._run())

    async def _run(self) -> None:
        """Lifetime agent: record accepted primary output frames until the test ends."""
        while True:
            await RisingEdge(self.clk)
            if resolved_int(self.endpoint._sig("TValid")) and resolved_int(self.ready):
                self._beats.append(self.endpoint.snapshot())
                if self._beats[-1].last:
                    self.frames.append(payload_from_beats(self._beats))
                    self._beats = []


class TopPauseBench:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.ethClk
        self.rng = random.Random(SEED)

    async def start(self, *, pause_time: int, pause_thresh: int, drop_on_pause: int = 0) -> None:
        dut = self.dut
        self._clock_task = start_lockstep_clocks(dut.ethClk, dut.primClk, period_ns=6.4)
        self.source = FlatEmacEndpoint(dut, prefix="sAxis")
        self.sink = FlatEmacEndpoint(dut, prefix="mAxis")
        self.source.set_idle()
        for name, value in {
            "ethRst": 1,
            "primRst": 1,
            "phyReady": 1,
            "mAxisTReady": 1,
            "localMac": mac_config_word_from_wire(LOCAL_MAC),
            "filtEnable": 0,
            "pauseEnable": 1,
            "pauseTime": pause_time,
            "pauseThresh": pause_thresh,
            "ipCsumEn": 0,
            "tcpCsumEn": 0,
            "udpCsumEn": 0,
            "dropOnPause": drop_on_pause,
        }.items():
            getattr(dut, name).setimmediatevalue(value)
        self.rx = XgmiiDriver(dut, clk=self.clk)
        self.rx.idle()
        # The monitor, status counter and output log are created in the same
        # timestep so their cycle indexes agree.
        self.tx = XgmiiMonitor(dut, clk=self.clk)
        self.status = StatusPulseCounter(
            self.clk,
            {
                "rxPause": dut.rxPauseCnt,
                "txPause": dut.txPauseCnt,
                "rxFifoDrop": dut.rxFifoDropCnt,
                "rxCount": dut.rxCountEn,
            },
        )
        self.out = OutputFrameLog(dut.primClk, self.sink, dut.mAxisTReady)
        await cycle(self.clk, 8)
        dut.ethRst.value = 0
        dut.primRst.value = 0
        await cycle(self.clk, 40)

        # Known issue 14 sends one pause frame right after reset. Tolerate it
        # (anything else is a failure) and let its retransmit hold expire
        # before the scenario starts.
        self.reset_frames = [f.frame for f in self.tx.frames]
        self.reset_pause_pulses = len(self.status.cycles["txPause"])
        assert self.reset_frames in ([], [build_pause_frame(pause_time)]), f"{len(self.reset_frames)} frames after reset"
        assert self.reset_pause_pulses == len(self.reset_frames)
        await cycle(self.clk, (pause_time >> 1) * QUANTUM + 16)

    def pulses_after(self, name: str, start: int) -> list[int]:
        return [c for c in self.status.cycles[name] if c > start]

    async def wait_pulse(self, name: str, start: int, timeout_cycles: int) -> int:
        for _ in range(timeout_cycles):
            pulses = self.pulses_after(name, start)
            if pulses:
                return pulses[0]
            await sample_after_tpd(self.clk)
        raise AssertionError(f"no {name} pulse within {timeout_cycles} cycles")

    async def wait_tx_frames(self, count: int, timeout_cycles: int) -> None:
        for _ in range(timeout_cycles):
            if len(self.tx.frames) >= count:
                return
            await sample_after_tpd(self.clk)
        raise AssertionError(f"expected {count} transmitted frames, saw {len(self.tx.frames)}")

    async def queue_tx_frame(self, tag: int) -> bytes:
        frame = random_frame(self.rng, 80, dst_mac=0x020000000020, src_mac=LOCAL_MAC)
        frame = frame[:14] + bytes([tag]) + frame[15:]
        await send_contiguous_frame(self.source, frame_beats_from_bytes(frame), clk=self.dut.primClk)
        return frame

    async def fill_rx_fifo(self, frames: list[bytes], *, gap_cycles: int) -> None:
        """Receive frames with the primary sink stalled.

        The occupancy compared with `pauseThresh` excludes words already moved
        into the RX FIFO output pipeline, so a single short frame only raises
        pause while it is being written. Four 100-byte frames hold it.
        """
        for frame in frames:
            await self.rx.send(xgmii_words(frame))
            await cycle(self.clk, gap_cycles)


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def top_rx_pause_holds_tx_test(dut):
    tb = TopPauseBench(dut)
    await tb.start(pause_time=0x0020, pause_thresh=0xFFFF)
    delays = {}

    for value in (0x10, 0x20, 0x30):
        # A received pause frame pulses `rxPauseCnt`; one TX frame queued on
        # that pulse waits for the hold before it reaches the XGMII pins.
        start = tb.status.cycle
        await tb.rx.send(xgmii_words(build_pause_frame(value)))
        pulse = await tb.wait_pulse("rxPause", start, timeout_cycles=64)
        frames_before = len(tb.tx.frames)
        frame = await tb.queue_tx_frame(value & 0xFF)
        await tb.wait_tx_frames(frames_before + 1, timeout_cycles=value * QUANTUM + 200)
        sent = tb.tx.frames[-1]
        assert sent.frame == frame and sent.fcs_ok, f"pause value={value:#x}: TX frame corrupted"
        delays[value] = sent.start_cycle - pulse
        assert len(tb.pulses_after("rxPause", start)) == 1, f"value={value:#x}: rxPauseCnt pulses"
        await cycle(tb.clk, 16)

    # The fixed path latency cancels between values; the hold difference is
    # exactly the pause-value difference in 8-cycle quanta.
    dut._log.info(f"rxPauseCnt-to-XGMII-start delays {delays}")
    values = sorted(delays)
    assert delays[values[0]] >= values[0] * QUANTUM
    for low, high in zip(values, values[1:]):
        assert delays[high] - delays[low] == (high - low) * QUANTUM, f"delays {delays}"

    # A pause frame with a bad FCS is marked EOFE by the receive path, so it
    # neither pulses `rxPauseCnt` nor holds TX.
    start = tb.status.cycle
    await tb.rx.send(xgmii_words(build_pause_frame(0x100), bad_fcs=True))
    await cycle(tb.clk, 32)
    assert not tb.pulses_after("rxPause", start), "bad-FCS pause frame accepted"
    frames_before = len(tb.tx.frames)
    queued = tb.status.cycle
    frame = await tb.queue_tx_frame(0xEE)
    await tb.wait_tx_frames(frames_before + 1, timeout_cycles=200)
    assert tb.tx.frames[-1].frame == frame
    assert tb.tx.frames[-1].start_cycle - queued < delays[values[0]], "TX held by a bad pause frame"

    # Pause frames are consumed by the receive path, never delivered.
    assert not tb.out.frames, f"{len(tb.out.frames)} pause frames delivered"
    assert not tb.pulses_after("rxFifoDrop", 0)


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def top_local_pause_generation_test(dut):
    pause_time = 0x0020
    interval = (pause_time >> 1) * QUANTUM + PAUSE_FRAME_CYCLES
    tb = TopPauseBench(dut)
    await tb.start(pause_time=pause_time, pause_thresh=4)

    # With the primary sink stalled, received frames fill the RX FIFO until
    # its pause flag starts local pause generation.
    await sample_after_tpd(dut.primClk)
    dut.mAxisTReady.value = 0
    received = [random_frame(tb.rng, 100, dst_mac=LOCAL_MAC) for _ in range(4)]
    fill_start = tb.status.cycle
    await tb.fill_rx_fifo(received, gap_cycles=30)
    start = tb.status.cycle
    first_tx = len(tb.tx.frames)
    await tb.wait_tx_frames(first_tx + 4, timeout_cycles=5 * interval + 64)

    # Every generated frame is a pause frame advertising `pauseTime` with a
    # good FCS, each pulses `txPauseCnt` once, and they repeat after half the
    # advertised time.
    pause_frames = tb.tx.frames[first_tx:]
    for index, sent in enumerate(pause_frames):
        assert sent.fcs_ok and sent.preamble_ok, f"pause frame {index} bad framing"
        assert sent.frame == build_pause_frame(pause_time), f"pause frame {index} payload"
    starts = [f.start_cycle for f in pause_frames]
    assert all(b - a == interval for a, b in zip(starts, starts[1:])), f"pause frame starts {starts}, expected interval {interval}"
    tx_pulses = tb.pulses_after("txPause", start)
    assert all(b - a == interval for a, b in zip(tx_pulses, tx_pulses[1:])), f"txPauseCnt cycles {tx_pulses}"

    # Releasing the sink drains the FIFO below the threshold; generation stops
    # and every received frame is delivered intact.
    await sample_after_tpd(dut.primClk)
    dut.mAxisTReady.value = 1
    for _ in range(200):
        if len(tb.out.frames) >= len(received):
            break
        await sample_after_tpd(tb.clk)
    released = tb.status.cycle
    await cycle(tb.clk, 2 * interval)
    assert tb.out.frames == received
    late = [f for f in tb.tx.frames if f.start_cycle > released + interval]
    assert not late, f"{len(late)} pause frames after the FIFO drained"
    total = [f for f in tb.tx.frames if f.start_cycle > fill_start]
    assert len(tb.pulses_after("txPause", fill_start)) == len(total), "txPauseCnt does not match frames on the wire"
    assert not tb.pulses_after("rxFifoDrop", 0)


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def top_drop_on_pause_test(dut):
    tb = TopPauseBench(dut)
    # A short pause time regenerates pause frames quickly, so the first
    # `txPauseCnt` pulse marks the moment the RX FIFO pause asserted.
    await tb.start(pause_time=0x0002, pause_thresh=4, drop_on_pause=0)

    # Fill the RX FIFO with the sink stalled until it holds pause, then set
    # `dropOnPause`: the next two frames arrive while pause is asserted and
    # are discarded by the filter. Pause frames every 13 cycles before and
    # after them show the pause was held throughout. (Setting `dropOnPause`
    # only after the fill keeps the fill frames out of the transient pause
    # raised while each frame is written.)
    regen = (0x0002 >> 1) * QUANTUM + PAUSE_FRAME_CYCLES
    await sample_after_tpd(dut.primClk)
    dut.mAxisTReady.value = 0
    stored = [random_frame(tb.rng, 100, dst_mac=LOCAL_MAC) for _ in range(4)]
    start = tb.status.cycle
    await tb.fill_rx_fifo(stored, gap_cycles=16)
    discard_start = tb.status.cycle
    assert tb.pulses_after("txPause", discard_start - regen), "RX FIFO pause not held after the fill"
    await sample_after_tpd(tb.clk)
    dut.dropOnPause.value = 1
    discarded = [random_frame(tb.rng, 100, dst_mac=LOCAL_MAC) for _ in range(2)]
    await tb.fill_rx_fifo(discarded, gap_cycles=0)
    pulses = tb.pulses_after("txPause", discard_start - regen)
    assert all(b - a == regen for a, b in zip(pulses, pulses[1:])) and tb.status.cycle - pulses[-1] <= regen, (
        f"pause dropped while the discarded frames arrived: {pulses}"
    )

    # Release: only the frames received before the pause were stored. Once
    # pause clears, a later frame passes again.
    await sample_after_tpd(dut.primClk)
    dut.mAxisTReady.value = 1
    await cycle(tb.clk, 64)
    after = random_frame(tb.rng, 100, dst_mac=LOCAL_MAC)
    await tb.rx.send(xgmii_words(after))
    await cycle(tb.clk, 64)
    assert tb.out.frames == stored + [after], f"{len(tb.out.frames)} frames delivered, {len(stored) + 1} expected"

    # Every frame was received without error; the ones discarded by
    # `dropOnPause` are not counted as RX FIFO drops (baseline).
    assert len(tb.pulses_after("rxCount", start)) == len(stored) + len(discarded) + 1
    assert not tb.pulses_after("rxFifoDrop", start)


@cocotb.test(skip=KNOWN_ISSUE_SKIP, timeout_time=2, timeout_unit="ms")
async def top_no_pause_frame_after_reset_known_issue_test(dut):
    # Known issue 14: with an empty RX FIFO and no traffic, reset must not
    # produce a pause frame on the wire or a `txPauseCnt` pulse.
    tb = TopPauseBench(dut)
    await tb.start(pause_time=0x0020, pause_thresh=4)
    assert not tb.reset_frames and not tb.reset_pause_pulses, (
        f"{len(tb.reset_frames)} pause frame(s) and {tb.reset_pause_pulses} txPauseCnt pulse(s) after reset with an empty RX FIFO"
    )


PARAMETER_SWEEP = [
    parameter_case(
        "xgmii_10g_quanta",
        PHY_TYPE_G="XGMII",
        PAUSE_512BITS_G="8",
        FIFO_ADDR_WIDTH_G="9",
        PRIM_COMMON_CLK_G="true",
        DROP_ERR_PKT_G="true",
        FILT_EN_G="true",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTopPause(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactopphywrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
