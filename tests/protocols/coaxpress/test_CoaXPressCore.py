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
# - Sweep: Keep the current `CoaXPressCore` coverage on the one-lane top-level
#   path, but extend it across the three core-only integration surfaces that
#   software cares about: AXI-Lite control into TX/config, RX overflow status,
#   and RX FSM-error counting/recovery.
# - Stimulus: Program `configPktTag` and the fast low-speed rate over AXI-Lite,
#   send one SRPv3 read request through the config ingress, then drive raw RX
#   image-header traffic once with sustained software backpressure and once with
#   a malformed header followed by a clean retry.
# - Checks: The core must expose the programmed AXI-Lite values back to
#   software, serialize the matching tagged config request on TX, increment
#   `RxOverflowCnt` when the output path cannot drain, increment
#   `RxFsmErrorCnt` on malformed receive traffic, and still accept a later good
#   image frame instead of remaining in a stuck error state.
# - Timing: AXI-Lite, config ingress, and the raw RX/data/header paths all run
#   on the real top-level interfaces, so the bench checks the actual sequencing
#   across `CoaXPressAxiL`, `CoaXPressConfig`, `CoaXPressRx`, and `CoaXPressTx`.

import os

import cocotb
from cocotb.triggers import Event, RisingEdge, Timer, with_timeout
from cocotb.utils import get_sim_time
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.common.regression_utils import env_flag, env_int, run_surf_vhdl_test, start_lockstep_clocks
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_IDLE,
    CXP_IDLE_K,
    CXP_MARKER,
    CXP_EOP,
    CXP_PKT_IMAGE_HEADER,
    CXP_PKT_IMAGE_LINE,
    CXP_PKT_STREAM_DATA,
    CXP_SOP,
    cycle,
    collect_stream_bytes,
    cxp_crc_word,
    endian_swap32,
    find_subsequence,
    pack_u32_words_le,
    reset_signals,
    repeat_byte,
    send_rx_word,
    send_axis_payload,
    set_initial_values,
    word_to_bytes,
)


