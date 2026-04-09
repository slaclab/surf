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
# - Sweep: Keep a two-lane simulation-enabled register wrapper so the bench can
#   exercise per-lane config and status counter visibility together.
# - Stimulus: Program polarity, bit-order, and user-delay registers over the
#   flattened AXI-Lite port, then pulse error and bit-slip status inputs.
# - Checks: Register readback and exported configuration outputs must match the
#   programmed values, and the status counters must increment for pulsed bits.
# - Timing: The bench waits several shared clock cycles after reset and after
#   each pulse so the AXI-Lite async bridge and status counters can settle.

import cocotb
import pytest

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.axil_test_utils import PgpAxiLiteTb
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


@cocotb.test()
async def low_speed_reg_visibility_test(dut):
    tb = PgpAxiLiteTb(
        dut,
        clock_names=("deserClk", "S_AXI_ACLK"),
        cycle_clock_name="S_AXI_ACLK",
        reset_signals=(("deserRst", 1, 0), ("S_AXI_ARESETN", 0, 1)),
        initial_values={
            "errorDet": 0,
            "bitSlip": 0,
            "locked": 0b11,
        },
    )
    await tb.reset()
    tb.start_axil_master()
    assert tb.axil is not None

    # Program one global enable, one bit per lane for polarity/bit order, and
    # one user delay value per lane.
    await axil_write_u32(tb.axil, 0x800, 1)
    await axil_write_u32(tb.axil, 0x814, 0b10)
    await axil_write_u32(tb.axil, 0x818, 0b01)
    await axil_write_u32(tb.axil, 0x500, 0x12)
    await axil_write_u32(tb.axil, 0x504, 0x34)
    await tb.cycle(4)

    assert int(dut.enUsrDlyCfgOut.value) == 1
    assert int(dut.polarityOut.value) == 0b10
    assert int(dut.bitOrderOut.value) == 0b01
    assert int(dut.lane0UsrDlyCfg.value) == 0x12
    assert int(dut.lane1UsrDlyCfg.value) == 0x34

    # Pulse wrapper-visible status inputs so the counter registers have
    # something observable to accumulate.
    dut.errorDet.value = 0b01
    await tb.cycle(1)
    dut.errorDet.value = 0
    dut.bitSlip.value = 0b10
    await tb.cycle(1)
    dut.bitSlip.value = 0
    await tb.cycle(12)

    assert (await axil_read_u32(tb.axil, 0x10) & 0xFF) >= 1
    assert (await axil_read_u32(tb.axil, 0x0C) & 0xFF) >= 1


PARAMETER_SWEEP = [parameter_case("two_lane_simulation_reg_block")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4RxLiteLowSpeedReg(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4rxlitelowspeedregwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4RxLiteLowSpeedRegWrapper.vhd",
        extra_env=parameters,
    )
