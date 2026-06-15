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
# - Sweep: Use the standalone legacy `AxiStreamPacketizer` wrapper with an
#   8-byte stream width and the default SSI packetized output mode.
# - Stimulus: Drive application AXI Stream beats directly into the packetizer,
#   including `TDEST`, `TID`, first-beat `TUSER`, and final-byte `TUSER`.
# - Checks: The packetized output must contain the expected V0 header, payload,
#   SSI SOF bit, and both supported EOF tail placements: appended into a
#   partially-filled final word and emitted as a separate one-byte final word.
# - Timing: The sink is kept ready while a concurrent source task sends input
#   beats, so the bench observes every accepted packetized beat without using
#   a depacketizer loopback as an oracle.

import cocotb
import pytest
from cocotb.triggers import with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.packetizer_test_utils import (
    AxisBeat,
    FlatAxisEndpoint,
    assert_packetized_beat,
    packetizer0_header_word,
    packetizer0_tail_byte,
    recv_beats,
    recv_beats_with_backpressure,
    reset_packetizer_dut,
    send_beats,
    start_packetizer_clock,
    tuser_for_lane,
    word_from_bytes,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = FlatAxisEndpoint(dut, prefix="S_AXIS")
        self.sink = FlatAxisEndpoint(dut, prefix="M_AXIS")

        start_packetizer_clock(dut)
        dut.axisRst.setimmediatevalue(1)
        dut.maxPktBytes.setimmediatevalue(64)
        dut.M_AXIS_TREADY.setimmediatevalue(0)
        self.source.set_idle()

    async def reset(self):
        await reset_packetizer_dut(self.dut)

@cocotb.test()
async def packetize_appended_tail_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A 15-byte frame leaves one spare byte in the final packet word, so the
    # legacy packetizer should append its EOF/user tail marker into that word.
    payload = bytes(range(0x10, 0x1F))
    tail = packetizer0_tail_byte(eof=1, tuser=0x41)
    input_beats = [
        AxisBeat(
            data=word_from_bytes(payload[0:8]),
            keep=0xFF,
            last=0,
            dest=0x3,
            tid=0xA5,
            user=0x20,
        ),
        AxisBeat(
            data=word_from_bytes(payload[8:15]),
            keep=0x7F,
            last=1,
            dest=0x3,
            tid=0xA5,
            user=tuser_for_lane(7, 0x41),
        ),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 3, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 2, "us")

    # The first packet word is protocol overhead: version/frame/packet plus the
    # application sideband fields copied out of the first input beat.
    assert_packetized_beat(
        rx_beats[0],
        data=packetizer0_header_word(frame=0, packet=0, tdest=0x3, tid=0xA5, tuser=0x20),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    # The final output beat carries seven payload bytes plus the tail marker in
    # byte lane 7; no depacketizer is involved in forming this expectation.
    assert_packetized_beat(
        rx_beats[2],
        data=word_from_bytes(payload[8:15] + bytes([tail])),
        last=1,
    )


@cocotb.test()
async def packetize_separate_tail_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A 16-byte frame fills the last payload word completely, so the legacy
    # packetizer must emit the EOF/user tail marker as its own one-byte word.
    payload = bytes(range(0x30, 0x40))
    tail = packetizer0_tail_byte(eof=1, tuser=0x42)
    input_beats = [
        AxisBeat(
            data=word_from_bytes(payload[0:8]),
            keep=0xFF,
            last=0,
            dest=0x2,
            tid=0x5A,
            user=0x10,
        ),
        AxisBeat(
            data=word_from_bytes(payload[8:16]),
            keep=0xFF,
            last=1,
            dest=0x2,
            tid=0x5A,
            user=0x42,
        ),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 4, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 2, "us")

    # The packetized sideband is only present in the header; following payload
    # beats should have neutralized `TDEST`, `TID`, and `TUSER`.
    assert_packetized_beat(
        rx_beats[0],
        data=packetizer0_header_word(frame=0, packet=0, tdest=0x2, tid=0x5A, tuser=0x10),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    assert_packetized_beat(rx_beats[2], data=word_from_bytes(payload[8:16]))
    # The separate tail word uses only byte lane 0 and terminates the packet.
    assert_packetized_beat(rx_beats[3], data=tail, keep=0x01, last=1)


@cocotb.test()
async def packetize_split_frame_on_max_size_test(dut):
    tb = TB(dut)
    dut.maxPktBytes.value = 32
    await tb.reset()

    # With a 32-byte packet limit, the legacy packetizer can carry two 8-byte
    # payload words plus header/tail overhead. A three-word frame must therefore
    # become a non-EOF packet followed by an EOF continuation packet.
    payload = bytes(range(0x60, 0x78))
    first_tail = packetizer0_tail_byte(eof=0, tuser=0x00)
    final_tail = packetizer0_tail_byte(eof=1, tuser=0x43)
    input_beats = [
        AxisBeat(
            data=word_from_bytes(payload[0:8]),
            keep=0xFF,
            last=0,
            dest=0x4,
            tid=0x22,
            user=0x31,
        ),
        AxisBeat(
            data=word_from_bytes(payload[8:16]),
            keep=0xFF,
            last=0,
            dest=0x4,
            tid=0x22,
            user=0,
        ),
        AxisBeat(
            data=word_from_bytes(payload[16:24]),
            keep=0xFF,
            last=1,
            dest=0x4,
            tid=0x22,
            user=0x43,
        ),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 7, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    assert_packetized_beat(
        rx_beats[0],
        data=packetizer0_header_word(frame=0, packet=0, tdest=0x4, tid=0x22, tuser=0x31),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    assert_packetized_beat(rx_beats[2], data=word_from_bytes(payload[8:16]))
    assert_packetized_beat(rx_beats[3], data=first_tail, keep=0x01, last=1)
    assert_packetized_beat(
        rx_beats[4],
        data=packetizer0_header_word(frame=0, packet=1, tdest=0x4, tid=0x22, tuser=0x43),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[5], data=word_from_bytes(payload[16:24]))
    assert_packetized_beat(rx_beats[6], data=final_tail, keep=0x01, last=1)


@cocotb.test()
async def packetize_output_backpressure_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Stall every packetized output beat before accepting it. This stresses the
    # legacy packetizer's output hold behavior across header, payload, and the
    # separate one-byte tail marker.
    payload = bytes(range(0x80, 0x90))
    tail = packetizer0_tail_byte(eof=1, tuser=0x45)
    input_beats = [
        AxisBeat(
            data=word_from_bytes(payload[0:8]),
            keep=0xFF,
            last=0,
            dest=0x5,
            tid=0x35,
            user=0x25,
        ),
        AxisBeat(
            data=word_from_bytes(payload[8:16]),
            keep=0xFF,
            last=1,
            dest=0x5,
            tid=0x35,
            user=0x45,
        ),
    ]

    rx_task = cocotb.start_soon(recv_beats_with_backpressure(tb.sink, 4, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert_packetized_beat(
        rx_beats[0],
        data=packetizer0_header_word(frame=0, packet=0, tdest=0x5, tid=0x35, tuser=0x25),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    assert_packetized_beat(rx_beats[2], data=word_from_bytes(payload[8:16]))
    assert_packetized_beat(rx_beats[3], data=tail, keep=0x01, last=1)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="legacy_v0")])
def test_AxiStreamPacketizer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreampacketizerwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["protocols/packetizer/wrappers/AxiStreamPacketizerWrapper.vhd"],
        },
    )