def _image_header_words(
    *,
    stream_id: int = 0x12,
    source_tag: int = 0x3456,
    x_size: int = 3,
    x_offs: int = 4,
    y_size: int = 1,
    y_offs: int = 5,
    dsize_l: int = 1,
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


async def _setup_core(axil_dut, *, data_ready: int = 1, hdr_ready: int = 1) -> AxiLiteMaster:
    start_lockstep_clocks(axil_dut.dataClk, axil_dut.cfgClk, axil_dut.txClk, axil_dut.rxClk, axil_dut.axilClk, period_ns=4.0)
    set_initial_values(
        axil_dut,
        {
            "txTrig": 0,
            "txLinkUp": 1,
            "rxData": CXP_IDLE,
            "rxDataK": CXP_IDLE_K,
            "rxDispErr": 0,
            "rxDecErr": 0,
            "rxLinkUp": 1,
            "S_CFG_IB_TVALID": 0,
            "S_CFG_IB_TDATA": 0,
            "S_CFG_IB_TKEEP": 0,
            "S_CFG_IB_TLAST": 0,
            "S_CFG_IB_TUSER": 0,
            "M_CFG_OB_TREADY": 0,
            "M_DATA_TREADY": data_ready,
            "M_HDR_TREADY": hdr_ready,
        },
    )
    await reset_signals(
        axil_dut,
        clk=axil_dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst", "axilRst"),
        assert_cycles=10,
        release_cycles=5,
    )
    axil = AxiLiteMaster(AxiLiteBus.from_prefix(axil_dut, "S_AXI"), axil_dut.axilClk, axil_dut.axilRst)
    await axil.write_dword(0xFFC, 1)
    await cycle(axil_dut.axilClk, 8)
    return axil


async def _read_counter(axil: AxiLiteMaster, dut, offset: int) -> int:
    await cycle(dut.axilClk, 8)
    return await axil.read_dword(offset)


async def _send_stream_packet_words(
    dut,
    payload_words: list[int],
    *,
    stream_id: int = 0x22,
    packet_tag: int = 0x33,
    corrupt_crc: bool = False,
) -> None:
    crc_inputs = [
        repeat_byte(stream_id),
        repeat_byte(packet_tag),
        repeat_byte((len(payload_words) >> 8) & 0xFF),
        repeat_byte(len(payload_words) & 0xFF),
        *payload_words,
    ]
    words = [
        CXP_SOP,
        repeat_byte(CXP_PKT_STREAM_DATA),
        repeat_byte(stream_id),
        repeat_byte(packet_tag),
        repeat_byte((len(payload_words) >> 8) & 0xFF),
        repeat_byte(len(payload_words) & 0xFF),
        *payload_words,
        cxp_crc_word(crc_inputs) ^ (0x00000001 if corrupt_crc else 0x00000000),
        CXP_EOP,
    ]
    for word in words:
        await send_rx_word(dut, data=word, data_k=0xF if word in (CXP_SOP, CXP_EOP) else 0x0, clk=dut.rxClk)


async def _collect_core_outputs(dut, *, cycles: int) -> tuple[list[int], list[int]]:
    hdr_words: list[int] = []
    data_words: list[int] = []
    for _ in range(cycles):
        await send_rx_word(dut, data=CXP_IDLE, data_k=CXP_IDLE_K, clk=dut.rxClk)
        if int(dut.M_HDR_TVALID.value) == 1:
            hdr_words.append(int(dut.M_HDR_TDATA.value))
        if int(dut.M_DATA_TVALID.value) == 1:
            data_words.append(int(dut.M_DATA_TDATA.value))
    return hdr_words, data_words


async def _drive_idle_rx(dut, *, cycles: int) -> None:
    for _ in range(cycles):
        await send_rx_word(dut, data=CXP_IDLE, data_k=CXP_IDLE_K, clk=dut.rxClk)


def _header_payload(**kwargs) -> list[int]:
    return [CXP_MARKER, repeat_byte(CXP_PKT_IMAGE_HEADER), *_image_header_words(**kwargs)]


def _line_payload(*line_words: int) -> list[int]:
    return [CXP_MARKER, repeat_byte(CXP_PKT_IMAGE_LINE), *line_words]


async def _send_image_frame(
    dut,
    *,
    stream_id: int,
    packet_tag: int,
    y_size: int,
    dsize_l: int,
    line_words: list[int],
) -> None:
    await _send_stream_packet_words(
        dut,
        _header_payload(stream_id=stream_id, y_size=y_size, dsize_l=dsize_l),
        stream_id=stream_id,
        packet_tag=packet_tag,
    )
    await _send_stream_packet_words(
        dut,
        _line_payload(*line_words),
        stream_id=(stream_id + 1) & 0xFF,
        packet_tag=(packet_tag + 1) & 0xFF,
    )


async def _count_signal_high_cycles(signal, clk, stop_event: Event, counts: dict[str, int], key: str) -> None:
    while True:
        await RisingEdge(clk)
        await Timer(2, unit="ns")
        if stop_event.is_set():
            return
        counts[key] += int(signal.value)


async def _trace_first_signal_high(signal, clk, stop_event: Event, trace: dict[str, object], capture) -> None:
    while True:
        await RisingEdge(clk)
        await Timer(2, unit="ns")
        if stop_event.is_set():
            return
        if trace["seen"] or int(signal.value) == 0:
            continue
        trace["seen"] = True
        trace.update(capture())


@cocotb.test()
async def coaxpress_core_tagged_config_tx_path_test(dut):
    axil = await _setup_core(dut)

    reg_ff8 = await axil.read_dword(0xFF8)
    await axil.write_dword(0xFF8, reg_ff8 | (1 << 26) | (1 << 27))
    updated_ff8 = await axil.read_dword(0xFF8)
    assert (updated_ff8 >> 26) & 0x1 == 1
    assert (updated_ff8 >> 27) & 0x1 == 1

    tid = 0x13579BDF
    addr = 0x00000040
    request_payload = pack_u32_words_le([0x00000003, tid, addr, 0x00000000, 0x00000003])

    tx_task = cocotb.start_soon(
        collect_stream_bytes(
            dut,
            clk=dut.txClk,
            valid_name="txLsValid",
            data_name="txLsData",
            count=32,
            timeout_cycles=12000,
        )
    )
    await send_axis_payload(dut, clk=dut.cfgClk, prefix="S_CFG_IB", payload=request_payload, width_bytes=32, tuser=0x2)

    tx_bytes = await with_timeout(tx_task, 20, "us")
    expected_packet = (
        bytes(word_to_bytes(CXP_SOP))
        + bytes([0x05] * 4)
        + b"\x00\x00\x00\x00"
        + bytes(word_to_bytes(0x04000000))
        + bytes(word_to_bytes(endian_swap32(addr)))
        + bytes(word_to_bytes(cxp_crc_word([0x00000000, 0x04000000, endian_swap32(addr)])))
        + bytes(word_to_bytes(CXP_EOP))
    )
    request_start = find_subsequence(tx_bytes, expected_packet)
    assert request_start is not None, tx_bytes


@cocotb.test()
async def coaxpress_core_rx_overflow_counter_under_backpressure_test(dut):
    axil = await _setup_core(dut, data_ready=1, hdr_ready=0)

    assert await _read_counter(axil, dut, 0x820) == 0

    header_payload = _header_payload(y_size=0, dsize_l=1)
    for index in range(24):
        await _send_stream_packet_words(dut, header_payload, stream_id=(0x30 + index) & 0xFF, packet_tag=0x55)

    overflow_count = await _read_counter(axil, dut, 0x820)
    assert overflow_count > 0

    dut.M_HDR_TREADY.value = 1
    hdr_words, _ = await _collect_core_outputs(dut, cycles=64)
    assert hdr_words


@cocotb.test()
async def coaxpress_core_rx_fsm_error_counter_and_recovery_test(dut):
    axil = await _setup_core(dut)

    malformed_header_words = _image_header_words(y_size=1, dsize_l=1)
    malformed_header_words[5] = 0x01020304
    malformed_payload = [CXP_MARKER, repeat_byte(CXP_PKT_IMAGE_HEADER), *malformed_header_words]
    await _send_stream_packet_words(dut, malformed_payload, stream_id=0x41, packet_tag=0x66)

    first_error_count = await _read_counter(axil, dut, 0x824)
    assert first_error_count > 0

    await _collect_core_outputs(dut, cycles=32)
    stable_error_count = await _read_counter(axil, dut, 0x824)
    assert stable_error_count == first_error_count

    await _send_image_frame(
        dut,
        stream_id=0x42,
        packet_tag=0x67,
        y_size=1,
        dsize_l=1,
        line_words=[0xAABBCCDD],
    )

    hdr_words, data_words = await _collect_core_outputs(dut, cycles=64)
    assert hdr_words
    assert 0xAABBCCDD in data_words
    assert await _read_counter(axil, dut, 0x824) == first_error_count


@cocotb.test()
async def coaxpress_core_rx_lane_crc_error_counter_test(dut):
    axil = await _setup_core(dut)

    assert await _read_counter(axil, dut, 0x824) == 0

    await _send_stream_packet_words(
        dut,
        _header_payload(y_size=1, dsize_l=1),
        stream_id=0x52,
        packet_tag=0x77,
    )
    await _send_stream_packet_words(
        dut,
        _line_payload(0x12345678),
        stream_id=0x53,
        packet_tag=0x78,
        corrupt_crc=True,
    )

    lane_error_count = await _read_counter(axil, dut, 0x824)
    assert lane_error_count > 0

    await _collect_core_outputs(dut, cycles=32)
    assert await _read_counter(axil, dut, 0x824) == lane_error_count

    await _send_image_frame(
        dut,
        stream_id=0x54,
        packet_tag=0x79,
        y_size=1,
        dsize_l=1,
        line_words=[0x87654321],
    )
    _hdr_words, data_words = await _collect_core_outputs(dut, cycles=64)
    assert 0x87654321 in data_words
    assert await _read_counter(axil, dut, 0x824) == lane_error_count


@cocotb.test()
async def coaxpress_core_rx_overflow_does_not_trigger_fsm_error_storm_test(dut):
    axil = await _setup_core(dut, data_ready=0, hdr_ready=1)

    assert await _read_counter(axil, dut, 0x820) == 0
    assert await _read_counter(axil, dut, 0x824) == 0

    frame_count = env_int("CXP_RX_OVERFLOW_STORM_FRAME_COUNT", default=8)
    line_word_count = env_int("CXP_RX_OVERFLOW_STORM_LINE_WORD_COUNT", default=96)
    vary_packet_fields = env_flag("CXP_CORE_RX_OVERFLOW_VARY_PACKET_FIELDS", default=True)
    signal_counts = {
        "core_rx_fsm_error": 0,
        "core_rx_overflow": 0,
        "core_rx_fsm_rst": 0,
        "axil_rx_fsm_error": 0,
        "axil_rx_overflow": 0,
    }
    signal_found = {
        "core_rx_fsm_error": False,
        "core_rx_overflow": False,
        "core_rx_fsm_rst": False,
        "axil_rx_fsm_error": False,
        "axil_rx_overflow": False,
    }
    phase_trace = {"label": "frame_drive", "frame_index": -1}
    first_core_error = {"seen": False}
    stop_event = Event()
    monitor_tasks = []
    for signal, clk, key in (
        (getattr(dut, "DBG_RX_FSM_ERROR", None), dut.rxClk, "core_rx_fsm_error"),
        (getattr(dut, "DBG_RX_OVERFLOW", None), dut.rxClk, "core_rx_overflow"),
        (getattr(dut, "DBG_RX_FSM_RST", None), dut.rxClk, "core_rx_fsm_rst"),
        (getattr(dut, "DBG_AXIL_FSM_ERROR", None), dut.axilClk, "axil_rx_fsm_error"),
        (getattr(dut, "DBG_AXIL_OVERFLOW", None), dut.axilClk, "axil_rx_overflow"),
    ):
        if signal is not None:
            signal_found[key] = True
            monitor_tasks.append(cocotb.start_soon(_count_signal_high_cycles(signal, clk, stop_event, signal_counts, key)))
    if getattr(dut, "DBG_RX_FSM_ERROR", None) is not None:
        monitor_tasks.append(
            cocotb.start_soon(
                _trace_first_signal_high(
                    dut.DBG_RX_FSM_ERROR,
                    dut.rxClk,
                    stop_event,
                    first_core_error,
                    lambda: {
                        "time_ns": get_sim_time(unit="ns"),
                        "phase": phase_trace["label"],
                        "frame_index": phase_trace["frame_index"],
                        "rx_data": int(dut.rxData.value),
                        "rx_data_k": int(dut.rxDataK.value),
                        "m_data_tvalid": int(dut.M_DATA_TVALID.value),
                        "m_data_tready": int(dut.M_DATA_TREADY.value),
                        "m_hdr_tvalid": int(dut.M_HDR_TVALID.value),
                    },
                )
            )
        )

    for index in range(frame_count):
        phase_trace["frame_index"] = index
        stream_id = (0x50 + (2 * index)) & 0xFF if vary_packet_fields else 0x50
        packet_tag = (0x70 + (2 * index)) & 0xFF if vary_packet_fields else 0x70
        await _send_image_frame(
            dut,
            stream_id=stream_id,
            packet_tag=packet_tag,
            y_size=1,
            dsize_l=line_word_count,
            line_words=[0x10000000 | (index << 12) | word_index for word_index in range(line_word_count)],
        )

    phase_trace["label"] = "idle_quiesce"
    phase_trace["frame_index"] = frame_count
    await _drive_idle_rx(dut, cycles=32)
    phase_trace["label"] = "axil_read"
    overflow_count = await _read_counter(axil, dut, 0x820)
    first_error_count = await _read_counter(axil, dut, 0x824)

    stop_event.set()
    for task in monitor_tasks:
        await task

    assert overflow_count > 0, (
        f"overflow_count={overflow_count} first_error_count={first_error_count} "
        f"core_overflow={signal_counts['core_rx_overflow']} core_error={signal_counts['core_rx_fsm_error']} "
        f"core_rx_fsm_rst={signal_counts['core_rx_fsm_rst']} "
        f"axil_overflow={signal_counts['axil_rx_overflow']} axil_error={signal_counts['axil_rx_fsm_error']} "
        f"first_core_error={first_core_error} "
        f"found_overflow={signal_found['core_rx_overflow']} found_error={signal_found['core_rx_fsm_error']} "
        f"found_rx_fsm_rst={signal_found['core_rx_fsm_rst']} "
        f"found_axil_overflow={signal_found['axil_rx_overflow']} found_axil_error={signal_found['axil_rx_fsm_error']}"
    )
    assert first_error_count == 0, (
        f"overflow_count={overflow_count} first_error_count={first_error_count} "
        f"core_overflow={signal_counts['core_rx_overflow']} core_error={signal_counts['core_rx_fsm_error']} "
        f"core_rx_fsm_rst={signal_counts['core_rx_fsm_rst']} "
        f"axil_overflow={signal_counts['axil_rx_overflow']} axil_error={signal_counts['axil_rx_fsm_error']} "
        f"first_core_error={first_core_error} "
        f"found_overflow={signal_found['core_rx_overflow']} found_error={signal_found['core_rx_fsm_error']} "
        f"found_rx_fsm_rst={signal_found['core_rx_fsm_rst']} "
        f"found_axil_overflow={signal_found['axil_rx_overflow']} found_axil_error={signal_found['axil_rx_fsm_error']}"
    )

    await _collect_core_outputs(dut, cycles=128)
    idle_error_count = await _read_counter(axil, dut, 0x824)
    assert idle_error_count == first_error_count

    dut.M_DATA_TREADY.value = 1
    await _collect_core_outputs(dut, cycles=256)
    released_error_count = await _read_counter(axil, dut, 0x824)
    assert released_error_count == first_error_count

    await _collect_core_outputs(dut, cycles=env_int("CXP_RX_OVERFLOW_STORM_DRAIN_CYCLES", default=1024))

    await _send_image_frame(
        dut,
        stream_id=0xE0,
        packet_tag=0xE1,
        y_size=1,
        dsize_l=1,
        line_words=[0xDEADBEEF],
    )
    _, data_words = await _collect_core_outputs(dut, cycles=128)
    assert 0xDEADBEEF in data_words
    assert await _read_counter(axil, dut, 0x824) == first_error_count


def test_CoaXPressCore():
    use_debug_wrapper = os.getenv("CXP_CORE_DEBUG_WRAPPER") == "1"
    parameters = {"FORCE_RX_CTRL_G": "true"} if use_debug_wrapper and os.getenv("CXP_CORE_FORCE_RX_CTRL") == "1" else None
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpresscoredebugwrapper" if use_debug_wrapper else "surf.coaxpresscorewrapper",
        parameters=parameters,
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressEventAckMsg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressTxLsFsm.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressTx.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxWordPacker.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxLaneMux.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxLane.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxHsFsm.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRx.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressConfig.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressAxiL.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressCore.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressCoreDebugWrapper.vhd" if use_debug_wrapper else "protocols/coaxpress/core/wrappers/CoaXPressCoreWrapper.vhd",
            ]
        },
    )
