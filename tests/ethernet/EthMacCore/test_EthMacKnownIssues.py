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
# - Sweep: Focused leaf and EthMacTop PHY wrappers for the reports numbered
#   in README.md. Known failures run only with RUN_KNOWN_ISSUE_TESTS=1 and
#   are skipped by pytest before building otherwise. Promote each reproducer
#   with its separate RTL fix. Default recovery scenarios cover reports whose
#   proposed stricter policy is not an established interface requirement.
# - Stimulus / expected failures:
#   #3 fixed: TX oversize followed by three distinct UDP frames must preserve
#       frame/transaction alignment and all recovery lengths/checksums.
#   #5: XGMII RX link loss continues unterminated beats; the full MAC then
#       swallows the first recovery frame while the checksum stage blows off.
#   #4: XGMII TX link loss sends the remaining bytes as a new valid-FCS frame.
#   #13: An outbound EOFE FIFO drop is absent from rxFifoDrop; the unconnected
#        lockup-reset event is not independently reproduced.
#   #7: EOFE TX frames leave with valid FCS (all GMII lengths, XGMII >=57).
#   #8: RX_ER followed by payload 0xD5 inside RX_DV starts a spurious frame.
#   #16 policy candidate: nested XGMII /S/ sweeps both start lanes. Accept
#       salvage or discard, require no clean merged frame and intact recovery.
#   #17 policy candidate: GMII link loss may finish or abort the in-flight
#       frame; require clean recovery and no fabricated valid-FCS fragment.
#       No undocumented abort deadline or link-loss status pulse is required.
# - Checks: exact delivered bytes and EOFE, independent line preamble/FCS/
#   termination/error decoding, status counts where their meaning is defined.
# - Timing: monitors sample rising edges before TPD_G; line and link changes
#   occur on falling edges. Waits are bounded and entrypoints have watchdogs.

from __future__ import annotations

from dataclasses import dataclass
import os
import random

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from tests.common.regression_utils import (
    cocotb_filtered_env,
    cocotb_test_filter,
    hdl_parameters_from,
    run_surf_vhdl_test,
)
from tests.ethernet.EthMacCore.ethmac_line_models import (
    GmiiDriver,
    GmiiMonitor,
    StatusPulseCounter,
    XgmiiDriver,
    XgmiiMonitor,
    gmii_data_offset,
    gmii_symbols,
    random_frame,
    resolved_int,
    xgmii_lanes,
    xgmii_words,
    xgmii_words_from_lanes,
)
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    EmacBeat,
    FlatEmacEndpoint,
    build_ipv4_udp_frame,
    cycle,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
    payload_from_beats,
    send_frame_burst,
    setup_flat_emac_testbench,
)


KNOWN_ISSUE_SKIP = os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1"
SEED = 0x5EED

TXCSUM_WRAPPER = "ethernet/EthMacCore/wrappers/EthMacTxCsumLoopbackWrapper.vhd"
TOP_PHY_WRAPPER = "ethernet/EthMacCore/wrappers/EthMacTopPhyWrapper.vhd"
IMPORT_EXPORT_WRAPPER = "ethernet/EthMacCore/wrappers/EthMacImportExportWrapper.vhd"
RX_FIFO_WRAPPER = "ethernet/EthMacCore/wrappers/EthMacRxFifoWrapper.vhd"

LOCAL_MAC = 0x001122334455

# Link-loss stimulus shared by the importer and EthMacTop RX reproductions:
# the first 200 XGMII lanes of a 400-byte frame (a whole number of 64-bit
# words, so neither an idle nor /T/ reaches the importer before phyReady
# drops), and the nested-/S/ split after about 120 lanes, adjusted so the
# second /S/ lands in the intended lane (0 or 4).
LINK_LOSS_LANES = 200
NESTED_SPLIT_LANES = 120


###############################################################################
# Bench helpers
###############################################################################


@dataclass
class CollectedFrame:
    beats: list[EmacBeat]

    @property
    def payload(self) -> bytes:
        return payload_from_beats(self.beats)

    @property
    def eofe(self) -> int:
        return self.beats[-1].eofe

    def describe(self) -> str:
        last = self.beats[-1]
        return (
            f"len={len(self.payload)} beats={len(self.beats)} sof={self.beats[0].sof} "
            f"eofe={last.eofe} iperr={last.iperr} udperr={last.udperr}"
        )


