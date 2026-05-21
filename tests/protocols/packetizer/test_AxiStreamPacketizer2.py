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
# - Sweep: Use the standalone `AxiStreamPacketizer2` wrapper in CRC-disabled
#   mode with an 8-byte stream width and a reduced packet-size limit for the
#   split-frame case.
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
    PACKETIZER2_CRC_NONE,
    packetizer2_header_word,
    packetizer2_tail_word,
    payload_to_beats,
    recv_beats,
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


def assert_packet_beat(beat: AxisBeat, *, data: int, last: int = 0, user: int = 0) -> None:
    assert beat.data == data
    assert beat.keep == 0xFF
    assert beat.last == last
    assert beat.dest == 0
    assert beat.tid == 0
    assert beat.user == user


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

    assert_packet_beat(
        rx_beats[0],
        data=packetizer2_header_word(
            crc_mode=PACKETIZER2_CRC_NONE,
            sof=1,
            tuser=0x22,
            tdest=0x3,
            tid=0xA5,
            seq=0,
        ),
        user=0x2,
    )
    assert_packet_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    assert_packet_beat(rx_beats[2], data=word_from_bytes(payload[8:16]))
    assert_packet_beat(
        rx_beats[3],
        data=packetizer2_tail_word(eof=1, tuser=0x41, byte_count=8),
        last=1,
    )


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

    assert_packet_beat(
        rx_beats[0],
        data=packetizer2_header_word(
            crc_mode=PACKETIZER2_CRC_NONE,
            sof=1,
            tuser=0x12,
            tdest=0x2,
            tid=0x5A,
            seq=0,
        ),
        user=0x2,
    )
    assert_packet_beat(rx_beats[1], data=word_from_bytes(payload[0:8]))
    assert_packet_beat(rx_beats[2], data=word_from_bytes(payload[8:16]))
    assert_packet_beat(
        rx_beats[3],
        data=packetizer2_tail_word(eof=0, tuser=0, byte_count=8),
        last=1,
    )
    assert_packet_beat(
        rx_beats[4],
        data=packetizer2_header_word(
            crc_mode=PACKETIZER2_CRC_NONE,
            sof=0,
            tuser=0,
            tdest=0x2,
            tid=0x5A,
            seq=1,
        ),
        user=0x2,
    )
    assert_packet_beat(rx_beats[5], data=word_from_bytes(payload[16:24]))
    assert_packet_beat(
        rx_beats[6],
        data=packetizer2_tail_word(eof=1, tuser=0x43, byte_count=8),
        last=1,
    )


@pytest.mark.parametrize("parameters", [pytest.param({}, id="crc_none")])
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
