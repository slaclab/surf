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
# - Sweep: EthMacRxImport behind `EthMacImportExportWrapper` with
#   `PHY_TYPE_G` = GMII and XGMII. XLGMII is omitted (see PARAMETER_SWEEP).
#   PHY-specific entrypoints (GMII RX_ER, GMII clock enable, XGMII /E/) are
#   selected per pytest node so no node runs an inapplicable scenario; the
#   GMII clock-enable scenarios run as their own node.
# - Stimulus: an independent GMII/XGMII line encoder drives seeded random
#   frames (`ETHMAC_LINE_SEED`, default 0x1A2B): good frames from 60 to 1518
#   bytes (XGMII alternating /S/ in lanes 0 and 4) back-to-back at the
#   standard and a reduced interframe gap, bad-FCS frames interleaved with
#   good ones, runts, truncated/corrupted preambles and missing SFDs, GMII
#   RX_ER at preamble/SFD/data/FCS positions, XGMII /E/ inside the preamble,
#   data and FCS, `rxPhyReady` low between frames and (GMII) mid-frame, and
#   GMII clock-enable patterns of 1-in-10 and 1-in-100.
# - Checks: a lifetime monitor assembles every importer output frame and the
#   bench compares exact payload bytes, SOF on the first beat, EOFE on the
#   last beat only, contiguous TKEEP, and exact `rxCountEn`/`rxCrcError`
#   pulse counts per frame. Every error case is followed by a good frame that
#   must be received intact. Behaviour that differs from IEEE 802.3 is
#   asserted explicitly and labelled "current baseline behaviour" with its RTL
#   location.
# - Timing: symbols change on the falling edge and are sampled by the DUT on
#   the next (enabled) rising edge; the output monitor and status counters
#   sample on rising edges before the registered `TPD_G` update. After each
#   stream the bench waits a fixed, enable-scaled drain time for the import
#   pipeline before comparing, so absence checks are bounded windows.
# - Known issue: GMII reception with a gated ethClkEn is broken (see
#   GMII_CLK_EN_ISSUE below). The default run pins the current drop and the
#   recovery in `rx_clk_en_baseline`; the intended exact-frame contract for
#   1-in-10 and 1-in-100 enables runs only with `RUN_KNOWN_ISSUE_TESTS=1` and
#   fails until the RTL is fixed.
# - Not covered (known-issue set, owned elsewhere): XGMII rxPhyReady loss or a
#   nested /S/ while a frame is being received.

from __future__ import annotations

from dataclasses import dataclass
import os
import random

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

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
    SFD,
    XGMII_ERROR,
    XGMII_IDLE,
    GmiiDriver,
    GmiiSymbol,
    StatusPulseCounter,
    XgmiiDriver,
    describe_case,
    fcs_bytes,
    gmii_data_offset,
    gmii_symbols,
    random_frame,
    resolved_int,
    wire_octets,
    xgmii_lanes,
    xgmii_words,
    xgmii_words_from_lanes,
)
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    cycle,
    payload_from_beats,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacImportExportWrapper.vhd"
DEFAULT_SEED = 0x1A2B
CLK_PERIOD_NS = 8.0
STATUS_NAMES = ("rxCountEn", "rxCrcError")
FULL_KEEP = 0xFFFF
GOOD = {"rxCountEn": 1, "rxCrcError": 0}
CRC_ERROR = {"rxCountEn": 0, "rxCrcError": 1}
NO_STATUS = {"rxCountEn": 0, "rxCrcError": 0}

GOOD_LENGTHS = [60, 61, 62, 63, 64, 65, 100, 127, 128, 129, MAX_FRAME_BYTES, MAX_VLAN_FRAME_BYTES]
SHORT_GAP_LENGTHS = [60, 61, 66, 67, 71, 64, 100, 129]
# GMII receive gap of 64 bit times; XGMII /T/ plus four idles is the 5-octet
# minimum receive IPG, rounded up so /S/ lands in lane 0 or 4.
GMII_SHORT_IFG = 8
XGMII_SHORT_IDLES = 4


@dataclass
class ImportFrame:
    payload: bytes
    beats: int
    sof: int
    eofe: int
    stray_sof: int
    stray_eofe: int
    keep_ok: bool


