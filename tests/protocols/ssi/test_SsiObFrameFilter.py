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
# - Sweep: Cover a curated three-case same-clock wrapper matrix across the
#   normal `VALID_THOLD_G=1` path, one pipelined `PIPE_STAGES_G=2` pass-through
#   path, and the cached-last-user `VALID_THOLD_G=0` path.
# - Stimulus: Drive one well-formed frame, one missing-SOF frame, one
#   interleaved-`TDEST` frame, one repeated-`SOF` frame, and one cached-EOFE
#   frame through the flat SSI wrapper contract.
# - Checks: Good traffic must pass unchanged, missing-SOF traffic must be
#   dropped, `TDEST` and repeated-`SOF` violations must terminate on the
#   violating beat with `EOFE`, and the cached-EOFE path must drop the frame
#   before any output becomes visible while strobing the exported drop flags.
# - Timing: The bench samples the first visible beat while the sink is stalled,
#   then consumes the frame one accepted transfer at a time so the checks stay
#   aligned with wrapper-visible framing policy instead of fixed latency.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    assert_beat_view,
    cycle,
    env_data_bytes,
    env_int,
    expect_no_output,
    expect_no_output_data,
    keep_mask,
    recv_expected_beat,
    send_contiguous_frame,
    setup_flat_ssi_testbench,
    SsiBeat,
    wait_output_clear,
    wait_signal_pulse,
)


@cocotb.test()
async def ssi_ob_frame_filter_test(dut):
    data_bytes = env_data_bytes(default=2)
    valid_thold = env_int("VALID_THOLD_G", default=1)
    keep = keep_mask(data_bytes)

    # The outbound filter bench keeps the sink stalled first so it can inspect
    # each visible beat before deciding when to accept it.
    bench = await setup_flat_ssi_testbench(
        dut,
        period_ns=5.0,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={"sTLastEofe": 0, "mAxisTReady": 0},
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    # A well-formed frame should appear unchanged at the output.
    good_send = cocotb.start_soon(
        send_contiguous_frame(
            source,
            [
                SsiBeat(data=0x1111, keep=keep, last=0, dest=0x2, sof=1),
                SsiBeat(data=0x2222, keep=keep, last=1, dest=0x2),
            ],
            clk=bench.clk,
        )
    )
    first = await sink.wait_valid(clk=bench.clk)
    assert_beat_view(
        first,
        fields=("data", "keep", "last", "dest", "sof", "eofe"),
        expected=(0x1111, keep, 0, 0x2, 1, 0),
    )
    second = await recv_expected_beat(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, expected_data=0x2222)
    await good_send
    assert_beat_view(
        second,
        fields=("data", "keep", "last", "dest", "sof", "eofe"),
        expected=(0x2222, keep, 1, 0x2, 0, 0),
    )
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)

    # Missing-SOF traffic is invalid and should never become visible.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x3001, keep=keep, last=0, dest=0x1),
            SsiBeat(data=0x3002, keep=keep, last=1, dest=0x1),
        ],
        clk=bench.clk,
    )
    await expect_no_output(sink, clk=bench.clk)

    # A mid-frame `TDEST` change should terminate the frame on the violating
    # beat with `EOFE` in both cached and non-cached modes.
    tdest_send = cocotb.start_soon(
        send_contiguous_frame(
            source,
            [
                SsiBeat(data=0x5001, keep=keep, last=0, dest=0x4, sof=1),
                SsiBeat(data=0x5002, keep=keep, last=0, dest=0x5),
                SsiBeat(data=0x5003, keep=keep, last=1, dest=0x5),
            ],
            clk=bench.clk,
        )
    )
    first = await sink.wait_valid(clk=bench.clk)
    second = await recv_expected_beat(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, expected_data=0x5002)
    await tdest_send
    assert_beat_view(
        first,
        fields=("data", "last", "dest", "sof", "eofe"),
        expected=(0x5001, 0, 0x4, 1, 0),
    )
    assert_beat_view(
        second,
        fields=("data", "last", "dest", "sof", "eofe"),
        expected=(0x5002, 1, 0x5, 0, 1),
    )
    await expect_no_output_data(sink, clk=bench.clk, forbidden_data=0x5003)
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)

    # Repeating `SOF` mid-frame should produce the same kind of early
    # termination in both modes.
    repeated_sof_send = cocotb.start_soon(
        send_contiguous_frame(
            source,
            [
                SsiBeat(data=0x6001, keep=keep, last=0, dest=0x6, sof=1),
                SsiBeat(data=0x6002, keep=keep, last=0, dest=0x6, sof=1),
                SsiBeat(data=0x6003, keep=keep, last=1, dest=0x6),
            ],
            clk=bench.clk,
        )
    )
    first = await sink.wait_valid(clk=bench.clk)
    second = await recv_expected_beat(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, expected_data=0x6002)
    await repeated_sof_send
    assert_beat_view(
        first,
        fields=("data", "last", "dest", "sof", "eofe"),
        expected=(0x6001, 0, 0x6, 1, 0),
    )
    assert_beat_view(
        second,
        fields=("data", "last", "dest", "sof", "eofe"),
        expected=(0x6002, 1, 0x6, 0, 1),
    )
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)

    if valid_thold == 0:
        # In the cached-last-user path, an `EOFE` indication on the terminal
        # source beat should suppress the frame before any output appears.
        dut.sTLastEofe.value = 1
        await send_contiguous_frame(
            source,
            [
                SsiBeat(data=0x4001, keep=keep, last=1, dest=0x3, sof=1),
            ],
            clk=bench.clk,
        )
        dut.sTLastEofe.value = 0
        await wait_signal_pulse(dut.mAxisDropWord, clk=bench.clk)
        await wait_signal_pulse(dut.mAxisDropFrame, clk=bench.clk)
        await expect_no_output(sink, clk=bench.clk)

    # Leave a short idle window so delayed stray output would still fail here.
    await cycle(bench.clk, 2)
    assert int(dut.mAxisTValid.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "default_configuration",
        DATA_BYTES_G="2",
        VALID_THOLD_G="1",
        PIPE_STAGES_G="0",
    ),
    parameter_case(
        "cached_last_user_path",
        DATA_BYTES_G="2",
        VALID_THOLD_G="0",
        PIPE_STAGES_G="0",
    ),
    parameter_case(
        "pipelined_default_path",
        DATA_BYTES_G="2",
        VALID_THOLD_G="1",
        PIPE_STAGES_G="2",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiObFrameFilter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiobframefilterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiObFrameFilterWrapper.vhd"]},
    )
