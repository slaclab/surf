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
# - Sweep: Cover a curated four-case same-clock FIFO matrix across normal
#   streaming, frame-ready release, threshold release (`VALID_THOLD_G=2`), and
#   the source-overflow `SLAVE_READY_EN_G=false` path.
# - Stimulus: Drive good single-beat frames, a missing-SOF frame, and
#   threshold/overflow-specific buffered traffic while
#   varying sink readiness and pause threshold settings.
# - Checks: Good frames must emerge intact, missing-SOF traffic must be
#   dropped, and the
#   threshold/overflow paths must expose wrapper-visible occupancy, pause, and
#   terminal-frame behavior without lockup resets.
# - Timing: The bench captures accepted beats by payload value and waits on
#   explicit counter or drop-flag transitions so the regression proves FIFO
#   gating behavior instead of relying on fixed-latency assumptions.

import cocotb
import pytest

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    assert_beat_list,
    cycle,
    env_data_bytes,
    env_int,
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
    wait_output_clear,
    wait_signal_level,
)


@cocotb.test()
async def ssi_fifo_test(dut):
    data_bytes = env_data_bytes(default=2)
    valid_thold = env_int("VALID_THOLD_G", default=1)
    slave_ready_en = env_flag("SLAVE_READY_EN_G", default=True)
    keep = keep_mask(data_bytes)

    start_clock(dut.axisClk, period_ns=5.0)

    source = FlatSsiEndpoint(dut, prefix="sAxis")
    sink = FlatSsiEndpoint(dut, prefix="mAxis")

    dut.axisRst.setimmediatevalue(1)
    source.set_idle()
    dut.fifoPauseThresh.setimmediatevalue(3)
    dut.mAxisTReady.setimmediatevalue(0)
    await reset_dut(dut)

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x1111, keep=keep, last=1, dest=0x2, sof=1),
        ],
        clk=dut.axisClk,
    )
    frame = await recv_frame_by_data(
        sink,
        clk=dut.axisClk,
        ready_signal=dut.mAxisTReady,
        expected_data=[0x1111],
    )
    assert_beat_list(
        frame,
        [
            SsiBeat(data=0x1111, keep=keep, last=1, dest=0x2, sof=1, eofe=0),
        ],
    )
    await wait_signal_level(dut.fifoWrCnt, clk=dut.axisClk, expected=0, cycles=64)
    await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)
    assert int(dut.lockupRstEvent.value) == 0

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x6666, keep=keep, last=0, dest=0x3),
            SsiBeat(data=0x7777, keep=keep, last=1, dest=0x3),
        ],
        clk=dut.axisClk,
    )
    await expect_no_output(sink, clk=dut.axisClk)
    await wait_signal_level(dut.fifoWrCnt, clk=dut.axisClk, expected=0, cycles=64)

    if valid_thold == 0:
        delayed_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x9901, keep=keep, last=1, dest=0x4, sof=1),
                ],
                clk=dut.axisClk,
            )
        )
        await cycle(dut.axisClk, 2)
        assert int(dut.mAxisTValid.value) == 0
        dut.mAxisTReady.value = 1
        frame = await recv_frame_by_data(
            sink,
            clk=dut.axisClk,
            ready_signal=dut.mAxisTReady,
            expected_data=[0x9901],
        )
        await delayed_send
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0x9901, keep=keep, last=1, dest=0x4, sof=1, eofe=0),
            ],
        )
        await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)
    elif valid_thold == 2:
        dut.fifoPauseThresh.value = 1
        threshold_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0xA001, keep=keep, last=1, dest=0x6, sof=1),
                ],
                clk=dut.axisClk,
            )
        )
        await cycle(dut.axisClk, 2)
        assert int(dut.mAxisTValid.value) == 0
        dut.fifoPauseThresh.value = 3
        frame = await recv_frame_by_data(
            sink,
            clk=dut.axisClk,
            ready_signal=dut.mAxisTReady,
            expected_data=[0xA001],
        )
        await threshold_send
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0xA001, keep=keep, last=1, dest=0x6, sof=1, eofe=0),
            ],
        )
        await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)
    elif not slave_ready_en:
        overflow_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0xB001, keep=keep, last=0, dest=0x7, sof=1),
                    SsiBeat(data=0xB002, keep=keep, last=0, dest=0x7),
                    SsiBeat(data=0xB003, keep=keep, last=1, dest=0x7),
                ],
                clk=dut.axisClk,
            )
        )
        first = await recv_expected_beat(
            sink,
            clk=dut.axisClk,
            ready_signal=dut.mAxisTReady,
            expected_data=0xB001,
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
        await expect_no_output_data(sink, clk=dut.axisClk, forbidden_data=0xB003)

    assert int(dut.lockupRstEvent.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "default_configuration",
        DATA_BYTES_G="2",
        FIFO_ADDR_WIDTH_G="4",
        VALID_THOLD_G="1",
        SLAVE_READY_EN_G="true",
    ),
    parameter_case(
        "frame_ready_release",
        DATA_BYTES_G="2",
        FIFO_ADDR_WIDTH_G="4",
        VALID_THOLD_G="0",
        SLAVE_READY_EN_G="true",
    ),
    parameter_case(
        "threshold_release",
        DATA_BYTES_G="2",
        FIFO_ADDR_WIDTH_G="4",
        VALID_THOLD_G="2",
        SLAVE_READY_EN_G="true",
    ),
    parameter_case(
        "overflow_no_slave_ready",
        DATA_BYTES_G="2",
        FIFO_ADDR_WIDTH_G="4",
        VALID_THOLD_G="1",
        SLAVE_READY_EN_G="false",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiFifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssififowrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiFifoWrapper.vhd"]},
    )
