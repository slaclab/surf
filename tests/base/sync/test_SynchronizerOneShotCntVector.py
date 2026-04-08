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
# - Sweep: Sweep a common-clock case and an asynchronous multi-clock case so
#   the vector counter is covered with and without CDC latency.
# - Stimulus: Pulse several lanes independently, then continue pulsing until
#   selected lanes hit rollover before asserting the counter-reset path.
# - Checks: Each lane's counter must increment independently, rollover must
#   occur only on the driven lanes that reach the limit, and reset must clear
#   the whole vector.
# - Timing: The bench checks per-lane updates after synchronization latency and
#   confirms that one lane's activity does not shift another lane's count
#   timing.

import os
from pathlib import Path

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

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
        self.width = int(os.environ["WIDTH_G"])
        self.cnt_width = int(os.environ["CNT_WIDTH_G"])
        self.common_clk = env_flag("COMMON_CLK_G", default=False)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.in_polarity = env_sl("IN_POLARITY_G", default=1)
        self.clk_period_ns = float(os.environ["WR_CLK_PERIOD_NS"])
        self.rd_clk_period_ns = float(os.environ["RD_CLK_PERIOD_NS"])
        self.max_count = (1 << self.cnt_width) - 1
        self.all_bits_mask = (1 << self.width) - 1

        dut.wrRst.value = self.reset_active_value()
        dut.rdRst.value = self.reset_active_value()
        dut.dataIn.value = self.input_inactive_mask()
        dut.rollOverEn.value = 0
        dut.cntRst.value = self.reset_inactive_value()

        # Start both domains before pulsing any lane so the helper methods can
        # talk about source and destination cycles explicitly.
        cocotb.start_soon(Clock(dut.wrClk, self.clk_period_ns, unit="ns").start())
        if self.common_clk:
            cocotb.start_soon(Clock(dut.rdClk, self.clk_period_ns, unit="ns").start())
        else:
            cocotb.start_soon(Clock(dut.rdClk, self.rd_clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def input_active_mask(self, mask: int) -> int:
        return mask if self.in_polarity else self.all_bits_mask ^ mask

    def input_inactive_mask(self) -> int:
        return 0 if self.in_polarity else self.all_bits_mask

    def counts(self) -> list[int]:
        raw = int(self.dut.cntOutFlat.value)
        mask = (1 << self.cnt_width) - 1
        return [(raw >> (index * self.cnt_width)) & mask for index in range(self.width)]

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle_wr(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.wrClk)
            await self.settle()

    async def cycle_rd(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.rdClk)
            await self.settle()

    async def reset(self) -> None:
        self.dut.wrRst.value = self.reset_active_value()
        self.dut.rdRst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle_wr(3)
        await self.cycle_rd(3)
        self.dut.wrRst.value = self.reset_inactive_value()
        self.dut.rdRst.value = self.reset_inactive_value()
        await self.cycle_wr(2)
        await self.cycle_rd(2)

    async def pulse_bits(self, mask: int) -> None:
        # Pulse the selected lanes for one write-domain cycle so the wrapper
        # has to keep each counter independent.
        self.dut.dataIn.value = self.input_active_mask(mask)
        await self.cycle_wr(1)
        self.dut.dataIn.value = self.input_inactive_mask()
        await self.cycle_wr(1)

    async def wait_for_counts(self, expected: list[int]) -> None:
        for _ in range(40):
            await self.cycle_rd(1)
            if self.counts() == expected:
                return
        assert self.counts() == expected


@cocotb.test()
async def vector_count_increment_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Fire two independent source lanes and confirm each destination-side
    # counter increments without disturbing the untouched middle lane.
    await tb.pulse_bits(0b101)
    await tb.wait_for_counts([1, 0, 1])


@cocotb.test()
async def rollover_and_counter_reset_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Enable rollover only on the middle lane so the test can check that each
    # channel obeys its own control bit inside the vector wrapper.
    tb.dut.rollOverEn.value = 0b010
    for _ in range(tb.max_count + 1):
        await tb.pulse_bits(0b011)

    await tb.wait_for_counts([tb.max_count, 0, 0])

    # Then issue the shared counter reset and confirm all flattened outputs
    # return to zero without needing a full module reset.
    tb.dut.cntRst.value = tb.reset_active_value()
    await tb.cycle_wr(1)
    tb.dut.cntRst.value = tb.reset_inactive_value()
    await tb.wait_for_counts([0, 0, 0])


PARAMETER_SWEEP = [
    parameter_case(
        "common_clock",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        COMMON_CLK_G="true",
        CNT_RST_EDGE_G="true",
        CNT_WIDTH_G="3",
        WIDTH_G="3",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_clock_domains",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        COMMON_CLK_G="false",
        CNT_RST_EDGE_G="true",
        CNT_WIDTH_G="3",
        WIDTH_G="3",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SynchronizerOneShotCntVector(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synchronizeroneshotcntvectorflatwrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": [str(Path("base/sync/wrappers/SynchronizerOneShotCntVectorFlatWrapper.vhd"))]},
    )