class ImportFrameMonitor:
    """Assemble importer output beats into frames; the importer has no backpressure."""

    def __init__(self, dut, clk):
        self.dut = dut
        self.clk = clk
        self.sink = FlatEmacEndpoint(dut, prefix="mAxis")
        self.frames: list[ImportFrame] = []
        self._beats = []
        self.task = cocotb.start_soon(self._run())

    @property
    def open_beats(self) -> int:
        """Beats seen since the last TLAST (a frame still in progress)."""
        return len(self._beats)

    async def _run(self) -> None:
        """Lifetime agent: collect importer output frames until the bench closes."""
        while True:
            await RisingEdge(self.clk)
            if resolved_int(self.dut.mAxisTValid) == 0:
                continue
            self._beats.append(self.sink.snapshot())
            if self._beats[-1].last:
                beats, self._beats = self._beats, []
                keeps = [beat.keep for beat in beats]
                self.frames.append(
                    ImportFrame(
                        payload=payload_from_beats(beats),
                        beats=len(beats),
                        sof=beats[0].sof,
                        eofe=beats[-1].eofe,
                        stray_sof=sum(beat.sof for beat in beats[1:]),
                        stray_eofe=sum(beat.eofe for beat in beats[:-1]),
                        keep_ok=all(keep == FULL_KEEP for keep in keeps[:-1])
                        and keeps[-1] != 0
                        and (keeps[-1] & (keeps[-1] + 1)) == 0,
                    )
                )


def xgmii_stream(
    frames_lanes: list[list[tuple[int, int]]], *, idles: int, first_lane: int = 0
) -> tuple[list[tuple[int, int]], list[int]]:
    """Concatenate encoded XGMII frames with at least ``idles`` idles after /T/.

    Each /S/ is moved up to the next lane 0 or 4, so /T/ and the next /S/ can
    share a word. Returns the packed words and the /S/ lane of every frame.
    """
    stream = [(XGMII_IDLE, 1)] * first_lane
    start_lanes = []
    for lanes in frames_lanes:
        stream += [(XGMII_IDLE, 1)] * (-len(stream) % 4)
        start_lanes.append(len(stream) % 8)
        stream += list(lanes) + [(XGMII_IDLE, 1)] * idles
    return xgmii_words_from_lanes(stream, start_lane=0), start_lanes


def frame_avoiding_sfd(rng: random.Random, length: int, *, after: int = 0) -> bytes:
    """Random frame with no 0xD5 octet from data index ``after`` through the FCS.

    The GMII importer re-arms its SFD search when it abandons a frame, so a
    later 0xD5 would start a second frame; cases that do not study that keep
    the remainder free of SFD-valued octets.
    """
    for _ in range(256):
        frame = random_frame(rng, length)
        if SFD not in frame[after:] + fcs_bytes(frame):
            return frame
    raise AssertionError(f"no {length}-byte frame without 0xD5 after {after}")


