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
# - Sweep: Run the single-clock `Pgp4RxKCodeChecker` RTL directly.
# - Stimulus: Drive ordinary data words, valid K-words, invalid K-words, idle
#   cycles, and reset directly into the checker input.
# - Checks: Data words pass regardless of K-code checksum contents, valid
#   K-words pass unchanged, invalid K-words are suppressed with a one-cycle
#   `linkError`, the word immediately following an invalid K-word is also
#   suppressed, and reset clears the registered outputs.
# - Timing: The checker is registered, so each input word is sampled one clock
#   cycle after it is driven.

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    PGP4_D_HEADER,
    PGP4_K_HEADER,
    PGP4_IDLE,
    PGP4_USER,
    Pgp4FlatTB,
    initialize_signals,
    pgp4_idle_word,
    pgp4_kword,
    pgp4_user_word,
    signal_int,
)

K_CODE_CSC_LSB = 48
DATA_PASS_THROUGH_WORD = 0x0123456789ABCDEF
DATA_AFTER_ERROR_WORD = 0xFEDCBA9876543210
DATA_RECOVERY_WORD = 0x55AA55AA55AA55AA
IDLE_PAUSE_MASK = 0x1234
IDLE_OVERFLOW_MASK = 0x00A5
USER_OPCODE_PAYLOAD = 0x0000CAFEBABE


def checker_outputs(dut) -> tuple[int, int, int, int]:
    return (
        signal_int(dut, "checkedValid"),
        signal_int(dut, "checkedHeader"),
        signal_int(dut, "checkedData"),
        signal_int(dut, "linkError"),
    )


async def cycle_and_sample(tb: Pgp4FlatTB):
    await tb.cycle()
    await Timer(1, unit="ns")


async def drive_checker_word(tb: Pgp4FlatTB, *, header: int, data: int, valid: int = 1) -> tuple[int, int, int, int]:
    tb.dut.phyRxValid.value = valid
    tb.dut.phyRxHeader.value = header
    tb.dut.phyRxData.value = data
    await Timer(1, unit="ps")
    await cycle_and_sample(tb)
    return checker_outputs(tb.dut)


def bad_kcode_checksum_word() -> int:
    """Build a real USER K-word and corrupt only its checksum field.

    `pgp4_user_word()` delegates to `pgp4_kword()`, which fills bits 55:48
    with the correct PGP4 control-word checksum.  Flipping bit 48 leaves the
    block type and 48-bit USER payload intact while making the checksum fail.
    """

    return pgp4_user_word(USER_OPCODE_PAYLOAD) ^ (1 << K_CODE_CSC_LSB)


@cocotb.test()
async def pgp4_rx_kcode_checker_test(dut):
    tb = Pgp4FlatTB(dut, clk_name="phyRxClk", rst_name="phyRxRst")
    initialize_signals(
        dut,
        phyRxValid=0,
        phyRxHeader=0,
        phyRxData=0,
    )
    await tb.reset()
    assert checker_outputs(dut) == (0, 0, 0, 0)

    # Data words do not carry a PGP4 K-code checksum.  This value is chosen
    # only to prove that ordinary data is registered and passed through
    # unchanged when the 64b/66b header marks it as data.
    assert await drive_checker_word(tb, header=PGP4_D_HEADER, data=DATA_PASS_THROUGH_WORD) == (
        1,
        PGP4_D_HEADER,
        DATA_PASS_THROUGH_WORD,
        0,
    )

    # `pgp4_idle_word()` builds the BTF, LINKINFO payload, and correct
    # checksum.  Rebuilding the same word with `pgp4_kword()` documents the
    # intended payload fields without relying on a raw 64-bit literal.
    idle_link_info = 0x104 | (IDLE_PAUSE_MASK << 16) | (IDLE_OVERFLOW_MASK << 32)
    idle_word = pgp4_idle_word(
        rem_link_ready=1,
        pause_mask=IDLE_PAUSE_MASK,
        overflow_mask=IDLE_OVERFLOW_MASK,
    )
    assert idle_word == pgp4_kword(PGP4_IDLE, idle_link_info)
    assert await drive_checker_word(tb, header=PGP4_K_HEADER, data=idle_word) == (
        1,
        PGP4_K_HEADER,
        idle_word,
        0,
    )

    # This USER word has a valid block type and opcode payload, but one
    # checksum bit is flipped so the checker should drop it and pulse
    # `linkError` for exactly this registered output cycle.
    good_user_word = pgp4_user_word(USER_OPCODE_PAYLOAD)
    assert good_user_word == pgp4_kword(PGP4_USER, USER_OPCODE_PAYLOAD)
    bad_user_word = bad_kcode_checksum_word()
    assert await drive_checker_word(tb, header=PGP4_K_HEADER, data=bad_user_word) == (
        0,
        PGP4_K_HEADER,
        bad_user_word,
        1,
    )

    # The checker also suppresses the immediately following word so downstream
    # link-error state can take effect before any more protocol words arrive.
    assert await drive_checker_word(tb, header=PGP4_D_HEADER, data=DATA_AFTER_ERROR_WORD) == (
        0,
        PGP4_D_HEADER,
        DATA_AFTER_ERROR_WORD,
        0,
    )

    assert await drive_checker_word(tb, header=PGP4_D_HEADER, data=DATA_RECOVERY_WORD) == (
        1,
        PGP4_D_HEADER,
        DATA_RECOVERY_WORD,
        0,
    )

    tb.dut.phyRxValid.value = 1
    tb.dut.phyRxHeader.value = PGP4_D_HEADER
    tb.dut.phyRxData.value = DATA_PASS_THROUGH_WORD
    tb.dut.phyRxRst.value = 1
    await cycle_and_sample(tb)
    assert checker_outputs(dut) == (0, 0, 0, 0)


PARAMETER_SWEEP = [parameter_case("direct_wrapper")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4RxKCodeChecker(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.pgp4rxkcodechecker",
        extra_env=parameters,
    )
