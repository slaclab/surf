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
# - Sweep: Keep one `Pgp2fcAlignmentController` wrapper instance in override
#   mode with a mocked AXI-Lite read completion path.
# - Stimulus: Hold the controller in its default no-override state with no
#   phase request or protocol error.
# - Checks: The wrapper must stay quiescent: no manual slide pulse, no phase
#   valid pulse, and no AXI-Lite read request.
# - Timing: Sample after the initial reset and cooldown window.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2fc_alignment_controller_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()

    await tb.cycle(70)
    assert signal_int(dut, "rxSlide") == 0
    assert signal_int(dut, "linkAlignPhaseValid") == 0
    assert signal_int(dut, "axilReadRequest") == 0


def test_Pgp2fcAlignmentController():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fcalignmentcontrollerwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcAlignmentControllerWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
