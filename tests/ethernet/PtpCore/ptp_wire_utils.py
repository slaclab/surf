##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Wire stimulus and observation for Phase 0; no production timestamp tap."""

from dataclasses import dataclass
from fractions import Fraction
import zlib

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time

from tests.ethernet.EthMacCore.ethmac_test_utils import FlatEmacEndpoint, payload_from_beats, setup_flat_emac_testbench
from tests.ethernet.PtpCore.ptp_reference import Capture

IDLE = 0x0707070707070707


def ptp_frame(sequence=1, message_type=0, ethertype=b"\x88\xf7", source=bytes.fromhex("001122fffe3344550001")):
    header = bytearray(44)
    header[0] = message_type
    header[1] = 0x12
    header[2:4] = (44).to_bytes(2, "big")
    header[6:8] = (0x0200 if message_type == 0 else 0).to_bytes(2, "big")
    header[20:30] = source
    header[30:32] = sequence.to_bytes(2, "big")
    header[32] = message_type
    header[33] = 0x7f if message_type == 1 else 0
    return bytes.fromhex("011b19000000001122334455") + ethertype + header + bytes(2)


def ptp_key(frame):
    if len(frame) < 58 or frame[12:14] != b"\x88\xf7":
        return None
    return (frame[14] & 15, frame[18], frame[34:44], int.from_bytes(frame[44:46], "big"))


def xgmii_words(frame, lane=0, corrupt_crc=False):
    assert lane in (0, 4)
    fcs = zlib.crc32(frame).to_bytes(4, "little")
    if corrupt_crc:
        fcs = bytes([fcs[0] ^ 1]) + fcs[1:]
    stream = [(7, 1)] * lane + [(0xfb, 1)] + [(0x55, 0)] * 6 + [(0xd5, 0)]
    stream += [(byte, 0) for byte in frame + fcs] + [(0xfd, 1)] + [(7, 1)] * 16
    stream += [(7, 1)] * (-len(stream) % 8)
    return [(sum(byte << (8 * i) for i, (byte, _) in enumerate(stream[n:n+8])),
             sum(ctrl << i for i, (_, ctrl) in enumerate(stream[n:n+8])))
            for n in range(0, len(stream), 8)]


@dataclass
class WireFrame:
    frame: bytes
    capture: Capture


class WireObserver:
    def __init__(self, period_ns=Fraction(32, 5)):
        self.period_ns = Fraction(period_ns)
        self.frames = []
        self.body = None
        self.timestamp = None

    def sample(self, data, controls, edge_ns):
        for lane in range(8):
            byte, control = (data >> (8 * lane)) & 255, (controls >> lane) & 1
            if control and byte == 0xfb:
                self.body = bytearray()
                self.timestamp = edge_ns + Fraction(lane + 8, 8)*self.period_ns
            elif self.body is not None:
                if control:
                    raw, self.body = bytes(self.body), None
                    if byte != 0xfd or len(raw) < 11 or raw[:7] != b"\x55" * 6 + b"\xd5":
                        continue
                    frame, fcs = raw[7:-4], raw[-4:]
                    valid = fcs == zlib.crc32(frame).to_bytes(4, "little")
                    self.frames.append(WireFrame(frame, Capture(ptp_key(frame), len(self.frames), self.timestamp, valid=valid)))
                else:
                    self.body.append(byte)


class MacBench:
    def __init__(self, dut):
        self.dut = dut
        self.rx_wire = WireObserver()
        self.tx_wire = WireObserver()
        self.frames = {"mAxis": [], "mByp": []}
        self.partial = {key: [] for key in self.frames}
        self.pulses = {key: [] for key in ("rxFifoDrop", "rxCrcErrorCnt", "rxOverFlow", "rxPauseCnt")}
        self.cycles = 0

    async def start(self):
        self.source = FlatEmacEndpoint(self.dut, prefix="sByp")
        self.source.set_idle()
        await setup_flat_emac_testbench(self.dut, period_ns=6.4, source_prefix="sAxis", initial_values={
            "bypRst": 1, "phyReady": 1, "xgmiiRxd": IDLE, "xgmiiRxc": 255,
            "mAxisTReady": 1, "mBypTReady": 1, "localMac": 0x554433221100,
            "filtEnable": 0, "pauseEnable": 0, "pauseTime": 32, "pauseThresh": 400,
            "ipCsumEn": 0, "tcpCsumEn": 0, "udpCsumEn": 0, "dropOnPause": 0,
        })
        self.dut.bypRst.value = 0
        self.task = cocotb.start_soon(self.monitor())
        await self.wait(40)

    async def monitor(self):
        endpoints = {name: FlatEmacEndpoint(self.dut, prefix=name) for name in self.frames}
        while True:
            # Read values accepted on this edge before the DUT's registered TPD updates.
            await RisingEdge(self.dut.ethClk)
            self.cycles += 1
            now = Fraction(int(get_sim_time(unit="fs")), 1_000_000)
            self.rx_wire.sample(int(self.dut.xgmiiRxd.value), int(self.dut.xgmiiRxc.value), now)
            self.tx_wire.sample(int(self.dut.xgmiiTxd.value), int(self.dut.xgmiiTxc.value), now)
            for name, endpoint in endpoints.items():
                if int(endpoint._sig("TValid").value) and int(endpoint._sig("TReady").value):
                    beat = endpoint.snapshot()
                    self.partial[name].append(beat)
                    if beat.last:
                        assert self.partial[name][0].sof
                        assert not any(b.eofe for b in self.partial[name])
                        self.frames[name].append(payload_from_beats(self.partial[name]))
                        self.partial[name] = []
            for name in self.pulses:
                if int(getattr(self.dut, name).value):
                    self.pulses[name].append(self.cycles)

    async def wait(self, cycles):
        for _ in range(cycles):
            await RisingEdge(self.dut.ethClk)
            await Timer(1, unit="ns")

    async def send(self, frame, **kwargs):
        for data, controls in xgmii_words(frame, **kwargs):
            await FallingEdge(self.dut.ethClk)
            self.dut.xgmiiRxd.value = data
            self.dut.xgmiiRxc.value = controls
            await RisingEdge(self.dut.ethClk)
        await FallingEdge(self.dut.ethClk)
        self.dut.xgmiiRxd.value = IDLE
        self.dut.xgmiiRxc.value = 255

    async def until(self, predicate, cycles=2000):
        for _ in range(cycles):
            if predicate():
                return
            await self.wait(1)
        raise AssertionError("bounded MAC observation timed out")
