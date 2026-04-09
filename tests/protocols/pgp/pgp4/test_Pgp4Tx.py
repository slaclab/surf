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
# - Sweep: Keep one single-VC direct-transmit wrapper and exercise one steady
#   downstream acceptance sequence.
# - Stimulus: Drive one full-width SSI-style AXI Stream beat into `Pgp4Tx`
#   through a checked-in wrapper with explicit SOF/EOF controls.
# - Checks: The DUT must accept the beat and emit non-zero protocol output on
#   the native 66-bit side.
# - Timing: Reset is released before traffic and the bench waits a bounded
#   window for the transmit output to become valid.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    Pgp4FlatTB,
    initialize_flat_tx_inputs,
    send_single_word_frame,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


@cocotb.test()
async def pgp4_tx_direct_wrapper_test(dut):
    tb = Pgp4FlatTB(dut)
    initialize_flat_tx_inputs(dut)
    dut.phyTxReady.setimmediatevalue(1)
    await tb.reset()
    await send_single_word_frame(tb, payload=0xDEADBEEF12345678)

    # This direct wrapper exposes the encoded 66-bit output.  The first useful
    # sanity check is that a real, non-zero transmit word appears after the
    # frame handshake has completed.
    seen_valid = False
    for _ in range(1400):
        await tb.cycle(1)
        if int(dut.phyTxValid.value) == 1:
            seen_valid = True
            assert int(dut.phyTxData.value) != 0
            break
    assert seen_valid


PARAMETER_SWEEP = [parameter_case("single_vc_direct_tx")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4Tx(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4txdirectwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4TxDirectWrapper.vhd",
        extra_env=parameters,
    )
