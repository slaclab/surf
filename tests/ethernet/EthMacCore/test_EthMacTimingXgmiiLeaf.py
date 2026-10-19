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
# - Sweep: One wrapper holds the timing XGMII import and export leaves, each
#   beside a PtpRxTimestampAdapter on the same pins. Separate cocotb tests
#   cover RX framing, qualification and termination, and TX framing, link
#   loss, underrun and forced abort.
# - Stimulus: RX words are built octet by octet from Python, so /S/ lane,
#   preamble, SFD, FCS, control characters and phyReady can be corrupted at
#   exact octets; frame lengths cover every alignment of the last word. TX
#   frames enter as tokened 128-bit AXIS beats; phyReady, source gaps and
#   abort are timed from the observed TX pins.
# - Checks: Every leaf start must fall on the edge on which the adapter
#   registers its capture SOF, with the same start lane, for RX and TX, and
#   the two start sets must be equal. RX frames arrive FCS-stripped with the
#   start token on every beat and one terminal event per start; token zero
#   produces no beats. TX wire frames carry a valid FCS, padding to exactly
#   60 bytes and /T/; done reports the padded length; underrun, link loss and
#   abort end the frame with an error character and one done with doneError,
#   draining only an outstanding remainder; PHY-not-ready frames retire.
# - Timing: The monitor samples 2 ns after each rising edge of the 6.4 ns
#   clock; equal cycle indices mean the same register edge.

from __future__ import annotations

from dataclasses import dataclass, field
import zlib

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    build_ethernet_frame,
    frame_beats_from_bytes,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTimingXgmiiLeafWrapper.vhd"

CLK_PERIOD_NS = 6.4
START = 0xFB
TERMINATE = 0xFD
ERROR = 0xFE
IDLE = 0x07


def _frame(seed: int, length: int) -> bytes:
    return build_ethernet_frame(
        dst_mac=0x5A0102030405,
        src_mac=0x660102030405,
        eth_type=0x88B5,
        payload=bytes(((seed + index) & 0xFF) for index in range(length - 14)),
    )


def _fcs(frame: bytes) -> bytes:
    return zlib.crc32(frame).to_bytes(4, "little")


def _octets(frame: bytes, *, preamble: int = 6, sfd: int = 0xD5, fcs: bytes | None = None,
            terminate: bool = True) -> list[tuple[int, int]]:
    body = frame + (_fcs(frame) if fcs is None else fcs)
    octets = [(START, 1)] + [(0x55, 0)] * preamble + [(sfd, 0)] + [(b, 0) for b in body]
    if terminate:
        octets.append((TERMINATE, 1))
    return octets


def _words(octets: list[tuple[int, int]], *, start_lane: int = 0, tail_idles: int = 12) -> list[tuple[int, int]]:
    stream = [(IDLE, 1)] * start_lane + octets + [(IDLE, 1)] * tail_idles
    stream += [(IDLE, 1)] * (-len(stream) % 8)
    words = []
    for base in range(0, len(stream), 8):
        data = 0
        ctrl = 0
        for lane, (octet, is_ctrl) in enumerate(stream[base : base + 8]):
            data |= octet << (8 * lane)
            ctrl |= is_ctrl << lane
        words.append((data, ctrl))
    return words


@dataclass
class Observed:
    cycle: int = 0
    rx_starts: list[tuple[int, int, int]] = field(default_factory=list)
    rx_oracle: list[int] = field(default_factory=list)
    rx_dones: list[tuple[int, int, int, int]] = field(default_factory=list)
    rx_lost: list[int] = field(default_factory=list)
    rx_retires: list[tuple[int, int]] = field(default_factory=list)
    rx_frames: list[dict] = field(default_factory=list)
    tx_starts: list[tuple[int, int]] = field(default_factory=list)
    tx_oracle: list[int] = field(default_factory=list)
    tx_dones: list[tuple[int, int, int, int]] = field(default_factory=list)
    tx_retires: list[tuple[int, int]] = field(default_factory=list)
    tx_wire: list[dict] = field(default_factory=list)
    tx_wire_octets: int = 0
    tx_underrun: int = 0
    abort_ack: list[int] = field(default_factory=list)


