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
# - Sweep: `PAUSE_512BITS_G` of 8 and 64 (powers of two, the 10G and 1G
#   quanta) run every default entrypoint. The 1 and 5 nodes exist only for
#   known issue 15 and are skipped unless `RUN_KNOWN_ISSUE_TESTS=1`.
# - DUT shape: EthMacTxPauseWrapper with the sink always ready, so every hold
#   is visible as the cycle at which the stage next accepts a client beat.
# - Stimulus: one-cycle `rxPauseReq` pulses with pause values 0, 1, 2, 7 and
#   0x100 ahead of a waiting frame; a request in the middle of a frame; pause
#   refresh, XON (value 0) and `pauseEnable` toggles during a hold; and
#   `clientPause` held high (with data traffic, mid-frame, with `phyReady` low
#   and with a pause time below two quanta) to drive local pause generation.
# - Checks: the hold equals `value * PAUSE_512BITS_G` write cycles beyond the
#   zero-value latency; the in-flight frame finishes without a gap; refresh and XON replace
#   the timer; generated pause frames are byte-exact (pause time big-endian);
#   regeneration happens every `(pauseTime >> 1) * PAUSE_512BITS_G + 5` cycles
#   and each frame pulses `pauseTx` once.
# - Timing: request, enable, acceptance (`sAxisTReady`) and `pauseTx` are
#   sampled on rising edges before the registered `TPD_G` update, so every
#   delay is an exact clock count.
# - Baselines: generated pause frames use an all-zero source MAC. A pause
#   time below two quanta regenerates continuously and starves client traffic.
# - Known issue (`RUN_KNOWN_ISSUE_TESTS=1`; promote to the default run with its
#   fix): 15. `tx_pause_quantum_length_known_issue_test` on the `quanta_1clk`
#   and `quanta_5clk` nodes asserts a hold of `value * PAUSE_512BITS_G`. The
#   pre-counter is `bitSize(PAUSE_512BITS_G-1)` bits wide
#   (EthMacTxPause.vhd:59), so a quantum is the next power of two at or above
#   the setting and 2 clocks for a setting of 1. Expected failure: value 1
#   holds 2 cycles instead of 1, and 8 instead of 5.

from __future__ import annotations

import os
import random

import cocotb
import pytest
from cocotb.triggers import RisingEdge

from tests.axi.utils import wait_sampled_ready
from tests.common.regression_utils import (
    cocotb_filtered_env,
    cocotb_test_filter,
    cocotb_test_filter_excluding,
    env_int,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    sample_after_tpd,
)
from tests.ethernet.EthMacCore.ethmac_line_models import StatusPulseCounter, resolved_int
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    EmacBeat,
    FlatEmacEndpoint,
    build_ethernet_frame,
    build_pause_frame,
    cycle,
    frame_beats_from_bytes,
    payload_from_beats,
    setup_flat_emac_testbench,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTxPauseWrapper.vhd"
KNOWN_ISSUE_SKIP = os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1"
QUANTUM_KNOWN_ISSUE_TEST = "tx_pause_quantum_length_known_issue_test"
SEED = int(os.environ.get("ETHMAC_TX_PAUSE_SEED", "512"))
# Delay from a sampled `rxPauseReq` to acceptance of a waiting first beat when
# the pause value is zero: one edge to enter PASS_S, one to accept.
ZERO_HOLD_LATENCY = 2
# A generated pause frame is four beats; `pauseTx` marks the last.
PAUSE_FRAME_CYCLES = 5


async def send_contiguous_frame(endpoint: FlatEmacEndpoint, beats: list[EmacBeat], *, clk, timeout_cycles: int = 20000) -> None:
    # Like the shared helper, but with a per-beat wait long enough for the
    # longest hold in this file (0x100 quanta of 64 clocks).
    for beat in beats:
        endpoint.drive(beat)
        await wait_sampled_ready(endpoint._sig("TReady"), clk=clk, timeout_cycles=timeout_cycles)
    endpoint.set_idle()


