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
# - Sweep: Cover one- and two-byte encoder configurations plus an async
#   active-low reset case while keeping `FLOW_CTRL_EN_G=true`.
# - Stimulus: Launch a symbol under downstream backpressure, mutate inputs
#   while stalled, and separately hold `clkEn` low across a launch attempt.
# - Checks: The encoder must hold its current output stable while stalled and
#   must not capture a new word until `clkEn` is re-enabled.
# - Timing: The bench checks the registered output one cycle after each launch
#   and then watches it remain stable across subsequent stalled cycles.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.line_codes.line_code_test_utils import (
    ClockedLineCodeTB,
    run_line_code_entity_test,
)


def _stimulus_for_width(width: int) -> tuple[int, int, int, int]:
    if width == 1:
        return 0xBC, 0x1, 0x4A, 0x0
    return 0xBC4A, 0x2, 0x1C55, 0x1


@cocotb.test()
async def flow_control_hold_test(dut):
    tb = ClockedLineCodeTB(dut)
    await tb.reset()

    width = int(dut.NUM_BYTES_G.value)
    first_data, first_k, second_data, second_k = _stimulus_for_width(width)

    dut.readyOut.value = 0
    dut.dataIn.value = first_data
    dut.dataKIn.value = first_k
    dut.validIn.value = 1
    await tb.cycle(1)
    dut.validIn.value = 0

    assert int(dut.validOut.value) == 1
    assert int(dut.readyIn.value) == 0
    held_word = int(dut.dataOut.value)

    # Once the encoder has a buffered output under backpressure, later inputs
    # must not overwrite the held word until the downstream side accepts it.
    dut.dataIn.value = second_data
    dut.dataKIn.value = second_k
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

    width = int(dut.NUM_BYTES_G.value)
    first_data, first_k, _, _ = _stimulus_for_width(width)

    dut.readyOut.value = 0
    dut.clkEn.value = 0
    dut.dataIn.value = first_data
    dut.dataKIn.value = first_k
    dut.validIn.value = 1
    await tb.cycle(1)

    assert int(dut.validOut.value) == 0

    dut.clkEn.value = 1
    await tb.cycle(1)
    dut.validIn.value = 0

    assert int(dut.validOut.value) == 1


PARAMETER_SWEEP = [
    parameter_case(
        "single_byte_sync",
        NUM_BYTES_G="1",
        FLOW_CTRL_EN_G="true",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "dual_byte_sync",
        NUM_BYTES_G="2",
        FLOW_CTRL_EN_G="true",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "dual_byte_async_active_low",
        NUM_BYTES_G="2",
        FLOW_CTRL_EN_G="true",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Encoder8b10b(parameters):
    run_line_code_entity_test(
        test_file=__file__,
        toplevel="surf.encoder8b10b",
        parameters=parameters,
    )
