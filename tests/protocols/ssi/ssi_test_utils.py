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


@dataclass
class SsiBeat:
    """One SSI transfer beat as seen on the flattened wrapper ports."""

    data: int
    keep: int
    last: int
    dest: int = 0
    tid: int = 0
    sof: int = 0
    eofe: int = 0


@dataclass
class FlatSsiBench:
    """Common cocotb bench wiring for flattened SSI wrappers."""

    clk: object
    source: FlatSsiEndpoint | None = None
    sink: FlatSsiEndpoint | None = None


class FlatSsiEndpoint:
    def __init__(self, dut, *, prefix: str):
        self.dut = dut
        self.prefix = prefix

    def _sig(self, suffix: str):
        return getattr(self.dut, f"{self.prefix}{suffix}")

    def set_idle(self):
        # In cocotb we usually model an idle source by driving `TVALID` low and
        # clearing the payload fields so stale values do not confuse debug.
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
        # This writes the values that will be presented on the next cycle where
        # the DUT samples a valid handshake.
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
        # A source keeps its beat stable until a sampled edge confirms that
        # the sink raised `TREADY`.
        await wait_sampled_ready(
            self._sig("TReady"),
            clk=clk,
        )

    async def send(self, beat: SsiBeat, *, clk):
        # `send()` is the simplest source-side helper: drive one beat, wait for
        # the handshake, then return the bus to idle.
        self.drive(beat)
        await self.wait_ready(clk=clk)
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
        # A sink-side test often wants to notice that a beat is visible before
        # it decides whether to accept that beat.
        await Timer(1, unit="ns")
        if int(self._sig("TValid").value) == 1:
            return self.snapshot()
        for _ in range(timeout_cycles):
            await FallingEdge(clk)
            await Timer(1, unit="ns")
            if int(self._sig("TValid").value) == 1:
                return self.snapshot()
            await RisingEdge(clk)
            await Timer(1, unit="ns")
            if int(self._sig("TValid").value) == 1:
                return self.snapshot()
        raise AssertionError(f"Timed out waiting for {self.prefix} valid")

    async def recv(self, *, clk, ready_signal=None, keep_ready: bool = False) -> SsiBeat:
        # `recv()` optionally raises `TREADY`, waits for one visible beat, then
        # consumes that beat on the next rising clock edge.
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


def data_mask_from_keep(keep: int, *, max_bytes: int = 8) -> int:
    mask = 0
    for byte_index in range(max_bytes):
        if keep & (1 << byte_index):
            mask |= 0xFF << (8 * byte_index)
    return mask


def start_clock(signal, *, period_ns: float = 5.0) -> None:
    # cocotb clocks run in the background once started.
    cocotb.start_soon(Clock(signal, period_ns, unit="ns").start())


async def cycle(clk, count: int = 1) -> None:
    # Most SSI benches sample a little after each edge so registered outputs
    # have time to settle before Python reads them.
    for _ in range(count):
        await RisingEdge(clk)
        await Timer(1, unit="ns")


async def reset_dut(dut, *, clk_name: str = "axisClk", rst_name: str = "axisRst") -> None:
    # Hold reset for a few cycles, then give the DUT a couple of recovery
    # cycles before starting stimulus.
    clk = getattr(dut, clk_name)
    rst = getattr(dut, rst_name)
    rst.value = 1
    await cycle(clk, 4)
    rst.value = 0
    await cycle(clk, 2)


async def setup_flat_ssi_testbench(
    dut,
    *,
    clk_name: str = "axisClk",
    rst_name: str = "axisRst",
    period_ns: float = 5.0,
    source_prefix: str | None = None,
    sink_prefix: str | None = None,
    initial_values: dict[str, int] | None = None,
) -> FlatSsiBench:
    # Most SSI wrapper benches share the same pattern: start one clock, drive
    # reset high immediately, optionally create flat source/sink endpoints,
    # seed a few sideband controls, then release reset.
    clk = getattr(dut, clk_name)
    rst = getattr(dut, rst_name)
    start_clock(clk, period_ns=period_ns)
    rst.setimmediatevalue(1)

    source = None if source_prefix is None else FlatSsiEndpoint(dut, prefix=source_prefix)
    sink = None if sink_prefix is None else FlatSsiEndpoint(dut, prefix=sink_prefix)

    if source is not None:
        source.set_idle()

    if initial_values is not None:
        for signal_name, value in initial_values.items():
            getattr(dut, signal_name).setimmediatevalue(value)

    await reset_dut(dut, clk_name=clk_name, rst_name=rst_name)
    return FlatSsiBench(clk=clk, source=source, sink=sink)


