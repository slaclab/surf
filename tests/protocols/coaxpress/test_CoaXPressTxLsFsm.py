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
# - Sweep: Exercise the low-speed transmit FSM on the faster `txRate=1` path
#   so the bench can cover idle cadence, config draining, trigger pulse-width
#   handling, and trigger-drop behavior in one practical runtime.
# - Stimulus: Queue config bytes ahead of time, then pulse `txTrig` once for a
#   normal trigger transaction and again while the first trigger message is
#   still active to hit the drop guardrail.
# - Checks: The DUT must emit the CoaXPress idle byte pattern before draining
#   config bytes, maintain the expected heartbeat spacing, serialize both the
#   asserted and deasserted trigger messages with the right K/data pattern, and
#   pulse `txTrigDrop` when a second trigger edge arrives mid-message.
# - Timing: The bench records every `txStrobe` pulse with its clock-cycle index
#   so cadence and serialized ordering are checked on the real byte timeline.

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
    cycle,
    reset_dut,
    start_clock,
)


IDLE_SEQUENCE = [
    (CXP_K28_5, 1),
    (CXP_K28_1, 1),
    (CXP_K28_1, 1),
    (CXP_D21_5, 0),
]


async def _drive_cfg_bytes(dut, beats: list[tuple[int, int]]) -> None:
    dut.cfgTValid.value = 0
    dut.cfgTData.value = 0
    dut.cfgTUser.value = 0
    for data, is_k in beats:
        dut.cfgTValid.value = 1
        dut.cfgTData.value = data
        dut.cfgTUser.value = is_k
        await wait_sampled_ready(dut.cfgTReady, clk=dut.txClk)
    dut.cfgTValid.value = 0
    dut.cfgTData.value = 0
    dut.cfgTUser.value = 0


async def _collect_strobes(dut, *, count: int, timeout_cycles: int) -> list[tuple[int, int, int]]:
    observed: list[tuple[int, int, int]] = []
    for cycle_index in range(timeout_cycles):
        await RisingEdge(dut.txClk)
        await Timer(1, unit="ns")
        if int(dut.txStrobe.value) == 1:
            observed.append((cycle_index, int(dut.txData.value), int(dut.txDataK.value)))
            if len(observed) == count:
                return observed
    raise AssertionError(f"Timed out waiting for {count} strobes, saw {len(observed)}")


async def _pulse_trigger(dut) -> None:
    dut.txTrig.value = 1
    await RisingEdge(dut.txClk)
    await Timer(1, unit="ns")
    dut.txTrig.value = 0


def _trigger_window(payload: list[tuple[int, int]], *, asserted: bool, inverted: bool) -> bool:
    if len(payload) != 6:
        return False
    link_trigger0 = [(CXP_K28_2, 1), (CXP_K28_4, 1), (CXP_K28_4, 1)]
    link_trigger1 = [(CXP_K28_4, 1), (CXP_K28_2, 1), (CXP_K28_2, 1)]
    expected_prefix = link_trigger1 if asserted == inverted else link_trigger0
    return (
        payload[:3] == expected_prefix
        and payload[3][1] == payload[4][1] == payload[5][1] == 0
        and payload[3][0] == payload[4][0] == payload[5][0]
    )


@cocotb.test()
async def coaxpress_tx_ls_fsm_idle_and_config_cadence_test(dut):
    # Start from reset with config bytes already queued so the FSM proves it
    # inserts one complete idle word before draining queued traffic.
    start_clock(dut.txClk)
    dut.txRst.setimmediatevalue(1)
    dut.cfgTValid.setimmediatevalue(0)
    dut.cfgTData.setimmediatevalue(0)
    dut.cfgTUser.setimmediatevalue(0)
    dut.txTrig.setimmediatevalue(0)
    dut.txTrigInv.setimmediatevalue(0)
    dut.txPulseWidth.setimmediatevalue(500)
    dut.txRate.setimmediatevalue(1)
    await reset_dut(dut, clk_name="txClk", reset_names=("txRst",))

    cfg_task = cocotb.start_soon(_drive_cfg_bytes(dut, [(0x33, 0), (0xDC, 1)]))
    observed = await _collect_strobes(dut, count=6, timeout_cycles=600)
    await cfg_task

    assert [(data, is_k) for _, data, is_k in observed[:4]] == IDLE_SEQUENCE
    assert [(data, is_k) for _, data, is_k in observed[4:]] == [(0x33, 0), (0xDC, 1)]
    assert [observed[index + 1][0] - observed[index][0] for index in range(5)] == [75] * 5


