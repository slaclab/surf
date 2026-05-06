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
#   transmit and receive halves, including RX packet decode, HKP/data mixing,
#   lane-0 `/Q/` no-output behavior, and `/E/` abort/recovery, so the
#   surrounding async gearboxes are covered, not only the inner 32-bit leaves.
# - Stimulus: Inject one low-speed transmit byte on the 312 MHz CXP side and,
#   separately, inject packetized, housekeeping, sequence, and error-bearing
#   64-bit XGMII receive sequences on the 156 MHz fiber side.
# - Checks: The bridge must pack the inner 32-bit TX sequence into the
#   expected two 64-bit XGMII words and must unpack the RX 64-bit XGMII words
#   back into the expected CoaXPress `SOP`, packet-type, payload, HKP, and
#   `EOP` words while suppressing unsupported `/Q/` and aborted `/E/` traffic.
# - Timing: The bench samples both sides on their native clocks and searches
#   the resulting streams for the expected ordered windows, which keeps the
#   checks robust to gearbox latency while still validating real output order.

import cocotb
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_IDLE,
    CXP_IDLE_K,
    CXP_PKT_EVENT_ACK,
    CXP_SOP,
    CXPOF_ERROR,
    CXPOF_IDLE,
    CXPOF_SEQ,
    CXPOF_START,
    CXPOF_TERM,
    cycle,
    find_subsequence,
    reset_signals,
    repeat_byte,
    set_initial_values,
    start_clock,
)


def _tx_start_word(rate: int, update: int) -> int:
    return CXPOF_START | (((update << 3) | (rate << 1)) << 8)


def _rx_start_word(packet_byte: int) -> int:
    return CXPOF_START | (0x80 << 8) | ((CXP_SOP & 0xFF) << 16) | (packet_byte << 24)


def _rx_hkp_start_word() -> int:
    return CXPOF_START | (0x81 << 8)


def _idle64() -> int:
    return int.from_bytes(bytes([CXPOF_IDLE] * 8), "little")


async def _setup_bridge(dut) -> None:
    # Keep all four bridge clocks running so both async gearboxes are in a
    # realistic environment even when a test only stimulates the RX side.
    start_clock(dut.txClk312, period_ns=4.0)
    start_clock(dut.txClk156, period_ns=8.0)
    start_clock(dut.rxClk312, period_ns=4.0)
    start_clock(dut.rxClk156, period_ns=8.0)

    set_initial_values(
        dut,
        {
            "txLsValid": 0,
            "txLsData": 0,
            "txLsDataK": 0,
            "txLsLaneEn": 0xF,
            "txLsRate": 1,
            "xgmiiRxd": _idle64(),
            "xgmiiRxc": 0xFF,
        },
    )
    await reset_signals(
        dut,
        clk=dut.txClk312,
        reset_names=("txRst312", "rxRst312"),
        assert_cycles=10,
        release_cycles=5,
    )
    await cycle(dut.txClk312, 6)
    await cycle(dut.rxClk156, 2)


async def _drive_rx64(dut, rxd: int, rxc: int) -> None:
    dut.xgmiiRxd.value = rxd
    dut.xgmiiRxc.value = rxc
    await RisingEdge(dut.rxClk156)
    await Timer(1, unit="ns")


async def _capture_rx_words(dut, *, cycles: int) -> list[tuple[int, int]]:
    observed: list[tuple[int, int]] = []
    for _ in range(cycles):
        await RisingEdge(dut.rxClk312)
        await Timer(1, unit="ns")
        sample = (int(dut.rxData.value), int(dut.rxDataK.value))
        if sample != (CXP_IDLE, CXP_IDLE_K):
            observed.append(sample)
    return observed


@cocotb.test()
async def coaxpress_over_fiber_bridge_top_level_integration_test(dut):
    # Run the 312 MHz and 156 MHz domains at a 2:1 ratio so the async gearboxes
    # see the intended width-conversion cadence while still operating on
    # independent clocks.
    await _setup_bridge(dut)

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
    await _drive_rx64(dut, _rx_start_word(CXP_PKT_EVENT_ACK) | (0x11223344 << 32), 0x01)
    await _drive_rx64(dut, 0x07FD00FD | (repeat_byte(CXPOF_IDLE) << 32), 0xFC)
    await _drive_rx64(dut, _idle64(), 0xFF)

    await tx_capture
    await rx_capture

    tx_expected = [
        ((_tx_start_word(rate=1, update=1) | (0xA501A501 << 32)), 0x01),
        ((0xA501A501 | (((CXPOF_IDLE << 24) | (CXPOF_TERM << 16)) << 32)), 0xC0),
    ]
    rx_expected = [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x11223344, 0x0),
        (CXP_EOP, 0xF),
    ]

    assert find_subsequence(tx_observed, tx_expected) is not None, (
        f"missing TX gearbox sequence in observed stream: {tx_observed}"
    )
    assert find_subsequence(rx_observed, rx_expected) is not None, (
        f"missing RX gearbox sequence in observed stream: {rx_observed}"
    )


