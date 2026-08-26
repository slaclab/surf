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
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.common.regression_utils import (
    run_surf_vhdl_test,
    start_lockstep_clocks,
)
from tests.axi.utils import axil_write_u32
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
        self.filter_delay = int(os.environ["FILTER_DELAY"])
        self.num_taps = int(os.environ["NUM_TAPS_G"])
        self.coeff_width = int(os.environ["COEFF_WIDTH_G"])
        self.axil = None

        start_lockstep_clocks(dut.clk, dut.S_AXI_ACLK, period_ns=5.0)
        dut.rst.setimmediatevalue(1)
        dut.S_AXI_ARESETN.setimmediatevalue(0)
        dut.ibValid.setimmediatevalue(0)
        dut.din.setimmediatevalue(0)
        dut.sbIn.setimmediatevalue(0)
        dut.obReady.setimmediatevalue(1)

    async def cycle(self, count=1):
        await tick(self.dut.clk, count=count)

    async def reset(self):
        self.dut.rst.value = 1
        self.dut.S_AXI_ARESETN.value = 0
        await self.cycle(4)
        self.dut.rst.value = 0
        self.dut.S_AXI_ARESETN.value = 1
        await self.cycle(4)

    def start_axil(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(
                AxiLiteBus.from_prefix(self.dut, "S_AXI"),
                self.dut.S_AXI_ACLK,
                self.dut.S_AXI_ARESETN,
                reset_active_level=False,
            )

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


def _parse_coeffs(raw: str) -> list[int]:
    values: list[int] = []
    for entry in raw.strip().strip("()").split(","):
        _, value = entry.split("=>")
        values.append(int(value.strip()))
    return values


async def _program_coeffs(tb: TB, coeffs: list[int]) -> None:
    tb.start_axil()
    for index, coeff in enumerate(coeffs):
        await axil_write_u32(tb.axil, 4 * index, to_unsigned(coeff, tb.coeff_width))


@cocotb.test()
async def visible_delay_and_alignment_test(dut):
    tb = TB(dut)
    await tb.reset()
    coeffs = _parse_coeffs(os.environ["COEFFICIENTS_G"])
    await _program_coeffs(tb, coeffs)

    samples = _samples_for_delay(tb.filter_delay)
    sidebands = _sidebands_for_count(len(samples))
    expected_words = fir_direct_outputs(
        samples,
        coeffs,
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
    coeffs = _parse_coeffs(os.environ["COEFFICIENTS_G"])
    await _program_coeffs(tb, coeffs)

    samples = _samples_for_delay(tb.filter_delay)
    sidebands = _sidebands_for_count(len(samples))
    expected_words = fir_direct_outputs(
        samples,
        coeffs,
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
            "NUM_TAPS_G": "5",
            "DATA_WIDTH_G": "8",
            "COEFF_WIDTH_G": "5",
            "SIDEBAND_WIDTH_G": "4",
            "COEFFICIENTS_G": "(0 => 0, 1 => 0, 2 => 8, 3 => 0, 4 => 0)",
            "FILTER_DELAY": "2",
        },
        id="five_tap_center_delay",
    ),
    pytest.param(
        {
            "NUM_TAPS_G": "31",
            "DATA_WIDTH_G": "8",
            "COEFF_WIDTH_G": "5",
            "SIDEBAND_WIDTH_G": "6",
            "COEFFICIENTS_G": "(0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 8, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0)",
            "FILTER_DELAY": "15",
        },
        id="thirty_one_tap_center_delay",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_FirFilterSingleChannelTiming(parameters):
    sim_build_key = str(
        Path(__file__).resolve().parents[2]
        / "sim_build"
        / "dsp"
        / "generic"
        / f"test_FirFilterSingleChannelTiming.NUM_TAPS_G={parameters['NUM_TAPS_G']},SIDEBAND_WIDTH_G={parameters['SIDEBAND_WIDTH_G']},DATA_WIDTH_G={parameters['DATA_WIDTH_G']},COEFF_WIDTH_G={parameters['COEFF_WIDTH_G']}"
    )
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.firfiltersinglechannelwrapper",
        parameters={
            "NUM_TAPS_G": parameters["NUM_TAPS_G"],
            "SIDEBAND_WIDTH_G": parameters["SIDEBAND_WIDTH_G"],
            "DATA_WIDTH_G": parameters["DATA_WIDTH_G"],
            "COEFF_WIDTH_G": parameters["COEFF_WIDTH_G"],
        },
        sim_build_key=sim_build_key,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "dsp/generic/wrappers/FirFilterSingleChannelWrapper.vhd",
            ]
        },
    )