class EmacFrameCollector:
    """Record every frame on a flattened EMAC output whose TREADY is held high.

    Samples on the rising edge before the registered TPD_G update, so each
    accepted beat is seen once (outputs without TREADY accept every valid
    beat). ``open_beats`` holds beats of a frame whose tLast has not arrived.
    """

    def __init__(self, dut, *, clk, prefix: str = "mAxis"):
        self.clk = clk
        self.endpoint = FlatEmacEndpoint(dut, prefix=prefix)
        self.valid = getattr(dut, f"{prefix}TValid")
        self.frames: list[CollectedFrame] = []
        self.open_beats: list[EmacBeat] = []
        self.total_beats = 0
        self.task = cocotb.start_soon(self._run())

    async def _run(self) -> None:
        """Lifetime agent: collect output frames until the test ends."""
        while True:
            await RisingEdge(self.clk)
            if resolved_int(self.valid) == 0:
                continue
            beat = self.endpoint.snapshot()
            self.total_beats += 1
            self.open_beats.append(beat)
            if beat.last:
                self.frames.append(CollectedFrame(self.open_beats))
                self.open_beats = []

    def describe(self) -> str:
        frames = "; ".join(frame.describe() for frame in self.frames) or "none"
        return f"{len(self.frames)} frame(s) [{frames}], {len(self.open_beats)} beat(s) without tLast pending"


async def wait_until(predicate, *, clk, cycles: int) -> bool:
    """Wait up to ``cycles`` edges for ``predicate``; report whether it held."""
    for _ in range(cycles):
        if predicate():
            return True
        await RisingEdge(clk)
    return predicate()


def describe_bytes(data: bytes, reference: dict[str, bytes]) -> str:
    """Name a frame by matching it, or a tail of it, against the stimulus."""
    for name, frame in reference.items():
        if data == frame:
            return f"{name} (complete)"
        if len(data) > len(frame) and data.endswith(frame):
            return f"{len(data) - len(frame)} leading bytes + {name} (appended)"
        for offset in range(1, len(frame)):
            tail = frame[offset:]
            if data[: len(tail)] == tail and not any(data[len(tail) :]):
                pad = len(data) - len(tail)
                return f"{name}[{offset}:]" + (f" + {pad} zero pad" if pad else "") + " (tail fragment)"
    return f"unrecognised {len(data)}-byte frame"


def describe_header(payload: bytes, reference: dict[str, bytes]) -> str:
    """Identify a delivered UDP frame by its MAC header and report checksums."""
    for name, frame in reference.items():
        if payload[:14] == frame[:14]:
            if payload == frame:
                return f"{name} (intact)"
            ip_len = int.from_bytes(payload[16:18], "big")
            ip_csum = int.from_bytes(payload[24:26], "big")
            exp_len = int.from_bytes(frame[16:18], "big")
            exp_csum = int.from_bytes(frame[24:26], "big")
            return (
                f"{name} with IPv4 length {ip_len} (expected {exp_len}) "
                f"and checksum {ip_csum:#06x} (expected {exp_csum:#06x})"
            )
    return "an unknown frame"


async def start_import_export_bench(dut):
    """Clock, reset and idle line for EthMacImportExportWrapper."""
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        initial_values={
            "ethClkEn": 1,
            "txPhyReady": 1,
            "rxPhyReady": 1,
            "xgmiiRxd": 0x0707070707070707,
            "xgmiiRxc": 0xFF,
            "gmiiRxDv": 0,
            "gmiiRxEr": 0,
            "gmiiRxd": 0,
        },
    )
    return bench


async def start_top_phy_bench(dut) -> tuple[XgmiiDriver, EmacFrameCollector, StatusPulseCounter]:
    """Clocks, reset and quiescent configuration for EthMacTopPhyWrapper."""
    # Independent MAC (156.25 MHz) and primary-stream clocks.
    cocotb.start_soon(Clock(dut.ethClk, 6.4, unit="ns").start())
    cocotb.start_soon(Clock(dut.primClk, 5.0, unit="ns").start())

    # Every testbench-driven input is defined before the first edge; checksum
    # checking, filtering and pause are disabled so only framing is judged.
    FlatEmacEndpoint(dut, prefix="sAxis").set_idle()
    for name, value in {
        "ethRst": 1,
        "primRst": 1,
        "phyReady": 1,
        "mAxisTReady": 1,
        "localMac": mac_config_word_from_wire(LOCAL_MAC),
        "filtEnable": 0,
        "pauseEnable": 0,
        "pauseTime": 1,
        "pauseThresh": 0xFFFF,
        "ipCsumEn": 0,
        "tcpCsumEn": 0,
        "udpCsumEn": 0,
        "dropOnPause": 0,
    }.items():
        getattr(dut, name).setimmediatevalue(value)
    driver = XgmiiDriver(dut, clk=dut.ethClk)
    driver.idle()

    # Hold both resets, release them, and let the FIFOs settle.
    await cycle(dut.ethClk, 8)
    dut.ethRst.value = 0
    dut.primRst.value = 0
    await cycle(dut.ethClk, 40)

    collector = EmacFrameCollector(dut, clk=dut.primClk)
    status = StatusPulseCounter(
        dut.ethClk,
        {"rxCountEn": dut.rxCountEn, "rxCrcErrorCnt": dut.rxCrcErrorCnt, "rxFifoDropCnt": dut.rxFifoDropCnt},
    )
    return driver, collector, status


