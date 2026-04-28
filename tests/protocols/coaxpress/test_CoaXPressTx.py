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
# - Sweep: Exercise the first full CoaXPress transmit assembly in two modes:
#   config/event-acknowledgment arbitration across the cfg-to-tx clock crossing and the
#   software-trigger path into the low-speed transmit FSM.
# - Stimulus: Queue one multi-byte config packet, pulse `eventAck` while that
#   packet is active, and separately pulse only `swTrig` with `txTrig` held
#   low so the OR-combined trigger path is the only source of trigger traffic.
# - Checks: The transmitted low-speed stream must preserve the config bytes,
#   serialize the spec-defined event-acknowledgment packet without corruption, and emit
#   both trigger message polarities from a software trigger without asserting
#   `txTrigDrop`.
# - Timing: The bench records each transmitted byte at the real `txClk`
#   heartbeat cadence and searches the resulting stream for exact packet and
#   trigger windows rather than assuming zero-latency handoff across modules.

import cocotb
from cocotb.triggers import RisingEdge, Timer

from tests.axi.utils import wait_sampled_ready
from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_D21_5,
    CXP_K28_1,
    CXP_K28_2,
    CXP_K28_4,
    CXP_K28_5,
    CXP_PKT_EVENT_ACK,
    CXP_EOP,
    CXP_SOP,
    cycle,
    find_subsequence,
    set_initial_values,
    start_clock,
    word_to_bytes,
)


IDLE_SEQUENCE = [
    (CXP_K28_5, 1),
    (CXP_K28_1, 1),
    (CXP_K28_1, 1),
    (CXP_D21_5, 0),
]


async def _reset_domains(dut) -> None:
    dut.cfgRst.value = 1
    dut.txRst.value = 1
    await Timer(40, unit="ns")
    dut.cfgRst.value = 0
    dut.txRst.value = 0
    await Timer(20, unit="ns")


async def _drive_cfg_packet(dut, beats: list[tuple[int, int]]) -> None:
    dut.cfgTValid.value = 0
    dut.cfgTData.value = 0
    dut.cfgTUser.value = 0
    dut.cfgTLast.value = 0
    await RisingEdge(dut.cfgClk)
    for index, (data, is_k) in enumerate(beats):
        dut.cfgTValid.value = 1
        dut.cfgTData.value = data
        dut.cfgTUser.value = is_k
        dut.cfgTLast.value = 1 if index == len(beats) - 1 else 0
        await wait_sampled_ready(dut.cfgTReady, clk=dut.cfgClk)
    dut.cfgTValid.value = 0
    dut.cfgTData.value = 0
    dut.cfgTUser.value = 0
    dut.cfgTLast.value = 0


async def _pulse_event_ack(dut, tag: int) -> None:
    dut.eventTag.value = tag
    dut.eventAck.value = 1
    await RisingEdge(dut.cfgClk)
    await Timer(1, unit="ns")
    dut.eventAck.value = 0


async def _pulse_sw_trigger(dut) -> None:
    dut.swTrig.value = 1
    await RisingEdge(dut.txClk)
    await Timer(1, unit="ns")
    dut.swTrig.value = 0


async def _collect_tx_bytes(dut, *, count: int, timeout_cycles: int) -> tuple[list[tuple[int, int, int]], bool]:
    observed: list[tuple[int, int, int]] = []
    tx_trig_drop_seen = False
    for cycle_index in range(timeout_cycles):
        await RisingEdge(dut.txClk)
        await Timer(1, unit="ns")
        if int(dut.txTrigDrop.value) == 1:
            tx_trig_drop_seen = True
        if int(dut.txLsValid.value) == 1:
            observed.append((cycle_index, int(dut.txLsData.value), int(dut.txLsDataK.value)))
            if len(observed) >= count:
                return observed, tx_trig_drop_seen
    raise AssertionError(f"Timed out waiting for {count} CoaXPress TX bytes, saw {len(observed)}")

