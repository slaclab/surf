##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
##############################################################################

# Test methodology:
# - Sweep: Keep one single-lane single-VC `Pgp2bTx` wrapper instance.
# - Stimulus: Let the integrated TX path reach link-up, then inject one opcode.
# - Checks: The wrapper must report link-ready and place the opcode ordered set
#   onto the serialized PHY interface.
# - Timing: Observe the PHY outputs after startup training completes.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import K_OTS, PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2b_tx_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()
    dut.locLinkReady.value = 1
    dut.phyTxReady.value = 1

    for _ in range(12):
        await tb.cycle()
        if signal_int(dut, "linkReady") == 1:
            break

    assert signal_int(dut, "linkReady") == 1

    dut.txOpCode.value = 0x5C
    dut.txOpCodeEn.value = 1
    for _ in range(4):
        await tb.cycle()
        if signal_int(dut, "phyTxData") == ((0x5C << 8) | K_OTS):
            break
    dut.txOpCodeEn.value = 0

    assert signal_int(dut, "phyTxData") == ((0x5C << 8) | K_OTS)
    assert signal_int(dut, "phyTxDataK") == 0b01


def test_Pgp2bTx():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2btxwrapper",
        wrapper_source="protocols/pgp/pgp2b/core/wrappers/Pgp2bTxWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2b"),
    )
