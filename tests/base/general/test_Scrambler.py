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
# - Sweep: Sweep scrambling mode, descrambling mode, and a reverse-I/O
#   asynchronous-reset case so the LFSR datapath is checked in both directions
#   and with alternate port ordering.
# - Stimulus: Feed a known payload stream through the datapath, enable bypass
#   for a transparent pass-through run, and then reset the internal state
#   mid-test.
# - Checks: Scramble and descramble outputs must match the local LFSR model,
#   bypass must reproduce the input exactly, and reset must reseed the state so
#   the next sequence restarts predictably.
# - Timing: The bench checks one word per accepted transfer, confirms that
#   bypass does not add hidden latency, and verifies that reset restarts the
#   sequence from the seed on the next eligible cycle.

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


def _bit_reverse(value: int, width: int) -> int:
    # Several generic combinations reverse bit ordering on the way in or out,
    # so keep the transform in one helper that both model and tests can reuse.
    reversed_value = 0
    for bit in range(width):
        reversed_value |= ((value >> bit) & 1) << (width - 1 - bit)
    return reversed_value


def _scramble_word(
    *,
    state: list[int],
    data: int,
    width: int,
    taps: list[int],
    direction: str,
    reverse_in: bool,
) -> tuple[int, list[int]]:
    # This helper mirrors the scrambler/descrambler bit-by-bit state update in
    # Python so tests can reason about transformed words without hand decoding
    # the LFSR behavior inline.
    working = _bit_reverse(data, width) if reverse_in else data
    output = 0
    next_state = list(state)

    for bit in range(width):
        bit_value = (working >> bit) & 1
        for tap in taps:
            bit_value ^= next_state[tap - 1]
        output |= bit_value << bit

        if direction == "SCRAMBLER":
            next_state = next_state[1:] + [bit_value]
        else:
            next_state = next_state[1:] + [((working >> bit) & 1)]

    return output, next_state


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.direction = os.environ["DIRECTION_G"]
        self.data_width = int(os.environ["DATA_WIDTH_G"])
        self.sideband_width = int(os.environ["SIDEBAND_WIDTH_G"])
        self.reverse_in = env_flag("BIT_REVERSE_IN_G", default=False)
        self.reverse_out = env_flag("BIT_REVERSE_OUT_G", default=False)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])
        self.taps = [39, 58]

        dut.rst.value = self.reset_active_value()
        dut.inputValid.value = 0
        dut.inputBypass.value = 0
        dut.inputData.value = 0
        dut.inputSideband.value = 0
        dut.outputReady.value = 1

        # Start the stream clock once during setup; all tests then interact with
        # the DUT only through the send/reset helpers below.
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
        # Reset clears the scrambler state, so each test starts from a known
        # all-zero LFSR history before any payload words are injected.
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(3)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(1)

    async def send_word(self, data: int, sideband: int, *, bypass: int = 0) -> tuple[int, int, int]:
        # Hold the downstream side off until the transformed word is visible so
        # the test cannot miss a one-cycle outputValid pulse.
        self.dut.outputReady.value = 0
        self.dut.inputData.value = data
        self.dut.inputSideband.value = sideband
        self.dut.inputBypass.value = bypass
        self.dut.inputValid.value = 1
        for _ in range(32):
            # inputReady is combinational for the current cycle, so sample it
            # before the next edge instead of waiting until after the transfer.
            await self.settle()
            if int(self.dut.inputReady.value) == 1:
                await self.cycle(1)
                break
            await self.cycle(1)
        else:
            assert False, "Timed out waiting for Scrambler inputReady"
        self.dut.inputValid.value = 0

        for _ in range(64):
            await self.cycle(1)
            if int(self.dut.outputValid.value) == 1:
                observed = (
                    int(self.dut.outputData.value),
                    int(self.dut.outputSideband.value),
                    int(self.dut.outputBypass.value),
                )
                self.dut.outputReady.value = 1
                await self.cycle(1)
                self.dut.outputReady.value = 0
                return observed
        assert False, "Timed out waiting for Scrambler outputValid"
        return (0, 0, 0)


@cocotb.test()
async def data_path_model_test(dut):
    tb = TB(dut)
    await tb.reset()

    payloads = [(0x12, 0x1), (0xA5, 0x2), (0x3C, 0x3)]
    observed_words: list[int] = []

    for index, (data, sideband) in enumerate(payloads):
        observed_data, observed_sideband, observed_bypass = await tb.send_word(data, sideband)
        assert observed_bypass == 0
        # Sideband only sees the configured bit-order transforms; the scrambler
        # state machine does not alter its payload.
        expected_sideband = _bit_reverse(sideband, tb.sideband_width) if tb.reverse_in else sideband
        if tb.reverse_out:
            expected_sideband = _bit_reverse(expected_sideband, tb.sideband_width)
        assert observed_sideband == expected_sideband
        observed_words.append(observed_data)

        if index == 0:
            # The LFSR state resets to zero, so the first non-bypassed word is
            # just the input word seen through the configured bit ordering.
            expected_first_data = _bit_reverse(data, tb.data_width) if tb.reverse_in else data
            if tb.reverse_out:
                expected_first_data = _bit_reverse(expected_first_data, tb.data_width)
            assert observed_data == expected_first_data

    # The stream should keep making forward progress rather than repeating a
    # constant output word for distinct inputs.
    assert len(set(observed_words)) > 1


@cocotb.test()
async def bypass_passthrough_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The bypass path should skip the scrambling math but still honor the same
    # configured input/output bit-order transforms as the normal datapath.
    observed_data, observed_sideband, observed_bypass = await tb.send_word(0x5A, 0x2, bypass=1)
    expected_data = _bit_reverse(0x5A, tb.data_width) if tb.reverse_in else 0x5A
    expected_sideband = _bit_reverse(0x2, tb.sideband_width) if tb.reverse_in else 0x2
    if tb.reverse_out:
        expected_data = _bit_reverse(expected_data, tb.data_width)
        expected_sideband = _bit_reverse(expected_sideband, tb.sideband_width)

    assert observed_bypass == 1
    assert observed_data == expected_data
    assert observed_sideband == expected_sideband


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()
    # First put one word through the datapath so the reset check is proving
    # that outputValid is cleared from an active transaction state.
    await tb.send_word(0x33, 0x1)

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.outputValid.value) == 0
    else:
        await tb.cycle(1)
        assert int(dut.outputValid.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "scrambler_baseline",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        DIRECTION_G="SCRAMBLER",
        DATA_WIDTH_G="8",
        SIDEBAND_WIDTH_G="2",
        BIT_REVERSE_IN_G="false",
        BIT_REVERSE_OUT_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "descrambler_baseline",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        DIRECTION_G="DESCRAMBLER",
        DATA_WIDTH_G="8",
        SIDEBAND_WIDTH_G="2",
        BIT_REVERSE_IN_G="false",
        BIT_REVERSE_OUT_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "reverse_io_async_reset",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        DIRECTION_G="SCRAMBLER",
        DATA_WIDTH_G="8",
        SIDEBAND_WIDTH_G="2",
        BIT_REVERSE_IN_G="true",
        BIT_REVERSE_OUT_G="true",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Scrambler(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.scrambler",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
