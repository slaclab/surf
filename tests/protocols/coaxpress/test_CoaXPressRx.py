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
# - Sweep: Keep the first `CoaXPressRx` assembly pass on the stable one-lane
#   path while still exercising all three externally visible outputs: config,
#   image header/data, and the synchronized ACK/event sidebands.
# - Stimulus: Drive one control-ack packet, one event packet, one `IO_ACK`,
#   and one rectangular image transaction directly into the raw receive lane,
#   keeping the receive-side packets spec-shaped where the current RTL can
#   consume that framing.
# - Checks: The assembled RX path must forward the config completion word,
#   export the event tag, pulse `trigAck`, emit the seven 32-bit image-header
#   words in order, and forward the programmed line payload with `SOF`/`TLAST`
#   behavior preserved through the output FIFOs.
# - Timing: All DUT-visible domains are driven in lockstep so the bench checks
#   the real FIFO/FSM sequencing without introducing unrelated clock skew.

import os

import cocotb
from cocotb.triggers import Event, RisingEdge, Timer
import pytest

from tests.common.regression_utils import env_flag, env_int, parameter_case, run_surf_vhdl_test, start_lockstep_clocks
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_IDLE,
    CXP_IDLE_K,
    CXP_IO_ACK,
    CXP_MARKER,
    CXP_PKT_CTRL_ACK_NO_TAG,
    CXP_PKT_EVENT,
    CXP_PKT_IMAGE_HEADER,
    CXP_PKT_IMAGE_LINE,
    CXP_SOP,
    append_snapshot_if_valid,
    cxp_crc_word,
    find_subsequence,
    pack_words,
    reset_signals,
    repeat_byte,
    send_rx_word,
    set_initial_values,
)


