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
# - Sweep: Keep one single-lane `Pgp2bRxPhy` wrapper instance.
# - Stimulus: Hold the PHY ready, prove malformed idles do not link, then drive
#   valid training, one opcode ordered set, one good cell sequence, and one
#   errored lane beat.
# - Checks: The DUT must acquire link only from valid training, report the
#   remote sideband fields, decode the opcode, emit cell SOF/EOF markers, and
#   pulse `pgpRxLinkError` on a post-link decode/disparity error.
# - Timing: Every check uses bounded waits so the bench stays stable across the
#   internal two-stage receive pipeline.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import (
    K_EOF,
    K_OTS,
    K_SOF,
    PgpModuleTB,
    collect_cell_snapshots,
    drive_rx_word,
    signal_int,
    train_p2b_rx_link,
    wait_for_signal,
)
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2b_rx_phy_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()
    dut.phyRxReady.value = 1

    # Bad idles must not create a false link-up or any receive decodes.
    for _ in range(8):
        await drive_rx_word(tb, data=0x0000, data_k=0b00)

    assert signal_int(dut, "pgpRxLinkReady") == 0
    assert signal_int(dut, "pgpRxOpCodeEn") == 0
    assert signal_int(dut, "cellRxSOF") == 0
    assert signal_int(dut, "cellRxEOC") == 0

    # Valid training should bring the lane into link-ready and surface sideband data.
    await train_p2b_rx_link(tb, rem_link_ready=1, rem_data=0xA5)
    await wait_for_signal(tb, "pgpRxLinkReady", value=1, cycles=16)
    assert signal_int(dut, "pgpRemLinkReady") == 1
    assert signal_int(dut, "pgpRemData") == 0xA5

    # The opcode ordered set should decode once the link is up.
    await drive_rx_word(tb, data=((0x5C << 8) | K_OTS), data_k=0b01)
    await wait_for_signal(tb, "pgpRxOpCodeEn", value=1, cycles=8)
    assert signal_int(dut, "pgpRxOpCode") == 0x5C

    # A simple cell transfer should expose both the frame markers and payload.
    # The shared snapshot helper records the wrapper-visible cell flags after
    # each incoming PHY word so the assertions can stay focused on behavior.
    cell_records = await collect_cell_snapshots(
        tb,
        [
            ((0x12 << 8) | K_SOF, 0b01),
            (0x3456, 0b00),
            ((0x78 << 8) | K_EOF, 0b01),
        ],
    )
    assert any(record["soc"] == 1 and record["sof"] == 1 for record in cell_records)
    assert any(record["data"] == 0x3456 for record in cell_records)
    assert any(record["eoc"] == 1 and record["eof"] == 1 and record["eofe"] == 0 for record in cell_records)

    # Once linked, a PHY decode/disparity error must raise a link-error pulse.
    await drive_rx_word(tb, data=0x0000, data_k=0b00, disp_err=0b01)
    await wait_for_signal(tb, "pgpRxLinkError", value=1, cycles=8)


def test_Pgp2bRxPhy():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2brxphywrapper",
        wrapper_source="protocols/pgp/pgp2b/core/wrappers/Pgp2bRxPhyWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2b"),
    )
