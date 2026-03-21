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
    env_sl,
    generate_vhdl_wrapper,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)


def _sync_trig_rate_wrapper_source() -> str:
    return build_vhdl_wrapper_source(
        wrapper_name="SyncTrigRateWrapper",
        wrapped_entity="SyncTrigRate",
        generic_declarations=[
            "TPD_G              : time     := 1 ns",
            "RST_ASYNC_G        : boolean  := false",
            "COMMON_CLK_G       : boolean  := false",
            "ONE_SHOT_G         : boolean  := false",
            "IN_POLARITY_G      : sl       := '1'",
            "COUNT_EDGES_G      : boolean  := false",
            "REF_CLK_FREQ_INT_G : positive := 8",
            "REFRESH_RATE_INT_G : positive := 1",
            "CNT_WIDTH_G        : positive := 32",
        ],
        port_declarations=[
            "trigIn          : in  sl",
            "trigRateUpdated : out sl",
            "trigRateOut     : out slv(CNT_WIDTH_G-1 downto 0)",
            "trigRateOutMax  : out slv(CNT_WIDTH_G-1 downto 0)",
            "trigRateOutMin  : out slv(CNT_WIDTH_G-1 downto 0)",
            "locClkEn        : in  sl := '1'",
            "locClk          : in  sl",
            "locRst          : in  sl := '0'",
            "refClk          : in  sl",
            "refRst          : in  sl := '0'",
        ],
        generic_map=[
            "TPD_G          => TPD_G",
            "RST_ASYNC_G    => RST_ASYNC_G",
            "COMMON_CLK_G   => COMMON_CLK_G",
            "ONE_SHOT_G     => ONE_SHOT_G",
            "IN_POLARITY_G  => IN_POLARITY_G",
            "COUNT_EDGES_G  => COUNT_EDGES_G",
            "REF_CLK_FREQ_G => real(REF_CLK_FREQ_INT_G)",
            "REFRESH_RATE_G => real(REFRESH_RATE_INT_G)",
            "CNT_WIDTH_G    => CNT_WIDTH_G",
        ],
        port_map=[
            "trigIn          => trigIn",
            "trigRateUpdated => trigRateUpdated",
            "trigRateOut     => trigRateOut",
            "trigRateOutMax  => trigRateOutMax",
            "trigRateOutMin  => trigRateOutMin",
            "locClkEn        => locClkEn",
            "locClk          => locClk",
            "locRst          => locRst",
            "refClk          => refClk",
            "refRst          => refRst",
        ],
    )


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.common_clk = env_flag("COMMON_CLK_G", default=False)
        self.count_edges = env_flag("COUNT_EDGES_G", default=False)
        self.in_polarity = env_sl("IN_POLARITY_G", default=1)
        self.ref_clk_freq = int(os.environ["REF_CLK_FREQ_INT_G"])
        self.clk_period_ns = float(os.environ["LOCCLK_PERIOD_NS"])
        self.ref_clk_period_ns = float(os.environ["REFCLK_PERIOD_NS"])

        dut.trigIn.value = self.inactive_value()
        dut.locClkEn.value = 1
        dut.locRst.value = 0
        dut.refRst.value = 0

        if self.common_clk:
            start_lockstep_clocks(dut.locClk, dut.refClk, period_ns=self.clk_period_ns)
        else:
            cocotb.start_soon(Clock(dut.locClk, self.clk_period_ns, unit="ns").start())
            cocotb.start_soon(Clock(dut.refClk, self.ref_clk_period_ns, unit="ns").start())

    def active_value(self) -> int:
        return self.in_polarity

    def inactive_value(self) -> int:
        return 1 - self.in_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle_loc(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.locClk)
            await self.settle()

    async def reset_stats(self) -> None:
        # These resets only clear the SyncMinMax statistics path. The trigger
        # counter and refresh timer keep running, so tests still need to align
        # stimulus to an observed update boundary before they expect an exact
        # rate sample.
        self.dut.locRst.value = 1
        self.dut.refRst.value = 1
        await self.cycle_loc(2)
        self.dut.locRst.value = 0
        self.dut.refRst.value = 0
        await self.cycle_loc(2)

    async def wait_for_update(self) -> tuple[int, int, int]:
        for _ in range(200):
            await self.cycle_loc(1)
            if int(self.dut.trigRateUpdated.value) == 1:
                return (
                    int(self.dut.trigRateOut.value),
                    int(self.dut.trigRateOutMin.value),
                    int(self.dut.trigRateOutMax.value),
                )

        assert int(self.dut.trigRateUpdated.value) == 1
        return (0, 0, 0)

    async def drive_window(self, active_cycles: set[int]) -> int:
        # Drive one full refresh window worth of trigger activity. For edge
        # mode that means one-cycle pulses; for high-time mode it means holding
        # the trigger active on the selected cycles.
        counted = 0
        previous_active = False
        for cycle in range(self.ref_clk_freq):
            active = cycle in active_cycles
            self.dut.trigIn.value = self.active_value() if active else self.inactive_value()
            await self.cycle_loc(1)
            if self.count_edges:
                if active and not previous_active:
                    counted += 1
            elif active:
                counted += 1
            previous_active = active

        self.dut.trigIn.value = self.inactive_value()
        return counted

    async def align_to_window_start(self) -> None:
        # SyncTrigRate never resets its free-running measurement timer. Anchor
        # the next stimulus window to the most recent published update pulse so
        # the following `REF_CLK_FREQ_INT_G` cycles correspond to one complete,
        # known measurement window.
        await self.wait_for_update()
        await self.cycle_loc(1)

    async def capture_next_snapshot(self) -> tuple[int, int, int]:
        return await self.wait_for_update()


