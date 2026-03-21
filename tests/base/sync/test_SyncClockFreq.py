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
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    build_vhdl_wrapper_source,
    env_flag,
    generate_vhdl_wrapper,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)


def _clock_freq_wrapper_source() -> str:
    return build_vhdl_wrapper_source(
        wrapper_name="SyncClockFreqWrapper",
        wrapped_entity="SyncClockFreq",
        generic_declarations=[
            "TPD_G               : time     := 1 ns",
            "RST_ASYNC_G         : boolean  := false",
            "USE_DSP_G           : string   := \"no\"",
            "REF_CLK_FREQ_INT_G  : positive := 8",
            "REFRESH_RATE_INT_G  : positive := 1",
            "CLK_LOWER_LIMIT_G   : natural  := 0",
            "CLK_UPPER_LIMIT_G   : natural  := 16",
            "COMMON_CLK_G        : boolean  := false",
            "CNT_WIDTH_G         : positive := 32",
        ],
        port_declarations=[
            "freqOut     : out slv(CNT_WIDTH_G-1 downto 0)",
            "freqUpdated : out sl",
            "locked      : out sl",
            "tooFast     : out sl",
            "tooSlow     : out sl",
            "clkIn       : in  sl",
            "locClk      : in  sl",
            "refClk      : in  sl",
        ],
        generic_map=[
            "TPD_G             => TPD_G",
            "RST_ASYNC_G       => RST_ASYNC_G",
            "USE_DSP_G         => USE_DSP_G",
            "REF_CLK_FREQ_G    => real(REF_CLK_FREQ_INT_G)",
            "REFRESH_RATE_G    => real(REFRESH_RATE_INT_G)",
            "CLK_LOWER_LIMIT_G => real(CLK_LOWER_LIMIT_G)",
            "CLK_UPPER_LIMIT_G => real(CLK_UPPER_LIMIT_G)",
            "COMMON_CLK_G      => COMMON_CLK_G",
            "CNT_WIDTH_G       => CNT_WIDTH_G",
        ],
        port_map=[
            "freqOut     => freqOut",
            "freqUpdated => freqUpdated",
            "locked      => locked",
            "tooFast     => tooFast",
            "tooSlow     => tooSlow",
            "clkIn       => clkIn",
            "locClk      => locClk",
            "refClk      => refClk",
        ],
    )


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.common_clk = env_flag("COMMON_CLK_G", default=False)
        self.lockstep_all = env_flag("LOCKSTEP_ALL_CLOCKS", default=False)
        self.clk_in_period_ns = float(os.environ["CLKIN_PERIOD_NS"])
        self.loc_clk_period_ns = float(os.environ["LOCCLK_PERIOD_NS"])
        self.ref_clk_period_ns = float(os.environ["REFCLK_PERIOD_NS"])
        self.expected_min_freq = int(os.environ["EXPECTED_MIN_FREQ"])
        self.expected_max_freq = int(os.environ["EXPECTED_MAX_FREQ"])
        self.expect_locked = env_flag("EXPECT_LOCKED", default=False)
        self.expect_too_slow = env_flag("EXPECT_TOO_SLOW", default=False)
        self.expect_too_fast = env_flag("EXPECT_TOO_FAST", default=False)

        if self.lockstep_all:
            # Use one coroutine when all three clocks are meant to be identical
            # so the COMMON_CLK_G case really sees shared edges.
            start_lockstep_clocks(dut.clkIn, dut.locClk, dut.refClk, period_ns=self.ref_clk_period_ns)
        elif self.common_clk:
            start_lockstep_clocks(dut.locClk, dut.refClk, period_ns=self.ref_clk_period_ns)
            cocotb.start_soon(Clock(dut.clkIn, self.clk_in_period_ns, unit="ns").start())
        else:
            cocotb.start_soon(Clock(dut.clkIn, self.clk_in_period_ns, unit="ns").start())
            cocotb.start_soon(Clock(dut.locClk, self.loc_clk_period_ns, unit="ns").start())
            cocotb.start_soon(Clock(dut.refClk, self.ref_clk_period_ns, unit="ns").start())

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle_loc(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.locClk)
            await self.settle()

    async def wait_for_measurement(self) -> None:
        # Wait until the published frequency lands inside the expected range.
        # The common-clock path can quantize one count above the abstract
        # target because the sampled free-running counter spans the refresh
        # boundary inclusively, so the bench checks a bounded range rather than
        # pretending the measurement is infinitely precise.
        for _ in range(200):
            await self.cycle_loc(1)
            measured = int(self.dut.freqOut.value)
            if (
                int(self.dut.freqUpdated.value) == 1
                and self.expected_min_freq <= measured <= self.expected_max_freq
            ):
                return
        assert self.expected_min_freq <= int(self.dut.freqOut.value) <= self.expected_max_freq

    async def wait_for_flags(self) -> None:
        # The lock/too-fast/too-slow comparators run in the local clock domain
        # after `freqHertz` has updated, so leave room for those one-cycle
        # status bits to settle before checking the monitor outputs.
        for _ in range(20):
            await self.cycle_loc(1)
            if (
                int(self.dut.locked.value) == int(self.expect_locked)
                and int(self.dut.tooSlow.value) == int(self.expect_too_slow)
                and int(self.dut.tooFast.value) == int(self.expect_too_fast)
            ):
                return

        assert int(self.dut.locked.value) == int(self.expect_locked)
        assert int(self.dut.tooSlow.value) == int(self.expect_too_slow)
        assert int(self.dut.tooFast.value) == int(self.expect_too_fast)


