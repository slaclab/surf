##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.base.crc.crc_test_utils import (
    crc_out_from_remainder,
    crc_update,
    pack_active_bytes,
)
from tests.common.regression_utils import (
    env_flag,
    env_sl,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        # This legacy-compatible CRC block always uses a 32-bit input bus with
        # 1-4 active bytes selected by `CRCDATAWIDTH`.
        dut.CRCCLKEN.value = 1
        dut.CRCDATAVALID.value = 0
        dut.CRCDATAWIDTH.value = 0
        dut.CRCIN.value = 0
        dut.CRCINIT.value = 0xFFFFFFFF
        dut.CRCRESET.value = self.reset_active_value()

        cocotb.start_soon(Clock(dut.CRCCLK, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.CRCCLK)
            await self.settle()

    async def initialize_crc(self, *, init_value: int = 0xFFFFFFFF) -> None:
        # Drive the CRC register to a known initial remainder before each test.
        self.dut.CRCINIT.value = init_value
        self.dut.CRCRESET.value = self.reset_active_value()
        await self.cycle(2)
        self.dut.CRCRESET.value = self.reset_inactive_value()
        await self.cycle(1)

    async def apply_word(self, data_bytes: list[int], *, clken: int = 1) -> int:
        # The active bytes are packed into the upper lanes so the Python driver
        # matches the same byte ordering convention as the VHDL block.
        self.dut.CRCCLKEN.value = clken
        self.dut.CRCDATAVALID.value = 1 if data_bytes else 0
        self.dut.CRCDATAWIDTH.value = max(len(data_bytes) - 1, 0)
        self.dut.CRCIN.value = pack_active_bytes(data_bytes, byte_width=4)

        await RisingEdge(self.dut.CRCCLK)

        self.dut.CRCDATAVALID.value = 0
        await self.settle()

        # This block always latches the incoming data/valid first and applies
        # the CRC update on the following cycle.
        await self.cycle(1)
        return int(self.dut.CRCOUT.value)


@cocotb.test()
async def crc_sequence_test(dut):
    tb = TB(dut)
    await tb.initialize_crc()

    remainder = 0xFFFFFFFF
    for payload in ([0x12], [0x34, 0x56], [0x78, 0x9A, 0xBC, 0xDE]):
        remainder = crc_update(remainder, payload)
        crc_out = await tb.apply_word(payload)
        assert crc_out == crc_out_from_remainder(remainder)


@cocotb.test()
async def clock_enable_hold_test(dut):
    tb = TB(dut)
    await tb.initialize_crc()

    remainder = crc_update(0xFFFFFFFF, [0x11, 0x22, 0x33, 0x44])
    assert await tb.apply_word([0x11, 0x22, 0x33, 0x44]) == crc_out_from_remainder(remainder)

    # With `CRCCLKEN=0`, the data staging registers and the CRC state should
    # both hold their previous values.
    held_crc = int(dut.CRCOUT.value)
    assert await tb.apply_word([0xAA, 0xBB, 0xCC, 0xDD], clken=0) == held_crc
    assert int(dut.CRCOUT.value) == held_crc


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.initialize_crc()

    await tb.apply_word([0xCA, 0xFE, 0xBA, 0xBE])
    reset_output = crc_out_from_remainder(0xFFFFFFFF)
    assert int(dut.CRCOUT.value) != reset_output

    await FallingEdge(dut.CRCCLK)
    await Timer(1, unit="ns")
    dut.CRCRESET.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.CRCOUT.value) == reset_output
    else:
        assert int(dut.CRCOUT.value) != reset_output
        await tb.cycle(1)
        assert int(dut.CRCOUT.value) == reset_output


PARAMETER_SWEEP = [
    parameter_case(
        "sync_baseline",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_reset",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_reset",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_CRC32Rtl(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.crc32rtl",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
