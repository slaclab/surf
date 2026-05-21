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
# - Sweep: Use a cocotb-facing loopback wrapper that connects
#   `AxiStreamPacketizer2` directly to `AxiStreamDepacketizer2`, sweeping the
#   NONE, DATA, and FULL CRC modes.
# - Stimulus: Drive application AXI Stream frames with partial final `TKEEP`,
#   nonzero first/last `TUSER`, `TDEST`, and `TID` through a small packet-size
#   limit that forces the packetizer to emit continuation packets internally.
# - Checks: The loopback output must restore payload bytes, `TKEEP`, `TLAST`,
#   `TDEST`, `TID`, and first/last `TUSER`, while the sink applies backpressure.
# - Timing: The test waits for depacketizer RAM initialization before traffic,
#   then uses ordinary AXI Stream ready/valid handshakes on the application
#   input and output only.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer, with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.packetizer_test_utils import (
    AxisBeat,
    FlatAxisEndpoint,
    bytes_from_word,
    payload_to_beats,
    recv_beats_with_backpressure,
    reset_packetizer_dut,
    send_beats,
    start_packetizer_clock,
)

DEBUG_INIT_DONE = 12


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = FlatAxisEndpoint(dut, prefix="S_AXIS")
        self.sink = FlatAxisEndpoint(dut, prefix="M_AXIS")

        start_packetizer_clock(dut)
        dut.axisRst.setimmediatevalue(1)
        dut.linkGood.setimmediatevalue(1)
        dut.maxPktBytes.setimmediatevalue(32)
        dut.M_AXIS_TREADY.setimmediatevalue(0)
        self.source.set_idle()

    async def reset(self):
        await reset_packetizer_dut(self.dut)
        await self.wait_init_done()

    async def wait_init_done(self, timeout_cycles: int = 64):
        for _ in range(timeout_cycles):
            if int(self.dut.debugOut.value) & (1 << DEBUG_INIT_DONE):
                return
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")
        raise AssertionError("Timed out waiting for loopback depacketizer initDone")


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
async def loopback_split_partial_frame_with_backpressure_test(dut):
    tb = TB(dut)
    await tb.reset()

    # This 19-byte frame forces an internal V2 packet split at the 32-byte
    # packetized limit, then ends with a three-byte final output word.
    payload = bytes(range(0x10, 0x23))
    input_beats = payload_to_beats(
        payload,
        dest=0x2,
        tid=0x39,
        first_user=0x2C,
        last_user=0x4C,
    )

    rx_task = cocotb.start_soon(recv_beats_with_backpressure(tb.sink, 3, clk=dut.axisClk))
    await send_beats(tb.source, input_beats, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 6, "us")

    assert_app_beat(rx_beats[0], payload=payload[0:8], dest=0x2, tid=0x39, user=0x2E)
    assert_app_beat(rx_beats[1], payload=payload[8:16], dest=0x2, tid=0x39)
    assert_app_beat(
        rx_beats[2],
        payload=payload[16:19],
        keep=0x07,
        last=1,
        dest=0x2,
        tid=0x39,
        user=0x4C << 16,
    )


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({"TDEST_BITS_G": 2}, id="crc_none"),
        pytest.param({"TDEST_BITS_G": 2, "CRC_MODE_G": "DATA"}, id="crc_data"),
        pytest.param({"TDEST_BITS_G": 2, "CRC_MODE_G": "FULL"}, id="crc_full"),
    ],
)
def test_AxiStreamPacketizer2Loopback(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreampacketizer2loopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["protocols/packetizer/wrappers/AxiStreamPacketizer2LoopbackWrapper.vhd"],
        },
    )
