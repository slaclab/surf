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


def _gray_encode(value: int) -> int:
    return value ^ (value >> 1)


class TB:
    def __init__(self, dut):
        self.dut = dut
        # This DUT is the write-side state machine inside the FIFO, so the test
        # emulates the write clock domain plus the read-side position feedback.
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.fifo_async = env_flag("FIFO_ASYNC_G", default=False)
        self.addr_width = int(os.environ["ADDR_WIDTH_G"])
        self.full_threshold = int(os.environ["FULL_THRES_G"])
        # A FIFO with N address bits can store 2^N - 1 words in this design.
        self.capacity = (1 << self.addr_width) - 1

        # Drive all DUT inputs to a known idle state before time starts.
        dut.rdRdy.value = 0
        dut.rdIndex.value = 0
        dut.wr_en.value = 0
        dut.din.value = 0
        dut.rst.value = self.reset_active_value()

        # Start the write-domain clock.
        cocotb.start_soon(Clock(dut.wr_clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def encode_index(self, value: int) -> int:
        # Async FIFOs exchange gray-coded pointers across clock domains, while
        # sync FIFOs just use the binary count directly.
        return _gray_encode(value) if self.fifo_async else value

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.wr_clk)
            await self.settle()

    async def reset(self) -> None:
        # Hold reset active for a few cycles so the FSM returns to its known
        # startup state.
        self.dut.rst.value = self.reset_active_value()

        if self.async_reset:
            await Timer(2, unit="ns")
            await self.cycle(3)
        else:
            await self.cycle(3)

        # Release reset and give the FSM one more cycle to recompute outputs.
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(1)

    async def initialize_reader(self, rd_addr: int = 0) -> None:
        # The write FSM keeps itself blocked until the read side reports ready.
        # This helper releases that dependency in a controlled way.
        self.dut.rdIndex.value = self.encode_index(rd_addr)
        self.dut.rdRdy.value = 1
        await self.cycle(2)

    async def write_word(self, value: int) -> tuple[int, int]:
        # Drive one write pulse and then sample the acknowledged/overflow result
        # after the edge, once combinational outputs have settled.
        self.dut.din.value = value
        self.dut.wr_en.value = 1
        await RisingEdge(self.dut.wr_clk)
        self.dut.wr_en.value = 0
        await self.settle()
        return int(self.dut.wr_ack.value), int(self.dut.overflow.value)

    async def set_reader_addr(self, rd_addr: int) -> None:
        # Move the read pointer forward to emulate the downstream side freeing
        # FIFO space.
        self.dut.rdIndex.value = self.encode_index(rd_addr)
        await self.cycle(1)


@cocotb.test()
async def readiness_and_count_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.initialize_reader()

    # Once the read side is ready, the write side should advertise space and a
    # zero count.
    assert int(dut.full.value) == 0
    assert int(dut.not_full.value) == 1
    assert int(dut.wr_data_count.value) == 0

    # Each accepted write should increment the visible count and index.
    for index, value in enumerate((0x10, 0x11, 0x12), start=1):
        wr_ack, overflow = await tb.write_word(value)
        assert wr_ack == 1
        assert overflow == 0
        assert int(dut.wr_data_count.value) == index
        assert int(dut.wrIndex.value) == tb.encode_index(index)


@cocotb.test()
async def full_and_overflow_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.initialize_reader()

    # Fill the FIFO to its usable capacity.
    for value in range(tb.capacity):
        wr_ack, overflow = await tb.write_word(value)
        assert wr_ack == 1
        assert overflow == 0

    # At capacity, the FSM should stop accepting writes and flag overflow on the
    # next attempted write.
    assert int(dut.full.value) == 1
    assert int(dut.not_full.value) == 0
    assert int(dut.wr_data_count.value) == tb.capacity

    wr_ack, overflow = await tb.write_word(0xFF)
    assert wr_ack == 0
    assert overflow == 1
    assert int(dut.wr_data_count.value) == tb.capacity


@cocotb.test()
async def threshold_and_release_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.initialize_reader()

    # Keep writing until the programmable-full flag asserts.
    while int(dut.prog_full.value) == 0:
        next_value = int(dut.wr_data_count.value) + 0x20
        wr_ack, overflow = await tb.write_word(next_value)
        assert wr_ack == 1
        assert overflow == 0

    current_count = int(dut.wr_data_count.value)
    assert current_count >= tb.full_threshold
    # Advance the read pointer to simulate words being consumed on the far side.
    await tb.set_reader_addr(2)
    assert int(dut.wr_data_count.value) == current_count - 2
    assert int(dut.full.value) == 0


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.initialize_reader()

    # Seed a non-zero count so reset has visible work to do.
    await tb.write_word(0x55)
    await tb.write_word(0x56)
    assert int(dut.wr_data_count.value) == 2

    # Assert reset away from the active edge so sync and async reset behavior
    # can be distinguished.
    await FallingEdge(dut.wr_clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        # Async reset should immediately restore the FSM's reset outputs.
        assert int(dut.full.value) == 1
        assert int(dut.not_full.value) == 0
    else:
        # Sync reset should not change registered outputs until the next clock.
        assert int(dut.wr_data_count.value) == 2
        await tb.cycle(1)
        assert int(dut.full.value) == 1
        assert int(dut.not_full.value) == 0

    # Releasing reset and reinitializing the read side should return the FSM to
    # an empty, writable state.
    dut.rst.value = tb.reset_inactive_value()
    await tb.initialize_reader()
    assert int(dut.full.value) == 0
    assert int(dut.not_full.value) == 1
    assert int(dut.wr_data_count.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "sync_baseline",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FIFO_ASYNC_G="false",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="3",
        FULL_THRES_G="1",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "sync_threshold_midpoint",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FIFO_ASYNC_G="false",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FULL_THRES_G="6",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_gray_index",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        FIFO_ASYNC_G="true",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="3",
        FULL_THRES_G="2",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_reset",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        FIFO_ASYNC_G="false",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="3",
        FULL_THRES_G="1",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_FifoWrFsm(parameters):
    # Run each interesting generic configuration in its own simulator process.
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.fifowrfsm",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
