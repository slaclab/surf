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
from math import ceil
from collections import deque

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import (
    env_flag,
    env_sl,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


def _bits_from_word(value: int, width: int, *, reverse: bool) -> list[int]:
    bits = [(value >> bit) & 1 for bit in range(width)]
    return list(reversed(bits)) if reverse else bits


def _word_from_bits(bits: list[int], *, reverse: bool) -> int:
    ordered = list(reversed(bits)) if reverse else bits
    value = 0
    for bit_index, bit in enumerate(ordered):
        value |= bit << bit_index
    return value


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.slave_width = int(os.environ["SLAVE_WIDTH_G"])
        self.master_width = int(os.environ["MASTER_WIDTH_G"])
        self.slave_reverse = env_flag("SLAVE_REVERSE", default=False)
        self.master_reverse = env_flag("MASTER_REVERSE", default=False)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.slaveData.value = 0
        dut.slaveValid.value = 0
        dut.startOfSeq.value = 0
        dut.slip.value = 0
        dut.masterReady.value = 1
        dut.slaveBitOrder.value = 1 if self.slave_reverse else 0
        dut.masterBitOrder.value = 1 if self.master_reverse else 0

        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()

    async def reset(self) -> None:
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(3)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(1)

    async def drive_inputs(self, words: list[int], *, start_of_seq_at: int | None = None) -> None:
        observed = await self.run_stream(words, expected_count=0, start_of_seq_at=start_of_seq_at)
        assert observed == []

    async def step(
        self,
        *,
        word: int | None,
        valid: bool,
        master_ready: int,
        start_of_seq: bool = False,
    ) -> tuple[bool, int | None]:
        self.dut.masterReady.value = master_ready
        self.dut.startOfSeq.value = 1 if start_of_seq else 0
        self.dut.slaveValid.value = 1 if valid else 0
        if word is not None:
            self.dut.slaveData.value = word & ((1 << self.slave_width) - 1)

        # Sample the handshakes in the stable part of the cycle, then advance
        # one edge to commit whatever transfer is accepted this cycle.
        await self.settle()
        accepted_input = valid and int(self.dut.slaveReady.value) == 1
        consumed_output = None
        if int(self.dut.masterValid.value) == 1 and master_ready == 1:
            consumed_output = int(self.dut.masterData.value)

        await self.cycle(1)
        return accepted_input, consumed_output

    async def run_stream(
        self,
        words: list[int],
        *,
        expected_count: int,
        start_of_seq_at: int | None = None,
        master_ready: int = 1,
        max_cycles: int = 128,
    ) -> list[int]:
        observed: list[int] = []
        input_index = 0

        for cycle_index in range(max_cycles):
            valid = input_index < len(words)
            current_word = words[input_index] if valid else None
            accepted_input, consumed_output = await self.step(
                word=current_word,
                valid=valid,
                master_ready=master_ready,
                start_of_seq=start_of_seq_at == input_index if valid else False,
            )

            if consumed_output is not None:
                observed.append(consumed_output)
            if accepted_input:
                input_index += 1

            if input_index == len(words) and len(observed) == expected_count:
                self.dut.slaveValid.value = 0
                self.dut.startOfSeq.value = 0
                return observed

        assert False, "Timed out streaming gearbox traffic"
        return observed

    async def wait_for_held_output(self, max_cycles: int = 64) -> int:
        for _ in range(max_cycles):
            await self.settle()
            if int(self.dut.masterValid.value) == 1:
                return int(self.dut.masterData.value)
            await self.cycle(1)
        assert False, "Timed out waiting for gearbox masterValid"
        return 0


def _expected_outputs(
    words: list[int],
    *,
    slave_width: int,
    master_width: int,
    slave_reverse: bool,
    master_reverse: bool,
    start_of_seq_at: int | None = None,
) -> list[int]:
    queue: deque[int] = deque()
    outputs: list[int] = []

    for index, word in enumerate(words):
        if start_of_seq_at == index:
            queue.clear()
        queue.extend(
            _bits_from_word(word, slave_width, reverse=slave_reverse),
        )
        while len(queue) >= master_width:
            bits = [queue.popleft() for _ in range(master_width)]
            outputs.append(_word_from_bits(bits, reverse=master_reverse))

    return outputs


@cocotb.test()
async def width_conversion_test(dut):
    tb = TB(dut)
    await tb.reset()

    words = [0x12, 0x34, 0x56]
    expected = _expected_outputs(
        words,
        slave_width=tb.slave_width,
        master_width=tb.master_width,
        slave_reverse=tb.slave_reverse,
        master_reverse=tb.master_reverse,
    )

    assert await tb.run_stream(words, expected_count=len(expected)) == expected


@cocotb.test()
async def backpressure_hold_test(dut):
    tb = TB(dut)
    await tb.reset()

    words_needed = ceil(tb.master_width / tb.slave_width)
    words = [(0xAB + index) & ((1 << tb.slave_width) - 1) for index in range(words_needed)]
    await tb.run_stream(words, expected_count=0, master_ready=0)

    # Once valid data is waiting, backpressure should hold the same output word
    # stable until the consumer reasserts readiness.
    held_value = await tb.wait_for_held_output()
    await tb.cycle(2)
    assert int(dut.masterValid.value) == 1
    assert int(dut.masterData.value) == held_value

    tb.dut.masterReady.value = 1
    # Releasing masterReady should eventually let the held word drain, even if
    # the next cycle already presents a different queued output word.
    for _ in range(4):
        await tb.cycle(1)
        if int(dut.masterValid.value) == 0:
            break
        if int(dut.masterData.value) != held_value:
            break
    else:
        assert False, "Gearbox held the same output after backpressure released"


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Prime the gearbox with just enough input to create one pending output
    # word, then assert reset while that word is being held.
    words_needed = ceil(tb.master_width / tb.slave_width)
    words = [(0x3C + index) & ((1 << tb.slave_width) - 1) for index in range(words_needed)]
    await tb.run_stream(words, expected_count=0, master_ready=0)
    await tb.wait_for_held_output()

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.masterValid.value) == 0
    else:
        await tb.cycle(1)
        assert int(dut.masterValid.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "down_convert",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SLAVE_WIDTH_G="8",
        MASTER_WIDTH_G="4",
        SLAVE_REVERSE="false",
        MASTER_REVERSE="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "up_convert",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SLAVE_WIDTH_G="4",
        MASTER_WIDTH_G="8",
        SLAVE_REVERSE="false",
        MASTER_REVERSE="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "bit_reverse_async_reset",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        SLAVE_WIDTH_G="8",
        MASTER_WIDTH_G="4",
        SLAVE_REVERSE="true",
        MASTER_REVERSE="true",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Gearbox(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.gearbox",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