async def send_frame(endpoint: FlatSsiEndpoint, beats: list[SsiBeat], *, clk) -> None:
    # Send one beat at a time, returning to idle after each accepted transfer.
    for beat in beats:
        await endpoint.send(beat, clk=clk)


async def send_contiguous_frame(endpoint: FlatSsiEndpoint, beats: list[SsiBeat], *, clk) -> None:
    # Some SSI modules care about uninterrupted frames, so this helper keeps
    # `TVALID` asserted across the whole packet until each beat is accepted on
    # a sampling clock edge.
    for beat in beats:
        endpoint.drive(beat)
        await endpoint.wait_ready(clk=clk)
    endpoint.set_idle()


async def expect_no_output(endpoint: FlatSsiEndpoint, *, clk, cycles: int = 8) -> None:
    # Use a bounded quiet window instead of assuming the DUT will stay silent
    # forever after a dropped or truncated frame.
    for _ in range(cycles):
        await Timer(1, unit="ns")
        assert int(endpoint._sig("TValid").value) == 0
        await RisingEdge(clk)


async def expect_no_output_data(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    forbidden_data: int,
    cycles: int = 8,
) -> None:
    for _ in range(cycles):
        await Timer(1, unit="ns")
        if int(endpoint._sig("TValid").value) == 1:
            assert endpoint.snapshot().data != forbidden_data
        await RisingEdge(clk)


