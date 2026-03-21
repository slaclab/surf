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
from textwrap import dedent

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    env_flag,
    generate_vhdl_wrapper,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)


def _sync_trig_rate_vector_wrapper() -> str:
    return dedent(
        """\
        library ieee;
        use ieee.std_logic_1164.all;

        library surf;
        use surf.StdRtlPkg.all;

        entity SyncTrigRateVectorFlatWrapper is
           generic (
              TPD_G              : time     := 1 ns;
              RST_ASYNC_G        : boolean  := false;
              COMMON_CLK_G       : boolean  := false;
              ONE_SHOT_G         : boolean  := false;
              IN_POLARITY_G      : slv      := "1";
              REF_CLK_FREQ_INT_G : positive := 8;
              REFRESH_RATE_INT_G : positive := 1;
              CNT_WIDTH_G        : positive := 8;
              WIDTH_G            : positive := 3);
           port (
              trigIn          : in  slv(WIDTH_G-1 downto 0);
              trigRateUpdated : out sl;
              trigRateOutFlat : out slv(WIDTH_G*CNT_WIDTH_G-1 downto 0);
              locClkEn        : in  sl := '1';
              locClk          : in  sl;
              refClk          : in  sl);
        end entity SyncTrigRateVectorFlatWrapper;

        architecture rtl of SyncTrigRateVectorFlatWrapper is
           signal trigRateOutArr : SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0);
        begin
           U_DUT : entity surf.SyncTrigRateVector
              generic map (
                 TPD_G          => TPD_G,
                 RST_ASYNC_G    => RST_ASYNC_G,
                 COMMON_CLK_G   => COMMON_CLK_G,
                 ONE_SHOT_G     => ONE_SHOT_G,
                 IN_POLARITY_G  => IN_POLARITY_G,
                 REF_CLK_FREQ_G => real(REF_CLK_FREQ_INT_G),
                 REFRESH_RATE_G => real(REFRESH_RATE_INT_G),
                 CNT_WIDTH_G    => CNT_WIDTH_G,
                 WIDTH_G        => WIDTH_G)
              port map (
                 trigIn          => trigIn,
                 trigRateUpdated => trigRateUpdated,
                 trigRateOut     => trigRateOutArr,
                 locClkEn        => locClkEn,
                 locClk          => locClk,
                 refClk          => refClk);

           GEN_FLAT :
           for i in 0 to WIDTH_G-1 generate
              GEN_BITS :
              for j in 0 to CNT_WIDTH_G-1 generate
                 trigRateOutFlat(i*CNT_WIDTH_G + j) <= trigRateOutArr(i, j);
              end generate GEN_BITS;
           end generate GEN_FLAT;
        end architecture rtl;
        """
    )


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.width = int(os.environ["WIDTH_G"])
        self.cnt_width = int(os.environ["CNT_WIDTH_G"])
        self.ref_clk_freq = int(os.environ["REF_CLK_FREQ_INT_G"])
        self.common_clk = env_flag("COMMON_CLK_G", default=True)
        self.clk_period_ns = float(os.environ["LOCCLK_PERIOD_NS"])

        dut.trigIn.value = 0
        dut.locClkEn.value = 1

        # Keep this wrapper bench on the common-clock path because the point is
        # per-lane aggregation, not another deep async CDC campaign.
        start_lockstep_clocks(dut.locClk, dut.refClk, period_ns=self.clk_period_ns)

    def rates(self) -> list[int]:
        raw = int(self.dut.trigRateOutFlat.value)
        mask = (1 << self.cnt_width) - 1
        return [(raw >> (index * self.cnt_width)) & mask for index in range(self.width)]

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.locClk)
            await self.settle()

    async def drive_window(self, lane_masks: dict[int, int]) -> list[int]:
        counts = [0 for _ in range(self.width)]
        for cycle in range(self.ref_clk_freq):
            mask = lane_masks.get(cycle, 0)
            self.dut.trigIn.value = mask
            await self.cycle(1)
            for index in range(self.width):
                if mask & (1 << index):
                    counts[index] += 1
        self.dut.trigIn.value = 0
        return counts

    async def wait_for_rates(self, expected: list[int]) -> None:
        for _ in range(200):
            await self.cycle(1)
            if int(self.dut.trigRateUpdated.value) == 1 and self.rates() == expected:
                return
        assert self.rates() == expected


@cocotb.test()
async def vector_rate_snapshot_and_strobe_test(dut):
    tb = TB(dut)

    # Give three lanes different trigger activity inside one shared window so
    # the wrapper must keep each flattened counter separate.
    expected = await tb.drive_window({
        1: 0b001,
        3: 0b101,
        5: 0b100,
    })
    await tb.wait_for_rates(expected)

    # All lanes share the same update event, so the published strobe should
    # clear again on the next local cycle rather than staying asserted.
    await tb.cycle(1)
    assert int(dut.trigRateUpdated.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "common_clock_vector",
        RST_ASYNC_G="false",
        COMMON_CLK_G="true",
        ONE_SHOT_G="false",
        IN_POLARITY_G="1",
        REF_CLK_FREQ_INT_G="8",
        REFRESH_RATE_INT_G="1",
        CNT_WIDTH_G="8",
        WIDTH_G="3",
        LOCCLK_PERIOD_NS="10",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SyncTrigRateVector(parameters):
    hdl_parameters = hdl_parameters_from(parameters)
    wrapper_path = generate_vhdl_wrapper(
        test_file=__file__,
        wrapper_name="SyncTrigRateVectorFlatWrapper",
        source=_sync_trig_rate_vector_wrapper(),
        parameters=hdl_parameters,
    )

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synctrigratevectorflatwrapper",
        parameters=hdl_parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": [wrapper_path]},
    )
