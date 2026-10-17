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
# - Sweep: One wrapper holds the timing GMII import leaf and export leaf, each
#   beside a PtpRxTimestampAdapter on the same pins (the legacy endpoint's
#   capture point). Separate cocotb tests cover RX framing, RX qualification,
#   RX termination, TX framing, TX link loss and TX underrun.
# - Stimulus: RX pins are driven symbol by symbol from Python so preambles,
#   SFD, FCS, RX_ER, RX_DV and phyReady can be corrupted at exact octets. TX
#   frames enter as tokened 128-bit AXIS beats; phyReady and source gaps are
#   timed from the observed TX pins.
# - Checks: Every leaf start must fall on exactly the edge on which the
#   adapter registers its capture SOF, for RX and TX alike, and every frame
#   the adapter qualifies must have a leaf start and vice versa. RX frames
#   must arrive FCS-stripped with the start token on every beat, and each
#   start must have exactly one terminal event (done, or retire for a start
#   with no frame byte); token zero must produce no beats. TX wire frames
#   must carry a valid FCS, done must report the padded length, and each
#   tokened frame must end in exactly one done or (for a PHY-not-ready dump)
#   one retire, with link loss draining only an outstanding remainder.
# - Timing: The monitor samples 2 ns after each rising edge of the 8 ns
#   clock, after registered outputs update; equal cycle indices therefore
#   mean the same register edge for the leaf and the oracle.

from __future__ import annotations

from dataclasses import dataclass, field
import zlib

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    build_ethernet_frame,
    frame_beats_from_bytes,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTimingGmiiLeafWrapper.vhd"

CLK_PERIOD_NS = 8
PREAMBLE = 0x55
SFD = 0xD5
IFG = [(0, 0, 0)] * 12


# --------------------------------------------------------------------------
# Frames and GMII symbols
# --------------------------------------------------------------------------

def _frame(seed: int, length: int) -> bytes:
    return build_ethernet_frame(
        dst_mac=0x5A0102030405,
        src_mac=0x660102030405,
        eth_type=0x88B5,
        payload=bytes(((seed + index) & 0xFF) for index in range(length - 14)),
    )


def _fcs(frame: bytes) -> bytes:
    return zlib.crc32(frame).to_bytes(4, "little")


def _symbols(octets: bytes, *, er_at: int | None = None) -> list[tuple[int, int, int]]:
    return [(1, 1 if index == er_at else 0, octet) for index, octet in enumerate(octets)]


def _wire(frame: bytes, *, preamble: int = 7, sfd: int = SFD, fcs: bytes | None = None) -> bytes:
    return bytes([PREAMBLE] * preamble + [sfd]) + frame + (_fcs(frame) if fcs is None else fcs)


# --------------------------------------------------------------------------
# Bench
# --------------------------------------------------------------------------

@dataclass
class Observed:
    cycle: int = 0
    rx_starts: list[tuple[int, int]] = field(default_factory=list)
    rx_oracle: list[int] = field(default_factory=list)
    rx_dones: list[tuple[int, int, int, int]] = field(default_factory=list)
    rx_lost: list[int] = field(default_factory=list)
    rx_retires: list[tuple[int, int]] = field(default_factory=list)
    rx_frames: list[dict] = field(default_factory=list)
    rx_count_en: int = 0
    rx_crc_error: int = 0
    tx_starts: list[tuple[int, int]] = field(default_factory=list)
    tx_oracle: list[int] = field(default_factory=list)
    tx_dones: list[tuple[int, int, int, int]] = field(default_factory=list)
    tx_retires: list[tuple[int, int]] = field(default_factory=list)
    tx_wire: list[dict] = field(default_factory=list)
    tx_wire_bytes: int = 0
    tx_underrun: int = 0
    tx_not_ready: int = 0


