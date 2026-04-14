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
# - Sweep: Sweep request vector sizes `4` and `5` and include an asynchronous
#   active-low reset case so the round-robin logic is exercised beyond a single
#   fixed width.
# - Stimulus: Present competing request patterns, keep the current requester
#   asserted to exercise hold behavior, and then rotate the contenders.
# - Checks: The grant must rotate in round-robin order, the hold case must keep
#   serving the same requester, and reset must clear the selection history.
# - Timing: Grant updates are checked on arbitration boundaries only, and the
#   pointer must not advance during cycles where the design is expected to hold
#   the current request.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import (
    env_flag,
    env_sl,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


def _priority_encode(req: int, width: int, pivot: int) -> int:
    # The DUT rotates priority after the last granted requester. Mirror that in
    # software so the expected winner is derived from the active request mask.
    bits = [(req >> i) & 1 for i in range(width)]
    rotated = [bits[(i + pivot) % width] for i in range(width)]
    best = 0
    for index in reversed(range(width)):
        if rotated[index]:
            best = index
    return (best + pivot) % width


def _expected_ack(selected: int) -> int:
    return 1 << selected


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.req_size = int(os.environ["REQ_SIZE_G"])
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])
        self.last_selected = 0

        dut.rst.value = self.reset_active_value()
        dut.req.value = 0

        # The arbiter is entirely clocked, so a single testbench clock drives
        # all cases once construction is complete.
        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()

    async def reset(self) -> None:
        # Reset also clears the "last selected" software tracker so the Python
        # expectation model starts from the same pivot as the DUT.
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(2)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(1)
        self.last_selected = 0

    async def drive_and_check(self, req: int) -> None:
        # Apply one request vector, advance one arbitration cycle, and then
        # compare the externally visible grant against the software model.
        self.dut.req.value = req
        await self.cycle(1)

        if req == 0:
            assert int(self.dut.valid.value) == 0
            assert int(self.dut.ack.value) == 0
            return

        expected_selected = _priority_encode(
            req=req,
            width=self.req_size,
            pivot=(self.last_selected + 1) % self.req_size,
        )
        assert int(self.dut.valid.value) == 1
        assert int(self.dut.selected.value) == expected_selected
        assert int(self.dut.ack.value) == _expected_ack(expected_selected)
        self.last_selected = expected_selected


@cocotb.test()
async def round_robin_selection_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Releasing the current requester should advance grant priority so the next
    # waiting requester gets the turn.
    await tb.drive_and_check(0b1110)
    await tb.drive_and_check(0b1100)
    await tb.drive_and_check(0b1000)
    await tb.drive_and_check(0b0011)


@cocotb.test()
async def hold_current_request_test(dut):
    tb = TB(dut)
    await tb.reset()

    # If the winning requester never drops out, round-robin arbitration should
    # not change the grant underneath an unchanged request vector.
    await tb.drive_and_check(0b0101)
    selected = int(dut.selected.value)
    ack = int(dut.ack.value)
    tb.dut.req.value = 0b0101
    await tb.cycle(1)
    assert int(dut.selected.value) == selected
    assert int(dut.ack.value) == ack


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.drive_and_check(0b0110)

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.valid.value) == 0
    else:
        await tb.cycle(1)
        assert int(dut.valid.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "size4_baseline",
        REQ_SIZE_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "size5_baseline",
        REQ_SIZE_G="5",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_active_low_reset",
        REQ_SIZE_G="4",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Arbiter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.arbiter",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
