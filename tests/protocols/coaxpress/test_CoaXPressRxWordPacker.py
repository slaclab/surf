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
# - Sweep: Cover a one-lane passthrough case and a four-lane packing case so
#   both the trivial path and the multi-word assembly path are exercised.
# - Stimulus: Drive sparse and offset `TKEEP` patterns, including a frame that
#   spans two input beats and a reset asserted while a partial output word is
#   still buffered.
# - Checks: The packed output words must preserve order, emit the expected
#   `TKEEP` mask on the short final beat, and discard any partial assembly
#   state across reset.
# - Timing: The bench samples the pulsed master-only output after every clock
#   edge while continuing to drive one input beat per cycle.

import cocotb
import pytest

from tests.common.regression_utils import env_int, parameter_case, run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    AxisBeat,
    collect_pulses,
    cycle,
    keep_for_words,
    lane_keep_mask,
    pack_words,
    reset_dut,
    send_axis_beats_no_ready,
    start_clock,
)


@cocotb.test()
async def coaxpress_rx_word_packer_repack_test(dut):
    num_lanes = env_int("NUM_LANES_G", default=1)
    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut)

    observed: list[dict[str, int]] = []

    if num_lanes == 1:
        # The one-lane case should behave like a direct passthrough.
        await send_axis_beats_no_ready(
            dut,
            beats=[
                AxisBeat(data=0x11223344, keep=0xF, last=0),
                AxisBeat(data=0x55667788, keep=0xF, last=1),
            ],
            clk=dut.rxClk,
            capture=observed,
            valid_name="mAxisTValid",
            field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
        )
        observed.extend(
            await collect_pulses(
                dut,
                clk=dut.rxClk,
                cycles=4,
                valid_name="mAxisTValid",
                field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
            )
        )
        assert observed == [
            {"mAxisTData": 0x11223344, "mAxisTKeep": 0xF, "mAxisTLast": 0},
            {"mAxisTData": 0x55667788, "mAxisTKeep": 0xF, "mAxisTLast": 1},
        ]
        return

    # The wider case intentionally starts on lane 1, fills one output beat,
    # then spills into a short final beat on the next cycle.
    await send_axis_beats_no_ready(
        dut,
        beats=[
            AxisBeat(
                data=pack_words([0x0, 0xAAA00001, 0xBBB00002, 0xCCC00003]),
                keep=0xFFF0,
                last=0,
            ),
            AxisBeat(
                data=pack_words([0xDDD00004, 0xEEE00005, 0xFFF00006]),
                keep=0x0FFF,
                last=1,
            ),
        ],
        clk=dut.rxClk,
        capture=observed,
        valid_name="mAxisTValid",
        field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
    )
    observed.extend(
        await collect_pulses(
            dut,
            clk=dut.rxClk,
            cycles=6,
            valid_name="mAxisTValid",
            field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
        )
    )

    assert observed == [
        {
            "mAxisTData": pack_words([0xAAA00001, 0xBBB00002, 0xCCC00003, 0xDDD00004]),
            "mAxisTKeep": keep_for_words(4),
            "mAxisTLast": 0,
        },
        {
            "mAxisTData": pack_words([0xEEE00005, 0xFFF00006]),
            "mAxisTKeep": keep_for_words(2),
            "mAxisTLast": 1,
        },
    ]


@cocotb.test()
async def coaxpress_rx_word_packer_reset_flush_test(dut):
    num_lanes = env_int("NUM_LANES_G", default=1)
    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut)

    if num_lanes == 1:
        return

    # Leave a half-full packed word buffered, then reset and confirm the next
    # frame starts cleanly rather than draining stale payload.
    await send_axis_beats_no_ready(
        dut,
        beats=[AxisBeat(data=pack_words([0x11111111, 0x22222222]), keep=0x00FF, last=0)],
        clk=dut.rxClk,
    )
    dut.rxRst.value = 1
    await cycle(dut.rxClk, 2)
    dut.rxRst.value = 0
    await cycle(dut.rxClk, 2)

    observed: list[dict[str, int]] = []
    await send_axis_beats_no_ready(
        dut,
        beats=[AxisBeat(data=pack_words([0xABCDEF01]), keep=0x000F, last=1)],
        clk=dut.rxClk,
        capture=observed,
        valid_name="mAxisTValid",
        field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
    )
    observed.extend(
        await collect_pulses(
            dut,
            clk=dut.rxClk,
            cycles=4,
            valid_name="mAxisTValid",
            field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
        )
    )

    assert observed == [
        {
            "mAxisTData": 0xABCDEF01,
            "mAxisTKeep": keep_for_words(1),
            "mAxisTLast": 1,
        }
    ]


