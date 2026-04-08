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
# - Sweep: Cover a curated two-case matrix across the normal
#   `SLAVE_READY_EN_G=true` path and the overflow-capable
#   `SLAVE_READY_EN_G=false` path.
# - Stimulus: Drive one valid multi-beat frame, one missing-SOF frame, one
#   interleaved-`TDEST` frame, one repeated-`SOF` frame, and one sink-stalled
#   overflow sequence through the flat SSI wrapper.
# - Checks: Valid traffic must pass unchanged, missing-SOF traffic must be
#   dropped, `TDEST` and repeated-`SOF` violations must terminate on the
#   violating beat with `EOFE`, and the no-ready overflow path must strobe the
#   drop flags and emit a terminal `EOFE` beat when the sink is released.
# - Timing: The sink is held not-ready on the first visible beat of accepted
#   frames so the wrapper contract proves stable outputs before consumption,
#   while overflow-specific checks wait on explicit flag pulses instead of
#   fixed-cycle assumptions.

import cocotb
import pytest

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    assert_beat_list,
    cycle,
    env_data_bytes,
    expect_no_output,
    expect_no_output_data,
    FlatSsiEndpoint,
    keep_mask,
    recv_expected_beat,
    recv_frame_by_data,
    recv_visible_beat,
    reset_dut,
    send_contiguous_frame,
    SsiBeat,
    start_clock,
    wait_signal_pulse,
)


@cocotb.test()
async def ssi_ib_frame_filter_test(dut):
    data_bytes = env_data_bytes(default=2)
    slave_ready_en = env_flag("SLAVE_READY_EN_G", default=True)
    keep = keep_mask(data_bytes)

    start_clock(dut.axisClk, period_ns=5.0)

    source = FlatSsiEndpoint(dut, prefix="sAxis")
    sink = FlatSsiEndpoint(dut, prefix="mAxis")

    source.set_idle()
    dut.mAxisTReady.setimmediatevalue(0 if slave_ready_en else 1)
    await reset_dut(dut)

    if slave_ready_en:
        valid_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x1111, keep=keep, last=0, dest=0x4, sof=1),
                    SsiBeat(data=0x2222, keep=keep, last=1, dest=0x4),
                ],
                clk=dut.axisClk,
            )
        )
        first = await sink.wait_valid(clk=dut.axisClk)
        assert_beat_list(
            [first],
            [SsiBeat(data=0x1111, keep=keep, last=0, dest=0x4, sof=1, eofe=0)],
        )
        frame = await recv_frame_by_data(
            sink,
            clk=dut.axisClk,
            ready_signal=dut.mAxisTReady,
            expected_data=[0x1111, 0x2222],
        )
        await valid_send
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0x1111, keep=keep, last=0, dest=0x4, sof=1, eofe=0),
                SsiBeat(data=0x2222, keep=keep, last=1, dest=0x4, sof=0, eofe=0),
            ],
        )
        dut.mAxisTReady.value = 0
    else:
        await send_contiguous_frame(
            source,
            [SsiBeat(data=0x1111, keep=keep, last=1, dest=0x4, sof=1)],
            clk=dut.axisClk,
        )
        beat = await recv_expected_beat(
            sink,
            clk=dut.axisClk,
            ready_signal=dut.mAxisTReady,
            expected_data=0x1111,
        )
        assert_beat_list(
            [beat],
            [SsiBeat(data=0x1111, keep=keep, last=1, dest=0x4, sof=1, eofe=0)],
        )
    dut.mAxisTReady.value = 0

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x3333, keep=keep, last=0, dest=0x1, sof=0),
            SsiBeat(data=0x4444, keep=keep, last=1, dest=0x1),
        ],
        clk=dut.axisClk,
    )
    await expect_no_output(sink, clk=dut.axisClk)
    if slave_ready_en:
        tdest_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x5555, keep=keep, last=0, dest=0x2, sof=1),
                    SsiBeat(data=0x6666, keep=keep, last=0, dest=0x3),
                    SsiBeat(data=0x7777, keep=keep, last=1, dest=0x3),
                ],
                clk=dut.axisClk,
            )
        )
        first = await sink.wait_valid(clk=dut.axisClk)
        frame = await recv_frame_by_data(
            sink,
            clk=dut.axisClk,
            ready_signal=dut.mAxisTReady,
            expected_data=[0x5555, 0x6666],
        )
        await tdest_send
        assert first.data == 0x5555
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0x5555, keep=keep, last=0, dest=0x2, sof=1, eofe=0),
                SsiBeat(data=0x6666, keep=keep, last=1, dest=0x3, sof=0, eofe=1),
            ],
        )
        await expect_no_output_data(sink, clk=dut.axisClk, forbidden_data=0x7777)

        repeated_sof_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x8881, keep=keep, last=0, dest=0x5, sof=1),
                    SsiBeat(data=0x8882, keep=keep, last=0, dest=0x5, sof=1),
                    SsiBeat(data=0x8883, keep=keep, last=1, dest=0x5),
                ],
                clk=dut.axisClk,
            )
        )
        first = await sink.wait_valid(clk=dut.axisClk)
        frame = await recv_frame_by_data(
            sink,
            clk=dut.axisClk,
            ready_signal=dut.mAxisTReady,
            expected_data=[0x8881, 0x8882],
        )
        await repeated_sof_send
        assert first.data == 0x8881
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0x8881, keep=keep, last=0, dest=0x5, sof=1, eofe=0),
                SsiBeat(data=0x8882, keep=keep, last=1, dest=0x5, sof=0, eofe=1),
            ],
        )
        await expect_no_output_data(sink, clk=dut.axisClk, forbidden_data=0x8883)
    else:
        dut.mAxisTReady.value = 0
        overflow_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x9991, keep=keep, last=0, dest=0x6, sof=1),
                    SsiBeat(data=0x9992, keep=keep, last=0, dest=0x6),
                    SsiBeat(data=0x9993, keep=keep, last=1, dest=0x6),
                ],
                clk=dut.axisClk,
            )
        )
        first = await sink.wait_valid(clk=dut.axisClk)
        assert first.data == 0x9991
        await wait_signal_pulse(dut.sAxisDropWord, clk=dut.axisClk)
        await wait_signal_pulse(dut.sAxisDropFrame, clk=dut.axisClk)
        first = await recv_expected_beat(
            sink,
            clk=dut.axisClk,
            ready_signal=dut.mAxisTReady,
            expected_data=0x9991,
        )
        terminal = await recv_visible_beat(
            sink,
            clk=dut.axisClk,
            ready_signal=dut.mAxisTReady,
        )
        await overflow_send
        assert first.last == 0
        assert first.sof == 1
        assert first.eofe == 0
        assert terminal.last == 1
        assert terminal.sof == 0
        assert terminal.eofe == 1
        await expect_no_output_data(sink, clk=dut.axisClk, forbidden_data=0x9993)


PARAMETER_SWEEP = [
    parameter_case(
        "default_configuration",
        DATA_BYTES_G="2",
        SLAVE_READY_EN_G="true",
    ),
    parameter_case(
        "overflow_no_slave_ready",
        DATA_BYTES_G="2",
        SLAVE_READY_EN_G="false",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiIbFrameFilter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiibframefilterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiIbFrameFilterWrapper.vhd"]},
    )