class AcceptedFrameLog:
    """Record frames accepted on the flattened master port with start cycles.

    The cycle index counts rising edges from construction, matching a
    StatusPulseCounter created in the same timestep.
    """

    def __init__(self, clk, endpoint: FlatEmacEndpoint, ready_signal):
        self.clk = clk
        self.endpoint = endpoint
        self.ready = ready_signal
        self.cycle = 0
        self.frames: list[tuple[int, list[EmacBeat]]] = []
        self._partial: list[EmacBeat] = []
        self._start = 0
        self.task = cocotb.start_soon(self._run())

    async def _run(self) -> None:
        """Lifetime agent: record accepted output frames until the test ends."""
        while True:
            await RisingEdge(self.clk)
            self.cycle += 1
            if resolved_int(self.endpoint._sig("TValid")) and resolved_int(self.ready):
                if not self._partial:
                    self._start = self.cycle
                self._partial.append(self.endpoint.snapshot())
                if self._partial[-1].last:
                    self.frames.append((self._start, self._partial))
                    self._partial = []


class TxPauseBench:
    def __init__(self, dut, bench):
        self.dut = dut
        self.clk = bench.clk
        self.source = bench.source
        self.p512 = env_int("PAUSE_512BITS_G", default=8)
        self.quantum = self.p512
        self.status = StatusPulseCounter(
            self.clk,
            {"req": dut.rxPauseReq, "accept": dut.sAxisTReady, "pauseTx": dut.pauseTx, "enable": dut.pauseEnable},
        )
        self.out = AcceptedFrameLog(self.clk, bench.sink, dut.mAxisTReady)
        self.rng = random.Random(SEED)
        self.case = f"PAUSE_512BITS_G={self.p512}"

    @classmethod
    async def create(cls, dut, *, pause_time: int = 0x0010):
        bench = await setup_flat_emac_testbench(
            dut,
            source_prefix="sAxis",
            sink_prefix="mAxis",
            initial_values={
                "mAxisTReady": 1,
                "clientPause": 0,
                "rxPauseReq": 0,
                "rxPauseValue": 0,
                "phyReady": 1,
                "pauseEnable": 1,
                "pauseTime": pause_time,
                "macAddress": 0x001122334455,
            },
        )
        return cls(dut, bench)

    def frame(self, payload_bytes: int, tag: int) -> bytes:
        payload = bytes([tag]) + bytes(self.rng.getrandbits(8) for _ in range(payload_bytes - 1))
        return build_ethernet_frame(dst_mac=0x020000000001, src_mac=0x020000000002, eth_type=0x88B5, payload=payload)

    async def drive_for_one_cycle(self, signal, value: int, idle: int) -> int:
        """Drive `signal` for exactly one sampled edge; return that edge index."""
        await sample_after_tpd(self.clk)
        signal.value = value
        sampled = self.status.cycle + 1
        await sample_after_tpd(self.clk)
        signal.value = idle
        return sampled

    async def pause_request(self, value: int) -> int:
        self.dut.rxPauseValue.value = value
        return await self.drive_for_one_cycle(self.dut.rxPauseReq, 1, 0)

    def accepts_after(self, start: int) -> list[int]:
        return [c for c in self.status.cycles["accept"] if c > start]

    async def wait_frames(self, count: int, timeout_cycles: int) -> None:
        for _ in range(timeout_cycles):
            if len(self.out.frames) >= count:
                return
            await RisingEdge(self.clk)
        raise AssertionError(f"{self.case}: expected {count} output frames, saw {len(self.out.frames)}")


async def measure_hold_delays(tb: TxPauseBench, values: tuple[int, ...]) -> dict[int, int]:
    """Request-to-first-accept delay for each pause value.

    Each request is made with the TX idle and a frame is presented on the
    next cycle, so the first beat waits on the hold counter.
    """
    delays = {}
    for value in values:
        req_cycle = await tb.pause_request(value)
        frame = tb.frame(40, value & 0xFF)
        expected_frames = len(tb.out.frames) + 1
        await send_contiguous_frame(tb.source, frame_beats_from_bytes(frame), clk=tb.clk)
        await tb.wait_frames(expected_frames, timeout_cycles=64)
        delays[value] = tb.accepts_after(req_cycle)[0] - req_cycle
        assert payload_from_beats(tb.out.frames[-1][1]) == frame, f"{tb.case}: frame after value={value:#x}"
        await cycle(tb.clk, 4)
    tb.dut._log.info(f"{tb.case}: request-to-accept delays {delays}")
    return delays


