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

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut, *, wr_clk_period_ns: float, rd_clk_period_ns: float):
        self.dut = dut

        dut.wr_en.value = 0
        dut.rd_en.value = 0
        dut.din.value = 0
        dut.rst.value = 1

        cocotb.start_soon(Clock(dut.wr_clk, wr_clk_period_ns, unit="ns").start())
        cocotb.start_soon(Clock(dut.rd_clk, rd_clk_period_ns, unit="ns").start())

    async def reset(self) -> None:
        self.dut.rst.value = 1
        for _ in range(6):
            await RisingEdge(self.dut.wr_clk)
            await RisingEdge(self.dut.rd_clk)
        self.dut.rst.value = 0
        for _ in range(6):
            await RisingEdge(self.dut.wr_clk)
            await RisingEdge(self.dut.rd_clk)

    async def write_word(self, value: int) -> None:
        await with_timeout(self._wait_not_full(), 5, "us")
        self.dut.din.value = value
        self.dut.wr_en.value = 1
        await RisingEdge(self.dut.wr_clk)
        self.dut.wr_en.value = 0
        await RisingEdge(self.dut.wr_clk)
        await Timer(2, unit="ns")

    async def read_word(self) -> int:
        await with_timeout(self._wait_valid(), 5, "us")
        value = int(self.dut.dout.value)
        self.dut.rd_en.value = 1
        await RisingEdge(self.dut.rd_clk)
        self.dut.rd_en.value = 0
        await RisingEdge(self.dut.rd_clk)
        return value

    async def _wait_not_full(self) -> None:
        while int(self.dut.not_full.value) == 0:
            await RisingEdge(self.dut.wr_clk)

    async def _wait_full(self) -> None:
        while int(self.dut.full.value) == 0:
            await RisingEdge(self.dut.wr_clk)

    async def _wait_empty(self) -> None:
        while int(self.dut.empty.value) == 0:
            await RisingEdge(self.dut.rd_clk)

    async def _wait_valid(self) -> None:
        while int(self.dut.valid.value) == 0:
            await RisingEdge(self.dut.rd_clk)


@cocotb.test()
async def basic_ordering_test(dut):
    tb = TB(
        dut,
        wr_clk_period_ns=float(os.environ["WR_CLK_PERIOD_NS"]),
        rd_clk_period_ns=float(os.environ["RD_CLK_PERIOD_NS"]),
    )
    await tb.reset()

    expected = list(range(10))
    for value in expected:
        await tb.write_word(value)

    received = []
    for _ in expected:
        received.append(await tb.read_word())

    assert received == expected


@cocotb.test()
async def full_empty_flag_test(dut):
    tb = TB(
        dut,
        wr_clk_period_ns=float(os.environ["WR_CLK_PERIOD_NS"]),
        rd_clk_period_ns=float(os.environ["RD_CLK_PERIOD_NS"]),
    )
    await tb.reset()

    depth = 2 ** int(os.environ["ADDR_WIDTH_G"])
    for value in range(depth):
        await tb.write_word(value)

    await with_timeout(tb._wait_full(), 5, "us")

    for expected in range(depth):
        assert await tb.read_word() == expected

    await with_timeout(tb._wait_empty(), 5, "us")


PARAMETER_SWEEP = [
    {
        "DATA_WIDTH_G": "16",
        "ADDR_WIDTH_G": "4",
        "FWFT_EN_G": "true",
        "MEMORY_TYPE_G": "block",
        "WR_CLK_PERIOD_NS": "5",
        "RD_CLK_PERIOD_NS": "13",
    },
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_FifoAsync(parameters):
    hdl_parameters = {
        key: value
        for key, value in parameters.items()
        if key.endswith("_G")
    }

    runtime_env = {
        key: value
        for key, value in parameters.items()
        if not key.endswith("_G")
    }

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.fifoasync",
        parameters=hdl_parameters,
        extra_env={**hdl_parameters, **runtime_env},
    )