class RxLineBench:
    """Line driver, importer output monitor and status counters for one PHY type."""

    def __init__(self, dut):
        self.dut = dut
        self.phy = os.environ["PHY_TYPE_G"]
        self.gmii = self.phy == "GMII"
        self.clk = dut.ethClk
        self.seed = env_int("ETHMAC_LINE_SEED", default=DEFAULT_SEED)
        self.rng = random.Random(self.seed)
        self.clk_en_period = 1
        self.driver = None
        self.monitor = None
        self.status = None
        self.case_index = 0
        self._clk_en_task = None
        self._tasks = []

    async def start(self, *, clk_en_period: int = 1) -> None:
        # Initialise every driven input before the first edge, start the
        # clock, monitor and counters, and hold reset for explicit clocks.
        dut = self.dut
        self.clk_en_period = clk_en_period
        dut.ethRst.setimmediatevalue(1)
        dut.ethClkEn.setimmediatevalue(1)
        dut.txPhyReady.setimmediatevalue(1)
        dut.rxPhyReady.setimmediatevalue(1)
        FlatEmacEndpoint(dut, prefix="sAxis").set_idle()
        self._tasks.append(cocotb.start_soon(Clock(self.clk, CLK_PERIOD_NS, unit="ns").start()))
        if clk_en_period > 1:
            self._clk_en_task = cocotb.start_soon(self._drive_clk_en(clk_en_period))
        if self.gmii:
            self.driver = GmiiDriver(dut, clk=self.clk, clk_en=dut.ethClkEn if clk_en_period > 1 else None)
        else:
            self.driver = XgmiiDriver(dut, clk=self.clk)
        self.driver.idle()
        self.monitor = ImportFrameMonitor(dut, self.clk)
        self.status = StatusPulseCounter(self.clk, {name: getattr(dut, name) for name in STATUS_NAMES})
        self._tasks += [self.monitor.task, self.status.task]
        await cycle(self.clk, 4 * clk_en_period)
        dut.ethRst.value = 0
        await cycle(self.clk, 8 * clk_en_period)
        assert self.monitor.frames == [] and self.status.snapshot() == NO_STATUS, f"{self.phy}: output during reset"

    async def _drive_clk_en(self, period: int) -> None:
        """Lifetime agent: drive ethClkEn high one clock in every ``period``; cancelled by close()."""
        phase = 0
        while True:
            await FallingEdge(self.clk)
            self.dut.ethClkEn.value = 1 if phase == 0 else 0
            phase = (phase + 1) % period

    async def hold_clk_en_high(self) -> None:
        """Stop the enable pattern and hold ethClkEn high from the next clock."""
        if self._clk_en_task is not None:
            await cancel_and_join_tasks([self._clk_en_task])
            self._clk_en_task = None
        await FallingEdge(self.clk)
        self.dut.ethClkEn.value = 1
        self.clk_en_period = 1
        self.driver.clk_en = None
        await cycle(self.clk, 4)

    async def close(self) -> None:
        tasks = self._tasks + ([self._clk_en_task] if self._clk_en_task is not None else [])
        await cancel_and_join_tasks(tasks)
        self._tasks = []
        self._clk_en_task = None

    def encode(self, frame: bytes, **kwargs):
        return gmii_symbols(frame, **kwargs) if self.gmii else xgmii_words(frame, **kwargs)

    async def drain(self) -> None:
        """Bounded wait for the import pipeline (at most ~10 enabled clocks deep)."""
        await cycle(self.clk, 48 * self.clk_en_period)

    async def receive(self, stream, label: str) -> tuple[list[ImportFrame], dict[str, int], str]:
        """Drive one encoded stream and return the frames and pulses it caused."""
        ctx = describe_case(self.seed, self.case_index, f"{self.phy} {label}")
        self.case_index += 1
        first = len(self.monitor.frames)
        before = self.status.snapshot()
        await self.driver.send(stream)
        await self.drain()
        assert self.monitor.open_beats == 0, f"{ctx}: importer left a frame without TLAST"
        frames = self.monitor.frames[first:]
        delta = self.status.delta(before)
        cocotb.log.info(f"{ctx}: lengths={[len(f.payload) for f in frames]} eofe={[f.eofe for f in frames]} status={delta}")
        return frames, delta, ctx

    def check_frame(self, frame: ImportFrame, payload: bytes, *, eofe: int, ctx: str, sof: int = 1) -> None:
        assert frame.payload == payload, (
            f"{ctx}: payload len={len(frame.payload)} expected={len(payload)}\n"
            f"observed={frame.payload.hex()}\nexpected={payload.hex()}"
        )
        assert (frame.sof, frame.eofe) == (sof, eofe), f"{ctx}: sof={frame.sof} eofe={frame.eofe} expected {sof}/{eofe}"
        assert frame.stray_sof == 0 and frame.stray_eofe == 0, f"{ctx}: SOF/EOFE on a middle beat"
        assert frame.keep_ok, f"{ctx}: non-contiguous TKEEP"

    async def expect_good(self, frame: bytes, label: str, **encode_kwargs) -> None:
        """A good frame is delivered intact with exactly one rxCountEn pulse."""
        frames, delta, ctx = await self.receive(self.encode(frame, **encode_kwargs), label)
        assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
        self.check_frame(frames[0], frame, eofe=0, ctx=ctx)
        assert delta == GOOD, f"{ctx}: status {delta}"

    async def expect_nothing(self, stream, label: str) -> None:
        frames, delta, ctx = await self.receive(stream, label)
        assert frames == [] and delta == NO_STATUS, f"{ctx}: frames={len(frames)} status={delta}"

    async def send_gmii_dropping_ready(self, symbols, *, drop_at: int) -> None:
        """Drive GMII symbols, lowering rxPhyReady together with symbol ``drop_at``.

        Same falling-edge timing as GmiiDriver (no clock enable), but without
        an idle octet at the drop point so RX_DV stays high across it.
        """
        for index, symbol in enumerate(symbols):
            await FallingEdge(self.clk)
            if index == drop_at:
                self.dut.rxPhyReady.value = 0
            self.dut.gmiiRxDv.value = symbol.dv
            self.dut.gmiiRxEr.value = symbol.er
            self.dut.gmiiRxd.value = symbol.d
            await RisingEdge(self.clk)
        await FallingEdge(self.clk)
        self.driver.idle()

    async def recover(self, label: str) -> None:
        """After an error case the next good frame must be received intact."""
        await self.expect_good(random_frame(self.rng, 80), f"recovery after {label}")


