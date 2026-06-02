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

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamSink


def pack_bytes(data: bytes, width_bytes: int = 8) -> int:
    """Pack a short little-endian byte string into one AXI Stream beat."""

    return int.from_bytes(data.ljust(width_bytes, b"\x00"), "little")


def keep_mask(length: int) -> int:
    """Return the byte-valid mask for a beat with `length` payload bytes."""

    return (1 << length) - 1


class VcFifoTb:
    """Async-clock AXI Stream harness used by the shared PGP VC FIFO tests.

    These wrappers sit between two clock domains, so the helper owns both clock
    generators and exposes explicit "cycle source" and "cycle sink" coroutines.
    That makes the CDC behavior visible in the tests instead of hiding it
    behind a single global clock.
    """

    def __init__(
        self,
        dut,
        *,
        source_clk_name: str,
        source_rst_name: str,
        sink_clk_name: str,
        sink_rst_name: str,
        source_period_ns: float = 5.0,
        sink_period_ns: float = 7.0,
    ):
        self.dut = dut
        self.source_clk = getattr(dut, source_clk_name)
        self.source_rst = getattr(dut, source_rst_name)
        self.sink_clk = getattr(dut, sink_clk_name)
        self.sink_rst = getattr(dut, sink_rst_name)
        self.sink = None

        cocotb.start_soon(Clock(self.source_clk, source_period_ns, unit="ns").start())
        cocotb.start_soon(Clock(self.sink_clk, sink_period_ns, unit="ns").start())

    async def settle(self):
        # SURF RTL commonly uses `TPD_G => 1 ns`, so wait a moment after each
        # edge before sampling registered outputs.
        await Timer(1, unit="ns")

    async def cycle_source(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.source_clk)
            await self.settle()

    async def cycle_sink(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.sink_clk)
            await self.settle()

    def drive_source_idle(self):
        # Holding every source signal at an explicit idle value avoids
        # accidental stale payload bits between frames.
        self.dut.S_AXIS_TVALID.value = 0
        self.dut.S_AXIS_TDATA.value = 0
        self.dut.S_AXIS_TKEEP.value = 0
        self.dut.S_AXIS_TLAST.value = 0
        self.dut.S_AXIS_TDEST.value = 0
        self.dut.S_AXIS_TID.value = 0
        self.dut.S_AXIS_TUSER.value = 0

    async def reset(self, *, link_signals: tuple[str, ...] = ()):
        # Reset both domains together, then also clear any wrapper-visible link
        # status inputs so each test starts from the same known state.
        self.source_rst.setimmediatevalue(1)
        self.sink_rst.setimmediatevalue(1)
        self.drive_source_idle()
        self.dut.M_AXIS_TREADY.setimmediatevalue(0)
        for name in link_signals:
            getattr(self.dut, name).setimmediatevalue(0)

        await self.cycle_source(4)
        await self.cycle_sink(4)

        self.source_rst.value = 0
        self.sink_rst.value = 0
        await self.cycle_source(4)
        await self.cycle_sink(4)

    def start_sink(self):
        # The sink is created lazily so tests that only need wrapper output
        # visibility do not pay for extra cocotbext agents they never use.
        if self.sink is None:
            self.sink = AxiStreamSink(
                bus=AxiStreamBus.from_prefix(self.dut, "M_AXIS"),
                clock=self.sink_clk,
                reset=self.sink_rst,
                reset_active_level=True,
            )

    async def send_frame(
        self,
        payload: bytes,
        *,
        tdest: int = 0,
        tid: int = 0,
        tuser_last: int = 0,
        on_handshake=None,
    ):
        """Drive one AXI Stream frame beat-by-beat.

        The helper intentionally performs the ready/valid handshake in-line.
        That makes it easy for a test to inject side effects at the exact beat
        where a transfer was accepted, which is useful for cases like
        "drop link immediately after the first beat."
        """

        beats = [payload[index : index + 8] for index in range(0, len(payload), 8)]
        for index, beat in enumerate(beats):
            self.dut.S_AXIS_TVALID.value = 1
            self.dut.S_AXIS_TDATA.value = pack_bytes(beat)
            self.dut.S_AXIS_TKEEP.value = keep_mask(len(beat))
            self.dut.S_AXIS_TLAST.value = int(index == len(beats) - 1)
            self.dut.S_AXIS_TDEST.value = tdest
            self.dut.S_AXIS_TID.value = tid
            self.dut.S_AXIS_TUSER.value = tuser_last if index == len(beats) - 1 else 0

            while True:
                await RisingEdge(self.source_clk)
                await self.settle()
                if int(self.dut.S_AXIS_TREADY.value) == 1:
                    if on_handshake is not None:
                        await on_handshake(index)
                    break

        self.drive_source_idle()
        await self.cycle_source(1)

    async def expect_no_output_valid(self, *, sink_cycles: int = 32):
        """Assert that no sink-side beat becomes visible for a short window."""

        for _ in range(sink_cycles):
            assert int(self.dut.M_AXIS_TVALID.value) == 0
            await self.cycle_sink()
