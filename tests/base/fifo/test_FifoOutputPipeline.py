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
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import (
    env_flag,
    env_sl,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        # This helper models the "upstream FIFO" side of the pipeline and lets
        # the tests observe the "downstream consumer" side.
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.pipe_stages = int(os.environ["PIPE_STAGES_G"])
        # `source_words` is a Python queue of words we want the source model to
        # feed into the DUT whenever the DUT asserts `sRdEn`.
        self.source_words: list[int] = []

        # Initialize DUT inputs before the clock starts.
        dut.sData.value = 0
        dut.sValid.value = 0
        dut.mRdEn.value = 0
        dut.rst.value = self.reset_active_value()

        # Start the main DUT clock. For pipelined cases, also start the little
        # Python coroutine that emulates the upstream FWFT source.
        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())
        if self.pipe_stages > 0:
            cocotb.start_soon(self._drive_source())

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
        # Reset clears both the HDL pipeline state and the Python-side source
        # queue so every test starts from a clean slate.
        self.dut.rst.value = self.reset_active_value()
        self.source_words.clear()

        if self.async_reset:
            await Timer(2, unit="ns")
            await self.cycle(3)
        else:
            await self.cycle(3)

        # Release reset and give the pipeline a couple cycles to settle.
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(2)

    def feed_words(self, words: list[int]) -> None:
        # Tests preload data here; `_drive_source()` will hand the words to the
        # DUT one at a time when the DUT asks for them.
        self.source_words.extend(words)

    async def _drive_source(self) -> None:
        # This coroutine emulates the upstream FIFO/source interface. It keeps
        # `sValid/sData` aligned to the DUT's `sRdEn` requests.
        next_valid = 0
        next_data = 0

        while True:
            # Drive whatever value was prepared on the previous cycle.
            self.dut.sValid.value = next_valid
            self.dut.sData.value = next_data

            await RisingEdge(self.dut.clk)
            await self.settle()

            if int(self.dut.rst.value) == self.reset_active_value():
                # While reset is active, hold the source idle.
                next_valid = 0
                next_data = 0
                continue

            if int(self.dut.sRdEn.value) == 1 and self.source_words:
                # The DUT requested another word, so present the next queued
                # item on the following cycle.
                next_valid = 1
                next_data = self.source_words.pop(0)
            else:
                # No request or no data means the source stays idle.
                next_valid = 0
                next_data = 0

    async def collect_words(self, expected_count: int, *, timeout_cycles: int = 80) -> list[int]:
        # Keep clocking until the downstream interface has accepted the desired
        # number of words, or fail with a timeout so the test does not hang.
        received = []
        for _ in range(timeout_cycles):
            await self.cycle(1)
            if int(self.dut.mValid.value) == 1 and int(self.dut.mRdEn.value) == 1:
                # A word only counts as consumed when both VALID and ready/read
                # are asserted together on the same cycle.
                received.append(int(self.dut.mData.value))
                if len(received) == expected_count:
                    return received

        raise AssertionError(f"Timed out collecting {expected_count} output words")


@cocotb.test()
async def zero_latency_passthrough_test(dut):
    tb = TB(dut)
    if tb.pipe_stages != 0:
        return

    # With zero stages, this block is combinational: data and handshaking should
    # pass straight through without waiting for a clock edge.
    dut.rst.value = tb.reset_inactive_value()
    for value in (0x11, 0x22, 0x33):
        dut.sData.value = value
        dut.sValid.value = 1
        dut.mRdEn.value = 1
        await tb.settle()
        assert int(dut.mData.value) == value
        assert int(dut.mValid.value) == 1
        assert int(dut.sRdEn.value) == 1


@cocotb.test()
async def ordering_test(dut):
    tb = TB(dut)
    if tb.pipe_stages == 0:
        return

    await tb.reset()

    # Preload a short stream and then let the downstream consumer read
    # continuously. The collected order should match exactly.
    expected = [0x10, 0x11, 0x12, 0x13, 0x14]
    tb.feed_words(expected.copy())
    dut.mRdEn.value = 1

    assert await tb.collect_words(len(expected)) == expected


@cocotb.test()
async def backpressure_test(dut):
    tb = TB(dut)
    if tb.pipe_stages < 2:
        return

    await tb.reset()

    # This test toggles downstream readiness to make sure the DUT can hold data
    # steady while the consumer is stalled.
    expected = [0x20, 0x21, 0x22, 0x23, 0x24]
    tb.feed_words(expected.copy())
    dut.mRdEn.value = 1

    received = []
    stall_cycles = 0
    held_data = None

    for _ in range(120):
        if stall_cycles > 0:
            dut.mRdEn.value = 0
        else:
            dut.mRdEn.value = 1

        await tb.cycle(1)

        if int(dut.mValid.value) == 0:
            continue

        current_data = int(dut.mData.value)
        if int(dut.mRdEn.value) == 0:
            # During backpressure, the presented word must stay constant until
            # the consumer resumes.
            if held_data is None:
                held_data = current_data
            else:
                assert current_data == held_data
            stall_cycles -= 1
            continue

        # Once the consumer is ready again, the held word can be accepted.
        received.append(current_data)
        held_data = None

        if len(received) == 2:
            stall_cycles = 3
        if len(received) == len(expected):
            break

    assert received == expected


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    if tb.pipe_stages == 0:
        return

    await tb.reset()

    # Fill the pipeline with a few words and consume one so we know the DUT has
    # real state to clear.
    tb.feed_words([0x31, 0x32, 0x33])
    dut.mRdEn.value = 1
    received = await tb.collect_words(1)
    assert received == [0x31]

    # Clear any not-yet-presented Python-side source data so only the DUT's own
    # internal pipeline state is being tested across reset.
    tb.source_words.clear()
    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        # Async reset should drop `mValid` right away.
        assert int(dut.mValid.value) == 0
    else:
        # Sync reset should wait until the next clock edge.
        await tb.cycle(1)
        assert int(dut.mValid.value) == 0

    # After reset releases, the source model can feed a fresh stream normally.
    dut.rst.value = tb.reset_inactive_value()
    await tb.cycle(2)

    tb.feed_words([0x41, 0x42])
    dut.mRdEn.value = 1
    assert await tb.collect_words(2) == [0x41, 0x42]


PARAMETER_SWEEP = [
    parameter_case(
        "zero_latency",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        DATA_WIDTH_G="16",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "stage1_ordering",
        PIPE_STAGES_G="1",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        DATA_WIDTH_G="16",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "stage2_backpressure",
        PIPE_STAGES_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        DATA_WIDTH_G="16",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_reset_stage2",
        PIPE_STAGES_G="2",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        DATA_WIDTH_G="16",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_reset_stage1",
        PIPE_STAGES_G="1",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        DATA_WIDTH_G="16",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_FifoOutputPipeline(parameters):
    # One simulation per parameter set keeps the source model and expectations
    # small and easy to follow.
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.fifooutputpipeline",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
