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
# - Sweep: Cover synchronous and asynchronous reset variants with
#   `USE_CLK_EN_G=true` and `FLOW_CTRL_EN_G=true`.
# - Stimulus: Launch a control symbol under downstream backpressure, mutate the
#   inputs while stalled, and separately hold `clkEn` low across a launch.
# - Checks: The encoder must hold its buffered output stable while stalled and
#   must not capture a new word while `clkEn` is low.
# - Timing: The bench samples the registered output one cycle after each
#   attempted launch.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.line_codes.line_code_test_utils import (
    ClockedLineCodeTB,
    run_line_code_entity_test,
)


@cocotb.test()
async def flow_control_hold_test(dut):
    tb = ClockedLineCodeTB(dut)
    await tb.reset()

    dut.readyOut.value = 0
    dut.dataIn.value = 0x07C
    dut.dataKIn.value = 1
    dut.validIn.value = 1
    await tb.cycle(1)
    dut.validIn.value = 0

    assert int(dut.validOut.value) == 1
    assert int(dut.readyIn.value) == 0
    held_word = int(dut.dataOut.value)

    dut.dataIn.value = 0x155
    dut.dataKIn.value = 0
    dut.validIn.value = 1
    await tb.cycle(2)
    dut.validIn.value = 0

    assert int(dut.validOut.value) == 1
    assert int(dut.dataOut.value) == held_word

    dut.readyOut.value = 1
    await tb.cycle(1)
    assert int(dut.validOut.value) == 0


@cocotb.test()
async def clk_enable_gates_update_test(dut):
    tb = ClockedLineCodeTB(dut)
    await tb.reset()

    dut.readyOut.value = 0
    dut.clkEn.value = 0
    dut.dataIn.value = 0x17C
    dut.dataKIn.value = 1
    dut.validIn.value = 1
    await tb.cycle(1)

    assert int(dut.validOut.value) == 0

    dut.clkEn.value = 1
    await tb.cycle(1)
    dut.validIn.value = 0

    assert int(dut.validOut.value) == 1


PARAMETER_SWEEP = [
    parameter_case(
        "sync_active_high",
        USE_CLK_EN_G="true",
        FLOW_CTRL_EN_G="true",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "async_active_low",
        USE_CLK_EN_G="true",
        FLOW_CTRL_EN_G="true",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Encoder10b12b(parameters):
    run_line_code_entity_test(
        test_file=__file__,
        toplevel="surf.encoder10b12b",
        parameters=parameters,
    )