class XgmiiBench:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.ethClk
        self.obs = Observed()
        self.source = FlatEmacEndpoint(dut, prefix="sAxis")
        self._beats: list[tuple[bytes, int, int, int]] = []
        self._wire: list[int] | None = None
        self._wire_er = False

    async def start(self) -> None:
        dut = self.dut
        self.clock_task = cocotb.start_soon(Clock(self.clk, CLK_PERIOD_NS, unit="ns").start())
        dut.ethRst.setimmediatevalue(1)
        dut.phyReady.setimmediatevalue(1)
        dut.xgmiiRxd.setimmediatevalue(0x0707070707070707)
        dut.xgmiiRxc.setimmediatevalue(0xFF)
        dut.rxNextToken.setimmediatevalue(0)
        dut.abortReq.setimmediatevalue(0)
        self.source.set_idle()
        await self.edge(4)
        dut.ethRst.value = 0
        await self.edge(4)
        self.monitor_task = cocotb.start_soon(self._monitor())

    async def edge(self, count: int = 1) -> None:
        """Propagation sampling: drive point after the 1 ns registered delay."""
        for _ in range(count):
            await RisingEdge(self.clk)
            await Timer(1, unit="ns")

    def _wire_word(self, data: int, ctrl: int) -> None:
        obs = self.obs
        for lane in range(8):
            octet = (data >> (8 * lane)) & 0xFF
            is_ctrl = (ctrl >> lane) & 1
            if self._wire is None:
                if is_ctrl and octet == START:
                    self._wire = []
                    self._wire_er = False
                continue
            if is_ctrl:
                if octet == TERMINATE:
                    obs.tx_wire.append({"data": bytes(self._wire), "er": self._wire_er})
                    self._wire = None
                else:
                    self._wire_er = True
            else:
                self._wire.append(octet)
                obs.tx_wire_octets += 1

    async def _monitor(self) -> None:
        """Lifetime agent: bench-owned monitor. Propagation sampling: outputs at +2 ns."""
        dut = self.dut
        obs = self.obs
        while True:
            await RisingEdge(self.clk)
            await Timer(2, unit="ns")
            obs.cycle += 1
            cyc = obs.cycle
            if int(dut.rxStart.value):
                obs.rx_starts.append((cyc, int(dut.rxStartToken.value), int(dut.rxStartLane.value)))
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
            if int(dut.mAxisTValid.value):
                keep = int(dut.mAxisTKeep.value)
                data = int(dut.mAxisTData.value).to_bytes(16, "little")
                chunk = bytes(data[i] for i in range(16) if (keep >> i) & 1)
                self._beats.append((chunk, int(dut.mAxisTId.value), int(dut.mAxisSof.value), int(dut.mAxisEofe.value)))
                if int(dut.mAxisTLast.value):
                    beats = self._beats
                    self._beats = []
                    obs.rx_frames.append({
                        "data": b"".join(b[0] for b in beats),
                        "tids": {b[1] for b in beats},
                        "sof": [b[2] for b in beats],
                        "eofe": beats[-1][3],
                    })
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
            if int(dut.abortAck.value):
                obs.abort_ack.append(cyc)
            self._wire_word(int(dut.xgmiiTxd.value), int(dut.xgmiiTxc.value))

    async def drive_rx(self, words, *, token: int | None = None, phy_drop_at: int | None = None) -> None:
        dut = self.dut
        if token is not None:
            dut.rxNextToken.value = token
        for index, (data, ctrl) in enumerate(words):
            if phy_drop_at is not None and index == phy_drop_at:
                dut.phyReady.value = 0
            dut.xgmiiRxd.value = data
            dut.xgmiiRxc.value = ctrl
            await self.edge()
        dut.xgmiiRxd.value = 0x0707070707070707
        dut.xgmiiRxc.value = 0xFF
        await self.edge(4)

    async def send_rx(self, frame: bytes, token: int, *, start_lane: int = 0, **kwargs) -> None:
        await self.drive_rx(_words(_octets(frame, **kwargs), start_lane=start_lane), token=token)

    async def send_tx(self, frame: bytes, token: int, *, gap_after_beat: int | None = None, gap_cycles: int = 0) -> None:
        beats = frame_beats_from_bytes(frame)
        for index, beat in enumerate(beats):
            beat.tid = token
            self.source.drive(beat)
            await self.source.wait_ready(clk=self.clk)
            if gap_after_beat is not None and index == gap_after_beat:
                self.source.set_idle()
                await self.edge(gap_cycles)
        self.source.set_idle()

    async def wait_tx_idle(self, cycles: int = 4000) -> None:
        idle = 0
        for _ in range(cycles):
            await self.edge()
            quiet = int(self.dut.xgmiiTxc.value) == 0xFF and int(self.dut.sAxisTValid.value) == 0
            idle = idle + 1 if quiet else 0
            if idle >= 32:
                return
        raise AssertionError("TX did not go idle")

    async def drop_phy_at_octets(self, count: int, cycles: int = 4000) -> None:
        # React in the same cycle the monitor counts the octet (it samples at
        # +2 ns), so phyReady is low at the very next edge.
        """Real-time timing: react at +3 ns, after the +2 ns wire monitor."""
        target = self.obs.tx_wire_octets + count
        for _ in range(cycles):
            await RisingEdge(self.clk)
            await Timer(3, unit="ns")
            if self.obs.tx_wire_octets >= target:
                self.dut.phyReady.value = 0
                return
        raise AssertionError("TX wire did not advance")

    async def wait_tx_octets(self, count: int, cycles: int = 4000) -> None:
        target = self.obs.tx_wire_octets + count
        for _ in range(cycles):
            await self.edge()
            if self.obs.tx_wire_octets >= target:
                return
        raise AssertionError("TX wire did not advance")


