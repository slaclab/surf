##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Shared bench for timing-mode EthMacTop regressions (EthMacTopTimingWrapper).

The bench acts as the timing port: it offers the lowest free RX token after
every start and reclaims it on delivery or retire, recording each resolution
so tests can require exactly one terminal disposition per token.
"""

from __future__ import annotations

import zlib

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.ethernet.EthMacCore.ethmac_test_utils import (
    FlatEmacEndpoint,
    build_ethernet_frame,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
)


TIMING_WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTopTimingWrapper.vhd"

CLK_PERIOD_NS = 8
LOCAL_MAC = 0x001122334455
OTHER_MAC = 0x00AABBCCDDEE
RX_SOURCES = {0: "pause", 1: "filter", 2: "fifo_ib", 3: "fifo_ob", 4: "import"}
TX_SOURCES = {0: "csum", 1: "export"}
TOKEN_POOL = list(range(1, 17))


def timing_frame(seed: int, length: int, dst: int = LOCAL_MAC) -> bytes:
    return build_ethernet_frame(
        dst_mac=dst,
        src_mac=0x660102030405,
        eth_type=0x88B5,
        payload=bytes(((seed + index) & 0xFF) for index in range(length - 14)),
    )


def gmii_wire(frame: bytes, *, fcs: bytes | None = None) -> bytes:
    return bytes([0x55] * 7 + [0xD5]) + frame + (zlib.crc32(frame).to_bytes(4, "little") if fcs is None else fcs)


class RetireBench:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.ethClk
        self.source = FlatEmacEndpoint(dut, prefix="sAxis")
        self.free = list(TOKEN_POOL)
        self.allocated: set[int] = set()
        self.resolutions: list[tuple[int, str]] = []
        self.errors: list[str] = []
        self.delivered: list[tuple[int, bytes]] = []
        self.tx_starts: list[int] = []
        self.tx_dones: list[tuple[int, int]] = []
        self.tx_retires: list[tuple[str, int]] = []
        self.tx_frames = 0
        # (cycle, kind, token) for every start, terminal event and retire
        self.log: list[tuple[int, str, int]] = []
        self.cycle = 0
        self._beats: list[bytes] = []
        self._beat_tids: set[int] = set()

    async def start(self, *, filt: int = 0, pause: int = 1) -> None:
        dut = self.dut
        self.clock_task = cocotb.start_soon(Clock(self.clk, CLK_PERIOD_NS, unit="ns").start())
        dut.ethRst.setimmediatevalue(1)
        dut.phyReady.setimmediatevalue(1)
        dut.rxInject.setimmediatevalue(1)
        dut.injRxDv.setimmediatevalue(0)
        dut.injRxEr.setimmediatevalue(0)
        dut.injRxd.setimmediatevalue(0)
        dut.mAxisTReady.setimmediatevalue(1)
        dut.localMac.setimmediatevalue(mac_config_word_from_wire(LOCAL_MAC))
        dut.filtEnable.setimmediatevalue(filt)
        dut.dropOnPause.setimmediatevalue(0)
        dut.pauseEnable.setimmediatevalue(pause)
        dut.rxNextToken.setimmediatevalue(self.free[0])
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

    def _release(self, token: int, how: str) -> None:
        if token not in self.allocated:
            self.errors.append(f"{how} for token {token:#x} that is not allocated")
            return
        self.allocated.remove(token)
        self.free.append(token)
        self.free.sort()
        self.resolutions.append((token, how))

    def release_all(self, how: str = "abort") -> list[int]:
        # The port's forced-abort release: every remaining entry, once
        released = sorted(self.allocated)
        for token in released:
            self._release(token, how)
        return released

    async def _monitor(self) -> None:
        """Lifetime agent: bench-owned monitor. Propagation sampling: outputs at +2 ns."""
        dut = self.dut
        while True:
            await RisingEdge(self.clk)
            await Timer(2, unit="ns")
            self.cycle += 1
            cyc = self.cycle
            # RX allocation: the offered token becomes owned at start
            if int(dut.rxStart.value):
                token = int(dut.rxStartToken.value)
                self.log.append((cyc, "rx_start", token))
                if token != 0:
                    if token not in self.free:
                        self.errors.append(f"start echoed token {token:#x} that was not free")
                    else:
                        self.free.remove(token)
                        self.allocated.add(token)
            # RX delivery: the last accepted beat releases the token
            if int(dut.mAxisTValid.value) and int(dut.mAxisTReady.value):
                keep = int(dut.mAxisTKeep.value)
                data = int(dut.mAxisTData.value).to_bytes(16, "little")
                self._beats.append(bytes(data[i] for i in range(16) if (keep >> i) & 1))
                self._beat_tids.add(int(dut.mAxisTId.value))
                if int(dut.mAxisTLast.value):
                    if len(self._beat_tids) != 1 or int(dut.mAxisEofe.value):
                        self.errors.append(f"delivered frame tids {self._beat_tids}, eofe {int(dut.mAxisEofe.value)}")
                    token = next(iter(self._beat_tids))
                    self.log.append((cyc, "delivered", token))
                    self.delivered.append((token, b"".join(self._beats)))
                    self._release(token, "delivered")
                    self._beats = []
                    self._beat_tids = set()
            # RX retires
            valid = int(dut.rxRetireValid.value)
            tokens = int(dut.rxRetireToken.value)
            for index, name in RX_SOURCES.items():
                if (valid >> index) & 1:
                    self.log.append((cyc, f"rx_{name}", (tokens >> (8 * index)) & 0xFF))
                    self._release((tokens >> (8 * index)) & 0xFF, name)
            # TX events
            if int(dut.rxDone.value):
                self.log.append((cyc, "rx_done", int(dut.rxDoneToken.value)))
            if int(dut.txStart.value):
                self.tx_starts.append(int(dut.txStartToken.value))
                self.log.append((cyc, "tx_start", int(dut.txStartToken.value)))
            if int(dut.txDone.value):
                self.tx_dones.append((int(dut.txDoneToken.value), int(dut.txDoneError.value)))
                self.log.append((cyc, "tx_done", int(dut.txDoneToken.value)))
            valid = int(dut.txRetireValid.value)
            tokens = int(dut.txRetireToken.value)
            for index, name in TX_SOURCES.items():
                if (valid >> index) & 1:
                    self.tx_retires.append((name, (tokens >> (8 * index)) & 0xFF))
                    self.log.append((cyc, f"tx_{name}", (tokens >> (8 * index)) & 0xFF))
            # Offer the lowest free token, as the port's registered nextToken
            dut.rxNextToken.value = self.free[0] if self.free else 0

    async def inject(self, octets: bytes, *, ifg: int = 12) -> None:
        dut = self.dut
        for octet in octets:
            dut.injRxDv.value = 1
            dut.injRxd.value = octet
            await self.edge()
        dut.injRxDv.value = 0
        dut.injRxd.value = 0
        await self.edge(ifg)

    async def send_tx(self, frame: bytes, token: int, *, eofe: int = 0) -> None:
        beats = frame_beats_from_bytes(frame, eofe=eofe)
        for beat in beats:
            beat.tid = token
            self.source.drive(beat)
            await self.source.wait_ready(clk=self.clk)
        self.source.set_idle()

    async def settle(self, cycles: int = 400) -> None:
        await self.edge(cycles)

    def check_ledger(self) -> None:
        assert not self.errors, self.errors
        assert not self.allocated, f"unresolved tokens {sorted(self.allocated)}"
