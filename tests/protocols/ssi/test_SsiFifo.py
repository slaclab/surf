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
# - Stimulus: Drive good single-beat and multi-beat frames, a missing-SOF
#   frame, repeated-`SOF` malformed frames in each buffered mode, and
#   threshold/overflow-specific buffered traffic while varying sink readiness
#   and the runtime pause threshold exposed by the wrapper.
# - Checks: Good frames must emerge intact, missing-SOF traffic must be
#   dropped, repeated-`SOF` must terminate on the violating beat with `EOFE`,
#   and the threshold/overflow paths must expose wrapper-visible occupancy,
#   dynamic pause, and terminal-frame behavior without lockup resets. The
#   default, frame-ready, and thresholded paths all prove contiguous 3-beat
#   frame preservation through the wrapper, and the overflow path proves longer
#   trailing blowoff traffic does not leak.
# - Timing: The bench uses handshake-based frame receive helpers for contiguous
#   traffic and waits on explicit counter or drop-flag transitions so the
#   regression proves FIFO gating behavior instead of relying on fixed-latency
#   assumptions.

import cocotb
import pytest

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    assert_beat_list,
    assert_beat_views,
    capture_accepted_beats,
    cycle,
    env_data_bytes,
    env_int,
    expect_no_output,
    expect_no_output_data,
    keep_mask,
    recv_frame,
    recv_frame_by_data,
    recv_visible_beat,
    send_contiguous_frame,
    setup_flat_ssi_testbench,
    SsiBeat,
    wait_output_clear,
    wait_signal_level,
    wait_signal_pulse,
)


async def drive_ready_pattern(ready_signal, *, clk, pattern: list[int], cycles: int) -> None:
    # This background task creates sink backpressure patterns while the main
    # coroutine keeps watching what traffic was actually accepted.
    for index in range(cycles):
        ready_signal.value = pattern[index % len(pattern)]
        await cocotb.triggers.RisingEdge(clk)
        await cocotb.triggers.Timer(1, unit="ns")
    ready_signal.value = 0