@cocotb.test()
async def aligned_windows_update_and_reseed_statistics_test(dut):
    tb = TB(dut)
    await tb.reset_stats()
    await tb.align_to_window_start()

    # Start from a known published boundary, then drive one full refresh window
    # with a smaller pulse train and the next window with a denser pulse train.
    # SyncMinMax already has its own leaf regression, so this wrapper bench is
    # intentionally focused on the integrated rate-publishing path: a live
    # non-zero sample, a higher rate for a denser pulse train, and a working
    # statistics-reset path that does not wedge the updater.
    await tb.drive_window({2, 6})
    first_rate, first_min, first_max = await tb.capture_next_snapshot()
    assert first_rate > 0

    await tb.drive_window({1, 3, 5, 7})
    second_rate, second_min, second_max = await tb.capture_next_snapshot()
    assert second_rate > first_rate
    assert second_min >= 0
    assert second_max >= 0

    # Reset the statistics path without touching the clocks, then confirm the
    # next aligned measurement still publishes a live sample. The measurement
    # engine itself keeps running, so re-anchor to the next published boundary
    # before driving the post-reset window.
    await tb.reset_stats()
    await tb.align_to_window_start()

    await tb.drive_window({2, 6})
    reseed_rate, reseed_min, reseed_max = await tb.capture_next_snapshot()
    assert reseed_rate > 0
    assert reseed_min >= 0
    assert reseed_max >= 0

    # The update strobe should still behave like a pulse after the reseed path
    # completes, not as a sticky indicator.
    await tb.cycle_loc(1)
    assert int(dut.trigRateUpdated.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "edge_count_common_clock",
        RST_ASYNC_G="false",
        COMMON_CLK_G="true",
        ONE_SHOT_G="false",
        IN_POLARITY_G="'1'",
        COUNT_EDGES_G="true",
        REF_CLK_FREQ_INT_G="8",
        REFRESH_RATE_INT_G="1",
        CNT_WIDTH_G="8",
        LOCCLK_PERIOD_NS="10",
        REFCLK_PERIOD_NS="10",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SyncTrigRate(parameters):
    hdl_parameters = hdl_parameters_from(parameters)
    wrapper_path = generate_vhdl_wrapper(
        test_file=__file__,
        wrapper_name="SyncTrigRateWrapper",
        source=_sync_trig_rate_wrapper_source(),
        parameters=hdl_parameters,
    )

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synctrigratewrapper",
        parameters=hdl_parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": [wrapper_path]},
    )
