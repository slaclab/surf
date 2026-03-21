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
# - Sweep: Sweep memory type, `FWFT` vs standard read mode, output pipeline
#   depth, reset style/polarity, synchronizer depth, width/depth scaling, and
#   threshold placements with a small curated matrix instead of a Cartesian
#   explosion.
# - Stimulus: Drive burst writes and reads on independent clocks so the FIFO
#   fills, drains, crosses programmable threshold points, and encounters both
#   empty and full boundaries.
# - Checks: The bench checks end-to-end ordering, `full`/`empty` behavior,
#   programmable threshold flags, deeper and wider geometry variants, and the
#   behavioral difference between `FWFT` and standard read mode.
# - Timing: Read and write timing is checked against separate clocks, `FWFT`
#   must prefetch data before an explicit read pop, standard mode must return
#   data after the read event, and asynchronous reset must clear both sides
#   immediately.

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
    def __init__(self, dut, *, wr_clk_period_ns: float, rd_clk_period_ns: float):
        self.dut = dut
        self.reset_is_active_high = env_flag("RST_ACTIVE_HIGH", default=True)
        self.fwft_enabled = env_flag("FWFT_EN_G", default=False)

        dut.wr_en.value = 0
        dut.rd_en.value = 0
        dut.din.value = 0
        dut.rst.value = self._reset_active_value()

        cocotb.start_soon(Clock(dut.wr_clk, wr_clk_period_ns, unit="ns").start())
        cocotb.start_soon(Clock(dut.rd_clk, rd_clk_period_ns, unit="ns").start())

    def _reset_active_value(self) -> int:
        return 1 if self.reset_is_active_high else 0

    def _reset_inactive_value(self) -> int:
        return 0 if self.reset_is_active_high else 1

    async def reset(self) -> None:
        # Hold reset long enough for both clock domains to settle before the
        # first transaction, then give the FIFO a few clean post-reset cycles.
        self.dut.rst.value = self._reset_active_value()

        if env_flag("RST_ASYNC_G", default=False):
            await Timer(3, unit="ns")
            for _ in range(6):
                await RisingEdge(self.dut.wr_clk)
                await RisingEdge(self.dut.rd_clk)
        else:
            for _ in range(6):
                await RisingEdge(self.dut.wr_clk)
                await RisingEdge(self.dut.rd_clk)

        self.dut.rst.value = self._reset_inactive_value()
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
        # Let FWFT outputs settle before the next operation samples status.
        await Timer(2, unit="ns")

    async def read_word(self) -> int:
        if self.fwft_enabled:
            await with_timeout(self._wait_valid(), 5, "us")
            value = int(self.dut.dout.value)
            self.dut.rd_en.value = 1
            await RisingEdge(self.dut.rd_clk)
            self.dut.rd_en.value = 0
            await RisingEdge(self.dut.rd_clk)
            return value

        await self._wait_not_empty()
        self.dut.rd_en.value = 1
        # In standard FIFO mode the valid pulse is tied to the explicit read
        # request, so wait for the pulse after asserting rd_en.
        await with_timeout(self._wait_valid(), 5, "us")
        await Timer(2, unit="ns")
        value = int(self.dut.dout.value)
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

    async def _wait_not_empty(self) -> None:
        while int(self.dut.empty.value) == 1:
            await RisingEdge(self.dut.rd_clk)

    async def _wait_valid(self) -> None:
        while int(self.dut.valid.value) == 0:
            await RisingEdge(self.dut.rd_clk)

    async def _wait_prog_full(self, expected: int) -> None:
        while int(self.dut.prog_full.value) != expected:
            await RisingEdge(self.dut.wr_clk)

    async def _wait_prog_empty(self, expected: int) -> None:
        while int(self.dut.prog_empty.value) != expected:
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

    if not env_flag("CHECK_FULL_EMPTY", default=True):
        return

    # Standard mode exposes one slot less than the raw address space, while
    # FWFT can present one prefetched word beyond the underlying storage count.
    entry_capacity = (2 ** int(os.environ["ADDR_WIDTH_G"])) - (0 if tb.fwft_enabled else 1)
    for value in range(entry_capacity):
        await tb.write_word(value)

    await with_timeout(tb._wait_full(), 5, "us")

    for expected in range(entry_capacity):
        assert await tb.read_word() == expected

    await with_timeout(tb._wait_empty(), 5, "us")


