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
# - Sweep: Sweep four flow-control cases across a curated 8B-40B payload set.
# - Stimulus: Send incrementing AXI Stream frames after the wrapper reports link-up.
# - Checks: All received frames must match the transmitted payload and packet length.
# - Timing: Traffic begins only after `LINK_READY`, with optional idle pauses and sink backpressure.

import cocotb
import pytest

from tests.protocols.pgp.pgp_test_utils import (
    PgpLoopbackTB,
    default_parameter_sweep,
    incrementing_payloads,
    run_pgp_wrapper_test,
)


@cocotb.test()
async def pgp3_core_loopback_test(dut):
    tb = PgpLoopbackTB(dut)
    await tb.reset_and_wait_for_link()
    tb.configure_optional_pauses()
    await tb.run_loopback(incrementing_payloads(range(8, 41, 8)))


PARAMETER_SWEEP = default_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp3Core(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp3corewrapper",
        wrapper_source="protocols/pgp/pgp3/core/wrappers/Pgp3CoreWrapper.vhd",
        extra_env=parameters,
    )
