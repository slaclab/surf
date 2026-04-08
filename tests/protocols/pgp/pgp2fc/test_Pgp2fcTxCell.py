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
# - Sweep: Keep one single-VC `Pgp2fcTxCell` wrapper instance.
# - Stimulus: Hold the cell transmitter with no scheduler request and no VC
#   traffic.
# - Checks: The wrapper must keep the transmit interface quiescent until the
#   scheduler asks it to emit a cell.
# - Timing: Sample after a few quiet cycles.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import K_EOC, PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2fc_tx_cell_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()
    dut.pgpTxLinkReady.value = 1
    await tb.cycle(4)

    assert signal_int(dut, "schTxAck") == 0
    assert signal_int(dut, "cellTxSOC") == 0
    assert signal_int(dut, "cellTxEOC") == 0


def test_Pgp2fcTxCell():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fctxcellwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcTxCellWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
