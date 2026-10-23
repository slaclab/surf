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
# - Sweep: 1-, 8-, 14-, and 16-bit ADC words; ascending and descending vectors
#   with nonzero bounds; both output codings and positive/negative clipping.
# - Stimulus: Known coding boundaries, 8-bit exhaustive input words, and real
#   voltages at quarter-LSB offsets around zero and the full-scale rails.
# - Checks: Independent Python coding helpers and integer quantization oracle;
#   positive saturation never wraps to negative full scale or offset zero.
# - Timing: Combinational package adapter, sampled after one nanosecond.

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.adc import (
    offset_binary_to_twos_complement,
    twos_complement_to_offset_binary,
)
from tests.common.regression_utils import run_surf_vhdl_test


@cocotb.test()
async def adc_package_functions(dut):
    bits = len(dut.code)
    half = 1 << (bits - 1)
    mask = (1 << bits) - 1
    dut.analogQuarterLsb.value = 0
    words = range(mask + 1) if bits <= 8 else (0, 1, half - 1, half, half + 1, mask)
    for code in words:
        dut.code.value = code
        await Timer(1, unit="ns")
        twos = offset_binary_to_twos_complement(code, bits)
        offset = twos_complement_to_offset_binary(code, bits)
        assert int(dut.twosDescending.value) == twos
        assert int(dut.twosAscending.value) == twos
        assert int(dut.offsetDescending.value) == offset
        assert int(dut.offsetAscending.value) == offset

    # Quarter-LSB units make rounding expectations exact integer arithmetic.
    for units in (-4*half-4, -4*half, -6, -2, -1, 0, 1, 2, 6,
                  4*(half-1), 4*half-1, 4*half, 4*half+4):
        dut.analogQuarterLsb.value = units & 0xFFFFFFFF
        await Timer(1, unit="ns")
        offset = min(mask, max(0, (units + 4*half + 2)//4))
        signed = ((abs(units) + 2)//4) * (-1 if units < 0 else 1)
        signed = min(half-1, max(-half, signed))
        assert int(dut.analogOffset.value) == offset
        assert int(dut.analogTwos.value) == (signed & mask)


@pytest.mark.parametrize("bits", [1, 8, 14, 16])
def test_StdRtlPkgAdc(bits):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.stdrtlpkgadcwrapper",
        parameters={"BITS_G": bits},
        extra_vhdl_sources={
            "surf": ["base/general/wrappers/StdRtlPkgAdcWrapper.vhd"],
        },
    )
