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
# - Sweep: Use a standalone `AxiStreamBytePacker` wrapper with several
#   compressed-keep input/output byte-width pairs.
# - Stimulus: Drive one input beat per clock because this RTL intentionally has
#   no ready handshake, using partial keeps, exact-width terminal beats, and
#   reset while a partial packed word is buffered.
# - Checks: The output valid pulses must contain compacted payload bytes in
#   arrival order, matching per-byte `TUSER`, compressed `TKEEP`, and `TLAST`
#   only on frame-terminating words.
# - Timing: Output is sampled on clocked valid pulses rather than through a
#   sink-ready handshake, matching the module's no-backpressure contract.

import os

import cocotb
import pytest
from cocotb.triggers import with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.packetizer_test_utils import (
    AxisBeat,
    FlatAxisEndpoint,
    assert_no_output,
    assert_packed_beat,
    byte_packer_source_beat,
    byte_packer_source_beats_from_payload,
    recv_valid_pulses,
    reset_packetizer_dut,
    send_unpaced_beats,
    start_packetizer_clock,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = FlatAxisEndpoint(dut, prefix="S_AXIS")
        self.sink = FlatAxisEndpoint(dut, prefix="M_AXIS")
        self.slave_bytes = int(os.getenv("SLAVE_BYTES_G", "4"))
        self.master_bytes = int(os.getenv("MASTER_BYTES_G", "8"))

        start_packetizer_clock(dut)
        dut.axisRst.setimmediatevalue(1)
        dut.M_AXIS_TREADY.setimmediatevalue(1)
        self.source.set_idle()

    async def reset(self):
        await reset_packetizer_dut(self.dut)


@cocotb.test()
async def pack_partial_beats_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The final input beat crosses an output-word boundary: one output word
    # becomes full and the remaining bytes start the next terminal output word.
    payload = bytes(range(0x10, 0x10 + tb.master_bytes + 3))
    input_beats = byte_packer_source_beats_from_payload(
        payload,
        max_beat_bytes=tb.slave_bytes,
        user_base=0xA0,
        first_size=max(1, min(tb.slave_bytes - 1, 3)),
    )

    rx_task = cocotb.start_soon(recv_valid_pulses(tb.sink, 2, clk=dut.axisClk))
    await send_unpaced_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 2, "us")

    assert_packed_beat(
        rx_beats[0],
        payload=payload[: tb.master_bytes],
        user_values=list(range(0xA0, 0xA0 + tb.master_bytes)),
    )
    assert_packed_beat(
        rx_beats[1],
        payload=payload[tb.master_bytes :],
        user_values=list(range(0xA0 + tb.master_bytes, 0xA0 + len(payload))),
        last=1,
    )


@cocotb.test()
async def pack_exact_width_last_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A frame exactly as wide as the output should produce one full terminal
    # word regardless of how many narrower input beats it takes to fill it.
    payload = bytes(range(0x30, 0x30 + tb.master_bytes))
    input_beats = byte_packer_source_beats_from_payload(
        payload,
        max_beat_bytes=tb.slave_bytes,
        user_base=0x10,
    )

    rx_task = cocotb.start_soon(recv_valid_pulses(tb.sink, 1, clk=dut.axisClk))
    await send_unpaced_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 2, "us")

    assert_packed_beat(
        rx_beats[0],
        payload=payload,
        user_values=list(range(0x10, 0x10 + len(payload))),
        last=1,
    )


@cocotb.test()
async def reset_flushes_partial_word_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Start a partial packed word and prove it does not leak out before reset.
    partial = bytes(range(0x40, 0x40 + min(3, tb.slave_bytes, tb.master_bytes - 1)))
    await send_unpaced_beats(
        tb.source,
        [byte_packer_source_beat(partial, user_values=list(range(0x20, 0x20 + len(partial))))],
        clk=dut.axisClk,
    )
    await assert_no_output(tb.sink, clk=dut.axisClk, cycles=3)

    # Reset should discard the buffered partial word. The only subsequent output
    # should be the new short frame driven after reset releases.
    await tb.reset()
    rx_task = cocotb.start_soon(recv_valid_pulses(tb.sink, 1, clk=dut.axisClk))
    new_frame = bytes(range(0x50, 0x50 + min(2, tb.slave_bytes)))
    await send_unpaced_beats(
        tb.source,
        [
            byte_packer_source_beat(
                new_frame,
                last=1,
                user_values=list(range(0x30, 0x30 + len(new_frame))),
            )
        ],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 2, "us")

    assert_packed_beat(
        rx_beats[0],
        payload=new_frame,
        user_values=list(range(0x30, 0x30 + len(new_frame))),
        last=1,
    )


