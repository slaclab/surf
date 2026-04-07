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
# - Sweep: Keep the default 32-bit incrementing stream configuration and a
#   same-clock FIFO path so the first pass proves generation order, metadata,
#   and minimum-length clamping.
# - Stimulus: Trigger one four-beat packet and then a second packet with an
#   undersized requested length.
# - Checks: The emitted frame words must follow the generator's seed/length/
#   incrementing-data contract, preserve `TDEST/TID`, and clamp short requests
#   to the module's minimum packet length.
# - Timing: The bench receives whole frames from the DUT and observes `busy`
#   before and after each trigger instead of assuming zero-latency generation.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import FlatSsiEndpoint, recv_frame, reset_dut, start_clock


async def pulse_trigger(dut):
    dut.trig.value = 1
    await cocotb.triggers.RisingEdge(dut.axisClk)
    await cocotb.triggers.Timer(1, unit="ns")
    dut.trig.value = 0


@cocotb.test()
async def emits_incrementing_frames_and_clamps_short_length(dut):
    start_clock(dut.axisClk)
    sink = FlatSsiEndpoint(dut, prefix="mAxis")
    dut.axisRst.setimmediatevalue(1)
    dut.trig.setimmediatevalue(0)
    dut.packetLength.setimmediatevalue(3)
    dut.tDest.setimmediatevalue(0x02)
    dut.tId.setimmediatevalue(0x00)
    dut.mAxisTReady.setimmediatevalue(1)
    await reset_dut(dut)

    await pulse_trigger(dut)
    beats = await recv_frame(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)
    assert [(beat.data, beat.last, beat.sof, beat.dest, beat.tid) for beat in beats] == [
        (0x00000000, 0, 1, 0x02, 0x00),
        (0x00000001, 0, 0, 0x02, 0x00),
        (0x00000002, 1, 0, 0x02, 0x00),
    ]
    assert int(dut.busy.value) == 0

    dut.packetLength.value = 0
    await pulse_trigger(dut)
    beats = await recv_frame(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)
    assert [(beat.data, beat.last, beat.sof) for beat in beats] == [
        (0x00000001, 0, 1),
        (0x00000002, 1, 0),
    ]
    assert int(dut.busy.value) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="default_incrementing_stream")])
def test_SsiIncrementingTx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiincrementingtxwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiIncrementingTxWrapper.vhd"]},
    )
