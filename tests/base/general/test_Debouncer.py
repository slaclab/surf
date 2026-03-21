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
# - Sweep: Sweep a baseline unsynchronized input case, a synchronized
#   inverted-output case, and an asynchronous active-low reset case so debounce
#   filtering is covered across the supported front-end options.
# - Stimulus: Apply short chatter bursts that should be ignored, then hold the
#   input stable beyond the debounce interval so the new level becomes eligible
#   to transfer.
# - Checks: Short chatter must never change the debounced output, a truly
#   stable level must update the output once, and reset must restore the idle
#   state.
# - Timing: The accepted transition is checked only after the full debounce
#   window elapses, and the synchronized-input case is expected to add the
#   extra capture latency from the front-end synchronizer.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import (
    build_vhdl_wrapper_source,
    env_flag,
    env_sl,
    generate_vhdl_wrapper,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.input_polarity = env_sl("INPUT_POLARITY_G", default=0)
        self.output_polarity = env_sl("OUTPUT_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.synchronize = env_flag("SYNCHRONIZE_G", default=True)
        self.edge_trigger = env_flag("SYNC_EDGE_TRIG_G", default=False)
        self.debounce_cycles = int(os.environ["DEBOUNCE_CYCLES"])
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.i.value = self.input_inactive_value()

        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def input_active_value(self) -> int:
        return self.input_polarity

    def input_inactive_value(self) -> int:
        return 1 - self.input_polarity

    def output_active_value(self) -> int:
        return self.output_polarity

    def output_inactive_value(self) -> int:
        return 1 - self.output_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()

    async def reset(self) -> None:
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(3)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(2)

    async def wait_for_stable_update(self) -> None:
        # Synchronized cases need a couple extra cycles for the input pipeline
        # before the debounce counter can even begin to see the stable level.
        await self.cycle(self.debounce_cycles + (2 if self.synchronize else 0) + 2)


@cocotb.test()
async def chatter_rejection_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A brief burst of chatter should not satisfy the full debounce interval.
    for _ in range(max(tb.debounce_cycles - 1, 1)):
        dut.i.value = tb.input_active_value()
        await tb.cycle(1)
        dut.i.value = tb.input_inactive_value()
        await tb.cycle(1)

    assert int(dut.o.value) == tb.output_inactive_value()


@cocotb.test()
async def stable_input_updates_output_test(dut):
    tb = TB(dut)
    await tb.reset()

    dut.i.value = tb.input_active_value()
    await tb.wait_for_stable_update()
    assert int(dut.o.value) == tb.output_active_value()

    dut.i.value = tb.input_inactive_value()
    await tb.wait_for_stable_update()
    assert int(dut.o.value) == tb.output_inactive_value()


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    dut.i.value = tb.input_active_value()
    await tb.wait_for_stable_update()
    assert int(dut.o.value) == tb.output_active_value()

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.o.value) == tb.output_inactive_value()
    else:
        await tb.cycle(1)
        assert int(dut.o.value) == tb.output_inactive_value()


PARAMETER_SWEEP = [
    parameter_case(
        "no_sync_baseline",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        INPUT_POLARITY_G="'1'",
        OUTPUT_POLARITY_G="'1'",
        SYNCHRONIZE_G="false",
        SYNC_EDGE_TRIG_G="false",
        DEBOUNCE_CYCLES_G="3",
        DEBOUNCE_CYCLES="3",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "synchronized_inverted_output",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        INPUT_POLARITY_G="'1'",
        OUTPUT_POLARITY_G="'0'",
        SYNCHRONIZE_G="true",
        SYNC_EDGE_TRIG_G="false",
        DEBOUNCE_CYCLES_G="4",
        DEBOUNCE_CYCLES="4",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_active_low_reset",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        INPUT_POLARITY_G="'0'",
        OUTPUT_POLARITY_G="'1'",
        SYNCHRONIZE_G="false",
        SYNC_EDGE_TRIG_G="false",
        DEBOUNCE_CYCLES_G="3",
        DEBOUNCE_CYCLES="3",
        CLK_PERIOD_NS="7",
    ),
]


def _debouncer_wrapper_source() -> str:
    return build_vhdl_wrapper_source(
        wrapper_name="DebouncerWrapper",
        wrapped_entity="Debouncer",
        generic_declarations=[
            "TPD_G             : time    := 1 ns",
            "RST_POLARITY_G    : sl      := '1'",
            "RST_ASYNC_G       : boolean := false",
            "INPUT_POLARITY_G  : sl      := '0'",
            "OUTPUT_POLARITY_G : sl      := '1'",
            "SYNCHRONIZE_G     : boolean := true",
            "SYNC_EDGE_TRIG_G  : boolean := false",
            "DEBOUNCE_CYCLES_G : positive := 3",
        ],
        port_declarations=[
            "clk : in  sl",
            "rst : in  sl := not RST_POLARITY_G",
            "i   : in  sl",
            "o   : out sl",
        ],
        generic_map=[
            "TPD_G             => TPD_G",
            "RST_POLARITY_G    => RST_POLARITY_G",
            "RST_ASYNC_G       => RST_ASYNC_G",
            "INPUT_POLARITY_G  => INPUT_POLARITY_G",
            "OUTPUT_POLARITY_G => OUTPUT_POLARITY_G",
            "CLK_FREQ_G        => 1.0",
            "DEBOUNCE_PERIOD_G => real(DEBOUNCE_CYCLES_G)",
            "SYNCHRONIZE_G     => SYNCHRONIZE_G",
            "SYNC_EDGE_TRIG_G  => SYNC_EDGE_TRIG_G",
        ],
        port_map=[
            "clk => clk",
            "rst => rst",
            "i   => i",
            "o   => o",
        ],
    )


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Debouncer(parameters):
    # Generate the shim locally so future real-generic leaves can reuse the
    # same path instead of adding another checked-in wrapper file.
    wrapper_path = generate_vhdl_wrapper(
        test_file=__file__,
        wrapper_name="DebouncerWrapper",
        source=_debouncer_wrapper_source(),
        parameters=parameters,
    )
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.debouncerwrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": [wrapper_path]},
    )
