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
# - Sweep: Cover a small two-case wrapper matrix across 16-bit and 32-bit SSI
#   lanes with a two-beat frame limit.
# - Stimulus: Send a valid short frame, an over-limit frame, a repeated-SOF
#   malformed frame, a missing-SOF frame, and one stalled frame that relies on
#   the wrapper's enabled timeout path.
# - Checks: Good traffic must pass unchanged, over-limit and repeated-SOF
#   cases must terminate early with `EOFE`, missing-SOF traffic must be
#   dropped, and the timeout path must eventually emit a terminal `EOFE` beat
#   and return the DUT to idle for the next frame.
# - Timing: The bench mixes whole-frame receives with bounded no-output waits
#   so the checks prove both frame policy and the enabled timeout behavior
#   without assuming fixed internal latency.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    assert_beat_views,
    cycle,
    env_data_bytes,
    env_int,
    expect_no_output,
    keep_mask,
    recv_n_beats_and_check,
    recv_visible_beat,
    SsiBeat,
    send_contiguous_frame,
    setup_flat_ssi_testbench,
    wait_output_clear,
)


@cocotb.test()
async def enforces_frame_limit_and_timeout_policy(dut):
    data_bytes = env_data_bytes(default=2)
    frame_limit = env_int("FRAME_LIMIT_G", default=2)
    keep = keep_mask(data_bytes)

    # Set up the shared SSI clock plus one source and one sink endpoint around
    # the flattened wrapper signals.
    bench = await setup_flat_ssi_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={"mAxisTReady": 1},
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    # A short legal frame should pass through unchanged.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x0011, keep=keep, last=1, dest=0x2, sof=1),
        ],
        clk=bench.clk,
    )
    beats = [await recv_visible_beat(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)]
    assert_beat_views(
        beats,
        fields=("data", "last", "sof", "eofe"),
        expected=[(0x0011, 1, 1, 0)],
    )
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, cycles=8)

    # Build a frame that is one beat too long. The limiter should forward data
    # until the limit and then terminate the frame with `EOFE`.
    over_limit_payload = [0x1101 + index for index in range(frame_limit + 1)]
    await send_contiguous_frame(
        source,
        [
            SsiBeat(
                data=word,
                keep=keep,
                last=1 if index == len(over_limit_payload) - 1 else 0,
                dest=0x3,
                sof=1 if index == 0 else 0,
            )
            for index, word in enumerate(over_limit_payload)
        ],
        clk=bench.clk,
    )
    beats = await recv_n_beats_and_check(
        sink,
        clk=bench.clk,
        count=2,
        ready_signal=dut.mAxisTReady,
        fields=("data", "last", "eofe"),
        expected=[
            (over_limit_payload[0], 0, 0),
            (over_limit_payload[1], 1, 1),
        ],
    )
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, cycles=8)
    await expect_no_output(sink, clk=bench.clk)

    # A repeated `SOF` is a framing violation, so the limiter should terminate
    # the frame on the violating beat with `EOFE`.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x2201, keep=keep, last=0, dest=0x4, sof=1),
            SsiBeat(data=0x2202, keep=keep, last=0, dest=0x4, sof=1),
            SsiBeat(data=0x2203, keep=keep, last=1, dest=0x4),
        ],
        clk=bench.clk,
    )
    await recv_n_beats_and_check(
        sink,
        clk=bench.clk,
        count=2,
        ready_signal=dut.mAxisTReady,
        fields=("data", "last", "sof", "eofe"),
        expected=[
            (0x2201, 0, 1, 0),
            (0x2202, 1, 1, 1),
        ],
    )
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, cycles=8)
    await expect_no_output(sink, clk=bench.clk)

    # Frames that never begin with `SOF` should be dropped completely.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x0101, keep=keep, last=0, dest=0x5),
            SsiBeat(data=0x0202, keep=keep, last=1, dest=0x5),
        ],
        clk=bench.clk,
    )
    await expect_no_output(sink, clk=bench.clk)
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, cycles=8)

    # The timeout path is easiest to see by sending only the first beat with
    # `last=0` and then waiting for the limiter to synthesize the terminal beat.
    await source.send(
        SsiBeat(data=0x3301, keep=keep, last=0, dest=0x6, sof=1),
        clk=bench.clk,
    )
    await recv_n_beats_and_check(
        sink,
        clk=bench.clk,
        count=2,
        ready_signal=dut.mAxisTReady,
        fields=("data", "last", "sof", "eofe"),
        expected=[
            (0x3301, 0, 1, 0),
            (0x3301, 1, 1, 1),
        ],
    )
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, cycles=8)

    await cycle(bench.clk, 2)
    assert int(dut.mAxisTValid.value) == 0

    # After a timeout recovery, the module should still accept the next clean
    # one-beat frame.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x4401, keep=keep, last=1, dest=0x7, sof=1),
        ],
        clk=bench.clk,
    )
    beats = [await recv_visible_beat(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)]
    assert_beat_views(
        beats,
        fields=("data", "last", "sof", "eofe"),
        expected=[(0x4401, 1, 1, 0)],
    )
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)


PARAMETER_SWEEP = [
    pytest.param({"DATA_BYTES_G": "2", "FRAME_LIMIT_G": "2"}, id="frame_limit_2_data_2"),
    pytest.param({"DATA_BYTES_G": "4", "FRAME_LIMIT_G": "2"}, id="frame_limit_2_data_4"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiFrameLimiter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiframelimiterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiFrameLimiterWrapper.vhd"]},
    )
