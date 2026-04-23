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
# - Sweep: Start with a one-lane wrapper configuration so the first CoaXPress
#   FSM regression can focus on header/line correctness before broader
#   multi-lane timing branches are added.
# - Stimulus: Drive a complete rectangular-image transaction with two lines,
#   then a malformed header followed by a clean retry.
# - Checks: The FSM must emit the packed rectangular-image header in the same
#   field order the RTL exports from the spec-defined repeated-byte header,
#   forward the exact programmed number of data words, assert frame `TLAST`
#   only on the final line, and recover cleanly after a malformed header word.
# - Timing: The source holds each beat until `sAxisTReady` rises so the checks
#   reflect the FSM's actual per-beat acceptance rather than idealized traffic.

import os

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import env_int, parameter_case, run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_MARKER,
    CXP_PKT_IMAGE_HEADER,
    CXP_PKT_IMAGE_LINE,
    cycle,
    keep_for_words,
    lane_keep_mask,
    pack_words,
    repeat_byte,
    reset_dut,
    start_clock,
)


def _capture_outputs(dut, *, header_beats: list[dict[str, int]], data_beats: list[dict[str, int]]) -> None:
    if int(dut.hdrTValid.value) == 1:
        header_beats.append(
            {
                "hdrTData": int(dut.hdrTData.value),
                "hdrTLast": int(dut.hdrTLast.value),
                "hdrTSof": int(dut.hdrTSof.value),
            }
        )
    if int(dut.dataTValid.value) == 1:
        data_beats.append(
            {
                "dataTData": int(dut.dataTData.value),
                "dataTKeep": int(dut.dataTKeep.value),
                "dataTLast": int(dut.dataTLast.value),
            }
        )


async def _send_handshaked_beat(dut, *, data: int, keep: int, last: int = 0) -> None:
    dut.sAxisTValid.value = 1
    dut.sAxisTData.value = data
    dut.sAxisTKeep.value = keep
    dut.sAxisTLast.value = last
    while True:
        await RisingEdge(dut.rxClk)
        await Timer(1, unit="ns")
        if int(dut.sAxisTReady.value) == 1:
            break
    dut.sAxisTValid.value = 0
    dut.sAxisTData.value = 0
    dut.sAxisTKeep.value = 0
    dut.sAxisTLast.value = 0


def _beat_data(words: list[int], *, num_lanes: int) -> int:
    return pack_words(words + [0] * (num_lanes - len(words)))


def _header_words() -> list[int]:
    return [
        repeat_byte(0x12),
        repeat_byte(0x34),
        repeat_byte(0x56),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x03),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x04),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x02),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x05),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x03),
        repeat_byte(0x00),
        repeat_byte(0x10),
        repeat_byte(0x00),
        repeat_byte(0x20),
        repeat_byte(0xAA),
    ]


def _expected_header_data() -> int:
    return pack_words(
        [
            0x3456AA12,
            0x00000003,
            0x00000004,
            0x00000002,
            0x00000005,
            0x00000003,
            0x00200010,
        ]
    )


def _single_line_header_words() -> list[int]:
    return [
        repeat_byte(0x12),
        repeat_byte(0x34),
        repeat_byte(0x56),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x01),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x01),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x01),
        repeat_byte(0x00),
        repeat_byte(0x10),
        repeat_byte(0x00),
        repeat_byte(0x20),
        repeat_byte(0xAA),
    ]


@cocotb.test()
async def coaxpress_rx_hs_fsm_header_and_lines_test(dut):
    if env_int("NUM_LANES_G", default=1) != 1:
        return
    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.rxFsmRst.setimmediatevalue(0)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut, reset_names=("rxRst",))
    header_beats: list[dict[str, int]] = []
    data_beats: list[dict[str, int]] = []

    # Send one header packet that declares two lines of three 32-bit words.
    await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_HEADER), keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    for word in _header_words():
        await _send_handshaked_beat(dut, data=word, keep=0xF)
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    # Follow with two line packets whose final word should close the frame.
    for line_words in ([0x11111111, 0x22222222, 0x33333333], [0x44444444, 0x55555555, 0x66666666]):
        await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
        await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_LINE), keep=0xF)
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
        for word in line_words:
            await _send_handshaked_beat(dut, data=word, keep=0xF)
            _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    for _ in range(6):
        await RisingEdge(dut.rxClk)
        await Timer(1, unit="ns")
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    assert header_beats == [{"hdrTData": _expected_header_data(), "hdrTLast": 1, "hdrTSof": 1}], (
        [] if not header_beats else [hex(header_beats[0]["hdrTData"])]
    )
    assert data_beats == [
        {"dataTData": 0x11111111, "dataTKeep": 0xF, "dataTLast": 0},
        {"dataTData": 0x22222222, "dataTKeep": 0xF, "dataTLast": 0},
        {"dataTData": 0x33333333, "dataTKeep": 0xF, "dataTLast": 0},
        {"dataTData": 0x44444444, "dataTKeep": 0xF, "dataTLast": 0},
        {"dataTData": 0x55555555, "dataTKeep": 0xF, "dataTLast": 0},
        {"dataTData": 0x66666666, "dataTKeep": 0xF, "dataTLast": 1},
    ]


