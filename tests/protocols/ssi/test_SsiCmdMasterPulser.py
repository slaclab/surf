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
# - Sweep: Keep one three-cycle pulse width so the wrapper stays on the
#   module's intended default timing path.
# - Stimulus: Drive one mismatched command pulse and one matching command pulse
#   into the flattened command-record interface.
# - Checks: Only the matching opcode may assert `syncPulse`, and the asserted
#   pulse must hold for exactly the configured number of cycles.
# - Timing: The bench advances one local clock at a time and observes the pulse
#   width directly instead of assuming combinational behavior.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import cycle, reset_dut, start_clock


async def pulse_command(dut, *, opcode: int):
    dut.cmdValid.value = 1
    dut.cmdOpCode.value = opcode
    await cycle(dut.locClk)
    dut.cmdValid.value = 0


async def wait_for_pulse_level(dut, level: int, *, cycles: int = 8):
    for _ in range(cycles):
        if int(dut.syncPulse.value) == level:
            return
        await cycle(dut.locClk)
    raise AssertionError(f"Timed out waiting for syncPulse={level}")


@cocotb.test()
async def opcode_match_generates_fixed_width_pulse(dut):
    start_clock(dut.locClk)
    dut.locRst.setimmediatevalue(1)
    dut.cmdValid.setimmediatevalue(0)
    dut.cmdOpCode.setimmediatevalue(0)
    dut.cmdCtx.setimmediatevalue(0)
    dut.opCode.setimmediatevalue(0x5A)
    await reset_dut(dut, clk_name="locClk", rst_name="locRst")

    await pulse_command(dut, opcode=0x33)
    for _ in range(4):
        assert int(dut.syncPulse.value) == 0
        await cycle(dut.locClk)

    await pulse_command(dut, opcode=0x5A)
    await wait_for_pulse_level(dut, 1)
    for _ in range(3):
        assert int(dut.syncPulse.value) == 1
        await cycle(dut.locClk)

    await wait_for_pulse_level(dut, 0)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="pulse_width_3")])
def test_SsiCmdMasterPulser(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssicmdmasterpulserwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiCmdMasterPulserWrapper.vhd"]},
    )