@cocotb.test()
async def idle_gap_preserves_partial_word_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The packer should keep a partial word across idle cycles and continue
    # filling it when traffic resumes.
    payload = bytes(range(0x60, 0x60 + tb.master_bytes))
    first_len = max(1, min(3, tb.slave_bytes, tb.master_bytes - 1))
    first = byte_packer_source_beat(
        payload[:first_len],
        user_values=list(range(0x40, 0x40 + first_len)),
    )
    remaining = byte_packer_source_beats_from_payload(
        payload[first_len:],
        max_beat_bytes=tb.slave_bytes,
        user_base=0x40 + first_len,
    )

    rx_task = cocotb.start_soon(recv_valid_pulses(tb.sink, 1, clk=dut.axisClk))
    await send_unpaced_beats(tb.source, [first], clk=dut.axisClk)
    await assert_no_output(tb.sink, clk=dut.axisClk, cycles=4)
    await send_unpaced_beats(tb.source, remaining, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 2, "us")

    assert_packed_beat(
        rx_beats[0],
        payload=payload,
        user_values=list(range(0x40, 0x40 + len(payload))),
        last=1,
    )


@cocotb.test()
async def zero_keep_beat_is_ignored_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A valid beat with no asserted keep bits should not contribute data or
    # sideband bytes to the packed output word. The following short terminal
    # frame should emerge exactly as if the zero-keep beat had been idle.
    payload = bytes(range(0x70, 0x70 + min(3, tb.slave_bytes)))
    rx_task = cocotb.start_soon(recv_valid_pulses(tb.sink, 1, clk=dut.axisClk))
    await send_unpaced_beats(
        tb.source,
        [
            AxisBeat(
                data=(1 << (8 * tb.slave_bytes)) - 1,
                keep=0x00,
                last=0,
                user=(1 << (8 * tb.slave_bytes)) - 1,
            ),
            byte_packer_source_beat(
                payload,
                last=1,
                user_values=list(range(0x60, 0x60 + len(payload))),
            ),
        ],
        clk=dut.axisClk,
    )
    rx_beats = await with_timeout(rx_task, 2, "us")

    assert_packed_beat(
        rx_beats[0],
        payload=payload,
        user_values=list(range(0x60, 0x60 + len(payload))),
        last=1,
    )


@cocotb.test()
async def output_ready_is_ignored_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The RTL explicitly has no ready handshaking. Holding output ready low must
    # not suppress the valid pulse for a complete packed output word.
    dut.M_AXIS_TREADY.value = 0
    payload = bytes(range(0x80, 0x80 + tb.master_bytes))
    input_beats = byte_packer_source_beats_from_payload(
        payload,
        max_beat_bytes=tb.slave_bytes,
        user_base=0x50,
    )

    rx_task = cocotb.start_soon(recv_valid_pulses(tb.sink, 1, clk=dut.axisClk))
    await send_unpaced_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 2, "us")

    assert_packed_beat(
        rx_beats[0],
        payload=payload,
        user_values=list(range(0x50, 0x50 + len(payload))),
        last=1,
    )


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({"SLAVE_BYTES_G": 1, "MASTER_BYTES_G": 8}, id="comp_keep_1_to_8"),
        pytest.param({"SLAVE_BYTES_G": 2, "MASTER_BYTES_G": 5}, id="comp_keep_2_to_5"),
        pytest.param({"SLAVE_BYTES_G": 3, "MASTER_BYTES_G": 6}, id="comp_keep_3_to_6"),
        pytest.param({"SLAVE_BYTES_G": 3, "MASTER_BYTES_G": 7}, id="comp_keep_3_to_7"),
        pytest.param({"SLAVE_BYTES_G": 4, "MASTER_BYTES_G": 8}, id="comp_keep_4_to_8"),
        pytest.param({"SLAVE_BYTES_G": 5, "MASTER_BYTES_G": 7}, id="comp_keep_5_to_7"),
        pytest.param({"SLAVE_BYTES_G": 7, "MASTER_BYTES_G": 8}, id="comp_keep_7_to_8"),
    ],
)
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