@cocotb.test()
async def measurement_and_update_pulse_test(dut):
    tb = TB(dut)
    await tb.wait_for_measurement()
    await tb.wait_for_flags()

    # Once one complete measurement has propagated back into `locClk`, the
    # rate output and the fast/slow/locked flags should agree with the chosen
    # threshold window for that parameter case.
    assert tb.expected_min_freq <= int(dut.freqOut.value) <= tb.expected_max_freq
    assert int(dut.locked.value) == int(tb.expect_locked)
    assert int(dut.tooSlow.value) == int(tb.expect_too_slow)
    assert int(dut.tooFast.value) == int(tb.expect_too_fast)

    # `freqUpdated` should behave like a pulse in the local clock domain, not a
    # sticky level that would make software think every cycle was a new sample.
    await tb.cycle_loc(1)
    assert int(dut.freqUpdated.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "common_clock_locked",
        COMMON_CLK_G="true",
        LOCKSTEP_ALL_CLOCKS="true",
        REF_CLK_FREQ_INT_G="8",
        REFRESH_RATE_INT_G="1",
        CLK_LOWER_LIMIT_G="7",
        CLK_UPPER_LIMIT_G="9",
        CNT_WIDTH_G="8",
        CLKIN_PERIOD_NS="10",
        LOCCLK_PERIOD_NS="10",
        REFCLK_PERIOD_NS="10",
        EXPECTED_MIN_FREQ="8",
        EXPECTED_MAX_FREQ="9",
        EXPECT_LOCKED="1",
        EXPECT_TOO_SLOW="0",
        EXPECT_TOO_FAST="0",
    ),
    parameter_case(
        "async_too_slow",
        COMMON_CLK_G="false",
        LOCKSTEP_ALL_CLOCKS="false",
        REF_CLK_FREQ_INT_G="8",
        REFRESH_RATE_INT_G="1",
        CLK_LOWER_LIMIT_G="5",
        CLK_UPPER_LIMIT_G="6",
        CNT_WIDTH_G="8",
        CLKIN_PERIOD_NS="20",
        LOCCLK_PERIOD_NS="10",
        REFCLK_PERIOD_NS="10",
        EXPECTED_MIN_FREQ="4",
        EXPECTED_MAX_FREQ="4",
        EXPECT_LOCKED="0",
        EXPECT_TOO_SLOW="1",
        EXPECT_TOO_FAST="0",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SyncClockFreq(parameters):
    hdl_parameters = hdl_parameters_from(parameters)
    wrapper_path = generate_vhdl_wrapper(
        test_file=__file__,
        wrapper_name="SyncClockFreqWrapper",
        source=_clock_freq_wrapper_source(),
        parameters=hdl_parameters,
    )

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.syncclockfreqwrapper",
        parameters=hdl_parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": [wrapper_path]},
    )