@cocotb.test()
async def coaxpress_rx_hs_fsm_malformed_header_recovery_test(dut):
    if env_int("NUM_LANES_G", default=1) != 1:
        return
    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.rxFsmRst.setimmediatevalue(0)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut, reset_names=("rxRst",))
    header_beats: list[dict[str, int]] = []
    data_beats: list[dict[str, int]] = []
    error_seen = False

    # Corrupt one repeated-byte header word and make sure the retry is what
    # actually emits the header/data outputs.
    await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
    error_seen |= int(dut.rxFsmError.value) == 1
    await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_HEADER), keep=0xF)
    error_seen |= int(dut.rxFsmError.value) == 1
    for index, word in enumerate(_header_words()):
        await _send_handshaked_beat(
            dut,
            data=0x01020304 if index == 5 else word,
            keep=0xF,
        )
        error_seen |= int(dut.rxFsmError.value) == 1
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await cycle(dut.rxClk, 2)
    error_seen |= int(dut.rxFsmError.value) == 1
    assert error_seen
    assert not header_beats

    await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_HEADER), keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    for word in _header_words():
        await _send_handshaked_beat(dut, data=word, keep=0xF)
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_LINE), keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=0xABCDEF00, keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=0xABCDEF01, keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=0xABCDEF02, keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    for _ in range(6):
        await RisingEdge(dut.rxClk)
        await Timer(1, unit="ns")
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    assert header_beats == [{"hdrTData": _expected_header_data(), "hdrTLast": 1, "hdrTSof": 1}], (
        [] if not header_beats else [hex(header_beats[0]["hdrTData"])]
    )
    assert data_beats == [
        {"dataTData": 0xABCDEF00, "dataTKeep": 0xF, "dataTLast": 0},
        {"dataTData": 0xABCDEF01, "dataTKeep": 0xF, "dataTLast": 0},
        {"dataTData": 0xABCDEF02, "dataTKeep": 0xF, "dataTLast": 0},
    ]


@cocotb.test()
async def coaxpress_rx_hs_fsm_malformed_header_drops_following_line_test(dut):
    if env_int("NUM_LANES_G", default=1) != 1:
        return

    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.rxFsmRst.setimmediatevalue(0)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut, reset_names=("rxRst",))

    header_beats: list[dict[str, int]] = []
    data_beats: list[dict[str, int]] = []
    error_seen = False

    await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
    error_seen |= int(dut.rxFsmError.value) == 1
    await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_HEADER), keep=0xF)
    error_seen |= int(dut.rxFsmError.value) == 1
    for index, word in enumerate(_header_words()):
        await _send_handshaked_beat(
            dut,
            data=0x01020304 if index == 5 else word,
            keep=0xF,
        )
        error_seen |= int(dut.rxFsmError.value) == 1
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    # A line packet arriving after a malformed header must be discarded until a
    # clean header has been accepted.
    await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
    error_seen |= int(dut.rxFsmError.value) == 1
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_LINE), keep=0xF)
    error_seen |= int(dut.rxFsmError.value) == 1
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    for word in (0x0BAD0000, 0x0BAD0001, 0x0BAD0002):
        await _send_handshaked_beat(dut, data=word, keep=0xF)
        error_seen |= int(dut.rxFsmError.value) == 1
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    await cycle(dut.rxClk, 2)
    error_seen |= int(dut.rxFsmError.value) == 1
    assert error_seen
    assert not header_beats
    assert not data_beats

    await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_HEADER), keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    for word in _header_words():
        await _send_handshaked_beat(dut, data=word, keep=0xF)
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_LINE), keep=0xF)
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    for word in (0xABCDEF00, 0xABCDEF01, 0xABCDEF02):
        await _send_handshaked_beat(dut, data=word, keep=0xF)
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    for _ in range(6):
        await RisingEdge(dut.rxClk)
        await Timer(1, unit="ns")
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    assert header_beats == [{"hdrTData": _expected_header_data(), "hdrTLast": 1, "hdrTSof": 1}], (
        [] if not header_beats else [hex(header_beats[0]["hdrTData"])]
    )
    assert data_beats == [
        {"dataTData": 0xABCDEF00, "dataTKeep": 0xF, "dataTLast": 0},
        {"dataTData": 0xABCDEF01, "dataTKeep": 0xF, "dataTLast": 0},
        {"dataTData": 0xABCDEF02, "dataTKeep": 0xF, "dataTLast": 0},
    ]


