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
# - Sweep: Exercise conversion latency and the system-facing AD9681 two-byte-lane
#   pin shape, including a sample-alternating checkerboard pattern.
# - Stimulus: Drive differential encode clock and independent real-valued
#   channels, then issue immediate writes through the actual shared SDIO pins.
# - Checks: Recombine both serialized bytes, verify coherent checkerboard words,
#   framing and differential complements, and confirm SPI updates are applied
#   across both channel halves.
# - Timing: Normal conversions appear exactly 16 sample clocks after capture;
#   both byte groups share an ideal centered DCO/FCO waveform.

import cocotb
from cocotb.triggers import Edge, Timer, with_timeout

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


async def spi_write(dut, address, value):
    header = address & 0x1FFF
    dut.sclk.value = 0
    dut.sdioEnable.value = 1
    dut.csb.value = 0
    await Timer(50, unit="ns")
    for bit in range(15, -1, -1):
        dut.sdioDrive.value = (header >> bit) & 1
        await Timer(30, unit="ns")
        dut.sclk.value = 1
        await Timer(30, unit="ns")
        dut.sclk.value = 0
    for bit in range(7, -1, -1):
        dut.sdioDrive.value = (value >> bit) & 1
        await Timer(30, unit="ns")
        dut.sclk.value = 1
        await Timer(30, unit="ns")
        dut.sclk.value = 0
    await Timer(50, unit="ns")
    dut.csb.value = 1
    dut.sdioEnable.value = 0
    await Timer(100, unit="ns")


async def capture_frame(dut):
    previous = int(dut.fcoP.value) & 1
    for _ in range(3):
        await with_timeout(Edge(dut.fcoP), 100, "ns")
        current = int(dut.fcoP.value) & 1
        if previous == 0 and current == 1:
            break
        previous = current
    else:
        assert False, "FCO did not produce a rising edge"
    low = [0] * 8
    high = [0] * 8
    frame = 0
    for _ in range(8):
        await Edge(dut.dcoP)
        data = int(dut.dP.value)
        frame = (frame << 1) | (int(dut.fcoP.value) & 1)
        for channel in range(8):
            low[channel] = (low[channel] << 1) | ((data >> channel) & 1)
            high[channel] = (high[channel] << 1) | ((data >> (8 + channel)) & 1)
    return [(high[i] << 8) | low[i] for i in range(8)], frame


def twos_complement_word(offset_binary_code):
    """Apply the AD9681's default offset-binary to two's-complement coding."""
    return ((offset_binary_code ^ 0x2000) << 2) & 0xFFFF


@cocotb.test()
async def ad9681_pin_level_device_sim_test(dut):
    normal = [0x200 + i for i in range(8)]
    dut.normalData.value = sum(value << (16 * i) for i, value in enumerate(normal))
    dut.sclk.value = 0
    dut.sdioDrive.value = 0
    dut.sdioEnable.value = 0
    dut.csb.value = 1
    clock_task = cocotb.start_soon(differential_clock(dut))
    await Timer(1, unit="ns")

    # A normal conversion captured with the first frame must remain absent for
    # 16 complete output frames, then appear on the seventeenth frame. The
    # serializer itself starts at zero. The conversion pipeline resets to
    # offset-binary code zero (-FS), which subsequent default two's-complement
    # frames emit as 0x8000 after justification.
    for frame_index in range(16):
        words, frame = await capture_frame(dut)
        expected = 0 if frame_index == 0 else 0x8000
        assert words == [expected] * 8
        assert frame == 0b11110000

    words, frame = await capture_frame(dut)
    assert words == [twos_complement_word(value) for value in normal]
    assert frame == 0b11110000
    assert int(dut.dN.value) == ((~int(dut.dP.value)) & 0xFFFF)
    assert int(dut.dcoN.value) == ((~int(dut.dcoP.value)) & 0x3)
    assert int(dut.fcoN.value) == ((~int(dut.fcoP.value)) & 0x3)

    # Device index bit 0 selects data channel pair A (physical channels 0 and
    # 1). The test mode applies to exactly that pair and leaves the rest on
    # normal data, confirming per-channel selection through the actual SPI pins.
    await spi_write(dut, 0x05, 0x01)
    await spi_write(dut, 0x0D, 0x02)
    words, _ = await capture_frame(dut)
    assert words[0] == 0xFFFC
    assert words[1] == 0xFFFC
    assert words[2:] == [twos_complement_word(value) for value in normal[2:]]

    # Reselect every channel, then apply the alternating checkerboard. Words are
    # latched once per frame; reading sampleData live for each serialized bit
    # would tear the two patterns together. A single broadcast write keeps every
    # channel coherent, so channels 0 and 4 must show the same phase each frame.
    await spi_write(dut, 0x05, 0x3F)
    await spi_write(dut, 0x0D, 0x04)
    checkerboard = []
    for _ in range(4):
        words, _ = await capture_frame(dut)
        assert words[0] == words[4]
        assert words[0] in (0xAAA8, 0x5554)
        checkerboard.append(words[0])
    assert checkerboard[0] == checkerboard[2]
    assert checkerboard[1] == checkerboard[3]
    assert checkerboard[0] != checkerboard[1]
    await cancel_and_join_tasks((clock_task,))


def test_Ad9681Sim():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ad9681simwrapper",
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
