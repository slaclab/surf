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
# - Sweep: All 36 lookup tables and all 256 byte values in each, read out of the
#   shipped VHDL package's own elaboration-time CRC_TABLES_C constant under GHDL
#   through a test-only probe wrapper, one table (all 256 entries) per step.
# - Stimulus: The sweep drives the probe wrapper's tabSel input across all 36
#   table indices and reads tabRow back. No clock is driven; the wrapper is
#   purely combinational.
# - Checks: The shipped VHDL constant must reproduce icrc_table() exactly for
#   all 9,216 values, naming the compared count and the first five differences
#   on failure. Comparing against a recurrence recomputed in Python rather than
#   against a committed snapshot means the two sides can only agree by both
#   being right; tests/ethernet/RoCEv2/test_roce_test_utils.py pins the Python
#   side to its own definition independently.
#   test_RoCEv2ICrc_table_wrapper_is_outside_the_build proves the probe wrapper
#   this bench depends on can never reach synthesis.
#   The sweep is mutation proven able to fail on a single perturbed table
#   entry, an iteration-count off-by-one, and a table-index transposition;
#   each mutation was reverted with an empty diff after its failure was
#   confirmed to name the right table and byte.
# - Timing: The probe wrapper has no clock port, so the sweep settles after a
#   fixed delay rather than a clock edge.

from __future__ import annotations

import cocotb
from cocotb.triggers import Timer

from tests.common.regression_utils import REPO_ROOT, run_surf_vhdl_test
from tests.ethernet.RoCEv2.roce_test_utils import icrc_table

TABLE_COUNT = 36
TABLE_DEPTH = 256

# The probe wrapper. RoCEv2ICrcPkg.vhd, which it reads CRC_TABLES_C from, comes
# from the imported ruckus farm; only the wrapper is outside that build.
VHDL_WRAPPER = "ethernet/RoCEv2/wrappers/RoCEv2ICrcTableWrapper.vhd"
# GHDL folds VHDL identifiers to lowercase; the entity lives in library surf.
GHDL_TOPLEVEL = "surf.rocev2icrctablewrapper"
RUCKUS_TCL_PATH = REPO_ROOT / "ethernet" / "RoCEv2" / "ruckus.tcl"


# ---------------------------------------------------------------------------
# The GHDL sweep over the shipped VHDL constant, and the build-description
# check that keeps its probe wrapper out of synthesis.
# ---------------------------------------------------------------------------


@cocotb.test()
async def rocev2icrc_table_wrapper_sweep_test(dut):
    # Reads all 36 x 256 entries of the shipped VHDL CRC_TABLES_C constant out
    # through the probe wrapper and compares every one against icrc_table(),
    # which recomputes the same value from the CRC recurrence in Python. The
    # reference is executable rather than a committed snapshot, so the two
    # sides can only agree by both being right about the recurrence;
    # test_icrc_table_recurrence_matches_shift_by_one_step in
    # test_roce_test_utils.py independently pins the Python side.
    differences = []
    compared = 0
    for table_index in range(TABLE_COUNT):
        dut.tabSel.value = table_index
        await Timer(1, unit="ns")
        row = int(dut.tabRow.value)
        expected_table = icrc_table(table_index)
        for byte_value in range(TABLE_DEPTH):
            compared += 1
            expected = expected_table[byte_value]
            read = (row >> (32 * byte_value)) & 0xFFFFFFFF
            if expected != read:
                differences.append((table_index, byte_value, expected, read))

    assert compared == TABLE_COUNT * TABLE_DEPTH, (
        f"compared {compared} values, expected exactly {TABLE_COUNT * TABLE_DEPTH}; a truncated "
        "sweep must not be able to pass by comparing fewer values"
    )
    dut._log.info(
        "compared %d table values from the shipped VHDL CRC_TABLES_C constant against icrc_table()",
        compared,
    )

    if differences:
        first_five = ", ".join(
            f"table {k}, byte {b:#04x}: expected {e:#010x}, read {r:#010x}" for k, b, e, r in differences[:5]
        )
        raise AssertionError(
            f"{len(differences)} of {compared} table value(s) read from the shipped VHDL CRC_TABLES_C "
            f"constant differ from the Python recurrence (first five: {first_five})."
        )


def test_RoCEv2ICrcTables():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel=GHDL_TOPLEVEL,
        extra_vhdl_sources={"surf": [VHDL_WRAPPER]},
    )


def test_RoCEv2ICrc_table_wrapper_is_outside_the_build():
    # Eight other test-only wrappers already live in ethernet/RoCEv2/wrappers/
    # under this same rule, and base/crc/wrappers is the in-tree precedent: a
    # wrapper directory that ruckus.tcl never loads, reached only through
    # extra_vhdl_sources in a test. This check asserts that
    # ethernet/RoCEv2/ruckus.tcl, read as text with comment lines dropped,
    # contains no reference to "wrappers", so the probe entity cannot reach a
    # synthesis flow.
    lines = RUCKUS_TCL_PATH.read_text().splitlines()
    code_lines = [line for line in lines if not line.strip().startswith("#")]
    code_text = "\n".join(code_lines)
    assert "wrappers" not in code_text, "ethernet/RoCEv2/ruckus.tcl must not load anything under wrappers/"
