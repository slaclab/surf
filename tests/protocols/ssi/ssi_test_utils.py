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
from cocotb.triggers import RisingEdge, Timer


@dataclass
class SsiBeat:
    data: int
    keep: int
    last: int
    dest: int = 0
    tid: int = 0
    sof: int = 0
    eofe: int = 0


class FlatSsiEndpoint:
    def __init__(self, dut, *, prefix: str):
        self.dut = dut
        self.prefix = prefix

    def _sig(self, suffix: str):
        return getattr(self.dut, f"{self.prefix}{suffix}")

    def set_idle(self):
        for suffix, value in (
            ("TValid", 0),
            ("TData", 0),
            ("TKeep", 0),
            ("TLast", 0),
            ("TDest", 0),
            ("TId", 0),
            ("Sof", 0),
            ("Eofe", 0),
        ):
            if hasattr(self.dut, f"{self.prefix}{suffix}"):
                self._sig(suffix).value = value

    def drive(self, beat: SsiBeat):
        self._sig("TValid").value = 1
        self._sig("TData").value = beat.data
        self._sig("TKeep").value = beat.keep
        self._sig("TLast").value = beat.last
        if hasattr(self.dut, f"{self.prefix}TDest"):
            self._sig("TDest").value = beat.dest
        if hasattr(self.dut, f"{self.prefix}TId"):
            self._sig("TId").value = beat.tid
        if hasattr(self.dut, f"{self.prefix}Sof"):
            self._sig("Sof").value = beat.sof
        if hasattr(self.dut, f"{self.prefix}Eofe"):
            self._sig("Eofe").value = beat.eofe

    async def wait_ready(self, *, clk):
        while int(self._sig("TReady").value) != 1:
            await RisingEdge(clk)
            await Timer(1, unit="ns")

    async def send(self, beat: SsiBeat, *, clk):
        self.drive(beat)
        await self.wait_ready(clk=clk)
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        self.set_idle()

    def snapshot(self) -> SsiBeat:
        return SsiBeat(
            data=int(self._sig("TData").value),
            keep=int(self._sig("TKeep").value),
            last=int(self._sig("TLast").value),
            dest=0 if not hasattr(self.dut, f"{self.prefix}TDest") else int(self._sig("TDest").value),
            tid=0 if not hasattr(self.dut, f"{self.prefix}TId") else int(self._sig("TId").value),
            sof=0 if not hasattr(self.dut, f"{self.prefix}Sof") else int(self._sig("Sof").value),
            eofe=0 if not hasattr(self.dut, f"{self.prefix}Eofe") else int(self._sig("Eofe").value),
        )

    async def wait_valid(self, *, clk, timeout_cycles: int = 64) -> SsiBeat:
        for _ in range(timeout_cycles):
            await Timer(1, unit="ns")
            if int(self._sig("TValid").value) == 1:
                return self.snapshot()
            await RisingEdge(clk)
        raise AssertionError(f"Timed out waiting for {self.prefix} valid")

    async def recv(self, *, clk, ready_signal=None, keep_ready: bool = False) -> SsiBeat:
        if ready_signal is not None:
            ready_signal.value = 1
        beat = await self.wait_valid(clk=clk)
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if ready_signal is not None and not keep_ready:
            ready_signal.value = 0
        return beat


def env_data_bytes(name: str = "DATA_BYTES_G", default: int = 2) -> int:
    raw = os.environ.get(name)
    return default if raw is None else int(raw)


def env_int(name: str, *, default: int) -> int:
    raw = os.environ.get(name)
    return default if raw is None else int(raw)


def keep_mask(data_bytes: int) -> int:
    return (1 << data_bytes) - 1


def start_clock(signal, *, period_ns: float = 5.0) -> None:
    cocotb.start_soon(Clock(signal, period_ns, unit="ns").start())


async def cycle(clk, count: int = 1) -> None:
    for _ in range(count):
        await RisingEdge(clk)
        await Timer(1, unit="ns")


async def reset_dut(dut, *, clk_name: str = "axisClk", rst_name: str = "axisRst") -> None:
    clk = getattr(dut, clk_name)
    rst = getattr(dut, rst_name)
    rst.value = 1
    await cycle(clk, 4)
    rst.value = 0
    await cycle(clk, 2)


async def send_frame(endpoint: FlatSsiEndpoint, beats: list[SsiBeat], *, clk) -> None:
    for beat in beats:
        await endpoint.send(beat, clk=clk)


async def send_contiguous_frame(endpoint: FlatSsiEndpoint, beats: list[SsiBeat], *, clk) -> None:
    for beat in beats:
        endpoint.drive(beat)
        await endpoint.wait_ready(clk=clk)
        await RisingEdge(clk)
        await Timer(1, unit="ns")
    endpoint.set_idle()


async def expect_no_output(endpoint: FlatSsiEndpoint, *, clk, cycles: int = 8) -> None:
    for _ in range(cycles):
        await Timer(1, unit="ns")
        assert int(endpoint._sig("TValid").value) == 0
        await RisingEdge(clk)


async def recv_frame(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    ready_signal=None,
    timeout_cycles: int = 128,
) -> list[SsiBeat]:
    beats = []
    for _ in range(timeout_cycles):
        beat = await endpoint.recv(clk=clk, ready_signal=ready_signal, keep_ready=True)
        beats.append(beat)
        if beat.last == 1:
            if ready_signal is not None:
                ready_signal.value = 0
            return beats
    raise AssertionError(f"Timed out waiting for {endpoint.prefix} frame end")


async def recv_n_beats(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    count: int,
    ready_signal=None,
    timeout_cycles: int = 128,
) -> list[SsiBeat]:
    beats = []
    for _ in range(count):
        beats.append(
            await endpoint.recv(
                clk=clk,
                ready_signal=ready_signal,
                keep_ready=True,
            )
        )

    if ready_signal is not None:
        ready_signal.value = 0
    return beats


async def recv_visible_beat(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    ready_signal,
    timeout_cycles: int = 64,
) -> SsiBeat:
    ready_signal.value = 0
    beat = await endpoint.wait_valid(clk=clk, timeout_cycles=timeout_cycles)
    ready_signal.value = 1
    await RisingEdge(clk)
    await Timer(1, unit="ns")
    ready_signal.value = 0
    return beat
