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
# - Sweep: Use the standalone `AxiStreamPacketizer2` wrapper with
#   `SEQ_CNT_SIZE_G=4`, the smallest supported sequence counter width.
# - Stimulus: Drive one long frame that requires 17 internal packetizer
#   packets, forcing the packet sequence field to wrap from 15 back to 0.
# - Checks: Every packet header must carry the expected wrapped sequence value,
#   SOF must appear only on the first packet, and EOF must appear only on the
#   final packet tail.
# - Timing: The sink is kept ready while the source frame is sent through the
#   normal ready/valid handshake.

import cocotb
import pytest
from cocotb.triggers import with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.packetizer_test_utils import (
    AxisBeat,
    FlatAxisEndpoint,
    PACKETIZER2_CRC_NONE,
    assert_packetized_beat,
    assert_packetizer2_tail_beat,
    packetizer2_header_word,
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


@cocotb.test()
async def packetize_sequence_counter_wrap_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Each packet carries two full payload words at this 32-byte packet limit.
    # Seventeen packets therefore require thirty-four 8-byte input beats.
    input_beats = []
    for index in range(34):
        payload = bytes((0x20 + index + lane) & 0xFF for lane in range(8))
        input_beats.append(
            AxisBeat(
                data=word_from_bytes(payload),
                keep=0xFF,
                last=int(index == 33),
                dest=0x1,
                tid=0x55,
                user=(0x24 if index == 0 else 0) | ((0x46 << 56) if index == 33 else 0),
            )
        )

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 68, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 20, "us")

    for packet_index in range(17):
        base = packet_index * 4
        seq = packet_index & 0xF
        assert_packetized_beat(
            rx_beats[base],
            data=packetizer2_header_word(
                crc_mode=PACKETIZER2_CRC_NONE,
                sof=int(packet_index == 0),
                tuser=0x24 if packet_index == 0 else 0x00,
                tdest=0x1,
                tid=0x55,
                seq=seq,
            ),
            user=0x2,
        )
        assert_packetizer2_tail_beat(
            rx_beats[base + 3],
            eof=int(packet_index == 16),
            tuser=0x46 if packet_index == 16 else 0x00,
            byte_count=8,
        )


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({"SEQ_CNT_SIZE_G": 4}, id="seq4_wrap"),
    ],
)
def test_AxiStreamPacketizer2SeqWrap(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreampacketizer2wrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["protocols/packetizer/wrappers/AxiStreamPacketizer2Wrapper.vhd"],
        },
    )
