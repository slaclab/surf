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
# - Sweep: Cover internal-disparity and debug-disparity modes, plus an async
#   active-low reset case, while keeping `FLOW_CTRL_EN_G=true`.
# - Stimulus: Launch a control symbol under backpressure, then compare the same
#   symbol under two disparity seeds after reset.
# - Checks: The encoder must hold its buffered word stable while stalled, and
#   `DEBUG_DISP_G` must make the external `dispIn` visible whereas the normal
#   internal-disparity path must ignore it after reset.
# - Timing: The bench samples the registered output one cycle after each
#   launch and compares post-reset captures across separate runs.

import cocotb
import pytest

from tests.common.regression_utils import env_flag, parameter_case
from tests.protocols.line_codes.line_code_test_utils import (
    ClockedLineCodeTB,
    run_line_code_entity_test,
)


CANDIDATE_DEBUG_SYMBOLS = [
    (0x000, 0),
    (0x0BD, 0),
    (0x5F8, 1),
    (0x078, 1),
]


@cocotb.test()
async def flow_control_hold_test(dut):
    tb = ClockedLineCodeTB(dut)
    await tb.reset()

    dut.readyOut.value = 0
    dut.dispIn.value = 0b00
    dut.dataIn.value = 0x5F8
    dut.dataKIn.value = 1
    dut.validIn.value = 1
    await tb.cycle(1)
    dut.validIn.value = 0

    assert int(dut.validOut.value) == 1
    assert int(dut.readyIn.value) == 0
    held_word = int(dut.dataOut.value)

    dut.dispIn.value = 0b10
    dut.dataIn.value = 0x0BD
    dut.dataKIn.value = 0
    dut.validIn.value = 1
    await tb.cycle(2)
    dut.validIn.value = 0

    assert int(dut.validOut.value) == 1
    assert int(dut.dataOut.value) == held_word


@cocotb.test()
async def debug_disparity_selection_test(dut):
    debug_disp = env_flag("DEBUG_DISP_G", default=False)
    tb = ClockedLineCodeTB(dut)
    differences = []

    for data_in, data_k_in in CANDIDATE_DEBUG_SYMBOLS:
        await tb.reset()
        dut.readyOut.value = 0
        dut.dispIn.value = 0b00
        dut.dataIn.value = data_in
        dut.dataKIn.value = data_k_in
        dut.validIn.value = 1
        await tb.cycle(1)
        dut.validIn.value = 0
        first = (int(dut.dataOut.value), int(dut.dispOut.value))

        await tb.reset()
        dut.readyOut.value = 0
        dut.dispIn.value = 0b10
        dut.dataIn.value = data_in
        dut.dataKIn.value = data_k_in
        dut.validIn.value = 1
        await tb.cycle(1)
        dut.validIn.value = 0
        second = (int(dut.dataOut.value), int(dut.dispOut.value))

        differences.append(first != second)

    if debug_disp:
        assert any(differences)
    else:
        assert not any(differences)


PARAMETER_SWEEP = [
    parameter_case(
        "internal_disparity_sync",
        DEBUG_DISP_G="false",
        FLOW_CTRL_EN_G="true",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "external_disparity_sync",
        DEBUG_DISP_G="true",
        FLOW_CTRL_EN_G="true",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "external_disparity_async_active_low",
        DEBUG_DISP_G="true",
        FLOW_CTRL_EN_G="true",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Encoder12b14b(parameters):
    run_line_code_entity_test(
        test_file=__file__,
        toplevel="surf.encoder12b14b",
        parameters=parameters,
    )