async def wait_output_clear(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    ready_signal,
    cycles: int = 16,
) -> None:
    ready_signal.value = 1
    for _ in range(cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if int(endpoint._sig("TValid").value) == 0:
            ready_signal.value = 0
            return
    ready_signal.value = 0
    raise AssertionError(f"Timed out waiting for {endpoint.prefix} output to clear")


async def recv_frame(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    ready_signal=None,
    timeout_cycles: int = 128,
) -> list[SsiBeat]:
    if ready_signal is None:
        ready_signal = endpoint._sig("TReady")
        ready_signal.value = 1
        try:
            beats = []
            for _ in range(timeout_cycles):
                beat = await endpoint.recv(clk=clk, ready_signal=ready_signal, keep_ready=True)
                beats.append(beat)
                if beat.last == 1:
                    return beats
            raise AssertionError(f"Timed out waiting for {endpoint.prefix} frame end")
        finally:
            ready_signal.value = 0

    ready_signal.value = 1
    beats = []
    for _ in range(timeout_cycles):
        beat = await endpoint.recv(clk=clk, ready_signal=ready_signal, keep_ready=True)
        beats.append(beat)
        if beat.last == 1:
            ready_signal.value = 0
            return beats

    ready_signal.value = 0
    raise AssertionError(f"Timed out waiting for {endpoint.prefix} frame end")


async def recv_n_beats(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    count: int,
    ready_signal=None,
    timeout_cycles: int = 128,
) -> list[SsiBeat]:
    if ready_signal is None:
        ready_signal = endpoint._sig("TReady")
        ready_signal.value = 1
        try:
            beats = []
            for _ in range(count):
                beats.append(
                    await endpoint.recv(
                        clk=clk,
                        ready_signal=ready_signal,
                        keep_ready=True,
                    )
                )
            return beats
        finally:
            ready_signal.value = 0

    ready_signal.value = 1
    beats = []
    for _ in range(timeout_cycles):
        beats.append(await endpoint.recv(clk=clk, ready_signal=ready_signal, keep_ready=True))
        if len(beats) == count:
            ready_signal.value = 0
            return beats

    ready_signal.value = 0
    raise AssertionError(f"Timed out waiting for {count} {endpoint.prefix} beats")


async def recv_visible_beat(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    ready_signal,
    timeout_cycles: int = 64,
) -> SsiBeat:
    # This helper is for "look before consume" checks. It first waits until a
    # beat is visible with `TREADY` low, then accepts exactly that beat.
    ready_signal.value = 0
    beat = await endpoint.wait_valid(clk=clk, timeout_cycles=timeout_cycles)
    ready_signal.value = 1
    await RisingEdge(clk)
    await Timer(1, unit="ns")
    ready_signal.value = 0
    return beat


async def capture_accepted_beats(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    cycles: int,
) -> list[SsiBeat]:
    beats = []
    for _ in range(cycles):
        # Sample only when both handshake signals are high so the capture list
        # matches the transfers the DUT really completed.
        await FallingEdge(clk)
        await Timer(1, unit="ns")
        if int(endpoint._sig("TValid").value) == 1 and int(endpoint._sig("TReady").value) == 1:
            beats.append(endpoint.snapshot())
    return beats


async def recv_expected_beat(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    ready_signal,
    expected_data: int,
    timeout_cycles: int = 64,
) -> SsiBeat:
    ready_signal.value = 1
    last_seen = None
    for _ in range(timeout_cycles):
        candidate = await endpoint.recv(clk=clk, ready_signal=ready_signal, keep_ready=True)
        last_seen = candidate
        if candidate.data == expected_data:
            ready_signal.value = 0
            return candidate
    ready_signal.value = 0
    raise AssertionError(
        f"Timed out waiting for {endpoint.prefix} data 0x{expected_data:04x}, last_seen={last_seen}"
    )


async def recv_frame_by_data(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    ready_signal,
    expected_data: list[int],
    timeout_cycles: int = 64,
) -> list[SsiBeat]:
    beats = []
    for data_word in expected_data:
        beats.append(
            await recv_expected_beat(
                endpoint,
                clk=clk,
                ready_signal=ready_signal,
                expected_data=data_word,
                timeout_cycles=timeout_cycles,
            )
        )
    return beats


def assert_beat_fields(actual: SsiBeat, expected: SsiBeat) -> None:
    assert actual == expected


def assert_beat_list(actual: list[SsiBeat], expected: list[SsiBeat]) -> None:
    assert len(actual) == len(expected)
    for actual_beat, expected_beat in zip(actual, expected):
        assert_beat_fields(actual_beat, expected_beat)


def beat_view(beat: SsiBeat, fields: tuple[str, ...]) -> tuple[int, ...]:
    return tuple(getattr(beat, field) for field in fields)


def assert_beat_views(
    actual: list[SsiBeat],
    *,
    fields: tuple[str, ...],
    expected: list[tuple[int, ...]],
) -> None:
    assert [beat_view(beat, fields) for beat in actual] == expected


def assert_beat_view(
    actual: SsiBeat,
    *,
    fields: tuple[str, ...],
    expected: tuple[int, ...],
) -> None:
    assert beat_view(actual, fields) == expected


async def recv_frame_and_check(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    ready_signal,
    fields: tuple[str, ...],
    expected: list[tuple[int, ...]],
    timeout_cycles: int = 128,
) -> list[SsiBeat]:
    beats = await recv_frame(
        endpoint,
        clk=clk,
        ready_signal=ready_signal,
        timeout_cycles=timeout_cycles,
    )
    assert_beat_views(beats, fields=fields, expected=expected)
    return beats


async def recv_n_beats_and_check(
    endpoint: FlatSsiEndpoint,
    *,
    clk,
    count: int,
    ready_signal,
    fields: tuple[str, ...],
    expected: list[tuple[int, ...]],
    timeout_cycles: int = 128,
) -> list[SsiBeat]:
    beats = await recv_n_beats(
        endpoint,
        clk=clk,
        count=count,
        ready_signal=ready_signal,
        timeout_cycles=timeout_cycles,
    )
    assert_beat_views(beats, fields=fields, expected=expected)
    return beats


async def wait_signal_level(signal, *, clk, expected: int, cycles: int = 32) -> None:
    for _ in range(cycles):
        if int(signal.value) == expected:
            return
        await RisingEdge(clk)
        await Timer(1, unit="ns")
    raise AssertionError(f"Timed out waiting for {signal}={expected}")


async def wait_signal_pulse(signal, *, clk, cycles: int = 32) -> None:
    await wait_signal_level(signal, clk=clk, expected=1, cycles=cycles)
