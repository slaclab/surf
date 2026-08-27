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
# - Sweep: Exercise a realistic 101-tap, 1 MHz low-pass FIR configuration at
#   the wrapper boundary.
# - Stimulus: Drive the same kind of waveform as the legacy VHDL bench, mixing
#   a 100 kHz tone that should pass with a 10 MHz tone that should be strongly
#   attenuated.
# - Checks: The wrapper-visible output stream must match the exact Python FIR
#   reference using the known `FirFilterSingleChannel` timing contract, and the
#   observed output must reduce the high-frequency residue relative to the raw
#   mixed input.

import math
import os
from pathlib import Path

import cocotb
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks
from tests.dsp.generic.dsp_test_utils import fir_direct_outputs, tick, to_signed_int, to_unsigned

LOWPASS_101_COEFFS = [
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 4, 6, 7, 9, 11, 12, 15, 17, 20, 22,
    25, 28, 31, 35, 38, 42, 46, 49, 53, 57, 61, 64, 68, 72, 75, 78, 82, 85, 87,
    90, 92, 94, 96, 97, 99, 99, 100, 100, 100, 99, 99, 97, 96, 94, 92, 90, 87,
    85, 82, 78, 75, 72, 68, 64, 61, 57, 53, 49, 46, 42, 38, 35, 31, 28, 25, 22,
    20, 17, 15, 12, 11, 9, 7, 6, 4, 3, 2, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
]


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.data_width = int(os.environ["DATA_WIDTH_G"])
        self.coeff_width = int(os.environ["COEFF_WIDTH_G"])
        self.filter_delay = int(os.environ["FILTER_DELAY"])
        self.axil = None

        start_lockstep_clocks(dut.clk, dut.S_AXI_ACLK, period_ns=10.0)
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

    async def send_sample(self, sample: int):
        self.dut.din.value = to_unsigned(sample, self.data_width)
        self.dut.sbIn.value = 0
        self.dut.ibValid.value = 1
        while int(self.dut.ibReady.value) == 0:
            await self.cycle(1)
        await self.cycle(1)
        self.dut.ibValid.value = 0

    def observed_word(self) -> int:
        return to_signed_int(int(self.dut.dout.value), self.data_width)


def _wave_samples(count: int) -> tuple[list[int], list[int]]:
    mixed: list[int] = []
    low_only: list[int] = []
    sample_period = 10.0e-9
    for index in range(count):
        t = index * sample_period
        low = 1000.0 * math.sin(2.0 * math.pi * 0.1e6 * t)
        high = 1000.0 * math.sin(2.0 * math.pi * 10.0e6 * t)
        mixed.append(int(low + high))
        low_only.append(int(low))
    return mixed, low_only


def _rms(values: list[float]) -> float:
    return math.sqrt(sum(value * value for value in values) / len(values))


async def _program_coeffs(tb: TB) -> None:
    tb.start_axil()
    for index, coeff in enumerate(LOWPASS_101_COEFFS):
        await axil_write_u32(tb.axil, 4 * index, to_unsigned(coeff, tb.coeff_width))


@cocotb.test()
async def low_pass_waveform_test(dut):
    tb = TB(dut)
    await tb.reset()
    await _program_coeffs(tb)

    sample_count = 192
    samples, low_only_samples = _wave_samples(sample_count)
    expected_words = fir_direct_outputs(
        samples,
        LOWPASS_101_COEFFS,
        data_width=tb.data_width,
        coeff_width=tb.coeff_width,
    )
    low_only_words = fir_direct_outputs(
        low_only_samples,
        LOWPASS_101_COEFFS,
        data_width=tb.data_width,
        coeff_width=tb.coeff_width,
    )

    observed_stream_words: list[int] = []
    for sample in samples:
        await tb.send_sample(sample)
        if int(dut.obValid.value):
            observed_stream_words.append(tb.observed_word())

    assert observed_stream_words

    matching_offsets = [
        offset
        for offset in range(len(expected_words) - len(observed_stream_words) + 1)
        if expected_words[offset : offset + len(observed_stream_words)] == observed_stream_words
    ]
    assert len(matching_offsets) == 1
    offset = matching_offsets[0]
    expected_stream_low_only = low_only_words[offset : offset + len(observed_stream_words)]

    input_residue = _rms(
        [
            float(mixed - low)
            for mixed, low in zip(
                samples[offset : offset + len(observed_stream_words)],
                low_only_samples[offset : offset + len(observed_stream_words)],
            )
        ]
    )
    output_residue = _rms(
        [
            float(observed - low)
            for observed, low in zip(observed_stream_words, expected_stream_low_only)
        ]
    )
    assert output_residue < (0.35 * input_residue)


def test_FirFilterSingleChannelLowPass():
    parameters = {
        "DATA_WIDTH_G": "12",
        "COEFF_WIDTH_G": "12",
        "NUM_TAPS_G": "101",
        "SIDEBAND_WIDTH_G": "1",
        "FILTER_DELAY": "50",
    }
    sim_build_key = str(
        Path(__file__).resolve().parents[2]
        / "sim_build"
        / "dsp"
        / "generic"
        / "test_FirFilterSingleChannelLowPass.NUM_TAPS_G=101,SIDEBAND_WIDTH_G=1,DATA_WIDTH_G=12,COEFF_WIDTH_G=12"
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
