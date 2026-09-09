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
# - Sweep: Sweep vector widths `4` and `8`, synchronizer depths `2` and `4`, an
#   asynchronous-reset stage-3 case, active-low reset, inverted output, and
#   bypass with inversion.
# - Stimulus: Drive changing source bit patterns, assert reset, and run bypass
#   and inversion cases so each vector option is visible at the output.
# - Checks: Each bit must propagate with the expected latency, reset must drive
#   the configured idle vector, inversion must flip each bit, and bypass must
#   remove the staged delay.
# - Timing: The bench measures vector update latency in destination-clock
#   cycles and confirms that all bits share the configured latency unless the
#   bypass path is selected.

import os

import cocotb
import pytest
from cocotb.triggers import FallingEdge, Timer

from tests.base.sync.sync_test_utils import SynchronizerLikeTB
from tests.common.regression_utils import (
    env_flag,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


@cocotb.test(skip=env_flag("BYPASS_SYNC_G", default=False))
async def propagation_latency_test(dut):
    # This test is structurally the same as the scalar synchronizer test; the
    # difference is that the data path now carries a whole vector at once.
    tb = SynchronizerLikeTB(dut, width=int(os.environ["WIDTH_G"]))
    await tb.reset()
    assert int(dut.dataOut.value) == tb.expected_output(0)

    # Use two different bit patterns so the test proves every lane is moving
    # through the vector synchronizer together.
    await tb.drive_and_expect_after_latency(0b101010 & tb.mask)
    await tb.drive_and_expect_after_latency(0b010101 & tb.mask)


@cocotb.test(skip=env_flag("BYPASS_SYNC_G", default=False))
async def reset_behavior_test(dut):
    tb = SynchronizerLikeTB(dut, width=int(os.environ["WIDTH_G"]))
    # Fill every bit with 1s so reset behavior is obvious on the output.
    await tb.reset()
    await tb.drive_and_expect_after_latency(tb.mask)
    assert int(dut.dataOut.value) == tb.expected_output(tb.mask)

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        # Async reset clears the pipeline immediately.
        assert int(dut.dataOut.value) == tb.expected_output(0)
    else:
        # Sync reset waits for the next clock edge before clearing.
        assert int(dut.dataOut.value) == tb.expected_output(tb.mask)
        await tb.cycle(1)
        assert int(dut.dataOut.value) == tb.expected_output(0)

    # Releasing reset should let the held all-ones input flow back through the
    # pipeline after the configured latency.
    dut.rst.value = tb.reset_inactive_value()
    await tb.cycle(tb.stages)
    assert int(dut.dataOut.value) == tb.expected_output(tb.mask)


@cocotb.test(skip=not env_flag("BYPASS_SYNC_G", default=False))
async def bypass_mode_test(dut):
    tb = SynchronizerLikeTB(dut, width=int(os.environ["WIDTH_G"]))
    # In bypass mode, just sample a few representative vector values directly.
    dut.rst.value = tb.reset_inactive_value()
    for value in (0, 0b101001 & tb.mask, tb.mask):
        dut.dataIn.value = value
        await tb.settle()
        assert int(dut.dataOut.value) == tb.expected_output(value)


PARAMETER_SWEEP = [
    parameter_case(
        "width4_stage2",
        WIDTH_G="4",
        STAGES_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "width8_stage4",
        WIDTH_G="8",
        STAGES_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_reset_stage3",
        WIDTH_G="6",
        STAGES_G="3",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_reset",
        WIDTH_G="5",
        STAGES_G="3",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "inverted_output",
        WIDTH_G="7",
        STAGES_G="3",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'0'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "bypass_inverted_output",
        WIDTH_G="7",
        STAGES_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'0'",
        BYPASS_SYNC_G="true",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SynchronizerVector(parameters):
    # Each parameter set becomes a separate cocotb simulation, which keeps the
    # expectations simple and avoids one huge stateful mega-test.
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synchronizervector",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
