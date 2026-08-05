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
# - Sweep: Exercise conversion latency and the system-facing AD9252 pin shape in
#   normal, deterministic, and sample-alternating checkerboard modes.
# - Stimulus: Drive differential encode clock and real-valued channel inputs,
#   then configure one channel through the actual shared SDIO interface.
# - Checks: Recover coherent serialized words and framing, verify differential
#   complements, and confirm staged SPI configuration reaches the output pins.
# - Timing: Normal conversions appear exactly eight sample clocks after capture;
#   data and FCO otherwise use ideal centered timing in this test.

import cocotb
from cocotb.triggers import Edge, Timer

from tests.common.regression_utils import run_surf_vhdl_test


async def differential_clock(dut, period_ns=24):
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
    await Timer(100, unit="ns")
    for bit in range(15, -1, -1):
        dut.sdioDrive.value = (header >> bit) & 1
        await Timer(80, unit="ns")
        dut.sclk.value = 1
        await Timer(80, unit="ns")
        dut.sclk.value = 0
    for bit in range(7, -1, -1):
        dut.sdioDrive.value = (value >> bit) & 1
        await Timer(80, unit="ns")
        dut.sclk.value = 1
        await Timer(80, unit="ns")
        dut.sclk.value = 0
    await Timer(100, unit="ns")
    dut.csb.value = 1
    dut.sdioEnable.value = 0
    await Timer(200, unit="ns")


async def capture_frame(dut):
    previous = int(dut.fcoP.value)
    while True:
        await Edge(dut.fcoP)
        current = int(dut.fcoP.value)
        if previous == 0 and current == 1:
            break
        previous = current
    words = [0] * 8
    frame = 0
    for _ in range(14):
        await Edge(dut.dcoP)
        data = int(dut.dP.value)
        frame = (frame << 1) | int(dut.fcoP.value)
        for channel in range(8):
            words[channel] = (words[channel] << 1) | ((data >> channel) & 1)
    return words, frame


@cocotb.test()
async def ad9252_pin_level_device_sim_test(dut):
    normal = [0x100 + i for i in range(8)]
    dut.normalData.value = sum(value << (16 * i) for i, value in enumerate(normal))
    dut.sclk.value = 0
    dut.sdioDrive.value = 0
    dut.sdioEnable.value = 0
    dut.csb.value = 1
    cocotb.start_soon(differential_clock(dut))
    # Allow the model's time-zero output initialization to settle before any
    # std_logic value is converted to an integer by the frame collector.
    await Timer(1, unit="ns")

    # Seven explicit conversion registers plus the coherent frame handoff model
    # the specified eight-clock latency at the device pins.
    for _ in range(8):
        words, frame = await capture_frame(dut)
        assert words == [0] * 8
        assert frame == 0b11111110000000

    words, frame = await capture_frame(dut)
    assert words == normal
    assert frame == 0b11111110000000
    assert int(dut.dN.value) == ((~int(dut.dP.value)) & 0xFF)
    assert int(dut.dcoN.value) == (not int(dut.dcoP.value))
    assert int(dut.fcoN.value) == (not int(dut.fcoP.value))

    await spi_write(dut, 0x05, 0x01)
    await spi_write(dut, 0x0D, 0x02)
    await spi_write(dut, 0xFF, 0x01)
    words, _ = await capture_frame(dut)
    assert words[0] == 0x3FFF
    assert words[1:] == normal[1:]

    # Alternating output words must remain coherent across each serialized
    # frame even though the core toggles the pattern every sample clock.
    await spi_write(dut, 0x0D, 0x04)
    await spi_write(dut, 0xFF, 0x01)
    checkerboard = []
    for _ in range(4):
        words, _ = await capture_frame(dut)
        assert words[0] in (0x2AAA, 0x1555)
        assert words[1:] == normal[1:]
        checkerboard.append(words[0])
    assert checkerboard[0] == checkerboard[2]
    assert checkerboard[1] == checkerboard[3]
    assert checkerboard[0] != checkerboard[1]


def test_Ad9252Sim():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ad9252simwrapper",
        extra_vhdl_sources={
            "surf": [
                "devices/AnalogDevices/general/rtl/AdiConfigSlave.vhd",
                "devices/AnalogDevices/adcDdr/sim/AdcDdrPatternPkg.vhd",
                "devices/AnalogDevices/ad9252/sim/Ad9252SimCore.vhd",
                "devices/AnalogDevices/ad9252/sim/Ad9252Sim.vhd",
                "devices/AnalogDevices/ad9252/wrappers/Ad9252SimWrapper.vhd",
            ],
        },
    )
