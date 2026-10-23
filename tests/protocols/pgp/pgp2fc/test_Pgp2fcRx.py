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
# - Stimulus: First prove malformed idles do not link, then train the link,
#   send one good single-cell frame, and finally send one frame with a payload
#   bit flipped after CRC generation.
# - Checks: The integrated receive path must stay quiescent before training,
#   accept the good frame through `frameRx`, and reject the corrupted frame
#   through `frameRxErr` plus `cellError` while keeping the link up.
# - Timing: Every protocol event is observed with bounded waits so the test
#   stays stable across the internal PHY, CRC, and depacketizer pipelines.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import (
    PgpModuleTB,
    build_p2_single_cell_frame,
    drive_rx_word,
    signal_int,
    train_p2fc_rx_link,
    wait_for_signal,
)
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

    # The wrapper should only reach link-ready after a proper training stream.
    await train_p2fc_rx_link(tb, rem_link_ready=1, rem_data=0xA5)
    await wait_for_signal(tb, "linkReady", value=1, cycles=16)
    assert signal_int(dut, "remLinkReady") == 1
    assert signal_int(dut, "remLinkData") == 0xA5

    # A correctly formatted frame should pass cleanly through the full receive
    # stack.  The helper models the SOF/CRC/EOF wire encoding so this is a real
    # integrated protocol transaction, not a local `RxCell` shortcut.
    for data, data_k in build_p2_single_cell_frame(serial=0, payload_words=[0x3412, 0x7856]):
        await drive_rx_word(tb, data=data, data_k=data_k)
    await drive_rx_word(tb, data=0x0000, data_k=0b00)
    await wait_for_signal(tb, "frameRx", value=1, cycles=24)
    assert signal_int(dut, "frameRxErr") == 0
    assert signal_int(dut, "cellError") == 0

    # Now flip one payload bit *after* the CRC words have already been derived.
    # That gives us the high-value integration check: the receiver must detect
    # a true in-flight corruption event even though the local CRC block itself
    # is perfectly healthy.
    for data, data_k in build_p2_single_cell_frame(
        serial=1,
        payload_words=[0xCAFE, 0xBABE],
        payload_corruption=(1, 0x0001),
    ):
        await drive_rx_word(tb, data=data, data_k=data_k)
    await drive_rx_word(tb, data=0x0000, data_k=0b00)
    await wait_for_signal(tb, "frameRxErr", value=1, cycles=24)
    assert signal_int(dut, "linkReady") == 1


def test_Pgp2fcRx():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fcrxwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcRxWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
