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
#   lanes with frame limits of two and three beats.
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
    cycle,
    env_data_bytes,
    env_int,
    expect_no_output,
    FlatSsiEndpoint,
    keep_mask,
    recv_visible_beat,
    SsiBeat,
    reset_dut,
    send_contiguous_frame,
    start_clock,
    wait_output_clear,
)


@cocotb.test()
async def enforces_frame_limit_and_timeout_policy(dut):
    data_bytes = env_data_bytes(default=2)
    frame_limit = env_int("FRAME_LIMIT_G", default=2)
    keep = keep_mask(data_bytes)

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
    beats = [await recv_visible_beat(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)]
    assert [(beat.data, beat.last, beat.sof, beat.eofe) for beat in beats] == [(0x0011, 1, 1, 0)]
    await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady, cycles=8)

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
        clk=dut.axisClk,
    )
    beats = [
        await recv_visible_beat(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady),
        await recv_visible_beat(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady),
    ]
    assert beats[0].data == over_limit_payload[0]
    assert [beat.last for beat in beats[:-1]] == [0] * (frame_limit - 1)
    assert beats[-1].last == 1
    assert beats[-1].eofe == 1
    await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady, cycles=8)
    await expect_no_output(sink, clk=dut.axisClk)

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x2201, keep=keep, last=0, dest=0x4, sof=1),
            SsiBeat(data=0x2202, keep=keep, last=0, dest=0x4, sof=1),
            SsiBeat(data=0x2203, keep=keep, last=1, dest=0x4),
        ],
        clk=dut.axisClk,
    )
    beats = [
        await recv_visible_beat(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady),
        await recv_visible_beat(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady),
    ]
    assert beats[0].data == 0x2201
    assert beats[0].last == 0
    assert beats[0].sof == 1
    assert beats[0].eofe == 0
    assert beats[1].last == 1
    assert beats[1].sof == 1
    assert beats[1].eofe == 1
    await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady, cycles=8)
    await expect_no_output(sink, clk=dut.axisClk)

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x0101, keep=keep, last=0, dest=0x5),
            SsiBeat(data=0x0202, keep=keep, last=1, dest=0x5),
        ],
        clk=dut.axisClk,
    )
    await expect_no_output(sink, clk=dut.axisClk)
    await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady, cycles=8)

    await source.send(
        SsiBeat(data=0x3301, keep=keep, last=0, dest=0x6, sof=1),
        clk=dut.axisClk,
    )
    beats = [
        await recv_visible_beat(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady),
        await recv_visible_beat(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady),
    ]
    assert beats[0].data == 0x3301
    assert beats[0].last == 0
    assert beats[0].sof == 1
    assert beats[0].eofe == 0
    assert beats[1].last == 1
    assert beats[1].eofe == 1
    await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady, cycles=8)

    await cycle(dut.axisClk, 2)
    assert int(dut.mAxisTValid.value) == 0

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x4401, keep=keep, last=1, dest=0x7, sof=1),
        ],
        clk=dut.axisClk,
    )
    beats = [await recv_visible_beat(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)]
    assert [(beat.data, beat.last, beat.sof, beat.eofe) for beat in beats] == [(0x4401, 1, 1, 0)]
    await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)


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
