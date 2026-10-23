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
# - Sweep: Sweep four flow-control cases across the historical 8B-32B payload set.
# - Stimulus: Send incrementing AXI Stream frames after link-up with optional pause sources.
# - Checks: All received frames must match the transmitted payload.
# - Timing: Traffic begins only after `LINK_READY`.

import cocotb
import pytest

from tests.protocols.pgp.pgp_test_utils import (
    PgpLoopbackTB,
    default_parameter_sweep,
    incrementing_payloads,
    run_pgp_wrapper_test,
)


@cocotb.test()
async def pgp4_core_lite_loopback_test(dut):
    tb = PgpLoopbackTB(dut)
    await tb.reset_and_wait_for_link()
    tb.configure_optional_pauses()
    await tb.run_loopback(incrementing_payloads(range(8, 33, 8)))


PARAMETER_SWEEP = default_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4CoreLite(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4corelitewrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4CoreLiteWrapper.vhd",
        extra_env=parameters,
    )
