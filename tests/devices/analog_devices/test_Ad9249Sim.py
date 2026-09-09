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
# - Sweep: Exercise conversion latency and the system-facing AD9249 shape with
#   two serialized banks, differential DCO/FCO/data pins, real conversion, and
#   a sample-alternating checkerboard pattern.
# - Stimulus: Drive a differential encode clock and independent channel codes,
#   then program only the second CSB bank for a deterministic full-scale pattern.
# - Checks: Recovered words, coherent checkerboard frames, FCO framing,
#   complementary pins, and bank-isolated SPI are checked without Xilinx models.
# - Timing: Normal conversions appear exactly 16 sample clocks after capture;
#   both banks otherwise use ideal centered DCO/FCO timing in this test.

import cocotb
from cocotb.triggers import Edge, Timer, with_timeout

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


async def spi_write(dut, bank, address, value):
    header = address & 0x1FFF
    dut.sclk.value = 0
    dut.sdioEnable.value = 1
    dut.csb.value = 0b10 if bank == 0 else 0b01
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
    dut.csb.value = 0b11
    dut.sdioEnable.value = 0
    await Timer(200, unit="ns")


async def wait_fco_rise(dut, bank):
    previous = (int(dut.fcoP.value) >> bank) & 1
    for _ in range(3):
        await with_timeout(Edge(dut.fcoP), 100, "ns")
        current = (int(dut.fcoP.value) >> bank) & 1
        if previous == 0 and current == 1:
            return
        previous = current
    assert False, f"FCO bank {bank} did not produce a rising edge"


async def capture_bank(dut, bank):
    await wait_fco_rise(dut, bank)
    words = [0] * 8
    frame = 0
    for _ in range(14):
        await Edge(dut.dcoP)
        data = int(dut.dP.value) >> (8 * bank)
        frame = (frame << 1) | ((int(dut.fcoP.value) >> bank) & 1)
        for channel in range(8):
            words[channel] = (words[channel] << 1) | ((data >> channel) & 1)
    return words, frame


@cocotb.test()
async def ad9249_pin_level_device_sim_test(dut):
    normal = [0x100 + i for i in range(16)]
    dut.normalData.value = sum(value << (16 * i) for i, value in enumerate(normal))
    dut.sclk.value = 0
    dut.sdioDrive.value = 0
    dut.sdioEnable.value = 0
    dut.csb.value = 0b11
    clock_task = cocotb.start_soon(differential_clock(dut))
    # Allow the model's time-zero output initialization to settle before any
    # std_logic_vector is converted to an integer by the frame collector.
    await Timer(1, unit="ns")

    # A normal conversion captured with the first frame must remain absent for
    # 16 complete output frames, then appear on the seventeenth frame.
    for _ in range(16):
        bank0, frame0 = await capture_bank(dut, 0)
        assert bank0 == [0] * 8
        assert frame0 == 0b11111110000000

    bank0, frame0 = await capture_bank(dut, 0)
    bank1, frame1 = await capture_bank(dut, 1)
    assert bank0 == normal[:8]
    assert bank1 == normal[8:]
    assert frame0 == 0b11111110000000
    assert frame1 == 0b11111110000000
    assert int(dut.dN.value) == ((~int(dut.dP.value)) & 0xFFFF)
    assert int(dut.dcoN.value) == ((~int(dut.dcoP.value)) & 0x3)
    assert int(dut.fcoN.value) == ((~int(dut.fcoP.value)) & 0x3)

    # Both groups share SCLK/SDIO, but their independent CSB pins must isolate
    # configuration. Program only bank 1 for positive full-scale output.
    await spi_write(dut, 1, 0x0D, 0x02)
    bank0, _ = await capture_bank(dut, 0)
    bank1, _ = await capture_bank(dut, 1)
    assert bank0 == normal[:8]
    assert bank1 == [0x3FFF] * 8

    # Alternating test words must be captured once per frame rather than read
    # live across serialization, which would combine both checkerboard phases.
    await spi_write(dut, 1, 0x0D, 0x04)
    checkerboard = []
    for _ in range(4):
        bank1, _ = await capture_bank(dut, 1)
        assert len(set(bank1)) == 1
        assert bank1[0] in (0x2AAA, 0x1555)
        checkerboard.append(bank1[0])
    assert checkerboard[0] == checkerboard[2]
    assert checkerboard[1] == checkerboard[3]
    assert checkerboard[0] != checkerboard[1]
    await cancel_and_join_tasks((clock_task,))


def test_Ad9249Sim():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ad9249simwrapper",
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
