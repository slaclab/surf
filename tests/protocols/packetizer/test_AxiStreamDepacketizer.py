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
# - Sweep: Use the standalone legacy `AxiStreamDepacketizer` wrapper with an
#   8-byte packetized input stream.
# - Stimulus: Present hand-built V0 header and payload beats directly,
#   including both tail encodings produced by the legacy packetizer.
# - Checks: The depacketized application stream must restore payload bytes,
#   `TDEST`, `TID`, SOF on first-beat `TUSER`, final-byte `TUSER`, `TKEEP`,
#   and `TLAST` for appended-tail and separate-tail packets.
# - Timing: The application sink is kept ready while source and sink tasks run
#   concurrently, with no packetizer loopback used as the stimulus generator.

import cocotb
import pytest
from cocotb.triggers import with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.packetizer_test_utils import (
    AxisBeat,
    FlatAxisEndpoint,
    bytes_from_word,
    packetizer0_header_word,
    packetizer0_tail_byte,
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
        dut.restart.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(0)
        self.source.set_idle()

    async def reset(self):
        await reset_packetizer_dut(self.dut)


def header_beat(*, frame: int, packet: int, tuser: int, dest: int, tid: int) -> AxisBeat:
    return AxisBeat(
        data=packetizer0_header_word(
            frame=frame,
            packet=packet,
            tdest=dest,
            tid=tid,
            tuser=tuser,
        ),
        keep=0xFF,
        last=0,
        user=0x2,
    )


def data_beat(payload: bytes, *, keep: int = 0xFF, last: int = 0) -> AxisBeat:
    return AxisBeat(data=word_from_bytes(payload), keep=keep, last=last, user=0)


def assert_app_beat(
    beat: AxisBeat,
    *,
    payload: bytes,
    keep: int = 0xFF,
    last: int = 0,
    dest: int,
    tid: int,
    user: int = 0,
) -> None:
    assert bytes_from_word(beat.data, keep=keep) == payload
    assert beat.keep == keep
    assert beat.last == last
    assert beat.dest == dest
    assert beat.tid == tid
    assert beat.user == user


@cocotb.test()
async def depacketize_appended_tail_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Build the packetizer-V0 stream directly: header, one full payload beat,
    # and a final beat whose last byte is the EOF/user tail marker.
    first = bytes(range(0x10, 0x18))
    last = bytes(range(0x18, 0x1F))
    tail = packetizer0_tail_byte(eof=1, tuser=0x41)
    packet = [
        header_beat(frame=0, packet=0, tuser=0x20, dest=0x3, tid=0xA5),
        data_beat(first),
        data_beat(last + bytes([tail]), last=1),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 2, clk=dut.axisClk))
    await send_beats(tb.source, packet, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    # The depacketizer restores header sideband onto the first application beat
    # and sets SSI SOF in the first byte's `TUSER`.
    assert_app_beat(rx_beats[0], payload=first, dest=0x3, tid=0xA5, user=0x22)
    # For an appended tail, the final byte lane is stripped via `TKEEP`, and the
    # tail user bits move onto the last real payload byte.
    assert_app_beat(
        rx_beats[1],
        payload=last,
        keep=0x7F,
        last=1,
        dest=0x3,
        tid=0xA5,
        user=0x41 << 48,
    )


@cocotb.test()
async def depacketize_separate_tail_test(dut):
    tb = TB(dut)
    await tb.reset()

    # This packet uses the other legal tail placement: a full final payload word
    # followed by a separate one-byte EOF/user marker.
    first = bytes(range(0x30, 0x38))
    last = bytes(range(0x38, 0x40))
    tail = packetizer0_tail_byte(eof=1, tuser=0x42)
    packet = [
        header_beat(frame=0, packet=0, tuser=0x10, dest=0x2, tid=0x5A),
        data_beat(first),
        data_beat(last),
        AxisBeat(data=tail, keep=0x01, last=1, user=0),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 2, clk=dut.axisClk))
    await send_beats(tb.source, packet, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 3, "us")

    # The first output beat proves sideband restoration, while the second proves
    # that the one-byte marker was consumed without becoming payload data.
    assert_app_beat(rx_beats[0], payload=first, dest=0x2, tid=0x5A, user=0x12)
    assert_app_beat(
        rx_beats[1],
        payload=last,
        last=1,
        dest=0x2,
        tid=0x5A,
        user=0x42 << 56,
    )


@cocotb.test()
async def depacketize_split_sequence_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Hand-build a valid two-packet V0 frame. The first packet terminates with
    # EOF=0, so the depacketizer must retain frame state and accept packet 1 as
    # a continuation without adding another SOF.
    chunks = [
        bytes(range(0x60, 0x68)),
        bytes(range(0x68, 0x70)),
        bytes(range(0x70, 0x78)),
    ]
    packet = [
        header_beat(frame=0, packet=0, tuser=0x30, dest=0x4, tid=0x22),
        data_beat(chunks[0]),
        data_beat(chunks[1]),
        AxisBeat(data=packetizer0_tail_byte(eof=0, tuser=0), keep=0x01, last=1, user=0),
        header_beat(frame=0, packet=1, tuser=0x00, dest=0x4, tid=0x22),
        data_beat(chunks[2]),
        AxisBeat(data=packetizer0_tail_byte(eof=1, tuser=0x43), keep=0x01, last=1, user=0),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 3, clk=dut.axisClk))
    await send_beats(tb.source, packet, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert_app_beat(rx_beats[0], payload=chunks[0], dest=0x4, tid=0x22, user=0x32)
    assert_app_beat(rx_beats[1], payload=chunks[1], dest=0x4, tid=0x22)
    assert_app_beat(
        rx_beats[2],
        payload=chunks[2],
        last=1,
        dest=0x4,
        tid=0x22,
        user=0x43 << 56,
    )


@pytest.mark.parametrize("parameters", [pytest.param({}, id="legacy_v0")])
def test_AxiStreamDepacketizer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdepacketizerwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["protocols/packetizer/wrappers/AxiStreamDepacketizerWrapper.vhd"],
        },
    )
