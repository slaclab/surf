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
# - Sweep: Exercise static per-lane/FCO transition skew together with bounded
#   deterministic jitter in the primitive-free AD9681 pin-level model.
# - Stimulus: Serialize a repeating transition-rich normal sample with a common
#   timing bias; one data lane and one FCO lane receive additional static skew.
# - Checks: DCO retains its exact period, the unskewed data/FCO setup times are
#   centered at 500 ps, paired lanes retain their programmed skew, transition
#   intervals alternate around their nominal cadence, and every differential
#   output remains binary and complementary.
# - Timing: Common bias and jitter are both 50 ps, data lane 0 adds 100 ps, and
#   FCO lane 0 adds 150 ps relative to their corresponding lane 1 outputs.

import cocotb
from cocotb.triggers import Edge, Timer
from cocotb.utils import get_sim_time

from tests.common.regression_utils import cancel_and_join_tasks, run_surf_vhdl_test


async def differential_clock(dut, period_ns=8):
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


def short_intervals(edges, maximum_ps):
    return [
        current-previous
        for previous, current in zip(edges, edges[1:])
        if current-previous < maximum_ps
    ]


def setup_times(edges, dco_edges):
    return [next(dco-edge for dco in dco_edges if dco > edge) for edge in edges]


@cocotb.test()
async def ad9681_binary_skew_and_jitter_test(dut):
    # 0x2AAA becomes 0xAAA8 on each 16-bit serialized channel, providing
    # repeated transitions in both physical byte groups without SPI setup.
    dut.normalData.value = sum(0x2AAA << (16*channel) for channel in range(8))
    dut.sclk.value = 0
    dut.sdioDrive.value = 0
    dut.sdioEnable.value = 0
    dut.csb.value = 1
    clock_task = cocotb.start_soon(differential_clock(dut))

    # Allow the modeled 16-sample ADC conversion pipeline to fill before
    # collecting data edges and their corresponding DCO sampling edges.
    await Timer(160, unit="ns")

    lane0_task = cocotb.start_soon(collect_bit_edges(dut.dP, 0, 16))
    lane1_task = cocotb.start_soon(collect_bit_edges(dut.dP, 1, 16))
    fco0_task = cocotb.start_soon(collect_bit_edges(dut.fcoP, 0, 6))
    fco1_task = cocotb.start_soon(collect_bit_edges(dut.fcoP, 1, 6))
    dco_task = cocotb.start_soon(collect_bit_edges(dut.dcoP, 0, 32))

    lane0_edges = await lane0_task
    lane1_edges = await lane1_task
    fco0_edges = await fco0_task
    fco1_edges = await fco1_task
    dco_edges = await dco_task

    assert all(a-b == 100 for a, b in zip(lane0_edges, lane1_edges))
    assert all(a-b == 150 for a, b in zip(fco0_edges, fco1_edges))
    assert all(interval == 1000 for interval in short_intervals(dco_edges, 1500))
    assert set(setup_times(lane1_edges, dco_edges)) == {450, 550}
    assert set(setup_times(fco1_edges, dco_edges)) == {450, 550}

    # Alternating -50/+50 ps displacement creates 900/1100 ps data intervals
    # and 3900/4100 ps FCO intervals around their nominal cadence.
    assert {900, 1100}.issubset(set(short_intervals(lane1_edges, 1500)))
    assert {3900, 4100}.issubset(set(short_intervals(fco1_edges, 5000)))

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


def test_Ad9681SimTiming():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ad9681simwrapper",
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
                "devices/AnalogDevices/ad9681/sim/Ad9681SimCore.vhd",
                "devices/AnalogDevices/ad9681/sim/Ad9681Sim.vhd",
                "devices/AnalogDevices/ad9681/wrappers/Ad9681SimWrapper.vhd",
            ],
        },
    )
