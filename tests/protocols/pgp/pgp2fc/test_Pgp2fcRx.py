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
# - Sweep: Keep one single-lane `Pgp2fcRx` wrapper instance.
# - Stimulus: Hold the top-level RX wrapper ready while driving only malformed
#   idle traffic.
# - Checks: The top-level status outputs must stay in the link-down quiescent
#   state until a real training sequence is supplied.
# - Timing: Run for several cycles to cover the internal detect pipeline.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import PgpModuleTB, build_p2fc_fc_frame, drive_rx_word, signal_int, train_p2fc_rx_link
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2fc_rx_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()

    dut.phyRxReady.value = 1
    for _ in range(8):
        await drive_rx_word(tb, data=0x0000, data_k=0b00)

    assert signal_int(dut, "linkReady") == 0
    assert signal_int(dut, "fcValid") == 0
    assert signal_int(dut, "linkError") == 0


def test_Pgp2fcRx():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fcrxwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcRxWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
