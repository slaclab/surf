##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout

from tests.common.regression_utils import (
    env_flag,
    env_sl,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


def _expected_reads(words: list[int], *, wr_width: int, rd_width: int, little_endian: bool) -> list[int]:
    if rd_width > wr_width:
        ratio = rd_width // wr_width
        outputs: list[int] = []
        for start in range(0, len(words), ratio):
            chunk = words[start : start + ratio]
            if len(chunk) < ratio:
                break
            ordered = chunk if little_endian else list(reversed(chunk))
            value = 0
            for index, word in enumerate(ordered):
                value |= word << (index * wr_width)
            outputs.append(value)
        return outputs

    ratio = wr_width // rd_width
    mask = (1 << rd_width) - 1
    outputs = []
    for word in words:
        for index in range(ratio):
            chunk_index = index if little_endian else ratio - 1 - index
            outputs.append((word >> (chunk_index * rd_width)) & mask)
    return outputs


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.wr_width = int(os.environ["WR_DATA_WIDTH_G"])
        self.rd_width = int(os.environ["RD_DATA_WIDTH_G"])
        self.wr_clk_period_ns = float(os.environ["WR_CLK_PERIOD_NS"])
        self.rd_clk_period_ns = float(os.environ["RD_CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.wr_en.value = 0
        dut.rd_en.value = 0
        dut.din.value = 0

        cocotb.start_soon(Clock(dut.wr_clk, self.wr_clk_period_ns, unit="ns").start())
        cocotb.start_soon(Clock(dut.rd_clk, self.rd_clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle_wr(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.wr_clk)
            await self.settle()

    async def cycle_rd(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.rd_clk)
            await self.settle()

    async def reset(self) -> None:
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        # Interleave both domains through reset so the write packer, the FIFO,
        # and the synchronized read-side reset all come out of reset with the
        # same choreography used by the validated async FIFO benches.
        for _ in range(6):
            await RisingEdge(self.dut.wr_clk)
            await RisingEdge(self.dut.rd_clk)
            await self.settle()
        self.dut.rst.value = self.reset_inactive_value()
        for _ in range(6):
            await RisingEdge(self.dut.wr_clk)
            await RisingEdge(self.dut.rd_clk)
            await self.settle()

    async def write_word(self, value: int) -> None:
        while int(self.dut.not_full.value) == 0:
            await RisingEdge(self.dut.wr_clk)
        self.dut.din.value = value
        self.dut.wr_en.value = 1
        await self.cycle_wr(1)
        self.dut.wr_en.value = 0
        await self.cycle_wr(1)

    async def read_word(self) -> int:
        # The wrapper still exposes an FWFT-style contract to cocotb: wait for
        # a visible word or slice, sample it, then pulse `rd_en` once so the
        # read-side state machine advances by exactly one user-visible item.
        await with_timeout(self._wait_valid(), 5, "us")
        value = int(self.dut.dout.value)
        self.dut.rd_en.value = 1
        await self.cycle_rd(1)
        self.dut.rd_en.value = 0
        await self.cycle_rd(1)
        return value

    async def _wait_valid(self) -> None:
        while int(self.dut.valid.value) == 0:
            await RisingEdge(self.dut.rd_clk)


@cocotb.test()
async def width_conversion_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Use the smallest stream that still exercises one complete width
    # conversion. That keeps the test focused on the wrapper's pack/split logic
    # without depending on longer drain behavior through the underlying FIFO.
    if tb.rd_width > tb.wr_width:
        words = [0x12, 0x34]
    else:
        words = [0x1234 & ((1 << tb.wr_width) - 1)]

    expected = _expected_reads(
        words,
        wr_width=tb.wr_width,
        rd_width=tb.rd_width,
        little_endian=env_flag("LITTLE_ENDIAN_G", default=False),
    )

    for value in words:
        await tb.write_word(value)

    observed = []
    for _ in expected:
        observed.append(await tb.read_word())

    assert observed == expected


@cocotb.test()
async def write_packer_reset_test(dut):
    tb = TB(dut)
    await tb.reset()

    if tb.rd_width <= tb.wr_width:
        return

    # When the wrapper is packing several narrow writes into one wider FIFO
    # word, a reset must discard the partial aggregate rather than letting stale
    # pre-reset fragments leak into the next output word.
    await tb.write_word(0xAA)
    await tb.reset()

    post_reset_words = [0x11, 0x22]
    expected = _expected_reads(
        post_reset_words,
        wr_width=tb.wr_width,
        rd_width=tb.rd_width,
        little_endian=env_flag("LITTLE_ENDIAN_G", default=False),
    )

    for value in post_reset_words:
        await tb.write_word(value)

    observed = []
    for _ in expected:
        observed.append(await tb.read_word())

    assert observed == expected


PARAMETER_SWEEP = [
    parameter_case(
        "split_to_narrow_little_endian",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        CASCADE_SIZE_G="1",
        LAST_STAGE_ASYNC_G="true",
        GEN_SYNC_FIFO_G="false",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="distributed",
        FWFT_EN_G="true",
        WR_DATA_WIDTH_G="16",
        RD_DATA_WIDTH_G="8",
        LITTLE_ENDIAN_G="true",
        ADDR_WIDTH_G="4",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="9",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_FifoMux(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.fifomux",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
