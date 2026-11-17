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
# - Sweep: EthMacTxExport behind `EthMacImportExportWrapper` with
#   `PHY_TYPE_G` = GMII and XGMII. XLGMII is omitted (see PARAMETER_SWEEP).
#   The GMII clock-enable scenarios run as their own pytest node; the XGMII
#   leaf has no clock enable, so its node excludes them.
# - Stimulus: seeded random frames (`ETHMAC_LINE_SEED`, default 0x7E57) are
#   pushed back-to-back on the 128-bit EMAC stream: every length 14..72 on
#   XGMII and a dense sample across the 60-byte padding boundary on GMII, plus
#   multi-beat 127..129 and the 1514/1518 maxima. Source underruns drop
#   `TVALID` for 64 clocks after the first beat, mid-frame and before the
#   last beat of a 128-byte frame. `txPhyReady` is held low while a frame
#   arrives in idle. GMII clock-enable patterns of 1-in-10 and 1-in-100 model
#   100 and 10 Mb/s operation.
#   GMII EOFE scenarios at enable periods 1/10/100 alternate errored and clean
#   frames across padding/beat boundaries, including minimum and long frames.
# - Checks: an independent GMII/XGMII line monitor decodes every frame and
#   checks the 7x0x55+SFD (GMII) or /S/+6x0x55+SFD (XGMII) preamble, the exact
#   payload with zero padding, the IEEE FCS, /T/ termination, the absence of
#   stray XGMII control characters and the interframe gap of back-to-back
#   frames. `txCountEn`, `txUnderRun` and `txLinkNotReady` are counted on
#   every clock and compared exactly. Underruns check what reaches the line
#   (GMII TX_ER, XGMII abort plus inverted FCS) and that the next frame is
#   clean. Behaviour that differs from IEEE 802.3 is asserted explicitly and
#   labelled "current baseline behaviour" with its RTL location.
#   EOFE checks require TX_ER through padding and every FCS byte, no TX_ER
#   outside TX_EN, exact payload/FCS and 12-octet gaps, and unchanged pins on
#   disabled clocks. Existing underrun assertions retain their separate policy.
# - Timing: monitors sample on rising edges (with the clock enable high for
#   GMII) before the registered `TPD_G` update, so gaps are measured in line
#   octets; XGMII gaps count /T/ as the first IPG octet. Every wait is bounded
#   by a cycle limit scaled to the PHY rate and enable period.
# - Mid-frame link loss is covered separately by test_EthMacKnownIssues.py
#   (default recovery scenarios for both PHYs).

from __future__ import annotations

import os
import random

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from tests.axi.utils import wait_sampled_ready
from tests.common.regression_utils import (
    cancel_and_join_tasks,
    cocotb_filtered_env,
    cocotb_test_filter,
    cocotb_test_filter_excluding,
    env_int,
    run_surf_vhdl_test,
)
from tests.ethernet.EthMacCore.ethmac_line_models import (
    MAX_FRAME_BYTES,
    MAX_VLAN_FRAME_BYTES,
    MIN_FRAME_BYTES,
    PREAMBLE,
    SFD,
    GmiiMonitor,
    StatusPulseCounter,
    XgmiiMonitor,
    describe_case,
    fcs_bytes,
    random_frame,
    resolved_int,
)
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    cycle,
    frame_beats_from_bytes,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacImportExportWrapper.vhd"
DEFAULT_SEED = 0x7E57
CLK_PERIOD_NS = 8.0
STATUS_NAMES = ("txCountEn", "txUnderRun", "txLinkNotReady")
GMII_PREAMBLE = PREAMBLE + bytes([SFD])
XGMII_PREAMBLE = b"\x55" * 6 + bytes([SFD])

GMII_LENGTHS = [14, 15, 16, 17, 30, 31, 32, 33, 34, 45, 46, 47, 58, 59, 60, 61, 62, 63, 64, 65, 127, 128, 129]
XGMII_LENGTHS = list(range(14, 73)) + [127, 128, 129]
MAX_LENGTHS = [MAX_FRAME_BYTES, MAX_VLAN_FRAME_BYTES, MIN_FRAME_BYTES, MAX_FRAME_BYTES, MAX_VLAN_FRAME_BYTES]

