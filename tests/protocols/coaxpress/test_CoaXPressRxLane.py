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
# - Sweep: Exercise the receive-lane decoder directly without a generic sweep
#   because the bug-prone surface is its packet-state logic rather than a set
#   of static parameters.
# - Stimulus: Drive raw CoaXPress stream, control-ack, event, and heartbeat
#   words using spec-shaped packet prefixes and trailers where the current RTL
#   can consume them, plus malformed-field and link-drop sequences.
# - Checks: The lane must emit the right config/data/heartbeat payloads, pulse
#   `ioAck` and `eventAck` at the correct points, preserve payload `TUSER`
#   bits, and reset cleanly after malformed packets or `rxLinkUp` loss.
# - Timing: The bench samples every output pulse cycle-by-cycle because the DUT
#   exposes only master-side pulse semantics with no backpressure input.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_IDLE,
    CXP_IDLE_K,
    CXP_IO_ACK,
    CXP_PKT_CTRL_ACK_NO_TAG,
    CXP_PKT_CTRL_ACK_WITH_TAG,
    CXP_PKT_EVENT,
    CXP_PKT_HEARTBEAT,
    CXP_PKT_STREAM_DATA,
    CXP_SOP,
    cycle,
    repeat_byte,
    reset_dut,
    send_rx_word,
    start_clock,
)


@cocotb.test()
async def coaxpress_rx_lane_stream_and_io_ack_test(dut):
    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.rxLinkUp.setimmediatevalue(1)
    dut.rxData.setimmediatevalue(CXP_IDLE)
    dut.rxDataK.setimmediatevalue(CXP_IDLE_K)
    await reset_dut(dut)

    data_beats: list[dict[str, int]] = []
    io_ack_pulses = 0

    async def drive(data: int, data_k: int) -> None:
        nonlocal io_ack_pulses
        await send_rx_word(
            dut,
            data=data,
            data_k=data_k,
            clk=dut.rxClk,
            capture=data_beats,
            valid_name="dataTValid",
            field_names=("dataTData", "dataTUser", "dataTLast"),
        )
        io_ack_pulses += int(dut.ioAck.value)

    # Build one three-word stream packet with a spec-shaped header/trailer and
    # interrupt it with an I/O ACK sequence before the payload starts to prove
    # the saved-state path.
    await drive(CXP_SOP, 0xF)
    await drive(repeat_byte(CXP_PKT_STREAM_DATA), 0x0)
    await drive(repeat_byte(0x22), 0x0)
    await drive(repeat_byte(0x33), 0x0)
    await drive(repeat_byte(0x00), 0x0)
    await drive(repeat_byte(0x03), 0x0)
    await drive(CXP_IO_ACK, 0xF)
    await drive(repeat_byte(0x01), 0x0)
    await drive(0x11223344, 0x0)
    await drive(0x55667788, 0x5)
    await drive(0x99AABBCC, 0x0)
    await drive(0xDEADBEEF, 0x0)
    await drive(CXP_EOP, 0xF)
    await drive(CXP_IDLE, CXP_IDLE_K)

    assert io_ack_pulses == 1
    assert data_beats == [
        {"dataTData": 0x11223344, "dataTUser": 0x0, "dataTLast": 0},
        {"dataTData": 0x55667788, "dataTUser": 0x5, "dataTLast": 0},
        {"dataTData": 0x99AABBCC, "dataTUser": 0x0, "dataTLast": 1},
    ]


