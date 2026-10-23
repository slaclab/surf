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
# - Sweep: AD9249, AD9252, and AD9681 pin models, both normal-data codings,
#   negative/positive differential voltages, zero, and full-scale overrange.
# - Stimulus: Signed millivolts go directly through thin wrappers to the real
#   model inputs. Actual SPI transactions select coding and AD9252 transfer.
# - Checks: Hand-calculated 14-bit conversion vectors, saturation, bank-wide
#   coding and device-specific right/left justification at serialized pins.
# - Timing: Wait beyond each model's conversion pipeline after input changes;
#   existing pin tests separately enforce exact conversion latency.

import importlib
import os

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.adc import offset_binary_to_twos_complement
from tests.common.regression_utils import cancel_and_join_tasks, run_surf_vhdl_test


@cocotb.test()
async def bipolar_analog_conversion(dut):
    part = os.environ["ADC_PART"]
    bench = importlib.import_module(f"tests.devices.analog_devices.test_{part}Sim")
    channels = 16 if part == "Ad9249" else 8
    shift = 2 if part == "Ad9681" else 0
    period = 8 if part == "Ad9681" else 24
    dut.normalData.value = 0
    dut.sclk.value = 0
    dut.sdioDrive.value = 0
    dut.sdioEnable.value = 0
    dut.csb.value = 3 if part == "Ad9249" else 1
    clock_task = cocotb.start_soon(bench.differential_clock(dut))

    async def set_coding(coding):
        if part == "Ad9249":
            for bank in range(2):
                await bench.spi_write(dut, bank, 0x14, coding)
        else:
            await bench.spi_write(dut, 0x14, coding)
            if part == "Ad9252":
                await bench.spi_write(dut, 0xFF, 0x01)

    try:
        await Timer(1, unit="ns")
        # These code vectors use 8192 codes/V; +/-1 mV rounds to +/-8 codes.
        # A high-rail wrap produces zero and is explicitly distinguished here.
        batches = [
            ([-1200, -1000, -500, -1, 0, 1, 500, 1000],
             [0x0000, 0x0000, 0x1000, 0x1FF8, 0x2000, 0x2008, 0x3000, 0x3FFF]),
            ([1200, 999, 250, -250, -999, 0, 1000, -1000],
             [0x3FFF, 0x3FF8, 0x2800, 0x1800, 0x0008, 0x2000, 0x3FFF, 0x0000]),
        ]
        # Check reset coding before any SPI write, then both explicit modes.
        default_coding = 0 if part == "Ad9252" else 1
        for coding in (None, 0, 1):
            active_coding = default_coding if coding is None else coding
            if coding is not None:
                await set_coding(coding)
            for millivolts, codes in batches:
                millivolts = millivolts * (channels // 8)
                codes = codes * (channels // 8)
                dut.normalData.value = sum(
                    (value & 0xFFFF) << (16*i) for i, value in enumerate(millivolts))
                await Timer(20*period, unit="ns")
                if part == "Ad9249":
                    first, _ = await bench.capture_bank(dut, 0)
                    second, _ = await bench.capture_bank(dut, 1)
                    words = first + second
                else:
                    words, _ = await bench.capture_frame(dut)
                expected = [
                    (offset_binary_to_twos_complement(code, 14) if active_coding else code) << shift
                    for code in codes
                ]
                assert words == expected, (part, coding, millivolts, words, expected)
    finally:
        await cancel_and_join_tasks((clock_task,))


@pytest.mark.parametrize("part", ["Ad9249", "Ad9252", "Ad9681"])
def test_AdcSimAnalog(part):
    device = f"devices/AnalogDevices/{part.lower()}"
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel=f"surf.{part.lower()}simwrapper",
        parameters={"INPUT_MILLIVOLTS_G": True},
        extra_env={"ADC_PART": part},
        extra_vhdl_sources={
            "surf": [
                "devices/AnalogDevices/general/rtl/AdiConfigSlave.vhd",
                "devices/AnalogDevices/adcDdr/sim/AdcDdrPatternPkg.vhd",
                f"{device}/sim/{part}SimCore.vhd",
                f"{device}/sim/{part}Sim.vhd",
                f"{device}/wrappers/{part}SimWrapper.vhd",
            ],
        },
    )