@cocotb.test()
async def rx_good_frames(dut):
    """Good frames of many lengths back-to-back, standard and reduced gap."""
    bench = RxLineBench(dut)
    await bench.start()
    for gap_label, lengths in (("standard gap", GOOD_LENGTHS), ("short gap", SHORT_GAP_LENGTHS)):
        frames = [random_frame(bench.rng, length) for length in lengths]
        if bench.gmii:
            ifg = 12 if gap_label == "standard gap" else GMII_SHORT_IFG
            stream = [symbol for frame in frames for symbol in gmii_symbols(frame, ifg=ifg)]
        else:
            # /T/ plus 11 idles is the standard 12-octet gap. Each /S/ lands in
            # lane 0 or 4 depending on the previous frame length; both occur.
            idles = 11 if gap_label == "standard gap" else XGMII_SHORT_IDLES
            stream, start_lanes = xgmii_stream([xgmii_lanes(frame) for frame in frames], idles=idles, first_lane=4)
            assert set(start_lanes) == {0, 4}, f"XGMII {gap_label}: start lanes {start_lanes}"
        observed, delta, ctx = await bench.receive(stream, f"{len(frames)} good frames, {gap_label}")
        assert len(observed) == len(frames), f"{ctx}: {len(observed)} frames for {len(frames)} sent"
        for index, (got, frame) in enumerate(zip(observed, frames, strict=True)):
            bench.check_frame(got, frame, eofe=0, ctx=f"{ctx} frame {index} length={len(frame)}")
        assert delta == {"rxCountEn": len(frames), "rxCrcError": 0}, f"{ctx}: status {delta}"
    await bench.close()


@cocotb.test()
async def rx_bad_fcs(dut):
    """Bad FCS frames are delivered with EOFE and one rxCrcError each."""
    bench = RxLineBench(dut)
    await bench.start()
    for lane in (0, 4) if not bench.gmii else (0,):
        for length in (60, 64, 65, 100, 129, MAX_FRAME_BYTES):
            kwargs = {} if bench.gmii else {"start_lane": lane}
            frame = random_frame(bench.rng, length)
            frames, delta, ctx = await bench.receive(bench.encode(frame, bad_fcs=True, **kwargs), f"bad FCS length={length} lane={lane}")
            assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
            # The whole payload is delivered; EOFE on the last beat marks it bad.
            bench.check_frame(frames[0], frame, eofe=1, ctx=ctx)
            assert delta == CRC_ERROR, f"{ctx}: status {delta}"
            await bench.expect_good(random_frame(bench.rng, length), f"good after bad FCS length={length}", **kwargs)
    await bench.close()


@cocotb.test()
async def rx_runts(dut):
    """Frames shorter than 64 bytes including FCS."""
    bench = RxLineBench(dut)
    await bench.start()
    # Current baseline behaviour: neither importer checks a minimum length, so
    # runts with a valid FCS are delivered as good frames and counted by
    # rxCountEn (EthMacRxImportGmii.vhd:205-220; EthMacRxImportXgmii.vhd
    # :274-275). IEEE 802.3 receivers discard frames shorter than 64 octets.
    for length in (14, 20, 32, 45, 59):
        await bench.expect_good(random_frame(bench.rng, length), f"runt length={length}")
    for length in (4, 8, 13):
        frame = bytes(bench.rng.getrandbits(8) for _ in range(length))
        await bench.expect_good(frame, f"sub-header runt length={length}")
    # A runt with a bad FCS is still flagged.
    frame = random_frame(bench.rng, 32)
    frames, delta, ctx = await bench.receive(bench.encode(frame, bad_fcs=True), "runt length=32 bad FCS")
    assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
    bench.check_frame(frames[0], frame, eofe=1, ctx=ctx)
    assert delta == CRC_ERROR, f"{ctx}: status {delta}"

    # A single data octet plus FCS is too short for either import pipeline.
    frame = bytes([bench.rng.getrandbits(8)])
    frames, delta, ctx = await bench.receive(bench.encode(frame), "one-octet frame")
    assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
    if bench.gmii:
        # Current baseline behaviour: the one beat is delivered without SOF.
        # GET_DATA_S tags SOF on its first clock even though RX_DV is already
        # low there, and CRC_S then emits the held byte with a cleared TUSER
        # (EthMacRxImportGmii.vhd:194-202, 211-213).
        bench.check_frame(frames[0], frame, eofe=0, sof=0, ctx=ctx)
        assert delta == GOOD, f"{ctx}: status {delta}"
    else:
        # Current baseline behaviour: the XGMII importer emits four octets and
        # flags them with EOFE and rxCrcError (EthMacRxImportXgmii.vhd:517-545
        # sizes the last line from the /T/ position only).
        assert len(frames[0].payload) == 4 and frames[0].sof == 1 and frames[0].eofe == 1, f"{ctx}: {frames[0]}"
        assert delta == CRC_ERROR, f"{ctx}: status {delta}"
    await bench.recover("runts")
    await bench.close()