@cocotb.test()
async def coaxpress_rx_lane_spec_prefix_control_event_and_heartbeat_test(dut):
    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.rxLinkUp.setimmediatevalue(1)
    dut.rxData.setimmediatevalue(CXP_IDLE)
    dut.rxDataK.setimmediatevalue(CXP_IDLE_K)
    await reset_dut(dut)

    cfg_beats: list[dict[str, int]] = []
    heartbeat_beats: list[dict[str, int]] = []
    event_pulses: list[tuple[int, int]] = []

    async def drive(data: int, data_k: int, *, link_up: int = 1) -> None:
        await send_rx_word(
            dut,
            data=data,
            data_k=data_k,
            clk=dut.rxClk,
            link_up=link_up,
        )
        if int(dut.cfgTValid.value) == 1:
            cfg_beats.append({"cfgTData": int(dut.cfgTData.value)})
        if int(dut.heartbeatTValid.value) == 1:
            heartbeat_beats.append(
                {
                    "heartbeatTData": int(dut.heartbeatTData.value),
                    "heartbeatTLast": int(dut.heartbeatTLast.value),
                }
            )
        if int(dut.eventAck.value) == 1:
            event_pulses.append((int(dut.eventAck.value), int(dut.eventTag.value)))

    # Drive one spec-shaped untagged read acknowledgment:
    # code 0x00, size=4 bytes, one reply-data word, CRC, EOP.
    await drive(CXP_SOP, 0xF)
    await drive(repeat_byte(CXP_PKT_CTRL_ACK_NO_TAG), 0x0)
    await drive(repeat_byte(0x00), 0x0)
    await drive(0x04000000, 0x0)
    await drive(0x01234567, 0x0)
    await drive(0xCAFEBABE, 0x0)
    await drive(CXP_EOP, 0xF)

    # Drive one alternate-success acknowledgment code. The current RTL maps
    # 0x04 to the same zero-success status word as 0x01.
    await drive(CXP_SOP, 0xF)
    await drive(repeat_byte(CXP_PKT_CTRL_ACK_NO_TAG), 0x0)
    await drive(repeat_byte(0x04), 0x0)
    await drive(0x04000000, 0x0)
    await drive(0x76543210, 0x0)
    await drive(0x0BADCAFE, 0x0)
    await drive(CXP_EOP, 0xF)

    # Drive one spec-shaped tagged read acknowledgment. The current RTL skips
    # the tag word, then forwards the first reply-data word with a zeroed
    # success status in the low 32 bits.
    await drive(CXP_SOP, 0xF)
    await drive(repeat_byte(CXP_PKT_CTRL_ACK_WITH_TAG), 0x0)
    await drive(repeat_byte(0x55), 0x0)
    await drive(repeat_byte(0x00), 0x0)
    await drive(0x04000000, 0x0)
    await drive(0x89ABCDEF, 0x0)
    await drive(0xFEEDBEEF, 0x0)
    await drive(CXP_EOP, 0xF)

    # Heartbeat first keeps the on-wire ordering consistent before the event.
    await drive(CXP_SOP, 0xF)
    await drive(repeat_byte(CXP_PKT_HEARTBEAT), 0x0)
    for word in range(0x20, 0x2C):
        await drive(repeat_byte(word), 0x0)
    await drive(0xB6B6B6B6, 0x0)
    await drive(CXP_EOP, 0xF)

    # Drive a fuller event packet shape. The current RTL only consumes the
    # prefix through the Packet Tag field, where it exports the tag and returns
    # to IDLE; later size/data/trailer words are present to keep the on-wire
    # stimulus aligned to the spec framing.
    await drive(CXP_SOP, 0xF)
    await drive(repeat_byte(CXP_PKT_EVENT), 0x0)
    for word in (0x10, 0x11, 0x12, 0x13):
        await drive(repeat_byte(word), 0x0)
    await drive(repeat_byte(0x5A), 0x0)
    await drive(0x00010000, 0x0)
    await drive(repeat_byte(0x00), 0x0)
    await drive(0x11223344, 0x0)
    await drive(0xA5A5A5A5, 0x0)
    await drive(CXP_EOP, 0xF)

    # A truncated event prefix must not raise a second event pulse.
    await drive(CXP_SOP, 0xF)
    await drive(repeat_byte(CXP_PKT_EVENT), 0x0)
    for word in (0xAA, 0xBB, 0xCC, 0xDD):
        await drive(repeat_byte(word), 0x0)
    await drive(CXP_EOP, 0xF)
    await drive(CXP_IDLE, CXP_IDLE_K)

    assert cfg_beats == [
        {"cfgTData": (0x01234567 << 32)},
        {"cfgTData": (0x76543210 << 32)},
        {"cfgTData": (0x89ABCDEF << 32)},
    ]
    assert event_pulses == [(1, 0x5A)]
    assert heartbeat_beats == [
        {
            "heartbeatTData": sum((word << (8 * (word - 0x20))) for word in range(0x20, 0x2C)),
            "heartbeatTLast": 1,
        }
    ]


