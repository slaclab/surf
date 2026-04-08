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
from tests.protocols.ssi.ssi_test_utils import (
    capture_accepted_beats,
    expect_no_output,
    assert_beat_views,
    recv_frame_and_check,
    setup_flat_ssi_testbench,
    wait_signal_level,
    wait_output_clear,
)


async def pulse_trigger(dut):
    # Pulse the packet trigger for one cycle, matching how software would kick
    # the generator in hardware.
    dut.trig.value = 1
    await cocotb.triggers.RisingEdge(dut.axisClk)
    await cocotb.triggers.Timer(1, unit="ns")
    dut.trig.value = 0


@cocotb.test()
async def emits_incrementing_frames_and_clamps_short_length(dut):
    # This generator only has a sink side from the bench's perspective, so the
    # test watches the outgoing SSI stream and a few control/status ports.
    bench = await setup_flat_ssi_testbench(
        dut,
        sink_prefix="mAxis",
        initial_values={
            "trig": 0,
            "packetLength": 3,
            "tDest": 0x02,
            "tId": 0x00,
            "mAxisTReady": 1,
        },
    )
    sink = bench.sink
    assert sink is not None

    # First prove the nominal packet format and metadata on a requested
    # four-beat packet.
    recv_task = cocotb.start_soon(
        recv_frame_and_check(
            sink,
            clk=bench.clk,
            ready_signal=dut.mAxisTReady,
            fields=("data", "last", "sof", "dest", "tid"),
            expected=[
                (0x00000000, 0, 1, 0x02, 0x00),
                (0x00000003, 0, 0, 0x02, 0x00),
                (0x00000001, 0, 0, 0x02, 0x00),
                (0x00000002, 1, 0, 0x02, 0x00),
            ],
        )
    )
    # The `busy` flag should assert while the DUT is actively producing the
    # frame and return low once the sink has accepted it all.
    await pulse_trigger(dut)
    await wait_signal_level(dut.busy, clk=bench.clk, expected=1, cycles=8)
    await recv_task
    assert int(dut.busy.value) == 0

    # A too-small requested length should clamp up to the module's minimum
    # packet size rather than producing an empty or malformed frame.
    dut.packetLength.value = 0
    recv_task = cocotb.start_soon(
        recv_frame_and_check(
            sink,
            clk=bench.clk,
            ready_signal=dut.mAxisTReady,
            fields=("data", "last", "sof"),
            expected=[
                (0x00000001, 0, 1),
                (0x00000002, 0, 0),
                (0x00000002, 1, 0),
            ],
        )
    )
    await pulse_trigger(dut)
    await recv_task
    assert int(dut.busy.value) == 0
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)

    # Finally, hold the sink not-ready so a second trigger arrives while the
    # first frame is still blocked. The DUT should finish the visible frame
    # cleanly without leaking extra traffic.
    dut.packetLength.value = 3
    dut.mAxisTReady.value = 0
    await pulse_trigger(dut)
    await wait_signal_level(dut.busy, clk=bench.clk, expected=1, cycles=8)
    await pulse_trigger(dut)
    capture_task = cocotb.start_soon(capture_accepted_beats(sink, clk=bench.clk, cycles=16))
    dut.mAxisTReady.value = 1
    beats = await capture_task
    assert_beat_views(
        beats,
        fields=("data", "last", "sof"),
        expected=[
            (0x00000002, 0, 1),
            (0x00000003, 0, 0),
            (0x00000003, 0, 0),
            (0x00000004, 1, 0),
        ],
    )
    await expect_no_output(sink, clk=bench.clk)
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