HEADER_WORDS = [
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
    repeat_byte(0x01),
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

SINGLE_LINE_HEADER_WORDS = [
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

EXPECTED_HDR_WORDS = [
    0x3456AA12,
    0x00000003,
    0x00000004,
    0x00000001,
    0x00000005,
    0x00000003,
    0x00200010,
]

def _event_crc_words(*, event_bytes: tuple[int, int, int, int], packet_tag: int, payload_words: list[int]) -> list[int]:
    crc_inputs = [
        *[repeat_byte(byte) for byte in event_bytes],
        repeat_byte(packet_tag),
        repeat_byte((len(payload_words) >> 8) & 0xFF),
        repeat_byte(len(payload_words) & 0xFF),
        *payload_words,
    ]
    return [
        *crc_inputs,
        cxp_crc_word(crc_inputs),
    ]


def _pack_lane_nibbles(values: list[int]) -> int:
    packed = 0
    for index, value in enumerate(values):
        packed |= (value & 0xF) << (4 * index)
    return packed


def _image_header_words(
    *,
    stream_id: int = 0x12,
    source_tag: int = 0x3456,
    x_size: int = 3,
    x_offs: int = 4,
    y_size: int = 1,
    y_offs: int = 5,
    dsize_l: int = 3,
    pixel_f: int = 0x0010,
    tap_g: int = 0x0020,
    flags: int = 0xAA,
) -> list[int]:
    def rep24(value: int) -> list[int]:
        return [
            repeat_byte((value >> 16) & 0xFF),
            repeat_byte((value >> 8) & 0xFF),
            repeat_byte(value & 0xFF),
        ]

    return [
        repeat_byte(stream_id),
        repeat_byte((source_tag >> 8) & 0xFF),
        repeat_byte(source_tag & 0xFF),
        *rep24(x_size),
        *rep24(x_offs),
        *rep24(y_size),
        *rep24(y_offs),
        *rep24(dsize_l),
        repeat_byte((pixel_f >> 8) & 0xFF),
        repeat_byte(pixel_f & 0xFF),
        repeat_byte((tap_g >> 8) & 0xFF),
        repeat_byte(tap_g & 0xFF),
        repeat_byte(flags),
    ]


def _logic_value_to_int(value, *, default: int = 0) -> int:
    return int(value) if value.is_resolvable else default


def _capture_outputs(
    dut,
    *,
    cfg_beats: list[tuple[int, int, int]],
    data_beats: list[tuple[int, int, int, int]],
    hdr_beats: list[tuple[int, int, int, int]],
    event_tags: list[int],
    trig_ack_cycles: list[int],
    cycle_index: int,
) -> None:
    cfg_samples: list[dict[str, int]] = []
    data_samples: list[dict[str, int]] = []
    hdr_samples: list[dict[str, int]] = []
    append_snapshot_if_valid(cfg_samples, dut, valid_name="cfgTValid", field_names=("cfgTData", "cfgTKeep", "cfgTLast"))
    append_snapshot_if_valid(
        data_samples,
        dut,
        valid_name="dataTValid",
        field_names=("dataTData", "dataTKeep", "dataTLast", "dataTUser"),
    )
    append_snapshot_if_valid(
        hdr_samples,
        dut,
        valid_name="hdrTValid",
        field_names=("hdrTData", "hdrTKeep", "hdrTLast", "hdrTUser"),
    )
    cfg_beats.extend((sample["cfgTData"], sample["cfgTKeep"], sample["cfgTLast"]) for sample in cfg_samples)
    data_beats.extend(
        (sample["dataTData"], sample["dataTKeep"], sample["dataTLast"], sample["dataTUser"]) for sample in data_samples
    )
    hdr_beats.extend(
        (sample["hdrTData"], sample["hdrTKeep"], sample["hdrTLast"], sample["hdrTUser"]) for sample in hdr_samples
    )
    if int(dut.eventAck.value) == 1:
        event_tags.append(int(dut.eventTag.value))
    if int(dut.trigAck.value) == 1:
        trig_ack_cycles.append(cycle_index)


async def _send_multi_lane_word(dut, *, lane_words: list[int], lane_ks: list[int], link_up: int) -> None:
    num_lanes = env_int("NUM_LANES_G", default=1)
    await send_rx_word(
        dut,
        data=pack_words(lane_words + [CXP_IDLE] * (num_lanes - len(lane_words))),
        data_k=_pack_lane_nibbles(lane_ks + [CXP_IDLE_K] * (num_lanes - len(lane_ks))),
        clk=dut.rxClk,
        link_up=link_up,
    )


def _active_link_mask() -> int:
    return (1 << env_int("NUM_LANES_G", default=1)) - 1


async def _send_isolated_lane_word(
    dut,
    *,
    lane: int,
    data: int,
    data_k: int,
    link_up: int | None = None,
) -> None:
    num_lanes = env_int("NUM_LANES_G", default=1)
    lane_words = [CXP_IDLE] * num_lanes
    lane_ks = [CXP_IDLE_K] * num_lanes
    lane_words[lane] = data
    lane_ks[lane] = data_k
    await _send_multi_lane_word(dut, lane_words=lane_words, lane_ks=lane_ks, link_up=_active_link_mask() if link_up is None else link_up)


def _isolated_lane_frame_sequence(
    *,
    line_words: list[int],
    header_words: list[int] | None = None,
    stream_id: int = 0x22,
    packet_tag: int = 0x33,
    corrupt_header_index: int | None = None,
    corrupt_header_word: int = 0x01020304,
) -> list[tuple[int, int]]:
    header_payload_words = list(header_words if header_words is not None else HEADER_WORDS)
    if corrupt_header_index is not None:
        header_payload_words[corrupt_header_index] = corrupt_header_word

    return [
        (CXP_SOP, 0xF),
        (repeat_byte(0x01), 0x0),
        (repeat_byte(stream_id), 0x0),
        (repeat_byte(packet_tag), 0x0),
        (repeat_byte((len(header_payload_words) + 2) >> 8), 0x0),
        (repeat_byte((len(header_payload_words) + 2) & 0xFF), 0x0),
        (CXP_MARKER, 0xF),
        (repeat_byte(CXP_PKT_IMAGE_HEADER), 0x0),
        *[(word, 0xF) for word in header_payload_words],
        (CXP_SOP, 0xF),
        (repeat_byte(0x01), 0x0),
        (repeat_byte((stream_id + 1) & 0xFF), 0x0),
        (repeat_byte((packet_tag + 1) & 0xFF), 0x0),
        (repeat_byte((len(line_words) + 2) >> 8), 0x0),
        (repeat_byte((len(line_words) + 2) & 0xFF), 0x0),
        (CXP_MARKER, 0xF),
        (repeat_byte(CXP_PKT_IMAGE_LINE), 0x0),
        *[(word, 0x0) for word in line_words],
    ]


async def _send_isolated_lane_frame(
    dut,
    *,
    lane: int,
    line_words: list[int],
    header_words: list[int] | None = None,
    stream_id: int = 0x22,
    packet_tag: int = 0x33,
    corrupt_header_index: int | None = None,
    corrupt_header_word: int = 0x01020304,
) -> None:
    sequence = _isolated_lane_frame_sequence(
        line_words=line_words,
        header_words=header_words,
        stream_id=stream_id,
        packet_tag=packet_tag,
        corrupt_header_index=corrupt_header_index,
        corrupt_header_word=corrupt_header_word,
    )
    for data, data_k in sequence:
        await _send_isolated_lane_word(dut, lane=lane, data=data, data_k=data_k)


async def _send_isolated_lane_frame_and_capture(
    dut,
    *,
    lane: int,
    line_words: list[int],
    data_beats: list[tuple[int, int, int, int]],
    hdr_beats: list[tuple[int, int, int, int]],
    header_words: list[int] | None = None,
    stream_id: int = 0x22,
    packet_tag: int = 0x33,
    corrupt_header_index: int | None = None,
    corrupt_header_word: int = 0x01020304,
    start_cycle_index: int = 0,
) -> int:
    sequence = _isolated_lane_frame_sequence(
        line_words=line_words,
        header_words=header_words,
        stream_id=stream_id,
        packet_tag=packet_tag,
        corrupt_header_index=corrupt_header_index,
        corrupt_header_word=corrupt_header_word,
    )
    cycle_index = start_cycle_index
    for data, data_k in sequence:
        await _send_isolated_lane_word(dut, lane=lane, data=data, data_k=data_k)
        _capture_outputs(
            dut,
            cfg_beats=[],
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            event_tags=[],
            trig_ack_cycles=[],
            cycle_index=cycle_index,
        )
        cycle_index += 1

    return cycle_index


async def _send_one_lane_frame(
    dut,
    *,
    line_word: int,
    header_stream_id: int = 0x22,
    header_packet_tag: int = 0x33,
    line_stream_id: int = 0x44,
    line_packet_tag: int = 0x55,
) -> None:
    sequence = [
        (CXP_SOP, 0xF),
        (repeat_byte(0x01), 0x0),
        (repeat_byte(header_stream_id), 0x0),
        (repeat_byte(header_packet_tag), 0x0),
        (repeat_byte(0x00), 0x0),
        (repeat_byte(25), 0x0),
        (CXP_MARKER, 0xF),
        (repeat_byte(CXP_PKT_IMAGE_HEADER), 0x0),
        *[(word, 0xF) for word in SINGLE_LINE_HEADER_WORDS],
        (CXP_SOP, 0xF),
        (repeat_byte(0x01), 0x0),
        (repeat_byte(line_stream_id), 0x0),
        (repeat_byte(line_packet_tag), 0x0),
        (repeat_byte(0x00), 0x0),
        (repeat_byte(3), 0x0),
        (CXP_MARKER, 0xF),
        (repeat_byte(CXP_PKT_IMAGE_LINE), 0x0),
        (line_word, 0x0),
    ]
    for data, data_k in sequence:
        await send_rx_word(dut, data=data, data_k=data_k, clk=dut.rxClk)


async def _count_signal_high_cycles(signal, clk, stop_event: Event, counts: dict[str, int], key: str) -> None:
    while True:
        await RisingEdge(clk)
        await Timer(2, unit="ns")
        if stop_event.is_set():
            return
        counts[key] += int(signal.value)


async def _drive_idle_and_capture(
    dut,
    *,
    cycles: int,
    data_beats: list[tuple[int, int, int, int]],
    hdr_beats: list[tuple[int, int, int, int]],
    start_cycle_index: int = 0,
) -> None:
    num_lanes = env_int("NUM_LANES_G", default=1)
    for cycle_index in range(start_cycle_index, start_cycle_index + cycles):
        await _send_multi_lane_word(
            dut,
            lane_words=[CXP_IDLE] * num_lanes,
            lane_ks=[CXP_IDLE_K] * num_lanes,
            link_up=_active_link_mask(),
        )
        _capture_outputs(
            dut,
            cfg_beats=[],
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            event_tags=[],
            trig_ack_cycles=[],
            cycle_index=cycle_index,
        )


async def _drive_idle_rx(dut, *, cycles: int) -> None:
    num_lanes = env_int("NUM_LANES_G", default=1)
    for _ in range(cycles):
        await _send_multi_lane_word(
            dut,
            lane_words=[CXP_IDLE] * num_lanes,
            lane_ks=[CXP_IDLE_K] * num_lanes,
            link_up=_active_link_mask(),
        )


async def _drive_idle_until_signal_high(dut, *, signal, max_cycles: int) -> bool:
    for _ in range(max_cycles):
        await _drive_idle_rx(dut, cycles=1)
        if _logic_value_to_int(signal.value) == 1:
            return True
    return False


async def _pulse_rx_fsm_reset(dut, *, cycles: int = 4) -> None:
    dut.rxFsmRst.value = 1
    await _drive_idle_rx(dut, cycles=cycles)
    dut.rxFsmRst.value = 0


@cocotb.test()
async def coaxpress_rx_one_lane_integration_test(dut):
    if env_int("NUM_LANES_G", default=1) != 1:
        return
    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "rxData": 0,
            "rxDataK": 0,
            "rxLinkUp": 1,
            "rxFsmRst": 0,
            "rxNumberOfLane": 0,
            "dataTReady": 1,
            "hdrTReady": 1,
        },
    )
    await reset_signals(
        dut,
        clk=dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst"),
        assert_cycles=4,
        release_cycles=4,
    )

    cfg_beats: list[tuple[int, int, int]] = []
    data_beats: list[tuple[int, int, int, int]] = []
    hdr_beats: list[tuple[int, int, int, int]] = []
    event_tags: list[int] = []
    trig_ack_cycles: list[int] = []

    sequence = [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_CTRL_ACK_NO_TAG), 0x0),
        (repeat_byte(0x00), 0x0),
        (0x04000000, 0x0),
        (0x01234567, 0x0),
        (0xCAFEBABE, 0x0),
        (CXP_EOP, 0xF),
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT), 0x0),
        *[
            (word, 0x0)
            for word in _event_crc_words(
                event_bytes=(0x10, 0x11, 0x12, 0x13),
                packet_tag=0x5A,
                payload_words=[0x11223344],
            )
        ],
        (CXP_EOP, 0xF),
        (CXP_IO_ACK, 0xF),
        (repeat_byte(0x01), 0x0),
        (CXP_SOP, 0xF),
        (repeat_byte(0x01), 0x0),
        (repeat_byte(0x22), 0x0),
        (repeat_byte(0x33), 0x0),
        (repeat_byte(0x00), 0x0),
        (repeat_byte(25), 0x0),
        (CXP_MARKER, 0xF),
        (repeat_byte(CXP_PKT_IMAGE_HEADER), 0x0),
        *[(word, 0xF) for word in HEADER_WORDS],
        (CXP_SOP, 0xF),
        (repeat_byte(0x01), 0x0),
        (repeat_byte(0x44), 0x0),
        (repeat_byte(0x55), 0x0),
        (repeat_byte(0x00), 0x0),
        (repeat_byte(5), 0x0),
        (CXP_MARKER, 0xF),
        (repeat_byte(CXP_PKT_IMAGE_LINE), 0x0),
        (0x11111111, 0x0),
        (0x22222222, 0x0),
        (0x33333333, 0x0),
        (0xBEEFBEEF, 0x0),
        (CXP_EOP, 0xF),
    ]

    for cycle_index, (data, data_k) in enumerate(sequence):
        await send_rx_word(dut, data=data, data_k=data_k, clk=dut.rxClk)
        _capture_outputs(
            dut,
            cfg_beats=cfg_beats,
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            event_tags=event_tags,
            trig_ack_cycles=trig_ack_cycles,
            cycle_index=cycle_index,
        )

    for cycle_index in range(40):
        await send_rx_word(dut, data=0xB53C3CBC, data_k=0x7, clk=dut.rxClk)
        _capture_outputs(
            dut,
            cfg_beats=cfg_beats,
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            event_tags=event_tags,
            trig_ack_cycles=trig_ack_cycles,
            cycle_index=cycle_index + len(sequence),
        )

    assert cfg_beats == [(0x0123456700000000, 0xFF, 0)]
    assert event_tags == [0x5A]
    assert trig_ack_cycles
    assert [beat[:3] for beat in hdr_beats] == [(word, 0xF, 1 if index == len(EXPECTED_HDR_WORDS) - 1 else 0) for index, word in enumerate(EXPECTED_HDR_WORDS)]
    assert [beat[0] for beat in hdr_beats] == EXPECTED_HDR_WORDS
    assert data_beats == [
        (0x11111111, 0xF, 0, 0),
        (0x22222222, 0xF, 0, 0),
        (0x33333333, 0xF, 1, 0),
    ]


