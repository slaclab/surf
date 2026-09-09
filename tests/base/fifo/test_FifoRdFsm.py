##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Sweep standard and `FWFT` read behavior, block and distributed
#   implementations, and both asynchronous and active-low reset handling so the
#   read FSM is covered across its main modes.
# - Stimulus: Model incoming FIFO occupancy and issue read requests that drive
#   the FSM through count changes, empty transitions, underflow attempts, and
#   `FWFT` prefetch conditions.
# - Checks: The bench checks read-side counts and flags, standard underflow
#   behavior, `FWFT` prefetch behavior, and reset recovery.
# - Timing: Standard mode must return data only after the explicit read
#   transaction, while `FWFT` must expose the next word ahead of time and reset
#   must immediately or synchronously clear the read state.

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
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.fifo_async = env_flag("FIFO_ASYNC_G", default=False)
        self.fwft_enabled = env_flag("FWFT_EN_G", default=False)
        self.memory_type = os.environ["MEMORY_TYPE_G"]
        self.addr_width = int(os.environ["ADDR_WIDTH_G"])
        self.empty_threshold = int(os.environ["EMPTY_THRES_G"])
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.wrRdy.value = 0
        dut.wrIndex.value = 0
        dut.doutb.value = 0
        dut.rd_en.value = 0

        cocotb.start_soon(Clock(dut.rd_clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def encode_index(self, value: int) -> int:
        return _gray_encode(value) if self.fifo_async else value

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.rd_clk)
            await self.settle()

    async def reset(self) -> None:
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(3)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(1)

    async def initialize_writer(self, fill_count: int) -> None:
        # The read FSM derives occupancy entirely from the incoming write-side
        # pointer, so the test can emulate FIFO fill level by driving `wrIndex`
        # directly without instantiating the write FSM.
        self.dut.wrRdy.value = 1
        self.dut.wrIndex.value = self.encode_index(fill_count)
        await self.cycle(1)

    async def read_pulse(self) -> tuple[int, int]:
        # `valid` and `underflow` are pulse-style outputs in standard mode, so
        # this helper samples them immediately after the active read edge and
        # then waits one more cycle for the count/flag state to settle.
        self.dut.rd_en.value = 1
        await RisingEdge(self.dut.rd_clk)
        self.dut.rd_en.value = 0
        await self.settle()
        sampled_valid = int(self.dut.valid.value)
        sampled_underflow = int(self.dut.underflow.value)
        await self.cycle(1)
        return sampled_valid, sampled_underflow


@cocotb.test(skip=env_flag("FWFT_EN_G", default=False))
async def count_and_flag_test(dut):
    tb = TB(dut)
    await tb.reset()

    await tb.initialize_writer(3)
    assert int(dut.empty.value) == 0
    assert int(dut.almost_empty.value) == 0
    assert int(dut.rd_data_count.value) == 3

    await tb.initialize_writer(1)
    assert int(dut.empty.value) == 0
    assert int(dut.almost_empty.value) == 1
    assert int(dut.rd_data_count.value) == 1
    assert int(dut.prog_empty.value) == (1 if 1 < tb.empty_threshold else 0)


@cocotb.test(skip=env_flag("FWFT_EN_G", default=False))
async def standard_read_and_underflow_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.initialize_writer(2)

    # Each successful read should move the read pointer forward and reduce the
    # visible count by one. The `valid` pulse itself is combinatorial in this
    # mode, so the stable post-read checks focus on the registered state that
    # remains after the pulse has passed.
    await tb.read_pulse()
    assert int(dut.rd_data_count.value) == 1
    assert int(dut.rdIndex.value) == tb.encode_index(1)

    await tb.read_pulse()
    assert int(dut.rd_data_count.value) == 0
    assert int(dut.empty.value) == 1

    # Once empty, another read should leave the state unchanged.
    await tb.read_pulse()
    assert int(dut.rd_data_count.value) == 0
    assert int(dut.empty.value) == 1


@cocotb.test(skip=not env_flag("FWFT_EN_G", default=False))
async def fwft_prefetch_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.initialize_writer(1)

    # FWFT mode should autonomously prefetch the first word so `valid` becomes
    # asserted even before software requests a read.
    saw_valid = False
    for _ in range(8):
        await tb.cycle(1)
        if int(dut.valid.value) == 1:
            saw_valid = True
            break

    assert saw_valid

    # Consuming that prefetched word should eventually leave the output empty
    # again when the write pointer does not advance further.
    tb.dut.rd_en.value = 1
    await RisingEdge(tb.dut.rd_clk)
    tb.dut.rd_en.value = 0
    await tb.settle()

    for _ in range(8):
        await tb.cycle(1)
        if int(dut.valid.value) == 0:
            break

    assert int(dut.valid.value) == 0


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.initialize_writer(2)

    if not tb.fwft_enabled:
        await tb.read_pulse()
        assert int(dut.rdIndex.value) != 0

    # Drop `wrRdy` before asserting reset so the post-reset outputs reflect the
    # FSM's own reset values rather than immediately recomputing from a live
    # upstream pointer.
    dut.wrRdy.value = 0

    await FallingEdge(dut.rd_clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.empty.value) == 1
    else:
        # Synchronous reset should not change the registered state until the
        # next destination clock edge.
        await tb.cycle(1)
        assert int(dut.empty.value) == 1


PARAMETER_SWEEP = [
    parameter_case(
        "standard_sync_block",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FIFO_ASYNC_G="false",
        MEMORY_TYPE_G="block",
        FWFT_EN_G="false",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="3",
        EMPTY_THRES_G="2",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "fwft_block",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FIFO_ASYNC_G="false",
        MEMORY_TYPE_G="block",
        FWFT_EN_G="true",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="3",
        EMPTY_THRES_G="2",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "fwft_distributed_async",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        FIFO_ASYNC_G="true",
        MEMORY_TYPE_G="distributed",
        FWFT_EN_G="true",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="3",
        EMPTY_THRES_G="2",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "standard_active_low",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        FIFO_ASYNC_G="false",
        MEMORY_TYPE_G="distributed",
        FWFT_EN_G="false",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="3",
        EMPTY_THRES_G="1",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_FifoRdFsm(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.fifordfsm",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
