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
from cocotb.triggers import FallingEdge, Timer

from tests.axi.utils import wait_sampled_ready
from tests.common.regression_utils import sample_after_tpd


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

    async def wait_valid(self, *, clk, timeout_cycles: int = 256) -> AxisBeat:
        await Timer(1, unit="ns")
        if int(self._sig("TVALID").value) == 1:
            return self.snapshot()
        for _ in range(timeout_cycles):
            await FallingEdge(clk)
            await Timer(1, unit="ns")
            if int(self._sig("TVALID").value) == 1:
                return self.snapshot()
            await sample_after_tpd(clk)
            if int(self._sig("TVALID").value) == 1:
                return self.snapshot()
        raise AssertionError(f"Timed out waiting for {self.prefix} valid")

    async def recv(self, *, clk, keep_ready: bool = False) -> AxisBeat:
        self._sig("TREADY").value = 1
        beat = await self.wait_valid(clk=clk)
        await sample_after_tpd(clk)
        if not keep_ready:
            self._sig("TREADY").value = 0
        return beat


def start_batcher_clock(dut, *, period_ns: float = 5.0) -> None:
    cocotb.start_soon(Clock(dut.axisClk, period_ns, unit="ns").start())


async def cycle(clk, count: int = 1) -> None:
    for _ in range(count):
        await sample_after_tpd(clk)


async def reset_batcher_dut(dut, *, cycles: int = 4) -> None:
    dut.axisRst.setimmediatevalue(1)
    await cycle(dut.axisClk, cycles)
    dut.axisRst.value = 0
    await cycle(dut.axisClk, 2)


def word_from_bytes(data: bytes) -> int:
    return int.from_bytes(data.ljust(8, b"\x00"), "little")


def bytes_from_word(word: int, *, keep: int = 0xFF) -> bytes:
    raw = word.to_bytes(8, "little")
    return bytes(raw[index] for index in range(8) if keep & (1 << index))


def keep_count(keep: int) -> int:
    return sum(1 for lane in range(8) if keep & (1 << lane))


def user_from_lanes(values: list[int]) -> int:
    user = 0
    for lane, value in enumerate(values):
        user |= (value & 0xFF) << (8 * lane)
    return user


def payload_to_beats(payload: bytes, *, dest: int, first_user: int, last_user: int) -> list[AxisBeat]:
    beats = []
    for offset in range(0, len(payload), 8):
        chunk = payload[offset : offset + 8]
        is_first = offset == 0
        is_last = offset + 8 >= len(payload)
        user_values = [0] * len(chunk)
        if is_first:
            user_values[0] = first_user
        if is_last:
            user_values[-1] = last_user
        beats.append(
            AxisBeat(
                data=word_from_bytes(chunk),
                keep=(1 << len(chunk)) - 1,
                last=int(is_last),
                dest=dest,
                user=user_from_lanes(user_values),
            )
        )
    return beats


def batcher_v2_header(*, seq: int = 0, data_bytes: int = 8) -> bytes:
    width = (data_bytes // 2).bit_length() - 1
    return bytes([0x2 | ((width & 0xF) << 4), seq & 0xFF])


def batcher_subframe_tail(*, byte_count: int, dest: int, first_user: int, last_user: int) -> bytes:
    return (
        byte_count.to_bytes(4, "little")
        + bytes([dest & 0xFF, first_user & 0xFF, last_user & 0xFF])
    )


def expected_batched_bytes(frames: list[tuple[bytes, int, int, int]], *, seq: int = 0) -> bytes:
    stream = bytearray(batcher_v2_header(seq=seq))
    for payload, dest, first_user, last_user in frames:
        stream.extend(payload)
        stream.extend(
            batcher_subframe_tail(
                byte_count=len(payload),
                dest=dest,
                first_user=first_user,
                last_user=last_user,
            )
        )
    return bytes(stream)


async def send_frame(endpoint: FlatAxisEndpoint, beats: list[AxisBeat], *, clk) -> None:
    for beat in beats:
        await endpoint.send(beat, clk=clk)


async def send_frames_concurrently(
    frames: list[tuple[FlatAxisEndpoint, list[AxisBeat]]],
    *,
    clk,
) -> None:
    tasks = [cocotb.start_soon(send_frame(endpoint, beats, clk=clk)) for endpoint, beats in frames]
    for task in tasks:
        await task


async def recv_until_last(endpoint: FlatAxisEndpoint, *, clk, max_beats: int = 32) -> list[AxisBeat]:
    beats = []
    for _ in range(max_beats):
        beat = await endpoint.recv(clk=clk, keep_ready=True)
        beats.append(beat)
        if beat.last:
            endpoint._sig("TREADY").value = 0
            return beats
    endpoint._sig("TREADY").value = 0
    raise AssertionError("Timed out waiting for terminal batcher beat")


async def recv_beats(endpoint: FlatAxisEndpoint, *, clk, count: int) -> list[AxisBeat]:
    beats = []
    for _ in range(count):
        beats.append(await endpoint.recv(clk=clk, keep_ready=True))
    endpoint._sig("TREADY").value = 0
    return beats


async def expect_no_valid(endpoint: FlatAxisEndpoint, *, clk, cycles: int) -> None:
    endpoint._sig("TREADY").value = 1
    for _ in range(cycles):
        await sample_after_tpd(clk)
        assert int(endpoint._sig("TVALID").value) == 0
    endpoint._sig("TREADY").value = 0


async def recv_until_last_with_backpressure(
    endpoint: FlatAxisEndpoint,
    *,
    clk,
    hold_cycles: int = 2,
    max_beats: int = 32,
) -> list[AxisBeat]:
    beats = []
    endpoint._sig("TREADY").value = 0
    for _ in range(max_beats):
        beat = await endpoint.wait_valid(clk=clk)
        for _ in range(hold_cycles):
            await sample_after_tpd(clk)
            assert endpoint.snapshot() == beat
        endpoint._sig("TREADY").value = 1
        await sample_after_tpd(clk)
        endpoint._sig("TREADY").value = 0
        beats.append(beat)
        if beat.last:
            return beats
    raise AssertionError("Timed out waiting for terminal batcher beat")


def beats_to_bytes(beats: list[AxisBeat]) -> bytes:
    payload = bytearray()
    for beat in beats:
        payload.extend(bytes_from_word(beat.data, keep=beat.keep))
    return bytes(payload)
