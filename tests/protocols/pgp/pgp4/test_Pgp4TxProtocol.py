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
    btf,
    initialize_flat_tx_inputs,
    send_opcode,
    send_single_word_frame_and_collect_protocol_words,
    signal_int,
    wait_for_non_idle_protocol_word,
    wait_for_signal,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


@cocotb.test()
async def pgp4_tx_protocol_test(dut):
    tb = Pgp4FlatTB(dut)
    initialize_flat_tx_inputs(dut, include_opcode=True)
    await tb.reset()
    await wait_for_signal(tb, "linkReady")

    await send_opcode(tb, 0x001122334455)
    header, data = await wait_for_non_idle_protocol_word(tb)
    assert header == PGP4_K_HEADER
    assert btf(data) == PGP4_USER
    assert data & ((1 << 48) - 1) == 0x001122334455

    payload = 0xDEADBEEF12345678
    # The shared helper hides the handshake plumbing and only returns the
    # meaningful non-IDLE words the wrapper emitted for the frame.
    words = await send_single_word_frame_and_collect_protocol_words(tb, payload=payload)
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