@cocotb.test()
async def rx_preamble_variants(dut):
    """Truncated or corrupted preamble and missing or corrupted SFD."""
    bench = RxLineBench(dut)
    await bench.start()
    rng = bench.rng
    if bench.gmii:
        # The GMII importer only looks for an SFD octet with RX_DV and no
        # RX_ER, so a shortened or corrupted preamble is accepted
        # (EthMacRxImportGmii.vhd:172-177).
        for preamble_bytes in (0, 1, 3):
            await bench.expect_good(random_frame(rng, 70), f"preamble of {preamble_bytes} octets", preamble_bytes=preamble_bytes)
        frame = random_frame(rng, 70)
        symbols = gmii_symbols(frame)
        symbols[2] = GmiiSymbol(1, 0, 0x5D)
        frames, delta, ctx = await bench.receive(symbols, "corrupted preamble octet")
        assert len(frames) == 1 and delta == GOOD, f"{ctx}: frames={len(frames)} status={delta}"
        bench.check_frame(frames[0], frame, eofe=0, ctx=ctx)

        # Without an SFD and no 0xD5 in the frame, nothing is received.
        await bench.expect_nothing(gmii_symbols(frame_avoiding_sfd(rng, 70), sfd=False), "missing SFD")
        await bench.recover("missing SFD")

        # Current baseline behaviour: the SFD search runs for the whole RX_DV
        # period, so without a real SFD the first 0xD5 data octet starts a
        # frame from the following octet. It fails the FCS check and is
        # delivered with EOFE and rxCrcError (EthMacRxImportGmii.vhd:172-177).
        frame = frame_avoiding_sfd(rng, 70)
        frame = frame[:30] + bytes([SFD]) + frame[31:]
        octets = wire_octets(frame, sfd=False)
        frames, delta, ctx = await bench.receive(gmii_symbols(frame, sfd=False), "missing SFD, 0xD5 at data 30")
        assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
        bench.check_frame(frames[0], octets[7 + 31 : -4], eofe=1, ctx=ctx)
        assert delta == CRC_ERROR, f"{ctx}: status {delta}"
        await bench.recover("false SFD")
    else:
        # Current baseline behaviour: the XGMII importer locates data purely
        # from the /S/ position and never inspects preamble or SFD values
        # (EthMacRxImportXgmii.vhd:357-368). A corrupted preamble octet or
        # SFD is accepted as a good frame; a preamble of the wrong length
        # shifts the payload, which then fails the FCS check.
        for label, index, value in (("corrupted preamble octet", 3, 0x5D), ("corrupted SFD", 7, 0x55)):
            frame = random_frame(rng, 70)
            lanes = xgmii_lanes(frame)
            lanes[index] = (value, 0)
            frames, delta, ctx = await bench.receive(xgmii_words_from_lanes(lanes), label)
            assert len(frames) == 1 and delta == GOOD, f"{ctx}: frames={len(frames)} status={delta}"
            bench.check_frame(frames[0], frame, eofe=0, ctx=ctx)
        for label, kwargs, shift in (
            ("preamble of 5 octets", {"preamble_bytes": 5}, -1),
            ("preamble of 7 octets", {"preamble_bytes": 7}, 1),
            ("missing SFD", {"sfd": False}, -1),
        ):
            frame = random_frame(rng, 70)
            frames, delta, ctx = await bench.receive(xgmii_words(frame, **kwargs), label)
            assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
            octets = xgmii_lanes(frame, **kwargs)[1:-1]
            # The importer always drops the first seven octets after /S/.
            bench.check_frame(frames[0], bytes(octet for octet, _ in octets)[7:-4], eofe=1, ctx=ctx)
            assert len(frames[0].payload) == len(frame) + shift
            assert delta == CRC_ERROR, f"{ctx}: status {delta}"
        await bench.recover("preamble variants")
    await bench.close()