@cocotb.test()
async def coaxpress_rx_lane_event_payload_crc_guardrail_test(dut):
    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.rxLinkUp.setimmediatevalue(1)
    dut.rxData.setimmediatevalue(CXP_IDLE)
    dut.rxDataK.setimmediatevalue(CXP_IDLE_K)
    await reset_dut(dut)

    cfg_beats: list[dict[str, int]] = []
    data_beats: list[dict[str, int]] = []
    heartbeat_beats: list[dict[str, int]] = []
    event_tags: list[int] = []

    async def drive(data: int, data_k: int) -> None:
        await send_rx_word(dut, data=data, data_k=data_k, clk=dut.rxClk)
        if int(dut.cfgTValid.value) == 1:
            cfg_beats.append({"cfgTData": int(dut.cfgTData.value)})
        if int(dut.dataTValid.value) == 1:
            data_beats.append(
                {
                    "dataTData": int(dut.dataTData.value),
                    "dataTUser": int(dut.dataTUser.value),
                    "dataTLast": int(dut.dataTLast.value),
                }
            )
        if int(dut.heartbeatTValid.value) == 1:
            heartbeat_beats.append({"heartbeatTData": int(dut.heartbeatTData.value)})
        if int(dut.eventAck.value) == 1:
            event_tags.append(int(dut.eventTag.value))

    # The current receive-lane RTL recognizes an event once it reaches the Packet
    # Tag byte, then returns to IDLE. Keep the rest of this packet spec-shaped so
    # payload, CRC, and EOP words are proven not to leak into any other output.
    await drive(CXP_SOP, 0xF)
    await drive(repeat_byte(CXP_PKT_EVENT), 0x0)
    for byte in (0xA0, 0xA1, 0xA2, 0xA3):
        await drive(repeat_byte(byte), 0x0)
    await drive(repeat_byte(0x6D), 0x0)
    await drive(repeat_byte(0x00), 0x0)
    await drive(repeat_byte(0x08), 0x0)
    await drive(0x11223344, 0x0)
    await drive(0x55667788, 0x0)
    await drive(0xDEADBEEF, 0x0)
    await drive(CXP_EOP, 0xF)

    # A later clean event must still be accepted, proving the ignored payload and
    # CRC/trailer words did not leave stale parser state behind.
    await drive(CXP_SOP, 0xF)
    await drive(repeat_byte(CXP_PKT_EVENT), 0x0)
    for byte in (0xB0, 0xB1, 0xB2, 0xB3):
        await drive(repeat_byte(byte), 0x0)
    await drive(repeat_byte(0x7E), 0x0)
    await drive(repeat_byte(0x00), 0x0)
    await drive(repeat_byte(0x00), 0x0)
    await drive(0xA5A5A5A5, 0x0)
    await drive(CXP_EOP, 0xF)
    await drive(CXP_IDLE, CXP_IDLE_K)

    assert event_tags == [0x6D, 0x7E]
    assert cfg_beats == []
    assert data_beats == []
    assert heartbeat_beats == []


@cocotb.test()
async def coaxpress_rx_lane_error_recovery_test(dut):
    start_clock(dut.rxClk)
    dut.rxRst.setimmediatevalue(1)
    dut.rxLinkUp.setimmediatevalue(1)
    dut.rxData.setimmediatevalue(CXP_IDLE)
    dut.rxDataK.setimmediatevalue(CXP_IDLE_K)
    await reset_dut(dut)

    # Corrupt the packet-tag repetition field, then drop link mid-packet and
    # confirm the next clean packet is the only one that produces payload.
    await send_rx_word(dut, data=CXP_SOP, data_k=0xF, clk=dut.rxClk)
    await send_rx_word(dut, data=repeat_byte(CXP_PKT_STREAM_DATA), data_k=0x0, clk=dut.rxClk)
    await send_rx_word(dut, data=repeat_byte(CXP_PKT_STREAM_DATA), data_k=0x0, clk=dut.rxClk)
    await send_rx_word(dut, data=0x01020304, data_k=0x0, clk=dut.rxClk)
    await send_rx_word(dut, data=CXP_SOP, data_k=0xF, clk=dut.rxClk)
    await send_rx_word(dut, data=repeat_byte(0x01), data_k=0x0, clk=dut.rxClk)
    await send_rx_word(dut, data=repeat_byte(0x02), data_k=0x0, clk=dut.rxClk)
    await send_rx_word(dut, data=repeat_byte(0x03), data_k=0x0, clk=dut.rxClk, link_up=0)
    await cycle(dut.rxClk, 2)
    dut.rxLinkUp.value = 1

    observed: list[dict[str, int]] = []
    for data, data_k in (
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_STREAM_DATA), 0x0),
        (repeat_byte(0xAA), 0x0),
        (repeat_byte(0xBB), 0x0),
        (repeat_byte(0x00), 0x0),
        (repeat_byte(0x01), 0x0),
        (0x55667788, 0x0),
        (CXP_IDLE, CXP_IDLE_K),
    ):
        await send_rx_word(
            dut,
            data=data,
            data_k=data_k,
            clk=dut.rxClk,
            capture=observed,
            valid_name="dataTValid",
            field_names=("dataTData", "dataTLast"),
        )

    assert observed == [{"dataTData": 0x55667788, "dataTLast": 1}]


def test_CoaXPressRxLane():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressrxlanewrapper",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxLane.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressRxLaneWrapper.vhd",
            ]
        },
    )