@cocotb.test()
async def ssi_fifo_test(dut):
    data_bytes = env_data_bytes(default=2)
    valid_thold = env_int("VALID_THOLD_G", default=1)
    slave_ready_en = env_flag("SLAVE_READY_EN_G", default=True)
    keep = keep_mask(data_bytes)

    # The wrapper exposes the source-side and sink-side SSI ports directly, so
    # the cocotb test can describe frames in protocol terms instead of packing
    # bits by hand.
    # Start from reset with the sink stalled. Several checks below first look
    # at a visible beat and only then begin accepting data.
    bench = await setup_flat_ssi_testbench(
        dut,
        period_ns=5.0,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={"fifoPauseThresh": 3, "mAxisTReady": 0},
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    if valid_thold == 1 and slave_ready_en:
        # In the default mode, a clean three-beat frame should pass through
        # intact even when the source drives it contiguously.
        good_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x1111, keep=keep, last=0, dest=0x2, sof=1),
                    SsiBeat(data=0x2222, keep=keep, last=0, dest=0x2),
                    SsiBeat(data=0x3333, keep=keep, last=1, dest=0x2),
                ],
                clk=bench.clk,
            )
        )
        frame = await recv_frame(
            sink,
            clk=bench.clk,
            ready_signal=dut.mAxisTReady,
            timeout_cycles=64,
        )
        await good_send
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0x1111, keep=keep, last=0, dest=0x2, sof=1, eofe=0),
                SsiBeat(data=0x2222, keep=keep, last=0, dest=0x2, sof=0, eofe=0),
                SsiBeat(data=0x3333, keep=keep, last=1, dest=0x2, sof=0, eofe=0),
            ],
        )
    else:
        # The non-default branches still start with one simple good-frame smoke
        # check before moving into their branch-specific behavior.
        await send_contiguous_frame(
            source,
            [
                SsiBeat(data=0x1111, keep=keep, last=1, dest=0x2, sof=1),
            ],
            clk=bench.clk,
        )
        frame = await recv_frame_by_data(
            sink,
            clk=bench.clk,
            ready_signal=dut.mAxisTReady,
            expected_data=[0x1111],
        )
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0x1111, keep=keep, last=1, dest=0x2, sof=1, eofe=0),
            ],
        )
    # After the first frame drains, the wrapper-visible occupancy counter
    # should return to zero and no lockup reset should have fired.
    await wait_signal_level(dut.fifoWrCnt, clk=bench.clk, expected=0, cycles=64)
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)
    assert int(dut.lockupRstEvent.value) == 0

    # Frames with no opening `SOF` are malformed and must disappear entirely.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x6666, keep=keep, last=0, dest=0x3),
            SsiBeat(data=0x7777, keep=keep, last=1, dest=0x3),
        ],
        clk=bench.clk,
    )
    await expect_no_output(sink, clk=bench.clk)
    await wait_signal_level(dut.fifoWrCnt, clk=bench.clk, expected=0, cycles=64)

    if valid_thold == 1 and slave_ready_en:
        # Hold the sink in a 1/0 ready pattern so the test proves the helper is
        # capturing accepted transfers correctly across backpressure.
        stall_good_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x1201, keep=keep, last=0, dest=0x2, sof=1),
                    SsiBeat(data=0x1202, keep=keep, last=0, dest=0x2),
                    SsiBeat(data=0x1203, keep=keep, last=0, dest=0x2),
                    SsiBeat(data=0x1204, keep=keep, last=0, dest=0x2),
                    SsiBeat(data=0x1205, keep=keep, last=1, dest=0x2),
                ],
                clk=bench.clk,
            )
        )
        capture_task = cocotb.start_soon(capture_accepted_beats(sink, clk=bench.clk, cycles=32))
        ready_task = cocotb.start_soon(
            drive_ready_pattern(dut.mAxisTReady, clk=bench.clk, pattern=[1, 0], cycles=24)
        )
        await stall_good_send
        beats = await capture_task
        await ready_task
        assert_beat_views(
            beats,
            fields=("data", "last", "dest", "sof", "eofe"),
            expected=[
                (0x1201, 0, 0x2, 1, 0),
                (0x1202, 0, 0x2, 0, 0),
                (0x1203, 0, 0x2, 0, 0),
                (0x1204, 0, 0x2, 0, 0),
                (0x1205, 1, 0x2, 0, 0),
            ],
        )
        await expect_no_output(sink, clk=bench.clk)

        # A repeated `SOF` should terminate the frame on the violating beat and
        # drop any trailing payload.
        repeated_sof_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x8801, keep=keep, last=0, dest=0x5, sof=1),
                    SsiBeat(data=0x8802, keep=keep, last=0, dest=0x5, sof=1),
                    SsiBeat(data=0x8803, keep=keep, last=1, dest=0x5),
                ],
                clk=bench.clk,
            )
        )
        first = await sink.wait_valid(clk=bench.clk)
        frame = await recv_frame_by_data(
            sink,
            clk=bench.clk,
            ready_signal=dut.mAxisTReady,
            expected_data=[0x8801, 0x8802],
        )
        await repeated_sof_send
        assert first.data == 0x8801
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0x8801, keep=keep, last=0, dest=0x5, sof=1, eofe=0),
                SsiBeat(data=0x8802, keep=keep, last=1, dest=0x5, sof=0, eofe=1),
            ],
        )
        await expect_no_output_data(sink, clk=bench.clk, forbidden_data=0x8803)
        await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)

        # Repeat the malformed-frame case under sink backpressure so the same
        # truncation policy is proven on accepted handshakes, not just on an
        # always-ready sink.
        stalled_malformed_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x8A01, keep=keep, last=0, dest=0x5, sof=1),
                    SsiBeat(data=0x8A02, keep=keep, last=0, dest=0x5, sof=1),
                    SsiBeat(data=0x8A03, keep=keep, last=1, dest=0x5),
                ],
                clk=bench.clk,
            )
        )
        capture_task = cocotb.start_soon(capture_accepted_beats(sink, clk=bench.clk, cycles=24))
        ready_task = cocotb.start_soon(
            drive_ready_pattern(dut.mAxisTReady, clk=bench.clk, pattern=[1, 0], cycles=20)
        )
        await stalled_malformed_send
        beats = await capture_task
        await ready_task
        assert_beat_views(
            beats,
            fields=("data", "last", "dest", "sof", "eofe"),
            expected=[
                (0x8A01, 0, 0x5, 1, 0),
                (0x8A02, 1, 0x5, 0, 1),
            ],
        )
        await expect_no_output_data(sink, clk=bench.clk, forbidden_data=0x8A03)
        await expect_no_output(sink, clk=bench.clk)
    elif valid_thold == 0:
        # In frame-ready mode the FIFO should hold a partial frame until the
        # terminal beat arrives, so no output should be visible early.
        delayed_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x9901, keep=keep, last=0, dest=0x4, sof=1),
                    SsiBeat(data=0x9902, keep=keep, last=0, dest=0x4),
                    SsiBeat(data=0x9903, keep=keep, last=1, dest=0x4),
                ],
                clk=bench.clk,
            )
        )
        await cycle(bench.clk, 2)
        assert int(dut.mAxisTValid.value) == 0
        await delayed_send
        assert int(dut.fifoWrCnt.value) != 0
        frame = await recv_frame(
            sink,
            clk=bench.clk,
            ready_signal=dut.mAxisTReady,
            timeout_cycles=64,
        )
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0x9901, keep=keep, last=0, dest=0x4, sof=1, eofe=0),
                SsiBeat(data=0x9902, keep=keep, last=0, dest=0x4, sof=0, eofe=0),
                SsiBeat(data=0x9903, keep=keep, last=1, dest=0x4, sof=0, eofe=0),
            ],
        )
        await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)

        # A malformed frame should still be dropped before any output becomes
        # visible in frame-ready mode.
        malformed_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x9A01, keep=keep, last=0, dest=0x4, sof=1),
                    SsiBeat(data=0x9A02, keep=keep, last=0, dest=0x4, sof=1),
                    SsiBeat(data=0x9A03, keep=keep, last=1, dest=0x4),
                ],
                clk=bench.clk,
            )
        )
        await cycle(bench.clk, 2)
        assert int(dut.mAxisTValid.value) == 0
        await malformed_send
        await expect_no_output(sink, clk=bench.clk)
    elif valid_thold == 2:
        # In threshold mode the FIFO should withhold output until enough beats
        # are buffered, while the wrapper-visible pause signal tracks the
        # runtime-configured pause threshold independently.
        dut.fifoPauseThresh.value = 4
        threshold_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0xA001, keep=keep, last=0, dest=0x6, sof=1),
                    SsiBeat(data=0xA002, keep=keep, last=0, dest=0x6),
                    SsiBeat(data=0xA003, keep=keep, last=1, dest=0x6),
                ],
                clk=bench.clk,
            )
        )
        await wait_signal_level(dut.fifoWrCnt, clk=bench.clk, expected=1, cycles=32)
        assert int(dut.mAxisTValid.value) == 0
        assert int(dut.sAxisPause.value) == 0
        dut.fifoPauseThresh.value = 1
        await wait_signal_level(dut.sAxisPause, clk=bench.clk, expected=1, cycles=32)
        dut.fifoPauseThresh.value = 4
        await wait_signal_level(dut.sAxisPause, clk=bench.clk, expected=0, cycles=32)
        await threshold_send
        frame = await recv_frame(
            sink,
            clk=bench.clk,
            ready_signal=dut.mAxisTReady,
            timeout_cycles=64,
        )
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0xA001, keep=keep, last=0, dest=0x6, sof=1, eofe=0),
                SsiBeat(data=0xA002, keep=keep, last=0, dest=0x6, sof=0, eofe=0),
                SsiBeat(data=0xA003, keep=keep, last=1, dest=0x6, sof=0, eofe=0),
            ],
        )
        await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)

        # The same thresholded release should preserve early-truncation policy
        # on a repeated-`SOF` malformed frame.
        dut.fifoPauseThresh.value = 4
        malformed_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0xAA01, keep=keep, last=0, dest=0x6, sof=1),
                    SsiBeat(data=0xAA02, keep=keep, last=0, dest=0x6, sof=1),
                    SsiBeat(data=0xAA03, keep=keep, last=1, dest=0x6),
                ],
                clk=bench.clk,
            )
        )
        await malformed_send
        frame = await recv_frame(
            sink,
            clk=bench.clk,
            ready_signal=dut.mAxisTReady,
            timeout_cycles=64,
        )
        assert_beat_list(
            frame,
            [
                SsiBeat(data=0xAA01, keep=keep, last=0, dest=0x6, sof=1, eofe=0),
                SsiBeat(data=0xAA02, keep=keep, last=1, dest=0x6, sof=0, eofe=1),
            ],
        )
        await expect_no_output_data(sink, clk=bench.clk, forbidden_data=0xAA03)
        await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)

        # Finally combine threshold release with sink backpressure and confirm
        # the accepted beat sequence still matches the original five-beat frame.
        dut.fifoPauseThresh.value = 4
        stalled_threshold_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0xAB01, keep=keep, last=0, dest=0x6, sof=1),
                    SsiBeat(data=0xAB02, keep=keep, last=0, dest=0x6),
                    SsiBeat(data=0xAB03, keep=keep, last=0, dest=0x6),
                    SsiBeat(data=0xAB04, keep=keep, last=0, dest=0x6),
                    SsiBeat(data=0xAB05, keep=keep, last=1, dest=0x6),
                ],
                clk=bench.clk,
            )
        )
        first = await recv_visible_beat(
            sink,
            clk=bench.clk,
            ready_signal=dut.mAxisTReady,
        )
        capture_task = cocotb.start_soon(capture_accepted_beats(sink, clk=bench.clk, cycles=32))
        ready_task = cocotb.start_soon(
            drive_ready_pattern(dut.mAxisTReady, clk=bench.clk, pattern=[1, 0], cycles=24)
        )
        await stalled_threshold_send
        beats = [first] + await capture_task
        await ready_task
        assert_beat_views(
            beats,
            fields=("data", "last", "dest", "sof", "eofe"),
            expected=[
                (0xAB01, 0, 0x6, 1, 0),
                (0xAB02, 0, 0x6, 0, 0),
                (0xAB03, 0, 0x6, 0, 0),
                (0xAB04, 0, 0x6, 0, 0),
                (0xAB05, 1, 0x6, 0, 0),
            ],
        )
        await expect_no_output(sink, clk=bench.clk)
    elif not slave_ready_en:
        # In the no-ready mode the source keeps sending even when the sink is
        # stalled. Drive a frame deeper than the FIFO can absorb so overflow
        # truncates the visible output and drops the trailing payload.
        overflow_beats = [
            SsiBeat(
                data=0xB000 + beat_index,
                keep=keep,
                last=1 if beat_index == 40 else 0,
                dest=0x7,
                sof=1 if beat_index == 1 else 0,
            )
            for beat_index in range(1, 41)
        ]
        overflow_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                overflow_beats,
                clk=bench.clk,
            )
        )
        await wait_signal_pulse(dut.sAxisDropWord, clk=bench.clk, cycles=256)
        await wait_signal_pulse(dut.sAxisDropFrame, clk=bench.clk, cycles=256)
        capture_task = cocotb.start_soon(capture_accepted_beats(sink, clk=bench.clk, cycles=160))
        dut.mAxisTReady.value = 1
        await overflow_send
        beats = await capture_task
        dut.mAxisTReady.value = 0
        assert beats[0] == SsiBeat(data=0xB001, keep=keep, last=0, dest=0x7, sof=1, eofe=0)
        assert len(beats) < len(overflow_beats)
        assert any(beat.last == 1 for beat in beats)
        assert all(beat.last == 0 for beat in beats[:-1])
        assert beats[-1].last == 1
        assert beats[-1].sof == 0
        assert all(beat.data != overflow_beats[-1].data for beat in beats)
        await expect_no_output(sink, clk=bench.clk)

    # None of the exercised paths should need the FIFO lockup recovery logic.
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