@cocotb.test()
async def rx_gmii_rx_er(dut):
    """GMII RX_ER at preamble, SFD, early/late data and FCS positions."""
    bench = RxLineBench(dut)
    await bench.start()
    rng = bench.rng
    length = 100
    offset = gmii_data_offset()
    for label, position in (
        ("preamble", 3),
        ("SFD", 7),
        ("data 0", offset + 0),
        ("data 4", offset + 4),
        ("data 5", offset + 5),
        ("data 20", offset + 20),
        ("last data", offset + length - 1),
        ("FCS 1", offset + length + 1),
    ):
        data_index = position - offset
        frame = frame_avoiding_sfd(rng, length, after=max(data_index, 0))
        frames, delta, ctx = await bench.receive(gmii_symbols(frame, er_at=position), f"RX_ER at {label}")
        if data_index < 0 and label == "preamble":
            # Current baseline behaviour: RX_ER on a preamble octet is ignored
            # and the frame is received as good; only the SFD octet is checked
            # (EthMacRxImportGmii.vhd:172-177). IEEE 802.3 treats RX_ER with
            # RX_DV anywhere in the frame as a reception error.
            assert len(frames) == 1 and delta == GOOD, f"{ctx}: frames={len(frames)} status={delta}"
            bench.check_frame(frames[0], frame, eofe=0, ctx=ctx)
        elif data_index < 5:
            # An errored SFD is not recognised, and RX_ER during the first five
            # data octets (WAIT_DATA_S) abandons the frame. Current baseline
            # behaviour: that drop is silent, with no EOFE frame and no
            # rxCrcError (EthMacRxImportGmii.vhd:179-184).
            assert frames == [] and delta == NO_STATUS, f"{ctx}: frames={len(frames)} status={delta}"
        elif data_index == 5:
            # Current baseline behaviour: RX_ER on the first GET_DATA_S clock
            # emits a lone one-byte EOFE beat without SOF; its byte is the
            # stale output register (EthMacRxImportGmii.vhd:187-191).
            assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
            got = frames[0]
            assert (len(got.payload), got.sof, got.eofe) == (1, 0, 1), f"{ctx}: {got}"
            assert delta == NO_STATUS, f"{ctx}: status {delta}"
        else:
            # The frame is cut with EOFE. Output lags the line by five octets,
            # so data[0:j-5] has been delivered. Current baseline behaviour:
            # the EOFE beat repeats the previous byte (TDATA is held,
            # EthMacRxImportGmii.vhd:187-191), and no rxCrcError is pulsed for
            # an RX_ER abort.
            assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
            delivered = frame[: data_index - 5]
            bench.check_frame(frames[0], delivered + delivered[-1:], eofe=1, ctx=ctx)
            assert delta == NO_STATUS, f"{ctx}: status {delta}"
        await bench.recover(f"RX_ER at {label}")

    # Current baseline behaviour: after an RX_ER abort the importer re-arms
    # its SFD search while RX_DV is still high, so a later 0xD5 data octet
    # starts a second, spurious frame that is delivered with EOFE and
    # rxCrcError (EthMacRxImportGmii.vhd:187-191 return to WAIT_SFD_S).
    frame = frame_avoiding_sfd(rng, length)
    frame = frame[:40] + bytes([SFD]) + frame[41:]
    octets = wire_octets(frame)
    frames, delta, ctx = await bench.receive(gmii_symbols(frame, er_at=offset + 20), "RX_ER at data 20, 0xD5 at data 40")
    assert len(frames) == 2, f"{ctx}: {len(frames)} frames"
    bench.check_frame(frames[0], frame[:15] + frame[14:15], eofe=1, ctx=f"{ctx} aborted frame")
    bench.check_frame(frames[1], octets[offset + 41 : -4], eofe=1, ctx=f"{ctx} spurious frame")
    assert delta == CRC_ERROR, f"{ctx}: status {delta}"
    await bench.recover("RX_ER with false SFD")
    await bench.close()


# Current baseline delivered lengths for a 100-byte frame with one /E/ at the
# given stream position (after /S/; 7 = first data octet) and /S/ lane. The
# importer ends a frame at the first word holding any control character and
# sizes the last line from the control mask alone (EthMacRxImportXgmii.vhd
# :371-373, 278-319), so the cut point depends on the /E/ lane.
XGMII_E_CASES = {
    ("data 0", 7): {0: 100, 4: 100},
    ("data 20", 27): {0: 12, 4: 20},
    ("last data", 106): {0: 92, 4: 95},
    ("FCS 1", 108): {0: 92, 4: 100},
}


