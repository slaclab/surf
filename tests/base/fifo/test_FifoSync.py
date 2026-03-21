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


def _env_flag(name: str, *, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default

    normalized = raw.strip().strip("'").lower()
    if normalized in {"1", "true"}:
        return True
    if normalized in {"0", "false"}:
        return False
    raise ValueError(f"Unsupported boolean environment value for {name}: {raw}")


class TB:
    def __init__(self, dut, *, clk_period_ns: float):
        self.dut = dut
        self.reset_is_active_high = _env_flag("RST_ACTIVE_HIGH", default=True)
        self.fwft_enabled = _env_flag("FWFT_EN_G", default=False)

        dut.wr_en.value = 0
        dut.rd_en.value = 0
        dut.din.value = 0
        dut.rst.value = self._reset_active_value()

        cocotb.start_soon(Clock(dut.clk, clk_period_ns, unit="ns").start())

    def _reset_active_value(self) -> int:
        return 1 if self.reset_is_active_high else 0

    def _reset_inactive_value(self) -> int:
        return 0 if self.reset_is_active_high else 1

    async def reset(self) -> None:
        # Use the same reset strategy as FifoAsync, but only one clock domain
        # needs to settle here.
        self.dut.rst.value = self._reset_active_value()

        if _env_flag("RST_ASYNC_G", default=False):
            await Timer(3, unit="ns")
            for _ in range(6):
                await RisingEdge(self.dut.clk)
        else:
            for _ in range(6):
                await RisingEdge(self.dut.clk)

        self.dut.rst.value = self._reset_inactive_value()
        for _ in range(6):
            await RisingEdge(self.dut.clk)

    async def write_word(self, value: int) -> None:
        await with_timeout(self._wait_not_full(), 5, "us")
        self.dut.din.value = value
        self.dut.wr_en.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.wr_en.value = 0
        await RisingEdge(self.dut.clk)
        await Timer(2, unit="ns")

    async def read_word(self) -> int:
        if self.fwft_enabled:
            await with_timeout(self._wait_valid(), 5, "us")
            value = int(self.dut.dout.value)
            self.dut.rd_en.value = 1
            await RisingEdge(self.dut.clk)
            self.dut.rd_en.value = 0
            await RisingEdge(self.dut.clk)
            return value

        await self._wait_not_empty()
        self.dut.rd_en.value = 1
        await with_timeout(self._wait_valid(), 5, "us")
        await Timer(2, unit="ns")
        value = int(self.dut.dout.value)
        self.dut.rd_en.value = 0
        await RisingEdge(self.dut.clk)
        return value

    async def _wait_not_full(self) -> None:
        while int(self.dut.not_full.value) == 0:
            await RisingEdge(self.dut.clk)

    async def _wait_full(self) -> None:
        while int(self.dut.full.value) == 0:
            await RisingEdge(self.dut.clk)

    async def _wait_empty(self) -> None:
        while int(self.dut.empty.value) == 0:
            await RisingEdge(self.dut.clk)

    async def _wait_not_empty(self) -> None:
        while int(self.dut.empty.value) == 1:
            await RisingEdge(self.dut.clk)

    async def _wait_valid(self) -> None:
        while int(self.dut.valid.value) == 0:
            await RisingEdge(self.dut.clk)

    async def _wait_prog_full(self, expected: int) -> None:
        while int(self.dut.prog_full.value) != expected:
            await RisingEdge(self.dut.clk)

    async def _wait_prog_empty(self, expected: int) -> None:
        while int(self.dut.prog_empty.value) != expected:
            await RisingEdge(self.dut.clk)


@cocotb.test()
async def basic_ordering_test(dut):
    tb = TB(dut, clk_period_ns=float(os.environ["CLK_PERIOD_NS"]))
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
    tb = TB(dut, clk_period_ns=float(os.environ["CLK_PERIOD_NS"]))
    await tb.reset()

    if not _env_flag("CHECK_FULL_EMPTY", default=True):
        return

    # FifoSync uses the same user-visible capacity convention as FifoAsync:
    # standard mode exposes N-1 entries, FWFT mode exposes N entries.
    entry_capacity = (2 ** int(os.environ["ADDR_WIDTH_G"])) - (0 if tb.fwft_enabled else 1)
    for value in range(entry_capacity):
        await tb.write_word(value)

    await with_timeout(tb._wait_full(), 5, "us")

    for expected in range(entry_capacity):
        assert await tb.read_word() == expected

    await with_timeout(tb._wait_empty(), 5, "us")


@cocotb.test()
async def threshold_flag_test(dut):
    if not _env_flag("CHECK_THRESHOLD_FLAGS", default=False):
        return

    tb = TB(dut, clk_period_ns=float(os.environ["CLK_PERIOD_NS"]))
    await tb.reset()

    entry_capacity = (2 ** int(os.environ["ADDR_WIDTH_G"])) - (0 if tb.fwft_enabled else 1)
    full_threshold = int(os.environ.get("FULL_THRES_G", "1"))
    empty_threshold = int(os.environ.get("EMPTY_THRES_G", "1"))
    trigger_count = 0

    # The exact cycle where prog_full asserts depends on the FIFO bookkeeping
    # path, so drive until the flag trips instead of assuming one fixed count.
    while trigger_count < entry_capacity and int(dut.prog_full.value) == 0:
        await tb.write_word(trigger_count)
        trigger_count += 1

    await with_timeout(tb._wait_prog_full(1), 5, "us")
    assert trigger_count >= full_threshold

    for _ in range(trigger_count):
        await tb.read_word()

    refill_values = []
    if empty_threshold == 0:
        await with_timeout(tb._wait_prog_empty(1), 5, "us")
    else:
        while len(refill_values) < entry_capacity and int(dut.prog_empty.value) == 1:
            value = 0x100 + len(refill_values)
            await tb.write_word(value)
            refill_values.append(value)
        await with_timeout(tb._wait_prog_empty(0), 5, "us")
        assert len(refill_values) >= empty_threshold
        for expected in refill_values:
            assert await tb.read_word() == expected
        await with_timeout(tb._wait_prog_empty(1), 5, "us")


def _case(case_id: str, **parameters):
    return pytest.param(parameters, id=case_id)


PARAMETER_SWEEP = [
    # This matrix tracks the same behavior-changing axes as FifoAsync, minus
    # the async-only synchronizer depth controls that do not exist here.
    _case(
        "block_fwft_baseline",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="1",
    ),
    _case(
        "distributed_fwft",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="distributed",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="1",
    ),
    _case(
        "block_standard_fifo",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="false",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="1",
    ),
    _case(
        "distributed_standard_fifo",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="false",
        MEMORY_TYPE_G="distributed",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="1",
    ),
    _case(
        "block_fwft_pipeline2",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="0",
        CHECK_THRESHOLD_FLAGS="0",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="1",
    ),
    _case(
        "fwft_async_reset",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="1",
    ),
    _case(
        "fwft_active_low_reset",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="0",
    ),
    _case(
        "wider_deeper_fifo",
        DATA_WIDTH_G="32",
        ADDR_WIDTH_G="5",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="1",
    ),
    _case(
        "narrow_distributed_deeper_fifo",
        DATA_WIDTH_G="8",
        ADDR_WIDTH_G="5",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="distributed",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="1",
    ),
    _case(
        "fwft_threshold_midpoint",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FULL_THRES_G="8",
        EMPTY_THRES_G="3",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="1",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="1",
    ),
    _case(
        "standard_threshold_near_full",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="false",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        FULL_THRES_G="14",
        EMPTY_THRES_G="2",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="1",
        CLK_PERIOD_NS="5",
        RST_ACTIVE_HIGH="1",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_FifoSync(parameters):
    # Keep simulator generics separate from runtime-only knobs such as the
    # cocotb clock period that does not exist on the HDL entity.
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
        toplevel="surf.fifosync",
        parameters=hdl_parameters,
        extra_env={**hdl_parameters, **runtime_env},
    )