def _assert_alignment(starts, oracle, name: str) -> None:
    assert [s[0] for s in starts] == oracle, f"{name} leaf starts {[s[0] for s in starts]} != adapter SOFs {oracle}"


def _check_wire(wire: dict, frame: bytes) -> int:
    data = wire["data"]
    assert data[:7] == bytes([0x55] * 6 + [0xD5])
    body, fcs = data[7:-4], data[-4:]
    assert fcs == _fcs(body), "TX FCS does not match the transmitted frame"
    assert body[: len(frame)] == frame
    assert body[len(frame):] == bytes(len(body) - len(frame))
    assert len(body) == max(60, len(frame)), f"padding to exactly 60, got {len(body)}"
    assert not wire["er"]
    return len(body)


# --------------------------------------------------------------------------
# RX
# --------------------------------------------------------------------------

@cocotb.test()
async def rx_frames_match_adapter_capture_edges(dut):
    bench = XgmiiBench(dut)
    await bench.start()
    obs = bench.obs

    lengths = [60, 61, 62, 63, 64, 65, 66, 67, 68, 100, 1514, 1518]
    expected = []
    for index, length in enumerate(lengths):
        lane = 4 * (index % 2)
        frame = _frame(index, length)
        await bench.send_rx(frame, index + 1, start_lane=lane)
        expected.append((frame, index + 1, lane))

    # Data-valued /S/ and /T/ codes inside a payload are ordinary data
    coded = build_ethernet_frame(dst_mac=0x5A0102030405, src_mac=0x660102030405, eth_type=0x88B5,
                                 payload=bytes([START, TERMINATE, ERROR, IDLE] * 20))
    await bench.send_rx(coded, 0x40, start_lane=4)
    expected.append((coded, 0x40, 4))

    # Minimum spacing: /T/ then idles, next /S/ in the same or next word
    a, b = _frame(0x50, 64), _frame(0x51, 70)
    octets = _octets(a) + [(IDLE, 1)] * 3
    octets += [(IDLE, 1)] * ((4 - len(octets)) % 4)
    dut.rxNextToken.value = 0x41
    await bench.drive_rx(_words(octets + _octets(b)))
    expected += [(a, 0x41, 0), (b, 0x41, (len(octets)) % 8)]

    # Token zero: start and done, no beats
    await bench.send_rx(_frame(0x60, 100), 0x00)

    _assert_alignment(obs.rx_starts, obs.rx_oracle, "RX")
    assert [(tok, lane) for _, tok, lane in obs.rx_starts] == [(t, l) for _, t, l in expected] + [(0, 0)]
    assert len(obs.rx_frames) == len(expected)
    for observed, (frame, token, _) in zip(obs.rx_frames, expected):
        assert observed["data"] == frame
        assert observed["tids"] == {token}
        assert observed["sof"][0] == 1 and sum(observed["sof"]) == 1
        assert observed["eofe"] == 0
    assert [(e, n, t) for _, e, n, t in obs.rx_dones] == [(0, len(f), t) for f, t, _ in expected] + [(0, 100, 0)]
    assert obs.rx_retires == [] and obs.rx_lost == []


