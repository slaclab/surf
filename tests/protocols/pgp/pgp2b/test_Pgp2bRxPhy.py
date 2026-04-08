##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
##############################################################################

# Test methodology:
# - Sweep: Keep one single-lane `Pgp2bRxPhy` wrapper instance.
# - Stimulus: Hold the PHY ready but drive only malformed idle traffic without
#   any valid training ordered set.
# - Checks: The wrapper must keep link-ready low and suppress opcode/cell
#   decodes until a real link-training sequence appears.
# - Timing: Run for several cycles to cover the two-stage detect pipeline.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import K_OTS, K_SOF, PgpModuleTB, drive_rx_word, signal_int, train_p2b_rx_link
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2b_rx_phy_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()
    dut.phyRxReady.value = 1

    for _ in range(8):
        await drive_rx_word(tb, data=0x0000, data_k=0b00)

    assert signal_int(dut, "pgpRxLinkReady") == 0
    assert signal_int(dut, "pgpRxOpCodeEn") == 0
    assert signal_int(dut, "cellRxSOF") == 0
    assert signal_int(dut, "cellRxEOC") == 0


def test_Pgp2bRxPhy():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2brxphywrapper",
        wrapper_source="protocols/pgp/pgp2b/core/wrappers/Pgp2bRxPhyWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2b"),
    )
