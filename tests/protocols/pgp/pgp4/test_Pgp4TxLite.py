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
# - Sweep: Keep the checked-in wrapper's single-lane direct-transmit shape and
#   run one steady-state handshake sequence.
# - Stimulus: Drive one fixed-width frame word with explicit SOF/EOF markers
#   into the native `Pgp4TxLiteWrapper` pin interface.
# - Checks: The wrapper must accept the input beat and produce protocol output
#   on its native 66-bit side.
# - Timing: Reset is released before traffic, and the bench waits a bounded
#   window for the wrapper to accept the beat and emit output.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    Pgp4FlatTB,
    initialize_flat_tx_inputs,
    send_single_word_frame,
    wait_for_nonzero_output,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


@cocotb.test()
async def pgp4_tx_lite_direct_wrapper_test(dut):
    tb = Pgp4FlatTB(dut)
    initialize_flat_tx_inputs(dut)
    dut.phyTxReady.setimmediatevalue(1)
    await tb.reset()
    await send_single_word_frame(tb, payload=0x1122334455667788)

    await wait_for_nonzero_output(tb, valid_name="phyTxValid", data_name="phyTxData", cycles=32)


PARAMETER_SWEEP = [parameter_case("direct_wrapper_default")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4TxLite(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4txlitewrapper",
        wrapper_source="protocols/pgp/pgp4/core/rtl/Pgp4TxLiteWrapper.vhd",
        extra_env=parameters,
    )
