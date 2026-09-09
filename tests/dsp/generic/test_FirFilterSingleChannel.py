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
# - Sweep: Keep one stable common-clock FIR configuration with a small
#   coefficient set so the test proves data flow, sideband alignment, and
#   AXI-Lite coefficient access without exploding runtime.
# - Stimulus: Drive scalar samples through a checked-in flat-port wrapper,
#   inspect the initial coefficient registers, rewrite one coefficient through
#   AXI-Lite, and then continue streaming data.
# - Checks: Readback values must match the programmed coefficients, output
#   samples must follow a Python FIR reference model, and the delayed sideband
#   must stay aligned with the corresponding filtered output.
# - Timing: The bench drives the data and AXI-Lite clocks in lockstep because
#   the DUT is in `COMMON_CLK_G=true`, then waits on `obValid` so the checks
#   follow the aligned wrapper-visible latency rather than a hard-coded cycle
#   count.

import os
from pathlib import Path

import cocotb
import pytest
from cocotb.triggers import Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
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
        self.coeff_width = int(os.environ["COEFF_WIDTH_G"])
        self.num_taps = int(os.environ["NUM_TAPS_G"])
        self.filter_delay = (int(os.environ["NUM_TAPS_G"]) - 1) // 2
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
        self.dut.sbIn.value = sideband
        self.dut.ibValid.value = 1
        await Timer(1, unit="ns")
        while int(self.dut.ibReady.value) == 0:
            await self.cycle(1)
        await self.cycle(1)
        self.dut.ibValid.value = 0

    async def wait_for_output(self):
        for _ in range(16):
            if int(self.dut.obValid.value):
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for FIR output")


def _parse_coeffs(raw: str) -> list[int]:
    values: list[int] = []
    for entry in raw.strip().strip("()").split(","):
        _, value = entry.split("=>")
        values.append(int(value.strip()))
    return values


@cocotb.test()
async def fir_data_and_axil_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_axil()

    coeffs = _parse_coeffs(os.environ["COEFFICIENTS_G"])
    coeff_mask = (1 << tb.coeff_width) - 1
    for index, coeff in enumerate(coeffs):
        assert await axil_read_u32(tb.axil, 4 * index) & coeff_mask == to_unsigned(coeff, tb.coeff_width)

    update_addr = int(os.environ["COEFF_UPDATE_ADDR"])
    update_value = int(os.environ["COEFF_UPDATE_VALUE"])
    await axil_write_u32(tb.axil, 4 * update_addr, to_unsigned(update_value, tb.coeff_width))
    assert await axil_read_u32(tb.axil, 4 * update_addr) & coeff_mask == to_unsigned(update_value, tb.coeff_width)
    coeffs[update_addr] = update_value
    reference_coeffs = coeffs
    if os.environ.get("REVERSE_REFERENCE_COEFFS", "0") == "1":
        reference_coeffs = list(reversed(coeffs))

    samples = [int(value) for value in os.environ["SAMPLE_SEQUENCE"].split(",")]
    sidebands = [int(value) for value in os.environ["SIDEBAND_SEQUENCE"].split(",")]
    expected_words = fir_direct_outputs(
        samples,
        reference_coeffs,
        data_width=tb.data_width,
        coeff_width=tb.coeff_width,
    )
    visible_offset = int(os.environ.get("VISIBLE_OFFSET", "0"))
    sideband_visible_offset = int(os.environ.get("SIDEBAND_VISIBLE_OFFSET", "0"))
    visible_count = len(samples) - (tb.filter_delay + 1)
    expected_visible_words = expected_words[visible_offset : visible_offset + visible_count]
    expected_visible_sidebands = sidebands[
        sideband_visible_offset : sideband_visible_offset + visible_count
    ]

    visible_index = 0
    for sample_index, (sample, sideband) in enumerate(zip(samples, sidebands)):
        await tb.send_sample(sample, sideband)
        if sample_index >= (tb.filter_delay + 1):
            await tb.wait_for_output()
            observed_word = to_signed_int(int(dut.dout.value), tb.data_width)
            observed_sideband = int(dut.sbOut.value)
            assert observed_word == expected_visible_words[visible_index]
            assert observed_sideband == expected_visible_sidebands[visible_index]
            visible_index += 1
            await tb.cycle(1)


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param(
            {
                "COEFFICIENTS_G": "(0 => 7, 1 => 0, 2 => 0)",
                "NUM_TAPS_G": 3,
                "SIDEBAND_WIDTH_G": 2,
                "DATA_WIDTH_G": 8,
                "COEFF_WIDTH_G": 4,
                "COEFF_UPDATE_ADDR": 1,
                "COEFF_UPDATE_VALUE": 7,
                "SAMPLE_SEQUENCE": "3,-2,5,1",
                "SIDEBAND_SEQUENCE": "1,2,3,0",
                "REVERSE_REFERENCE_COEFFS": "1",
                "VISIBLE_OFFSET": 0,
                "SIDEBAND_VISIBLE_OFFSET": 0,
            },
            id="common_clock_data_and_axil",
        )
    ],
)
def test_FirFilterSingleChannel(parameters):
    sim_build_key = str(
        Path(__file__).resolve().parents[2]
        / "sim_build"
        / "dsp"
        / "generic"
        / "test_FirFilterSingleChannel.FirFilterSingleChannelTestWrapper"
    )
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.firfiltersinglechanneltestwrapper",
        parameters=None,
        sim_build_key=sim_build_key,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "dsp/generic/wrappers/FirFilterSingleChannelTestWrapper.vhd",
            ]
        },
    )
