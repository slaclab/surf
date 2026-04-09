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
# - Sweep: Keep one direct `Pgp4TxProtocol` wrapper with a single VC and zero
#   startup hold so the protocol word sequence is deterministic.
# - Stimulus: Inject one opcode and one single-word frame through a checked-in
#   packetizer-backed wrapper.
# - Checks: The opcode must emit a USER k-code, and the frame must emit a SOF,
#   one data word, and an EOF tail while asserting `frameTx`.
# - Timing: The bench waits for the flat input-side `txReady` handshake and
#   skips background IDLE traffic when collecting output words.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    PGP4_D_HEADER,
    PGP4_EOF,
    PGP4_K_HEADER,
    PGP4_SOF,
    PGP4_USER,
    Pgp4FlatTB,
    signal_int,
    wait_for_signal,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


def btf(word: int) -> int:
    return (word >> 56) & 0xFF


async def send_single_word_frame(tb: Pgp4FlatTB, *, payload: int, eofe: int = 0):
    tb.dut.txValid.value = 1
    tb.dut.txData.value = payload
    tb.dut.txSof.value = 1
    tb.dut.txEof.value = 1
    tb.dut.txEofe.value = eofe
    await wait_for_signal(tb, "txReady")
    await tb.cycle()
    tb.dut.txValid.value = 0
    tb.dut.txSof.value = 0
    tb.dut.txEof.value = 0
    tb.dut.txEofe.value = 0


def is_non_idle(header: int, data: int) -> bool:
    return header == PGP4_D_HEADER or btf(data) != 0x99


async def wait_for_non_idle_protocol_word(tb: Pgp4FlatTB, *, cycles: int = 256) -> tuple[int, int]:
    for _ in range(cycles):
        await tb.cycle()
        if signal_int(tb.dut, "protTxValid") != 1:
            continue
        header = signal_int(tb.dut, "protTxHeader")
        data = signal_int(tb.dut, "protTxData")
        if is_non_idle(header, data):
            return header, data
    raise AssertionError("Timed out waiting for non-IDLE protocol word")


async def send_single_word_frame_and_collect(tb: Pgp4FlatTB, *, payload: int, eofe: int = 0) -> list[tuple[int, int]]:
    tb.dut.txValid.value = 1
    tb.dut.txData.value = payload
    tb.dut.txSof.value = 1
    tb.dut.txEof.value = 1
    tb.dut.txEofe.value = eofe

    words = []
    accepted = False
    for _ in range(64):
        await tb.cycle()
        if signal_int(tb.dut, "protTxValid") == 1:
            header = signal_int(tb.dut, "protTxHeader")
            data = signal_int(tb.dut, "protTxData")
            if is_non_idle(header, data):
                words.append((header, data))
        if not accepted and signal_int(tb.dut, "txReady") == 1:
            accepted = True
            tb.dut.txValid.value = 0
            tb.dut.txSof.value = 0
            tb.dut.txEof.value = 0
            tb.dut.txEofe.value = 0
        if accepted and len(words) >= 3:
            return words[:3]

    raise AssertionError("Timed out collecting frame protocol words")


@cocotb.test()
async def pgp4_tx_protocol_test(dut):
    tb = Pgp4FlatTB(dut)
    dut.txValid.setimmediatevalue(0)
    dut.txData.setimmediatevalue(0)
    dut.txSof.setimmediatevalue(0)
    dut.txEof.setimmediatevalue(0)
    dut.txEofe.setimmediatevalue(0)
    dut.opCodeEn.setimmediatevalue(0)
    dut.opCodeData.setimmediatevalue(0)
    await tb.reset()
    await wait_for_signal(tb, "linkReady")

    dut.opCodeData.value = 0x001122334455
    dut.opCodeEn.value = 1
    await tb.cycle()
    dut.opCodeEn.value = 0

    header, data = await wait_for_non_idle_protocol_word(tb)
    assert header == PGP4_K_HEADER
    assert btf(data) == PGP4_USER
    assert data & ((1 << 48) - 1) == 0x001122334455

    payload = 0xDEADBEEF12345678
    words = await send_single_word_frame_and_collect(tb, payload=payload)
    assert words[0][0] == PGP4_K_HEADER
    assert btf(words[0][1]) == PGP4_SOF
    assert words[1][0] == PGP4_D_HEADER
    assert words[1][1] == payload
    assert words[2][0] == PGP4_K_HEADER
    assert btf(words[2][1]) == PGP4_EOF
    assert ((words[2][1] >> 12) & 0xF) == 8

    await wait_for_signal(tb, "frameTx")
    assert signal_int(dut, "frameTxErr") == 0


PARAMETER_SWEEP = [parameter_case("packetizer_backed_protocol_wrapper")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4TxProtocol(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4txprotocolwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4TxProtocolWrapper.vhd",
        extra_env=parameters,
    )
