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
# - Sweep: Keep one checked-in `Pgp4Rx` wrapper that uses an internal `Pgp4Tx`
#   helper to generate real scrambled PHY traffic.
# - Stimulus: Allow the internal link to train, then send one opcode and one
#   single-word frame through the flat transmit side of the wrapper.
# - Checks: `Pgp4Rx` must report link-ready, surface the opcode, and emit the
#   depacketized frame data with `frameRx` asserted.
# - Timing: The bench waits through the built-in startup/training interval and
#   then uses bounded polling for opcode and frame receive visibility.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    Pgp4FlatTB,
    initialize_flat_tx_inputs,
    send_opcode,
    signal_int,
    wait_for_signal,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


async def send_single_word_frame_and_capture(tb: Pgp4FlatTB, *, payload: int, eofe: int = 0) -> tuple[int, int]:
    """Send one beat and capture the first returned RX beat.

    This helper is local because it is tailored to the integrated `Pgp4Rx`
    wrapper's receive-side contract.  The test needs to watch `rxValid` while
    the transmit handshake is still in flight so it does not miss a narrow
    one-cycle output pulse.
    """

    tb.dut.txValid.value = 1
    tb.dut.txData.value = payload
    tb.dut.txSof.value = 1
    tb.dut.txEof.value = 1
    tb.dut.txEofe.value = eofe

    accepted = False
    captured = None
    for _ in range(1024):
        await tb.cycle()
        if signal_int(tb.dut, "rxValid") == 1:
            captured = (
                signal_int(tb.dut, "rxData"),
                signal_int(tb.dut, "rxLast"),
            )
        if not accepted and signal_int(tb.dut, "txReady") == 1:
            accepted = True
            tb.dut.txValid.value = 0
            tb.dut.txSof.value = 0
            tb.dut.txEof.value = 0
            tb.dut.txEofe.value = 0
        if accepted and captured is not None:
            return captured

    raise AssertionError("Timed out waiting for RX frame capture")


@cocotb.test()
async def pgp4_rx_direct_test(dut):
    tb = Pgp4FlatTB(dut)
    initialize_flat_tx_inputs(dut, include_opcode=True)
    await tb.reset()

    await wait_for_signal(tb, "linkReady", cycles=2600)

    await send_opcode(tb, 0x0000ABCDE123)
    await wait_for_signal(tb, "rxOpCodeEn", cycles=512)
    assert signal_int(dut, "rxOpCodeData") == 0x0000ABCDE123

    # The helper samples `rxValid` in the correct cycle so the test does not
    # miss narrow receive pulses after the internal depacketizer fires.
    payload = 0xCAFEBABE01234567
    rx_data, rx_last = await send_single_word_frame_and_capture(tb, payload=payload)
    assert rx_data == payload
    assert rx_last == 1
    assert signal_int(dut, "frameRxErr") == 0


PARAMETER_SWEEP = [parameter_case("integrated_scrambled_rx_wrapper")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4Rx(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4rxwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4RxWrapper.vhd",
        extra_env=parameters,
    )
