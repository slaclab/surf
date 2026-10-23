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
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import env_flag, env_sl


class DualClockRamTB:
    def __init__(self, dut):
        self.dut = dut
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.clka_period_ns = float(os.environ["CLKA_PERIOD_NS"])
        self.clkb_period_ns = float(os.environ["CLKB_PERIOD_NS"])

        cocotb.start_soon(Clock(dut.clka, self.clka_period_ns, unit="ns").start())
        cocotb.start_soon(Clock(dut.clkb, self.clkb_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def full_byte_mask(self, signal_name: str) -> int:
        return (1 << len(getattr(self.dut, signal_name))) - 1

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle_a(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clka)
            await self.settle()

    async def cycle_b(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clkb)
            await self.settle()

    async def warmup(self) -> None:
        # One idle cycle per port keeps the first transaction from racing the
        # just-started clock coroutines.
        await self.cycle_a(1)
        await self.cycle_b(1)
