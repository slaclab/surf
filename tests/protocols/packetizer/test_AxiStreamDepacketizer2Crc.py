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
#   checking enabled in DATA and FULL modes.
# - Stimulus: Drive one hand-built packet whose header advertises the active
#   CRC mode but whose tail CRC field is deliberately wrong.
# - Checks: The depacketizer must forward the held payload beat, terminate the
#   application frame, and mark the last byte-lane `TUSER` with SSI `EOFE`.
# - Timing: The test waits for depacketizer initialization, then uses ordinary
#   AXI Stream source and sink handshakes around a short packet.

import cocotb
import pytest
from cocotb.triggers import with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.packetizer.packetizer_test_utils import (
    FlatAxisEndpoint,
    assert_app_beat,
    crc_mode_from_env,
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
async def depacketize_bad_crc_marks_eofe_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The CRC field is intentionally not a computed CRC. In DATA and FULL modes
    # that must be treated as a terminal frame error on the held payload word.
    payload = bytes(range(0x20, 0x28))
    packet = [
        packetizer2_header_beat(
            crc_mode=crc_mode_from_env("DATA"),
            sof=1,
            tuser=0x30,
            dest=0x2,
            tid=0x5C,
            seq=0,
        ),
        packetizer2_data_beat(payload),
        packetizer2_tail_beat(eof=1, tuser=0x42, byte_count=8, crc=0x0),
    ]

    rx_task = cocotb.start_soon(recv_beats(tb.sink, 1, clk=dut.axisClk))
    await send_beats(tb.source, packet, clk=dut.axisClk)
    rx_beats = await with_timeout(rx_task, 4, "us")

    assert_app_beat(
        rx_beats[0],
        payload=payload,
        last=1,
        dest=0x2,
        tid=0x5C,
        user=0x32 | (0x43 << 56),
    )


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({"TDEST_BITS_G": 2, "CRC_MODE_G": "DATA"}, id="crc_data_bad_crc"),
        pytest.param({"TDEST_BITS_G": 2, "CRC_MODE_G": "FULL"}, id="crc_full_bad_crc"),
    ],
)
def test_AxiStreamDepacketizer2Crc(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdepacketizer2wrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["protocols/packetizer/wrappers/AxiStreamDepacketizer2Wrapper.vhd"],
        },
    )