# Current baseline behaviour: back-to-back XGMII frames are separated by
# 28..35 octets (counting /T/), never the 12-octet IEEE minimum. Each frame
# costs ST_WAIT_C (at least 3 clocks, EthMacTxExportXgmii.vhd:345-350) plus
# the ST_IDLE_C and FIFO restart clocks, and /S/ is always in lane 0.
XGMII_BACK_TO_BACK_GAP = range(28, 36)

# Current baseline txUnderRun counts for a 64-clock stall of a 128-byte
# frame: the exporter's 64-bit FIFO still holds 2, 5 and 8 words when the
# source stalls before beat 1, 4 and 7, and the level lasts until data
# returns (EthMacTxExportXgmii.vhd:305-308).
XGMII_UNDERRUN_CYCLES = {"first": 62, "middle": 59, "last": 56}


def contiguous(cycles: list[int]) -> bool:
    return all(b == a + 1 for a, b in zip(cycles, cycles[1:]))


class TxLineBench:
    """Exporter source, line monitor and status counters for one PHY type."""

    def __init__(self, dut):
        self.dut = dut
        self.phy = os.environ["PHY_TYPE_G"]
        self.gmii = self.phy == "GMII"
        self.clk = dut.ethClk
        self.seed = env_int("ETHMAC_LINE_SEED", default=DEFAULT_SEED)
        self.rng = random.Random(self.seed)
        self.source = FlatEmacEndpoint(dut, prefix="sAxis")
        self.clk_en_period = 1
        self.monitor = None
        self.status = None
        self._error_base = 0
        self._tasks = []

    async def start(self, *, clk_en_period: int = 1) -> None:
        # Initialise every driven input before the first edge, then start the
        # clock, the line monitor and the status counters, and hold reset for
        # an explicit number of (enabled) clocks.
        dut = self.dut
        self.clk_en_period = clk_en_period
        dut.ethRst.setimmediatevalue(1)
        dut.ethClkEn.setimmediatevalue(1)
        dut.txPhyReady.setimmediatevalue(1)
        dut.rxPhyReady.setimmediatevalue(1)
        self.source.set_idle()
        self._tasks.append(cocotb.start_soon(Clock(self.clk, CLK_PERIOD_NS, unit="ns").start()))
        if clk_en_period > 1:
            self._tasks.append(cocotb.start_soon(self._drive_clk_en(clk_en_period)))
        clk_en = dut.ethClkEn if clk_en_period > 1 else None
        if self.gmii:
            self.monitor = GmiiMonitor(dut, clk=self.clk, clk_en=clk_en)
        else:
            self.monitor = XgmiiMonitor(dut, clk=self.clk)
        self.status = StatusPulseCounter(self.clk, {name: getattr(dut, name) for name in STATUS_NAMES})
        self._tasks += [self.monitor.task, self.status.task]
        await cycle(self.clk, 4 * clk_en_period)
        dut.ethRst.value = 0
        await cycle(self.clk, 4 * clk_en_period)
        if not self.gmii:
            # Current baseline behaviour: in reset the XGMII exporter drives
            # all-zero data characters (TXC=0x00) instead of idles
            # (EthMacTxExportXgmii.vhd:501-503). Pin that, then judge line
            # protocol only from reset release onwards.
            reset_errors = list(self.monitor.protocol_errors)
            assert reset_errors and all(byte == 0x00 for _, _, byte in reset_errors), (
                f"XGMII reset-time line characters {reset_errors[:4]}"
            )
            self._error_base = len(reset_errors)

    async def _drive_clk_en(self, period: int) -> None:
        """Lifetime agent: drive ethClkEn high one clock in every ``period``; cancelled by close()."""
        phase = 0
        while True:
            await FallingEdge(self.clk)
            self.dut.ethClkEn.value = 1 if phase == 0 else 0
            phase = (phase + 1) % period

    async def close(self) -> None:
        await cancel_and_join_tasks(self._tasks)
        self._tasks = []

    # --- timing -------------------------------------------------------------

    def line_cycles(self, length: int) -> int:
        """Clock cycles to serialise one frame plus gap, with generous slack."""
        octets = 8 + max(length, MIN_FRAME_BYTES) + 4 + 40
        per_clock = 1 if self.gmii else 8
        return (octets // per_clock + 32) * self.clk_en_period

    async def wait_frames(self, count: int, *, cycles: int, what: str) -> None:
        for _ in range(cycles):
            if len(self.monitor.frames) >= count:
                return
            await RisingEdge(self.clk)
        raise AssertionError(
            f"{self.phy}: timed out after {cycles} cycles waiting for {what}: "
            f"{len(self.monitor.frames)}/{count} line frames (seed={self.seed})"
        )

    async def settle(self, octets: int = 64) -> None:
        """Let the line return to idle and trailing status pulses land."""
        per_clock = 1 if self.gmii else 8
        await cycle(self.clk, (octets // per_clock + 8) * self.clk_en_period)

    # --- stimulus -----------------------------------------------------------

    async def _send_beat(self, beat) -> None:
        # Hold the beat until a sampled TREADY; the limit covers one maximum
        # frame on the line at the slowest clock-enable rate.
        self.source.drive(beat)
        await wait_sampled_ready(self.dut.sAxisTReady, clk=self.clk, timeout_cycles=self.line_cycles(MAX_VLAN_FRAME_BYTES))

    async def send_frames(self, frames: list[bytes]) -> None:
        for frame in frames:
            for beat in frame_beats_from_bytes(frame):
                await self._send_beat(beat)
            self.source.set_idle()

    async def send_with_stall(self, frame: bytes, *, stall_before: int, stall_cycles: int) -> None:
        """Send ``frame`` but drop TVALID for ``stall_cycles`` before beat ``stall_before``."""
        for index, beat in enumerate(frame_beats_from_bytes(frame)):
            if index == stall_before:
                self.source.set_idle()
                await cycle(self.clk, stall_cycles)
            await self._send_beat(beat)
        self.source.set_idle()

    # --- checks -------------------------------------------------------------

    def expected_line_payload(self, frame: bytes) -> bytes:
        """Frame as it should appear on the line: zero-padded to 60 bytes."""
        if len(frame) >= MIN_FRAME_BYTES:
            return frame
        if self.gmii:
            # Current baseline behaviour: the GMII exporter pads every frame
            # shorter than 60 bytes to 61 octets, one more than the IEEE 802.3
            # minimum. PAD_S only leaves after a clock with txCount = 60 and
            # TX_CRC_S then emits one more zero (EthMacTxExportGmii.vhd:217-230).
            # The FCS covers all 61 octets, so the frame is still valid.
            return frame + bytes(61 - len(frame))
        return frame + bytes(MIN_FRAME_BYTES - len(frame))

    def check_clean_frame(self, line, frame: bytes, ctx: str) -> None:
        expected = self.expected_line_payload(frame)
        assert line.preamble_ok, f"{self.phy} {ctx}: bad preamble/SFD raw[:8]={line.raw[:8].hex()}"
        assert line.terminated, f"{self.phy} {ctx}: frame not terminated by /T/"
        assert not line.error, f"{self.phy} {ctx}: error symbol inside frame"
        assert line.frame == expected, (
            f"{self.phy} {ctx}: payload mismatch len={len(line.frame)} expected={len(expected)}\n"
            f"observed={line.frame.hex()}\nexpected={expected.hex()}"
        )
        assert line.fcs_ok, f"{self.phy} {ctx}: FCS {line.raw[-4:].hex()} expected {fcs_bytes(expected).hex()}"
        if not self.gmii:
            assert line.start_lane in (0, 4), f"XGMII {ctx}: /S/ in lane {line.start_lane}"

    def ifg_octets(self, line) -> int | None:
        """IEEE interframe gap in octets; XGMII /T/ is the first IPG octet."""
        if line.ifg is None:
            return None
        return line.ifg if self.gmii else line.ifg + 1

    def protocol_errors(self) -> list:
        """XGMII control characters outside the frame grammar since reset release."""
        return [] if self.gmii else self.monitor.protocol_errors[self._error_base :]


async def run_back_to_back(bench: TxLineBench, lengths: list[int], *, label: str) -> None:
    """Push frames of ``lengths`` back-to-back and check every line frame."""
    frames = [random_frame(bench.rng, length) for length in lengths]
    first = len(bench.monitor.frames)
    before = bench.status.snapshot()
    # The sender is finite work: it is awaited before the line checks start.
    sender = cocotb.start_soon(bench.send_frames(frames))
    await bench.wait_frames(
        first + len(frames),
        cycles=sum(bench.line_cycles(len(f)) for f in frames) + 1024,
        what=f"{label} frames",
    )
    await sender
    await bench.settle()

    lines = bench.monitor.frames[first:]
    assert len(lines) == len(frames), f"{bench.phy} {label}: {len(lines)} line frames for {len(frames)} sent"
    for index, (line, frame) in enumerate(zip(lines, frames, strict=True)):
        bench.check_clean_frame(line, frame, describe_case(bench.seed, index, f"{label} length={len(frame)}"))

    # Interframe gap of every back-to-back pair.
    for index in range(1, len(frames)):
        ctx = describe_case(bench.seed, index, f"{label} gap after length={len(frames[index - 1])}")
        gap = bench.ifg_octets(lines[index])
        assert gap is not None and gap >= 12, f"{bench.phy} {ctx}: interframe gap {gap} < 12 octets"
        if bench.gmii:
            # GMII: 11 octets in INTERGAP_S plus one in IDLE_S, then preamble.
            assert gap == 12, f"GMII {ctx}: back-to-back gap {gap} != 12 octets"
        else:
            assert gap in XGMII_BACK_TO_BACK_GAP, f"XGMII {ctx}: back-to-back gap {gap} outside 28..35 octets"

    assert bench.protocol_errors() == [], f"{bench.phy} {label}: XGMII protocol errors {bench.protocol_errors()[:8]}"
    delta = bench.status.delta(before)
    assert delta == {"txCountEn": len(frames), "txUnderRun": 0, "txLinkNotReady": 0}, (
        f"{bench.phy} {label}: status pulses {delta} for {len(frames)} frames (seed={bench.seed})"
    )


@cocotb.test()
async def tx_length_sweep(dut):
    """Every frame length across the padding boundary and the maxima, back-to-back."""
    bench = TxLineBench(dut)
    await bench.start()
    lengths = GMII_LENGTHS if bench.gmii else XGMII_LENGTHS
    await run_back_to_back(bench, lengths, label="padding sweep")
    await run_back_to_back(bench, MAX_LENGTHS, label="maximum frames")
    await bench.close()


def check_gmii_underrun(lines, er_symbols, delta, frame: bytes, accepted: int, ctx: str) -> None:
    """GMII: TX_ER marks the last octet sent; the rest of the frame is dropped."""
    assert len(lines) == 1, f"GMII {ctx}: {len(lines)} line frames"
    line = lines[0]
    # Every accepted byte reaches the line; the last one carries TX_ER.
    assert line.raw == GMII_PREAMBLE + frame[:accepted], f"GMII {ctx}: raw={line.raw.hex()}"
    assert line.error, f"GMII {ctx}: no TX_ER inside the aborted frame"
    assert not line.fcs_ok, f"GMII {ctx}: aborted frame carries a valid FCS"
    assert er_symbols, f"GMII {ctx}: no TX_ER symbols"
    first_cycle, first_en, first_d = er_symbols[0]
    assert (first_en, first_d) == (1, frame[accepted - 1]), f"GMII {ctx}: first TX_ER symbol {er_symbols[0]}"
    assert first_cycle == line.end_cycle, f"GMII {ctx}: TX_ER at {first_cycle}, frame ended {line.end_cycle}"
    # Current baseline behaviour: after the TX_EN+TX_ER octet, TX_ER stays
    # high with TX_EN low and TXD=0x00 (a reserved GMII encoding) through
    # DUMP_S and INTERGAP_S until IDLE_S clears it
    # (EthMacTxExportGmii.vhd:211-215 sets it, :250-266 keep it, :168 clears).
    assert contiguous([entry[0] for entry in er_symbols]), f"GMII {ctx}: TX_ER run is not contiguous"
    assert all((en, d) == (0, 0) for _, en, d in er_symbols[1:]), f"GMII {ctx}: TX_ER tail {er_symbols[1:4]}"
    assert len(er_symbols) > 12, f"GMII {ctx}: TX_ER tail only {len(er_symbols)} octets"
    # One underrun pulse; an aborted frame is not counted as transmitted.
    assert delta == {"txCountEn": 0, "txUnderRun": 1, "txLinkNotReady": 0}, f"GMII {ctx}: status {delta}"


def check_xgmii_underrun(lines, errors, under_cycles, delta, frame: bytes, accepted: int, position: str, ctx: str) -> None:
    """XGMII: the frame is aborted and its remainder carries an inverted FCS."""
    inverted_fcs = bytes(b ^ 0xFF for b in fcs_bytes(frame))
    assert len(lines) == 2, f"XGMII {ctx}: {len(lines)} line frames"
    head, tail = lines
    # Current baseline behaviour: once the stall drains the exporter, the open
    # frame is ended with idles and no /T/ (txEnable0 drops,
    # EthMacTxExportXgmii.vhd:410-411 and :515-517), and the resumed data
    # starts a fresh /S/ frame (:519-522). That extra preamble word shifts the
    # fixed-latency CRC delay path, so the inverted FCS replaces the final
    # eight payload bytes, which never reach the line.
    assert head.raw == XGMII_PREAMBLE + frame[:accepted], f"XGMII {ctx}: head raw={head.raw.hex()}"
    assert not head.terminated and head.error, f"XGMII {ctx}: head terminated={head.terminated} error={head.error}"
    assert errors and all(byte == 0x07 for _, _, byte in errors), f"XGMII {ctx}: abort characters {errors[:4]}"
    # The remainder is terminated, and its FCS is the inverted CRC of the
    # whole frame (crcMaskIn = 0xFF, :433-434 and :578-581), so no receiver
    # accepts it.
    assert tail.terminated and tail.preamble_ok, f"XGMII {ctx}: tail terminated={tail.terminated}"
    assert not tail.fcs_ok, f"XGMII {ctx}: underrun frame carries a valid FCS"
    assert tail.raw == XGMII_PREAMBLE + frame[accepted:-8] + inverted_fcs, f"XGMII {ctx}: tail raw={tail.raw.hex()}"
    # Current baseline behaviour: txUnderRun is a level on every starved
    # clock (:305-308) and the aborted frame is still counted by txCountEn
    # when its tLast is read (:292-302).
    assert contiguous(under_cycles), f"XGMII {ctx}: txUnderRun clocks not contiguous: {under_cycles}"
    expected = {"txCountEn": 1, "txUnderRun": XGMII_UNDERRUN_CYCLES[position], "txLinkNotReady": 0}
    assert delta == expected, f"XGMII {ctx}: status {delta} expected {expected}"


@cocotb.test()
async def tx_underrun(dut):
    """Source underrun after the first beat, mid-frame and before the last beat."""
    bench = TxLineBench(dut)
    await bench.start()
    frame_len = 128  # eight full 16-byte beats
    stall_cycles = 64  # longer than all exporter buffering for both PHYs
    for index, (position, stall_before) in enumerate((("first", 1), ("middle", 4), ("last", 7))):
        ctx = describe_case(bench.seed, index, f"underrun before beat {stall_before} ({position})")
        frame = random_frame(bench.rng, frame_len)
        clean = random_frame(bench.rng, 100)
        first = len(bench.monitor.frames)
        er_first = len(bench.monitor.er_symbols) if bench.gmii else 0
        err_first = len(bench.protocol_errors())
        under_first = len(bench.status.cycles["txUnderRun"])
        before = bench.status.snapshot()

        # Drop TVALID before beat `stall_before`, then finish the frame.
        await bench.send_with_stall(frame, stall_before=stall_before, stall_cycles=stall_cycles)
        await bench.settle(octets=256)
        lines = bench.monitor.frames[first:]
        delta = bench.status.delta(before)
        accepted = 16 * stall_before
        if bench.gmii:
            check_gmii_underrun(lines, bench.monitor.er_symbols[er_first:], delta, frame, accepted, ctx)
        else:
            check_xgmii_underrun(
                lines,
                bench.protocol_errors()[err_first:],
                bench.status.cycles["txUnderRun"][under_first:],
                delta,
                frame,
                accepted,
                position,
                ctx,
            )

        # Recovery: the next frame is clean and counted once.
        err_first = len(bench.protocol_errors())
        mid = bench.status.snapshot()
        await bench.send_frames([clean])
        await bench.wait_frames(len(lines) + first + 1, cycles=bench.line_cycles(100) + 256, what="post-underrun frame")
        await bench.settle()
        assert len(bench.monitor.frames) == first + len(lines) + 1, f"{bench.phy} {ctx}: extra line frames after recovery"
        bench.check_clean_frame(bench.monitor.frames[-1], clean, f"{ctx} recovery frame")
        assert bench.protocol_errors()[err_first:] == [], f"{bench.phy} {ctx}: protocol errors after recovery"
        delta = bench.status.delta(mid)
        assert delta == {"txCountEn": 1, "txUnderRun": 0, "txLinkNotReady": 0}, f"{bench.phy} {ctx} recovery: {delta}"
    await bench.close()


@cocotb.test()
async def tx_phy_not_ready_idle(dut):
    """txPhyReady low while idle: frame handling, status pulse and recovery."""
    bench = TxLineBench(dut)
    await bench.start()
    blocked = random_frame(bench.rng, 40)
    recovery = random_frame(bench.rng, 80)
    before = bench.status.snapshot()

    # Present one frame with the PHY not ready and keep the link down for a
    # fixed number of clocks.
    dut.txPhyReady.value = 0
    down_start = bench.status.cycle
    await bench.send_frames([blocked])
    await bench.settle(octets=400)
    down_end = bench.status.cycle
    assert len(bench.monitor.frames) == 0, f"{bench.phy}: frame on the line while txPhyReady=0"
    down = bench.status.delta(before)
    not_ready_cycles = list(bench.status.cycles["txLinkNotReady"])

    # Restore the link, then send a recovery frame.
    dut.txPhyReady.value = 1
    await cycle(bench.clk, 8)
    await bench.send_frames([recovery])
    await bench.wait_frames(1 if bench.gmii else 2, cycles=2 * bench.line_cycles(80) + 256, what="recovery frame")
    await bench.settle()
    after = bench.status.delta(before)
    lines = bench.monitor.frames

    if bench.gmii:
        # The frame is consumed and dropped with exactly one txLinkNotReady
        # pulse; only the recovery frame reaches the line.
        assert down == {"txCountEn": 0, "txUnderRun": 0, "txLinkNotReady": 1}, f"GMII link-down status {down}"
        assert len(lines) == 1, f"GMII: {len(lines)} frames after recovery"
        bench.check_clean_frame(lines[0], recovery, "GMII recovery frame")
        assert after == {"txCountEn": 1, "txUnderRun": 0, "txLinkNotReady": 1}, f"GMII status {after}"
    else:
        # Current baseline behaviour: the XGMII exporter holds the frame rather
        # than dropping it. IDLE waits for phyReady, so txLinkNotReady is
        # asserted on every clock the frame waits, and the held frame is sent
        # when the link returns, ahead of the recovery frame.
        assert down["txCountEn"] == 0 and down["txUnderRun"] == 0, f"XGMII link-down status {down}"
        assert contiguous(not_ready_cycles), "XGMII txLinkNotReady clocks not contiguous"
        assert not_ready_cycles[-1] == down_end, (
            f"XGMII txLinkNotReady ended at clock {not_ready_cycles[-1]}, link restored at {down_end}"
        )
        assert down_end - down_start - 8 <= len(not_ready_cycles) <= down_end - down_start, (
            f"XGMII txLinkNotReady held {len(not_ready_cycles)} of {down_end - down_start} link-down clocks"
        )
        assert len(lines) == 2, f"XGMII: {len(lines)} frames after recovery"
        bench.check_clean_frame(lines[0], blocked, "XGMII held frame")
        bench.check_clean_frame(lines[1], recovery, "XGMII recovery frame")
        expected = {"txCountEn": 2, "txUnderRun": 0, "txLinkNotReady": len(not_ready_cycles)}
        assert after == expected, f"XGMII status {after} expected {expected}"
    assert bench.protocol_errors() == [], f"{bench.phy}: XGMII protocol errors {bench.protocol_errors()[:8]}"
    await bench.close()


async def run_clk_en(dut, period: int, lengths: list[int]) -> None:
    """GMII with ethClkEn high one clock in ``period``: exact frames and counts."""
    bench = TxLineBench(dut)
    assert bench.gmii, "clock-enable scenarios apply to GMII only"
    await bench.start(clk_en_period=period)
    await run_back_to_back(bench, lengths, label=f"clock enable 1-in-{period}")
    await bench.close()


@cocotb.test()
async def tx_clk_en_1_in_10(dut):
    """GMII 100 Mb/s style enable: one enabled clock in ten."""
    await run_clk_en(dut, 10, [60, 33, 14, 100, 129])


@cocotb.test()
async def tx_clk_en_1_in_100(dut):
    """GMII 10 Mb/s style enable: one enabled clock in a hundred."""
    await run_clk_en(dut, 100, [60, 45])


async def run_gmii_eofe(dut, period: int, lengths: list[int]) -> None:
    """EOFE spans the final data/padding/FCS and clears with TX_EN."""
    bench = TxLineBench(dut)
    assert bench.gmii, "GMII EOFE pin timing requires the GMII parameter case"
    await bench.start(clk_en_period=period)

    async def check_disabled_clocks():
        """Lifetime agent: check GMII pin holds until bench.close() cancels it."""
        names = ("gmiiTxEn", "gmiiTxEr", "gmiiTxd")
        previous = tuple(resolved_int(getattr(dut, name)) for name in names)
        while True:
            await RisingEdge(bench.clk)
            enabled = resolved_int(dut.ethClkEn)
            # Falling-edge observation is after TPD_G and before the next
            # rising edge; outputs may advance only on an enabled edge.
            await FallingEdge(bench.clk)
            current = tuple(resolved_int(getattr(dut, name)) for name in names)
            if not enabled:
                assert current == previous, f"GMII 1-in-{period}: pins changed on disabled clock"
            previous = current

    bench._tasks.append(cocotb.start_soon(check_disabled_clocks()))
    frames = []
    for length in lengths:
        frames.extend((random_frame(bench.rng, length), random_frame(bench.rng, 100)))
    before = bench.status.snapshot()
    # Drive continuously through the stream handshake so every error frame
    # has an immediately queued clean successor. All finite sends are awaited.
    for index, frame in enumerate(frames):
        for beat in frame_beats_from_bytes(frame, eofe=int(index % 2 == 0)):
            await bench._send_beat(beat)
    bench.source.set_idle()
    await bench.wait_frames(len(frames), cycles=bench.line_cycles(100) + 256, what="EOFE recovery")
    await bench.settle()

    lines = bench.monitor.frames
    errors = bench.monitor.er_symbols
    assert len(lines) == len(frames), f"GMII 1-in-{period}: extra/missing line frame"
    for index, (line, frame) in enumerate(zip(lines, frames, strict=True)):
        ctx = describe_case(bench.seed, index, f"EOFE 1-in-{period}, length={len(frame)}")
        expected = bench.expected_line_payload(frame)
        assert line.raw == GMII_PREAMBLE + expected + fcs_bytes(expected), ctx
        assert line.preamble_ok and line.terminated and line.fcs_ok, ctx
        if index:
            assert line.ifg == 12, f"{ctx}: interframe gap {line.ifg}"
        if index % 2 == 0:
            assert line.error, f"{ctx}: missing TX_ER"
            error_cycles = [tick for tick, _, _ in errors if line.start_cycle <= tick <= line.end_cycle]
            # At least the last payload byte, all padding and all four FCS
            # bytes must carry TX_ER. In particular, do not clear on CRC3.
            last_payload = line.start_cycle + len(GMII_PREAMBLE) + len(frame) - 1
            assert set(range(last_payload, line.end_cycle + 1)) <= set(error_cycles), (
                ctx, "TX_ER missing from final payload/padding/FCS", error_cycles
            )
            assert contiguous(error_cycles), f"{ctx}: TX_ER has a gap inside the frame"
        else:
            bench.check_clean_frame(line, frame, ctx)
    # Checking every error sample also covers the first idle byte and the
    # complete following gap, which frame-level error decoding would miss.
    assert all(en == 1 for _, en, _ in errors), f"GMII 1-in-{period}: TX_ER remained high during idle"
    assert not bench.monitor.frame_pending
    assert bench.status.delta(before) == {"txCountEn": len(frames), "txUnderRun": 0, "txLinkNotReady": 0}
    await bench.close()


@cocotb.test(timeout_time=500, timeout_unit="us")
async def tx_gmii_eofe_boundary(dut):
    await run_gmii_eofe(dut, 1, [14, 40, 59, 60, 61, 64, 127, 128, 129, 1518])


@cocotb.test(timeout_time=1000, timeout_unit="us")
async def tx_gmii_eofe_clk_en_1_in_10(dut):
    await run_gmii_eofe(dut, 10, [14, 59, 60, 61, 129])


@cocotb.test(timeout_time=2000, timeout_unit="us")
async def tx_gmii_eofe_clk_en_1_in_100(dut):
    await run_gmii_eofe(dut, 100, [14, 59, 60, 61, 129])


CLK_EN_TESTS = ("tx_clk_en_1_in_10", "tx_clk_en_1_in_100",
                "tx_gmii_eofe_clk_en_1_in_10", "tx_gmii_eofe_clk_en_1_in_100")
GMII_ONLY_TESTS = ("tx_gmii_eofe_boundary", *CLK_EN_TESTS)

# XLGMII is omitted: EthMacTxExportXlgmii is a placeholder leaf with no line
# behaviour, this wrapper leaves its pins open and there is no XLGMII line
# model. test_EthMacTxExport.py keeps the inert-placeholder check.
PARAMETER_SWEEP = [
    pytest.param({"PHY_TYPE_G": "GMII"}, cocotb_test_filter_excluding(*CLK_EN_TESTS), id="gmii"),
    pytest.param({"PHY_TYPE_G": "GMII"}, cocotb_test_filter(*CLK_EN_TESTS), id="gmii_clk_en"),
    pytest.param({"PHY_TYPE_G": "XGMII"}, cocotb_test_filter_excluding(*GMII_ONLY_TESTS), id="xgmii"),
]


@pytest.mark.parametrize(("parameters", "test_filter"), PARAMETER_SWEEP)
def test_EthMacTxExportLine(parameters, test_filter):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacimportexportwrapper",
        parameters=parameters,
        extra_env=cocotb_filtered_env(parameters, test_filter),
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