async def _drive_two_lane_mux_rotation(
    dut,
) -> tuple[list[tuple[int, int, int, int]], list[tuple[int, int, int, int]], list[int]]:
    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "rxData": 0,
            "rxDataK": 0,
            "rxLinkUp": 0x3,
            "rxFsmRst": 0,
            "rxNumberOfLane": 1,
            "dataTReady": 1,
            "hdrTReady": 1,
        },
    )
    await reset_signals(
        dut,
        clk=dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst"),
        assert_cycles=4,
        release_cycles=4,
    )

    data_beats: list[tuple[int, int, int, int]] = []
    hdr_beats: list[tuple[int, int, int, int]] = []
    error_cycles: list[int] = []

    async def capture(cycle_index: int) -> None:
        _capture_outputs(
            dut,
            cfg_beats=[],
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            event_tags=[],
            trig_ack_cycles=[],
            cycle_index=cycle_index,
        )
        if int(dut.rxFsmError.value) == 1:
            error_cycles.append(cycle_index)

    lane0_sequence = [
        ([CXP_SOP, CXP_IDLE], [0xF, CXP_IDLE_K]),
        ([repeat_byte(0x01), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([repeat_byte(0x22), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([repeat_byte(0x33), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([repeat_byte(0x00), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([repeat_byte(25), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([CXP_MARKER, CXP_IDLE], [0xF, CXP_IDLE_K]),
        ([repeat_byte(CXP_PKT_IMAGE_HEADER), CXP_IDLE], [0x0, CXP_IDLE_K]),
        *[([word, CXP_IDLE], [0xF, CXP_IDLE_K]) for word in HEADER_WORDS],
        ([CXP_SOP, CXP_IDLE], [0xF, CXP_IDLE_K]),
        ([repeat_byte(0x01), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([repeat_byte(0x44), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([repeat_byte(0x55), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([repeat_byte(0x00), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([repeat_byte(5), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([CXP_MARKER, CXP_IDLE], [0xF, CXP_IDLE_K]),
        ([repeat_byte(CXP_PKT_IMAGE_LINE), CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([0x11111111, CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([0x22222222, CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([0x33333333, CXP_IDLE], [0x0, CXP_IDLE_K]),
        ([CXP_EOP, CXP_IDLE], [0xF, CXP_IDLE_K]),
    ]
    lane1_sequence = [
        ([CXP_IDLE, CXP_SOP], [CXP_IDLE_K, 0xF]),
        ([CXP_IDLE, repeat_byte(0x01)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, repeat_byte(0x22)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, repeat_byte(0x33)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, repeat_byte(0x00)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, repeat_byte(25)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, CXP_MARKER], [CXP_IDLE_K, 0xF]),
        ([CXP_IDLE, repeat_byte(CXP_PKT_IMAGE_HEADER)], [CXP_IDLE_K, 0x0]),
        *[([CXP_IDLE, word], [CXP_IDLE_K, 0xF]) for word in HEADER_WORDS],
        ([CXP_IDLE, CXP_SOP], [CXP_IDLE_K, 0xF]),
        ([CXP_IDLE, repeat_byte(0x01)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, repeat_byte(0x44)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, repeat_byte(0x55)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, repeat_byte(0x00)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, repeat_byte(5)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, CXP_MARKER], [CXP_IDLE_K, 0xF]),
        ([CXP_IDLE, repeat_byte(CXP_PKT_IMAGE_LINE)], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, 0x44444444], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, 0x55555555], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, 0x66666666], [CXP_IDLE_K, 0x0]),
        ([CXP_IDLE, CXP_EOP], [CXP_IDLE_K, 0xF]),
    ]

    cycle_index = 0
    for lane_words, lane_ks in lane0_sequence:
        await _send_multi_lane_word(dut, lane_words=lane_words, lane_ks=lane_ks, link_up=0x3)
        await capture(cycle_index)
        cycle_index += 1

    for _ in range(12):
        await _send_multi_lane_word(dut, lane_words=[CXP_IDLE, CXP_IDLE], lane_ks=[CXP_IDLE_K, CXP_IDLE_K], link_up=0x3)
        await capture(cycle_index)
        cycle_index += 1

    for lane_words, lane_ks in lane1_sequence:
        await _send_multi_lane_word(dut, lane_words=lane_words, lane_ks=lane_ks, link_up=0x3)
        await capture(cycle_index)
        cycle_index += 1

    for _ in range(80):
        await _send_multi_lane_word(dut, lane_words=[CXP_IDLE, CXP_IDLE], lane_ks=[CXP_IDLE_K, CXP_IDLE_K], link_up=0x3)
        await capture(cycle_index)
        cycle_index += 1

    return hdr_beats, data_beats, error_cycles


@cocotb.test()
async def coaxpress_rx_two_lane_mux_rotation_test(dut):
    if env_int("NUM_LANES_G", default=1) != 2:
        return

    hdr_beats, data_beats, error_cycles = await _drive_two_lane_mux_rotation(dut)

    assert not error_cycles
    assert [beat[0] for beat in hdr_beats] == EXPECTED_HDR_WORDS * 2
    assert [beat[0] for beat in data_beats] == [
        0x11111111,
        0x22222222,
        0x33333333,
        0x44444444,
        0x55555555,
        0x66666666,
    ]
    assert [beat[2] for beat in data_beats] == [0, 0, 1, 0, 0, 1]


#
# Opt-in investigation benches. These stay behind RUN_KNOWN_ISSUE_TESTS until
# the remaining 4-lane short-frame boundary issue in CoaXPressRxHsFsm is fixed.
#


@cocotb.test(skip=os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1")
async def coaxpress_rx_four_lane_fsm_error_reset_recovery_known_issue_test(dut):
    if env_int("NUM_LANES_G", default=1) != 4:
        return

    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "rxData": 0,
            "rxDataK": 0,
            "rxLinkUp": 0xF,
            "rxFsmRst": 0,
            "rxNumberOfLane": 3,
            "dataTReady": 1,
            "hdrTReady": 1,
        },
    )
    await reset_signals(
        dut,
        clk=dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst"),
        assert_cycles=4,
        release_cycles=4,
    )

    await _send_isolated_lane_frame(
        dut,
        lane=0,
        line_words=[0x0BAD0000, 0x0BAD0001, 0x0BAD0002],
        header_words=_image_header_words(dsize_l=3),
        stream_id=0x40,
        packet_tag=0x50,
        corrupt_header_index=5,
    )
    assert await _drive_idle_until_signal_high(
        dut,
        signal=dut.rxFsmError,
        max_cycles=env_int("CXP_RX_FOUR_LANE_ERROR_WAIT_CYCLES", default=64),
    )
    await _pulse_rx_fsm_reset(dut)

    data_beats: list[tuple[int, int, int, int]] = []
    hdr_beats: list[tuple[int, int, int, int]] = []
    cycle_index = 0
    expected_recovery_words: list[int] = []
    for lane in range(4):
        recovery_words = [0xD1000000 | (lane << 8) | word_index for word_index in range(3)]
        expected_recovery_words.extend(recovery_words)
        cycle_index = await _send_isolated_lane_frame_and_capture(
            dut,
            lane=lane,
            line_words=recovery_words,
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            stream_id=0x60 + lane,
            packet_tag=0x70 + lane,
            start_cycle_index=cycle_index,
        )

    await _drive_idle_and_capture(dut, cycles=256, data_beats=data_beats, hdr_beats=hdr_beats, start_cycle_index=cycle_index)

    assert [beat[0] for beat in hdr_beats] == EXPECTED_HDR_WORDS * 4, hdr_beats
    observed_data_words = [beat[0] for beat in data_beats]
    subseq_start = find_subsequence(observed_data_words, expected_recovery_words)
    assert subseq_start is not None, data_beats
    observed_recovery_last = [beat[2] for beat in data_beats[subseq_start : subseq_start + len(expected_recovery_words)]]
    assert observed_recovery_last == [0, 0, 1] * 4, observed_recovery_last


@cocotb.test(skip=os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1")
async def coaxpress_rx_four_lane_clean_rotation_known_issue_test(dut):
    if env_int("NUM_LANES_G", default=1) != 4:
        return

    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "rxData": 0,
            "rxDataK": 0,
            "rxLinkUp": 0xF,
            "rxFsmRst": 0,
            "rxNumberOfLane": 3,
            "dataTReady": 1,
            "hdrTReady": 1,
        },
    )
    await reset_signals(
        dut,
        clk=dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst"),
        assert_cycles=4,
        release_cycles=4,
    )

    data_beats: list[tuple[int, int, int, int]] = []
    hdr_beats: list[tuple[int, int, int, int]] = []
    cycle_index = 0
    expected_data_words: list[int] = []
    for lane in range(4):
        line_words = [0xC1000000 | (lane << 8) | word_index for word_index in range(3)]
        expected_data_words.extend(line_words)
        cycle_index = await _send_isolated_lane_frame_and_capture(
            dut,
            lane=lane,
            line_words=line_words,
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            stream_id=0x30 + lane,
            packet_tag=0x40 + lane,
            start_cycle_index=cycle_index,
        )

    await _drive_idle_and_capture(
        dut,
        cycles=256,
        data_beats=data_beats,
        hdr_beats=hdr_beats,
        start_cycle_index=cycle_index,
    )

    assert [beat[0] for beat in hdr_beats] == EXPECTED_HDR_WORDS * 4, hdr_beats
    observed_data_words = [beat[0] for beat in data_beats]
    assert observed_data_words == expected_data_words, observed_data_words
    assert [beat[2] for beat in data_beats] == [0, 0, 1] * 4, data_beats


@cocotb.test(skip=os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1")
async def coaxpress_rx_four_lane_fsm_error_recovery_known_issue_test(dut):
    if env_int("NUM_LANES_G", default=1) != 4:
        return

    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "rxData": 0,
            "rxDataK": 0,
            "rxLinkUp": 0xF,
            "rxFsmRst": 0,
            "rxNumberOfLane": 3,
            "dataTReady": 1,
            "hdrTReady": 1,
        },
    )
    await reset_signals(
        dut,
        clk=dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst"),
        assert_cycles=4,
        release_cycles=4,
    )

    signal_counts = {"error_pulses": 0}
    stop_event = Event()
    monitor_task = cocotb.start_soon(_count_signal_high_cycles(dut.rxFsmError, dut.rxClk, stop_event, signal_counts, "error_pulses"))

    data_beats: list[tuple[int, int, int, int]] = []
    hdr_beats: list[tuple[int, int, int, int]] = []
    cycle_index = 0
    malformed_header = _image_header_words(dsize_l=3)
    cycle_index = await _send_isolated_lane_frame_and_capture(
        dut,
        lane=0,
        line_words=[0x0BAD0000, 0x0BAD0001, 0x0BAD0002],
        data_beats=data_beats,
        hdr_beats=hdr_beats,
        header_words=malformed_header,
        stream_id=0x40,
        packet_tag=0x50,
        corrupt_header_index=5,
        start_cycle_index=cycle_index,
    )

    recovery_lane_order = [1, 2, 3, 0]
    expected_recovery_words: list[int] = []
    for lane in recovery_lane_order:
        recovery_words = [
            0xD1000000 | (lane << 8) | word_index
            for word_index in range(3)
        ]
        expected_recovery_words.extend(recovery_words)
        cycle_index = await _send_isolated_lane_frame_and_capture(
            dut,
            lane=lane,
            line_words=recovery_words,
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            stream_id=0x60 + lane,
            packet_tag=0x70 + lane,
            start_cycle_index=cycle_index,
        )

    await _drive_idle_and_capture(
        dut,
        cycles=256,
        data_beats=data_beats,
        hdr_beats=hdr_beats,
        start_cycle_index=cycle_index,
    )

    stop_event.set()
    await monitor_task

    observed_data_words = [beat[0] for beat in data_beats]
    observed_header_words = [beat[0] for beat in hdr_beats]
    assert signal_counts["error_pulses"] > 0
    assert find_subsequence(observed_header_words, EXPECTED_HDR_WORDS) is not None, observed_header_words
    subseq_start = find_subsequence(observed_data_words, expected_recovery_words)
    # Known issue under investigation:
    # a malformed 4-lane header does raise rxFsmError, but the current RTL does
    # not fully recover the expected post-error lane rotation and line payloads.
    assert subseq_start is not None, data_beats
    observed_recovery_last = [beat[2] for beat in data_beats[subseq_start : subseq_start + len(expected_recovery_words)]]
    assert observed_recovery_last == [0, 0, 1] * 4, observed_recovery_last


@cocotb.test(skip=os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1")
async def coaxpress_rx_four_lane_overflow_reset_recovery_known_issue_test(dut):
    if env_int("NUM_LANES_G", default=1) != 4:
        return

    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "rxData": 0,
            "rxDataK": 0,
            "rxLinkUp": 0xF,
            "rxFsmRst": 0,
            "rxNumberOfLane": 3,
            "dataTReady": 0,
            "hdrTReady": 1,
        },
    )
    await reset_signals(
        dut,
        clk=dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst"),
        assert_cycles=4,
        release_cycles=4,
    )

    signal_counts = {"error_pulses": 0, "overflow_pulses": 0}
    stop_event = Event()
    monitor_tasks = [
        cocotb.start_soon(_count_signal_high_cycles(dut.rxFsmError, dut.rxClk, stop_event, signal_counts, "error_pulses")),
        cocotb.start_soon(_count_signal_high_cycles(dut.rxOverflow, dut.rxClk, stop_event, signal_counts, "overflow_pulses")),
    ]

    stress_line_words = [0xA0000000 + word_index for word_index in range(80)]
    stress_header_words = _image_header_words(dsize_l=len(stress_line_words))
    stress_frame_count = env_int("CXP_RX_FOUR_LANE_OVERFLOW_FRAME_COUNT", default=32)
    for index in range(stress_frame_count):
        lane = index % 4
        await _send_isolated_lane_frame(
            dut,
            lane=lane,
            line_words=stress_line_words,
            header_words=stress_header_words,
            stream_id=0x20 + lane,
            packet_tag=0x30 + lane,
        )

    overflow_seen = await _drive_idle_until_signal_high(
        dut,
        signal=dut.rxOverflow,
        max_cycles=env_int("CXP_RX_FOUR_LANE_OVERFLOW_WAIT_CYCLES", default=4096),
    )
    dut.dataTReady.value = 1
    await _drive_idle_rx(dut, cycles=env_int("CXP_RX_FOUR_LANE_DRAIN_IDLE_CYCLES", default=512))
    await _pulse_rx_fsm_reset(dut)

    data_beats: list[tuple[int, int, int, int]] = []
    hdr_beats: list[tuple[int, int, int, int]] = []
    cycle_index = 0
    expected_recovery_words: list[int] = []
    for lane in range(4):
        recovery_words = [0xE1000000 | (lane << 8) | word_index for word_index in range(3)]
        expected_recovery_words.extend(recovery_words)
        cycle_index = await _send_isolated_lane_frame_and_capture(
            dut,
            lane=lane,
            line_words=recovery_words,
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            stream_id=0x80 + lane,
            packet_tag=0x90 + lane,
            start_cycle_index=cycle_index,
        )

    await _drive_idle_and_capture(
        dut,
        cycles=env_int("CXP_RX_FOUR_LANE_RECOVERY_IDLE_CYCLES", default=512),
        data_beats=data_beats,
        hdr_beats=hdr_beats,
        start_cycle_index=cycle_index,
    )

    stop_event.set()
    for task in monitor_tasks:
        await task

    assert overflow_seen or signal_counts["overflow_pulses"] > 0, signal_counts
    assert [beat[0] for beat in hdr_beats] == EXPECTED_HDR_WORDS * 4, hdr_beats
    observed_data_words = [beat[0] for beat in data_beats]
    subseq_start = find_subsequence(observed_data_words, expected_recovery_words)
    assert subseq_start is not None, (signal_counts, observed_data_words[-64:])
    observed_recovery_last = [beat[2] for beat in data_beats[subseq_start : subseq_start + len(expected_recovery_words)]]
    assert observed_recovery_last == [0, 0, 1] * 4, (signal_counts, observed_recovery_last)


@cocotb.test(skip=os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1")
async def coaxpress_rx_four_lane_overflow_recovery_known_issue_test(dut):
    if env_int("NUM_LANES_G", default=1) != 4:
        return

    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "rxData": 0,
            "rxDataK": 0,
            "rxLinkUp": 0xF,
            "rxFsmRst": 0,
            "rxNumberOfLane": 3,
            "dataTReady": 0,
            "hdrTReady": 1,
        },
    )
    await reset_signals(
        dut,
        clk=dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst"),
        assert_cycles=4,
        release_cycles=4,
    )

    signal_counts = {"error_pulses": 0, "overflow_pulses": 0}
    stop_event = Event()
    monitor_tasks = [
        cocotb.start_soon(_count_signal_high_cycles(dut.rxFsmError, dut.rxClk, stop_event, signal_counts, "error_pulses")),
        cocotb.start_soon(_count_signal_high_cycles(dut.rxOverflow, dut.rxClk, stop_event, signal_counts, "overflow_pulses")),
    ]

    stress_line_words = [0xA0000000 + word_index for word_index in range(80)]
    stress_header_words = _image_header_words(dsize_l=len(stress_line_words))
    stress_frame_count = env_int("CXP_RX_FOUR_LANE_OVERFLOW_FRAME_COUNT", default=32)
    idle_cycles = env_int("CXP_RX_FOUR_LANE_OVERFLOW_IDLE_CYCLES", default=3200)
    cycle_index = 0
    for index in range(stress_frame_count):
        lane = index % 4
        await _send_isolated_lane_frame(
            dut,
            lane=lane,
            line_words=stress_line_words,
            header_words=stress_header_words,
            stream_id=0x20 + lane,
            packet_tag=0x30 + lane,
        )
        cycle_index += len(_isolated_lane_frame_sequence(line_words=stress_line_words, header_words=stress_header_words, stream_id=0x20 + lane, packet_tag=0x30 + lane))

    dut.dataTReady.value = 1

    data_beats: list[tuple[int, int, int, int]] = []
    hdr_beats: list[tuple[int, int, int, int]] = []
    recovery_line_words_by_lane = {
        lane: [0xE1000000 | (lane << 8) | word_index for word_index in range(3)]
        for lane in range(4)
    }
    expected_recovery_words = [word for lane in range(4) for word in recovery_line_words_by_lane[lane]]
    for lane in range(4):
        cycle_index = await _send_isolated_lane_frame_and_capture(
            dut,
            lane=lane,
            line_words=recovery_line_words_by_lane[lane],
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            stream_id=0x80 + lane,
            packet_tag=0x90 + lane,
            start_cycle_index=cycle_index,
        )

    await _drive_idle_and_capture(
        dut,
        cycles=idle_cycles,
        data_beats=data_beats,
        hdr_beats=hdr_beats,
        start_cycle_index=cycle_index,
    )

    stop_event.set()
    for task in monitor_tasks:
        await task

    observed_data_words = [beat[0] for beat in data_beats]
    # Known issue under investigation:
    # with 4 bonded lanes, sustained sink backpressure can emit rxFsmError
    # pulses before or alongside the expected overflow indication. The desired
    # behavior is overflow-only, followed by clean post-stall recovery data.
    assert signal_counts["error_pulses"] == 0, signal_counts
    assert signal_counts["overflow_pulses"] > 0, signal_counts
    assert find_subsequence(observed_data_words, expected_recovery_words) is not None, observed_data_words[-64:]
    subseq_start = find_subsequence(observed_data_words, expected_recovery_words)
    assert subseq_start is not None
    observed_recovery_last = [beat[2] for beat in data_beats[subseq_start : subseq_start + len(expected_recovery_words)]]
    assert observed_recovery_last == [0, 0, 1] * 4, observed_recovery_last


@cocotb.test(skip=os.getenv("RUN_KNOWN_ISSUE_TESTS") != "1")
async def coaxpress_rx_repeated_single_line_frame_known_issue_test(dut):
    if env_int("NUM_LANES_G", default=1) != 1:
        return

    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "rxData": 0,
            "rxDataK": 0,
            "rxLinkUp": 1,
            "rxFsmRst": 0,
            "rxNumberOfLane": 0,
            "dataTReady": env_int("CXP_RX_KNOWN_ISSUE_DATA_READY", default=0),
            "hdrTReady": 1,
        },
    )
    await reset_signals(
        dut,
        clk=dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst"),
        assert_cycles=4,
        release_cycles=4,
    )

    frame_count = env_int("CXP_RX_REPEATED_FRAME_COUNT", default=72)
    vary_packet_fields = env_flag("CXP_RX_KNOWN_ISSUE_VARY_PACKET_FIELDS", default=False)
    signal_counts = {"error_pulses": 0, "overflow_pulses": 0}
    stop_event = Event()
    monitor_tasks = [
        cocotb.start_soon(_count_signal_high_cycles(dut.rxFsmError, dut.rxClk, stop_event, signal_counts, "error_pulses")),
        cocotb.start_soon(_count_signal_high_cycles(dut.rxOverflow, dut.rxClk, stop_event, signal_counts, "overflow_pulses")),
    ]
    for index in range(frame_count):
        header_stream_id = (0x50 + (2 * index)) & 0xFF if vary_packet_fields else 0x22
        header_packet_tag = (0x70 + (2 * index)) & 0xFF if vary_packet_fields else 0x33
        await _send_one_lane_frame(
            dut,
            line_word=0xA0000000 + index,
            header_stream_id=header_stream_id,
            header_packet_tag=header_packet_tag,
            line_stream_id=(header_stream_id + 1) & 0xFF if vary_packet_fields else 0x44,
            line_packet_tag=(header_packet_tag + 1) & 0xFF if vary_packet_fields else 0x55,
        )

    for _ in range(32):
        await send_rx_word(dut, data=CXP_IDLE, data_k=CXP_IDLE_K, clk=dut.rxClk)
    stop_event.set()
    for task in monitor_tasks:
        await task

    assert signal_counts["overflow_pulses"] > 0, (
        f"overflow_pulses={signal_counts['overflow_pulses']} error_pulses={signal_counts['error_pulses']}"
    )
    assert signal_counts["error_pulses"] == 0, (
        f"overflow_pulses={signal_counts['overflow_pulses']} error_pulses={signal_counts['error_pulses']}"
    )


PARAMETER_SWEEP = [
    parameter_case("single_lane", NUM_LANES_G="1", RX_FSM_CNT_WIDTH_G="8"),
    parameter_case("dual_lane", NUM_LANES_G="2", RX_FSM_CNT_WIDTH_G="8"),
    parameter_case("quad_lane", NUM_LANES_G="4", RX_FSM_CNT_WIDTH_G="8"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_CoaXPressRx(parameters):
    use_core_path_wrapper = os.getenv("CXP_RX_CORE_PATH_WRAPPER") == "1"
    if use_core_path_wrapper:
        toplevel = "surf.coaxpressrxcorepathwrapper"
        wrapper = "protocols/coaxpress/core/wrappers/CoaXPressRxCorePathWrapper.vhd"
    else:
        toplevel = "surf.coaxpressrxwrapper"
        wrapper = "protocols/coaxpress/core/wrappers/CoaXPressRxWrapper.vhd"
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel=toplevel,
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxWordPacker.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxLaneMux.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxLane.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxHsFsm.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRx.vhd",
                wrapper,
            ]
        },
    )
