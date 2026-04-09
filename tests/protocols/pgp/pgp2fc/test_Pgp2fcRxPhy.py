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
# - Sweep: Keep one single-lane `Pgp2fcRxPhy` wrapper instance.
# - Stimulus: Hold the PHY ready, prove malformed idles do not link, then drive
#   valid training, one good FC frame, one good cell sequence, and one errored
#   lane beat.
# - Checks: The DUT must acquire link only from valid training, report the
#   remote sideband fields, decode the FC payload, emit cell SOF/EOF markers,
#   and pulse `pgpRxLinkError` on a post-link decode/disparity error.
# - Timing: Every check uses bounded waits so the bench stays stable across the
#   internal two-stage receive pipeline and FC CRC path.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import (
    K_EOF,
    K_SOF,
    PgpModuleTB,
    build_p2fc_fc_frame,
    drive_rx_word,
    signal_int,
    train_p2fc_rx_link,
)
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


async def wait_for_signal(tb: PgpModuleTB, signal_name: str, *, value: int = 1, cycles: int = 32):
    for _ in range(cycles):
        if signal_int(tb.dut, signal_name) == value:
            return
        await tb.cycle()
    raise AssertionError(f"Timed out waiting for {signal_name}={value}")


async def collect_snapshots(tb: PgpModuleTB, words: list[tuple[int, int]], *, extra_cycles: int = 4):
    snapshots = []

    def snapshot():
        snapshots.append(
            {
                "sof": signal_int(tb.dut, "cellRxSOF"),
                "soc": signal_int(tb.dut, "cellRxSOC"),
                "eoc": signal_int(tb.dut, "cellRxEOC"),
                "eof": signal_int(tb.dut, "cellRxEOF"),
                "eofe": signal_int(tb.dut, "cellRxEOFE"),
                "data": signal_int(tb.dut, "cellRxData"),
            }
        )

    for data, data_k in words:
        await drive_rx_word(tb, data=data, data_k=data_k)
        snapshot()

    for _ in range(extra_cycles):
        await tb.cycle()
        snapshot()

    return snapshots


@cocotb.test()
async def pgp2fc_rx_phy_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()

    # Keep the PHY in lock while the bench controls the incoming stream.
    dut.phyRxReady.value = 1

    # Malformed idle traffic must not bring the link up or decode control words.
    for _ in range(8):
        await drive_rx_word(tb, data=0x0000, data_k=0b00)

    assert signal_int(dut, "pgpRxLinkReady") == 0
    assert signal_int(dut, "fcValid") == 0
    assert signal_int(dut, "cellRxSOF") == 0

    # Valid training should be the only path into link-ready.
    await train_p2fc_rx_link(tb, rem_link_ready=1, rem_data=0xA5, fc_words=1)
    await wait_for_signal(tb, "pgpRxLinkReady", value=1, cycles=16)
    assert signal_int(dut, "pgpRemLinkReady") == 1
    assert signal_int(dut, "pgpRemData") == 0xA5

    # A correctly framed FC word should raise fcValid and preserve the payload.
    for data, data_k in build_p2fc_fc_frame(0x2244):
        await drive_rx_word(tb, data=data, data_k=data_k)
    await drive_rx_word(tb, data=0x0000, data_k=0b00)
    await wait_for_signal(tb, "fcValid", value=1, cycles=8)
    assert signal_int(dut, "fcWord") == 0x2244
    assert signal_int(dut, "fcError") == 0

    # Corrupting the CRC byte must be rejected through fcError instead.
    bad_fc = build_p2fc_fc_frame(0x55AA)
    await drive_rx_word(tb, data=bad_fc[0][0], data_k=bad_fc[0][1])
    await drive_rx_word(tb, data=(bad_fc[1][0] ^ 0x0100), data_k=bad_fc[1][1])
    await drive_rx_word(tb, data=0x0000, data_k=0b00)
    await wait_for_signal(tb, "fcError", value=1, cycles=8)

    # A simple cell transfer should expose both the frame markers and payload.
    cell_records = await collect_snapshots(
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
    await drive_rx_word(tb, data=0x0000, data_k=0b00, dec_err=0b01)
    await wait_for_signal(tb, "pgpRxLinkError", value=1, cycles=8)


def test_Pgp2fcRxPhy():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fcrxphywrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcRxPhyWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