def top_status(status: StatusPulseCounter) -> str:
    return (
        f"importer rxCountEn={status.counts['rxCountEn']} rxCrcErrorCnt={status.counts['rxCrcErrorCnt']}, "
        f"RX FIFO inbound drops rxFifoDropCnt={status.counts['rxFifoDropCnt']}"
    )


###############################################################################
# Report #3: EthMacTxCsum oversize branch
###############################################################################


@cocotb.test(timeout_time=200, timeout_unit="us")
async def tx_csum_oversize_recovery_test(dut):
    # Start the clock, enable IPv4/UDP insertion and release reset.
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        initial_values={"mAxisTReady": 1, "ipCsumEn": 1, "tcpCsumEn": 0, "udpCsumEn": 1},
    )
    collector = EmacFrameCollector(dut, clk=bench.clk)

    # A 1600-byte frame exceeds the 1500-byte non-jumbo limit; three UDP
    # frames of different length follow with both checksums zeroed so the
    # block must insert per-frame lengths and checksums.
    rng = random.Random(SEED)
    oversize = random_frame(rng, 1600)
    repaired = []
    inputs = []
    for index, length in enumerate((40, 100, 70)):
        fields = dict(
            dst_mac=0x020000000001 + index,
            src_mac=0x0A0000000001,
            src_ip="10.0.0.1",
            dst_ip=f"10.0.0.{10 + index}",
            src_port=0x1000 + index,
            dst_port=0x2000 + index,
            payload=bytes(rng.getrandbits(8) for _ in range(length)),
        )
        repaired.append(build_ipv4_udp_frame(**fields))
        inputs.append(build_ipv4_udp_frame(**fields, ip_checksum_override=0, udp_checksum_override=0))

    frames = [frame_beats_from_bytes(oversize)] + [frame_beats_from_bytes(frame) for frame in inputs]
    await send_frame_burst(bench.source, frames, clk=bench.clk, inter_frame_gap_cycles=4)
    await wait_until(lambda: len(collector.frames) >= len(repaired), clk=bench.clk, cycles=2000)
    await cycle(bench.clk, 200)

    # Expected: the oversize frame is dropped and every good frame emerges
    # intact with the checksums computed for that frame.
    delivered = [frame.payload for frame in collector.frames]
    names = {f"good{index}": frame for index, frame in enumerate(repaired)}
    observed = "; ".join(
        f"{frame.describe()} looks like {describe_header(frame.payload, names)}" for frame in collector.frames
    ) or "none"
    assert delivered == repaired and all(frame.eofe == 0 for frame in collector.frames), (
        "Report #3: oversize TX must not consume a recovery frame or its checksum metadata. "
        f"seed={SEED:#x}; expected good0, good1, good2 intact; delivered {observed}"
    )


###############################################################################
# Reports #5 and #16: EthMacRxImportXgmii phyReady loss and nested /S/
###############################################################################


@cocotb.test(skip=KNOWN_ISSUE_SKIP, timeout_time=100, timeout_unit="us")
async def rx_xgmii_import_link_loss_emits_beats_known_issue_test(dut):
    bench = await start_import_export_bench(dut)
    driver = XgmiiDriver(dut, clk=bench.clk)
    collector = EmacFrameCollector(dut, clk=bench.clk)
    rng = random.Random(SEED + 1)
    interrupted = random_frame(rng, 400)
    recovery = random_frame(rng, 100, src_mac=0x660000000001)

    # Part of a frame, then phyReady drops on the same falling edge that the
    # line goes idle.
    partial = xgmii_lanes(interrupted, terminate=False)[:LINK_LOSS_LANES]
    await driver.send(xgmii_words_from_lanes(partial, ifg=0))
    dut.rxPhyReady.value = 0

    # Allow 16 clocks for the importer pipeline to close the frame, then
    # count every beat it emits during the rest of a 200-clock outage.
    await cycle(bench.clk, 16)
    closed = list(collector.frames)
    beats_before = collector.total_beats
    await cycle(bench.clk, 184)
    outage_beats = collector.total_beats - beats_before
    await FallingEdge(bench.clk)
    dut.rxPhyReady.value = 1
    await cycle(bench.clk, 20)

    # A good frame after recovery.
    await driver.send(xgmii_words(recovery))
    await cycle(bench.clk, 100)

    # Expected: the interrupted frame is closed (tLast with EOFE) shortly
    # after phyReady drops, nothing is emitted while the link is down, and
    # the recovery frame is delivered on its own.
    interrupted_closed = len(closed) == 1 and closed[0].eofe == 1
    recovered = [frame for frame in collector.frames if frame.payload == recovery and frame.eofe == 0]
    observed = "; ".join(
        f"{describe_bytes(frame.payload, {'recovery': recovery})} eofe={frame.eofe}" for frame in collector.frames
    ) or "none"
    assert interrupted_closed and outage_beats == 0 and len(recovered) == 1, (
        "Known defect (EthMacRxImportXgmii phyReady loss): phyReady clears the frame and "
        "CRC pipeline but not intAdvance, so the importer keeps emitting beats with no "
        "tLast and merges them with the next frame. "
        f"seed={SEED + 1:#x}; interrupted frame closed within 16 clocks: "
        f"{interrupted_closed}; beats emitted during the next 184 link-down clocks: "
        f"{outage_beats}; importer frames: [{observed}]"
    )


