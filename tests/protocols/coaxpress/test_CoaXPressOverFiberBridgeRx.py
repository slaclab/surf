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
# - Sweep: Exercise bridge RX low-speed packet decode, `IO_ACK`, HKP forwarding,
#   HKP-to-payload transition, misplaced control-character guardrails, `/Q/`
#   no-output behavior, `/E/` abort behavior, and recovery to a later packet.
# - Stimulus: Drive CXPoF start/payload/terminate sequences, housekeeping start
#   words, lane-misplaced `/S/`, `/Q/`, `/T/`, and `/E/` controls, lane-0 `/Q/`,
#   and an explicit `/E/` during an active low-speed packet.
# - Checks: The bridge must reconstruct repeated-byte `SOP`, packet-type,
#   payload, and `EOP` words for valid packets, emit standalone `IO_ACK`, forward
#   raw HKP words, suppress malformed control traffic, and recover cleanly.
# - Timing: The bench samples the reconstructed CXP word stream every cycle so
#   it checks the bridge's real shift-register latency and output ordering.

import cocotb

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_IDLE,
    CXP_IDLE_K,
    CXP_IO_ACK,
    CXP_PKT_EVENT_ACK,
    CXP_SOP,
    CXPOF_ERROR,
    CXPOF_IDLE,
    CXPOF_SEQ,
    CXPOF_START,
    CXPOF_TERM,
    cycle,
    repeat_byte,
    reset_dut,
    start_clock,
)


def _cxp_start_word(packet_byte: int) -> int:
    return CXPOF_START | (0x80 << 8) | ((CXP_SOP & 0xFF) << 16) | (packet_byte << 24)


def _control_in_lane(control_byte: int, lane: int) -> int:
    shift = 8 * lane
    return (0x07070707 & ~(0xFF << shift)) | ((control_byte & 0xFF) << shift)


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

    # Low-speed packet carrying a CoaXPress event-acknowledgment byte followed by
    # one 32-bit payload word and an EOP terminator.
    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
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
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x11223344, 0x0),
        (CXP_EOP, 0xF),
        (CXP_IO_ACK, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_hkp_and_invalid_control_test(dut):
    # Keep the bridge idle through malformed lane placement for /S/ and /Q/,
    # then verify the HKP path emits raw K-coded words and recovers to normal
    # packet decode afterward.
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

    await drive(0x0707FB07, 0x2)
    await drive(0x07079C07, 0x2)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    await drive(CXPOF_START | (0x81 << 8), 0x1)
    await drive(0x5C5C5C5C, 0xF)
    await drive(CXP_EOP, 0xF)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x55667788, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert observed == [
        (0x5C5C5C5C, 0xF),
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x55667788, 0x0),
        (CXP_EOP, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_sequence_error_and_recovery_test(dut):
    # The current bridge RX does not implement a normative /Q/ ordered-set path;
    # lock it down as a no-output guardrail, then prove an explicit /E/ in a
    # payload aborts the packet without emitting a synthetic CXP EOP and the next
    # packet still decodes cleanly.
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

    await drive(CXPOF_SEQ | (0x00 << 8) | (0x12 << 16) | (0x34 << 24), 0x1)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x11223344, 0x0)
    await drive(CXPOF_ERROR | (CXPOF_IDLE << 8) | (CXPOF_IDLE << 16) | (CXPOF_IDLE << 24), 0x1)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x55667788, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert observed == [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x11223344, 0x0),
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x55667788, 0x0),
        (CXP_EOP, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_hkp_then_payload_mix_test(dut):
    # A housekeeping start word may be followed by one raw K-coded HKP word and
    # then normal data/EOP handling. This locks down the current RTL contract for
    # the HKP-to-payload transition without claiming full housekeeping semantics.
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

    hkp_word = 0x9C5C3CBC
    await drive(CXPOF_START | (0x81 << 8), 0x1)
    await drive(hkp_word, 0xF)
    await drive(0x10203040, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert observed == [
        (hkp_word, 0xF),
        (0x10203040, 0x0),
        (CXP_EOP, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_control_lane_guardrail_sweep_test(dut):
    # `/S/`, `/Q/`, `/T/`, and `/E/` are lane-sensitive XGMII control bytes.
    # Misplaced control bytes should not leak any CoaXPress words, and a later
    # valid low-speed packet must still decode.
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

    for control_byte in (CXPOF_START, CXPOF_SEQ, CXPOF_ERROR):
        for lane in (1, 2, 3):
            await drive(_control_in_lane(control_byte, lane), 1 << lane)
            await drive(0x07070707, 0xF)

    # `/T/` outside an active packet is also malformed for this bridge input. It
    # is swept separately because lane 2 is valid only as part of a terminate
    # word once a payload is already active.
    for lane in (0, 1, 2, 3):
        await drive(_control_in_lane(CXPOF_TERM, lane), 1 << lane)
        await drive(0x07070707, 0xF)

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0xA1B2C3D4, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert observed == [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0xA1B2C3D4, 0x0),
        (CXP_EOP, 0xF),
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
