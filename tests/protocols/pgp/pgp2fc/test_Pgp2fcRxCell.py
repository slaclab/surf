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
# - Sweep: Keep one single-VC `Pgp2fcRxCell` wrapper instance.
# - Stimulus: Hold the receive side in link-down with no incoming cell traffic.
# - Checks: The wrapper must keep frame-valid low while advertising the remote
#   almost-full fallback state used during link-down.
# - Timing: Sample after reset release and a few quiet cycles.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2fc_rx_cell_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()
    dut.pgpRxLinkReady.value = 0
    await tb.cycle(4)

    assert signal_int(dut, "vc0FrameRxValid") == 0
    assert signal_int(dut, "vc0RemAlmostFull") == 1
    assert signal_int(dut, "vc0RemOverflow") == 0


def test_Pgp2fcRxCell():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fcrxcellwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcRxCellWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
