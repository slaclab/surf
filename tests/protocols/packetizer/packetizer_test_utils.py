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

import os
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
DEBUG_INIT_DONE = 12

CRC_MODE_VALUES = {
    "NONE": PACKETIZER2_CRC_NONE,
    "DATA": PACKETIZER2_CRC_DATA,
    "FULL": PACKETIZER2_CRC_FULL,
}


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


async def wait_debug_init_done(dut, *, timeout_cycles: int = 64) -> None:
    for _ in range(timeout_cycles):
        if int(dut.debugOut.value) & (1 << DEBUG_INIT_DONE):
            return
        await RisingEdge(dut.axisClk)
        await Timer(1, unit="ns")
    raise AssertionError("Timed out waiting for depacketizer initDone")


def crc_mode_from_env(default: str = "NONE") -> int:
    return CRC_MODE_VALUES[os.getenv("CRC_MODE_G", default)]


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


def user_from_bytes(values: list[int]) -> int:
    user = 0
    for lane, value in enumerate(values):
        user |= (value & 0xFF) << (8 * lane)
    return user


def tuser_for_lane(lane: int, value: int) -> int:
    return (value & 0xFF) << (8 * lane)


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


def packetizer2_header_beat(
    *,
    sof: int,
    tuser: int,
    dest: int,
    tid: int,
    seq: int,
    crc_mode: int = PACKETIZER2_CRC_NONE,
) -> AxisBeat:
    return AxisBeat(
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=sof,
            tuser=tuser,
            tdest=dest,
            tid=tid,
            seq=seq,
        ),
        keep=0xFF,
        last=0,
        user=0x2,
    )


def packetizer2_data_beat(payload: bytes) -> AxisBeat:
    return AxisBeat(data=word_from_bytes(payload), keep=0xFF, last=0, user=0)


def packetizer2_tail_beat(*, eof: int, tuser: int, byte_count: int, crc: int = 0) -> AxisBeat:
    return AxisBeat(
        data=packetizer2_tail_word(eof=eof, tuser=tuser, byte_count=byte_count, crc=crc),
        keep=0xFF,
        last=1,
        user=0,
    )


def packetizer0_header_beat(*, frame: int, packet: int, tuser: int, dest: int, tid: int) -> AxisBeat:
    return AxisBeat(
        data=packetizer0_header_word(
            frame=frame,
            packet=packet,
            tdest=dest,
            tid=tid,
            tuser=tuser,
        ),
        keep=0xFF,
        last=0,
        user=0x2,
    )


def packetizer_data_beat(payload: bytes, *, keep: int = 0xFF, last: int = 0) -> AxisBeat:
    return AxisBeat(data=word_from_bytes(payload), keep=keep, last=last, user=0)


def assert_packetized_beat(
    beat: AxisBeat,
    *,
    data: int,
    keep: int = 0xFF,
    last: int = 0,
    user: int = 0,
    dest: int = 0,
    tid: int = 0,
) -> None:
    assert beat.data == data
    assert beat.keep == keep
    assert beat.last == last
    assert beat.dest == dest
    assert beat.tid == tid
    assert beat.user == user


def assert_packetizer2_tail_beat(
    beat: AxisBeat,
    *,
    eof: int,
    tuser: int,
    byte_count: int,
    crc_mode: int = PACKETIZER2_CRC_NONE,
) -> None:
    expected = packetizer2_tail_word(eof=eof, tuser=tuser, byte_count=byte_count)
    assert (beat.data & 0xFFFFFFFF) == (expected & 0xFFFFFFFF)
    if crc_mode == PACKETIZER2_CRC_NONE:
        assert (beat.data >> 32) == 0
    else:
        assert (beat.data >> 32) != 0
    assert beat.keep == 0xFF
    assert beat.last == 1
    assert beat.dest == 0
    assert beat.tid == 0
    assert beat.user == 0


def assert_app_beat(
    beat: AxisBeat,
    *,
    payload: bytes,
    keep: int = 0xFF,
    last: int = 0,
    dest: int,
    tid: int,
    user: int = 0,
) -> None:
    assert bytes_from_word(beat.data, keep=keep) == payload
    assert beat.keep == keep
    assert beat.last == last
    assert beat.dest == dest
    assert beat.tid == tid
    assert beat.user == user


async def assert_no_output(
    endpoint: FlatAxisEndpoint,
    *,
    clk,
    cycles: int,
    drive_ready: bool = False,
) -> None:
    if drive_ready:
        endpoint._sig("TREADY").value = 1
    for _ in range(cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        assert int(endpoint._sig("TVALID").value) == 0
    if drive_ready:
        endpoint._sig("TREADY").value = 0


def byte_packer_source_beat(payload: bytes, *, last: int = 0, user_values: list[int]) -> AxisBeat:
    return AxisBeat(
        data=word_from_bytes(payload),
        keep=(1 << len(payload)) - 1,
        last=last,
        user=user_from_bytes(user_values),
    )


def byte_packer_source_beats_from_payload(
    payload: bytes,
    *,
    max_beat_bytes: int,
    user_base: int,
    first_size: int | None = None,
) -> list[AxisBeat]:
    beats = []
    offset = 0
    while offset < len(payload):
        if offset == 0 and first_size is not None:
            size = min(first_size, max_beat_bytes, len(payload))
        else:
            size = min(max_beat_bytes, len(payload) - offset)
        chunk = payload[offset : offset + size]
        beats.append(
            byte_packer_source_beat(
                chunk,
                last=int(offset + size == len(payload)),
                user_values=list(range(user_base + offset, user_base + offset + len(chunk))),
            )
        )
        offset += size
    return beats


async def send_unpaced_beats(endpoint: FlatAxisEndpoint, beats: list[AxisBeat], *, clk) -> None:
    # `AxiStreamBytePacker` has no slave-ready output. Each driven beat is held
    # for exactly one rising edge, which is the module's intended acceptance
    # cadence.
    for beat in beats:
        endpoint.drive(beat)
        await RisingEdge(clk)
        await Timer(1, unit="ns")
    endpoint.set_idle()


async def recv_valid_pulses(endpoint: FlatAxisEndpoint, count: int, *, clk) -> list[AxisBeat]:
    beats = []
    while len(beats) < count:
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if int(endpoint._sig("TVALID").value):
            beats.append(endpoint.snapshot())
    return beats


def assert_packed_beat(
    beat: AxisBeat,
    *,
    payload: bytes,
    user_values: list[int],
    last: int = 0,
) -> None:
    keep = (1 << len(payload)) - 1
    assert bytes_from_word(beat.data, keep=keep) == payload
    assert beat.keep == keep
    assert beat.last == last
    assert beat.user == user_from_bytes(user_values)


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
