##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the terms
## contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Generate 8-, 14-, and 16-bit words used by supported ADC modes.
# - Stimulus: Feed all-ones and asymmetric nonzero PN9/PN23 states through many
#   consecutive word advances.
# - Checks: Every word and next state matches independent polynomial models;
#   the PN9 one-bit recurrence also proves its full 511-state nonzero period.
# - Timing: Package functions are combinational and checked after settling.

import os

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import hdl_parameters_from, parameter_case, run_surf_vhdl_test


def pn_next(state, order, tap):
    return ((state << 1) & ((1 << order) - 1)) | (((state >> (order - 1)) ^ (state >> (tap - 1))) & 1)


def pn_word(state, order, tap, width):
    word = 0
    for _ in range(width):
        word = (word << 1) | ((state >> (order - 1)) & 1)
        state = pn_next(state, order, tap)
    return word, state


@cocotb.test()
async def pn_pattern_test(dut):
    width = int(os.environ["WORD_WIDTH_G"])
    states = [(0x1FF, 0x7FFFFF), (0x12D, 0x654321)]

    for pn9, pn23 in states:
        for _ in range(64):
            dut.pn9State.value = pn9
            dut.pn23State.value = pn23
            await Timer(1, unit="ns")
            expected9, next9 = pn_word(pn9, 9, 5, width)
            expected23, next23 = pn_word(pn23, 23, 18, width)
            assert int(dut.pn9Word.value) == expected9
            assert int(dut.pn23Word.value) == expected23
            assert int(dut.pn9Next.value) == next9
            assert int(dut.pn23Next.value) == next23
            pn9, pn23 = next9, next23

    state = 0x1FF
    visited = set()
    for _ in range(511):
        assert state not in visited and state != 0
        visited.add(state)
        state = pn_next(state, 9, 5)
    assert state == 0x1FF


PARAMETER_SWEEP = [
    parameter_case("word_8", WORD_WIDTH_G="8"),
    parameter_case("word_14", WORD_WIDTH_G="14"),
    parameter_case("word_16", WORD_WIDTH_G="16"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AdcDdrPatternPkg(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.adcddrpatternpkgtb",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "devices/AnalogDevices/adcDdr/sim/AdcDdrPatternPkg.vhd",
                "devices/AnalogDevices/adcDdr/wrappers/AdcDdrPatternPkgTb.vhd",
            ],
        },
    )