@cocotb.test(timeout_time=100, timeout_unit="us")
async def rx_xgmii_import_nested_start_recovery_test(dut):
    bench = await start_import_export_bench(dut)
    driver = XgmiiDriver(dut, clk=bench.clk)
    collector = EmacFrameCollector(dut, clk=bench.clk)
    status = StatusPulseCounter(bench.clk, {"rxCountEn": dut.rxCountEn, "rxCrcError": dut.rxCrcError})
    rng = random.Random(SEED + 2)

    # Every /S/ lane pairing: the first frame starts in lane 0 or 4 and the
    # nested /S/ lands in lane 0 or 4 after about 120 lanes (no /T/).
    failures = []
    for first_lane, nested_lane in ((0, 0), (0, 4), (4, 0), (4, 4)):
        interrupted = random_frame(rng, 200)
        nested = random_frame(rng, 100, src_mac=0x660000000003)
        split = NESTED_SPLIT_LANES + (nested_lane - first_lane)
        lanes = xgmii_lanes(interrupted, terminate=False)[:split] + xgmii_lanes(nested)
        frames_before = len(collector.frames)
        status_before = status.snapshot()
        await driver.send(xgmii_words_from_lanes(lanes, start_lane=first_lane))
        await cycle(bench.clk, 40)

        # The malformed sequence may be discarded or salvaged. It must not
        # become a clean merged frame or poison the next normally framed input.
        recovery = random_frame(rng, 80)
        await driver.send(xgmii_words(recovery))
        await cycle(bench.clk, 40)
        frames = collector.frames[frames_before:]
        good = [frame.payload for frame in frames if frame.eofe == 0]
        if good not in ([recovery], [nested, recovery]) or collector.open_beats:
            observed = "; ".join(
                f"{describe_bytes(frame.payload, {'nested': nested})} eofe={frame.eofe}" for frame in frames
            ) or "none"
            failures.append(
                f"first /S/ lane {first_lane}, nested /S/ lane {nested_lane}: importer frames [{observed}], "
                f"status {status.delta(status_before)}"
            )

    assert not failures, "Nested /S/ broke clean recovery: " + " | ".join(failures)


@cocotb.test(skip=KNOWN_ISSUE_SKIP, timeout_time=300, timeout_unit="us")
async def rx_xgmii_top_link_loss_swallows_next_frame_known_issue_test(dut):
    driver, collector, status = await start_top_phy_bench(dut)
    rng = random.Random(SEED + 1)
    interrupted = random_frame(rng, 400)
    first_good = random_frame(rng, 100, src_mac=0x660000000001)
    second_good = random_frame(rng, 80, src_mac=0x660000000002)

    # Part of a frame, then phyReady drops on the same falling edge that the
    # line goes idle.
    partial = xgmii_lanes(interrupted, terminate=False)[:LINK_LOSS_LANES]
    await driver.send(xgmii_words_from_lanes(partial, ifg=0))
    dut.phyReady.value = 0

    # Hold the link down for longer than 1500 bytes of importer output
    # (8 bytes per clock) so EthMacRxCsum reaches its oversize blow-off.
    await cycle(dut.ethClk, 400)
    await FallingEdge(dut.ethClk)
    dut.phyReady.value = 1
    await cycle(dut.ethClk, 20)

    # Two good frames after recovery.
    await driver.send(xgmii_words(first_good))
    await driver.send(xgmii_words(second_good))
    await wait_until(lambda: len(collector.frames) >= 2, clk=dut.primClk, cycles=3000)
    await cycle(dut.primClk, 300)

    # Expected: the interrupted frame is ended with EOFE (and dropped by the
    # error-dropping FIFO); both good frames are delivered intact.
    delivered = [frame.payload for frame in collector.frames]
    names = {"first_good": first_good, "second_good": second_good}
    observed = "; ".join(describe_bytes(payload, names) for payload in delivered) or "none"
    assert delivered == [first_good, second_good], (
        "Known defect (EthMacRxImportXgmii phyReady loss + EthMacRxCsum blow-off): the "
        "importer keeps emitting beats without tLast after phyReady drops, EthMacRxCsum "
        "closes them at 1500 bytes and its BLOWOFF_S swallows the next frame. "
        f"seed={SEED + 1:#x}; expected [first_good, second_good]; delivered [{observed}] "
        f"({collector.describe()}); {top_status(status)}"
    )


