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
# - Sweep: Exercise the bridge TX on two successive packets so the bench covers
#   the first-packet update flag and a later rate-change update.
# - Stimulus: Send one all-data low-speed packet at `txLsRate=1`, then toggle
#   the low-speed rate and send one all-K-code packet.
# - Checks: The bridge must emit the CXPoF start word with the expected control
#   bits, serialize four enabled CoaXPress lanes into two XGMII payload words,
#   terminate with `/T/` and `/I/`, and reflect the changed rate/update flags
#   on the second packet.
# - Timing: The bench records each XGMII word cycle-by-cycle so it checks the
#   actual start, payload, terminate, and return-to-idle ordering.

import cocotb

from tests.common.regression_utils import sample_after_tpd

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_D21_5,
    CXP_K28_1,
    CXP_K28_5,
    CXPOF_IDLE,
    CXPOF_START,
    CXPOF_TERM,
    cycle,
    reset_dut,
    start_clock,
)


def _start_word(rate: int, update: int) -> int:
    sop_ctrl = (update << 3) | (rate << 1)
    return CXPOF_START | (sop_ctrl << 8)


IDLE_BYTES = [CXP_K28_5, CXP_K28_1, CXP_K28_1, CXP_D21_5]
IDLE_IS_K = [1, 1, 1, 0]


def _ls_slot(byte: int, is_k: int) -> int:
    return (byte << 8) | (0x02 if is_k else 0x01)


def _bridge_payload_words(byte: int, is_k: int, lane_enable: int, idle_index: int) -> list[int]:
    slots: list[int] = []
    for lane in range(4):
        if (lane_enable >> lane) & 0x1:
            slots.append(_ls_slot(byte, is_k))
        else:
            slots.append(_ls_slot(IDLE_BYTES[idle_index], IDLE_IS_K[idle_index]))
    return [slots[0] | (slots[1] << 16), slots[2] | (slots[3] << 16)]


@cocotb.test()
async def coaxpress_over_fiber_bridge_tx_packet_format_test(dut):
    # Reset into the idle state, then emit two packets with different rate and
    # K/data modes so both start-word flag combinations are exercised.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.txLsValid.setimmediatevalue(0)
    dut.txLsData.setimmediatevalue(0)
    dut.txLsDataK.setimmediatevalue(0)
    dut.txLsRate.setimmediatevalue(1)
    dut.txLsLaneEn.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []

    async def capture_words(count: int) -> None:
        while len(observed) < count:
            await sample_after_tpd(dut.clk)
            observed.append((int(dut.xgmiiTxd.value), int(dut.xgmiiTxc.value)))

    capture = cocotb.start_soon(capture_words(20))

    dut.txLsData.value = 0xA5
    dut.txLsDataK.value = 0
    dut.txLsValid.value = 1
    await sample_after_tpd(dut.clk)
    dut.txLsValid.value = 0

    await cycle(dut.clk, 6)

    dut.txLsRate.value = 0
    dut.txLsData.value = 0x5C
    dut.txLsDataK.value = 1
    dut.txLsValid.value = 1
    await sample_after_tpd(dut.clk)
    dut.txLsValid.value = 0

    await capture

    first_packet = None
    second_packet = None
    for start in range(len(observed) - 3):
        words = observed[start : start + 4]
        if words[0] == (_start_word(rate=1, update=1), 0x1):
            first_packet = words
        if words[0] == (_start_word(rate=0, update=1), 0x1):
            second_packet = words
            break

    assert first_packet is not None
    assert second_packet is not None

    assert first_packet[1:] == [
        (0xA501A501, 0x0),
        (0xA501A501, 0x0),
        ((CXPOF_IDLE << 24) | (CXPOF_TERM << 16), 0xC),
    ]
    assert second_packet[1:] == [
        (0x5C025C02, 0x0),
        (0x5C025C02, 0x0),
        ((CXPOF_IDLE << 24) | (CXPOF_TERM << 16), 0xC),
    ]

    # The bridge should fall back to all-idle words once packet emission ends.
    assert any(word == (int.from_bytes(bytes([CXPOF_IDLE] * 4), "little"), 0xF) for word in observed[-3:])


