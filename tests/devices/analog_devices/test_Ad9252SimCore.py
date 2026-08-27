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
# - Sweep: Exercise AD9252 defaults, channel indexing, buffered transfer,
#   user patterns, PN9, inversion, bit order, and channel power controls.
# - Stimulus: Write the logical register interface and issue device-update
#   transfers while sampling eight independent normal input words.
# - Checks: Reads expose identity/defaults, writes have no effect before
#   transfer, selected channels update together, PN resets hold/release, and
#   unselected channels do not change.
# - Timing: Register writes and each output sample occur on the sample clock.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test


async def write(dut, addr, data):
    """Propagation sampling: deassert writes after registered TPD updates."""
    await FallingEdge(dut.sampleClk)
    dut.cfgAddr.value = addr
    dut.cfgWrData.value = data
    dut.cfgWrEn.value = 1
    await RisingEdge(dut.sampleClk)
    await Timer(2, unit="ns")
    dut.cfgWrEn.value = 0


async def read(dut, addr):
    dut.cfgAddr.value = addr
    await Timer(1, unit="ns")
    return int(dut.cfgRdData.value)


async def sample(dut):
    """Propagation sampling: read each registered sample after its TPD update."""
    await FallingEdge(dut.sampleClk)
    dut.sampleEnable.value = 1
    await RisingEdge(dut.sampleClk)
    await Timer(2, unit="ns")
    dut.sampleEnable.value = 0
    return int(dut.sampleData.value)


def channel(data, index):
    return (data >> (16 * index)) & 0xFFFF


def pn_word(state, order=9, tap=5, width=14):
    word = 0
    for _ in range(width):
        word = (word << 1) | ((state >> (order - 1)) & 1)
        state = ((state << 1) & ((1 << order) - 1)) | (((state >> (order - 1)) ^ (state >> (tap - 1))) & 1)
    return word


def pn_advance(state, order=9, tap=5, width=14):
    for _ in range(width):
        state = ((state << 1) & ((1 << order) - 1)) | (((state >> (order - 1)) ^ (state >> (tap - 1))) & 1)
    return state


@cocotb.test()
async def ad9252_register_and_pattern_test(dut):
    dut.sampleRst.value = 1
    dut.sampleEnable.value = 0
    dut.cfgWrEn.value = 0
    dut.cfgAddr.value = 0
    dut.cfgWrData.value = 0
    dut.normalData.value = sum((0x100 + i) << (16 * i) for i in range(8))
    cocotb.start_soon(Clock(dut.sampleClk, 8, unit="ns").start())
    for _ in range(2):
        await RisingEdge(dut.sampleClk)
    dut.sampleRst.value = 0

    assert await read(dut, 0x01) == 0x09
    assert await read(dut, 0x02) == 0x30
    data = await sample(dut)
    assert [channel(data, i) for i in range(8)] == [0x100 + i for i in range(8)]

    # Select channels 0 and 3, stage checkerboard, and prove transfer is required.
    await write(dut, 0x05, 0x09)
    await write(dut, 0x0D, 0x04)
    data = await sample(dut)
    assert channel(data, 0) == 0x100
    await write(dut, 0xFF, 0x01)
    data = await sample(dut)
    assert channel(data, 0) == 0x2AAA
    assert channel(data, 3) == 0x2AAA
    assert channel(data, 1) == 0x101

    # User pattern updates selected channels atomically.
    await write(dut, 0x19, 0x23)
    await write(dut, 0x1A, 0x01)
    await write(dut, 0x1B, 0x56)
    await write(dut, 0x1C, 0x04)
    await write(dut, 0x0D, 0x08)
    await write(dut, 0xFF, 0x01)
    first = channel(await sample(dut), 0)
    second = channel(await sample(dut), 0)
    assert {first, second} == {0x0123, 0x0456}

    # PN23 reset is published by device update and remains asserted until a
    # second staged write/update releases the generator from its seed.
    pn23_seed = 0b01001101110000000101000
    pn23_first = pn_word(pn23_seed, order=23, tap=18)
    pn23_state_1 = pn_advance(pn23_seed, order=23, tap=18)
    pn23_state_2 = pn_advance(pn23_state_1, order=23, tap=18)
    pn23_second = pn_word(pn23_state_1, order=23, tap=18)
    pn23_third = pn_word(pn23_state_2, order=23, tap=18)
    await write(dut, 0x0D, 0x25)
    await write(dut, 0xFF, 0x01)
    assert await read(dut, 0x0D) == 0x25
    assert channel(await sample(dut), 0) == pn23_first
    assert channel(await sample(dut), 0) == pn23_first
    await write(dut, 0x0D, 0x05)
    await write(dut, 0xFF, 0x01)
    assert await read(dut, 0x0D) == 0x05
    assert channel(await sample(dut), 0) == pn23_first
    assert channel(await sample(dut), 0) == pn23_second
    # Re-publishing unchanged shadow configuration must not rewind live PN
    # state maintained independently by each selected channel.
    await write(dut, 0xFF, 0x01)
    assert channel(await sample(dut), 0) == pn23_third

    # Apply the same hold/release check to PN9 together with global inversion
    # and LSB-first bit reversal.
    await write(dut, 0x0D, 0x16)
    await write(dut, 0x14, 0x04)
    await write(dut, 0x21, 0x80)
    await write(dut, 0xFF, 0x01)
    assert await read(dut, 0x0D) == 0x16
    pn9_seed = 0b011011111
    pn9_first = int(f"{pn_word(pn9_seed):014b}"[::-1], 2) ^ 0x3FFF
    pn9_second = int(
        f"{pn_word(pn_advance(pn9_seed)):014b}"[::-1], 2) ^ 0x3FFF
    assert channel(await sample(dut), 0) == pn9_first
    assert channel(await sample(dut), 0) == pn9_first
    await write(dut, 0x0D, 0x06)
    await write(dut, 0xFF, 0x01)
    assert await read(dut, 0x0D) == 0x06
    assert channel(await sample(dut), 0) == pn9_first
    assert channel(await sample(dut), 0) == pn9_second

    # Power-down is per selected channel and leaves other channels running.
    await write(dut, 0x22, 0x01)
    await write(dut, 0xFF, 0x01)
    data = await sample(dut)
    assert channel(data, 0) == 0
    assert channel(data, 3) == 0
    normal_reversed = int(f"{0x101:014b}"[::-1], 2)
    assert channel(data, 1) == (normal_reversed ^ 0x3FFF)


def test_Ad9252SimCore():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ad9252simcorewrapper",
        extra_vhdl_sources={
            "surf": [
                "devices/AnalogDevices/adcDdr/sim/AdcDdrPatternPkg.vhd",
                "devices/AnalogDevices/ad9252/sim/Ad9252SimCore.vhd",
                "devices/AnalogDevices/ad9252/wrappers/Ad9252SimCoreWrapper.vhd",
            ],
        },
    )
