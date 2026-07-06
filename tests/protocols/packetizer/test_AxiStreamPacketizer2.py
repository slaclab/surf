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
# - Sweep: Use the standalone `AxiStreamPacketizer2` wrapper across CRC NONE,
#   DATA, and FULL modes with an 8-byte stream width and a reduced packet-size
#   limit for the split-frame case.
# - Stimulus: Drive application AXI Stream beats directly into the packetizer,
#   including first/last `TUSER`, `TDEST`, `TID`, and a three-beat frame that
#   must be divided into two packetizer packets.
# - Checks: The packetized output must contain the expected V2 header words,
#   payload words, tail words, sequence numbers, SOF/EOF flags, and output
#   sideband remapping.
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
    assert_packetizer2_tail_beat,
    crc_mode_from_env,
    packetizer2_header_word,
    payload_to_beats,
    recv_beats,
    recv_beats_with_backpressure,
    reset_packetizer_dut,
    send_beats,
    start_packetizer_clock,
    word_from_bytes,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = FlatAxisEndpoint(dut, prefix="S_AXIS")
        self.sink = FlatAxisEndpoint(dut, prefix="M_AXIS")

        start_packetizer_clock(dut)
        dut.axisRst.setimmediatevalue(1)
        dut.maxPktBytes.setimmediatevalue(32)
        dut.M_AXIS_TREADY.setimmediatevalue(0)
        self.source.set_idle()

    async def reset(self):
        await reset_packetizer_dut(self.dut)


