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
# - Sweep: Use the standalone `AxiStreamDepacketizer2` wrapper with CRC
#   disabled and a small `TDEST_BITS_G=2` address space so startup RAM
#   initialization stays short under GHDL.
# - Stimulus: Present packetizer-V2 header, payload, and tail beats directly,
#   including a two-packet continuation sequence with incrementing packet
#   sequence numbers.
# - Checks: The depacketized application stream must restore payload bytes,
#   `TDEST`, `TID`, first-beat SOF, final-beat `TUSER`, `TKEEP`, and `TLAST`
#   without relying on `AxiStreamPacketizer2` as the stimulus generator.
# - Timing: The test waits for the depacketizer `initDone` debug bit before
#   traffic, then keeps the application sink ready while source and sink tasks
#   run concurrently.

import cocotb
import pytest
from cocotb.triggers import with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.packetizer_test_utils import (
    AxisBeat,
    FlatAxisEndpoint,
    PACKETIZER2_CRC_DATA,
    PACKETIZER2_CRC_NONE,
    DEBUG_INIT_DONE,
    assert_app_beat,
    cycle,
    packetizer2_data_beat,
    packetizer2_header_beat,
    packetizer2_header_word,
    packetizer2_tail_beat,
    recv_beats,
    reset_packetizer_dut,
    send_beats,
    start_packetizer_clock,
    wait_debug_init_done,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = FlatAxisEndpoint(dut, prefix="S_AXIS")
        self.sink = FlatAxisEndpoint(dut, prefix="M_AXIS")

        start_packetizer_clock(dut)
        dut.axisRst.setimmediatevalue(1)
        dut.linkGood.setimmediatevalue(1)
        dut.M_AXIS_TREADY.setimmediatevalue(0)
        self.source.set_idle()

    async def reset(self):
        await reset_packetizer_dut(self.dut)
        await self.wait_init_done()

    async def wait_init_done(self, timeout_cycles: int = 64):
        await wait_debug_init_done(self.dut, timeout_cycles=timeout_cycles)


def assert_error_beat(beat: AxisBeat, *, dest: int, tid: int, header_user: int) -> None:
    assert beat.last == 1
    assert beat.dest == dest
    assert beat.tid == tid
    assert (beat.user & 0xFF) == (header_user | 0x3)
    assert (beat.user >> 56) & 0x1 == 0x1


@cocotb.test()
async def depacketize_single_packet_test(dut):
    tb = TB(dut)
    await tb.reset()

    first = bytes(range(0x10, 0x18))
    last = bytes(range(0x18, 0x20))
    packet = [
        packetizer2_header_beat(sof=1, tuser=0x20, dest=0x3, tid=0xA5, seq=0),
        packetizer2_data_beat(first),
        packetizer2_data_beat(last),
        packetizer2_tail_beat(eof=1, tuser=0x41, byte_count=8),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 2, clk=dut.axisClk))
    await send_beats(tb.source, packet, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    assert_app_beat(rx_beats[0], payload=first, dest=0x3, tid=0xA5, user=0x22)
    assert_app_beat(rx_beats[1], payload=last, last=1, dest=0x3, tid=0xA5, user=0x41 << 56)


@cocotb.test()
async def depacketize_split_sequence_test(dut):
    tb = TB(dut)
    await tb.reset()

    chunks = [
        bytes(range(0x30, 0x38)),
        bytes(range(0x38, 0x40)),
        bytes(range(0x40, 0x48)),
    ]
    packets = [
        packetizer2_header_beat(sof=1, tuser=0x10, dest=0x2, tid=0x5A, seq=0),
        packetizer2_data_beat(chunks[0]),
        packetizer2_data_beat(chunks[1]),
        packetizer2_tail_beat(eof=0, tuser=0, byte_count=8),
        packetizer2_header_beat(sof=0, tuser=0x00, dest=0x2, tid=0x5A, seq=1),
        packetizer2_data_beat(chunks[2]),
        packetizer2_tail_beat(eof=1, tuser=0x43, byte_count=8),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 3, clk=dut.axisClk))
    await send_beats(tb.source, packets, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert_app_beat(rx_beats[0], payload=chunks[0], dest=0x2, tid=0x5A, user=0x12)
    assert_app_beat(rx_beats[1], payload=chunks[1], dest=0x2, tid=0x5A)
    assert_app_beat(rx_beats[2], payload=chunks[2], last=1, dest=0x2, tid=0x5A, user=0x43 << 56)


@cocotb.test()
async def depacketize_partial_last_tkeep_test(dut):
    tb = TB(dut)
    await tb.reset()

    first = bytes(range(0x50, 0x58))
    last = bytes(range(0x58, 0x5B))
    packet = [
        packetizer2_header_beat(sof=1, tuser=0x24, dest=0x1, tid=0xC3, seq=0),
        packetizer2_data_beat(first),
        packetizer2_data_beat(last),
        packetizer2_tail_beat(eof=1, tuser=0x47, byte_count=3),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 2, clk=dut.axisClk))
    await send_beats(tb.source, packet, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    assert_app_beat(rx_beats[0], payload=first, dest=0x1, tid=0xC3, user=0x26)
    assert_app_beat(
        rx_beats[1],
        payload=last,
        keep=0x07,
        last=1,
        dest=0x1,
        tid=0xC3,
        user=0x47 << 16,
    )


@cocotb.test()
async def depacketize_crc_none_nonzero_crc_marks_eofe_test(dut):
    tb = TB(dut)
    await tb.reset()

    payload = bytes(range(0x70, 0x78))
    packet = [
        packetizer2_header_beat(sof=1, tuser=0x30, dest=0x2, tid=0x55, seq=0),
        packetizer2_data_beat(payload),
        packetizer2_tail_beat(eof=1, tuser=0x40, byte_count=8, crc=0x1),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 1, clk=dut.axisClk))
    await send_beats(tb.source, packet, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    # CRC mode NONE requires the CRC field to be zero. A nonzero field marks
    # the frame as terminal-error while still forwarding the held payload beat.
    assert_app_beat(
        rx_beats[0],
        payload=payload,
        last=1,
        dest=0x2,
        tid=0x55,
        user=0x32 | (0x41 << 56),
    )


@cocotb.test()
async def depacketize_bad_version_header_marks_eofe_test(dut):
    tb = TB(dut)
    await tb.reset()

    bad_header = packetizer2_header_word(
        crc_mode=PACKETIZER2_CRC_NONE,
        sof=1,
        tuser=0x29,
        tdest=0x1,
        tid=0x66,
        seq=0,
    )
    packet = [AxisBeat(data=(bad_header & ~0xF) | 0x7, keep=0xFF, last=0, user=0x2)]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 1, clk=dut.axisClk))
    await send_beats(tb.source, packet, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    assert_error_beat(rx_beats[0], dest=0x1, tid=0x66, header_user=0x29)


@cocotb.test()
async def depacketize_bad_crc_mode_header_marks_eofe_test(dut):
    tb = TB(dut)
    await tb.reset()

    packet = [
        packetizer2_header_beat(
            sof=1,
            tuser=0x2B,
            dest=0x2,
            tid=0x77,
            seq=0,
            crc_mode=PACKETIZER2_CRC_DATA,
        )
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 1, clk=dut.axisClk))
    await send_beats(tb.source, packet, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    assert_error_beat(rx_beats[0], dest=0x2, tid=0x77, header_user=0x2B)


@cocotb.test()
async def depacketize_link_drop_recovers_test(dut):
    tb = TB(dut)
    await tb.reset()

    dut.linkGood.value = 0
    await cycle(dut.axisClk, 4)
    assert (int(dut.debugOut.value) & (1 << DEBUG_INIT_DONE)) == 0

    dut.linkGood.value = 1
    await tb.wait_init_done()

    payload = bytes(range(0x90, 0x98))
    packet = [
        packetizer2_header_beat(sof=1, tuser=0x34, dest=0x3, tid=0x88, seq=0),
        packetizer2_data_beat(payload),
        packetizer2_tail_beat(eof=1, tuser=0x48, byte_count=8),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 1, clk=dut.axisClk))
    await send_beats(tb.source, packet, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    assert_app_beat(
        rx_beats[0],
        payload=payload,
        last=1,
        dest=0x3,
        tid=0x88,
        user=0x36 | (0x48 << 56),
    )


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param(
            {
                "TDEST_BITS_G": 2,
            },
            id="crc_none_tdest2",
        )
    ],
)
def test_AxiStreamDepacketizer2(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdepacketizer2wrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["protocols/packetizer/wrappers/AxiStreamDepacketizer2Wrapper.vhd"],
        },
    )