@cocotb.test()
async def coaxpress_over_fiber_bridge_top_rx_error_abort_and_recovery_test(dut):
    await _setup_bridge(dut)

    rx_capture = cocotb.start_soon(_capture_rx_words(dut, cycles=64))

    # Start a valid low-speed packet, then inject `/E/` as the next 32-bit word.
    # The first packet must not receive a synthetic CXP EOP.
    await _drive_rx64(dut, _rx_start_word(CXP_PKT_EVENT_ACK) | (0x11223344 << 32), 0x01)
    await _drive_rx64(
        dut,
        CXPOF_ERROR
        | (CXPOF_IDLE << 8)
        | (CXPOF_IDLE << 16)
        | (CXPOF_IDLE << 24)
        | (_idle64() & 0xFFFFFFFF00000000),
        0xF1,
    )
    await _drive_rx64(dut, _idle64(), 0xFF)

    # A later clean packet must still cross the 64b-to-32b gearbox and decode.
    await _drive_rx64(dut, _rx_start_word(CXP_PKT_EVENT_ACK) | (0x55667788 << 32), 0x01)
    await _drive_rx64(dut, 0x07FD00FD | (repeat_byte(CXPOF_IDLE) << 32), 0xFC)
    await _drive_rx64(dut, _idle64(), 0xFF)

    rx_observed = await rx_capture
    rx_expected = [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x11223344, 0x0),
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x55667788, 0x0),
        (CXP_EOP, 0xF),
    ]
    assert find_subsequence(rx_observed, rx_expected) is not None, (
        f"missing RX /E/ recovery sequence: {rx_observed}"
    )


@cocotb.test()
async def coaxpress_over_fiber_bridge_top_rx_hkp_then_payload_mix_test(dut):
    await _setup_bridge(dut)

    rx_capture = cocotb.start_soon(_capture_rx_words(dut, cycles=48))

    hkp_word = 0x9C5C3CBC
    await _drive_rx64(dut, _rx_hkp_start_word() | (hkp_word << 32), 0xF1)
    await _drive_rx64(dut, 0x10203040 | (0x07FD00FD << 32), 0xC0)
    await _drive_rx64(dut, _idle64(), 0xFF)

    rx_observed = await rx_capture
    rx_expected = [
        (hkp_word, 0xF),
        (0x10203040, 0x0),
        (CXP_EOP, 0xF),
    ]
    assert find_subsequence(rx_observed, rx_expected) is not None, f"missing RX HKP/data sequence: {rx_observed}"


@cocotb.test()
async def coaxpress_over_fiber_bridge_top_rx_sequence_no_output_recovery_test(dut):
    await _setup_bridge(dut)

    rx_capture = cocotb.start_soon(_capture_rx_words(dut, cycles=64))

    # Lane-0 `/Q/` is not decoded into a CXP word by the current RX bridge. The
    # top-level gearbox should preserve that no-output guardrail and allow a
    # later valid low-speed packet to recover.
    await _drive_rx64(
        dut,
        (CXPOF_SEQ | (0x12 << 16) | (0x34 << 24)) | (_idle64() & 0xFFFFFFFF00000000),
        0xF1,
    )
    await _drive_rx64(dut, _idle64(), 0xFF)

    await _drive_rx64(dut, _rx_start_word(CXP_PKT_EVENT_ACK) | (0xA1B2C3D4 << 32), 0x01)
    await _drive_rx64(dut, 0x07FD00FD | (repeat_byte(CXPOF_IDLE) << 32), 0xFC)
    await _drive_rx64(dut, _idle64(), 0xFF)

    rx_observed = await rx_capture
    rx_expected = [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0xA1B2C3D4, 0x0),
        (CXP_EOP, 0xF),
    ]
    assert rx_observed == rx_expected


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
