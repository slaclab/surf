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
# - Sweep: EVEN and ODD parity with 8-bit data and BAUD_MULT_G=16, EVEN parity
#   with 7-bit data and BAUD_MULT_G=8, and a NONE-parity control.
# - Stimulus: Drive start, LSB-first data, optional parity, and stop bits
#   directly on rx (without UartTx). The appended parity bit comes from an
#   independent Python ones count; each word is sent with matching parity and
#   then with an inverted parity bit.
# - Checks: rdValid and exact rdData for every frame; parityError is clear for
#   matching parity and set for inverted parity, holds with rdReady low, and
#   clears with rdValid on the rdReady handshake.
# - Timing: 100 MHz clock, one baudClkEn pulse every four clocks, so one bit
#   lasts 4 * BAUD_MULT_G clocks. Outputs are sampled 2 ns after each edge,
#   past the default 1 ns TPD_G. Framing errors and reset during a frame are
#   not covered.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import (
    env_int,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    sample_after_tpd,
)

CLK_PERIOD_NS = 10
# Sample strictly after the 1 ns TPD_G register update; sampling at exactly
# 1 ns races the update in GHDL.
SAMPLE_DELAY_NS = 2.0
BAUD_EN_DIVIDE = 4
DATA_WORDS = (0x00, 0x01, 0x55, 0xA7, 0xFF, 0x80)


def expected_parity_bit(data, mode):
    # Standard UART parity: EVEN makes the total ones count (data + parity)
    # even, ODD makes it odd.
    ones = bin(data).count("1") & 1
    return ones if mode == "EVEN" else ones ^ 1


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.data_width = env_int("DATA_WIDTH_G", default=8)
        self.bit_clocks = BAUD_EN_DIVIDE * env_int("BAUD_MULT_G", default=16)

        # Initialize every bench-driven input before the first clock edge.
        dut.rst.setimmediatevalue(1)
        dut.rx.setimmediatevalue(1)
        dut.baudClkEn.setimmediatevalue(0)
        dut.rdReady.setimmediatevalue(0)

        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
        self._baud_task = cocotb.start_soon(self._drive_baud_enable())

    async def _drive_baud_enable(self):
        """Lifetime agent: one baudClkEn pulse every BAUD_EN_DIVIDE clocks."""
        count = 0
        while True:
            await RisingEdge(self.dut.clk)
            self.dut.baudClkEn.value = int(count == 0)
            count = (count + 1) % BAUD_EN_DIVIDE

    async def clocks(self, count):
        for _ in range(count):
            await RisingEdge(self.dut.clk)

    async def reset(self):
        await self.clocks(8)
        self.dut.rst.value = 0
        # Let the rx synchronizer settle on the idle-high line.
        await self.clocks(self.bit_clocks)

    async def send_frame(self, bits):
        for bit in bits:
            self.dut.rx.value = bit
            await self.clocks(self.bit_clocks)

    async def wait_valid(self, context):
        for _ in range(2 * self.bit_clocks):
            await sample_after_tpd(self.dut.clk, propagation_time=SAMPLE_DELAY_NS)
            if int(self.dut.rdValid.value):
                return
        raise AssertionError(f"{context}: rdValid timeout")


@cocotb.test()
async def parity_error_flags_only_mismatches(dut):
    """parityError must flag a mismatching parity bit and nothing else."""
    tb = TB(dut)
    mode = os.environ["PARITY_G"]
    await tb.reset()

    # Idle after reset: no data and no error.
    await sample_after_tpd(dut.clk, propagation_time=SAMPLE_DELAY_NS)
    assert int(dut.rdValid.value) == 0
    assert int(dut.parityError.value) == 0

    mask = (1 << tb.data_width) - 1
    corrupt_cases = (0,) if mode == "NONE" else (0, 1)
    for word in DATA_WORDS:
        data = word & mask
        for corrupt in corrupt_cases:
            context = f"{mode} data={data:#04x} corrupt={corrupt}"

            # Frame: start bit, LSB-first data, optional parity, stop bit.
            bits = [0] + [(data >> i) & 1 for i in range(tb.data_width)]
            if mode != "NONE":
                bits.append(expected_parity_bit(data, mode) ^ corrupt)
            bits.append(1)
            await tb.send_frame(bits)

            # The result must be held while rdReady stays low.
            await tb.wait_valid(context)
            for _ in range(8):
                assert int(dut.rdValid.value) == 1, context
                assert int(dut.rdData.value) == data, (
                    f"{context}: rdData={int(dut.rdData.value):#04x}"
                )
                assert int(dut.parityError.value) == corrupt, (
                    f"{context}: parityError={int(dut.parityError.value)}, "
                    f"expected {corrupt}"
                )
                await sample_after_tpd(dut.clk, propagation_time=SAMPLE_DELAY_NS)

            # Accept the result; valid and error clear on the handshake.
            dut.rdReady.value = 1
            await sample_after_tpd(dut.clk, propagation_time=SAMPLE_DELAY_NS)
            dut.rdReady.value = 0
            assert int(dut.rdValid.value) == 0, context
            assert int(dut.parityError.value) == 0, context

            # Idle line between frames.
            await tb.clocks(tb.bit_clocks)


PARAMETER_SWEEP = [
    parameter_case("none_8bit", PARITY_G="NONE", BAUD_MULT_G=16, DATA_WIDTH_G=8),
    parameter_case("even_8bit", PARITY_G="EVEN", BAUD_MULT_G=16, DATA_WIDTH_G=8),
    parameter_case("odd_8bit", PARITY_G="ODD", BAUD_MULT_G=16, DATA_WIDTH_G=8),
    parameter_case("even_7bit_mult8", PARITY_G="EVEN", BAUD_MULT_G=8, DATA_WIDTH_G=7),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_UartRx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.uartrx",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