class LeafBench:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.ethClk
        self.obs = Observed()
        self.source = FlatEmacEndpoint(dut, prefix="sAxis")
        self._rx_beats: list[tuple[bytes, int, int, int]] = []
        self._tx_octets: list[tuple[int, int]] = []

    async def start(self) -> None:
        dut = self.dut
        cocotb.start_soon(Clock(self.clk, CLK_PERIOD_NS, unit="ns").start())
        dut.ethRst.setimmediatevalue(1)
        dut.phyReady.setimmediatevalue(1)
        dut.gmiiRxDv.setimmediatevalue(0)
        dut.gmiiRxEr.setimmediatevalue(0)
        dut.gmiiRxd.setimmediatevalue(0)
        dut.rxNextToken.setimmediatevalue(0)
        self.source.set_idle()
        await self.edge(4)
        dut.ethRst.value = 0
        await self.edge(4)
        cocotb.start_soon(self._monitor())

    async def edge(self, count: int = 1) -> None:
        # Drive point: 1 ns after the edge, held until the next edge.
        for _ in range(count):
            await RisingEdge(self.clk)
            await Timer(1, unit="ns")

    async def _monitor(self) -> None:
        dut = self.dut
        obs = self.obs
        while True:
            await RisingEdge(self.clk)
            await Timer(2, unit="ns")
            obs.cycle += 1
            cyc = obs.cycle

            # RX events and stream
            if int(dut.rxStart.value):
                obs.rx_starts.append((cyc, int(dut.rxStartToken.value)))
            if int(dut.rxOracleSof.value):
                obs.rx_oracle.append(cyc)
            if int(dut.rxDone.value):
                obs.rx_dones.append(
                    (cyc, int(dut.rxDoneError.value), int(dut.rxDoneLength.value), int(dut.rxDoneToken.value))
                )
            if int(dut.rxLost.value):
                obs.rx_lost.append(cyc)
            if int(dut.rxRetireValid.value):
                obs.rx_retires.append((cyc, int(dut.rxRetireToken.value)))
            obs.rx_count_en += int(dut.rxCountEn.value)
            obs.rx_crc_error += int(dut.rxCrcError.value)
            if int(dut.mAxisTValid.value):
                keep = int(dut.mAxisTKeep.value)
                data = int(dut.mAxisTData.value).to_bytes(16, "little")
                chunk = bytes(data[i] for i in range(16) if (keep >> i) & 1)
                self._rx_beats.append((chunk, int(dut.mAxisTId.value), int(dut.mAxisSof.value), int(dut.mAxisEofe.value)))
                if int(dut.mAxisTLast.value):
                    beats = self._rx_beats
                    self._rx_beats = []
                    obs.rx_frames.append(
                        {
                            "data": b"".join(beat[0] for beat in beats),
                            "tids": {beat[1] for beat in beats},
                            "sof": [beat[2] for beat in beats],
                            "eofe": beats[-1][3],
                        }
                    )

            # TX events and wire
            if int(dut.txStart.value):
                obs.tx_starts.append((cyc, int(dut.txStartToken.value)))
            if int(dut.txOracleSof.value):
                obs.tx_oracle.append(cyc)
            if int(dut.txDone.value):
                obs.tx_dones.append(
                    (cyc, int(dut.txDoneError.value), int(dut.txDoneLength.value), int(dut.txDoneToken.value))
                )
            if int(dut.txRetireValid.value):
                obs.tx_retires.append((cyc, int(dut.txRetireToken.value)))
            obs.tx_underrun += int(dut.txUnderRun.value)
            obs.tx_not_ready += int(dut.txLinkNotReady.value)
            if int(dut.gmiiTxEn.value):
                self._tx_octets.append((int(dut.gmiiTxd.value), int(dut.gmiiTxEr.value)))
                obs.tx_wire_bytes += 1
            elif self._tx_octets:
                octets = self._tx_octets
                self._tx_octets = []
                obs.tx_wire.append({"data": bytes(o[0] for o in octets), "er": any(o[1] for o in octets)})

    # RX pin driver ------------------------------------------------------
    async def drive_rx(self, symbols, *, token: int | None = None, phy_drop_at: int | None = None) -> None:
        dut = self.dut
        if token is not None:
            dut.rxNextToken.value = token
        for index, (dv, er, octet) in enumerate(symbols):
            if phy_drop_at is not None and index == phy_drop_at:
                dut.phyReady.value = 0
            dut.gmiiRxDv.value = dv
            dut.gmiiRxEr.value = er
            dut.gmiiRxd.value = octet
            await self.edge()
        dut.gmiiRxDv.value = 0
        dut.gmiiRxEr.value = 0
        dut.gmiiRxd.value = 0
        await self.edge(len(IFG))

    async def send_rx(self, frame: bytes, token: int, **kwargs) -> None:
        await self.drive_rx(_symbols(_wire(frame, **kwargs)), token=token)

    # TX source ----------------------------------------------------------
    async def send_tx(self, frame: bytes, token: int, *, gap_after_beat: int | None = None, gap_cycles: int = 0) -> None:
        beats = frame_beats_from_bytes(frame)
        for index, beat in enumerate(beats):
            beat.tid = token
            self.source.drive(beat)
            await self.source.wait_ready(clk=self.clk)
            if gap_after_beat is not None and index == gap_after_beat:
                self.source.set_idle()
                for _ in range(gap_cycles):
                    await self.edge()
        self.source.set_idle()

    async def wait_tx_idle(self, cycles: int = 2000) -> None:
        idle = 0
        for _ in range(cycles):
            await self.edge()
            idle = idle + 1 if int(self.dut.gmiiTxEn.value) == 0 and int(self.dut.sAxisTValid.value) == 0 else 0
            if idle >= 32:
                return
        raise AssertionError("TX did not go idle")

    async def wait_tx_wire_bytes(self, count: int, cycles: int = 4000) -> None:
        # Wait until `count` octets of the current frame have been driven
        target = self.obs.tx_wire_bytes + count
        for _ in range(cycles):
            await self.edge()
            if self.obs.tx_wire_bytes >= target:
                return
        raise AssertionError("TX wire did not advance")