def check_hold_delays(tb: TxPauseBench, delays: dict[int, int]) -> None:
    # The zero-value latency is the stage's own pipeline; every other value
    # adds exactly `value * PAUSE_512BITS_G` write clocks.
    assert delays[0] == ZERO_HOLD_LATENCY, f"{tb.case}: zero-value delay {delays[0]}"
    for value, delay in delays.items():
        assert delay - delays[0] == value * tb.p512, (
            f"{tb.case}: value={value:#x} held {delay - delays[0]} cycles, expected {value * tb.p512}"
        )


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def tx_pause_hold_quanta_test(dut):
    tb = await TxPauseBench.create(dut)
    check_hold_delays(tb, await measure_hold_delays(tb, (0, 1, 2, 7, 0x100)))


@cocotb.test(skip=KNOWN_ISSUE_SKIP, timeout_time=2, timeout_unit="ms")
async def tx_pause_quantum_length_known_issue_test(dut):
    # Known issue 15: a non-power-of-two `PAUSE_512BITS_G` (and 1) should still
    # hold `value * PAUSE_512BITS_G` cycles; this tree rounds the quantum up.
    tb = await TxPauseBench.create(dut)
    check_hold_delays(tb, await measure_hold_delays(tb, (0, 1, 2, 7)))


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def tx_pause_mid_frame_test(dut):
    tb = await TxPauseBench.create(dut)
    value = 4

    # Two frames queued back to back; the request lands after the third beat
    # of the first frame has been accepted.
    first = frame_beats_from_bytes(tb.frame(110, 0xA1))
    second = frame_beats_from_bytes(tb.frame(40, 0xA2))
    start = tb.status.cycle
    sender = cocotb.start_soon(send_contiguous_frame(tb.source, first + second, clk=tb.clk))
    for _ in range(64):
        await sample_after_tpd(tb.clk)
        if len(tb.accepts_after(start)) >= 3:
            break
    else:
        raise AssertionError(f"{tb.case}: first frame never started")
    req_cycle = await tb.pause_request(value)
    await sender
    await tb.wait_frames(2, timeout_cycles=value * tb.quantum + 64)

    # The in-flight frame finishes on consecutive cycles; the next frame waits
    # for the full hold measured from the request.
    accepts = tb.accepts_after(start)
    first_accepts = accepts[: len(first)]
    assert first_accepts == list(range(first_accepts[0], first_accepts[0] + len(first))), (
        f"{tb.case}: in-flight frame stalled {first_accepts}"
    )
    assert first_accepts[-1] < req_cycle + value * tb.quantum
    assert accepts[len(first)] == req_cycle + value * tb.quantum + ZERO_HOLD_LATENCY, (
        f"{tb.case}: second frame accepted at {accepts[len(first)] - req_cycle} cycles after the request"
    )
    assert [payload_from_beats(f) for _, f in tb.out.frames] == [payload_from_beats(first), payload_from_beats(second)]


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def tx_pause_enable_and_refresh_test(dut):
    tb = await TxPauseBench.create(dut)
    long_value = 0x40

    async def held_frame(tag: int) -> tuple[object, list[EmacBeat]]:
        beats = frame_beats_from_bytes(tb.frame(30, tag))
        return cocotb.start_soon(send_contiguous_frame(tb.source, beats, clk=tb.clk)), beats

    # Baseline: dropping `pauseEnable` clears the remaining hold (the counter
    # is zeroed, not frozen), so the waiting frame goes on the next cycles.
    req_cycle = await tb.pause_request(long_value)
    sender, _ = await held_frame(0xB1)
    await cycle(tb.clk, 10)
    disable_cycle = await tb.drive_for_one_cycle(dut.pauseEnable, 0, 1)
    await sender
    assert tb.accepts_after(req_cycle)[0] == disable_cycle + ZERO_HOLD_LATENCY, tb.case
    await cycle(tb.clk, 4)

    # With pause disabled a received request is ignored.
    await sample_after_tpd(tb.clk)
    dut.pauseEnable.value = 0
    req_cycle = await tb.pause_request(long_value)
    sender, _ = await held_frame(0xB2)
    await sender
    assert tb.accepts_after(req_cycle)[0] == req_cycle + ZERO_HOLD_LATENCY, tb.case
    await sample_after_tpd(tb.clk)
    dut.pauseEnable.value = 1
    await cycle(tb.clk, 4)

    # A new request replaces the running timer (shorter value).
    await tb.pause_request(long_value)
    sender, _ = await held_frame(0xB3)
    await cycle(tb.clk, 10)
    refresh_cycle = await tb.pause_request(3)
    await sender
    assert tb.accepts_after(refresh_cycle)[0] == refresh_cycle + 3 * tb.quantum + ZERO_HOLD_LATENCY, tb.case
    await cycle(tb.clk, 4)

    # XON: a zero-value request releases the hold.
    await tb.pause_request(long_value)
    sender, _ = await held_frame(0xB4)
    await cycle(tb.clk, 10)
    xon_cycle = await tb.pause_request(0)
    await sender
    assert tb.accepts_after(xon_cycle)[0] == xon_cycle + ZERO_HOLD_LATENCY, tb.case
    await tb.wait_frames(4, timeout_cycles=64)


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def tx_pause_local_generation_test(dut):
    pause_time = 0x0011
    tb = await TxPauseBench.create(dut, pause_time=pause_time)
    interval = (pause_time >> 1) * tb.quantum + PAUSE_FRAME_CYCLES

    # Hold `clientPause` high long enough for four pause frames.
    await sample_after_tpd(tb.clk)
    start = tb.status.cycle
    dut.clientPause.value = 1
    await tb.wait_frames(4, timeout_cycles=4 * interval + 64)
    await sample_after_tpd(tb.clk)
    dut.clientPause.value = 0
    stop = tb.status.cycle

    # Each frame is the standard MAC control pause frame with `pauseTime`
    # big-endian in the first two payload bytes (and an all-zero source MAC),
    # one `pauseTx` pulse marks each frame, and regeneration happens after half
    # the advertised pause time.
    pulses = [c for c in tb.status.cycles["pauseTx"] if start < c <= stop]
    frames = [f for f in tb.out.frames if f[0] > start]
    for index, (_, beats) in enumerate(frames):
        assert payload_from_beats(beats) == build_pause_frame(pause_time), f"{tb.case}: pause frame {index}"
    assert len(pulses) == len(frames), f"{tb.case}: {len(pulses)} pauseTx pulses for {len(frames)} frames"
    gaps = [b - a for a, b in zip(pulses, pulses[1:])]
    starts = [s for s, _ in frames]
    assert gaps and all(g == interval for g in gaps), f"{tb.case}: pauseTx intervals {gaps}, expected {interval}"
    assert all(b - a == interval for a, b in zip(starts, starts[1:])), f"{tb.case}: frame starts {starts}"

    # After `clientPause` falls no new pause frame starts.
    await cycle(tb.clk, 2 * interval)
    assert not [c for c in tb.status.cycles["pauseTx"] if c > stop + PAUSE_FRAME_CYCLES], tb.case

    # A request raised during a client frame waits for it to finish: the
    # pause frame starts on the cycle after the client frame's last beat.
    client = frame_beats_from_bytes(tb.frame(100, 0xC1))
    before = len(tb.out.frames)
    sender = cocotb.start_soon(send_contiguous_frame(tb.source, client, clk=tb.clk))
    await cycle(tb.clk, 3)
    await sample_after_tpd(tb.clk)
    dut.clientPause.value = 1
    await sender
    await tb.wait_frames(before + 2, timeout_cycles=64)
    await sample_after_tpd(tb.clk)
    dut.clientPause.value = 0
    (client_start, client_out), (pause_start, pause_out) = tb.out.frames[before : before + 2]
    assert payload_from_beats(client_out) == payload_from_beats(client)
    assert payload_from_beats(pause_out) == build_pause_frame(pause_time)
    assert pause_start == client_start + len(client) + 1, f"{tb.case}: pause frame started {pause_start - client_start} cycles after the client frame"
    await cycle(tb.clk, interval + 8)

    # With `phyReady` low `clientPause` is ignored.
    await sample_after_tpd(tb.clk)
    dut.phyReady.value = 0
    dut.clientPause.value = 1
    low_start = tb.status.cycle
    await cycle(tb.clk, 2 * interval)
    assert not [c for c in tb.status.cycles["pauseTx"] if c > low_start], f"{tb.case}: pause sent with phyReady low"
    dut.clientPause.value = 0
    dut.phyReady.value = 1
    await cycle(tb.clk, 4)


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def tx_pause_short_pause_time_test(dut):
    # Baseline: with `pauseTime` below two quanta the retransmit counter
    # (`pauseTime >> 1`) is zero, so pause frames repeat every five cycles and,
    # because IDLE_S serves `clientPause` before client data, a waiting client
    # frame is starved until `clientPause` falls.
    tb = await TxPauseBench.create(dut, pause_time=1)
    client = frame_beats_from_bytes(tb.frame(30, 0xD1))
    await sample_after_tpd(tb.clk)
    start = tb.status.cycle
    dut.clientPause.value = 1
    sender = cocotb.start_soon(send_contiguous_frame(tb.source, client, clk=tb.clk))
    await cycle(tb.clk, 60)
    pulses = [c for c in tb.status.cycles["pauseTx"] if c > start]
    assert len(pulses) >= 10 and all(b - a == PAUSE_FRAME_CYCLES for a, b in zip(pulses, pulses[1:])), (
        f"{tb.case}: pauseTx cycles {pulses}"
    )
    assert not tb.accepts_after(start), f"{tb.case}: client frame passed during continuous pause"
    await sample_after_tpd(tb.clk)
    dut.clientPause.value = 0
    await sender
    await tb.wait_frames(len(tb.out.frames) + 1, timeout_cycles=32)
    assert payload_from_beats(tb.out.frames[-1][1]) == payload_from_beats(client)


