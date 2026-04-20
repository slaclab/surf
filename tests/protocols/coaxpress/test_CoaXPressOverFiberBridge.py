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
# - Sweep: Exercise the top-level CoaXPress-over-Fiber bridge across both its
#   transmit and receive halves so the surrounding async gearboxes are covered,
#   not only the inner 32-bit bridge leaves.
# - Stimulus: Inject one low-speed transmit byte on the 312 MHz CXP side and,
#   separately, inject one packetized 64-bit XGMII receive sequence on the 156
#   MHz fiber side.
# - Checks: The bridge must pack the inner 32-bit TX sequence into the
#   expected two 64-bit XGMII words and must unpack the RX 64-bit XGMII words
#   back into the expected CoaXPress `SOP`, packet-type, payload, and `EOP`
#   words.
# - Timing: The bench samples both sides on their native clocks and searches
#   the resulting streams for the expected ordered windows, which keeps the
#   checks robust to gearbox latency while still validating real output order.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_IDLE,
    CXP_IDLE_K,
    CXP_PKT_EVENT_ACK_MSG,
    CXP_SOP,
    CXPOF_IDLE,
    CXPOF_START,
    CXPOF_TERM,
    cycle,
    repeat_byte,
)


def _tx_start_word(rate: int, update: int) -> int:
    return CXPOF_START | (((update << 3) | (rate << 1)) << 8)


def _rx_start_word(packet_byte: int) -> int:
    return CXPOF_START | (0x80 << 8) | ((CXP_SOP & 0xFF) << 16) | (packet_byte << 24)


def _find_subsequence(observed: list[tuple[int, int]], expected: list[tuple[int, int]]) -> int | None:
    for start in range(len(observed) - len(expected) + 1):
        if observed[start : start + len(expected)] == expected:
            return start
    return None


async def _reset_domains(dut) -> None:
    dut.txRst312.value = 1
    dut.rxRst312.value = 1
    await Timer(40, unit="ns")
    dut.txRst312.value = 0
    dut.rxRst312.value = 0
    await Timer(20, unit="ns")


@cocotb.test()
async def coaxpress_over_fiber_bridge_top_level_integration_test(dut):
    # Run the 312 MHz and 156 MHz domains at a 2:1 ratio so the async gearboxes
    # see the intended width-conversion cadence while still operating on
    # independent clocks.
    cocotb.start_soon(Clock(dut.txClk312, 4, unit="ns").start())
    cocotb.start_soon(Clock(dut.txClk156, 8, unit="ns").start())
    cocotb.start_soon(Clock(dut.rxClk312, 4, unit="ns").start())
    cocotb.start_soon(Clock(dut.rxClk156, 8, unit="ns").start())

    idle64 = int.from_bytes(bytes([CXPOF_IDLE] * 8), "little")
    dut.txLsValid.setimmediatevalue(0)
    dut.txLsData.setimmediatevalue(0)
    dut.txLsDataK.setimmediatevalue(0)
    dut.txLsLaneEn.setimmediatevalue(0xF)
    dut.txLsRate.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(idle64)
    dut.xgmiiRxc.setimmediatevalue(0xFF)
    await _reset_domains(dut)
    await cycle(dut.txClk312, 6)
    await cycle(dut.rxClk156, 2)

    tx_observed: list[tuple[int, int]] = []
    rx_observed: list[tuple[int, int]] = []

    async def capture_tx_words(cycles: int) -> None:
        for _ in range(cycles):
            await RisingEdge(dut.txClk156)
            await Timer(1, unit="ns")
            tx_observed.append((int(dut.xgmiiTxd.value), int(dut.xgmiiTxc.value)))

    async def capture_rx_words(cycles: int) -> None:
        for _ in range(cycles):
            await RisingEdge(dut.rxClk312)
            await Timer(1, unit="ns")
            sample = (int(dut.rxData.value), int(dut.rxDataK.value))
            if sample != (CXP_IDLE, CXP_IDLE_K):
                rx_observed.append(sample)

    tx_capture = cocotb.start_soon(capture_tx_words(32))
    rx_capture = cocotb.start_soon(capture_rx_words(32))

    dut.txLsData.value = 0xA5
    dut.txLsDataK.value = 0
    dut.txLsValid.value = 1
    await RisingEdge(dut.txClk312)
    await Timer(1, unit="ns")
    await RisingEdge(dut.txClk312)
    await Timer(1, unit="ns")
    dut.txLsValid.value = 0

    await cycle(dut.rxClk156, 3)
    dut.xgmiiRxd.value = (_rx_start_word(CXP_PKT_EVENT_ACK_MSG) | (0x11223344 << 32))
    dut.xgmiiRxc.value = 0x01
    await RisingEdge(dut.rxClk156)
    await Timer(1, unit="ns")
    dut.xgmiiRxd.value = (0x07FD00FD | (repeat_byte(CXPOF_IDLE) << 32))
    dut.xgmiiRxc.value = 0xFC
    await RisingEdge(dut.rxClk156)
    await Timer(1, unit="ns")
    dut.xgmiiRxd.value = idle64
    dut.xgmiiRxc.value = 0xFF

    await tx_capture
    await rx_capture

    tx_expected = [
        ((_tx_start_word(rate=1, update=1) | (0xA501A501 << 32)), 0x01),
        ((0xA501A501 | (((CXPOF_IDLE << 24) | (CXPOF_TERM << 16)) << 32)), 0xC0),
    ]
    rx_expected = [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK_MSG), 0x0),
        (0x11223344, 0x0),
        (CXP_EOP, 0xF),
    ]

    assert _find_subsequence(tx_observed, tx_expected) is not None, f"missing TX gearbox sequence in observed stream: {tx_observed}"
    assert _find_subsequence(rx_observed, rx_expected) is not None, f"missing RX gearbox sequence in observed stream: {rx_observed}"


def test_CoaXPressOverFiberBridge():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressoverfiberbridge",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressOverFiberBridgeRx.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressOverFiberBridgeTx.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressOverFiberBridge.vhd",
            ]
        },
    )
