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
# - Sweep: Keep one single-lane single-VC `Pgp2fcTx` wrapper instance.
# - Stimulus: Let the integrated TX path reach link-up, then send one fast
#   control word.
# - Checks: The wrapper must report link-ready and assert `fcSent` once the
#   fast-control frame is emitted.
# - Timing: Observe the top-level status outputs after startup training.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2fc_tx_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()

    for _ in range(12):
        await tb.cycle()
        if signal_int(dut, "linkReady") == 1:
            break

    assert signal_int(dut, "linkReady") == 1

    dut.txFcWord.value = 0x2222
    dut.txFcValid.value = 1
    await tb.cycle()
    dut.txFcValid.value = 0

    for _ in range(4):
        await tb.cycle()
        if signal_int(dut, "fcSent") == 1:
            break

    assert signal_int(dut, "fcSent") == 1


def test_Pgp2fcTx():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fctxwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcTxWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
