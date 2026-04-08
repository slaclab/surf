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


class SynchronizerLikeTB:
    def __init__(self, dut, *, width: int):
        self.dut = dut
        # cocotb passes the elaborated HDL object in as `dut`. All signal
        # access in the testbench goes through that object.
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])
        # Test parameters are injected through environment variables by
        # `run_surf_vhdl_test(..., extra_env=...)`, so the cocotb layer reads
        # back the same generic/runtime knobs the pytest case selected.
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.out_polarity = env_sl("OUT_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.bypass_enabled = env_flag("BYPASS_SYNC_G", default=False)
        self.stages = int(os.environ["STAGES_G"])
        # `mask` lets the same helper work for both a 1-bit synchronizer and
        # the vector version while keeping inversion logic simple.
        self.mask = (1 << width) - 1

        # Give the DUT a defined starting state before the clock starts. In
        # cocotb, assigning `.value` drives the HDL signal immediately.
        dut.dataIn.value = 0
        dut.rst.value = self.reset_active_value()

        # `Clock(...).start()` is an async coroutine that toggles the HDL clock
        # forever. `start_soon()` launches it in the background so the test can
        # keep running while the clock continues.
        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def expected_output(self, data_in: int) -> int:
        # The DUT can optionally invert its output polarity. Keeping that rule
        # in one helper avoids re-deriving the expected value in every test.
        return data_in if self.out_polarity == 1 else self.mask ^ data_in

    async def settle(self) -> None:
        # The RTL uses `TPD_G => 1 ns`, so sampling exactly on a clock edge can
        # read the old value. This tiny delay gives the simulator time to apply
        # the scheduled output update before assertions run.
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        # `await RisingEdge(...)` means "pause this coroutine until the HDL
        # signal has its next rising transition". This is the core way cocotb
        # synchronizes Python code to simulated hardware time.
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()

    async def reset(self) -> None:
        # Drive reset active first so the DUT starts from its known reset state.
        self.dut.rst.value = self.reset_active_value()

        if self.async_reset:
            # For async reset cases, assert reset away from a clock edge first
            # and then let a few clock cycles pass so the design fully settles.
            await Timer(2, unit="ns")
            await self.cycle(4)
        else:
            # For sync reset cases, just hold reset across several clock edges.
            await self.cycle(4)

        # Release reset, then allow a couple more cycles for post-reset state to
        # propagate through the synchronizer pipeline.
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(2)

    async def drive_and_expect_after_latency(self, value: int) -> None:
        # Capture the current output so we can prove the synchronizer does not
        # update too early while the new input is still moving through stages.
        previous_output = int(self.dut.dataOut.value)
        self.dut.dataIn.value = value
        await self.settle()

        # For each stage before the final one, the output should still show the
        # old value because the new sample has not reached the end yet.
        for _ in range(self.stages - 1):
            await RisingEdge(self.dut.clk)
            await self.settle()
            assert int(self.dut.dataOut.value) == previous_output

        # One more clock should move the new sample to the output stage.
        await RisingEdge(self.dut.clk)
        await self.settle()
        assert int(self.dut.dataOut.value) == self.expected_output(value)
