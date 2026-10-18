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
# - Sweep: A curated EthMacTop generic matrix on GMII and XGMII: the entity
#   defaults; filter plus pause with a common primary clock; bypass with an
#   asynchronous bypass clock; an asynchronous, slower primary clock;
#   `DROP_ERR_PKT_G = false`; jumbo frames; and a small RX FIFO forced to
#   overflow. Each case has a fixed seed. `RUN_ETHMAC_EXTENDED_TESTS=1` adds a
#   soak with more frames and several seeds per case, plus a GMII 1-in-10
#   `ethClkEn` (100 Mb/s) TX case.
# - Stimulus: Independent seeded random traffic in both directions through
#   EthMacTopPhyWrapper, whose PHY transmit and receive pins are separate. TX
#   frames enter the primary (and bypass) AXI Stream inputs with random
#   lengths, input gaps and EOFE; RX frames are driven onto the line with good
#   or bad FCS, GMII RX_ER, pause frames, foreign/multicast/broadcast
#   destinations and the bypass EtherType, with random sink backpressure.
#   Traffic runs in bursts separated by `phyReady` low windows while both
#   directions are idle. A second scenario asserts every reset mid-traffic.
# - Checks: Every frame carries a stream/epoch/sequence tag. A reference model
#   gives each frame's expected disposition: delivered intact, delivered with
#   EOFE, or dropped. Line frames must have a valid preamble and FCS, the
#   PHY's minimum-size padding, the expected order per stream and nothing
#   untagged except MAC-generated pause frames carrying `pauseTime`. Status
#   pulses are counted exactly (`txCountEn`, `rxCountEn`, `rxCrcErrorCnt`,
#   `rxPauseCnt`, `txPauseCnt`, no underrun or not-ready). Only the small-FIFO
#   case may lose deliverable frames, and each loss must be covered by a
#   `rxFifoDropCnt` pulse. After a reset no frame from before it may appear,
#   and traffic after it must be exact. Failures report seed and frame index.
# - Timing: All waits are bounded by frame-count-scaled cycle limits; monitors
#   sample accepted handshakes and PHY pins on rising edges before the DUT's
#   `TPD_G` update, and stimulus changes on falling edges.
#
# Known defects kept out of the default run (see the EthMacCore test README):
# `phyReady` changes only while both directions are idle, because mid-frame
# link loss reaches the XGMII importer/exporter and GMII exporter defects; TX
# frames never exceed the checksum stage's size limit; and EOFE TX frames are
# not sent on GMII with `DROP_ERR_PKT_G = false`, whose exporter ignores EOFE.

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
    env_flag,
    env_int,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)
from tests.ethernet.EthMacCore.ethmac_line_models import (
    GmiiDriver,
    GmiiMonitor,
    StatusPulseCounter,
    XgmiiDriver,
    XgmiiMonitor,
    describe_case,
    fcs_bytes,
    gmii_data_offset,
    gmii_symbols,
    resolved_int,
    xgmii_words,
)
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    build_ethernet_frame,
    build_pause_frame,
    mac_config_word_from_wire,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTopPhyWrapper.vhd"

LOCAL_MAC = 0x001122334455
FOREIGN_MAC = 0x00AABBCCDDEE
MULTICAST_MAC = 0x01005E000001
BROADCAST_MAC = 0xFFFFFFFFFFFF
REMOTE_MAC = 0x660102030405
DATA_ETHERTYPE = 0x88B5
BYPASS_ETHERTYPE = 0x88B6
# EthMacRxBypass compares tData(111 downto 96), the EtherType in lane order
# (byte 12 in the low octet), so the generic takes the byte-swapped value.
BYPASS_ETHERTYPE_GENERIC = 0xB688
PAUSE_DST = bytes.fromhex("0180C2000001")
TAG_MARKER = 0xA5
TAG_BYTES = 7
STREAM_TX_PRIM, STREAM_TX_BYP, STREAM_RX = 0, 1, 2
STATUS_NAMES = (
    "rxFifoDropCnt",
    "rxPauseCnt",
    "txPauseCnt",
    "rxCountEn",
    "rxOverFlow",
    "rxCrcErrorCnt",
    "txCountEn",
    "txUnderRunCnt",
    "txNotReadyCnt",
)


###############################################################################
# Configuration
###############################################################################


