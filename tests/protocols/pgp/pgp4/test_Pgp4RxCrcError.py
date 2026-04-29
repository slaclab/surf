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
# - Sweep: Keep one checked-in `Pgp4Rx` wrapper with the integrated `Pgp4Tx`
#   traffic source and the new one-shot corruption hook disabled by default.
# - Stimulus: Arm the corruption hook, then send one valid single-word frame so
#   one 64-bit data beat is flipped after TX formatting but before RX checking.
# - Checks: The integrated receive path must flag `frameRxErr` while staying
#   link-up, which proves CRC-style rejection beyond the standalone CRC blocks.
#   A separate test flips one control word after TX formatting and checks that
#   the no-elastic-buffer RX path reports a link error instead of accepting the
#   bad K-code.
# - Timing: The corruption hook only touches the first transmitted data word of
#   the next frame, so the injected error is deterministic.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    Pgp4FlatTB,
    initialize_flat_tx_inputs,
    initialize_signals,
    send_single_word_frame,
    signal_int,
    wait_for_signal,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


@cocotb.test()
async def pgp4_rx_crc_error_test(dut):
    tb = Pgp4FlatTB(dut)
    initialize_flat_tx_inputs(dut, include_opcode=True)
    initialize_signals(dut, corruptArm=0, corruptMask=0)
    await tb.reset()
    await wait_for_signal(tb, "linkReady", cycles=2600)

    dut.corruptMask.value = 0x1
    dut.corruptArm.value = 1
    await tb.cycle()
    dut.corruptArm.value = 0

    await send_single_word_frame(tb, payload=0x0123456789ABCDEF)
    await wait_for_signal(tb, "corruptBusy", value=0, cycles=64)
    await wait_for_signal(tb, "frameRxErr", cycles=512)
    assert int(dut.linkReady.value) == 1


@cocotb.test()
async def pgp4_rx_bad_kcode_csc_error_test(dut):
    tb = Pgp4FlatTB(dut)
    initialize_flat_tx_inputs(dut, include_opcode=True)
    initialize_signals(
        dut,
        corruptArm=0,
        corruptMask=0,
        corruptKCodeArm=0,
        corruptKCodeMask=0,
    )
    await tb.reset()
    await wait_for_signal(tb, "linkReady", cycles=2600)

    dut.corruptKCodeMask.value = 0x1
    dut.corruptKCodeArm.value = 1
    await tb.cycle()
    dut.corruptKCodeArm.value = 0

    saw_error = False
    for _ in range(512):
        await tb.cycle()
        if signal_int(dut, "linkError") == 1:
            saw_error = True
            break

    assert saw_error, "RX did not report linkError after bad K-code CSC"


PARAMETER_SWEEP = [parameter_case("integrated_scrambled_rx_wrapper_crc_error")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4RxCrcError(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4rxwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4RxWrapper.vhd",
        extra_env=parameters,
    )
