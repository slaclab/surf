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
# - Sweep: Use the standalone `AxiStreamDepacketizer2` wrapper in CRC NONE
#   mode with a small two-bit destination state table.
# - Stimulus: Start a packet without sending its tail, then drop `linkGood`
#   while the depacketizer has active frame state.
# - Checks: The depacketizer must terminate the incomplete frame with SSI
#   `EOFE` during link cleanup and accept a fresh frame after link recovery.
# - Timing: The test runs alone in this file so the link-cleanup sweep observes
#   only the intentionally opened destination state.

import cocotb
import pytest
from cocotb.triggers import with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.packetizer_test_utils import (
    FlatAxisEndpoint,
    assert_app_beat,
    bytes_from_word,
    packetizer2_data_beat,
    packetizer2_header_beat,
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


@cocotb.test()
async def depacketize_mid_frame_link_drop_terminates_and_recovers_test(dut):
    tb = TB(dut)
    await tb.reset()

    payload = bytes(range(0xA0, 0xA8))
    open_packet = [
        packetizer2_header_beat(sof=1, tuser=0x36, dest=0x1, tid=0x91, seq=0),
        packetizer2_data_beat(payload),
    ]

    await send_beats(tb.source, open_packet, clk=dut.axisClk)
    rx_task = cocotb.start_soon(recv_beats(tb.sink, 2, clk=dut.axisClk))
    dut.linkGood.value = 0
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert bytes_from_word(rx_beats[0].data) == payload
    assert rx_beats[0].last == 0
    assert rx_beats[0].dest == 0x1
    assert rx_beats[0].tid == 0x91
    assert rx_beats[0].user == 0x36
    assert rx_beats[1].last == 1
    assert bytes_from_word(rx_beats[1].data) == payload
    assert ((rx_beats[1].user >> 56) & 0x1) == 0x1

    dut.linkGood.value = 1
    await tb.wait_init_done()

    recovery = bytes(range(0xB0, 0xB8))
    recovery_packet = [
        packetizer2_header_beat(sof=1, tuser=0x38, dest=0x1, tid=0x92, seq=0),
        packetizer2_data_beat(recovery),
        packetizer2_tail_beat(eof=1, tuser=0x4A, byte_count=8),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 1, clk=dut.axisClk))
    await send_beats(tb.source, recovery_packet, clk=dut.axisClk)
    recovery_beats = await with_timeout(rx_task, 3, "us")

    assert_app_beat(
        recovery_beats[0],
        payload=recovery,
        last=1,
        dest=0x1,
        tid=0x92,
        user=0x3A | (0x4A << 56),
    )


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({"TDEST_BITS_G": 2}, id="crc_none_tdest2"),
    ],
)
def test_AxiStreamDepacketizer2LinkDrop(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdepacketizer2wrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["protocols/packetizer/wrappers/AxiStreamDepacketizer2Wrapper.vhd"],
        },
    )
