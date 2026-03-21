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
from collections import deque
from math import ceil

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


def _expected_outputs(
    words: list[int],
    *,
    slave_width: int,
    master_width: int,
    slave_reverse: bool,
    master_reverse: bool,
) -> list[int]:
    queue: deque[int] = deque()
    outputs: list[int] = []

    for word in words:
        queue.extend(_bits_from_word(word, slave_width, reverse=slave_reverse))
        while len(queue) >= master_width:
            bits = [queue.popleft() for _ in range(master_width)]
            outputs.append(_word_from_bits(bits, reverse=master_reverse))

    return outputs


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.slave_width = int(os.environ["SLAVE_WIDTH_G"])
        self.master_width = int(os.environ["MASTER_WIDTH_G"])
        self.slave_reverse = env_flag("SLAVE_REVERSE", default=False)
        self.master_reverse = env_flag("MASTER_REVERSE", default=False)
        self.slave_clk_period_ns = float(os.environ["SLAVE_CLK_PERIOD_NS"])
        self.master_clk_period_ns = float(os.environ["MASTER_CLK_PERIOD_NS"])

        dut.slaveRst.value = self.reset_active_value()
        dut.masterRst.value = self.reset_active_value()
        dut.slaveData.value = 0
        dut.slaveValid.value = 0
        dut.slip.value = 0
        dut.masterReady.value = 1
        dut.slaveBitOrder.value = 1 if self.slave_reverse else 0
        dut.masterBitOrder.value = 1 if self.master_reverse else 0

        cocotb.start_soon(Clock(dut.slaveClk, self.slave_clk_period_ns, unit="ns").start())
        cocotb.start_soon(Clock(dut.masterClk, self.master_clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def reset(self) -> None:
        # Reset both visible domains together so the async FIFO and the inner
        # gearbox restart from the same word boundary.
        self.dut.slaveRst.value = self.reset_active_value()
        self.dut.masterRst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        for _ in range(6):
            await RisingEdge(self.dut.slaveClk)
            await RisingEdge(self.dut.masterClk)
        self.dut.slaveRst.value = self.reset_inactive_value()
        self.dut.masterRst.value = self.reset_inactive_value()
        for _ in range(6):
            await RisingEdge(self.dut.slaveClk)
            await RisingEdge(self.dut.masterClk)

    async def produce(self, words: list[int]) -> None:
        index = 0
        while index < len(words):
            # Present the candidate word during the low phase so the upcoming
            # slaveClk edge sees a stable valid/data pair.
            await FallingEdge(self.dut.slaveClk)
            self.dut.slaveValid.value = 1
            self.dut.slaveData.value = words[index]
            await self.settle()
            ready = int(self.dut.slaveReady.value) == 1
            await RisingEdge(self.dut.slaveClk)
            if ready:
                index += 1

        await FallingEdge(self.dut.slaveClk)
        self.dut.slaveValid.value = 0

    async def consume(self, expected_count: int, *, master_ready: int = 1, max_cycles: int = 256) -> list[int]:
        observed: list[int] = []
        for _ in range(max_cycles):
            # Hold masterReady stable across the next masterClk edge and sample
            # any accepted output word immediately afterward.
            await FallingEdge(self.dut.masterClk)
            self.dut.masterReady.value = master_ready
            await RisingEdge(self.dut.masterClk)
            await self.settle()

            if int(self.dut.masterValid.value) == 1 and master_ready == 1:
                observed.append(int(self.dut.masterData.value))
                if len(observed) == expected_count:
                    return observed

        assert False, "Timed out waiting for AsyncGearbox outputs"
        return observed

    async def wait_for_master_valid(self, max_cycles: int = 128) -> int:
        for _ in range(max_cycles):
            await RisingEdge(self.dut.masterClk)
            await self.settle()
            if int(self.dut.masterValid.value) == 1:
                return int(self.dut.masterData.value)
        assert False, "Timed out waiting for AsyncGearbox masterValid"
        return 0


@cocotb.test()
async def async_streaming_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Stream enough input words to generate several outputs and compare the
    # observed read-side words against the same bit-level model used by the
    # single-clock Gearbox regression.
    words = [index & ((1 << tb.slave_width) - 1) for index in [1, 2, 3, 4, 5, 6]]
    expected = _expected_outputs(
        words,
        slave_width=tb.slave_width,
        master_width=tb.master_width,
        slave_reverse=tb.slave_reverse,
        master_reverse=tb.master_reverse,
    )

    producer = cocotb.start_soon(tb.produce(words))
    observed = await tb.consume(len(expected))
    await producer

    assert observed == expected


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Generate just enough source words to build one output word, then hold the
    # master side stalled so reset is asserted while a word is pending.
    words_needed = ceil(tb.master_width / tb.slave_width)
    producer = cocotb.start_soon(tb.produce(list(range(words_needed))))
    await tb.wait_for_master_valid()
    tb.dut.masterReady.value = 0
    await producer

    await FallingEdge(dut.masterClk)
    await Timer(1, unit="ns")
    dut.slaveRst.value = tb.reset_active_value()
    dut.masterRst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.masterValid.value) == 0
    else:
        await RisingEdge(dut.masterClk)
        await tb.settle()
        assert int(dut.masterValid.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "slave_faster_upconvert",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SLAVE_WIDTH_G="4",
        MASTER_WIDTH_G="8",
        SLAVE_REVERSE="false",
        MASTER_REVERSE="false",
        SLAVE_CLK_PERIOD_NS="5",
        MASTER_CLK_PERIOD_NS="11",
    ),
    parameter_case(
        "master_faster_downconvert",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        SLAVE_WIDTH_G="8",
        MASTER_WIDTH_G="4",
        SLAVE_REVERSE="false",
        MASTER_REVERSE="false",
        SLAVE_CLK_PERIOD_NS="11",
        MASTER_CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AsyncGearbox(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.asyncgearbox",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