@cocotb.test(timeout_time=300, timeout_unit="us")
async def rx_xgmii_top_nested_start_recovery_test(dut):
    driver, collector, status = await start_top_phy_bench(dut)
    rng = random.Random(SEED + 2)
    interrupted = random_frame(rng, 200)
    nested = random_frame(rng, 100, src_mac=0x660000000003)
    following = random_frame(rng, 80, src_mac=0x660000000004)

    # The first frame starts in lane 4 and, without /T/, is followed by the
    # nested frame's /S/ in lane 0 (the alignment at which the importer
    # appends), then a normally framed third frame.
    lanes = xgmii_lanes(interrupted, terminate=False)[: NESTED_SPLIT_LANES - 4] + xgmii_lanes(nested)
    await driver.send(xgmii_words_from_lanes(lanes, start_lane=4))
    await driver.send(xgmii_words(following))
    recovered = await wait_until(lambda: any(frame.payload == following for frame in collector.frames),
                                 clk=dut.primClk, cycles=3000)
    assert recovered, "nested /S/ prevented the following frame from recovering"
    await cycle(dut.primClk, 300)

    # A nested start is malformed; either salvage or discard is acceptable.
    # With error dropping enabled, only intact frames may be delivered.
    delivered = [frame.payload for frame in collector.frames]
    assert delivered in ([following], [nested, following]), collector.describe()
    assert not collector.open_beats, collector.describe()
    assert all(frame.eofe == 0 for frame in collector.frames), collector.describe()


###############################################################################
# Report #4: EthMacTxExportXgmii phyReady loss
###############################################################################


@cocotb.test(skip=KNOWN_ISSUE_SKIP, timeout_time=200, timeout_unit="us")
async def tx_xgmii_link_loss_sends_valid_fragment_known_issue_test(dut):
    bench = await start_import_export_bench(dut)
    monitor = XgmiiMonitor(dut, clk=bench.clk)
    rng = random.Random(SEED + 3)
    interrupted = random_frame(rng, 512)
    recovery = random_frame(rng, 100, src_mac=0x660000000005)

    # Queue the long frame and wait for its /S/ on the line.
    send_task = cocotb.start_soon(
        send_frame_burst(bench.source, [frame_beats_from_bytes(interrupted)], clk=bench.clk)
    )
    started = await wait_until(
        lambda: (resolved_int(dut.xgmiiTxc) & 1) == 1 and (resolved_int(dut.xgmiiTxd) & 0xFF) == 0xFB,
        clk=bench.clk,
        cycles=200,
    )
    assert started, "Bench: the exporter never started the long frame"

    # Ten words into the frame, take the link down for 50 clocks.
    await cycle(bench.clk, 10)
    dut.txPhyReady.value = 0
    await cycle(bench.clk, 50)
    dut.txPhyReady.value = 1
    await send_task

    # A recovery frame after the link returns.
    await send_frame_burst(bench.source, [frame_beats_from_bytes(recovery)], clk=bench.clk)
    await cycle(bench.clk, 300)

    # Expected: nothing with a valid FCS appears on the line except complete
    # submitted frames, and the recovery frame is transmitted intact.
    names = {"interrupted": interrupted, "recovery": recovery}
    valid = [frame for frame in monitor.frames if frame.fcs_ok and frame.preamble_ok and frame.terminated and not frame.error]
    fragments = [frame for frame in valid if frame.frame not in (interrupted, recovery)]
    recovered = [frame for frame in valid if frame.frame == recovery]
    line = "; ".join(
        f"{describe_bytes(frame.frame, names)} fcs_ok={frame.fcs_ok} terminated={frame.terminated} error={frame.error}"
        for frame in monitor.frames
    )
    assert not fragments and len(recovered) == 1, (
        "Known defect (EthMacTxExportXgmii phyReady loss): the remainder of the frame "
        "interrupted by link loss is sent after the link returns as a fresh frame with a "
        f"correct FCS. seed={SEED + 3:#x}; line frames: [{line}]"
    )


###############################################################################
# Report #17: EthMacTxExportGmii phyReady loss
###############################################################################