def _assert_start_alignment(starts, oracle, name: str) -> None:
    assert [cyc for cyc, _ in starts] == oracle, (
        f"{name} leaf starts {[cyc for cyc, _ in starts]} differ from adapter capture SOFs {oracle}"
    )


def _check_wire_frame(wire: dict, frame: bytes) -> int:
    data = wire["data"]
    assert data[:8] == bytes([PREAMBLE] * 7 + [SFD]), f"bad preamble {data[:8].hex()}"
    body, fcs = data[8:-4], data[-4:]
    assert fcs == _fcs(body), "TX FCS does not match the transmitted frame"
    assert body[: len(frame)] == frame
    assert body[len(frame):] == bytes(len(body) - len(frame)), "padding must be zero"
    assert len(body) >= 60
    assert not wire["er"]
    return len(body)


# --------------------------------------------------------------------------
# RX
# --------------------------------------------------------------------------

@cocotb.test()
async def rx_frames_match_adapter_capture_edges(dut):
    bench = LeafBench(dut)
    await bench.start()
    obs = bench.obs

    cases = [(60, 0x01), (61, 0x02), (64, 0x7F), (127, 0x80), (1514, 0xFE), (1518, 0xFF)]
    for seed, (length, token) in enumerate(cases):
        await bench.send_rx(_frame(seed, length), token)

    # Minimum gap of one idle octet between frames still qualifies both.
    tight = [_frame(0x40, 64), _frame(0x41, 64)]
    symbols = _symbols(_wire(tight[0])) + [(0, 0, 0)] + _symbols(_wire(tight[1]))
    dut.rxNextToken.value = 0x33
    await bench.drive_rx(symbols)

    # Token zero: start and done are published, but no beat enters the MAC.
    await bench.send_rx(_frame(0x50, 100), 0x00)

    expected = [(_frame(seed, length), token) for seed, (length, token) in enumerate(cases)]
    expected += [(tight[0], 0x33), (tight[1], 0x33)]

    _assert_start_alignment(obs.rx_starts, obs.rx_oracle, "RX")
    assert [token for _, token in obs.rx_starts] == [token for _, token in expected] + [0x00]
    assert len(obs.rx_frames) == len(expected)
    for observed, (frame, token) in zip(obs.rx_frames, expected):
        assert observed["data"] == frame
        assert observed["tids"] == {token}
        assert observed["sof"][0] == 1 and sum(observed["sof"]) == 1
        assert observed["eofe"] == 0
    assert [(err, length, token) for _, err, length, token in obs.rx_dones] == (
        [(0, len(frame), token) for frame, token in expected] + [(0, 100, 0x00)]
    )
    assert all(done_cyc > start_cyc for (start_cyc, _), (done_cyc, *_rest) in zip(obs.rx_starts, obs.rx_dones))
    assert obs.rx_retires == [] and obs.rx_lost == []
    assert obs.rx_count_en == len(expected) + 1 and obs.rx_crc_error == 0


