##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test


def _env_flag(name: str, *, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default

    normalized = raw.strip().strip("'").lower()
    if normalized in {"1", "true"}:
        return True
    if normalized in {"0", "false"}:
        return False
    raise ValueError(f"Unsupported boolean environment value for {name}: {raw}")


def _env_sl(name: str, *, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None:
        return default

    normalized = raw.strip().strip("'")
    if normalized in {"0", "1"}:
        return int(normalized)
    raise ValueError(f"Unsupported std_logic environment value for {name}: {raw}")


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])
        self.rst_polarity = _env_sl("RST_POLARITY_G", default=1)
        self.out_polarity = _env_sl("OUT_POLARITY_G", default=1)
        self.async_reset = _env_flag("RST_ASYNC_G", default=False)
        self.bypass_enabled = _env_flag("BYPASS_SYNC_G", default=False)
        self.stages = int(os.environ["STAGES_G"])

        dut.dataIn.value = 0
        dut.rst.value = self.reset_active_value()

        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def expected_output(self, data_in: int) -> int:
        return data_in if self.out_polarity == 1 else 1 - data_in

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
            await self.cycle(4)
        else:
            await self.cycle(4)

        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(2)

    async def drive_and_expect_after_latency(self, value: int) -> None:
        previous_output = int(self.dut.dataOut.value)
        self.dut.dataIn.value = value
        await self.settle()

        for _ in range(self.stages - 1):
            await RisingEdge(self.dut.clk)
            await self.settle()
            assert int(self.dut.dataOut.value) == previous_output

        await RisingEdge(self.dut.clk)
        await self.settle()
        assert int(self.dut.dataOut.value) == self.expected_output(value)


@cocotb.test()
async def propagation_latency_test(dut):
    tb = TB(dut)
    if tb.bypass_enabled:
        return

    await tb.reset()

    assert int(dut.dataOut.value) == tb.expected_output(0)

    await tb.drive_and_expect_after_latency(1)
    await tb.drive_and_expect_after_latency(0)


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    if tb.bypass_enabled:
        return

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
        assert int(dut.dataOut.value) == tb.expected_output(0)
    else:
        assert int(dut.dataOut.value) == tb.expected_output(1)
        await tb.cycle(1)
        assert int(dut.dataOut.value) == tb.expected_output(0)

    dut.rst.value = tb.reset_inactive_value()
    await tb.cycle(tb.stages)
    assert int(dut.dataOut.value) == tb.expected_output(1)


@cocotb.test()
async def bypass_mode_test(dut):
    tb = TB(dut)
    if not tb.bypass_enabled:
        return

    dut.rst.value = tb.reset_inactive_value()
    for value in (0, 1, 0, 1):
        dut.dataIn.value = value
        await tb.settle()
        assert int(dut.dataOut.value) == tb.expected_output(value)

    dut.rst.value = tb.reset_active_value()
    await tb.settle()
    assert int(dut.dataOut.value) == tb.expected_output(1)

    dut.dataIn.value = 0
    await tb.settle()
    assert int(dut.dataOut.value) == tb.expected_output(0)


def _case(case_id: str, **parameters):
    return pytest.param(parameters, id=case_id)


PARAMETER_SWEEP = [
    # This matrix covers the behavior-changing generics for the leaf module
    # without spending runtime on timing-only TPD_G or custom INIT_G values.
    _case(
        "sync_stage2_baseline",
        STAGES_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    _case(
        "sync_stage4_baseline",
        STAGES_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    _case(
        "async_reset_stage3",
        STAGES_G="3",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    _case(
        "active_low_reset",
        STAGES_G="3",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    _case(
        "inverted_output",
        STAGES_G="3",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'0'",
        BYPASS_SYNC_G="false",
        CLK_PERIOD_NS="5",
    ),
    _case(
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
    hdl_parameters = {
        key: value
        for key, value in parameters.items()
        if key.endswith("_G")
    }

    runtime_env = {
        key: value
        for key, value in parameters.items()
        if not key.endswith("_G")
    }

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synchronizer",
        parameters=hdl_parameters,
        extra_env={**hdl_parameters, **runtime_env},
    )
