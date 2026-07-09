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
# - Sweep: Sweep the shared four pause/backpressure cases across a 1B-9B
#   payload set on a single-VC `Pgp2fcLane` loopback wrapper.
# - Stimulus: Send incrementing SSI/AXI Stream frames after link-up.
# - Checks: The looped-back frames must match byte-for-byte.
# - Timing: Traffic starts only after the wrapper reports `LINK_READY`.

import cocotb
import pytest

from tests.protocols.pgp.pgp_test_utils import (
    PgpLoopbackTB,
    default_parameter_sweep,
    incrementing_payloads,
    pgp_family_sources,
    run_pgp_wrapper_test,
)


@cocotb.test()
async def pgp2fc_lane_loopback_test(dut):
    tb = PgpLoopbackTB(dut)
    await tb.reset_and_wait_for_link()
    tb.configure_optional_pauses()
    await tb.run_loopback(incrementing_payloads(range(1, 10)))


PARAMETER_SWEEP = default_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp2fcLane(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fclanewrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcLaneWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
        extra_env=parameters,
    )
