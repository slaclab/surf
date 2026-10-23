##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
##############################################################################

# Test methodology:
# - Sweep: Keep one single-lane `Pgp2bTxPhy` wrapper instance.
# - Stimulus: Let the PHY emit its startup ordered sets, then drive one SOF
#   cell marker.
# - Checks: Startup must contain the expected training words, link-ready must
#   assert, and the SOF marker must map onto the outgoing K character lane.
# - Timing: Sample the serialized outputs cycle-by-cycle.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import D_102, K_LTS, K_SOF, PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2b_tx_phy_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset(settle_cycles=0)
    dut.phyTxReady.value = 1
    dut.pgpLocLinkReady.value = 1

    observed = []
    for _ in range(8):
        await tb.cycle()
        observed.append((signal_int(dut, "phyTxData"), signal_int(dut, "phyTxDataK")))

    assert ((D_102 << 8) | K_LTS, 0b01) in observed
    assert signal_int(dut, "pgpTxLinkReady") == 1

    # Once the link is up, a SOF request should be translated into the K_SOF symbol.
    dut.cellTxSOF.value = 1
    dut.cellTxData.value = 0x1234
    await tb.cycle(2)
    dut.cellTxSOF.value = 0

    assert signal_int(dut, "phyTxData") == ((0x12 << 8) | K_SOF)
    assert signal_int(dut, "phyTxDataK") == 0b01


def test_Pgp2bTxPhy():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2btxphywrapper",
        wrapper_source="protocols/pgp/pgp2b/core/wrappers/Pgp2bTxPhyWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2b"),
    )
