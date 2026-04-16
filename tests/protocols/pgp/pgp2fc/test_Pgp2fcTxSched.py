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
# - Sweep: Keep one single-VC `Pgp2fcTxSched` wrapper instance.
# - Stimulus: Hold the scheduler in idle and then force link-down/flush cases
#   while no VC traffic is present.
# - Checks: The wrapper must not raise spurious transmit requests or timeouts in
#   the quiescent gating cases.
# - Timing: Sample the outputs after a few registered state updates.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2fc_tx_sched_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()
    dut.pgpTxLinkReady.value = 1
    dut.pgpTxBusy.value = 0
    dut.vc0RemAlmostFull.value = 0
    dut.schTxSOF.value = 0
    dut.schTxEOF.value = 0

    await tb.cycle(4)
    assert signal_int(dut, "schTxReq") == 0
    assert signal_int(dut, "schTxTimeout") == 0

    dut.pgpTxLinkReady.value = 0
    dut.pgpTxFlush.value = 1
    await tb.cycle(2)
    assert signal_int(dut, "schTxReq") == 0
    assert signal_int(dut, "schTxTimeout") == 0


def test_Pgp2fcTxSched():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fctxschedwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcTxSchedWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