@cocotb.test()
async def rx_xgmii_error_char(dut):
    """XGMII /E/ in the preamble, data and FCS with /S/ in lanes 0 and 4."""
    bench = RxLineBench(dut)
    await bench.start()
    rng = bench.rng
    for lane in (0, 4):
        # Current baseline behaviour: /E/ inside the /S/ word's preamble is
        # ignored because start detection has priority over end detection
        # (EthMacRxImportXgmii.vhd:357-373); the frame is received as good.
        # IEEE 802.3 treats /E/ anywhere between /S/ and /T/ as an error.
        frame = random_frame(rng, 100)
        await bench.expect_good(frame, f"/E/ in preamble lane={lane}", error_at=2, start_lane=lane)
        for (label, position), lengths in XGMII_E_CASES.items():
            frame = random_frame(rng, 100)
            frames, delta, ctx = await bench.receive(bench.encode(frame, error_at=position, start_lane=lane), f"/E/ at {label} lane={lane}")
            assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
            # The delivered bytes are the frame prefix, with /E/ appearing as
            # 0xFE data, and the frame is flagged by EOFE and one rxCrcError.
            data_index = position - 7
            corrupted = frame[:data_index] + bytes([XGMII_ERROR]) + frame[data_index + 1 :]
            bench.check_frame(frames[0], corrupted[: lengths[lane]], eofe=1, ctx=ctx)
            assert delta == CRC_ERROR, f"{ctx}: status {delta}"
            await bench.recover(f"/E/ at {label} lane={lane}")
    await bench.close()


@cocotb.test()
async def rx_phy_ready(dut):
    """rxPhyReady low between frames, and (GMII) lost in the middle of a frame."""
    bench = RxLineBench(dut)
    await bench.start()
    rng = bench.rng
    # A frame that arrives while the PHY is not ready is ignored; recovery is
    # clean once rxPhyReady returns between frames.
    dut.rxPhyReady.value = 0
    await bench.expect_nothing(bench.encode(random_frame(rng, 100)), "frame while rxPhyReady=0")
    dut.rxPhyReady.value = 1
    await cycle(bench.clk, 4)
    await bench.recover("rxPhyReady low between frames")

    if bench.gmii:
        # GMII only: drop rxPhyReady at a data octet and keep it low until the
        # frame has ended. During WAIT_DATA_S the frame is abandoned silently;
        # during GET_DATA_S it is cut with EOFE (EthMacRxImportGmii.vhd
        # :179-191), without an rxCrcError pulse. The XGMII equivalent is a
        # known defect and is not run here.
        offset = gmii_data_offset()
        for data_index in (2, 30):
            frame = frame_avoiding_sfd(rng, 100)
            symbols = gmii_symbols(frame)
            first = len(bench.monitor.frames)
            before = bench.status.snapshot()
            ctx = describe_case(bench.seed, bench.case_index, f"GMII rxPhyReady lost at data {data_index}")
            bench.case_index += 1
            await bench.send_gmii_dropping_ready(symbols, drop_at=offset + data_index)
            await bench.drain()
            dut.rxPhyReady.value = 1
            await cycle(bench.clk, 4)
            frames = bench.monitor.frames[first:]
            delta = bench.status.delta(before)
            assert bench.monitor.open_beats == 0, f"{ctx}: frame left without TLAST"
            assert delta == NO_STATUS, f"{ctx}: status {delta}"
            if data_index < 5:
                assert frames == [], f"{ctx}: {len(frames)} frames"
            else:
                # As for RX_ER: data[0:j-5] was delivered and the EOFE beat
                # repeats the previous byte (current baseline behaviour).
                assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
                delivered = frame[: data_index - 5]
                bench.check_frame(frames[0], delivered + delivered[-1:], eofe=1, ctx=ctx)
            await bench.recover(f"rxPhyReady lost at data {data_index}")
    await bench.close()


@cocotb.test()
async def rx_clk_en_baseline(dut):
    """GMII importer with a gated ethClkEn: current baseline drops every frame."""
    bench = RxLineBench(dut)
    assert bench.gmii, "clock-enable scenarios apply to GMII only"
    await bench.start(clk_en_period=10)
    # Current baseline behaviour (RTL defect, see GMII_CLK_EN_ISSUE): with any
    # enable period above one the importer never leaves WAIT_DATA_S, so good
    # and bad frames alike vanish without a status pulse.
    await bench.expect_nothing(gmii_symbols(random_frame(bench.rng, 60)), "1-in-10 good frame")
    await bench.expect_nothing(gmii_symbols(random_frame(bench.rng, 64), bad_fcs=True), "1-in-10 bad FCS")
    # With the enable held high again the importer receives normally.
    await bench.hold_clk_en_high()
    await bench.recover("gated clock enable")
    await bench.close()


