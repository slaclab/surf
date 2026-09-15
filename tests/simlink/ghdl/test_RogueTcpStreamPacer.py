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
# - Sweep: Bypass, integer and fractional rates, sparse TKEEP, and downstream
#   backpressure with one-beat credit saturation.
# - Stimulus: Drive deterministic AXI Stream beats into the flattened pacer and
#   select the configured clock/rate/width through VHDL generics.
# - Checks: Record exact handshake cycles, verify payload/sideband pass-through,
#   and compare the schedule with the pinned reference-model expectations.
# - Timing: All expectations are expressed in axisClk cycles. No ZeroMQ worker,
#   operating-system timing, or Rogue process participates in these tests.

import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
import pytest

from tests.common.regression_utils import run_surf_vhdl_test


CLK_PERIOD_NS = 10

CASES = {
    "bypass": {
        "data_bytes": 8,
        "clock_hz": 100,
        "rate_bps": 0,
        "keeps": [0xFF, 0xFF, 0xFF],
        "cycles": [1, 2, 3],
        "stall_cycles": 0,
        "tkeep_count": False,
    },
    "half_rate": {
        "data_bytes": 8,
        "clock_hz": 100,
        "rate_bps": 3_200,
        "keeps": [0xFF, 0xFF, 0xFF],
        "cycles": [1, 3, 5],
        "stall_cycles": 0,
        "tkeep_count": False,
    },
    "fractional": {
        "data_bytes": 3,
        "clock_hz": 10,
        "rate_bps": 120,
        "keeps": [0x7, 0x7, 0x7],
        "cycles": [1, 3, 5],
        "stall_cycles": 0,
        "tkeep_count": False,
    },
    "sparse_keep": {
        "data_bytes": 8,
        "clock_hz": 100,
        "rate_bps": 800,
        "keeps": [0xFF, 0x81, 0x01],
        "cycles": [1, 3, 4],
        "stall_cycles": 0,
        "tkeep_count": False,
    },
    "tkeep_count": {
        "data_bytes": 8,
        "clock_hz": 100,
        "rate_bps": 3_200,
        "keeps": [8, 8, 8],
        "cycles": [1, 3, 5],
        "stall_cycles": 0,
        "tkeep_count": True,
    },
    "backpressure": {
        "data_bytes": 8,
        "clock_hz": 100,
        "rate_bps": 3_200,
        "keeps": [0xFF, 0xFF],
        "cycles": [11, 13],
        "stall_cycles": 10,
        "tkeep_count": False,
    },
}


async def _drive_beats(dut, keeps, stall_cycles):
    transfers = []
    cycle = 0
    payload = int.from_bytes(bytes(range(len(dut.S_AXIS_TDATA) // 8)), "little")

    dut.S_AXIS_TVALID.value = 1
    dut.S_AXIS_TDATA.value = payload
    dut.S_AXIS_TKEEP.value = keeps[0]
    dut.S_AXIS_TLAST.value = int(len(keeps) == 1)
    dut.M_AXIS_TREADY.value = int(stall_cycles == 0)

    index = 0
    while index < len(keeps):
        await RisingEdge(dut.axisClk)
        cycle += 1

        if cycle == stall_cycles:
            await Timer(1, unit="ps")
            dut.M_AXIS_TREADY.value = 1

        if int(dut.S_AXIS_TREADY.value) == 1:
            transfers.append(cycle)
            assert int(dut.M_AXIS_TVALID.value) == 1
            assert int(dut.M_AXIS_TDATA.value) == payload
            assert int(dut.M_AXIS_TKEEP.value) == keeps[index]
            assert int(dut.M_AXIS_TLAST.value) == int(index == len(keeps)-1)

            index += 1
            await Timer(1, unit="ps")
            if index < len(keeps):
                dut.S_AXIS_TKEEP.value = keeps[index]
                dut.S_AXIS_TLAST.value = int(index == len(keeps)-1)

    dut.S_AXIS_TVALID.value = 0
    return transfers


@cocotb.test()
async def pacer_exact_cycle_test(dut):
    case = CASES[os.environ["PACER_CASE"]]
    cocotb.start_soon(Clock(dut.axisClk, CLK_PERIOD_NS, unit="ns").start())

    dut.axisRst.value = 1
    dut.S_AXIS_TVALID.value = 0
    dut.S_AXIS_TDATA.value = 0
    dut.S_AXIS_TKEEP.value = 0
    dut.S_AXIS_TLAST.value = 0
    dut.M_AXIS_TREADY.value = 0

    for _ in range(2):
        await RisingEdge(dut.axisClk)
    dut.axisRst.value = 0
    await Timer(1, unit="ps")

    transfers = await with_timeout(
        _drive_beats(
            dut,
            case["keeps"],
            case["stall_cycles"],
        ),
        10,
        "us",
    )
    assert transfers == case["cycles"]


@pytest.mark.parametrize("case_name", CASES)
def test_RogueTcpStreamPacer(case_name):
    case = CASES[case_name]
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.roguetcpstreampacerflatharness",
        parameters={
            "DATA_BYTES_G": case["data_bytes"],
            "AXIS_CLK_FREQ_HZ_G": case["clock_hz"],
            "PAYLOAD_RATE_BPS_G": case["rate_bps"],
            "TKEEP_COUNT_G": case["tkeep_count"],
        },
        extra_env={"PACER_CASE": case_name},
        extra_vhdl_sources={
            "surf": ["simlink/test/common/RogueTcpStreamPacerFlatHarness.vhd"],
        },
    )


def test_RogueTcpStreamPacer_rejects_rate_above_interface_ceiling():
    with pytest.raises(SystemExit):
        run_surf_vhdl_test(
            test_file=__file__,
            toplevel="surf.roguetcpstreampacerflatharness",
            parameters={
                "DATA_BYTES_G": 8,
                "AXIS_CLK_FREQ_HZ_G": 100,
                "PAYLOAD_RATE_BPS_G": 6_401,
            },
            extra_env={"PACER_CASE": "bypass"},
            extra_vhdl_sources={
                "surf": ["simlink/test/common/RogueTcpStreamPacerFlatHarness.vhd"],
            },
        )
