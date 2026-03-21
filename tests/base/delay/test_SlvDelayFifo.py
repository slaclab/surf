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
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = 1
        dut.delay.value = 0
        dut.inputData.value = 0
        dut.inputValid.value = 0

        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()

    async def reset(self) -> None:
        self.dut.rst.value = 1
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(3)
        self.dut.rst.value = 0
        await self.cycle(4)

    async def load_delay(self, value: int) -> None:
        # Program the delay one cycle ahead of the write pulse so the inserted
        # FIFO metadata already reflects the intended timestamp.
        self.dut.delay.value = value
        await self.cycle(1)

    async def write_word(self, value: int) -> None:
        self.dut.inputData.value = value
        self.dut.inputValid.value = 1
        await self.cycle(1)
        self.dut.inputValid.value = 0

    async def wait_for_output(self) -> int:
        await with_timeout(self._wait_valid(), 10, "us")
        value = int(self.dut.outputData.value)
        await self.cycle(1)
        return value

    async def _wait_valid(self) -> None:
        while int(self.dut.outputValid.value) == 0:
            await RisingEdge(self.dut.clk)


@cocotb.test()
async def short_delay_request_returns_data_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Even when software asks for a very short delay, the FIFO-based path
    # should still deliver one clean delayed output word.
    await tb.load_delay(1)
    await tb.write_word(0xAA)

    assert await tb.wait_for_output() == 0xAA


@cocotb.test()
async def timestamped_outputs_preserve_programmed_order_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Program two writes with different target delays and confirm the earlier
    # scheduled item emerges first from the shared output FIFO.
    await tb.load_delay(4)
    await tb.write_word(0x11)

    await tb.load_delay(6)
    await tb.write_word(0x22)

    assert await tb.wait_for_output() == 0x11
    assert await tb.wait_for_output() == 0x22


PARAMETER_SWEEP = [
    parameter_case(
        "block_sync_reset",
        RST_ASYNC_G="false",
        DATA_WIDTH_G="8",
        DELAY_BITS_G="6",
        FIFO_ADDR_WIDTH_G="4",
        FIFO_MEMORY_TYPE_G="block",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "distributed_async_reset",
        RST_ASYNC_G="true",
        DATA_WIDTH_G="8",
        DELAY_BITS_G="6",
        FIFO_ADDR_WIDTH_G="4",
        FIFO_MEMORY_TYPE_G="distributed",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SlvDelayFifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.slvdelayfifo",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
