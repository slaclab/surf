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
# - Sweep: Use a standalone `AxiStreamBatcher` wrapper at an 8-byte AXI Stream
#   width. Exercise the V2 compacted output path through `AxiStreamGearbox` and
#   the V1 padded-output path for the idle-gap tail regression.
# - Stimulus: Drive one or more input subframes with varied payload lengths,
#   `TKEEP`, `TDEST`, first-byte `TUSER`, and last-byte `TUSER`, then terminate
#   superframes by subframe count, idle gap, byte threshold, and sink
#   backpressure.
# - Checks: The emitted byte stream must match the V2 superframe header,
#   payload bytes, and subframe tail metadata exactly, with `TLAST` only on the
#   terminal superframe beat.
# - Timing: Source and sink use ready/valid handshakes, including a held-not-
#   ready sink case that asserts the DUT holds every output beat stable.

import cocotb
import pytest
from cocotb.triggers import with_timeout

from tests.common.regression_utils import (
    cocotb_filtered_env,
    cocotb_test_filter,
    cocotb_test_filter_excluding,
    run_surf_vhdl_test,
)
from tests.protocols.batcher.batcher_test_utils import (
    AxisBeat,
    FlatAxisEndpoint,
    beats_to_bytes,
    cycle,
    expected_batched_bytes,
    expected_batched_v1_bytes,
    keep_count,
    payload_to_beats,
    recv_beats,
    recv_until_last,
    recv_until_last_with_backpressure,
    reset_batcher_dut,
    send_frame,
    start_batcher_clock,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = FlatAxisEndpoint(dut, prefix="S_AXIS")
        self.sink = FlatAxisEndpoint(dut, prefix="M_AXIS")

        start_batcher_clock(dut)
        dut.axisRst.setimmediatevalue(1)
        dut.forceTerm.setimmediatevalue(0)
        dut.superFrameByteThreshold.setimmediatevalue(0)
        dut.maxSubFrames.setimmediatevalue(1)
        dut.maxClkGap.setimmediatevalue(256)
        dut.M_AXIS_TREADY.setimmediatevalue(0)
        self.source.set_idle()

    async def reset(self):
        await reset_batcher_dut(self.dut)


@cocotb.test()
async def single_subframe_terminates_on_count_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A five-byte frame exercises the V2 gearbox because the two-byte
    # superframe header, payload, and seven-byte tail do not align to an
    # eight-byte output boundary.
    payload = bytes(range(0x10, 0x15))
    frame = (payload, 0x3, 0x22, 0x41)
    input_beats = payload_to_beats(
        payload,
        dest=frame[1],
        first_user=frame[2],
        last_user=frame[3],
    )

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes([frame])
    assert rx_beats[-1].last == 1
    await cycle(dut.axisClk, 2)
    assert int(dut.idle.value) == 1


@cocotb.test()
async def two_subframes_share_one_superframe_test(dut):
    tb = TB(dut)
    await tb.reset()
    dut.maxSubFrames.value = 2

    # Two subframes should share one superframe when the runtime subframe limit
    # is raised.  The second frame is deliberately not word-aligned so the tail
    # metadata lands in a compacted output beat.
    first = (bytes(range(0x20, 0x28)), 0x4, 0x11, 0x91)
    second = (bytes(range(0x40, 0x45)), 0x7, 0x33, 0xA5)

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    for payload, dest, first_user, last_user in (first, second):
        await send_frame(
            tb.source,
            payload_to_beats(
                payload,
                dest=dest,
                first_user=first_user,
                last_user=last_user,
            ),
            clk=dut.axisClk,
        )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes([first, second])
    assert [beat.last for beat in rx_beats[:-1]] == [0] * (len(rx_beats) - 1)
    assert rx_beats[-1].last == 1


@cocotb.test()
async def idle_gap_terminates_pending_tail_test(dut):
    tb = TB(dut)
    await tb.reset()
    dut.maxSubFrames.value = 8
    dut.maxClkGap.value = 32

    # With no second subframe arriving, the small max-clock-gap setting must
    # close the superframe after the tail has been accepted into the batcher.
    payload = bytes(range(0x60, 0x6B))
    frame = (payload, 0x2, 0x44, 0xB1)
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source,
        payload_to_beats(
            payload,
            dest=frame[1],
            first_user=frame[2],
            last_user=frame[3],
        ),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes([frame])
    assert rx_beats[-1].last == 1


@cocotb.test()
async def v1_idle_gap_preserves_pending_tail_test(dut):
    tb = TB(dut)
    await tb.reset()
    dut.maxSubFrames.value = 8
    dut.maxClkGap.value = 8

    # Version 1 holds the padded tail word with TVALID deasserted while GAP_S
    # waits for this timeout.  The held data must survive until the timeout
    # reasserts TVALID and marks that same word as the terminal superframe beat.
    payload = bytes(range(0x60, 0x6B))
    frame = (payload, 0x2, 0x44, 0xB1)
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source,
        payload_to_beats(
            payload,
            dest=frame[1],
            first_user=frame[2],
            last_user=frame[3],
        ),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_v1_bytes([frame])
    assert rx_beats[-1].last == 1


@cocotb.test()
async def byte_threshold_terminates_superframe_test(dut):
    tb = TB(dut)
    await tb.reset()
    dut.maxSubFrames.value = 8
    dut.maxClkGap.value = 0
    dut.superFrameByteThreshold.value = 24

    # The threshold check is asserted through externally visible termination
    # behavior only.  The RTL floors the register value internally to its word
    # accounting granularity, so the test avoids overfitting that private count.
    first = (bytes(range(0x70, 0x78)), 0x1, 0x55, 0xC1)

    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source,
        payload_to_beats(
            first[0],
            dest=first[1],
            first_user=first[2],
            last_user=first[3],
        ),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes([first])
    assert rx_beats[-1].last == 1


@cocotb.test()
async def force_term_marks_terminal_eofe_test(dut):
    tb = TB(dut)
    await tb.reset()
    dut.maxSubFrames.value = 8
    dut.maxClkGap.value = 256

    # Send one complete subframe, then force the enclosing superframe closed
    # before the clock-gap timer or subframe count can terminate it naturally.
    payload = bytes(range(0x80, 0x85))
    frame = (payload, 0x6, 0x66, 0xE2)
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source,
        payload_to_beats(
            payload,
            dest=frame[1],
            first_user=frame[2],
            last_user=frame[3],
        ),
        clk=dut.axisClk,
    )

    # `forceTerm` is sampled into the RTL and then applied from the non-header
    # state, so hold it for a few clocks to avoid making the test sensitive to
    # the exact state transition cycle.
    await cycle(dut.axisClk, 4)
    dut.forceTerm.value = 1
    await cycle(dut.axisClk, 4)
    dut.forceTerm.value = 0

    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats).startswith(expected_batched_bytes([frame]))
    assert rx_beats[-1].last == 1
    terminal_lane = keep_count(rx_beats[-1].keep) - 1
    assert terminal_lane >= 0
    assert (rx_beats[-1].user >> (8 * terminal_lane)) & 0x1 == 1