@cocotb.test()
async def rx_unqualified_starts_never_start(dut):
    bench = XgmiiBench(dut)
    await bench.start()
    obs = bench.obs
    frame = _frame(0x10, 64)
    corrupted = _octets(frame)
    corrupted[3] = (0x54, 0)
    bad = [
        _words(_octets(frame, preamble=5)),
        _words(_octets(frame, preamble=7)),
        _words(corrupted),
        _words(_octets(frame, sfd=0xD4)),
        _words(_octets(frame), start_lane=2),
        _words([(0x55, 0)] * 7 + [(0xD5, 0)] + [(x, 0) for x in frame + _fcs(frame)] + [(TERMINATE, 1)]),
    ]
    for index, words in enumerate(bad):
        await bench.drive_rx(words, token=0x10 + index)
        await bench.send_rx(_frame(0x20 + index, 64), 0x20 + index, start_lane=4 * (index % 2))

    _assert_alignment(obs.rx_starts, obs.rx_oracle, "RX")
    assert [t for _, t, _ in obs.rx_starts] == [0x20 + i for i in range(len(bad))]
    assert len(obs.rx_lost) == 5, "every unqualified /S/ is lost; a burst without /S/ is idle noise"
    assert [f["data"] for f in obs.rx_frames] == [_frame(0x20 + i, 64) for i in range(len(bad))]
    assert obs.rx_retires == []


@cocotb.test()
async def rx_termination_has_one_terminal_event(dut):
    bench = XgmiiBench(dut)
    await bench.start()
    obs = bench.obs
    frame = _frame(0x30, 96)

    # Bad FCS
    await bench.send_rx(frame, 0x31, fcs=b"\x00\x00\x00\x00")
    # /E/ 40 octets into the frame; the rest of the burst, including a
    # complete preamble/SFD, is drained until /T/
    octets = _octets(frame, terminate=False)
    octets[8 + 40] = (ERROR, 1)
    tail = _octets(_frame(0x32, 64), terminate=True)[1:]
    await bench.drive_rx(_words(octets + tail), token=0x32)
    # Nested /S/: the open frame ends with an error, the nested start is lost
    nested = _octets(frame, terminate=False)[: 8 + 50] + _octets(_frame(0x33, 64))
    await bench.drive_rx(_words(nested), token=0x33)
    # Link loss mid-frame, then a clean frame after the link returns
    await bench.drive_rx(_words(_octets(frame)), token=0x34, phy_drop_at=5)
    dut.phyReady.value = 1
    await bench.edge(4)
    await bench.send_rx(_frame(0x35, 64), 0x35)
    # Early ends: k octets after SFD, then /T/
    for k in range(0, 7):
        octets = _octets(frame, terminate=False)[: 8 + k] + [(TERMINATE, 1)]
        await bench.drive_rx(_words(octets, start_lane=4 * (k % 2)), token=0x40 + k)

    _assert_alignment(obs.rx_starts, obs.rx_oracle, "RX")
    started = [0x31, 0x32, 0x33, 0x34, 0x35] + [0x40 + k for k in range(1, 7)]
    assert [t for _, t, _ in obs.rx_starts] == started
    assert [t for _, t in obs.rx_retires] == [0x40 + k for k in range(1, 5)]
    dones = {t: (e, n) for _, e, n, t in obs.rx_dones}
    assert [t for *_r, t in obs.rx_dones] == [0x31, 0x32, 0x33, 0x34, 0x35, 0x45, 0x46]
    assert dones[0x31] == (1, 96)
    assert dones[0x32] == (1, 40 - 4)
    assert dones[0x33] == (1, 50 - 4)
    assert dones[0x34][0] == 1
    assert dones[0x35] == (0, 64)
    assert dones[0x45] == (1, 1) and dones[0x46] == (1, 2)
    frames = obs.rx_frames
    assert [f["tids"] for f in frames] == [{0x31}, {0x32}, {0x33}, {0x34}, {0x35}, {0x45}, {0x46}]
    assert [f["eofe"] for f in frames] == [1, 1, 1, 1, 0, 1, 1]
    assert frames[1]["data"] == frame[:36] and frames[2]["data"] == frame[:46]
    assert frames[4]["data"] == _frame(0x35, 64)
    # Lost: the zero-octet early end and the nested /S/
    assert len(obs.rx_lost) == 2


# --------------------------------------------------------------------------
# TX
# --------------------------------------------------------------------------

