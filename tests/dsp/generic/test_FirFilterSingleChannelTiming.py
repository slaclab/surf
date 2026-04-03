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
# - Sweep: Characterize both a short 5-tap and a deeper 31-tap single-channel
#   FIR using a checked-in center-tap-only coefficient set.
# - Stimulus: Drive one sample per accepted beat with unique sideband tags so
#   output timing can be read directly at the wrapper pins.
# - Checks: `obValid` must stay low until the full `din->dout` pipeline delay
#   has elapsed, then each visible beat must match both the FIR data reference
#   and the sideband from that same accepted input beat. A held output must
#   also remain stable when `obReady` is deasserted.
# - Timing: The test intentionally proves that the sideband path now matches
#   the actual filtered-data latency, not just the nominal FIR group delay.

import os
from pathlib import Path

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks
from tests.dsp.generic.dsp_test_utils import (
    fir_direct_outputs,
    tick,
    to_signed_int,
    to_unsigned,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.data_width = int(os.environ["DATA_WIDTH_G"])
        self.sideband_width = int(os.environ["SIDEBAND_WIDTH_G"])
        self.filter_delay = int(os.environ["FILTER_DELAY_G"])
        self.num_taps = int(os.environ["NUM_TAPS_G"])
        self.coeff_width = int(os.environ["COEFF_WIDTH_G"])
        self.center_coeff = int(os.environ["CENTER_COEFF_G"])

        start_lockstep_clocks(dut.clk, period_ns=5.0)
        dut.rst.setimmediatevalue(1)
        dut.ibValid.setimmediatevalue(0)
        dut.din.setimmediatevalue(0)
        dut.sbIn.setimmediatevalue(0)
        dut.obReady.setimmediatevalue(1)

    async def cycle(self, count=1):
        await tick(self.dut.clk, count=count)

    async def reset(self):
        self.dut.rst.value = 1
        await self.cycle(4)
        self.dut.rst.value = 0
        await self.cycle(4)

    async def send_sample(self, sample: int, sideband: int):
        self.dut.din.value = to_unsigned(sample, self.data_width)
        self.dut.sbIn.value = to_unsigned(sideband, self.sideband_width)
        self.dut.ibValid.value = 1
        await Timer(1, unit="ns")
        while int(self.dut.ibReady.value) == 0:
            await self.cycle(1)
        await self.cycle(1)
        self.dut.ibValid.value = 0

    async def wait_for_output(self):
        for _ in range(max(16, 4 * self.filter_delay)):
            if int(self.dut.obValid.value):
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for FIR timing output")

    def observed_word(self) -> int:
        return to_signed_int(int(self.dut.dout.value), self.data_width)

    def observed_sideband(self) -> int:
        return int(self.dut.sbOut.value)


def _samples_for_delay(filter_delay: int) -> list[int]:
    base = [14, -10, 6, -4, 12, 2, -8, 4, -6, 10, -2, 8, -12, 4, 6, -14, 2, -4, 12, -10, 8, -6, 14, -2]
    return base[: filter_delay + 9]


def _sidebands_for_count(count: int) -> list[int]:
    return list(range(1, count + 1))


def _coeffs(tb: TB) -> list[int]:
    coeffs = [0] * tb.num_taps
    coeffs[tb.filter_delay] = tb.center_coeff
    return coeffs


@cocotb.test()
async def visible_delay_and_alignment_test(dut):
    tb = TB(dut)
    await tb.reset()

    samples = _samples_for_delay(tb.filter_delay)
    sidebands = _sidebands_for_count(len(samples))
    expected_words = fir_direct_outputs(
        samples,
        _coeffs(tb),
        data_width=tb.data_width,
        coeff_width=tb.coeff_width,
    )
    visible_count = len(samples) - (tb.filter_delay + 1)
    expected_visible_words = expected_words[
        tb.filter_delay : tb.filter_delay + visible_count
    ]
    expected_visible_sidebands = sidebands[:visible_count]

    visible_outputs = 0
    for sample_index, (sample, sideband) in enumerate(zip(samples, sidebands)):
        await tb.send_sample(sample, sideband)

        if sample_index <= tb.filter_delay:
            assert int(dut.obValid.value) == 0
            continue

        assert int(dut.obValid.value) == 1

        assert tb.observed_word() == expected_visible_words[visible_outputs]
        assert tb.observed_sideband() == expected_visible_sidebands[visible_outputs]
        visible_outputs += 1

    assert visible_outputs == visible_count


@cocotb.test()
async def output_hold_test(dut):
    tb = TB(dut)
    await tb.reset()

    samples = _samples_for_delay(tb.filter_delay)
    sidebands = _sidebands_for_count(len(samples))
    expected_words = fir_direct_outputs(
        samples,
        _coeffs(tb),
        data_width=tb.data_width,
        coeff_width=tb.coeff_width,
    )
    visible_count = len(samples) - (tb.filter_delay + 1)
    expected_visible_words = expected_words[
        tb.filter_delay : tb.filter_delay + visible_count
    ]
    expected_visible_sidebands = sidebands[:visible_count]

    for sample_index, (sample, sideband) in enumerate(zip(samples, sidebands)):
        await tb.send_sample(sample, sideband)
        if sample_index <= tb.filter_delay:
            continue

        visible_index = sample_index - (tb.filter_delay + 1)
        if expected_visible_words[visible_index] == 0:
            continue

        tb.dut.obReady.value = 0
        held = (
            int(dut.obValid.value),
            int(dut.dout.value),
            int(dut.sbOut.value),
        )
        assert tb.observed_word() == expected_visible_words[visible_index]
        assert tb.observed_sideband() == expected_visible_sidebands[visible_index]
        await tb.cycle(3)
        assert held == (
            int(dut.obValid.value),
            int(dut.dout.value),
            int(dut.sbOut.value),
        )
        return

    raise AssertionError("Never reached a non-zero visible FIR output to hold")


PARAMETER_SWEEP = [
    pytest.param(
        {
            "WRAPPER_NAME": "FirFilterSingleChannelTiming5TapWrapper",
            "WRAPPER_PATH": "dsp/generic/wrappers/FirFilterSingleChannelTiming5TapWrapper.vhd",
            "FILTER_DELAY_G": "2",
            "NUM_TAPS_G": "5",
            "DATA_WIDTH_G": "8",
            "COEFF_WIDTH_G": "5",
            "SIDEBAND_WIDTH_G": "4",
            "CENTER_COEFF_G": "8",
        },
        id="five_tap_center_delay",
    ),
    pytest.param(
        {
            "WRAPPER_NAME": "FirFilterSingleChannelTiming31TapWrapper",
            "WRAPPER_PATH": "dsp/generic/wrappers/FirFilterSingleChannelTiming31TapWrapper.vhd",
            "FILTER_DELAY_G": "15",
            "NUM_TAPS_G": "31",
            "DATA_WIDTH_G": "8",
            "COEFF_WIDTH_G": "5",
            "SIDEBAND_WIDTH_G": "6",
            "CENTER_COEFF_G": "8",
        },
        id="thirty_one_tap_center_delay",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_FirFilterSingleChannelTiming(parameters):
    wrapper_name = str(parameters["WRAPPER_NAME"])
    sim_build_key = str(
        Path(__file__).resolve().parents[2]
        / "sim_build"
        / "dsp"
        / "generic"
        / f"test_FirFilterSingleChannelTiming.{wrapper_name}"
    )
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel=f"surf.{wrapper_name.lower()}",
        parameters=None,
        sim_build_key=sim_build_key,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "dsp/generic/fixed/FirFilterTap.vhd",
                "dsp/generic/fixed/FirFilterSingleChannel.vhd",
                str(parameters["WRAPPER_PATH"]),
            ]
        },
    )
