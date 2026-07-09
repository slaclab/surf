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
# - Sweep: Run a raw `Pgp4RxProtocol` plus `AxiStreamDepacketizer2` wrapper.
# - Stimulus: Train the protocol link with valid IDLE words, then send one
#   SOF/data/EOF cell whose EOF carries an intentionally wrong frame CRC.
# - Checks: The depacketizer must report an errored frame end while the PGP4
#   link itself remains up, proving that payload CRC errors are handled at the
#   frame/cell layer instead of as link alignment errors.
# - Timing: The bench drives complete 64-bit protocol words directly, so no
#   test-only corruption ports are needed on the integrated RX loopback wrapper.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    PGP4_D_HEADER,
    PGP4_K_HEADER,
    Pgp4FlatTB,
    initialize_signals,
    pgp4_eof_word,
    pgp4_idle_word,
    pgp4_sof_word,
    signal_int,
    wait_for_signal,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test

PAYLOAD_WORD = 0x0123456789ABCDEF
BAD_CELL_CRC = 0x11223344


async def send_protocol_word(tb: Pgp4FlatTB, *, header: int, data: int):
    tb.dut.protRxHeader.value = header
    tb.dut.protRxData.value = data
    tb.dut.protRxValid.value = 1
    await tb.cycle()


async def train_rx_protocol_link(tb: Pgp4FlatTB, *, cycles: int = 1002):
    idle_word = pgp4_idle_word(rem_link_ready=1)
    for _ in range(cycles):
        await send_protocol_word(tb, header=PGP4_K_HEADER, data=idle_word)
    tb.dut.protRxValid.value = 0
    await wait_for_signal(tb, "linkReady", cycles=8)


@cocotb.test()
async def pgp4_rx_crc_error_test(dut):
    tb = Pgp4FlatTB(dut)
    initialize_signals(
        dut,
        phyRxActive=1,
        protRxValid=0,
        protRxHeader=0,
        protRxData=0,
        rxReady=1,
    )
    await tb.reset()
    await train_rx_protocol_link(tb)

    await send_protocol_word(tb, header=PGP4_K_HEADER, data=pgp4_sof_word(vc=0, seq=0))
    await send_protocol_word(tb, header=PGP4_D_HEADER, data=PAYLOAD_WORD)
    await send_protocol_word(tb, header=PGP4_K_HEADER, data=pgp4_eof_word(bytes_last=8, crc=BAD_CELL_CRC))
    dut.protRxValid.value = 0

    await wait_for_signal(tb, "frameRxErr", cycles=512)
    assert signal_int(dut, "linkReady") == 1
    assert signal_int(dut, "linkError") == 0


PARAMETER_SWEEP = [parameter_case("raw_protocol_depacketizer_crc_error")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4RxCrcError(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4rxprotocoldepacketizerwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4RxProtocolDepacketizerWrapper.vhd",
        extra_env=parameters,
    )
