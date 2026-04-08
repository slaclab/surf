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
# - Sweep: Cover a curated three-case same-clock FIFO matrix across normal
#   streaming, frame-ready release, and threshold release (`VALID_THOLD_G=2`).
# - Stimulus: Drive good single-beat frames, a missing-SOF frame, and
#   threshold-specific buffered traffic while varying sink readiness and pause
#   threshold settings.
# - Checks: Good frames must emerge intact, missing-SOF traffic must be
#   dropped, and the threshold-specific cases must preserve the stable
#   single-beat path while exposing wrapper-visible FIFO occupancy and pause
#   gating behavior.
# - Timing: The bench samples `TVALID`, `TREADY`, and `fifoWrCnt` between beat
#   transfers so the regression proves wrapper-visible FIFO gating behavior
#   instead of only end-state payload contents.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    SsiBeat,
    cycle,
    env_data_bytes,
    env_int,
    expect_no_output,
    keep_mask,
    reset_dut,
    send_contiguous_frame,
    send_frame,
    start_clock,
)


async def wait_count_zero(signal, clk, cycles=64):
    for _ in range(cycles):
        await cycle(clk)
        if int(signal.value) == 0:
            return
    raise AssertionError("Timed out waiting for fifoWrCnt to return to zero")


async def recv_expected_beat(sink, dut, expected_data):
    dut.mAxisTReady.value = 1
    last_seen = None
    for _ in range(64):
        await cycle(dut.axisClk)
        if int(dut.mAxisTValid.value) == 1:
            beat = sink.snapshot()
            last_seen = beat
            if beat.data == expected_data:
                return beat
    raise AssertionError(f"Timed out waiting for SSI output data 0x{expected_data:04x}, last_seen={last_seen}")


async def wait_output_clear(dut, cycles=16):
    dut.mAxisTReady.value = 1
    for _ in range(cycles):
        await cycle(dut.axisClk)
        if int(dut.mAxisTValid.value) == 0:
            dut.mAxisTReady.value = 0
            return
    dut.mAxisTReady.value = 0
    raise AssertionError("Timed out waiting for SSI output to clear")


async def wait_input_ready_level(dut, expected: int, cycles=16):
    for _ in range(cycles):
        await cycle(dut.axisClk)
        if int(dut.sAxisTReady.value) == expected:
            return
    raise AssertionError(f"Timed out waiting for sAxisTReady={expected}")


@cocotb.test()
async def ssi_fifo_test(dut):
    data_bytes = env_data_bytes(default=2)
    valid_thold = env_int("VALID_THOLD_G", default=1)
    keep = keep_mask(data_bytes)

    start_clock(dut.axisClk, period_ns=5.0)

    source = FlatSsiEndpoint(dut, prefix="sAxis")
    sink = FlatSsiEndpoint(dut, prefix="mAxis")

    dut.axisRst.setimmediatevalue(1)
    source.set_idle()
    dut.fifoPauseThresh.setimmediatevalue(3)
    dut.mAxisTReady.setimmediatevalue(1)
    await reset_dut(dut)

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x1111, keep=keep, last=1, dest=0x2, sof=1),
        ],
        clk=dut.axisClk,
    )
    beat = await recv_expected_beat(sink, dut, 0x1111)
    dut.mAxisTReady.value = 0
    assert (beat.data, beat.keep, beat.last, beat.dest, beat.sof, beat.eofe) == (0x1111, keep, 1, 0x2, 1, 0)
    await wait_count_zero(dut.fifoWrCnt, dut.axisClk)
    await wait_output_clear(dut)
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
    await wait_count_zero(dut.fifoWrCnt, dut.axisClk)
    assert int(dut.lockupRstEvent.value) == 0

    if valid_thold == 0:
        dut.mAxisTReady.value = 1
        await send_contiguous_frame(
            source,
            [SsiBeat(data=0x8801, keep=keep, last=1, dest=0x4, sof=1)],
            clk=dut.axisClk,
        )
        beat = await recv_expected_beat(sink, dut, 0x8801)
        dut.mAxisTReady.value = 0
        assert beat.last == 1
        assert beat.sof == 1
        assert beat.eofe == 0
        await wait_output_clear(dut)
    elif valid_thold == 2:
        dut.mAxisTReady.value = 0
        dut.fifoPauseThresh.value = 1
        await source.send(
            SsiBeat(data=0x9901, keep=keep, last=1, dest=0x5, sof=1),
            clk=dut.axisClk,
        )
        await wait_input_ready_level(dut, 0)
        assert int(dut.fifoWrCnt.value) >= 1

        dut.fifoPauseThresh.value = 3

        dut.mAxisTReady.value = 1
        beat = await recv_expected_beat(sink, dut, 0x9901)
        dut.mAxisTReady.value = 0
        assert beat.last == 1
        assert beat.sof == 1
        assert beat.eofe == 0


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
