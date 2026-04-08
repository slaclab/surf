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
# - Sweep: Cover a small two-case pulse-width matrix so the bench proves both
#   the minimum one-cycle pulse path and a longer multi-cycle hold path.
# - Stimulus: Drive mismatched commands, one matching command, a second
#   matching command after the first pulse clears, and one matching command
#   while the output pulse is already asserted.
# - Checks: Only matching opcodes may assert `syncPulse`, the pulse width must
#   match `PULSE_WIDTH_G`, back-to-back matches must generate distinct pulses,
#   and an in-flight pulse must not be retriggered or extended.
# - Timing: The bench advances one local clock at a time and measures pulse
#   duration directly instead of assuming any combinational decode behavior.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import cycle, env_int, reset_dut, start_clock, wait_signal_level


async def pulse_command(dut, *, opcode: int, ctx: int = 0):
    # Present one decoded command for exactly one local-clock cycle.
    dut.cmdValid.value = 1
    dut.cmdOpCode.value = opcode
    dut.cmdCtx.value = ctx
    await cycle(dut.locClk)
    dut.cmdValid.value = 0


async def measure_pulse_width(dut, *, max_cycles: int = 16) -> int:
    # Once the pulse starts, count how many full cycles it stays asserted.
    await wait_signal_level(dut.syncPulse, clk=dut.locClk, expected=1, cycles=max_cycles)
    width = 0
    while int(dut.syncPulse.value) == 1:
        width += 1
        await cycle(dut.locClk)
        if width > max_cycles:
            raise AssertionError("syncPulse stayed asserted longer than expected")
    return width


@cocotb.test()
async def opcode_match_generates_fixed_width_pulses(dut):
    pulse_width = env_int("PULSE_WIDTH_G", default=3)

    # This module runs only on the local command clock, so the bench uses that
    # single clock for reset, stimulus, and pulse-width measurements.
    start_clock(dut.locClk)
    dut.locRst.setimmediatevalue(1)
    dut.cmdValid.setimmediatevalue(0)
    dut.cmdOpCode.setimmediatevalue(0)
    dut.cmdCtx.setimmediatevalue(0)
    dut.opCode.setimmediatevalue(0x5A)
    await reset_dut(dut, clk_name="locClk", rst_name="locRst")

    # A non-matching opcode should leave the output low for the full check
    # window.
    await pulse_command(dut, opcode=0x33)
    for _ in range(pulse_width + 1):
        assert int(dut.syncPulse.value) == 0
        await cycle(dut.locClk)

    # A matching opcode should create one pulse whose duration matches the
    # configured generic exactly.
    await pulse_command(dut, opcode=0x5A, ctx=0x123456)
    assert await measure_pulse_width(dut, max_cycles=pulse_width + 4) == pulse_width
    await wait_signal_level(dut.syncPulse, clk=dut.locClk, expected=0, cycles=4)

    # The next matching command should create a second independent pulse after
    # the first one returns to zero.
    await pulse_command(dut, opcode=0x5A, ctx=0xABCDEF)
    assert await measure_pulse_width(dut, max_cycles=pulse_width + 4) == pulse_width
    await wait_signal_level(dut.syncPulse, clk=dut.locClk, expected=0, cycles=4)

    if pulse_width > 1:
        # When the pulse is already high, another matching command must not
        # stretch the pulse beyond its configured width.
        await pulse_command(dut, opcode=0x5A)
        await wait_signal_level(dut.syncPulse, clk=dut.locClk, expected=1, cycles=4)
        observed_width = 1

        await pulse_command(dut, opcode=0x5A)
        observed_width += 1
        assert int(dut.syncPulse.value) == 1

        while int(dut.syncPulse.value) == 1:
            await cycle(dut.locClk)
            if int(dut.syncPulse.value) == 1:
                observed_width += 1
            if observed_width > pulse_width + 1:
                raise AssertionError("syncPulse extended beyond configured width")

        assert observed_width == pulse_width

    # Leave a short post-check idle window so a delayed retrigger would still
    # be caught here.
    for _ in range(3):
        assert int(dut.syncPulse.value) == 0
        await cycle(dut.locClk)


PARAMETER_SWEEP = [
    parameter_case("pulse_width_1", PULSE_WIDTH_G="1"),
    parameter_case("pulse_width_3", PULSE_WIDTH_G="3"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiCmdMasterPulser(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssicmdmasterpulserwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiCmdMasterPulserWrapper.vhd"]},
    )
