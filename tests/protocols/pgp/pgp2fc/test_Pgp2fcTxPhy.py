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
# - Sweep: Keep one `Pgp2fcTxPhy` wrapper instance with one fast-control word.
# - Stimulus: Let startup training complete, then send one fast-control word.
# - Checks: The startup sequence must include LTS A, link-ready must assert,
#   and the emitted fast-control framing must match the expected two-word
#   sequence.
# - Timing: Sample the serialized words cycle-by-cycle.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import D_102, K_FCD, K_LTS, PgpModuleTB, build_p2fc_fc_frame, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2fc_tx_phy_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset(settle_cycles=0)
    dut.phyTxReady.value = 1
    dut.pgpLocLinkReady.value = 1

    observed = []
    for _ in range(4):
        await tb.cycle()
        observed.append((signal_int(dut, "phyTxData"), signal_int(dut, "phyTxDataK")))

    assert ((D_102 << 8) | K_LTS, 0b01) in observed
    assert signal_int(dut, "pgpTxLinkReady") == 1

    expected_fc = build_p2fc_fc_frame(0x1234)
    dut.fcWord.value = 0x1234
    dut.fcValid.value = 1
    await tb.cycle()
    dut.fcValid.value = 0

    emitted = []
    for _ in range(4):
        await tb.cycle()
        emitted.append((signal_int(dut, "phyTxData"), signal_int(dut, "phyTxDataK")))

    assert expected_fc[0] in emitted
    assert expected_fc[1] in emitted


def test_Pgp2fcTxPhy():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fctxphywrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcTxPhyWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