@cocotb.test(timeout_time=200, timeout_unit="us")
async def tx_gmii_link_loss_recovery_test(dut):
    bench = await start_import_export_bench(dut)
    monitor = GmiiMonitor(dut, clk=bench.clk)
    status = StatusPulseCounter(bench.clk, {"txLinkNotReady": dut.txLinkNotReady, "txCountEn": dut.txCountEn})
    rng = random.Random(SEED + 4)
    frame = random_frame(rng, 300)

    # Queue a 300-byte frame and wait for TX_EN.
    send_task = cocotb.start_soon(send_frame_burst(bench.source, [frame_beats_from_bytes(frame)], clk=bench.clk))
    started = await wait_until(lambda: resolved_int(dut.gmiiTxEn) == 1, clk=bench.clk, cycles=200)
    assert started, "Bench: the exporter never raised TX_EN"

    # 40 octets into the frame (past the SFD), drop phyReady and keep it low.
    await cycle(bench.clk, 40)
    dut.txPhyReady.value = 0
    drop_cycle = monitor.cycle
    await send_task
    await wait_until(lambda: len(monitor.frames) >= 1, clk=bench.clk, cycles=1000)
    await cycle(bench.clk, 50)
    assert monitor.frames, "Bench: no GMII frame was decoded"

    # No abort latency is specified for GMII. Accept completion or abort of
    # the original frame, then require an intact new frame after link recovery.
    line = monitor.frames[0]
    dut._log.info("report #17: complete=%s clocks_after_drop=%d not_ready=%d",
                  line.frame == frame, line.end_cycle - drop_cycle, status.counts["txLinkNotReady"])
    await FallingEdge(bench.clk)
    dut.txPhyReady.value = 1
    recovery = random_frame(rng, 80, src_mac=0x660000000009)
    await send_frame_burst(bench.source, [frame_beats_from_bytes(recovery)], clk=bench.clk)
    await cycle(bench.clk, 200)
    valid = [item.frame for item in monitor.frames
             if item.preamble_ok and item.fcs_ok and item.terminated and not item.error]
    assert valid in ([recovery], [frame, recovery]), "GMII link loss fabricated a frame or lost recovery"
    assert not monitor.frame_pending, "GMII recovery left an unterminated frame"


###############################################################################
# Report #13: EthMacRxFifo drop status
###############################################################################


@cocotb.test(skip=KNOWN_ISSUE_SKIP, timeout_time=100, timeout_unit="us")
async def rx_fifo_outbound_drop_not_counted_known_issue_test(dut):
    # Distinct write and read clocks, link up, sink always ready.
    cocotb.start_soon(Clock(dut.sClk, 4.0, unit="ns").start())
    cocotb.start_soon(Clock(dut.mPrimClk, 6.0, unit="ns").start())
    source = FlatEmacEndpoint(dut, prefix="sAxis")
    source.set_idle()
    for name, value in {"sRst": 1, "mPrimRst": 1, "phyReady": 1, "pauseThresh": 0xFFFF, "mAxisTReady": 1}.items():
        getattr(dut, name).setimmediatevalue(value)
    await cycle(dut.sClk, 8)
    dut.sRst.value = 0
    dut.mPrimRst.value = 0
    await cycle(dut.sClk, 8)

    collector = EmacFrameCollector(dut, clk=dut.mPrimClk)
    status = StatusPulseCounter(dut.sClk, {"rxFifoDrop": dut.rxFifoDrop})

    # Good frame, frame closed with EOFE, good frame.
    rng = random.Random(SEED + 5)
    first = random_frame(rng, 64)
    errored = random_frame(rng, 96, src_mac=0x660000000006)
    last = random_frame(rng, 80, src_mac=0x660000000007)
    beats = [
        frame_beats_from_bytes(first),
        frame_beats_from_bytes(errored, eofe=1),
        frame_beats_from_bytes(last),
    ]
    await send_frame_burst(source, beats, clk=dut.sClk, inter_frame_gap_cycles=2)
    await wait_until(lambda: len(collector.frames) >= 2, clk=dut.mPrimClk, cycles=500)
    await cycle(dut.mPrimClk, 50)

    # The error frame itself must be dropped (this part works today).
    delivered = [frame.payload for frame in collector.frames]
    assert delivered == [first, last], f"Bench: unexpected RX FIFO output {collector.describe()}"

    # Expected: the outbound EOFE drop pulses rxFifoDrop exactly once.
    assert status.counts["rxFifoDrop"] == 1, (
        "Known defect (EthMacRxFifo drop status): SsiFifo's mAxisDropFrame and "
        "lockupRstEvent are left unconnected, so an EOFE frame dropped by the outbound "
        "filter is not counted. "
        f"seed={SEED + 5:#x}; EOFE frame dropped, rxFifoDrop pulses={status.counts['rxFifoDrop']} (expected 1)"
    )


###############################################################################
# Report #7: EOFE frames leave the exporter with a valid FCS
###############################################################################

EOFE_LENGTHS = {
    # XGMII: every length across the 60-byte pad boundary and the first few
    # 64-bit words, plus 128-bit beat boundaries and the maximum.
    "XGMII": list(range(14, 81)) + [100, 120, 127, 128, 129, 130, 135, 136, 137, 143, 144, 200, 255, 256, 257, 1514],
    "GMII": [14, 40, 59, 60, 61, 64, 100, 128, 129, 300],
}


def length_ranges(lengths: list[int]) -> str:
    """Compress sorted lengths into 'a-b' ranges."""
    ranges = []
    for length in sorted(lengths):
        if ranges and length == ranges[-1][1] + 1:
            ranges[-1][1] = length
        else:
            ranges.append([length, length])
    return ", ".join(f"{low}" if low == high else f"{low}-{high}" for low, high in ranges) or "none"


