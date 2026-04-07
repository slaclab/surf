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
# - Sweep: Keep the wrapper on one same-clock two-byte configuration with a
#   frame limit of two beats and the timeout path enabled.
# - Stimulus: Send one single-beat frame and one missing-SOF frame through the
#   flat SSI interface while holding the sink continuously ready.
# - Checks: The single-beat frame must pass unchanged, and the missing-SOF
#   frame must be dropped in the IDLE state.
# - Timing: The bench receives complete output frames from the DUT rather than
#   assuming fixed cut-through latency.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    expect_no_output,
    FlatSsiEndpoint,
    SsiBeat,
    recv_frame,
    reset_dut,
    send_contiguous_frame,
    start_clock,
)


@cocotb.test()
async def passes_single_beat_frame_and_drops_missing_sof(dut):
    keep = 0x3

    start_clock(dut.axisClk)
    source = FlatSsiEndpoint(dut, prefix="sAxis")
    sink = FlatSsiEndpoint(dut, prefix="mAxis")
    dut.axisRst.setimmediatevalue(1)
    source.set_idle()
    dut.mAxisTReady.setimmediatevalue(1)
    await reset_dut(dut)

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x0011, keep=keep, last=1, dest=0x2, sof=1),
        ],
        clk=dut.axisClk,
    )
    beats = await recv_frame(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)
    assert [(beat.data, beat.last, beat.sof, beat.eofe) for beat in beats] == [(0x0011, 1, 1, 0)]

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x0101, keep=keep, last=0, dest=0x3),
            SsiBeat(data=0x0202, keep=keep, last=1, dest=0x3),
        ],
        clk=dut.axisClk,
    )
    await expect_no_output(sink, clk=dut.axisClk)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="frame_limit_2")])
def test_SsiFrameLimiter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiframelimiterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiFrameLimiterWrapper.vhd"]},
    )
