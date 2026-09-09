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
# - Sweep: Exercise one eight-channel AD9249 bank's defaults, device indexing,
#   immediate writes, transferred resolution/rate override, user patterns, PN9,
#   inversion, bit order, and power-down.
# - Stimulus: Write the primitive-free byte-register interface while sampling
#   independent normal words for every bank channel.
# - Checks: Identity/default readback, selected-channel isolation, pattern
#   values, PN reset hold/release, global transforms, soft reset, and
#   suppression and the staged 0x100 update are checked.
# - Timing: Configuration writes and samples share the model sample clock;
#   only the AD9249 resolution/rate override requires device update.

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
async def ad9249_bank_register_and_pattern_test(dut):
    dut.sampleRst.value = 1
    dut.sampleEnable.value = 0
    dut.cfgWrEn.value = 0
    dut.cfgAddr.value = 0
    dut.cfgWrData.value = 0
    dut.normalData.value = sum((0x200 + i) << (16 * i) for i in range(8))
    cocotb.start_soon(Clock(dut.sampleClk, 8, unit="ns").start())
    for _ in range(2):
        await RisingEdge(dut.sampleClk)
    dut.sampleRst.value = 0

    assert await read(dut, 0x01) == 0x92
    assert await read(dut, 0x02) == 0x30
    assert await read(dut, 0x04) == 0x0F
    assert await read(dut, 0x05) == 0x3F
    assert await read(dut, 0x100) == 0x00
    data = await sample(dut)
    assert [channel(data, i) for i in range(8)] == [0x200 + i for i in range(8)]

    # Register 0x100 is staged until the transfer strobe at register 0xFF.
    await write(dut, 0x100, 0x63)
    assert await read(dut, 0x100) == 0x00
    await write(dut, 0xFF, 0x01)
    assert await read(dut, 0x100) == 0x63

    # Two's-complement normal-data mode flips the 14-bit code MSB. Test
    # patterns are checked separately because their format applicability differs.
    await write(dut, 0x14, 0x01)
    data = await sample(dut)
    assert channel(data, 1) == (0x201 ^ 0x2000)
    await write(dut, 0x00, 0x04)

    # Select only channels 0 and 3. AD9249 writes become visible immediately.
    await write(dut, 0x04, 0x00)
    await write(dut, 0x05, 0x09)
    await write(dut, 0x0D, 0x04)
    data = await sample(dut)
    assert channel(data, 0) in (0x2AAA, 0x1555)
    assert channel(data, 3) == channel(data, 0)
    assert channel(data, 1) == 0x201

    await write(dut, 0x19, 0x23)
    await write(dut, 0x1A, 0x01)
    await write(dut, 0x1B, 0x56)
    await write(dut, 0x1C, 0x04)
    await write(dut, 0x0D, 0x08)
    first = channel(await sample(dut), 0)
    second = channel(await sample(dut), 0)
    assert {first, second} == {0x0123, 0x0456}

    # PN23 reset remains readable and holds the generator at its seed until
    # software clears the level.
    pn23_seed = 0b01001101110000000101000
    pn23_first = pn_word(pn23_seed, order=23, tap=18)
    pn23_second = pn_word(
        pn_advance(pn23_seed, order=23, tap=18), order=23, tap=18)
    await write(dut, 0x0D, 0x25)
    assert await read(dut, 0x0D) == 0x25
    assert channel(await sample(dut), 0) == pn23_first
    assert channel(await sample(dut), 0) == pn23_first
    await write(dut, 0x0D, 0x05)
    assert await read(dut, 0x0D) == 0x05
    assert channel(await sample(dut), 0) == pn23_first
    assert channel(await sample(dut), 0) == pn23_second

    # Apply the same hold/release check to PN9, then retain the existing global
    # output inversion and LSB-first serialization coverage.
    await write(dut, 0x0D, 0x16)
    await write(dut, 0x14, 0x04)
    await write(dut, 0x21, 0x80)
    assert await read(dut, 0x0D) == 0x16
    pn9_seed = 0b011011111
    pn9_first = int(f"{pn_word(pn9_seed):014b}"[::-1], 2) ^ 0x3FFF
    pn9_second = int(
        f"{pn_word(pn_advance(pn9_seed)):014b}"[::-1], 2) ^ 0x3FFF
    assert channel(await sample(dut), 0) == pn9_first
    assert channel(await sample(dut), 0) == pn9_first
    await write(dut, 0x0D, 0x06)
    assert await read(dut, 0x0D) == 0x06
    assert channel(await sample(dut), 0) == pn9_first
    assert channel(await sample(dut), 0) == pn9_second

    await write(dut, 0x22, 0x01)
    data = await sample(dut)
    assert channel(data, 0) == 0
    assert channel(data, 3) == 0
    normal_reversed = int(f"{0x201:014b}"[::-1], 2)
    assert channel(data, 1) == (normal_reversed ^ 0x3FFF)

    # Global power modes suppress every output bank channel.
    await write(dut, 0x08, 0x01)
    assert await sample(dut) == 0

    # Soft reset restores selection, normal data, inversion, and bit order.
    await write(dut, 0x00, 0x04)
    assert await read(dut, 0x04) == 0x0F
    assert await read(dut, 0x05) == 0x3F
    assert await read(dut, 0x100) == 0x00
    data = await sample(dut)
    assert [channel(data, i) for i in range(8)] == [0x200 + i for i in range(8)]


def test_Ad9249SimCore():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ad9249simcorewrapper",
        extra_vhdl_sources={
            "surf": [
                "devices/AnalogDevices/adcDdr/sim/AdcDdrPatternPkg.vhd",
                "devices/AnalogDevices/ad9249/sim/Ad9249SimCore.vhd",
                "devices/AnalogDevices/ad9249/wrappers/Ad9249SimCoreWrapper.vhd",
            ],
        },
    )
