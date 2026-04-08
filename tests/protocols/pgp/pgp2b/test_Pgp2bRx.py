##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
##############################################################################

# Test methodology:
# - Sweep: Keep one single-lane `Pgp2bRx` wrapper instance.
# - Stimulus: Hold the top-level RX wrapper ready while driving only malformed
#   idle traffic.
# - Checks: The top-level status outputs must stay in the link-down quiescent
#   state until a real training sequence is supplied.
# - Timing: Run for several cycles to cover the internal detect pipeline.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import K_OTS, PgpModuleTB, drive_rx_word, signal_int, train_p2b_rx_link
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2b_rx_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()
    dut.phyRxReady.value = 1

    for _ in range(8):
        await drive_rx_word(tb, data=0x0000, data_k=0b00)

    assert signal_int(dut, "linkReady") == 0
    assert signal_int(dut, "opCodeEn") == 0
    assert signal_int(dut, "linkError") == 0


def test_Pgp2bRx():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2brxwrapper",
        wrapper_source="protocols/pgp/pgp2b/core/wrappers/Pgp2bRxWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2b"),
    )
