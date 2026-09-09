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
# - Sweep: Exercise default two-lane words, the register 0x05 device index that
#   selects data channels, the staged resolution/rate override, user and PN
#   patterns, inversion, bit order, and power for all eight channels.
# - Stimulus: Write the primitive-free byte-register interface while sampling
#   independent normal codes for all eight channels.
# - Checks: Padding placement, identity, immediate ordinary-register updates,
#   device-index channel isolation, 0x100 transfer semantics, unsupported-format
#   fallback, pattern values, PN reset hold/release, transforms, soft reset, and
#   suppression are checked.
# - Timing: Configuration and samples share one clock; only the resolution/rate
#   override remains hidden until the register 0xFF transfer write.

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


def reverse_bytes(word):
    upper = int(f"{(word >> 8) & 0xFF:08b}"[::-1], 2)
    lower = int(f"{word & 0xFF:08b}"[::-1], 2)
    return (upper << 8) | lower


@cocotb.test()
async def ad9681_register_index_and_pattern_test(dut):
    normal = [0x200 + i for i in range(8)]
    dut.sampleRst.value = 1
    dut.sampleEnable.value = 0
    dut.cfgWrEn.value = 0
    dut.cfgAddr.value = 0
    dut.cfgWrData.value = 0
    dut.normalData.value = sum(value << (16 * i) for i, value in enumerate(normal))
    cocotb.start_soon(Clock(dut.sampleClk, 8, unit="ns").start())
    for _ in range(2):
        await RisingEdge(dut.sampleClk)
    dut.sampleRst.value = 0

    # Identity and defaults. Register 0x05 powers up at 0x3F so every data and
    # clock channel receives the next write.
    assert await read(dut, 0x01) == 0x8F
    assert await read(dut, 0x02) == 0x60
    assert await read(dut, 0x05) == 0x3F
    assert await read(dut, 0x100) == 0x00
    data = await sample(dut)
    assert [channel(data, i) for i in range(8)] == [value << 2 for value in normal]
    assert all((channel(data, i) & 0x3) == 0 for i in range(8))

    # Register 0x100 is staged until the transfer strobe at Register 0xFF.
    await write(dut, 0x100, 0x66)
    assert await read(dut, 0x100) == 0x00
    await write(dut, 0xFF, 0x00)
    assert await read(dut, 0x100) == 0x00
    await write(dut, 0xFF, 0x01)
    assert await read(dut, 0x100) == 0x66

    # Unsupported output formats warn immediately but retain register
    # readback and continue using the model's fixed two-lane bytewise format.
    await write(dut, 0x21, 0x00)
    assert await read(dut, 0x21) == 0x00
    data = await sample(dut)
    assert [channel(data, i) for i in range(8)] == [value << 2 for value in normal]
    await write(dut, 0x21, 0x30)

    # Device index bits[3:0] select data channels A..D, each a pair (channel ch
    # is gated by bit ch/2). Selecting only channel B (bit 1) applies a test
    # mode to channels 2 and 3 and leaves the others on normal data.
    await write(dut, 0x05, 0x02)
    await write(dut, 0x0D, 0x02)
    data = await sample(dut)
    assert channel(data, 2) == 0xFFFC
    assert channel(data, 3) == 0xFFFC
    assert channel(data, 0) == normal[0] << 2
    assert channel(data, 4) == normal[4] << 2

    # A local read with a single channel selected returns that channel's copy.
    assert await read(dut, 0x0D) == 0x02
    # Restore full selection; the datasheet returns Channel A1 for an all-set
    # read, so 0x0D reads back channel 0's (still default) test mode.
    await write(dut, 0x05, 0x3F)
    await write(dut, 0x0D, 0x00)

    # Program every channel for alternating user words in one broadcast write.
    # A single snapshot holds one shared toggle phase, so all channels match;
    # consecutive snapshots alternate. Capturing one sample and indexing every
    # channel keeps the shared state at a single instant.
    await write(dut, 0x19, 0x23)
    await write(dut, 0x1A, 0x01)
    await write(dut, 0x1B, 0x56)
    await write(dut, 0x1C, 0x04)
    await write(dut, 0x0D, 0x48)
    first = await sample(dut)
    second = await sample(dut)
    assert all(channel(first, i) == channel(first, 0) for i in range(8))
    assert all(channel(second, i) == channel(second, 0) for i in range(8))
    assert {channel(first, 0), channel(second, 0)} == {0x0123, 0x0456}

    # PN23 reset is a retained level, not a self-clearing command. While it is
    # asserted, the selected generators stay at their seed; clearing it releases
    # a repeatable sequence from that seed. Because one broadcast write reseeds
    # all channels in the same cycle, every channel stays coherent.
    pn23_seed = 0b01001101110000000101000
    pn23_first = pn_word(pn23_seed, order=23, tap=18) << 2
    pn23_state_1 = pn_advance(pn23_seed, order=23, tap=18)
    pn23_state_2 = pn_advance(pn23_state_1, order=23, tap=18)
    pn23_second = pn_word(pn23_state_1, order=23, tap=18) << 2
    pn23_third = pn_word(pn23_state_2, order=23, tap=18) << 2
    def all_channels(data):
        return [channel(data, i) for i in range(8)]

    await write(dut, 0x0D, 0x25)
    assert await read(dut, 0x0D) == 0x25
    assert all_channels(await sample(dut)) == [pn23_first] * 8
    assert all_channels(await sample(dut)) == [pn23_first] * 8
    await write(dut, 0x0D, 0x05)
    assert await read(dut, 0x0D) == 0x05
    assert all_channels(await sample(dut)) == [pn23_first] * 8
    assert all_channels(await sample(dut)) == [pn23_second] * 8
    # Transferring unchanged resolution/rate configuration must not rewind the
    # live PN state maintained independently by each channel.
    await write(dut, 0xFF, 0x01)
    assert all_channels(await sample(dut)) == [pn23_third] * 8

    # Apply the same hold/release check to the PN9 generator, together with
    # global inversion and byte-local LSB-first ordering.
    await write(dut, 0x0D, 0x16)
    await write(dut, 0x14, 0x04)
    await write(dut, 0x21, 0xB0)
    assert await read(dut, 0x0D) == 0x16
    pn9_seed = 0b011011111
    pn9_first = reverse_bytes((pn_word(pn9_seed) << 2) ^ 0xFFFF)
    pn9_second = reverse_bytes(
        (pn_word(pn_advance(pn9_seed)) << 2) ^ 0xFFFF)
    assert all_channels(await sample(dut)) == [pn9_first] * 8
    assert all_channels(await sample(dut)) == [pn9_first] * 8
    await write(dut, 0x0D, 0x06)
    assert await read(dut, 0x0D) == 0x06
    assert all_channels(await sample(dut)) == [pn9_first] * 8
    assert all_channels(await sample(dut)) == [pn9_second] * 8

    # A power-mode write immediately suppresses all channels. Soft reset
    # immediately restores default two-lane normal output and override state.
    await write(dut, 0x08, 0x01)
    assert await sample(dut) == 0
    await write(dut, 0x00, 0x04)
    assert await read(dut, 0x05) == 0x3F
    assert await read(dut, 0x100) == 0x00
    data = await sample(dut)
    assert [channel(data, i) for i in range(8)] == [value << 2 for value in normal]


def test_Ad9681SimCore():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ad9681simcorewrapper",
        extra_vhdl_sources={
            "surf": [
                "devices/AnalogDevices/adcDdr/sim/AdcDdrPatternPkg.vhd",
                "devices/AnalogDevices/ad9681/sim/Ad9681SimCore.vhd",
                "devices/AnalogDevices/ad9681/wrappers/Ad9681SimCoreWrapper.vhd",
            ],
        },
    )