@cocotb.test()
async def packetize_single_frame_test(dut):
    tb = TB(dut)
    await tb.reset()

    payload = bytes(range(0x10, 0x20))
    input_beats = payload_to_beats(
        payload,
        dest=0x3,
        tid=0xA5,
        first_user=0x22,
        last_user=0x41,
    )

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 4, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 2, "us")

    crc_mode = crc_mode_from_env()

    assert_packetized_beat(
        rx_beats[0],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=1,
            tuser=0x22,
            tdest=0x3,
            tid=0xA5,
            seq=0,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    assert_packetized_beat(rx_beats[2], data=word_from_bytes(payload[8:16]))
    assert_packetizer2_tail_beat(rx_beats[3], eof=1, tuser=0x41, byte_count=8, crc_mode=crc_mode)


@cocotb.test()
async def packetize_split_frame_test(dut):
    tb = TB(dut)
    await tb.reset()

    payload = bytes(range(0x30, 0x48))
    input_beats = payload_to_beats(
        payload,
        dest=0x2,
        tid=0x5A,
        first_user=0x12,
        last_user=0x43,
    )

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 7, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    crc_mode = crc_mode_from_env()

    assert_packetized_beat(
        rx_beats[0],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=1,
            tuser=0x12,
            tdest=0x2,
            tid=0x5A,
            seq=0,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    assert_packetized_beat(rx_beats[2], data=word_from_bytes(payload[8:16]))
    assert_packetizer2_tail_beat(rx_beats[3], eof=0, tuser=0, byte_count=8, crc_mode=crc_mode)
    assert_packetized_beat(
        rx_beats[4],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=0,
            tuser=0,
            tdest=0x2,
            tid=0x5A,
            seq=1,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[5], data=word_from_bytes(payload[16:24]))
    assert_packetizer2_tail_beat(rx_beats[6], eof=1, tuser=0x43, byte_count=8, crc_mode=crc_mode)


@cocotb.test()
async def packetize_partial_last_tkeep_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A partial final input beat should still produce a full-width packetized
    # tail word whose byte-count field tells the depacketizer how much of the
    # previous payload word is real frame data.
    payload = bytes(range(0x50, 0x5B))
    input_beats = payload_to_beats(
        payload,
        dest=0x1,
        tid=0xC3,
        first_user=0x24,
        last_user=0x47,
    )

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 4, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 2, "us")

    crc_mode = crc_mode_from_env()

    assert_packetized_beat(
        rx_beats[0],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=1,
            tuser=0x24,
            tdest=0x1,
            tid=0xC3,
            seq=0,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    assert_packetized_beat(rx_beats[2], data=word_from_bytes(payload[8:11]))
    assert_packetizer2_tail_beat(rx_beats[3], eof=1, tuser=0x47, byte_count=3, crc_mode=crc_mode)


@cocotb.test()
async def packetize_one_byte_over_max_packet_boundary_test(dut):
    tb = TB(dut)
    await tb.reset()

    # With `maxPktBytes=32`, two 8-byte payload words plus header/tail exactly
    # fill one packet. A 17-byte frame must therefore split after the first 16
    # payload bytes and carry the final byte in a continuation packet.
    payload = bytes(range(0x58, 0x69))
    input_beats = payload_to_beats(
        payload,
        dest=0x2,
        tid=0xB4,
        first_user=0x26,
        last_user=0x49,
    )

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 7, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    crc_mode = crc_mode_from_env()

    assert_packetized_beat(
        rx_beats[0],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=1,
            tuser=0x26,
            tdest=0x2,
            tid=0xB4,
            seq=0,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    assert_packetized_beat(rx_beats[2], data=word_from_bytes(payload[8:16]))
    assert_packetizer2_tail_beat(rx_beats[3], eof=0, tuser=0, byte_count=8, crc_mode=crc_mode)
    assert_packetized_beat(
        rx_beats[4],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=0,
            tuser=0x49,
            tdest=0x2,
            tid=0xB4,
            seq=1,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[5], data=word_from_bytes(payload[16:17]))
    assert_packetizer2_tail_beat(rx_beats[6], eof=1, tuser=0x49, byte_count=1, crc_mode=crc_mode)


@cocotb.test()
async def packetize_interleaved_tdest_state_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Changing TDEST mid-frame forces a non-EOF tail for the active destination
    # without accepting the new beat. The source helper holds the new beat until
    # the packetizer rearbitrates and returns ready.
    dest_a_first = bytes(range(0x70, 0x78))
    dest_b_frame = bytes(range(0x90, 0x98))
    dest_a_last = bytes(range(0x78, 0x80))
    input_beats = [
        AxisBeat(
            data=word_from_bytes(dest_a_first),
            keep=0xFF,
            last=0,
            dest=0x1,
            tid=0x11,
            user=0x21,
        ),
        AxisBeat(
            data=word_from_bytes(dest_b_frame),
            keep=0xFF,
            last=1,
            dest=0x2,
            tid=0x22,
            user=0x31 | (0x44 << 56),
        ),
        AxisBeat(
            data=word_from_bytes(dest_a_last),
            keep=0xFF,
            last=1,
            dest=0x1,
            tid=0x11,
            user=0x45 << 56,
        ),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 9, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 4, "us")

    crc_mode = crc_mode_from_env()

    assert_packetized_beat(
        rx_beats[0],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=1,
            tuser=0x21,
            tdest=0x1,
            tid=0x11,
            seq=0,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[1], data=word_from_bytes(dest_a_first))
    assert_packetizer2_tail_beat(rx_beats[2], eof=0, tuser=0, byte_count=8, crc_mode=crc_mode)
    assert_packetized_beat(
        rx_beats[3],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=1,
            tuser=0x31,
            tdest=0x2,
            tid=0x22,
            seq=0,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[4], data=word_from_bytes(dest_b_frame))
    assert_packetizer2_tail_beat(rx_beats[5], eof=1, tuser=0x44, byte_count=8, crc_mode=crc_mode)
    assert_packetized_beat(
        rx_beats[6],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=0,
            tuser=0x00,
            tdest=0x1,
            tid=0x11,
            seq=1,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[7], data=word_from_bytes(dest_a_last))
    assert_packetizer2_tail_beat(rx_beats[8], eof=1, tuser=0x45, byte_count=8, crc_mode=crc_mode)


@cocotb.test()
async def packetize_output_backpressure_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Hold each packetized beat at the sink for multiple clocks before
    # accepting it. The helper checks that VALID-side data, keep, last, and
    # sideband remain stable while TREADY is low.
    payload = bytes(range(0xA0, 0xB8))
    input_beats = payload_to_beats(
        payload,
        dest=0x3,
        tid=0x33,
        first_user=0x2A,
        last_user=0x4A,
    )

    rx_task = cocotb.start_soon(recv_beats_with_backpressure(tb.sink, 7, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 5, "us")

    crc_mode = crc_mode_from_env()

    assert_packetized_beat(
        rx_beats[0],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=1,
            tuser=0x2A,
            tdest=0x3,
            tid=0x33,
            seq=0,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    assert_packetized_beat(rx_beats[2], data=word_from_bytes(payload[8:16]))
    assert_packetizer2_tail_beat(rx_beats[3], eof=0, tuser=0, byte_count=8, crc_mode=crc_mode)
    assert_packetized_beat(
        rx_beats[4],
        data=packetizer2_header_word(
            crc_mode=crc_mode,
            sof=0,
            tuser=0,
            tdest=0x3,
            tid=0x33,
            seq=1,
        ),
        user=0x2,
    )
    assert_packetized_beat(rx_beats[5], data=word_from_bytes(payload[16:24]))
    assert_packetizer2_tail_beat(rx_beats[6], eof=1, tuser=0x4A, byte_count=8, crc_mode=crc_mode)


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({}, id="crc_none"),
        pytest.param({"CRC_MODE_G": "DATA"}, id="crc_data"),
        pytest.param({"CRC_MODE_G": "FULL"}, id="crc_full"),
    ],
)
def test_AxiStreamPacketizer2(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreampacketizer2wrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["protocols/packetizer/wrappers/AxiStreamPacketizer2Wrapper.vhd"],
        },
    )