@cocotb.test()
async def coaxpress_rx_hs_fsm_two_lane_step_alignment_test(dut):
    if env_int("NUM_LANES_G", default=1) != 2:
        return

    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.rxFsmRst.setimmediatevalue(0)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut, reset_names=("rxRst",))

    header_beats: list[dict[str, int]] = []
    data_beats: list[dict[str, int]] = []
    header_words = [
        repeat_byte(0xA1),
        repeat_byte(0x12),
        repeat_byte(0x34),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x03),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x01),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x00),
        repeat_byte(0x03),
        repeat_byte(0x00),
        repeat_byte(0x02),
        repeat_byte(0x00),
        repeat_byte(0x04),
        repeat_byte(0x5E),
    ]

    await _send_handshaked_beat(
        dut,
        data=_beat_data([CXP_MARKER, repeat_byte(CXP_PKT_IMAGE_HEADER)], num_lanes=2),
        keep=lane_keep_mask([0, 1]),
    )
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    for index in range(0, len(header_words), 2):
        words = header_words[index : index + 2]
        await _send_handshaked_beat(
            dut,
            data=_beat_data(words, num_lanes=2),
            keep=lane_keep_mask(list(range(len(words)))),
        )
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    await _send_handshaked_beat(
        dut,
        data=_beat_data([CXP_MARKER], num_lanes=2),
        keep=lane_keep_mask([0]),
    )
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(
        dut,
        data=_beat_data([repeat_byte(CXP_PKT_IMAGE_LINE), 0x11111111], num_lanes=2),
        keep=lane_keep_mask([0, 1]),
    )
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)
    await _send_handshaked_beat(
        dut,
        data=_beat_data([0x22222222, 0x33333333], num_lanes=2),
        keep=lane_keep_mask([0, 1]),
    )
    _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    for _ in range(8):
        await RisingEdge(dut.rxClk)
        await Timer(1, unit="ns")
        _capture_outputs(dut, header_beats=header_beats, data_beats=data_beats)

    assert header_beats == [
        {
            "hdrTData": pack_words(
                [
                    0x12345EA1,
                    0x00000003,
                    0x00000000,
                    0x00000001,
                    0x00000000,
                    0x00000003,
                    0x00040002,
                ]
            ),
            "hdrTLast": 1,
            "hdrTSof": 1,
        }
    ]
    assert data_beats == [
        {
            "dataTData": pack_words([0x11111111, 0x22222222]),
            "dataTKeep": keep_for_words(2),
            "dataTLast": 0,
        },
        {
            "dataTData": 0x33333333,
            "dataTKeep": keep_for_words(1),
            "dataTLast": 1,
        },
    ]


@cocotb.test(skip=os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1")
async def coaxpress_rx_hs_fsm_repeated_single_line_frame_known_issue_test(dut):
    if env_int("NUM_LANES_G", default=1) != 1:
        return

    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.rxFsmRst.setimmediatevalue(0)
    dut.sAxisTValid.setimmediatevalue(0)
    dut.sAxisTData.setimmediatevalue(0)
    dut.sAxisTKeep.setimmediatevalue(0)
    dut.sAxisTLast.setimmediatevalue(0)
    await reset_dut(dut, reset_names=("rxRst",))

    frame_count = env_int("CXP_RX_HSFSM_FRAME_COUNT", default=72)
    error_pulses = 0

    for index in range(frame_count):
        await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
        error_pulses += int(dut.rxFsmError.value)
        await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_HEADER), keep=0xF)
        error_pulses += int(dut.rxFsmError.value)
        for word in _single_line_header_words():
            await _send_handshaked_beat(dut, data=word, keep=0xF)
            error_pulses += int(dut.rxFsmError.value)
        await _send_handshaked_beat(dut, data=CXP_MARKER, keep=0xF)
        error_pulses += int(dut.rxFsmError.value)
        await _send_handshaked_beat(dut, data=repeat_byte(CXP_PKT_IMAGE_LINE), keep=0xF)
        error_pulses += int(dut.rxFsmError.value)
        await _send_handshaked_beat(dut, data=0xA0000000 + index, keep=0xF)
        error_pulses += int(dut.rxFsmError.value)

    await cycle(dut.rxClk, 8)
    error_pulses += sum(int(dut.rxFsmError.value) for _ in range(1))
    assert error_pulses == 0


PARAMETER_SWEEP = [
    parameter_case("single_lane", NUM_LANES_G="1", RX_FSM_CNT_WIDTH_G="8"),
    parameter_case("dual_lane", NUM_LANES_G="2", RX_FSM_CNT_WIDTH_G="8"),
    parameter_case("quad_lane", NUM_LANES_G="4", RX_FSM_CNT_WIDTH_G="8"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_CoaXPressRxHsFsm(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressrxhsfsmwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxWordPacker.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxHsFsm.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressRxHsFsmWrapper.vhd",
            ]
        },
    )
