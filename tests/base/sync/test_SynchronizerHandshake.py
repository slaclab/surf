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
# - Sweep: Cover asynchronous and common clocks, internal and external
#   destination acknowledgment, synchronous and asynchronous resets, both
#   reset polarities, and two vector widths.
# - Stimulus: Launch several back-to-back source transfers, change srcData
#   immediately after launch, delay external acknowledgments to apply
#   backpressure, and reset both domains during an in-flight transfer.
# - Checks: Every destination request must carry the value present at launch,
#   external requests and data must remain stable during backpressure, internal
#   requests must be one destination cycle wide, and the full source receive
#   handshake must return to idle before another transfer.
# - Timing: Clocks use unrelated periods in CDC cases. All progress waits are
#   bounded while allowing the configured request and acknowledgment
#   synchronizer latency in each direction.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    env_flag,
    env_sl,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.common_clk = env_flag("COMMON_CLK_G", default=False)
        self.ext_handshake = env_flag("DEST_EXT_HSK_G", default=True)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.data_width = int(os.environ["DATA_WIDTH_G"])
        self.src_period_ns = float(os.environ["SRC_CLK_PERIOD_NS"])
        self.dest_period_ns = float(os.environ["DEST_CLK_PERIOD_NS"])
        self.data_mask = (1 << self.data_width) - 1

        dut.srcRst.value = self.reset_active_value()
        dut.destRst.value = self.reset_active_value()
        dut.srcData.value = 0
        dut.srcSend.value = 0
        dut.destAck.value = 0

        if self.common_clk:
            start_lockstep_clocks(
                dut.srcClk,
                dut.destClk,
                period_ns=self.src_period_ns,
            )
        else:
            cocotb.start_soon(Clock(dut.srcClk, self.src_period_ns, unit="ns").start())
            cocotb.start_soon(Clock(dut.destClk, self.dest_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle_src(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.srcClk)
            await self.settle()

    async def cycle_dest(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.destClk)
            await self.settle()

    async def wait_src(self, signal, value: int, cycles: int = 80) -> None:
        for _ in range(cycles):
            await self.cycle_src()
            if int(signal.value) == value:
                return
        assert int(signal.value) == value

    async def wait_dest(self, signal, value: int, cycles: int = 80) -> None:
        for _ in range(cycles):
            await self.cycle_dest()
            if int(signal.value) == value:
                return
        assert int(signal.value) == value

    async def reset(self) -> None:
        self.dut.srcRst.value = self.reset_active_value()
        self.dut.destRst.value = self.reset_active_value()
        self.dut.srcSend.value = 0
        self.dut.destAck.value = 0

        if self.async_reset:
            await self.settle()

        await self.cycle_src(3)
        await self.cycle_dest(3)

        assert int(self.dut.srcRcv.value) == 0
        assert int(self.dut.destReq.value) == 0
        assert int(self.dut.destData.value) == 0

        self.dut.srcRst.value = self.reset_inactive_value()
        self.dut.destRst.value = self.reset_inactive_value()
        await self.cycle_src(2)
        await self.cycle_dest(2)

    async def transfer(self, value: int, *, backpressure_cycles: int = 0) -> None:
        expected = value & self.data_mask

        # Launch on srcClk. The source-side holding register must preserve this
        # value even though srcData changes while the handshake is in flight.
        self.dut.srcData.value = expected
        self.dut.srcSend.value = 1
        await self.cycle_src()
        self.dut.srcData.value = expected ^ self.data_mask

        await self.wait_dest(self.dut.destReq, 1)
        assert int(self.dut.destData.value) == expected

        if self.ext_handshake:
            # External mode holds request and data until the consumer accepts
            # the word, providing destination-side backpressure.
            for _ in range(backpressure_cycles):
                await self.cycle_dest()
                assert int(self.dut.destReq.value) == 1
                assert int(self.dut.destData.value) == expected
                assert int(self.dut.srcRcv.value) == 0

            self.dut.destAck.value = 1
        else:
            # Internal mode acknowledges immediately and advertises the data
            # for exactly one destination clock cycle.
            await self.cycle_dest()
            assert int(self.dut.destReq.value) == 0

        await self.wait_src(self.dut.srcRcv, 1)
        self.dut.srcSend.value = 0

        if self.ext_handshake:
            await self.wait_dest(self.dut.destReq, 0)
            self.dut.destAck.value = 0

        await self.wait_src(self.dut.srcRcv, 0)


@cocotb.test()
async def coherent_back_to_back_transfer_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Different bit patterns make torn or stale destination words obvious.
    values = [0x15, 0x2A, 0x33, 0x01]
    for index, value in enumerate(values):
        await tb.transfer(value, backpressure_cycles=index + 1)


@cocotb.test()
async def coordinated_reset_aborts_transfer_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Start a transfer and wait until it is visible in the destination domain,
    # then reset both sides before the full handshake can complete.
    tb.dut.srcData.value = 0x2D & tb.data_mask
    tb.dut.srcSend.value = 1
    await tb.cycle_src()
    await tb.wait_dest(tb.dut.destReq, 1)

    tb.dut.srcRst.value = tb.reset_active_value()
    tb.dut.destRst.value = tb.reset_active_value()
    tb.dut.srcSend.value = 0
    tb.dut.destAck.value = 0

    if tb.async_reset:
        await tb.settle()
    await tb.cycle_src(2)
    await tb.cycle_dest(2)

    assert int(tb.dut.srcRcv.value) == 0
    assert int(tb.dut.destReq.value) == 0
    assert int(tb.dut.destData.value) == 0

    tb.dut.srcRst.value = tb.reset_inactive_value()
    tb.dut.destRst.value = tb.reset_inactive_value()
    await tb.cycle_src(2)
    await tb.cycle_dest(2)

    # A clean transfer after reset proves both four-phase state machines
    # returned to idle rather than preserving a half-completed request.
    await tb.transfer(0x12, backpressure_cycles=2)


@cocotb.test()
async def early_src_send_deassertion_recovers_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Violate the full-handshake source contract deliberately. The RTL emits a
    # simulation warning, but its internal holding register must still preserve
    # the launched word and allow the four-phase state machines to return idle.
    expected = 0x1B & tb.data_mask
    tb.dut.srcData.value = expected
    tb.dut.srcSend.value = 1
    await tb.cycle_src()
    tb.dut.srcSend.value = 0
    tb.dut.srcData.value = expected ^ tb.data_mask

    await tb.wait_dest(tb.dut.destReq, 1)
    assert int(tb.dut.destData.value) == expected

    if tb.ext_handshake:
        tb.dut.destAck.value = 1

    await tb.wait_src(tb.dut.srcRcv, 1)

    if tb.ext_handshake:
        await tb.wait_dest(tb.dut.destReq, 0)
        tb.dut.destAck.value = 0

    await tb.wait_src(tb.dut.srcRcv, 0)

    # A subsequent legal transfer proves the violation did not leave either
    # side wedged or accidentally consume the next transaction.
    await tb.transfer(0x24, backpressure_cycles=1)


PARAMETER_SWEEP = [
    parameter_case(
        "async_external",
        RST_POLARITY_G="'1'",
        RST_ASYNC_G="false",
        COMMON_CLK_G="false",
        SRC_SYNC_STAGES_G="2",
        DEST_SYNC_STAGES_G="3",
        DEST_EXT_HSK_G="true",
        DATA_WIDTH_G="8",
        SRC_CLK_PERIOD_NS="5",
        DEST_CLK_PERIOD_NS="7",
    ),
    parameter_case(
        "async_internal_active_low_reset",
        RST_POLARITY_G="'0'",
        RST_ASYNC_G="true",
        COMMON_CLK_G="false",
        SRC_SYNC_STAGES_G="3",
        DEST_SYNC_STAGES_G="2",
        DEST_EXT_HSK_G="false",
        DATA_WIDTH_G="6",
        SRC_CLK_PERIOD_NS="7",
        DEST_CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "common_clock_external",
        RST_POLARITY_G="'1'",
        RST_ASYNC_G="false",
        COMMON_CLK_G="true",
        SRC_SYNC_STAGES_G="2",
        DEST_SYNC_STAGES_G="2",
        DEST_EXT_HSK_G="true",
        DATA_WIDTH_G="8",
        SRC_CLK_PERIOD_NS="5",
        DEST_CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SynchronizerHandshake(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synchronizerhandshake",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
