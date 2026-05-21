##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from __future__ import annotations

from dataclasses import dataclass

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.axi.utils import wait_sampled_ready

PACKETIZER2_VERSION = 0x2
PACKETIZER2_CRC_NONE = 0x0
PACKETIZER2_CRC_DATA = 0x1
PACKETIZER2_CRC_FULL = 0x2
PACKETIZER0_VERSION = 0x0
SSI_EOFE = 0
SSI_SOF = 1


@dataclass
class AxisBeat:
    data: int
    keep: int = 0xFF
    last: int = 0
    dest: int = 0
    tid: int = 0
    user: int = 0


class FlatAxisEndpoint:
    def __init__(self, dut, *, prefix: str):
        self.dut = dut
        self.prefix = prefix

    def _sig(self, suffix: str):
        return getattr(self.dut, f"{self.prefix}_{suffix}")

    def set_idle(self) -> None:
        for suffix, value in (
            ("TVALID", 0),
            ("TDATA", 0),
            ("TKEEP", 0),
            ("TLAST", 0),
            ("TDEST", 0),
            ("TID", 0),
            ("TUSER", 0),
        ):
            if hasattr(self.dut, f"{self.prefix}_{suffix}"):
                self._sig(suffix).value = value

    def drive(self, beat: AxisBeat) -> None:
        self._sig("TVALID").value = 1
        self._sig("TDATA").value = beat.data
        self._sig("TKEEP").value = beat.keep
        self._sig("TLAST").value = beat.last
        self._sig("TDEST").value = beat.dest
        self._sig("TID").value = beat.tid
        self._sig("TUSER").value = beat.user

    def snapshot(self) -> AxisBeat:
        return AxisBeat(
            data=int(self._sig("TDATA").value),
            keep=int(self._sig("TKEEP").value),
            last=int(self._sig("TLAST").value),
            dest=int(self._sig("TDEST").value),
            tid=int(self._sig("TID").value),
            user=int(self._sig("TUSER").value),
        )

    async def send(self, beat: AxisBeat, *, clk) -> None:
        self.drive(beat)
        await wait_sampled_ready(self._sig("TREADY"), clk=clk)
        self.set_idle()

    async def wait_valid(self, *, clk, timeout_cycles: int = 128) -> AxisBeat:
        await Timer(1, unit="ns")
        if int(self._sig("TVALID").value) == 1:
            return self.snapshot()
        for _ in range(timeout_cycles):
            await FallingEdge(clk)
            await Timer(1, unit="ns")
            if int(self._sig("TVALID").value) == 1:
                return self.snapshot()
            await RisingEdge(clk)
            await Timer(1, unit="ns")
            if int(self._sig("TVALID").value) == 1:
                return self.snapshot()
        raise AssertionError(f"Timed out waiting for {self.prefix} valid")

    async def recv(self, *, clk, keep_ready: bool = False) -> AxisBeat:
        self._sig("TREADY").value = 1
        beat = await self.wait_valid(clk=clk)
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if not keep_ready:
            self._sig("TREADY").value = 0
        return beat


def start_packetizer_clock(dut, *, period_ns: float = 5.0) -> None:
    cocotb.start_soon(Clock(dut.axisClk, period_ns, unit="ns").start())


async def cycle(clk, count: int = 1) -> None:
    for _ in range(count):
        await RisingEdge(clk)
        await Timer(1, unit="ns")


async def reset_packetizer_dut(dut, *, cycles: int = 4) -> None:
    dut.axisRst.setimmediatevalue(1)
    await cycle(dut.axisClk, cycles)
    dut.axisRst.value = 0
    await cycle(dut.axisClk, 2)


def word_from_bytes(data: bytes) -> int:
    return int.from_bytes(data.ljust(8, b"\x00"), "little")


def bytes_from_word(word: int, *, keep: int = 0xFF) -> bytes:
    raw = word.to_bytes(8, "little")
    return bytes(raw[index] for index in range(8) if keep & (1 << index))


def payload_to_beats(
    payload: bytes,
    *,
    dest: int,
    tid: int,
    first_user: int,
    last_user: int,
) -> list[AxisBeat]:
    beats = []
    for offset in range(0, len(payload), 8):
        chunk = payload[offset : offset + 8]
        is_first = offset == 0
        is_last = offset + 8 >= len(payload)
        keep = (1 << len(chunk)) - 1
        user = 0
        if is_first:
            user |= first_user
        if is_last:
            user |= last_user << (8 * (len(chunk) - 1))
        beats.append(
            AxisBeat(
                data=word_from_bytes(chunk),
                keep=keep,
                last=int(is_last),
                dest=dest,
                tid=tid,
                user=user,
            )
        )
    return beats


def packetizer2_header_word(*, crc_mode: int, sof: int, tuser: int, tdest: int, tid: int, seq: int) -> int:
    return (
        (PACKETIZER2_VERSION & 0xF)
        | ((crc_mode & 0xF) << 4)
        | ((tuser & 0xFF) << 8)
        | ((tdest & 0xFF) << 16)
        | ((tid & 0xFF) << 24)
        | ((seq & 0xFFFF) << 32)
        | ((sof & 0x1) << 63)
    )


def packetizer2_tail_word(*, eof: int, tuser: int, byte_count: int, crc: int = 0) -> int:
    return (
        (tuser & 0xFF)
        | ((eof & 0x1) << 8)
        | ((byte_count & 0xF) << 16)
        | ((crc & 0xFFFFFFFF) << 32)
    )


def packetizer0_header_word(*, frame: int, packet: int, tdest: int, tid: int, tuser: int) -> int:
    return (
        (PACKETIZER0_VERSION & 0xF)
        | ((frame & 0xFFF) << 4)
        | ((packet & 0xFFFFFF) << 16)
        | ((tdest & 0xFF) << 40)
        | ((tid & 0xFF) << 48)
        | ((tuser & 0xFF) << 56)
    )


def packetizer0_tail_byte(*, eof: int, tuser: int) -> int:
    return ((eof & 0x1) << 7) | (tuser & 0x7F)


async def send_beats(endpoint: FlatAxisEndpoint, beats: list[AxisBeat], *, clk) -> None:
    for beat in beats:
        await endpoint.send(beat, clk=clk)


async def recv_beats(endpoint: FlatAxisEndpoint, count: int, *, clk) -> list[AxisBeat]:
    beats = []
    for _ in range(count):
        beats.append(await endpoint.recv(clk=clk, keep_ready=True))
    endpoint._sig("TREADY").value = 0
    return beats


async def recv_beats_with_backpressure(
    endpoint: FlatAxisEndpoint,
    count: int,
    *,
    clk,
    hold_cycles: int = 2,
) -> list[AxisBeat]:
    beats = []
    endpoint._sig("TREADY").value = 0
    for _ in range(count):
        beat = await endpoint.wait_valid(clk=clk)
        for _ in range(hold_cycles):
            await RisingEdge(clk)
            await Timer(1, unit="ns")
            assert endpoint.snapshot() == beat
        endpoint._sig("TREADY").value = 1
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        endpoint._sig("TREADY").value = 0
        beats.append(beat)
    return beats