@cocotb.test()
async def coaxpress_tx_ls_fsm_trigger_width_and_drop_test(dut):
    # Trigger immediately after reset so the next heartbeat starts the trigger
    # message, then re-trigger mid-message to check the drop guardrail.
    start_clock(dut.txClk)
    dut.txRst.setimmediatevalue(1)
    dut.cfgTValid.setimmediatevalue(0)
    dut.cfgTData.setimmediatevalue(0)
    dut.cfgTUser.setimmediatevalue(0)
    dut.txTrig.setimmediatevalue(0)
    dut.txTrigInv.setimmediatevalue(0)
    dut.txPulseWidth.setimmediatevalue(500)
    dut.txRate.setimmediatevalue(1)
    await reset_dut(dut, clk_name="txClk", reset_names=("txRst",))

    await _pulse_trigger(dut)

    async def pulse_again_mid_message() -> None:
        await cycle(dut.txClk, 200)
        await _pulse_trigger(dut)

    retrigger_task = cocotb.start_soon(pulse_again_mid_message())

    strobes: list[tuple[int, int, int]] = []
    tx_trig_drop_seen = False
    for cycle_index in range(1400):
        await RisingEdge(dut.txClk)
        await Timer(1, unit="ns")
        if int(dut.txTrigDrop.value) == 1:
            tx_trig_drop_seen = True
        if int(dut.txStrobe.value) == 1:
            strobes.append((cycle_index, int(dut.txData.value), int(dut.txDataK.value)))
            if len(strobes) >= 14 and tx_trig_drop_seen:
                break

    await retrigger_task

    first_trigger = None
    second_trigger = None
    for start in range(len(strobes) - 5):
        window = strobes[start : start + 6]
        payload = [(data, is_k) for _, data, is_k in window]
        if payload[:3] == [(CXP_K28_2, 1), (CXP_K28_4, 1), (CXP_K28_4, 1)] and payload[3][1] == payload[4][1] == payload[5][1] == 0 and payload[3][0] == payload[4][0] == payload[5][0]:
            first_trigger = payload
        if payload[:3] == [(CXP_K28_4, 1), (CXP_K28_2, 1), (CXP_K28_2, 1)] and payload[3][1] == payload[4][1] == payload[5][1] == 0 and payload[3][0] == payload[4][0] == payload[5][0]:
            second_trigger = payload
            break

    assert tx_trig_drop_seen
    assert first_trigger is not None
    assert second_trigger is not None


@cocotb.test()
async def coaxpress_tx_ls_fsm_rate0_inverted_trigger_test(dut):
    # Exercise the slower heartbeat cadence plus the inverted trigger mapping
    # the current RTL implements on the rising edge.
    start_clock(dut.txClk)
    dut.txRst.setimmediatevalue(1)
    dut.cfgTValid.setimmediatevalue(0)
    dut.cfgTData.setimmediatevalue(0)
    dut.cfgTUser.setimmediatevalue(0)
    dut.txTrig.setimmediatevalue(0)
    dut.txTrigInv.setimmediatevalue(1)
    dut.txPulseWidth.setimmediatevalue(120)
    dut.txRate.setimmediatevalue(0)
    await reset_dut(dut, clk_name="txClk", reset_names=("txRst",))

    await _pulse_trigger(dut)
    strobes = await _collect_strobes(dut, count=24, timeout_cycles=5200)

    assert [strobes[index + 1][0] - strobes[index][0] for index in range(23)] == [150] * 23
    assert [(data, is_k) for _, data, is_k in strobes[:6]] == [
        (CXP_K28_4, 1),
        (CXP_K28_2, 1),
        (CXP_K28_2, 1),
        (0x03, 0),
        (0x03, 0),
        (0x03, 0),
    ]

    assert any((data, is_k) == IDLE_SEQUENCE[0] for _, data, is_k in strobes[6:])


@cocotb.test()
async def coaxpress_tx_ls_fsm_pulse_width_update_terminates_active_trigger_test(dut):
    # Start with a long trigger pulse, then shorten txPulseWidth after the assert
    # message has completed. The RTL should force the active pulse to terminate
    # quickly instead of waiting for the original long timeout.
    start_clock(dut.txClk)
    dut.txRst.setimmediatevalue(1)
    dut.cfgTValid.setimmediatevalue(0)
    dut.cfgTData.setimmediatevalue(0)
    dut.cfgTUser.setimmediatevalue(0)
    dut.txTrig.setimmediatevalue(0)
    dut.txTrigInv.setimmediatevalue(0)
    dut.txPulseWidth.setimmediatevalue(1000)
    dut.txRate.setimmediatevalue(1)
    await reset_dut(dut, clk_name="txClk", reset_names=("txRst",))

    await _pulse_trigger(dut)

    strobes: list[tuple[int, int, int]] = []
    pulse_width_update_cycle = None
    asserted_start = None
    deasserted_start = None
    tx_trig_drop_seen = False

    for cycle_index in range(1800):
        await RisingEdge(dut.txClk)
        await Timer(1, unit="ns")
        if int(dut.txTrigDrop.value) == 1:
            tx_trig_drop_seen = True
        if int(dut.txStrobe.value) == 1:
            strobes.append((cycle_index, int(dut.txData.value), int(dut.txDataK.value)))

            for start in range(max(0, len(strobes) - 6), len(strobes) - 5):
                payload = [(data, is_k) for _, data, is_k in strobes[start : start + 6]]
                if asserted_start is None and _trigger_window(payload, asserted=True, inverted=False):
                    asserted_start = strobes[start][0]
                elif pulse_width_update_cycle is not None and _trigger_window(payload, asserted=False, inverted=False):
                    deasserted_start = strobes[start][0]
                    break

            if asserted_start is not None and pulse_width_update_cycle is None and len(strobes) >= 6:
                dut.txPulseWidth.value = 20
                pulse_width_update_cycle = cycle_index

            if deasserted_start is not None:
                break

    assert asserted_start is not None, strobes
    assert pulse_width_update_cycle is not None
    assert deasserted_start is not None, strobes
    assert deasserted_start - pulse_width_update_cycle < 200
    assert not tx_trig_drop_seen


def test_CoaXPressTxLsFsm():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpresstxlsfsmwrapper",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressTxLsFsm.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressTxLsFsmWrapper.vhd",
            ]
        },
    )
