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
# - Sweep: Exercise the event-acknowledgment serializer directly with two event tags so
#   the bench checks both the initial transfer and a second post-idle retry.
# - Stimulus: Pulse `eventAck`, hold `TREADY` low across the first serialized
#   byte to create backpressure, then release the sink and repeat with a second
#   tag while the sink stays ready.
# - Checks: The DUT must serialize the CoaXPress event-acknowledgment message as
#   `SOP`, type `0x08`, repeated event tag, and `EOP`, preserve the K/data
#   classification on each byte, assert `TLAST` only on the final byte, and
#   hold the stalled first byte stable under backpressure.
# - Timing: The bench samples the byte output cycle-by-cycle and records only
#   accepted handshakes once `TREADY` is asserted.

import cocotb
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_PKT_EVENT_ACK,
    CXP_SOP,
    cycle,
    repeat_byte,
    reset_dut,
    start_clock,
    word_to_bytes,
)


def _expected_event_ack_bytes(tag: int) -> list[tuple[int, int, int]]:
    expected: list[tuple[int, int, int]] = []
    for word, is_k in (
        (CXP_SOP, 1),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0),
        (repeat_byte(tag), 0),
        (CXP_EOP, 1),
    ):
        for byte in word_to_bytes(word):
            expected.append((byte, is_k, 0))
    expected[-1] = (expected[-1][0], expected[-1][1], 1)
    return expected


async def _pulse_event_ack(dut, tag: int) -> None:
    dut.eventTag.value = tag
    dut.eventAck.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.eventAck.value = 0


async def _collect_handshakes(dut, *, count: int, timeout_cycles: int) -> list[tuple[int, int, int]]:
    observed: list[tuple[int, int, int]] = []
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        if int(dut.eventAckTValid.value) == 1 and int(dut.eventAckTReady.value) == 1:
            observed.append(
                (
                    int(dut.eventAckTData.value),
                    int(dut.eventAckTK.value),
                    int(dut.eventAckTLast.value),
                )
            )
            if len(observed) == count:
                return observed
    raise AssertionError(f"Timed out waiting for {count} accepted bytes, saw {len(observed)}")


@cocotb.test()
async def coaxpress_event_ack_msg_serialize_and_backpressure_test(dut):
    # Bring the serializer into a known idle state before driving any pulses.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.eventAck.setimmediatevalue(0)
    dut.eventTag.setimmediatevalue(0)
    dut.eventAckTReady.setimmediatevalue(0)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    # Create one event-acknowledgment request while the sink is stalled so the first byte
    # must remain stable until `TREADY` is released.
    await _pulse_event_ack(dut, 0x5A)

    stalled_byte = None
    for _ in range(8):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        if int(dut.eventAckTValid.value) == 1:
            sample = (
                int(dut.eventAckTData.value),
                int(dut.eventAckTK.value),
                int(dut.eventAckTLast.value),
            )
            if stalled_byte is None:
                stalled_byte = sample
            else:
                assert sample == stalled_byte
            break
    assert stalled_byte == (word_to_bytes(CXP_SOP)[0], 1, 0)

    for _ in range(2):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        assert (
            int(dut.eventAckTData.value),
            int(dut.eventAckTK.value),
            int(dut.eventAckTLast.value),
        ) == stalled_byte

    # Release the sink and collect the full serialized message on accepted
    # handshakes only.
    dut.eventAckTReady.value = 1
    first_transfer = await _collect_handshakes(dut, count=16, timeout_cycles=40)
    assert first_transfer[0] == stalled_byte

    # A second idle-to-active transition should emit the next tag cleanly.
    await cycle(dut.clk, 4)
    await _pulse_event_ack(dut, 0xA5)
    second_transfer = await _collect_handshakes(dut, count=16, timeout_cycles=40)

    assert first_transfer == _expected_event_ack_bytes(0x5A)
    assert second_transfer == _expected_event_ack_bytes(0xA5)


def test_CoaXPressEventAckMsg():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpresseventackmsgwrapper",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressEventAckMsg.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressEventAckMsgWrapper.vhd",
            ]
        },
    )