@cocotb.test()
async def coaxpress_over_fiber_bridge_tx_partial_lane_enable_test(dut):
    # Enable only lanes 0 and 2 so the unused slots are filled with CoaXPress
    # idle characters instead of extra payload copies.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.txLsValid.setimmediatevalue(0)
    dut.txLsData.setimmediatevalue(0)
    dut.txLsDataK.setimmediatevalue(0)
    dut.txLsRate.setimmediatevalue(1)
    dut.txLsLaneEn.setimmediatevalue(0x5)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []

    async def capture_words(count: int) -> None:
        while len(observed) < count:
            await sample_after_tpd(dut.clk)
            observed.append((int(dut.xgmiiTxd.value), int(dut.xgmiiTxc.value)))

    capture = cocotb.start_soon(capture_words(8))

    dut.txLsData.value = CXP_K28_1
    dut.txLsDataK.value = 1
    dut.txLsValid.value = 1
    await sample_after_tpd(dut.clk)
    dut.txLsValid.value = 0

    await capture

    partial_packet = None
    for start in range(len(observed) - 3):
        words = observed[start : start + 4]
        if words[0] == (_start_word(rate=1, update=1), 0x1):
            partial_packet = words
            break

    assert partial_packet is not None
    assert partial_packet[1:] == [
        (0xBC023C02, 0x0),
        (0xBC023C02, 0x0),
        ((CXPOF_IDLE << 24) | (CXPOF_TERM << 16), 0xC),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_tx_lane_enable_idle_rotation_test(dut):
    # Sweep each single active low-speed lane over consecutive packets. Disabled
    # lanes should be filled with the rotating CoaXPress idle sequence, and the
    # update bit should only be set on the first same-rate packet after reset.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.txLsValid.setimmediatevalue(0)
    dut.txLsData.setimmediatevalue(0)
    dut.txLsDataK.setimmediatevalue(0)
    dut.txLsRate.setimmediatevalue(1)
    dut.txLsLaneEn.setimmediatevalue(0x1)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []

    async def capture_words(count: int) -> None:
        while len(observed) < count:
            await sample_after_tpd(dut.clk)
            observed.append((int(dut.xgmiiTxd.value), int(dut.xgmiiTxc.value)))

    async def send_byte(byte: int, lane_enable: int) -> None:
        dut.txLsLaneEn.value = lane_enable
        dut.txLsData.value = byte
        dut.txLsDataK.value = 0
        dut.txLsValid.value = 1
        await sample_after_tpd(dut.clk)
        dut.txLsValid.value = 0
        await cycle(dut.clk, 4)

    capture = cocotb.start_soon(capture_words(32))
    for index, lane_enable in enumerate((0x1, 0x2, 0x4, 0x8)):
        await send_byte(0xA0 + index, lane_enable)
    await capture

    starts: list[tuple[int, list[tuple[int, int]]]] = []
    for index in range(len(observed) - 3):
        word, control = observed[index]
        if control == 0x1 and (word & 0xFF) == CXPOF_START:
            starts.append((word, observed[index : index + 4]))

    assert len(starts) >= 4, observed
    for packet_index, (start_word, packet) in enumerate(starts[:4]):
        expected_update = 1 if packet_index == 0 else 0
        expected_payload = _bridge_payload_words(
            0xA0 + packet_index,
            0,
            1 << packet_index,
            packet_index,
        )
        assert start_word == _start_word(rate=1, update=expected_update)
        assert packet[1:] == [
            (expected_payload[0], 0x0),
            (expected_payload[1], 0x0),
            ((CXPOF_IDLE << 24) | (CXPOF_TERM << 16), 0xC),
        ]


def test_CoaXPressOverFiberBridgeTx():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressoverfiberbridgetx",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressOverFiberBridgeTx.vhd",
            ]
        },
    )