@cocotb.test(skip=KNOWN_ISSUE_SKIP, timeout_time=500, timeout_unit="us")
async def tx_eofe_frame_leaves_with_valid_fcs_known_issue_test(dut):
    phy = os.environ["PHY_TYPE_G"]
    bench = await start_import_export_bench(dut)
    monitor = XgmiiMonitor(dut, clk=bench.clk) if phy == "XGMII" else GmiiMonitor(dut, clk=bench.clk)
    rng = random.Random(SEED + 6)

    # Every frame is closed with EOFE on its last beat, as EthMacTx forwards
    # it with DROP_ERR_PKT_G=false. Frames go back-to-back.
    lengths = EOFE_LENGTHS[phy]
    frames = [random_frame(rng, length) for length in lengths]
    await send_frame_burst(bench.source, [frame_beats_from_bytes(frame, eofe=1) for frame in frames], clk=bench.clk)
    per_frame = 90 if phy == "XGMII" else 1600
    await wait_until(lambda: len(monitor.frames) >= len(frames), clk=bench.clk, cycles=per_frame * len(frames))
    await cycle(bench.clk, 100)
    assert len(monitor.frames) == len(frames), (
        f"Bench: {len(monitor.frames)} line frames decoded for {len(frames)} submitted"
    )

    # Expected: every EOFE frame that reaches the line carries an invalid FCS
    # (or /E/ / TX_ER), so no receiver accepts it.
    # The bench check compares only the leading bytes: the XGMII error path
    # overwrites the last pad octets with the inverted FCS, and the GMII
    # exporter pads short frames to 61 octets (baseline behaviour owned by
    # test_EthMacTxExportLine).
    valid_fcs = []
    for length, frame, line in zip(lengths, frames, monitor.frames, strict=True):
        prefix = min(len(frame), 56)
        assert line.preamble_ok and line.frame[:prefix] == frame[:prefix], (
            f"Bench: line frame for length {length} does not start with the submitted payload"
        )
        if line.fcs_ok and not line.error:
            valid_fcs.append(length)
    assert not valid_fcs, (
        f"Known defect (EthMacTxExport{'Gmii' if phy == 'GMII' else 'Xgmii'} EOFE): "
        + (
            "EthMacTxExportGmii never looks at EOFE, so an EOFE frame leaves with a valid FCS. "
            if phy == "GMII"
            else "when tLast falls on the 8th or later 64-bit word (ST_READ_C, exportWordCnt >= 7) "
            "intLastLine is set in the same cycle that EOFE is ORed into nxtError, so the FCS "
            "mask is chosen from the old intError and the EOFE is lost; only frames finished "
            "through ST_PAD_C (<= 56 bytes) get the inverted FCS. "
        )
        + f"seed={SEED + 6:#x}; EOFE frames with a valid FCS on the line, by length (bytes "
        f"without FCS): {length_ranges(valid_fcs)}; tested lengths: {length_ranges(lengths)}"
    )


###############################################################################
# Report #8: EthMacRxImportGmii re-arms its SFD search while RX_DV is high
###############################################################################


@cocotb.test(skip=KNOWN_ISSUE_SKIP, timeout_time=200, timeout_unit="us")
async def rx_gmii_import_sfd_rearm_after_rx_er_known_issue_test(dut):
    bench = await start_import_export_bench(dut)
    driver = GmiiDriver(dut, clk=bench.clk, prefix="gmiiRx")
    driver.idle()
    collector = EmacFrameCollector(dut, clk=bench.clk)
    status = StatusPulseCounter(bench.clk, {"rxCountEn": dut.rxCountEn, "rxCrcError": dut.rxCrcError})
    rng = random.Random(SEED + 7)

    # A 200-byte frame with RX_ER on data octet 40 and the only 0xD5 of the
    # frame at data byte 120, then a clean frame with no 0xD5 octet.
    errored = bytearray(bytes(0xD4 if byte == 0xD5 else byte for byte in random_frame(rng, 200)))
    errored[120] = 0xD5
    clean = bytes(0xD4 if byte == 0xD5 else byte for byte in random_frame(rng, 100, src_mac=0x660000000008))
    await driver.send(gmii_symbols(bytes(errored), er_at=gmii_data_offset() + 40))
    await cycle(bench.clk, 40)
    errored_frames = list(collector.frames)
    errored_status = status.snapshot()
    await driver.send(gmii_symbols(clean))
    await wait_until(lambda: len(collector.frames) > len(errored_frames), clk=bench.clk, cycles=300)
    await cycle(bench.clk, 20)

    # Expected: one EOFE frame for the RX_ER abort, no further frame until
    # RX_DV drops, then the clean frame intact.
    clean_frames = [frame for frame in collector.frames if frame.payload == clean and frame.eofe == 0]
    observed = "; ".join(
        f"{frame.describe()} starts at errored[{bytes(errored).find(frame.payload[:8])}]"
        if frame.payload[:8] and bytes(errored).find(frame.payload[:8]) >= 0
        else frame.describe()
        for frame in errored_frames
    ) or "none"
    assert len(errored_frames) == 1 and errored_frames[0].eofe == 1 and len(clean_frames) == 1, (
        "Known defect (EthMacRxImportGmii SFD re-arm): after an RX_ER abort the importer "
        "returns to WAIT_SFD_S while RX_DV is still high, so a later 0xD5 octet in the same "
        "frame starts a second, spurious frame. "
        f"seed={SEED + 7:#x}; frames emitted for the RX_ER frame: {len(errored_frames)} [{observed}]; "
        f"status during it {errored_status}; clean frame delivered: {len(clean_frames) == 1}"
    )