@cocotb.test()
async def coaxpress_tx_config_and_event_ack_test(dut):
    # Hold the assembly in reset long enough for both domains to settle, then
    # prove that a config packet already in flight is preserved ahead of a
    # later event-acknowledgment packet through the mux and CDC FIFO.
    start_clock(dut.cfgClk, period_ns=6.0)
    start_clock(dut.txClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "cfgTValid": 0,
            "cfgTData": 0,
            "cfgTUser": 0,
            "cfgTLast": 0,
            "eventAck": 0,
            "eventTag": 0,
            "txLsRate": 1,
            "txTrigInv": 0,
            "txPulseWidth": 500,
            "swTrig": 0,
            "txTrig": 0,
        },
    )
    await _reset_domains(dut)

    cfg_bytes = [(0x12, 0), (0x9C, 1), (0x55, 0)]
    event_tag = 0xA6
    cfg_driver = cocotb.start_soon(_drive_cfg_packet(dut, cfg_bytes))

    await cycle(dut.cfgClk, 4)
    await _pulse_event_ack(dut, event_tag)

    observed, tx_trig_drop_seen = await _collect_tx_bytes(dut, count=28, timeout_cycles=4000)
    await cfg_driver

    assert not tx_trig_drop_seen

    cfg_start = find_subsequence([(data, is_k) for _, data, is_k in observed], cfg_bytes)
    assert cfg_start is not None, f"config bytes not found in observed stream: {observed}"

    event_ack_bytes = [
        *[(byte, 1) for byte in word_to_bytes(CXP_SOP)],
        *[(CXP_PKT_EVENT_ACK, 0)] * 4,
        *[(event_tag, 0)] * 4,
        *[(byte, 1) for byte in word_to_bytes(CXP_EOP)],
    ]
    event_start = find_subsequence([(data, is_k) for _, data, is_k in observed], event_ack_bytes)
    assert event_start is not None, f"event-acknowledgment packet not found in observed stream: {observed}"
    idle_after_event = find_subsequence(
        [(data, is_k) for _, data, is_k in observed[event_start + len(event_ack_bytes) :]],
        IDLE_SEQUENCE,
    )
    assert cfg_start < event_start, f"unexpected config/event ordering in observed stream: {observed}"
    assert idle_after_event is not None, f"idle word not restored after event-acknowledgment packet: {observed}"


@cocotb.test()
async def coaxpress_tx_software_trigger_path_test(dut):
    # Keep the hardware trigger low and use only `swTrig` so the bench proves
    # the assembly's OR-combined software trigger path end-to-end.
    start_clock(dut.cfgClk, period_ns=6.0)
    start_clock(dut.txClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "cfgTValid": 0,
            "cfgTData": 0,
            "cfgTUser": 0,
            "cfgTLast": 0,
            "eventAck": 0,
            "eventTag": 0,
            "txLsRate": 1,
            "txTrigInv": 1,
            "txPulseWidth": 500,
            "swTrig": 0,
            "txTrig": 0,
        },
    )
    await _reset_domains(dut)

    await _pulse_sw_trigger(dut)
    await cycle(dut.txClk, 4)
    await _pulse_sw_trigger(dut)
    observed, tx_trig_drop_seen = await _collect_tx_bytes(dut, count=24, timeout_cycles=2200)

    first_trigger = None
    second_trigger = None
    for start in range(len(observed) - 5):
        window = observed[start : start + 6]
        payload = [(data, is_k) for _, data, is_k in window]
        if payload[:3] == [(CXP_K28_4, 1), (CXP_K28_2, 1), (CXP_K28_2, 1)] and payload[3][1] == payload[4][1] == payload[5][1] == 0 and payload[3][0] == payload[4][0] == payload[5][0]:
            first_trigger = payload
        if payload[:3] == [(CXP_K28_2, 1), (CXP_K28_4, 1), (CXP_K28_4, 1)] and payload[3][1] == payload[4][1] == payload[5][1] == 0 and payload[3][0] == payload[4][0] == payload[5][0]:
            second_trigger = payload
            break

    assert first_trigger is not None, f"asserted trigger window not found in observed stream: {observed}"
    assert second_trigger is not None, f"deasserted trigger window not found in observed stream: {observed}"
    assert not tx_trig_drop_seen, f"unexpected txTrigDrop in observed stream: {observed}"


def test_CoaXPressTx():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpresstxwrapper",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressEventAckMsg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressTxLsFsm.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressTx.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressTxWrapper.vhd",
            ]
        },
    )
