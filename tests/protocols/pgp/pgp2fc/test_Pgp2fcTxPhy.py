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
# - Sweep: Keep one `Pgp2fcTxPhy` wrapper instance with one fast-control word
#   and exercise FC insertion from `ST_LTS_A`, `ST_CELL`, and `ST_EMPTY`.
# - Stimulus: Bring link training up, place the PHY into each source state,
#   then pulse `fcValid` for one cycle with a known FC word.
# - Checks: The emitted FC framing must stay exact in the quiescent reference
#   case, while the `fcValid -> fcSent` latency and `pgpBusy` width must stay
#   identical across all exercised source states.
# - Timing: The bench measures cycle deltas on the serialized output and uses
#   bounded state-alignment waits before every FC pulse.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import PgpModuleTB, build_p2fc_fc_frame, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


def sample_output(dut):
    return {
        "data": signal_int(dut, "phyTxData"),
        "data_k": signal_int(dut, "phyTxDataK"),
        "busy": signal_int(dut, "pgpBusy"),
        "fc_sent": signal_int(dut, "fcSent"),
    }


def contiguous_busy_width(records: list[dict[str, int]]) -> int:
    first_busy = next((idx for idx, record in enumerate(records) if record["busy"] == 1), None)
    if first_busy is None:
        raise AssertionError("No busy pulse observed during FC transmission")

    width = 0
    for record in records[first_busy:]:
        if record["busy"] != 1:
            break
        width += 1
    return width


def find_fc_sequence(records: list[dict[str, int]], expected_fc: list[tuple[int, int]]) -> int:
    for idx in range(len(records) - len(expected_fc) + 1):
        if all(
            records[idx + offset]["data"] == expected_word[0]
            and records[idx + offset]["data_k"] == expected_word[1]
            for offset, expected_word in enumerate(expected_fc)
        ):
            return idx
    raise AssertionError("Timed out waiting for the contiguous FC word sequence on the PHY output")


async def measure_fc_window(tb: PgpModuleTB, *, fc_word: int, require_sequence: bool = True):
    expected_fc = build_p2fc_fc_frame(fc_word)
    records = []

    tb.dut.fcWord.value = fc_word
    tb.dut.fcValid.value = 1
    await tb.cycle()
    records.append(sample_output(tb.dut))
    tb.dut.fcValid.value = 0

    for _ in range(11):
        await tb.cycle()
        records.append(sample_output(tb.dut))

    sent_idx = next((idx for idx, record in enumerate(records) if record["fc_sent"] == 1), None)
    if sent_idx is None:
        raise AssertionError("Timed out waiting for fcSent")

    first_idx = None
    if require_sequence:
        first_idx = find_fc_sequence(records, expected_fc)

    return {
        "first_fcd_latency": None if first_idx is None else first_idx + 1,
        "fc_sent_latency": sent_idx + 1,
        "busy_width": contiguous_busy_width(records),
    }


@cocotb.test()
async def pgp2fc_tx_phy_fixed_latency_test(dut):
    tb = PgpModuleTB(dut)
    async def prepare_case():
        await tb.reset(settle_cycles=0)
        dut.phyTxReady.value = 1
        dut.pgpLocLinkReady.value = 1
        dut.cellTxSOC.value = 0
        dut.cellTxSOF.value = 0
        dut.cellTxEOC.value = 0
        dut.cellTxEOF.value = 0
        dut.cellTxEOFE.value = 0
        dut.cellTxData.value = 0

    # Reference the FC-entry latency from the training-A state.
    await prepare_case()
    await tb.cycle()
    reference = await measure_fc_window(tb, fc_word=0x1234, require_sequence=True)

    # Drive a non-empty cell so the PHY is actively streaming cell data.
    await prepare_case()
    dut.cellTxData.value = 0x1357
    await tb.cycle(3)
    cell_case = await measure_fc_window(tb, fc_word=0x2345, require_sequence=False)

    # Terminate the cell, which forces one ST_EMPTY cycle before training resumes.
    await prepare_case()
    dut.cellTxData.value = 0x2468
    await tb.cycle(3)
    dut.cellTxEOC.value = 1
    await tb.cycle()
    dut.cellTxEOC.value = 0
    dut.cellTxData.value = 0
    empty_case = await measure_fc_window(tb, fc_word=0x3456, require_sequence=False)

    for case in (cell_case, empty_case):
        assert case["fc_sent_latency"] == reference["fc_sent_latency"]
        assert case["busy_width"] == reference["busy_width"]


def test_Pgp2fcTxPhy():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fctxphywrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcTxPhyWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