@cocotb.test()
async def coaxpress_rx_word_packer_three_word_last_beat_test(dut):
    if env_int("NUM_LANES_G", default=1) != 4:
        return

    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut)

    observed: list[dict[str, int]] = []
    await send_axis_beats_no_ready(
        dut,
        beats=[
            AxisBeat(
                data=pack_words([0x11111111, 0x22222222, 0x33333333]),
                keep=keep_for_words(3),
                last=1,
            )
        ],
        clk=dut.rxClk,
        capture=observed,
        valid_name="mAxisTValid",
        field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
    )
    observed.extend(
        await collect_pulses(
            dut,
            clk=dut.rxClk,
            cycles=4,
            valid_name="mAxisTValid",
            field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
        )
    )

    assert observed == [
        {
            "mAxisTData": pack_words([0x11111111, 0x22222222, 0x33333333]),
            "mAxisTKeep": keep_for_words(3),
            "mAxisTLast": 1,
        }
    ]


@cocotb.test()
async def coaxpress_rx_word_packer_two_plus_one_last_beat_test(dut):
    if env_int("NUM_LANES_G", default=1) != 4:
        return

    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut)

    observed: list[dict[str, int]] = []
    await send_axis_beats_no_ready(
        dut,
        beats=[
            AxisBeat(
                data=pack_words([0x11111111, 0x22222222]),
                keep=keep_for_words(2),
                last=0,
            ),
            AxisBeat(
                data=pack_words([0x33333333]),
                keep=keep_for_words(1),
                last=1,
            ),
        ],
        clk=dut.rxClk,
        capture=observed,
        valid_name="mAxisTValid",
        field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
    )
    observed.extend(
        await collect_pulses(
            dut,
            clk=dut.rxClk,
            cycles=4,
            valid_name="mAxisTValid",
            field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
        )
    )

    assert observed == [
        {
            "mAxisTData": pack_words([0x11111111, 0x22222222, 0x33333333]),
            "mAxisTKeep": keep_for_words(3),
            "mAxisTLast": 1,
        }
    ]


@cocotb.test()
async def coaxpress_rx_word_packer_offset_two_plus_one_last_beat_test(dut):
    if env_int("NUM_LANES_G", default=1) != 4:
        return

    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut)

    observed: list[dict[str, int]] = []
    await send_axis_beats_no_ready(
        dut,
        beats=[
            AxisBeat(
                data=pack_words([0xAAAAAAAA, 0xBBBBBBBB, 0x11111111, 0x22222222]),
                keep=lane_keep_mask([2, 3]),
                last=0,
            ),
            AxisBeat(
                data=pack_words([0x33333333]),
                keep=lane_keep_mask([0]),
                last=1,
            ),
        ],
        clk=dut.rxClk,
        capture=observed,
        valid_name="mAxisTValid",
        field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
    )
    observed.extend(
        await collect_pulses(
            dut,
            clk=dut.rxClk,
            cycles=4,
            valid_name="mAxisTValid",
            field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
        )
    )

    assert observed == [
        {
            "mAxisTData": pack_words([0x11111111, 0x22222222, 0x33333333]),
            "mAxisTKeep": keep_for_words(3),
            "mAxisTLast": 1,
        }
    ]


@cocotb.test()
async def coaxpress_rx_word_packer_back_to_back_offset_short_frames_test(dut):
    if env_int("NUM_LANES_G", default=1) != 4:
        return

    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut)

    observed: list[dict[str, int]] = []
    await send_axis_beats_no_ready(
        dut,
        beats=[
            AxisBeat(
                data=pack_words([0xAAAAAAAA, 0xBBBBBBBB, 0x11111111, 0x22222222]),
                keep=lane_keep_mask([2, 3]),
                last=0,
            ),
            AxisBeat(
                data=pack_words([0x33333333]),
                keep=lane_keep_mask([0]),
                last=1,
            ),
            AxisBeat(
                data=pack_words([0xCCCCCCCC, 0xDDDDDDDD, 0x44444444, 0x55555555]),
                keep=lane_keep_mask([2, 3]),
                last=0,
            ),
            AxisBeat(
                data=pack_words([0x66666666]),
                keep=lane_keep_mask([0]),
                last=1,
            ),
        ],
        clk=dut.rxClk,
        capture=observed,
        valid_name="mAxisTValid",
        field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
    )
    observed.extend(
        await collect_pulses(
            dut,
            clk=dut.rxClk,
            cycles=6,
            valid_name="mAxisTValid",
            field_names=("mAxisTData", "mAxisTKeep", "mAxisTLast"),
        )
    )

    assert observed == [
        {
            "mAxisTData": pack_words([0x11111111, 0x22222222, 0x33333333]),
            "mAxisTKeep": keep_for_words(3),
            "mAxisTLast": 1,
        },
        {
            "mAxisTData": pack_words([0x44444444, 0x55555555, 0x66666666]),
            "mAxisTKeep": keep_for_words(3),
            "mAxisTLast": 1,
        },
    ]


PARAMETER_SWEEP = [
    parameter_case("single_lane", NUM_LANES_G="1"),
    parameter_case("four_lane", NUM_LANES_G="4"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_CoaXPressRxWordPacker(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressrxwordpackerwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxWordPacker.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressRxWordPackerWrapper.vhd",
            ]
        },
    )
