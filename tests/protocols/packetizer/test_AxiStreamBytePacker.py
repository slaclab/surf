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
# - Sweep: Use a standalone `AxiStreamBytePacker` wrapper with a 4-byte
#   compressed-keep input stream and an 8-byte compressed-keep output stream.
# - Stimulus: Drive one input beat per clock because this RTL intentionally has
#   no ready handshake, using partial keeps, exact-width terminal beats, and
#   reset while a partial packed word is buffered.
# - Checks: The output valid pulses must contain compacted payload bytes in
#   arrival order, matching per-byte `TUSER`, compressed `TKEEP`, and `TLAST`
#   only on frame-terminating words.
# - Timing: Output is sampled on clocked valid pulses rather than through a
#   sink-ready handshake, matching the module's no-backpressure contract.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer, with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.packetizer_test_utils import (
    AxisBeat,
    FlatAxisEndpoint,
    bytes_from_word,
    cycle,
    reset_packetizer_dut,
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
        dut.M_AXIS_TREADY.setimmediatevalue(1)
        self.source.set_idle()

    async def reset(self):
        await reset_packetizer_dut(self.dut)


def user_from_bytes(values: list[int]) -> int:
    user = 0
    for lane, value in enumerate(values):
        user |= (value & 0xFF) << (8 * lane)
    return user


def source_beat(payload: bytes, *, last: int = 0, user_base: int) -> AxisBeat:
    return AxisBeat(
        data=word_from_bytes(payload),
        keep=(1 << len(payload)) - 1,
        last=last,
        user=user_from_bytes([user_base + index for index in range(len(payload))]),
    )


async def send_unpaced(endpoint: FlatAxisEndpoint, beats: list[AxisBeat], *, clk) -> None:
    # `AxiStreamBytePacker` has no slave-ready output. Each driven beat is held
    # for exactly one rising edge, which is the module's intended acceptance
    # cadence.
    for beat in beats:
        endpoint.drive(beat)
        await RisingEdge(clk)
        await Timer(1, unit="ns")
    endpoint.set_idle()


async def recv_valid_pulses(endpoint: FlatAxisEndpoint, count: int, *, clk) -> list[AxisBeat]:
    beats = []
    while len(beats) < count:
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if int(endpoint._sig("TVALID").value):
            beats.append(endpoint.snapshot())
    return beats


async def assert_no_output(endpoint: FlatAxisEndpoint, *, clk, cycles: int) -> None:
    for _ in range(cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        assert int(endpoint._sig("TVALID").value) == 0


def assert_packed_beat(
    beat: AxisBeat,
    *,
    payload: bytes,
    user_values: list[int],
    last: int = 0,
) -> None:
    keep = (1 << len(payload)) - 1
    assert bytes_from_word(beat.data, keep=keep) == payload
    assert beat.keep == keep
    assert beat.last == last
    assert beat.user == user_from_bytes(user_values)


@cocotb.test()
async def pack_partial_beats_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The third input beat fills the first 8-byte output word and contributes
    # one extra byte to the next packed word; the final beat then terminates
    # that partial word.
    input_beats = [
        source_beat(bytes([0x10, 0x11, 0x12]), user_base=0xA0),
        source_beat(bytes([0x13, 0x14]), user_base=0xA3),
        source_beat(bytes([0x15, 0x16, 0x17, 0x18]), user_base=0xA5),
        source_beat(bytes([0x19, 0x1A]), last=1, user_base=0xA9),
    ]

    rx_task = cocotb.start_soon(recv_valid_pulses(tb.sink, 2, clk=dut.axisClk))
    await send_unpaced(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 2, "us")

    assert_packed_beat(
        rx_beats[0],
        payload=bytes(range(0x10, 0x18)),
        user_values=list(range(0xA0, 0xA8)),
    )
    assert_packed_beat(
        rx_beats[1],
        payload=bytes([0x18, 0x19, 0x1A]),
        user_values=[0xA8, 0xA9, 0xAA],
        last=1,
    )


@cocotb.test()
async def pack_exact_width_last_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Two four-byte input beats should produce one full eight-byte output beat.
    # Because the second input beat is terminal, the full output is terminal too.
    input_beats = [
        source_beat(bytes([0x30, 0x31, 0x32, 0x33]), user_base=0x10),
        source_beat(bytes([0x34, 0x35, 0x36, 0x37]), last=1, user_base=0x14),
    ]

    rx_task = cocotb.start_soon(recv_valid_pulses(tb.sink, 1, clk=dut.axisClk))
    await send_unpaced(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 2, "us")

    assert_packed_beat(
        rx_beats[0],
        payload=bytes(range(0x30, 0x38)),
        user_values=list(range(0x10, 0x18)),
        last=1,
    )


@cocotb.test()
async def reset_flushes_partial_word_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Start a partial packed word and prove it does not leak out before reset.
    await send_unpaced(
        tb.source,
        [source_beat(bytes([0x40, 0x41, 0x42]), user_base=0x20)],
        clk=dut.axisClk,
    )
    await assert_no_output(tb.sink, clk=dut.axisClk, cycles=3)

    # Reset should discard the buffered partial word. The only subsequent output
    # should be the new short frame driven after reset releases.
    await tb.reset()
    rx_task = cocotb.start_soon(recv_valid_pulses(tb.sink, 1, clk=dut.axisClk))
    await send_unpaced(
        tb.source,
        [source_beat(bytes([0x50, 0x51]), last=1, user_base=0x30)],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 2, "us")

    assert_packed_beat(
        rx_beats[0],
        payload=bytes([0x50, 0x51]),
        user_values=[0x30, 0x31],
        last=1,
    )


@pytest.mark.parametrize("parameters", [pytest.param({}, id="comp_keep_4_to_8")])
def test_AxiStreamBytePacker(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreambytepackerwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["protocols/packetizer/wrappers/AxiStreamBytePackerWrapper.vhd"],
        },
    )