@cocotb.test()
async def rx_unqualified_bursts_never_start(dut):
    bench = LeafBench(dut)
    await bench.start()
    obs = bench.obs

    frame = _frame(0x10, 64)
    bad_bursts = [
        _symbols(_wire(frame, preamble=6)),                       # shortened preamble
        _symbols(_wire(frame, preamble=8)),                       # lengthened preamble
        _symbols(_wire(frame)[:3] + b"\x54" + _wire(frame)[4:]),  # corrupted preamble octet
        _symbols(_wire(frame), er_at=3),                          # RX_ER inside the preamble
        _symbols(_wire(frame, sfd=0xD4)),                         # bad SFD
        _symbols(frame + _fcs(frame)),                            # no preamble at all
    ]
    for index, burst in enumerate(bad_bursts):
        await bench.drive_rx(burst, token=0x10 + index)
        await bench.send_rx(_frame(0x20 + index, 64), 0x20 + index)

    _assert_start_alignment(obs.rx_starts, obs.rx_oracle, "RX")
    assert [token for _, token in obs.rx_starts] == [0x20 + index for index in range(len(bad_bursts))]
    assert len(obs.rx_lost) == len(bad_bursts)
    assert [f["data"] for f in obs.rx_frames] == [_frame(0x20 + index, 64) for index in range(len(bad_bursts))]
    assert all(err == 0 for _, err, _, _ in obs.rx_dones) and len(obs.rx_dones) == len(bad_bursts)
    assert obs.rx_retires == []


@cocotb.test()
async def rx_termination_has_one_terminal_event(dut):
    bench = LeafBench(dut)
    await bench.start()
    obs = bench.obs

    # Bad FCS: one EOFE frame and one done with doneError.
    frame = _frame(0x30, 80)
    await bench.send_rx(frame, 0x31, fcs=b"\x00\x00\x00\x00")

    # RX_ER mid-frame with RX_DV still high, followed in the same burst by a
    # valid-looking preamble/SFD: one terminated frame and no second start.
    tail = _wire(_frame(0x32, 64))
    burst = _symbols(_wire(frame), er_at=8 + 40) + _symbols(tail)
    await bench.drive_rx(burst, token=0x32)

    # Link loss mid-frame: one EOFE frame, one done, nothing until the link
    # returns, then a clean frame.
    await bench.drive_rx(_symbols(_wire(frame)), token=0x33, phy_drop_at=8 + 30)
    await bench.edge(4)
    dut.phyReady.value = 1
    await bench.edge(4)
    await bench.send_rx(_frame(0x34, 64), 0x34)

    # Early aborts: k octets after SFD, then RX_DV falls.
    for k in range(0, 7):
        await bench.drive_rx(_symbols(_wire(frame)[: 8 + k]), token=0x40 + k)

    _assert_start_alignment(obs.rx_starts, obs.rx_oracle, "RX")
    started = [0x31, 0x32, 0x33, 0x34] + [0x40 + k for k in range(1, 7)]
    assert [token for _, token in obs.rx_starts] == started
    assert len(obs.rx_lost) == 1, "only the zero-octet abort lacks a capture"

    # k = 1..4: the octets can only be FCS, so the start is retired with no beat
    assert [token for _, token in obs.rx_retires] == [0x40 + k for k in range(1, 5)]
    # Every other start ends in exactly one done
    done_tokens = [token for *_rest, token in obs.rx_dones]
    assert done_tokens == [0x31, 0x32, 0x33, 0x34, 0x45, 0x46]
    errors = {token: (err, length) for _, err, length, token in obs.rx_dones}
    assert errors[0x31] == (1, 80)
    assert errors[0x32][0] == 1 and errors[0x33][0] == 1
    assert errors[0x34] == (0, 64)
    assert errors[0x45] == (1, 1) and errors[0x46] == (1, 2)
    assert len(set(done_tokens) | {token for _, token in obs.rx_retires}) == len(started)

    frames = obs.rx_frames
    assert [f["tids"] for f in frames] == [{0x31}, {0x32}, {0x33}, {0x34}, {0x45}, {0x46}]
    assert [f["eofe"] for f in frames] == [1, 1, 1, 0, 1, 1]
    assert frames[0]["data"] == frame
    assert frames[1]["data"] == frame[: 40 - 4], "bytes before RX_ER less the FCS delay"
    assert frames[3]["data"] == _frame(0x34, 64)
    assert frames[4]["data"] == frame[:1] and frames[5]["data"] == frame[:2]
    assert obs.rx_crc_error == 5 and obs.rx_count_en == 1


# --------------------------------------------------------------------------
# TX
# --------------------------------------------------------------------------