# GMII_CLK_EN_ISSUE: EthMacRxImportGmii clears delRxDv on every clock
# (EthMacRxImportGmii.vhd:147) but shifts it into delRxDvSr only on enabled
# clocks (:160). The one-clock pulse set at the SFD (:175) is gone before the
# next enabled clock, delRxDvSr(3) never rises and WAIT_DATA_S (:179-184)
# never reaches GET_DATA_S, so 10/100 Mb/s reception is lost. The entrypoints
# below assert the intended contract and fail on the current RTL; promote
# them to the default run with the fix and drop rx_clk_en_baseline.
KNOWN_ISSUE_SKIP = os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1"


async def run_clk_en(dut, period: int, lengths: list[int]) -> None:
    """GMII with ethClkEn high one clock in ``period``: exact frames and counts."""
    bench = RxLineBench(dut)
    assert bench.gmii, "clock-enable scenarios apply to GMII only"
    await bench.start(clk_en_period=period)
    for length in lengths:
        await bench.expect_good(random_frame(bench.rng, length), f"1-in-{period} length={length}")
    frame = random_frame(bench.rng, 64)
    frames, delta, ctx = await bench.receive(gmii_symbols(frame, bad_fcs=True), f"1-in-{period} bad FCS")
    assert len(frames) == 1, f"{ctx}: {len(frames)} frames"
    bench.check_frame(frames[0], frame, eofe=1, ctx=ctx)
    assert delta == CRC_ERROR, f"{ctx}: status {delta}"
    await bench.recover(f"1-in-{period} bad FCS")
    await bench.close()


@cocotb.test(skip=KNOWN_ISSUE_SKIP)
async def rx_clk_en_1_in_10_known_issue(dut):
    """GMII 100 Mb/s style enable, one enabled clock in ten (GMII_CLK_EN_ISSUE)."""
    await run_clk_en(dut, 10, [60, 100, 129])


@cocotb.test(skip=KNOWN_ISSUE_SKIP)
async def rx_clk_en_1_in_100_known_issue(dut):
    """GMII 10 Mb/s style enable, one enabled clock in a hundred (GMII_CLK_EN_ISSUE)."""
    await run_clk_en(dut, 100, [60])


KNOWN_ISSUE_CLK_EN_TESTS = ("rx_clk_en_1_in_10_known_issue", "rx_clk_en_1_in_100_known_issue")
CLK_EN_TESTS = ("rx_clk_en_baseline",) + KNOWN_ISSUE_CLK_EN_TESTS
GMII_ONLY_TESTS = ("rx_gmii_rx_er",) + CLK_EN_TESTS
XGMII_ONLY_TESTS = ("rx_xgmii_error_char",)
# cocotb runs a skip-marked test anyway when a filter names it, so the
# clock-enable node only names the known-issue entrypoints when gated in.
SELECTED_CLK_EN_TESTS = CLK_EN_TESTS if not KNOWN_ISSUE_SKIP else ("rx_clk_en_baseline",)

# XLGMII is omitted: EthMacRxImportXlgmii is a placeholder leaf with no line
# behaviour, this wrapper ties its pins off and there is no XLGMII line model.
# test_EthMacRxImport.py keeps the inert-placeholder check.
PARAMETER_SWEEP = [
    pytest.param({"PHY_TYPE_G": "GMII"}, cocotb_test_filter_excluding(*CLK_EN_TESTS, *XGMII_ONLY_TESTS), id="gmii"),
    pytest.param({"PHY_TYPE_G": "GMII"}, cocotb_test_filter(*SELECTED_CLK_EN_TESTS), id="gmii_clk_en"),
    pytest.param({"PHY_TYPE_G": "XGMII"}, cocotb_test_filter_excluding(*GMII_ONLY_TESTS), id="xgmii"),
]


@pytest.mark.parametrize(("parameters", "test_filter"), PARAMETER_SWEEP)
def test_EthMacRxImportLine(parameters, test_filter):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacimportexportwrapper",
        parameters=parameters,
        extra_env=cocotb_filtered_env(parameters, test_filter),
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