@dataclass
class TopConfig:
    phy: str
    seed: int
    frames: int
    bursts: int
    filt_en: bool
    pause_en: bool
    drop_err: bool
    jumbo: bool
    fifo_addr_width: int
    prim_common: bool
    byp_en: bool
    jumbo_frames: bool
    eth_period: float
    prim_period: float
    byp_period: float
    clk_en_div: int
    backpressure: float
    pause_thresh: int
    rx_traffic: bool

    @classmethod
    def from_env(cls) -> "TopConfig":
        phy = os.environ["PHY_TYPE_G"]
        eth_period = 8.0 if phy == "GMII" else 6.4
        return cls(
            phy=phy,
            seed=env_int("SEED", default=1),
            frames=env_int("FRAMES", default=120),
            bursts=env_int("BURSTS", default=3),
            filt_en=env_flag("FILT_EN_G", default=False),
            pause_en=env_flag("PAUSE_EN_G", default=True),
            drop_err=env_flag("DROP_ERR_PKT_G", default=True),
            jumbo=env_flag("JUMBO_G", default=True),
            fifo_addr_width=env_int("FIFO_ADDR_WIDTH_G", default=11),
            prim_common=env_flag("PRIM_COMMON_CLK_G", default=False),
            byp_en=env_flag("BYP_EN_G", default=False),
            jumbo_frames=env_flag("JUMBO_FRAMES", default=False),
            eth_period=eth_period,
            prim_period=float(os.environ.get("PRIM_PERIOD_NS", eth_period)),
            byp_period=float(os.environ.get("BYP_PERIOD_NS", 9.1)),
            clk_en_div=env_int("CLK_EN_DIV", default=1),
            backpressure=float(os.environ.get("BACKPRESSURE", "0.2")),
            pause_thresh=env_int("PAUSE_THRESH", default=9000 // 16),
            rx_traffic=env_flag("RX_TRAFFIC", default=True),
        )


###############################################################################
# Frames and expectations
###############################################################################


@dataclass
class Expected:
    stream: int
    epoch: int
    seq: int
    kind: str
    frame: bytes
    eofe: int = 0
    deliver: str | None = None  # "prim", "byp", "line" or None (dropped)
    prefix_only: bool = False  # truncated delivery (GMII RX_ER) is allowed
    seen: bool = False


def tag(stream: int, epoch: int, seq: int) -> bytes:
    return bytes([TAG_MARKER, stream, epoch]) + seq.to_bytes(4, "big")


def parse_tag(frame: bytes) -> tuple[int, int, int] | None:
    if len(frame) < 14 + TAG_BYTES or frame[14] != TAG_MARKER:
        return None
    return frame[15], frame[16], int.from_bytes(frame[17:21], "big")


def tagged_frame(rng: random.Random, length: int, *, dst: int, src: int, eth_type: int, stream: int, epoch: int, seq: int) -> bytes:
    body = tag(stream, epoch, seq)
    body += bytes(rng.getrandbits(8) for _ in range(max(0, length - 14 - len(body))))
    return build_ethernet_frame(dst_mac=dst, src_mac=src, eth_type=eth_type, payload=body)


def random_length(rng: random.Random, cfg: TopConfig) -> int:
    roll = rng.random()
    if cfg.jumbo_frames and roll < 0.3:
        return rng.randint(1515, 9000)
    if roll < 0.15:
        return rng.randint(14 + TAG_BYTES, 59)
    if roll < 0.65:
        return rng.randint(60, 128)
    if roll < 0.9:
        return rng.randint(129, 600)
    return rng.randint(601, 1514)


def gmii_wire_tail(frame: bytes, er_at: int) -> bytes:
    """Wire octets after index ``er_at`` (preamble/SFD included in indexing)."""
    return (bytes([0x55] * 7 + [0xD5]) + frame + fcs_bytes(frame))[er_at + 1 :]


def padded_line_frame(phy: str, frame: bytes) -> bytes:
    """Expected frame on the line (without FCS) for a transmitted frame.

    XGMII pads to the 60-byte minimum. The GMII exporter pads short frames to
    61 bytes (one octet beyond the minimum); that is current baseline
    behaviour of EthMacTxExportGmii's pad counter, still a valid frame.
    """
    if len(frame) >= 60:
        return frame
    return frame + bytes((61 if phy == "GMII" else 60) - len(frame))


###############################################################################
# Bench
###############################################################################


class TopBench:
    def __init__(self, dut, cfg: TopConfig):
        self.dut = dut
        self.cfg = cfg
        self.rng = random.Random(cfg.seed)
        self.epoch = 0
        self.expected: dict[tuple[int, int, int], Expected] = {}
        self.tx_order: dict[int, list[tuple[int, int, int]]] = {STREAM_TX_PRIM: [], STREAM_TX_BYP: []}
        self.errors: list[str] = []
        self.delivered = {"prim": [], "byp": []}
        self.pause_frames_on_line = 0
        self.in_reset = False
        self.ignore_line_until = 0
        self.tasks: list = []
        self.seq = 0
        self.rx_pause_sent = 0
        self.line_index = 0
        self.last_sink_activity = 0

    # ----------------------------------------------------------------- setup
    async def start(self) -> None:
        dut, cfg = self.dut, self.cfg
        if cfg.prim_common:
            self.tasks.append(start_lockstep_clocks(dut.ethClk, dut.primClk, period_ns=cfg.eth_period))
        else:
            cocotb.start_soon(Clock(dut.ethClk, cfg.eth_period, unit="ns").start())
            cocotb.start_soon(Clock(dut.primClk, cfg.prim_period, unit="ns").start())
        cocotb.start_soon(Clock(dut.bypClk, cfg.byp_period, unit="ns").start())

        initial = {
            "ethRst": 1,
            "primRst": 1,
            "bypRst": 1,
            "ethClkEn": 1,
            "phyReady": 0,
            "mAxisTReady": 0,
            "mBypTReady": 0,
            "localMac": mac_config_word_from_wire(LOCAL_MAC),
            "filtEnable": 1,
            "pauseEnable": 1,
            "pauseTime": 0x0010,
            "pauseThresh": cfg.pause_thresh,
            "ipCsumEn": 0,
            "tcpCsumEn": 0,
            "udpCsumEn": 0,
            "dropOnPause": 0,
        }
        for name, value in initial.items():
            getattr(dut, name).setimmediatevalue(value)
        for prefix in ("sAxis", "sByp"):
            for suffix, value in (("TValid", 0), ("TData", 0), ("TKeep", 0), ("TLast", 0), ("Sof", 0), ("Eofe", 0)):
                getattr(dut, f"{prefix}{suffix}").setimmediatevalue(value)

        clk_en = None
        if cfg.phy == "GMII":
            dut.gmiiRxDv.setimmediatevalue(0)
            dut.gmiiRxEr.setimmediatevalue(0)
            dut.gmiiRxd.setimmediatevalue(0)
            if cfg.clk_en_div > 1:
                clk_en = dut.ethClkEn
                self.tasks.append(cocotb.start_soon(self._clock_enable()))
            self.line_tx = GmiiMonitor(dut, clk=dut.ethClk, clk_en=clk_en)
            self.line_rx = GmiiDriver(dut, clk=dut.ethClk, clk_en=clk_en)
        else:
            dut.xgmiiRxd.setimmediatevalue(0x0707070707070707)
            dut.xgmiiRxc.setimmediatevalue(0xFF)
            self.line_tx = XgmiiMonitor(dut, clk=dut.ethClk)
            self.line_rx = XgmiiDriver(dut, clk=dut.ethClk)
        self.tasks.append(self.line_tx.task)
        self.status = StatusPulseCounter(dut.ethClk, {name: getattr(dut, name) for name in STATUS_NAMES})
        self.tasks.append(self.status.task)
        self.tasks.append(cocotb.start_soon(self._sink("prim", "mAxis", dut.primClk)))
        if cfg.byp_en:
            self.tasks.append(cocotb.start_soon(self._sink("byp", "mByp", dut.bypClk)))
        await self.reset()
        # PHY outputs are all-zero during reset; judge the line only after it.
        self.ignore_line_until = self.line_tx.cycle
        await self.set_link(1)

    async def eth_cycles(self, count: int) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.ethClk)

    async def _clock_enable(self) -> None:
        """Lifetime agent: drive a 1-in-N ethClkEn pattern until the test ends."""
        count = 0
        while True:
            await FallingEdge(self.dut.ethClk)
            count = (count + 1) % self.cfg.clk_en_div
            self.dut.ethClkEn.value = 1 if count == 0 else 0

    async def reset(self, cycles: int = 16) -> None:
        dut = self.dut
        self.in_reset = True
        await FallingEdge(dut.ethClk)
        dut.ethRst.value = 1
        dut.primRst.value = 1
        dut.bypRst.value = 1
        await self.eth_cycles(cycles)
        self.line_tx.abort()
        await FallingEdge(dut.ethClk)
        dut.ethRst.value = 0
        dut.primRst.value = 0
        dut.bypRst.value = 0
        self.in_reset = False
        await self.eth_cycles(32)

    async def set_link(self, value: int) -> None:
        await FallingEdge(self.dut.ethClk)
        self.dut.phyReady.value = value
        await self.eth_cycles(8)

    # ----------------------------------------------------------------- sinks
    async def _sink(self, name: str, prefix: str, clk) -> None:
        """Lifetime agent: accept outbound frames with random backpressure."""
        dut = self.dut
        ready = getattr(dut, f"{prefix}TReady")
        valid = getattr(dut, f"{prefix}TValid")
        rng = random.Random(self.cfg.seed * 7 + (1 if name == "byp" else 0))
        beats: list[tuple[bytes, int, int]] = []
        while True:
            await FallingEdge(clk)
            if self.in_reset:
                beats = []
                ready.value = 0
                continue
            ready.value = 0 if rng.random() < self.cfg.backpressure else 1
            await RisingEdge(clk)
            if self.in_reset:
                beats = []
                continue
            if resolved_int(valid):
                self.last_sink_activity = self.status.cycle
            if resolved_int(valid) and resolved_int(ready):
                keep = int(getattr(dut, f"{prefix}TKeep").value)
                data = int(getattr(dut, f"{prefix}TData").value).to_bytes(16, "little")
                payload = bytes(data[i] for i in range(16) if (keep >> i) & 1)
                beats.append((payload, int(getattr(dut, f"{prefix}Sof").value), int(getattr(dut, f"{prefix}Eofe").value)))
                if int(getattr(dut, f"{prefix}TLast").value):
                    frame = b"".join(beat[0] for beat in beats)
                    sof_ok = beats[0][1] == 1 and all(beat[1] == 0 for beat in beats[1:])
                    self.delivered[name].append((frame, beats[-1][2], sof_ok))
                    self._check_delivery(name, frame, beats[-1][2], sof_ok)
                    beats = []

    def _check_delivery(self, name: str, frame: bytes, eofe: int, sof_ok: bool) -> None:
        key = parse_tag(frame)
        if not sof_ok:
            self.errors.append(f"{name}: SOF framing wrong for delivered frame {key}")
        if key is None or key not in self.expected:
            # An EOFE frame truncated before its tag is acceptable only where
            # truncation is part of the model (overflow without drop).
            if not (eofe and not self.cfg.drop_err):
                self.errors.append(f"{name}: untagged or unknown delivered frame {frame[:24].hex()} eofe={eofe}")
            return
        exp = self.expected[key]
        where = describe_case(self.cfg.seed, exp.seq, f"stream {exp.stream} epoch {exp.epoch} {exp.kind}")
        if exp.epoch != self.epoch:
            self.errors.append(f"{name}: stale delivery after reset: {where}")
            return
        if exp.seen:
            self.errors.append(f"{name}: duplicate delivery: {where}")
        exp.seen = True
        overflow_ok = self.cfg.fifo_addr_width < 11 and not self.cfg.drop_err
        if exp.deliver != name:
            if overflow_ok and eofe and exp.deliver == name:
                return
            self.errors.append(f"{name}: frame delivered but expected {exp.deliver}: {where}")
            return
        if eofe != exp.eofe and not (overflow_ok and eofe):
            self.errors.append(f"{name}: eofe={eofe} expected {exp.eofe}: {where}")
        if exp.prefix_only:
            # Current GMII importer behaviour for RX_ER at data octet j >= 6:
            # data[0:j-5] followed by a repeat of the previous byte, with EOFE.
            if len(frame) < 2 or not exp.frame.startswith(frame[:-1]) or frame[-1] != frame[-2]:
                self.errors.append(f"{name}: RX_ER delivery is not prefix + repeated byte ({len(frame)} bytes): {where}")
        elif overflow_ok and eofe:
            if not exp.frame.startswith(frame):
                self.errors.append(f"{name}: truncated delivery is not a prefix: {where}")
        elif frame != exp.frame:
            self.errors.append(f"{name}: payload mismatch ({len(frame)} vs {len(exp.frame)} bytes): {where}")

    # ---------------------------------------------------------------- sources
    async def _axis_send(self, prefix: str, clk, frame: bytes, *, eofe: int, gap_prob: float, rng: random.Random) -> None:
        dut = self.dut
        sig = lambda suffix: getattr(dut, f"{prefix}{suffix}")  # noqa: E731
        chunks = [frame[offset : offset + 16] for offset in range(0, len(frame), 16)]
        for index, chunk in enumerate(chunks):
            while rng.random() < gap_prob:
                await FallingEdge(clk)
                sig("TValid").value = 0
                await RisingEdge(clk)
            await FallingEdge(clk)
            if self.in_reset:
                break
            sig("TValid").value = 1
            sig("TData").value = int.from_bytes(chunk.ljust(16, b"\x00"), "little")
            sig("TKeep").value = (1 << len(chunk)) - 1
            sig("TLast").value = int(index == len(chunks) - 1)
            sig("Sof").value = int(index == 0)
            sig("Eofe").value = eofe if index == len(chunks) - 1 else 0
            for _ in range(200_000):
                await RisingEdge(clk)
                if self.in_reset or int(sig("TReady").value):
                    break
            else:
                raise AssertionError(f"{prefix} TREADY timeout")
            if self.in_reset:
                break
        await FallingEdge(clk)
        sig("TValid").value = 0
        sig("TLast").value = 0

    def _new_tx(self, stream: int) -> Expected:
        cfg, rng = self.cfg, self.rng
        self.seq += 1
        eth_type = DATA_ETHERTYPE
        frame = tagged_frame(rng, random_length(rng, cfg), dst=REMOTE_MAC, src=LOCAL_MAC, eth_type=eth_type, stream=stream, epoch=self.epoch, seq=self.seq)
        # EOFE TX frames only where DROP_ERR_PKT_G drops them: when they are
        # forwarded, the exporters can still send a valid FCS (known issue).
        eofe = int(rng.random() < 0.08 and cfg.drop_err)
        deliver = None if (eofe and cfg.drop_err) else "line"
        exp = Expected(stream, self.epoch, self.seq, "tx_eofe" if eofe else "tx", frame, eofe=eofe, deliver=deliver)
        self.expected[(stream, self.epoch, self.seq)] = exp
        if deliver:
            self.tx_order[stream].append((stream, self.epoch, self.seq))
        return exp

    async def tx_source(self, prefix: str, clk, stream: int, count: int) -> None:
        rng = random.Random(self.cfg.seed * 31 + stream + 100 * self.epoch)
        for _ in range(count):
            if self.in_reset:
                return
            exp = self._new_tx(stream)
            await self._axis_send(prefix, clk, exp.frame, eofe=exp.eofe, gap_prob=0.1, rng=rng)
            for _ in range(rng.choice((0, 0, 0, 1, 5, 40))):
                await RisingEdge(clk)

    def _new_rx(self) -> tuple[Expected, list]:
        cfg, rng = self.cfg, self.rng
        self.seq += 1
        kinds = ["good"] * 10 + ["bad_fcs"] * 2 + ["multicast", "broadcast"]
        if cfg.pause_en:
            kinds += ["pause"]
        if cfg.filt_en:
            kinds += ["foreign"] * 2
        if cfg.byp_en:
            kinds += ["bypass"] * 3
        if cfg.phy == "GMII":
            kinds += ["rx_er"]
        kind = rng.choice(kinds)
        dst = {"multicast": MULTICAST_MAC, "broadcast": BROADCAST_MAC, "foreign": FOREIGN_MAC}.get(kind, LOCAL_MAC)
        eth_type = BYPASS_ETHERTYPE if kind == "bypass" else DATA_ETHERTYPE
        length = max(60, random_length(rng, cfg))
        if kind == "pause":
            value = rng.randint(1, 40)
            frame = build_pause_frame(value)
        else:
            frame = tagged_frame(rng, length, dst=dst, src=REMOTE_MAC, eth_type=eth_type, stream=STREAM_RX, epoch=self.epoch, seq=self.seq)
        exp = Expected(STREAM_RX, self.epoch, self.seq, kind, frame)
        if kind in ("good", "multicast", "broadcast"):
            exp.deliver = "prim"
        elif kind == "foreign":
            exp.deliver = None
        elif kind == "bypass":
            exp.deliver = "byp"
        elif kind == "pause":
            exp.deliver = None
        elif kind in ("bad_fcs", "rx_er"):
            exp.deliver = None if cfg.drop_err else "prim"
            exp.eofe = 1
            exp.prefix_only = kind == "rx_er"
        if cfg.phy == "GMII":
            er_at = None
            if kind == "rx_er":
                # The truncated delivery keeps data[0:j-5]; start late enough
                # that it still carries the whole tag.
                er_at = gmii_data_offset() + rng.randint(14 + TAG_BYTES + 6, len(frame) - 1)
                # After an RX_ER abort the GMII importer re-arms its SFD search
                # while RX_DV is high (known issue), so keep 0xD5 out of the
                # octets that follow the error.
                while 0xD5 in gmii_wire_tail(frame, er_at):
                    frame = tagged_frame(rng, len(frame), dst=dst, src=REMOTE_MAC, eth_type=eth_type, stream=STREAM_RX, epoch=self.epoch, seq=self.seq)
                exp.frame = frame
            symbols = gmii_symbols(frame, bad_fcs=kind == "bad_fcs", er_at=er_at, ifg=rng.randint(12, 30))
        else:
            symbols = xgmii_words(frame, bad_fcs=kind == "bad_fcs", start_lane=rng.choice((0, 4)), ifg=rng.randint(12, 30))
        if kind == "pause":
            self.rx_pause_sent += 1
        else:
            self.expected[(STREAM_RX, self.epoch, self.seq)] = exp
        return exp, symbols

    async def rx_source(self, count: int) -> list[Expected]:
        sent = []
        if not self.cfg.rx_traffic:
            return sent
        for _ in range(count):
            if self.in_reset:
                break
            exp, symbols = self._new_rx()
            await self.line_rx.send(symbols)
            sent.append(exp)
        return sent

    # --------------------------------------------------------------- checking
    def check_line(self, start_index: int = 0) -> int:
        """Match decoded line frames from ``start_index``; return next index."""
        frames = self.line_tx.frames
        for index in range(start_index, len(frames)):
            line = frames[index]
            if line.end_cycle <= self.ignore_line_until:
                continue
            if not line.preamble_ok:
                self.errors.append(f"line frame {index}: bad preamble {line.raw[:8].hex()}")
                continue
            if line.frame[:6] == PAUSE_DST:
                self.pause_frames_on_line += 1
                value = int.from_bytes(line.frame[16:18], "big")
                if not line.fcs_ok or line.frame[12:16] != bytes.fromhex("88080001") or value != int(self.dut.pauseTime.value):
                    self.errors.append(f"line frame {index}: malformed generated pause {line.frame[:20].hex()}")
                continue
            key = parse_tag(line.frame)
            if key is None or key not in self.expected:
                self.errors.append(f"line frame {index}: untagged or unknown frame {line.frame[:24].hex()}")
                continue
            exp = self.expected[key]
            where = describe_case(self.cfg.seed, exp.seq, f"stream {exp.stream} epoch {exp.epoch} {exp.kind}")
            if exp.epoch != self.epoch and line.start_cycle > self.ignore_line_until:
                self.errors.append(f"line: stale transmission after reset: {where}")
            if exp.deliver != "line":
                self.errors.append(f"line: frame should have been dropped: {where}")
                continue
            order = self.tx_order[exp.stream]
            if not order or order[0] != key:
                self.errors.append(f"line: out of order, expected {order[:1]}: {where}")
            else:
                order.pop(0)
            exp.seen = True
            if line.frame != padded_line_frame(self.cfg.phy, exp.frame):
                self.errors.append(f"line: content mismatch ({len(line.frame)} vs {len(exp.frame)} bytes): {where}")
            # An EOFE frame forwarded without drop goes out with an invalid FCS.
            if line.fcs_ok == bool(exp.eofe):
                self.errors.append(f"line: fcs_ok={line.fcs_ok} for eofe={exp.eofe}: {where}")
        return len(frames)

    def outstanding(self) -> list[Expected]:
        return [exp for exp in self.expected.values() if exp.epoch == self.epoch and exp.deliver and not exp.seen and not self._loss_allowed(exp)]

    def _loss_allowed(self, exp: Expected) -> bool:
        return exp.stream == STREAM_RX and self.cfg.fifo_addr_width < 11

    def quiet(self, cycles: int) -> bool:
        """No outbound stream activity and no line frame for ``cycles`` clocks."""
        now = self.status.cycle
        last_line = max((frame.end_cycle for frame in self.line_tx.frames), default=0)
        # The GMII monitor counts enabled clocks only.
        line_quiet = (self.line_tx.cycle - last_line) * self.cfg.clk_en_div
        return now - self.last_sink_activity > cycles and line_quiet > cycles

    async def drain(self, limit: int) -> None:
        # Wait for every expected frame and, where RX loss is allowed, for the
        # outbound streams and the line to go quiet so the MAC is truly idle.
        quiet_cycles = 400 * self.cfg.clk_en_div
        for _ in range(limit // 64):
            await self.eth_cycles(64)
            self.line_index = self.check_line(self.line_index)
            if not self.outstanding() and self.quiet(quiet_cycles):
                break
        await self.eth_cycles(200)
        self.line_index = self.check_line(self.line_index)

    def drain_limit(self, frames: int) -> int:
        per_byte = 1 if self.cfg.phy == "GMII" else 1 / 8
        avg = 3000 if self.cfg.jumbo_frames else 700
        return int(frames * avg * per_byte * 4 * self.cfg.clk_en_div * (1 + self.cfg.backpressure * 4)) + 20_000

    def assert_clean(self) -> None:
        assert not self.errors, "\n".join(self.errors[:20]) + f"\n({len(self.errors)} errors, seed={self.cfg.seed})"
        missing = self.outstanding()
        assert not missing, "frames not delivered: " + ", ".join(
            describe_case(self.cfg.seed, exp.seq, f"stream {exp.stream} {exp.kind} -> {exp.deliver}") for exp in missing[:10]
        )

    def lost_rx(self) -> int:
        return sum(1 for exp in self.expected.values() if exp.epoch == self.epoch and exp.stream == STREAM_RX and exp.deliver and not exp.seen)


async def run_traffic(bench: TopBench, frames: int) -> None:
    cfg, dut = bench.cfg, bench.dut
    tx_count = frames
    byp_count = frames // 3 if cfg.byp_en else 0
    rx_count = frames
    tasks = [
        cocotb.start_soon(bench.tx_source("sAxis", dut.primClk, STREAM_TX_PRIM, tx_count)),
        cocotb.start_soon(bench.rx_source(rx_count)),
    ]
    if byp_count:
        tasks.append(cocotb.start_soon(bench.tx_source("sByp", dut.bypClk, STREAM_TX_BYP, byp_count)))
    for task in tasks:
        await task


###############################################################################
# Scenarios
###############################################################################


def check_counts(bench: TopBench, before: dict[str, int], line_start: int) -> dict[str, int]:
    """Exact status-pulse accounting for the current epoch's traffic."""
    cfg = bench.cfg
    counts = bench.status.delta(before)
    rx = [exp for exp in bench.expected.values() if exp.stream == STREAM_RX and exp.epoch == bench.epoch]
    good_rx = sum(1 for exp in rx if exp.kind not in ("bad_fcs", "rx_er"))
    line_frames = len(bench.line_tx.frames) - line_start
    context = f"seed={cfg.seed} counts={counts}"
    assert counts["txCountEn"] == line_frames, f"txCountEn vs {line_frames} line frames: {context}"
    assert counts["txPauseCnt"] == bench.pause_frames_on_line, f"txPauseCnt vs {bench.pause_frames_on_line} pause frames on the line: {context}"
    assert counts["txUnderRunCnt"] == 0, context
    assert counts["txNotReadyCnt"] == 0, context
    assert counts["rxCrcErrorCnt"] == sum(1 for exp in rx if exp.kind == "bad_fcs"), context
    assert counts["rxCountEn"] == good_rx + bench.rx_pause_sent, f"rxCountEn vs {good_rx} good + {bench.rx_pause_sent} pause: {context}"
    assert counts["rxPauseCnt"] == bench.rx_pause_sent, f"rxPauseCnt vs {bench.rx_pause_sent}: {context}"
    lost = bench.lost_rx()
    if cfg.fifo_addr_width >= 11:
        assert counts["rxOverFlow"] == 0, context
        assert lost == 0, context
    else:
        # Every deliverable frame lost to overflow must be counted. Outbound
        # EOFE drops are not counted at all (known EthMacRxFifo defect), so
        # only this lower bound is asserted.
        assert counts["rxFifoDropCnt"] >= lost, f"{lost} frames lost: {context}"
    if cfg.phy == "GMII":
        er_symbols = [sym for sym in bench.line_tx.er_symbols if sym[0] > bench.ignore_line_until]
        assert not er_symbols, f"unexpected TX_ER: {er_symbols[:4]} {context}"
    else:
        errors = [err for err in bench.line_tx.protocol_errors if err[0] > bench.ignore_line_until]
        assert not errors, f"XGMII protocol errors {errors[:4]} {context}"
    return counts


@cocotb.test()
async def eth_mac_top_scoreboard_test(dut):
    cfg = TopConfig.from_env()
    bench = TopBench(dut, cfg)
    await bench.start()
    before = bench.status.snapshot()
    per_burst = max(1, cfg.frames // cfg.bursts)
    try:
        for burst in range(cfg.bursts):
            await run_traffic(bench, per_burst)
            await bench.drain(bench.drain_limit(per_burst))
            bench.assert_clean()
            if burst != cfg.bursts - 1:
                # Link-down window while both directions are idle: the MAC must
                # neither transmit nor count anything, and must resume cleanly.
                quiet = bench.status.snapshot()
                await bench.set_link(0)
                await bench.eth_cycles(100 * cfg.clk_en_div)
                await bench.set_link(1)
                await bench.eth_cycles(20 * cfg.clk_en_div)
                assert bench.status.delta(quiet) == {name: 0 for name in STATUS_NAMES}, (
                    f"status pulses during idle link-down window: {bench.status.delta(quiet)} seed={cfg.seed}"
                )
        counts = check_counts(bench, before, 0)
        dut._log.info(f"seed={cfg.seed} status={counts} lost={bench.lost_rx()} pause_tx={bench.pause_frames_on_line}")
    finally:
        await cancel_and_join_tasks(bench.tasks)


@cocotb.test()
async def eth_mac_top_reset_recovery_test(dut):
    cfg = TopConfig.from_env()
    bench = TopBench(dut, cfg)
    await bench.start()
    frames = max(8, cfg.frames // 4)
    try:
        sources = [
            cocotb.start_soon(bench.tx_source("sAxis", dut.primClk, STREAM_TX_PRIM, frames)),
            cocotb.start_soon(bench.rx_source(frames)),
        ]
        if cfg.byp_en:
            sources.append(cocotb.start_soon(bench.tx_source("sByp", dut.bypClk, STREAM_TX_BYP, frames)))
        # Reset at a seeded point while traffic is flowing in both directions.
        await bench.eth_cycles(bench.rng.randint(800, 2500) * cfg.clk_en_div)
        await cancel_and_join_tasks(sources)
        for prefix in ("sAxis", "sByp"):
            getattr(dut, f"{prefix}TValid").value = 0
        bench.line_rx.idle()
        await bench.reset()
        bench.ignore_line_until = bench.line_tx.cycle
        bench.line_index = len(bench.line_tx.frames)
        bench.epoch += 1
        bench.rx_pause_sent = 0
        bench.pause_frames_on_line = 0
        for stream in bench.tx_order:
            bench.tx_order[stream] = []
        before = bench.status.snapshot()
        line_start = len(bench.line_tx.frames)
        await run_traffic(bench, frames)
        await bench.drain(bench.drain_limit(frames))
        bench.assert_clean()
        counts = check_counts(bench, before, line_start)
        dut._log.info(f"seed={cfg.seed} post-reset status={counts}")
    finally:
        await cancel_and_join_tasks(bench.tasks)


###############################################################################
# Pytest matrix
###############################################################################


def _matrix(phy: str, *, extended: bool = False) -> list:
    eth_period = 8.0 if phy == "GMII" else 6.4
    frames = "30" if phy == "GMII" else "80"
    base = {"PHY_TYPE_G": phy, "FRAMES": frames}
    cases = [
        ("defaults", {"SEED": "11"}),
        ("filter_pause", {"SEED": "12", "FILT_EN_G": "true", "PRIM_COMMON_CLK_G": "true", "JUMBO_G": "false"}),
        ("bypass_async", {"SEED": "13", "BYP_EN_G": "true", "BYP_ETH_TYPE_G": str(BYPASS_ETHERTYPE_GENERIC)}),
        ("async_prim", {"SEED": "14", "PRIM_PERIOD_NS": f"{eth_period * 1.37:.2f}"}),
        ("drop_err_false", {"SEED": "15", "DROP_ERR_PKT_G": "false"}),
        ("jumbo", {"SEED": "16", "JUMBO_FRAMES": "1", "FRAMES": "8" if phy == "GMII" else "24"}),
        ("small_fifo", {"SEED": "17", "FIFO_ADDR_WIDTH_G": "9", "BACKPRESSURE": "0.85", "PAUSE_THRESH": "64"}),
    ]
    if phy == "GMII" and extended:
        # Extended only: the bench pays per-clock cost for a tenth of the
        # traffic, and test_EthMacTxExportLine covers ethClkEn at the leaf.
        # TX only: GMII reception with a gated ethClkEn loses every frame
        # (known issue in EthMacRxImportGmii).
        cases.append(("clk_en_100m", {"SEED": "18", "CLK_EN_DIV": "10", "FRAMES": "6", "RX_TRAFFIC": "0"}))
    return [parameter_case(f"{phy.lower()}_{name}", **{**base, **overrides}) for name, overrides in cases]


PARAMETER_SWEEP = _matrix("GMII") + _matrix("XGMII")

EXTENDED_SWEEP = [
    parameter_case(
        f"{case.id}_soak_seed{seed}",
        **{**case.values[0], "SEED": str(seed), "FRAMES": str(int(case.values[0]["FRAMES"]) * 4)},
    )
    for case in _matrix("GMII", extended=True) + _matrix("XGMII")
    for seed in (101, 202, 303)
]


def _run(parameters: dict[str, str]) -> None:
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactopphywrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTopScoreboard(parameters):
    _run(parameters)


@pytest.mark.skipif(
    os.getenv("RUN_ETHMAC_EXTENDED_TESTS") != "1",
    reason="extended EthMacTop soak; set RUN_ETHMAC_EXTENDED_TESTS=1",
)
@pytest.mark.parametrize("parameters", EXTENDED_SWEEP)
def test_EthMacTopScoreboard_extended(parameters):
    _run(parameters)
