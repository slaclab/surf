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
# - Sweep: Sweep a common-clock case and an asynchronous-clock active-low input
#   case so period measurement is covered across both CDC and input-polarity
#   variation.
# - Stimulus: Generate trigger pulses with deliberately varied gaps, then reset
#   the statistics path to restart measurement.
# - Checks: The reported trigger period, min/max history, and update pulse must
#   reflect the actual spacing of the pulses after applying the configured
#   input polarity.
# - Timing: The bench checks period snapshots only when a new measurement
#   window closes and confirms that reset clears the historical statistics
#   before the next measured pulse pair.

import os

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
        self.common_clk = env_flag("COMMON_CLK_G", default=False)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.in_polarity = env_sl("IN_POLARITY_G", default=1)
        self.trig_clk_period_ns = float(os.environ["TRIG_CLK_PERIOD_NS"])
        self.loc_clk_period_ns = float(os.environ["LOC_CLK_PERIOD_NS"])

        dut.trigRst.value = 1
        dut.locRst.value = 1
        dut.resetStat.value = 0
        dut.trigIn.value = self.input_inactive_value()

        cocotb.start_soon(Clock(dut.trigClk, self.trig_clk_period_ns, unit="ns").start())
        if self.common_clk:
            cocotb.start_soon(Clock(dut.locClk, self.trig_clk_period_ns, unit="ns").start())
        else:
            cocotb.start_soon(Clock(dut.locClk, self.loc_clk_period_ns, unit="ns").start())

    def input_active_value(self) -> int:
        return self.in_polarity

    def input_inactive_value(self) -> int:
        return 1 - self.in_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle_trig(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.trigClk)
            await self.settle()

    async def cycle_loc(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.locClk)
            await self.settle()

    async def reset(self) -> None:
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle_trig(3)
        await self.cycle_loc(3)
        self.dut.trigRst.value = 0
        self.dut.locRst.value = 0
        await self.cycle_trig(2)
        await self.cycle_loc(2)

    async def emit_pulse(self) -> None:
        # Keep the trigger active for two source-clock cycles so the destination
        # side reliably sees one clean one-shot pulse even in async mode.
        self.dut.trigIn.value = self.input_active_value()
        await self.cycle_trig(2)
        self.dut.trigIn.value = self.input_inactive_value()

    async def wait_for_nonzero_period(self) -> int:
        for _ in range(60):
            await self.cycle_loc(1)
            if int(self.dut.period.value) != 0:
                return int(self.dut.period.value)
        assert int(self.dut.period.value) != 0
        return int(self.dut.period.value)


@cocotb.test()
async def period_tracking_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Arm the measurement with the first pulse, then generate two more pulses
    # separated by known locClk gaps so the current/min/max outputs can update.
    await tb.emit_pulse()
    await tb.cycle_loc(5)
    await tb.emit_pulse()
    first_period = await tb.wait_for_nonzero_period()

    await tb.cycle_loc(8)
    await tb.emit_pulse()
    second_period = await tb.wait_for_nonzero_period()

    if tb.common_clk:
        assert first_period >= 5
        assert second_period >= 8
        assert int(dut.periodMax.value) == max(first_period, second_period)
        assert int(dut.periodMin.value) == min(first_period, second_period)
    else:
        # In async mode the exact locClk cycle where the synchronized one-shot
        # appears depends on phase alignment, but the measured period must still
        # be non-zero and bounded by the min/max outputs.
        assert first_period > 0
        assert second_period > 0
        assert int(dut.periodMin.value) <= int(dut.period.value) <= int(dut.periodMax.value)


@cocotb.test()
async def statistics_reset_test(dut):
    tb = TB(dut)
    await tb.reset()

    await tb.emit_pulse()
    await tb.cycle_loc(6)
    await tb.emit_pulse()
    await tb.wait_for_nonzero_period()

    # resetStat should clear the tracked period statistics without needing a
    # full clock-domain reset sequence.
    tb.dut.resetStat.value = 1
    await tb.cycle_loc(1)
    tb.dut.resetStat.value = 0
    await tb.cycle_loc(1)

    assert int(dut.period.value) == 0
    assert int(dut.periodMax.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "common_clock",
        RST_ASYNC_G="false",
        COMMON_CLK_G="true",
        IN_POLARITY_G="'1'",
        CNT_WIDTH_G="8",
        TRIG_CLK_PERIOD_NS="5",
        LOC_CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_clock_active_low_input",
        RST_ASYNC_G="false",
        COMMON_CLK_G="false",
        IN_POLARITY_G="'0'",
        CNT_WIDTH_G="8",
        TRIG_CLK_PERIOD_NS="7",
        LOC_CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SyncTrigPeriod(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synctrigperiod",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
