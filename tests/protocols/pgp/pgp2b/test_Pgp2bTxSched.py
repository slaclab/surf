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
# - Sweep: Keep one single-VC `Pgp2bTxSched` wrapper instance.
# - Stimulus: Hold the scheduler in idle and then force link-down/flush
#   conditions while no VC traffic is present.
# - Checks: The wrapper must not raise spurious transmit requests or timeouts in
#   the quiescent cases that gate later higher-level tests.
# - Timing: Sample outputs after a few registered state updates.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2b_tx_sched_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()
    dut.pgpTxLinkReady.value = 1
    dut.vc0RemAlmostFull.value = 0
    dut.schTxSOF.value = 0
    dut.schTxEOF.value = 0

    # With no VC traffic pending, the scheduler should stay quiescent.
    await tb.cycle(4)
    assert signal_int(dut, "schTxReq") == 0
    assert signal_int(dut, "schTxTimeout") == 0

    # Losing link-ready or issuing a flush must still keep the scheduler quiet.
    dut.pgpTxLinkReady.value = 0
    dut.pgpTxFlush.value = 1
    await tb.cycle(2)
    assert signal_int(dut, "schTxReq") == 0
    assert signal_int(dut, "schTxTimeout") == 0


def test_Pgp2bTxSched():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2btxschedwrapper",
        wrapper_source="protocols/pgp/pgp2b/core/wrappers/Pgp2bTxSchedWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2b"),
    )
