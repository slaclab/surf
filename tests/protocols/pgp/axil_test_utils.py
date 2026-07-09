##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.common.regression_utils import start_lockstep_clocks


class PgpAxiLiteTb:
    """Reusable cocotb harness for flattened AXI-Lite register blocks.

    Many PGP tests only need three things:
    1. one or more clocks,
    2. a predictable reset sequence, and
    3. a cocotbext AXI-Lite master attached to the wrapper's `S_AXI` bus.

    Without a shared helper, every register test ends up re-implementing the
    same boilerplate in slightly different ways.  Keeping that setup here makes
    the actual tests read more like short verification scripts and less like
    simulator bring-up code.
    """

    def __init__(
        self,
        dut,
        *,
        axil_clk_name: str = "S_AXI_ACLK",
        axil_reset_name: str = "S_AXI_ARESETN",
        clock_names: tuple[str, ...] | None = None,
        cycle_clock_name: str | None = None,
        period_ns: float = 5.0,
        axil_prefix: str = "S_AXI",
        axil_reset_active_level: bool = False,
        reset_signals: tuple[tuple[str, int, int], ...] | None = None,
        initial_values: dict[str, int] | None = None,
    ):
        self.dut = dut
        self.axil = None
        self.axil_prefix = axil_prefix
        self.axil_clk = getattr(dut, axil_clk_name)
        self.axil_reset = getattr(dut, axil_reset_name)
        self.axil_reset_active_level = axil_reset_active_level

        driven_clock_names = clock_names or (axil_clk_name,)
        cycle_clock_name = cycle_clock_name or driven_clock_names[0]
        self.cycle_clk = getattr(dut, cycle_clock_name)

        if len(driven_clock_names) == 1:
            cocotb.start_soon(Clock(self.cycle_clk, period_ns, unit="ns").start())
        else:
            # Common-clock PGP tests need truly shared edges, not just same-
            # period clocks started by separate coroutines.
            start_lockstep_clocks(
                *(getattr(dut, name) for name in driven_clock_names),
                period_ns=period_ns,
            )

        self.reset_signals = reset_signals or ((axil_reset_name, 0, 1),)

        for signal_name, value in (initial_values or {}).items():
            getattr(dut, signal_name).setimmediatevalue(value)

    async def cycle(self, count: int = 1):
        """Advance the bench by a whole number of visible wrapper clock edges."""

        for _ in range(count):
            await RisingEdge(self.cycle_clk)
            # Most SURF RTL uses the default `TPD_G => 1 ns`, so the tests wait
            # a small amount after every edge before sampling outputs.
            await Timer(1, unit="ns")

    async def reset(self, *, hold_cycles: int = 4, settle_cycles: int = 8):
        """Drive every declared reset signal through its active and idle state."""

        for signal_name, active_value, _inactive_value in self.reset_signals:
            getattr(self.dut, signal_name).value = active_value
        await self.cycle(hold_cycles)

        for signal_name, _active_value, inactive_value in self.reset_signals:
            getattr(self.dut, signal_name).value = inactive_value
        await self.cycle(settle_cycles)

    def start_axil_master(self):
        """Construct the cocotbext AXI-Lite master on first use."""

        if self.axil is None:
            self.axil = AxiLiteMaster(
                AxiLiteBus.from_prefix(self.dut, self.axil_prefix),
                self.axil_clk,
                self.axil_reset,
                reset_active_level=self.axil_reset_active_level,
            )
