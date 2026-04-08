##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
##############################################################################

# Test methodology:
# - Sweep: Keep one single-VC `Pgp2bTxCell` wrapper instance.
# - Stimulus: Hold the cell transmitter with no scheduler request and no VC
#   traffic.
# - Checks: The wrapper must keep the transmit interface quiescent until the
#   scheduler asks it to emit a cell.
# - Timing: Sample after a few quiet cycles.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import K_EOC, PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2b_tx_cell_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()
    dut.pgpTxLinkReady.value = 1
    await tb.cycle(4)

    assert signal_int(dut, "schTxAck") == 0
    assert signal_int(dut, "cellTxSOC") == 0
    assert signal_int(dut, "cellTxEOC") == 0


def test_Pgp2bTxCell():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2btxcellwrapper",
        wrapper_source="protocols/pgp/pgp2b/core/wrappers/Pgp2bTxCellWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2b"),
    )
