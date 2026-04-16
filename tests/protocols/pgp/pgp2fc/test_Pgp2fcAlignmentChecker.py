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
# - Sweep: Keep one `Pgp2fcAlignmentChecker` wrapper instance exposing both the
#   combinational and latched error variants.
# - Stimulus: Drive clean input, then disparity and alignment errors, then
#   clear the inputs and reset.
# - Checks: The live error flag must track the current lane health while the
#   latched flag must stay high until reset.
# - Timing: Sample after synchronous updates.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2fc_alignment_checker_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()

    assert signal_int(dut, "error") == 0
    assert signal_int(dut, "latchError") == 0

    # A disparity error should trip both checker modes.
    dut.dispErr.value = 0b01
    await tb.cycle()
    assert signal_int(dut, "error") == 1
    assert signal_int(dut, "latchError") == 1

    dut.dispErr.value = 0
    await tb.cycle()
    assert signal_int(dut, "error") == 0
    assert signal_int(dut, "latchError") == 1

    # Reset must clear the latched variant.
    await tb.reset()
    assert signal_int(dut, "latchError") == 0


def test_Pgp2fcAlignmentChecker():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fcalignmentcheckerwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcAlignmentCheckerWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
