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
# - Sweep: Exercise the bridge RX on the two CoaXPress receive-side cases the
#   current RTL decodes explicitly from the start word: normal low-speed
#   packets and `IO_ACK`.
# - Stimulus: Drive one CXPoF start/payload/terminate sequence that encodes a
#   serialized CoaXPress packet, then drive a separate start/terminate sequence
#   that encodes an `IO_ACK`.
# - Checks: The bridge must reconstruct the repeated-byte `SOP`, packet-type,
#   payload, and `EOP` words for the first packet, emit the standalone
#   `IO_ACK` word for the second packet, and otherwise remain in the CoaXPress
#   idle state.
# - Timing: The bench samples the reconstructed CXP word stream every cycle so
#   it checks the bridge's real shift-register latency and output ordering.

import cocotb

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_IDLE,
    CXP_IDLE_K,
    CXP_IO_ACK,
    CXP_PKT_EVENT_ACK_MSG,
    CXP_SOP,
    CXPOF_START,
    cycle,
    repeat_byte,
    reset_dut,
    start_clock,
)


def _cxp_start_word(packet_byte: int) -> int:
    return CXPOF_START | (0x80 << 8) | ((CXP_SOP & 0xFF) << 16) | (packet_byte << 24)


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_decode_test(dut):
    # Hold the bridge in its XGMII idle state until reset completes, then feed
    # one packetized CXP frame followed by a separate IO-ack indication.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []

    async def drive(rxd: int, rxc: int) -> None:
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        sample = (int(dut.rxData.value), int(dut.rxDataK.value))
        if sample != (CXP_IDLE, CXP_IDLE_K):
            observed.append(sample)

    # Low-speed packet carrying a CoaXPress event-ack message byte followed by
    # one 32-bit payload word and an EOP terminator.
    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK_MSG), 0x1)
    await drive(0x11223344, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    # Separate IO_ACK indication with no terminal payload word emitted.
    dut.xgmiiRxd.value = CXPOF_START | (0x80 << 8) | ((CXP_IO_ACK & 0xFF) << 16)
    dut.xgmiiRxc.value = 0x1
    await cycle(dut.clk, 1)
    sample = (int(dut.rxData.value), int(dut.rxDataK.value))
    if sample != (CXP_IDLE, CXP_IDLE_K):
        observed.append(sample)
    await drive(0x07FD0000, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert observed == [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK_MSG), 0x0),
        (0x11223344, 0x0),
        (CXP_EOP, 0xF),
        (CXP_IO_ACK, 0xF),
    ]


def test_CoaXPressOverFiberBridgeRx():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressoverfiberbridgerx",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressOverFiberBridgeRx.vhd",
            ]
        },
    )