PARAMETER_SWEEP = [
    # Known issue 15 only: these settings are not powers of two (or are 1), so
    # every default entrypoint would observe the rounded quantum.
    pytest.param(
        {"PAUSE_512BITS_G": "1", "KNOWN_ISSUE_ONLY": "1"},
        id="quanta_1clk",
        marks=pytest.mark.skipif(KNOWN_ISSUE_SKIP, reason="known issue 15 (PAUSE_512BITS_G rounding); set RUN_KNOWN_ISSUE_TESTS=1"),
    ),
    pytest.param(
        {"PAUSE_512BITS_G": "5", "KNOWN_ISSUE_ONLY": "1"},
        id="quanta_5clk",
        marks=pytest.mark.skipif(KNOWN_ISSUE_SKIP, reason="known issue 15 (PAUSE_512BITS_G rounding); set RUN_KNOWN_ISSUE_TESTS=1"),
    ),
    parameter_case("quanta_8clk", PAUSE_512BITS_G="8"),
    parameter_case("quanta_64clk", PAUSE_512BITS_G="64"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTxPauseTiming(parameters):
    # Known-issue nodes name only the known-issue entrypoint (they run only
    # with the gate set); the default nodes exclude it.
    if parameters.get("KNOWN_ISSUE_ONLY") == "1":
        extra_env = cocotb_filtered_env(parameters, cocotb_test_filter(QUANTUM_KNOWN_ISSUE_TEST))
    else:
        extra_env = cocotb_filtered_env(parameters, cocotb_test_filter_excluding(QUANTUM_KNOWN_ISSUE_TEST))
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactxpausewrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=extra_env,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
