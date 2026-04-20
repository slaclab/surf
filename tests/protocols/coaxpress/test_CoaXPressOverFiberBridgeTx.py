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
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
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
            await RisingEdge(dut.clk)
            await Timer(1, unit="ns")
            observed.append((int(dut.xgmiiTxd.value), int(dut.xgmiiTxc.value)))

    capture = cocotb.start_soon(capture_words(20))

    dut.txLsData.value = 0xA5
    dut.txLsDataK.value = 0
    dut.txLsValid.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.txLsValid.value = 0

    await cycle(dut.clk, 6)

    dut.txLsRate.value = 0
    dut.txLsData.value = 0x5C
    dut.txLsDataK.value = 1
    dut.txLsValid.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
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
