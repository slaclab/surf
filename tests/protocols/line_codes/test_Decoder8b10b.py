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
# - Sweep: Cover one- and two-byte decoder configurations plus an async
#   active-low reset case.
# - Stimulus: Drive clearly malformed encoded words, then repeat the launch
#   while `clkEn` is held low for one cycle.
# - Checks: Malformed words must assert a decoder error, and `clkEn=0` must
#   prevent the decoder from publishing that result until the clock is enabled.
# - Timing: The bench samples the registered outputs one cycle after each
#   attempted launch.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.line_codes.line_code_test_utils import (
    ClockedLineCodeTB,
    all_ones,
    error_detected,
    run_line_code_entity_test,
)


@cocotb.test()
async def malformed_symbol_flags_error_test(dut):
    tb = ClockedLineCodeTB(dut)
    await tb.reset()

    for malformed in (0, all_ones(dut.dataIn)):
        dut.dataIn.value = malformed
        dut.validIn.value = 1
        await tb.cycle(1)
        dut.validIn.value = 0

        assert int(dut.validOut.value) == 1
        assert error_detected(dut)


@cocotb.test()
async def clk_enable_gates_update_test(dut):
    tb = ClockedLineCodeTB(dut)
    await tb.reset()

    dut.clkEn.value = 0
    dut.dataIn.value = all_ones(dut.dataIn)
    dut.validIn.value = 1
    await tb.cycle(1)

    assert int(dut.validOut.value) == 0

    dut.clkEn.value = 1
    await tb.cycle(1)
    dut.validIn.value = 0

    assert int(dut.validOut.value) == 1
    assert error_detected(dut)


PARAMETER_SWEEP = [
    parameter_case(
        "single_byte_sync",
        NUM_BYTES_G="1",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "dual_byte_sync",
        NUM_BYTES_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "dual_byte_async_active_low",
        NUM_BYTES_G="2",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Decoder8b10b(parameters):
    run_line_code_entity_test(
        test_file=__file__,
        toplevel="surf.decoder8b10b",
        parameters=parameters,
    )
