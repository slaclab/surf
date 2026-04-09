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
# - Sweep: Keep one single-VC `Pgp2fcRxCell` wrapper instance.
# - Stimulus: Hold the link down first, then drive one clean VC0 frame and one
#   bad-CRC VC0 frame through the checked-in wrapper with explicit cell
#   boundary markers.
# - Checks: The DUT must keep the link-down fallback state, assemble the good
#   frame onto the VC output, update the remote flow-control bits from the EOC
#   word, and promote a non-zero CRC result into EOFE plus `pgpRxCellError`.
# - Timing: Sample over bounded windows so the checks tolerate the internal
#   delay chain and end-of-cell bookkeeping.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


def snapshot(tb: PgpModuleTB):
    return {
        "valid": signal_int(tb.dut, "vc0FrameRxValid"),
        "sof": signal_int(tb.dut, "vcFrameRxSOF"),
        "eof": signal_int(tb.dut, "vcFrameRxEOF"),
        "eofe": signal_int(tb.dut, "vcFrameRxEOFE"),
        "data": signal_int(tb.dut, "vcFrameRxData"),
        "cell_error": signal_int(tb.dut, "pgpRxCellError"),
        "crc_init": signal_int(tb.dut, "crcRxInit"),
        "crc_valid": signal_int(tb.dut, "crcRxValid"),
    }


async def drive_words_and_capture(tb: PgpModuleTB, words: list[dict[str, int]], *, extra_cycles: int = 8):
    records = []

    for word in words:
        tb.dut.cellRxSOC.value = word.get("soc", 0)
        tb.dut.cellRxSOF.value = word.get("sof", 0)
        tb.dut.cellRxEOC.value = word.get("eoc", 0)
        tb.dut.cellRxEOF.value = word.get("eof", 0)
        tb.dut.cellRxEOFE.value = word.get("eofe", 0)
        tb.dut.cellRxData.value = word.get("data", 0)
        await tb.cycle()
        records.append(snapshot(tb))

    tb.dut.cellRxSOC.value = 0
    tb.dut.cellRxSOF.value = 0
    tb.dut.cellRxEOC.value = 0
    tb.dut.cellRxEOF.value = 0
    tb.dut.cellRxEOFE.value = 0
    tb.dut.cellRxData.value = 0

    for _ in range(extra_cycles):
        await tb.cycle()
        records.append(snapshot(tb))

    return records


@cocotb.test()
async def pgp2fc_rx_cell_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()
    dut.crcRxOut.setimmediatevalue(0)

    # While the link is down the wrapper should advertise the conservative
    # remote-flow-control state and suppress frame output.
    dut.pgpRxLinkReady.value = 0
    await tb.cycle(4)
    assert signal_int(dut, "vc0FrameRxValid") == 0
    assert signal_int(dut, "vc0RemAlmostFull") == 1
    assert signal_int(dut, "vc0RemOverflow") == 0

    # Bring the receive side up and send a clean single-cell VC0 frame with
    # updated remote flow-control bits in the EOC word.
    dut.pgpRxLinkReady.value = 1
    good_records = await drive_words_and_capture(
        tb,
        [
            {"soc": 1, "sof": 1, "data": 0x0011},
            {"data": 0x3456},
            {"eoc": 1, "eof": 1, "data": 0x1100},
            {"data": 0x0000},
        ],
        extra_cycles=14,
    )

    assert any(record["crc_init"] == 1 for record in good_records)
    assert any(record["crc_valid"] == 1 for record in good_records)
    assert any(record["valid"] == 1 and record["sof"] == 1 for record in good_records)
    assert any(record["valid"] == 1 and record["data"] == 0x3456 for record in good_records)
    assert signal_int(dut, "vc0RemAlmostFull") == 1
    assert signal_int(dut, "vc0RemOverflow") == 1

    # A non-zero CRC result should turn the terminating beat into an error and
    # pulse the cell-error output.
    dut.crcRxOut.value = 1
    bad_records = await drive_words_and_capture(
        tb,
        [
            {"soc": 1, "sof": 1, "data": 0x0111},
            {"data": 0xABCD},
            {"eoc": 1, "eof": 1, "data": 0x0000},
            {"data": 0x0000},
        ],
        extra_cycles=14,
    )
    dut.crcRxOut.value = 0

    assert any(record["valid"] == 1 and record["data"] == 0xABCD for record in bad_records)
    assert any(record["eof"] == 1 and record["eofe"] == 1 for record in bad_records)
    assert any(record["cell_error"] == 1 for record in bad_records)


def test_Pgp2fcRxCell():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fcrxcellwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcRxCellWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