@cocotb.test()
async def reset_recovers_after_partial_superframe_test(dut):
    tb = TB(dut)
    await tb.reset()
    dut.maxSubFrames.value = 8
    dut.maxClkGap.value = 256

    # Present a non-terminal input beat and let the DUT emit at least one
    # partial output beat.  The following reset should discard that incomplete
    # superframe state instead of contaminating the next accepted frame.
    partial = AxisBeat(
        data=int.from_bytes(bytes(range(0xA0, 0xA8)), "little"),
        keep=0xFF,
        last=0,
        dest=0x2,
        user=0x19,
    )
    await tb.source.send(partial, clk=dut.axisClk)
    partial_rx = await with_timeout(recv_beats(tb.sink, clk=dut.axisClk, count=1), 2, "us")
    assert partial_rx[0].last == 0

    await reset_batcher_dut(dut)
    assert int(dut.idle.value) == 1
    dut.maxSubFrames.value = 1
    await cycle(dut.axisClk, 1)

    payload = bytes(range(0xB0, 0xB5))
    frame = (payload, 0x1, 0x22, 0xC3)
    rx_task = cocotb.start_soon(recv_until_last(tb.sink, clk=dut.axisClk))
    await send_frame(
        tb.source,
        payload_to_beats(
            payload,
            dest=frame[1],
            first_user=frame[2],
            last_user=frame[3],
        ),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes([frame])
    assert rx_beats[-1].last == 1


@cocotb.test()
async def output_backpressure_holds_each_beat_stable_test(dut):
    tb = TB(dut)
    await tb.reset()

    payload = bytes(range(0x90, 0x9A))
    frame = (payload, 0x5, 0x77, 0xD4)
    rx_task = cocotb.start_soon(
        recv_until_last_with_backpressure(tb.sink, clk=dut.axisClk, hold_cycles=3)
    )
    await send_frame(
        tb.source,
        payload_to_beats(
            payload,
            dest=frame[1],
            first_user=frame[2],
            last_user=frame[3],
        ),
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert beats_to_bytes(rx_beats) == expected_batched_bytes([frame])
    assert rx_beats[-1].last == 1


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param(
            {
                "VERSION_G": 2,
                "DATA_BYTES_G": 8,
                "INPUT_PIPE_STAGES_G": 0,
                "OUTPUT_PIPE_STAGES_G": 1,
            },
            id="v2_8byte",
        ),
    ],
)
def test_AxiStreamBatcher(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreambatcherwrapper",
        parameters=parameters,
        extra_env=cocotb_filtered_env(
            parameters,
            cocotb_test_filter_excluding("v1_idle_gap_preserves_pending_tail_test"),
        ),
        extra_vhdl_sources={
            "surf": [
                "protocols/batcher/wrappers/AxiStreamBatcherWrapper.vhd",
            ],
        },
    )


def test_AxiStreamBatcher_v1_idle_gap():
    parameters = {
        "VERSION_G": 1,
        "DATA_BYTES_G": 8,
        "INPUT_PIPE_STAGES_G": 0,
        "OUTPUT_PIPE_STAGES_G": 1,
    }
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreambatcherwrapper",
        parameters=parameters,
        extra_env={
            **parameters,
            "COCOTB_TEST_FILTER": cocotb_test_filter(
                "v1_idle_gap_preserves_pending_tail_test"
            ),
        },
        extra_vhdl_sources={
            "surf": [
                "protocols/batcher/wrappers/AxiStreamBatcherWrapper.vhd",
            ],
        },
    )