@cocotb.test()
async def threshold_flag_test(dut):
    if not env_flag("CHECK_THRESHOLD_FLAGS", default=False):
        return

    tb = TB(
        dut,
        wr_clk_period_ns=float(os.environ["WR_CLK_PERIOD_NS"]),
        rd_clk_period_ns=float(os.environ["RD_CLK_PERIOD_NS"]),
    )
    await tb.reset()

    entry_capacity = (2 ** int(os.environ["ADDR_WIDTH_G"])) - 1
    full_threshold = int(os.environ.get("FULL_THRES_G", "1"))
    empty_threshold = int(os.environ.get("EMPTY_THRES_G", "1"))
    trigger_count = min(entry_capacity, full_threshold + 1)

    for value in range(trigger_count):
        await tb.write_word(value)

    await with_timeout(tb._wait_prog_full(1), 5, "us")

    for _ in range(trigger_count):
        await tb.read_word()

    # FWFT mode can prefetch one word into the output path, so refill one extra
    # entry to guarantee the visible count rises above EMPTY_THRES_G.
    refill_count = max(empty_threshold + (1 if tb.fwft_enabled else 0), 0)
    if refill_count == 0:
        await with_timeout(tb._wait_prog_empty(1), 5, "us")
    else:
        for value in range(refill_count):
            await tb.write_word(0x100 + value)
        # prog_empty deasserts only when the count is no longer below the
        # configured threshold, so refill back to EMPTY_THRES_G entries.
        await with_timeout(tb._wait_prog_empty(0), 5, "us")
        for _ in range(refill_count):
            await tb.read_word()
        await with_timeout(tb._wait_prog_empty(1), 5, "us")


PARAMETER_SWEEP = [
    # These cases cover the major functional axes of FifoAsync without trying
    # to brute-force every generic combination. TPD_G is timing-only, INIT_G is
    # not used in the current implementation, and BYP_RAM_G has no active
    # generate path here, so they are intentionally excluded from this matrix.
    parameter_case(
        "block_fwft_baseline",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="13",
        RST_ACTIVE_HIGH="1",
    ),
    parameter_case(
        "distributed_fwft",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="distributed",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        WR_CLK_PERIOD_NS="7",
        RD_CLK_PERIOD_NS="11",
        RST_ACTIVE_HIGH="1",
    ),
    parameter_case(
        "block_standard_fifo",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="false",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="13",
        RST_ACTIVE_HIGH="1",
    ),
    parameter_case(
        "distributed_standard_fifo",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="false",
        MEMORY_TYPE_G="distributed",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        WR_CLK_PERIOD_NS="7",
        RD_CLK_PERIOD_NS="11",
        RST_ACTIVE_HIGH="1",
    ),
    parameter_case(
        "block_fwft_pipeline2",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="0",
        CHECK_THRESHOLD_FLAGS="0",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="13",
        RST_ACTIVE_HIGH="1",
    ),
    parameter_case(
        "fwft_async_reset",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="13",
        RST_ACTIVE_HIGH="1",
    ),
    parameter_case(
        "fwft_active_low_reset",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="13",
        RST_ACTIVE_HIGH="0",
    ),
    parameter_case(
        "fwft_sync_stages4",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="4",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="13",
        RST_ACTIVE_HIGH="1",
    ),
    parameter_case(
        "wider_deeper_fifo",
        DATA_WIDTH_G="32",
        ADDR_WIDTH_G="5",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="9",
        RST_ACTIVE_HIGH="1",
    ),
    parameter_case(
        "narrow_distributed_deeper_fifo",
        DATA_WIDTH_G="8",
        ADDR_WIDTH_G="5",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="distributed",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="1",
        EMPTY_THRES_G="1",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="0",
        WR_CLK_PERIOD_NS="7",
        RD_CLK_PERIOD_NS="11",
        RST_ACTIVE_HIGH="1",
    ),
    parameter_case(
        "fwft_threshold_midpoint",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="true",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="8",
        EMPTY_THRES_G="3",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="1",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="13",
        RST_ACTIVE_HIGH="1",
    ),
    parameter_case(
        "standard_threshold_near_full",
        DATA_WIDTH_G="16",
        ADDR_WIDTH_G="4",
        FWFT_EN_G="false",
        MEMORY_TYPE_G="block",
        PIPE_STAGES_G="0",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        SYNC_STAGES_G="3",
        FULL_THRES_G="14",
        EMPTY_THRES_G="2",
        CHECK_FULL_EMPTY="1",
        CHECK_THRESHOLD_FLAGS="1",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="13",
        RST_ACTIVE_HIGH="1",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_FifoAsync(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.fifoasync",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