@cocotb.test()
async def tx_frames_match_tap_capture_edges(dut):
    bench = XgmiiBench(dut)
    await bench.start()
    obs = bench.obs
    lengths = [16, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 100, 1514]
    for index, length in enumerate(lengths):
        await bench.send_tx(_frame(index, length), index + 1)
    await bench.send_tx(_frame(0x70, 64), 0x00)
    await bench.wait_tx_idle()

    _assert_alignment(obs.tx_starts, obs.tx_oracle, "TX")
    assert [t for _, t in obs.tx_starts] == [i + 1 for i in range(len(lengths))] + [0]
    assert len(obs.tx_wire) == len(lengths) + 1
    wire_lengths = [_check_wire(w, _frame(i, n)) for i, (w, n) in enumerate(zip(obs.tx_wire, lengths))]
    _check_wire(obs.tx_wire[-1], _frame(0x70, 64))
    assert [(e, n, t) for _, e, n, t in obs.tx_dones] == [(0, w, i + 1) for i, w in enumerate(wire_lengths)]
    assert obs.tx_retires == []


@cocotb.test()
async def tx_link_loss_resolves_each_frame_once(dut):
    bench = XgmiiBench(dut)
    await bench.start()
    obs = bench.obs
    frame = _frame(0x20, 400)

    dut.phyReady.value = 0
    await bench.send_tx(frame, 0x11)
    await bench.edge(16)
    dut.phyReady.value = 1
    await bench.edge(16)

    send = cocotb.start_soon(bench.send_tx(frame, 0x12))
    await bench.wait_tx_octets(8 + 100)
    dut.phyReady.value = 0
    await send
    await bench.edge(16)
    dut.phyReady.value = 1
    await bench.wait_tx_idle()

    # 61 bytes: the last word carries three FCS octets and the fourth spills
    # into a tail word; link loss lands on the tail edge, after the input tLast
    short = _frame(0x21, 61)
    send = cocotb.start_soon(bench.send_tx(short, 0x13))
    await bench.drop_phy_at_octets(7 + 61 + 3)
    await send
    await bench.edge(16)
    dut.phyReady.value = 1
    await bench.edge(4)
    await bench.send_tx(_frame(0x22, 64), 0x14)
    await bench.wait_tx_idle()

    _assert_alignment(obs.tx_starts, obs.tx_oracle, "TX")
    assert [t for _, t in obs.tx_starts] == [0x12, 0x13, 0x14]
    assert [t for _, t in obs.tx_retires] == [0x11]
    assert [(e, n, t) for _, e, n, t in obs.tx_dones] == [(1, 400, 0x12), (1, 61, 0x13), (0, 64, 0x14)]
    assert [w["er"] for w in obs.tx_wire] == [True, True, False]
    _check_wire(obs.tx_wire[2], _frame(0x22, 64))


@cocotb.test()
async def tx_underrun_reports_wire_error(dut):
    bench = XgmiiBench(dut)
    await bench.start()
    obs = bench.obs
    await bench.send_tx(_frame(0x30, 200), 0x21, gap_after_beat=1, gap_cycles=32)
    await bench.wait_tx_idle()
    await bench.send_tx(_frame(0x31, 64), 0x22)
    await bench.wait_tx_idle()

    _assert_alignment(obs.tx_starts, obs.tx_oracle, "TX")
    assert [t for _, t in obs.tx_starts] == [0x21, 0x22]
    assert obs.tx_underrun == 1
    assert [(e, n, t) for _, e, n, t in obs.tx_dones] == [(1, 200, 0x21), (0, 64, 0x22)]
    assert obs.tx_wire[0]["er"]
    _check_wire(obs.tx_wire[1], _frame(0x31, 64))


@cocotb.test()
async def tx_abort_ends_frame_before_ack(dut):
    bench = XgmiiBench(dut)
    await bench.start()
    obs = bench.obs
    send = cocotb.start_soon(bench.send_tx(_frame(0x40, 800), 0x31))
    await bench.wait_tx_octets(8 + 200)
    dut.abortReq.value = 1
    await send
    await bench.edge(64)
    assert obs.abort_ack, "abort was not acknowledged"
    done_cycles = [c for c, *_r in obs.tx_dones]
    assert [(e, n, t) for _, e, n, t in obs.tx_dones] == [(1, 800, 0x31)]
    assert done_cycles[0] < obs.abort_ack[0]
    dut.abortReq.value = 0
    await bench.edge(4)
    await bench.send_tx(_frame(0x42, 64), 0x33)
    await bench.wait_tx_idle()
    _assert_alignment(obs.tx_starts, obs.tx_oracle, "TX")
    assert [t for _, t in obs.tx_starts] == [0x31, 0x33]
    assert obs.tx_wire[0]["er"]
    _check_wire(obs.tx_wire[1], _frame(0x42, 64))


def test_EthMacTimingXgmiiLeaf():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactimingxgmiileafwrapper",
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