@cocotb.test()
async def tx_frames_match_tap_capture_edges(dut):
    bench = LeafBench(dut)
    await bench.start()
    obs = bench.obs

    cases = [(16, 0x01), (59, 0x02), (60, 0x03), (61, 0x04), (100, 0x05), (1514, 0x06)]
    for seed, (length, token) in enumerate(cases):
        await bench.send_tx(_frame(seed, length), token)
    # Token zero, as for a generated pause frame: no done and no retire
    await bench.send_tx(_frame(0x70, 64), 0x00)
    await bench.wait_tx_idle()

    _assert_start_alignment(obs.tx_starts, obs.tx_oracle, "TX")
    assert [token for _, token in obs.tx_starts] == [token for _, token in cases] + [0x00]
    assert len(obs.tx_wire) == len(cases) + 1
    lengths = [_check_wire_frame(wire, _frame(seed, length)) for seed, (wire, (length, _)) in enumerate(zip(obs.tx_wire, cases))]
    _check_wire_frame(obs.tx_wire[-1], _frame(0x70, 64))
    assert [(err, length, token) for _, err, length, token in obs.tx_dones] == [
        (0, wire_length, token) for wire_length, (_, token) in zip(lengths, cases)
    ]
    assert all(done > start for (start, _), (done, *_r) in zip(obs.tx_starts, obs.tx_dones))
    assert obs.tx_retires == []


@cocotb.test()
async def tx_link_loss_resolves_each_frame_once(dut):
    bench = LeafBench(dut)
    await bench.start()
    obs = bench.obs
    frame = _frame(0x20, 200)

    # PHY not ready at SOF: dumped through tLast, one retire, nothing on the pins.
    dut.phyReady.value = 0
    await bench.send_tx(frame, 0x11)
    await bench.edge(16)
    dut.phyReady.value = 1
    await bench.edge(16)

    # Link loss during the preamble: no start; the frame is drained, one done.
    send = cocotb.start_soon(bench.send_tx(frame, 0x12))
    await bench.wait_tx_wire_bytes(3)
    dut.phyReady.value = 0
    await send
    await bench.edge(16)
    dut.phyReady.value = 1
    await bench.wait_tx_idle()

    # Link loss mid-frame with an input remainder outstanding: drained, one done.
    send = cocotb.start_soon(bench.send_tx(frame, 0x13))
    await bench.wait_tx_wire_bytes(8 + 40)
    dut.phyReady.value = 0
    await send
    await bench.edge(16)
    dut.phyReady.value = 1
    await bench.wait_tx_idle()

    # Link loss in the FCS after the input tLast was accepted: done at once and
    # the following frame is not consumed by a drain.
    short = _frame(0x21, 60)
    send = cocotb.start_soon(bench.send_tx(short, 0x14))
    await bench.wait_tx_wire_bytes(8 + 60 + 2)
    dut.phyReady.value = 0
    await send
    await bench.edge(16)
    dut.phyReady.value = 1
    await bench.edge(4)
    await bench.send_tx(_frame(0x22, 64), 0x15)
    await bench.wait_tx_idle()

    _assert_start_alignment(obs.tx_starts, obs.tx_oracle, "TX")
    assert [token for _, token in obs.tx_starts] == [0x13, 0x14, 0x15]
    assert [token for _, token in obs.tx_retires] == [0x11]
    assert obs.tx_not_ready >= 1
    assert [(err, length, token) for _, err, length, token in obs.tx_dones] == [
        (1, 200, 0x12),
        (1, 200, 0x13),
        (1, 60, 0x14),
        (0, 64, 0x15),
    ]
    # Cut frames are truncated on the pins; only the last frame is complete,
    # and no remainder is retransmitted as a frame of its own on link return.
    assert len(obs.tx_wire) == 4
    assert all(len(w["data"]) < 8 + 200 + 4 for w in obs.tx_wire[:2])
    _check_wire_frame(obs.tx_wire[3], _frame(0x22, 64))


@cocotb.test()
async def tx_underrun_reports_wire_error(dut):
    bench = LeafBench(dut)
    await bench.start()
    obs = bench.obs
    frame = _frame(0x30, 120)

    # A source gap after the first beat starves the serializer mid-frame.
    await bench.send_tx(frame, 0x21, gap_after_beat=0, gap_cycles=64)
    await bench.wait_tx_idle()
    await bench.send_tx(_frame(0x31, 64), 0x22)
    await bench.wait_tx_idle()

    _assert_start_alignment(obs.tx_starts, obs.tx_oracle, "TX")
    assert [token for _, token in obs.tx_starts] == [0x21, 0x22]
    assert obs.tx_underrun == 1
    assert [(err, length, token) for _, err, length, token in obs.tx_dones] == [(1, 120, 0x21), (0, 64, 0x22)]
    assert obs.tx_wire[0]["er"]
    _check_wire_frame(obs.tx_wire[1], _frame(0x31, 64))


def test_EthMacTimingGmiiLeaf():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactiminggmiileafwrapper",
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
