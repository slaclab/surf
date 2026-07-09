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
# - Sweep: Keep one single-VC direct wrapper around `Pgp4RxProtocol`.
# - Stimulus: Drive enough valid IDLE words to achieve link-up, then inject one
#   metadata IDLE, one USER opcode, and one SOF/data/EOF packet sequence.
# - Checks: Link-ready and remote pause metadata must update correctly, the
#   USER word must surface on `opCodeData`, and the packetizer-format output
#   must contain the expected data beat and terminating tail.
# - Timing: The bench keeps `pktReady` asserted and polls the pipelined packet
#   output for a bounded number of cycles after each protocol sequence.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    PGP4_D_HEADER,
    PGP4_K_HEADER,
    Pgp4FlatTB,
    collect_valid_beats,
    pgp4_eof_word,
    pgp4_idle_word,
    pgp4_sof_word,
    pgp4_user_word,
    initialize_signals,
    signal_int,
    wait_for_signal,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


async def collect_packet_words(tb: Pgp4FlatTB, *, count: int, cycles: int = 128) -> list[tuple[int, int, int]]:
    return await collect_valid_beats(
        tb,
        valid_name="pktValid",
        field_names=("pktData", "pktLast", "pktUser"),
        count=count,
        cycles=cycles,
    )


async def send_protocol_word(tb: Pgp4FlatTB, *, header: int, data: int):
    """Drive one raw protocol word into the direct `Pgp4RxProtocol` wrapper."""

    tb.dut.protRxHeader.value = header
    tb.dut.protRxData.value = data
    tb.dut.protRxValid.value = 1
    await tb.cycle()


async def train_rx_protocol_link(tb: Pgp4FlatTB, *, cycles: int = 1002):
    """Drive enough good IDLE words for the wrapper to declare link-up."""

    train_word = pgp4_idle_word(rem_link_ready=1)
    for _ in range(cycles):
        await send_protocol_word(tb, header=PGP4_K_HEADER, data=train_word)
    tb.dut.protRxValid.value = 0
    await wait_for_signal(tb, "linkReady", cycles=8)


@cocotb.test()
async def pgp4_rx_protocol_test(dut):
    tb = Pgp4FlatTB(dut)
    initialize_signals(
        dut,
        protRxValid=0,
        protRxHeader=0,
        protRxData=0,
        phyRxActive=1,
        linkErrorIn=0,
        resetRx=0,
        pktReady=1,
    )
    await tb.reset()

    await train_rx_protocol_link(tb)

    meta_word = pgp4_idle_word(rem_link_ready=1, pause_mask=0x1, overflow_mask=0x1)
    await send_protocol_word(tb, header=PGP4_K_HEADER, data=meta_word)
    dut.protRxValid.value = 0
    await tb.cycle(4)
    assert signal_int(dut, "remRxLinkReady") == 1
    assert signal_int(dut, "remPause") == 1
    assert signal_int(dut, "remOverflow") == 1

    opcode = 0x0000CAFEBABE
    await send_protocol_word(tb, header=PGP4_K_HEADER, data=pgp4_user_word(opcode))
    dut.protRxValid.value = 0
    await wait_for_signal(tb, "opCodeEn")
    assert signal_int(dut, "opCodeData") == opcode

    await send_protocol_word(tb, header=PGP4_K_HEADER, data=pgp4_sof_word(vc=0, seq=0x11))
    await send_protocol_word(tb, header=PGP4_D_HEADER, data=0x0123456789ABCDEF)
    await send_protocol_word(tb, header=PGP4_K_HEADER, data=pgp4_eof_word(bytes_last=8, crc=0x11223344))
    dut.protRxValid.value = 0

    words = await collect_packet_words(tb, count=3)
    assert words[0][0] != 0
    assert words[1][0] == 0x0123456789ABCDEF
    assert words[2][1] == 1

PARAMETER_SWEEP = [parameter_case("single_vc_raw_protocol_wrapper")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4RxProtocol(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4rxprotocolwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4RxProtocolWrapper.vhd",
        extra_env=parameters,
    )
