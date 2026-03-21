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
# - Sweep: Sweep stage counts `2` and `4`, an asynchronous-reset stage-3 case,
#   active-low reset, inverted output, and bypass with inversion so the scalar
#   synchronizer is covered across its major options.
# - Stimulus: Toggle the source input, assert reset, and run a bypass
#   configuration so each feature changes the observed destination value at
#   least once.
# - Checks: The destination output must appear after the configured
#   synchronizer depth, reset must drive the expected idle value, inversion
#   must flip the sense, and bypass must short-circuit the latency.
# - Timing: The bench counts exact destination-clock latency through the
#   synchronizer chain and distinguishes bypass and asynchronous reset from the
#   normal staged path.

import cocotb
import pytest
from cocotb.triggers import FallingEdge, Timer

from tests.base.sync.sync_test_utils import SynchronizerLikeTB
from tests.common.regression_utils import (
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


@cocotb.test()
async def propagation_latency_test(dut):
    # Each `@cocotb.test()` function is an async coroutine. cocotb starts it,
    # gives it the HDL `dut`, and advances simulation time whenever we `await`.
    tb = SynchronizerLikeTB(dut, width=1)
    if tb.bypass_enabled:
        # The bypass case has different behavior and is covered by its own test.
        return

    await tb.reset()

    # After reset, the synchronizer should present the reset/default value.
    assert int(dut.dataOut.value) == tb.expected_output(0)

    # Drive a 0->1 transition, then a 1->0 transition, and let the shared
    # helper verify the configured stage latency each time.
    await tb.drive_and_expect_after_latency(1)
    await tb.drive_and_expect_after_latency(0)


@cocotb.test()
async def reset_behavior_test(dut):
    tb = SynchronizerLikeTB(dut, width=1)
    if tb.bypass_enabled:
        return

    # First prove the DUT can leave reset and pass a non-default value through.
    await tb.reset()
    await tb.drive_and_expect_after_latency(1)
    assert int(dut.dataOut.value) == tb.expected_output(1)

    # Assert reset away from a rising edge so the test can distinguish the
    # asynchronous reset path from the synchronous one.
    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        # Async reset should take effect immediately, without waiting for the
        # next rising edge.
        assert int(dut.dataOut.value) == tb.expected_output(0)
    else:
        # Sync reset should not take effect until a clock edge arrives.
        assert int(dut.dataOut.value) == tb.expected_output(1)
        await tb.cycle(1)
        assert int(dut.dataOut.value) == tb.expected_output(0)

    # After releasing reset, the previously held input should propagate back
    # through the configured number of stages.
    dut.rst.value = tb.reset_inactive_value()
    await tb.cycle(tb.stages)
    assert int(dut.dataOut.value) == tb.expected_output(1)


@cocotb.test()
async def bypass_mode_test(dut):
    tb = SynchronizerLikeTB(dut, width=1)
    if not tb.bypass_enabled:
        return

    # In bypass mode, the DUT is combinational from input to output, so no
    # clock edge is needed to observe each new value.
    dut.rst.value = tb.reset_inactive_value()
    for value in (0, 1, 0, 1):
        dut.dataIn.value = value
        await tb.settle()
        assert int(dut.dataOut.value) == tb.expected_output(value)

    # Reset should not add sequential latency in bypass mode; the output still
    # simply reflects the current input with optional polarity inversion.
    dut.rst.value = tb.reset_active_value()
    await tb.settle()
    assert int(dut.dataOut.value) == tb.expected_output(1)

    dut.dataIn.value = 0
    await tb.settle()
    assert int(dut.dataOut.value) == tb.expected_output(0)


PARAMETER_SWEEP = [
    # This matrix covers the behavior-changing generics for the leaf module
    # without spending runtime on timing-only TPD_G or custom INIT_G values.
    parameter_case(
        "sync_stage2_baseline",
        STAGES_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "sync_stage4_baseline",
        STAGES_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_reset_stage3",
        STAGES_G="3",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_reset",
        STAGES_G="3",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "inverted_output",
        STAGES_G="3",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'0'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "bypass_inverted_output",
        STAGES_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'0'",
        BYPASS_SYNC_G="true",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Synchronizer(parameters):
    # pytest expands this into one simulator run per parameter set. The helper
    # keeps HDL generics (`*_G`) separate from runtime-only environment values
    # such as the cocotb clock period.
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synchronizer",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
