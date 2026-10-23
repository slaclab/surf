##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the terms
## contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Exercise per-lane/per-bank static skew and bounded deterministic
#   jitter in both source-synchronous AD9249 output banks.
# - Stimulus: Serialize transition-rich normal samples after the 16-clock
#   conversion pipeline; skew data lane 0 and FCO bank 0 relative to bank 1.
# - Checks: DCO remains ideal, skew is preserved, jitter alternates around each
#   nominal transition cadence, and every differential output remains binary.
# - Timing: Bias/jitter are 50 ps, data skew is 100 ps, and FCO skew is 150 ps.

import cocotb
from cocotb.triggers import Edge, Timer
from cocotb.utils import get_sim_time

from tests.common.regression_utils import cancel_and_join_tasks, run_surf_vhdl_test


async def differential_clock(dut, period_ns=24):
    """Lifetime agent: drive the encode clock until the owning test cancels it."""
    half = period_ns / 2
    while True:
        dut.clkP.value = 0
        dut.clkN.value = 1
        await Timer(half, unit="ns")
        dut.clkP.value = 1
        dut.clkN.value = 0
        await Timer(half, unit="ns")


async def collect_bit_edges(signal, bit, count):
    previous = (int(signal.value) >> bit) & 1
    edges = []
    while len(edges) < count:
        await Edge(signal)
        current = (int(signal.value) >> bit) & 1
        if current != previous:
            edges.append(int(get_sim_time(unit="ps")))
            previous = current
    return edges


def intervals(edges):
    return [current-previous for previous, current in zip(edges, edges[1:])]


def setup_times(edges, dco_edges):
    return [next(dco-edge for dco in dco_edges if dco > edge) for edge in edges]


def contains_near(values, expected, tolerance=2):
    return any(abs(value-expected) <= tolerance for value in values)


@cocotb.test()
async def ad9249_binary_skew_and_jitter_test(dut):
    dut.normalData.value = sum(0x2AAA << (16*channel) for channel in range(16))
    dut.sclk.value = 0
    dut.sdioDrive.value = 0
    dut.sdioEnable.value = 0
    dut.csb.value = 0b11
    clock_task = cocotb.start_soon(differential_clock(dut))

    await Timer(480, unit="ns")

    lane0_task = cocotb.start_soon(collect_bit_edges(dut.dP, 0, 16))
    lane1_task = cocotb.start_soon(collect_bit_edges(dut.dP, 1, 16))
    fco0_task = cocotb.start_soon(collect_bit_edges(dut.fcoP, 0, 6))
    fco1_task = cocotb.start_soon(collect_bit_edges(dut.fcoP, 1, 6))
    # Include a DCO edge after the last, much slower FCO transition so every
    # measured source edge has a following sampling edge for setup calculation.
    dco_task = cocotb.start_soon(collect_bit_edges(dut.dcoP, 0, 48))

    lane0_edges = await lane0_task
    lane1_edges = await lane1_task
    fco0_edges = await fco0_task
    fco1_edges = await fco1_task
    dco_edges = await dco_task

    assert all(abs((a-b)-100) <= 1 for a, b in zip(lane0_edges, lane1_edges))
    assert all(abs((a-b)-150) <= 1 for a, b in zip(fco0_edges, fco1_edges))
    assert all(abs(interval-1714) <= 1 for interval in intervals(dco_edges))

    data_setup = setup_times(lane1_edges, dco_edges)
    assert contains_near(data_setup, 807)
    assert contains_near(data_setup, 907)
    assert contains_near(intervals(lane1_edges), 1614)
    assert contains_near(intervals(lane1_edges), 1814)
    assert contains_near(intervals(fco1_edges), 11900)
    assert contains_near(intervals(fco1_edges), 12100)

    assert dut.dP.value.is_resolvable
    assert dut.dN.value.is_resolvable
    assert dut.dcoP.value.is_resolvable
    assert dut.dcoN.value.is_resolvable
    assert dut.fcoP.value.is_resolvable
    assert dut.fcoN.value.is_resolvable
    assert int(dut.dN.value) == ((~int(dut.dP.value)) & 0xFFFF)
    assert int(dut.dcoN.value) == ((~int(dut.dcoP.value)) & 0x3)
    assert int(dut.fcoN.value) == ((~int(dut.fcoP.value)) & 0x3)
    await cancel_and_join_tasks((clock_task,))


def test_Ad9249SimTiming():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ad9249simwrapper",
        parameters={
            "DATA_LANE0_SKEW_PS_G": 100,
            "FCO_LANE0_SKEW_PS_G": 150,
            "JITTER_PS_G": 50,
            "TIMING_BIAS_PS_G": 50,
        },
        extra_vhdl_sources={
            "surf": [
                "devices/AnalogDevices/general/rtl/AdiConfigSlave.vhd",
                "devices/AnalogDevices/adcDdr/sim/AdcDdrPatternPkg.vhd",
                "devices/AnalogDevices/ad9249/sim/Ad9249SimCore.vhd",
                "devices/AnalogDevices/ad9249/sim/Ad9249Sim.vhd",
                "devices/AnalogDevices/ad9249/wrappers/Ad9249SimWrapper.vhd",
            ],
        },
    )