###############################################################################
# pytest wrappers
###############################################################################


KNOWN_ISSUE_CASES = [
    pytest.param(
        "surf.ethmacimportexportwrapper",
        IMPORT_EXPORT_WRAPPER,
        {"PHY_TYPE_G": "XGMII"},
        (
            "rx_xgmii_import_link_loss_emits_beats_known_issue_test",
            "tx_xgmii_link_loss_sends_valid_fragment_known_issue_test",
            "tx_eofe_frame_leaves_with_valid_fcs_known_issue_test",
        ),
        id="xgmii_import_export",
    ),
    pytest.param(
        "surf.ethmactopphywrapper",
        TOP_PHY_WRAPPER,
        {"PHY_TYPE_G": "XGMII", "JUMBO_G": "false"},
        (
            "rx_xgmii_top_link_loss_swallows_next_frame_known_issue_test",
        ),
        id="rx_xgmii_top",
    ),
    pytest.param(
        "surf.ethmacimportexportwrapper",
        IMPORT_EXPORT_WRAPPER,
        {"PHY_TYPE_G": "GMII"},
        (
            "tx_eofe_frame_leaves_with_valid_fcs_known_issue_test",
            "rx_gmii_import_sfd_rearm_after_rx_er_known_issue_test",
        ),
        id="gmii_import_export",
    ),
    pytest.param(
        "surf.ethmacrxfifowrapper",
        RX_FIFO_WRAPPER,
        {"DROP_ERR_PKT_G": "true"},
        ("rx_fifo_outbound_drop_not_counted_known_issue_test",),
        id="rx_fifo_outbound_drop",
    ),
]


@pytest.mark.parametrize("toplevel, wrapper, parameters, entrypoints", KNOWN_ISSUE_CASES)
def test_EthMacKnownIssues(toplevel, wrapper, parameters, entrypoints):
    if KNOWN_ISSUE_SKIP:
        pytest.skip("unresolved RTL reports; set RUN_KNOWN_ISSUE_TESTS=1")
    _run_case(toplevel, wrapper, parameters, entrypoints)


FIXED_ISSUE_CASES = [
    pytest.param(
        "surf.ethmactxcsumloopbackwrapper",
        TXCSUM_WRAPPER,
        {"JUMBO_G": "false"},
        ("tx_csum_oversize_recovery_test",),
        id="txcsum_oversize",
    ),
]


@pytest.mark.parametrize("toplevel, wrapper, parameters, entrypoints", FIXED_ISSUE_CASES)
def test_EthMacFixedIssues(toplevel, wrapper, parameters, entrypoints):
    _run_case(toplevel, wrapper, parameters, entrypoints)


RECOVERY_CASES = [
    pytest.param("surf.ethmacimportexportwrapper", IMPORT_EXPORT_WRAPPER, {"PHY_TYPE_G": "XGMII"},
                 ("rx_xgmii_import_nested_start_recovery_test",), id="xgmii_nested_start"),
    pytest.param("surf.ethmactopphywrapper", TOP_PHY_WRAPPER, {"PHY_TYPE_G": "XGMII", "JUMBO_G": "false"},
                 ("rx_xgmii_top_nested_start_recovery_test",), id="xgmii_top_nested_start"),
    pytest.param("surf.ethmacimportexportwrapper", IMPORT_EXPORT_WRAPPER, {"PHY_TYPE_G": "GMII"},
                 ("tx_gmii_link_loss_recovery_test",), id="gmii_link_loss"),
]


@pytest.mark.parametrize("toplevel, wrapper, parameters, entrypoints", RECOVERY_CASES)
def test_EthMacRecoveryPolicy(toplevel, wrapper, parameters, entrypoints):
    _run_case(toplevel, wrapper, parameters, entrypoints)


def _run_case(toplevel, wrapper, parameters, entrypoints):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel=toplevel,
        parameters=hdl_parameters_from(parameters),
        extra_env=cocotb_filtered_env(parameters, cocotb_test_filter(*entrypoints)),
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [wrapper]},
    )
