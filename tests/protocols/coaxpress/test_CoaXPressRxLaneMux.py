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
# - Sweep: Use one three-lane wrapper configuration because the mux behavior is
#   driven mainly by frame boundaries, active-lane selection, and backpressure
#   rather than by a broad generic matrix.
# - Stimulus: Hold one multi-beat frame on lane 0 while single-beat frames wait
#   on lanes 1 and 2, set `numOfLane` above the generic range to exercise the
#   clipping path, and stall the sink on the first visible output beat.
# - Checks: The mux must keep serving the current lane until `TLAST`, clip the
#   active-lane count to the instantiated maximum, propagate payload/keep/last
#   unchanged, and hold the stalled output beat stable.
# - Timing: Each source beat stays asserted until the corresponding lane-ready
#   bit rises, so the bench checks the mux's real accepted-handshake order.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import env_int, parameter_case, run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import pack_words, reset_dut, start_clock

CXP_RX_STREAM_TRAILER_USER = 1 << 4


def _set_lane_inputs(dut, lane_beats, *, num_lanes: int) -> None:
    lane_width = 32 * num_lanes
    keep_width = 4 * num_lanes
    user_width = 8
    valid = 0
    data = 0
    keep = 0
    user = 0
    last = 0
    for lane, beat in enumerate(lane_beats):
        if beat is None:
            continue
        valid |= 1 << lane
        data |= beat["data"] << (lane * lane_width)
        keep |= beat["keep"] << (lane * keep_width)
        user |= beat.get("user", 0) << (lane * user_width)
        last |= beat["last"] << lane
    dut.sAxisTValid.value = valid
    dut.sAxisTData.value = data
    dut.sAxisTKeep.value = keep
    dut.sAxisTUser.value = user
    dut.sAxisTLast.value = last


@cocotb.test()
async def coaxpress_rx_lane_mux_round_robin_test(dut):
    num_lanes = env_int("NUM_LANES_G", default=3)
    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.rxFsmRst.setimmediatevalue(0)
    dut.numOfLane.setimmediatevalue(7)
    dut.mAxisTReady.setimmediatevalue(0)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTUser.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut, reset_names=("rxRst",))

    lane_queues = [
        [
            {"data": pack_words([0x10, 0x11, 0x12]), "keep": 0x0FFF, "last": 0},
            {"data": pack_words([0x13, 0x14, 0x15]), "keep": 0x0FFF, "last": 1},
            {"data": 0, "keep": 0x0FFF, "user": CXP_RX_STREAM_TRAILER_USER, "last": 1},
        ],
        [
            {"data": pack_words([0x20, 0x21, 0x22]), "keep": 0x0FFF, "last": 1},
            {"data": 0, "keep": 0x0FFF, "user": CXP_RX_STREAM_TRAILER_USER, "last": 1},
        ],
        [
            {"data": pack_words([0x30, 0x31, 0x32]), "keep": 0x0FFF, "last": 1},
            {"data": 0, "keep": 0x0FFF, "user": CXP_RX_STREAM_TRAILER_USER, "last": 1},
        ],
    ]

    observed: list[tuple[int, int, int]] = []
    held_first: tuple[int, int, int] | None = None

    for cycle_index in range(12):
        current = [queue[0] if queue else None for queue in lane_queues]
        _set_lane_inputs(dut, current, num_lanes=num_lanes)
        dut.mAxisTReady.value = 0 if cycle_index < 2 else 1

        await RisingEdge(dut.rxClk)
        await Timer(1, unit="ns")

        ready_bits = int(dut.sAxisTReady.value)
        for lane, queue in enumerate(lane_queues):
            if queue and ((ready_bits >> lane) & 0x1):
                queue.pop(0)

        if int(dut.mAxisTValid.value) == 1:
            beat = (
                int(dut.mAxisTData.value),
                int(dut.mAxisTKeep.value),
                int(dut.mAxisTLast.value),
            )
            if held_first is None:
                held_first = beat
            if cycle_index == 1:
                assert beat == held_first
            if int(dut.mAxisTReady.value) == 1:
                observed.append(beat)

    assert held_first is not None
    assert observed == [
        (pack_words([0x10, 0x11, 0x12]), 0x0FFF, 0),
        (pack_words([0x13, 0x14, 0x15]), 0x0FFF, 1),
        (0, 0x0FFF, 1),
        (pack_words([0x20, 0x21, 0x22]), 0x0FFF, 1),
        (0, 0x0FFF, 1),
        (pack_words([0x30, 0x31, 0x32]), 0x0FFF, 1),
        (0, 0x0FFF, 1),
    ]


PARAMETER_SWEEP = [parameter_case("three_lane", NUM_LANES_G="3")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_CoaXPressRxLaneMux(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressrxlanemuxwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxLaneMux.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressRxLaneMuxWrapper.vhd",
            ]
        },
    )
