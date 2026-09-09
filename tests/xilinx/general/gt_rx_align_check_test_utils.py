##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Helpers for the GtRxAlignCheck bench.

Two models stand in for the GT wizard, mirroring how TimingGtCoreWrapper wires
the checker to a GTHE3 core:

- `DrpAxiLiteSlave` answers the master-side AXI-Lite read that fetches
  COMMA_ALIGN_LATENCY through AxiLiteToDrp.
- `GtBuffBypassModel` reproduces gtwiz_buffbypass_rx_done_out and
  gtwiz_buffbypass_rx_error_out in the RX clock domain, reacting to the
  checker's reset output the way the buffer bypass helper block does.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiResp


# Register map offsets, mirroring surf.GtRxAlignCheck and the PyRogue model in
# python/surf/xilinx/_GtRxAlignCheck.py.
PHASE_HIST_BASE = 0x000
CONFIG_ADDR = 0x100          # PhaseTarget[6:0], Mask[14:8], ResetLen[19:16]
LAST_PHASE_ADDR = 0x104
TX_CLK_FREQ_ADDR = 0x108
RX_CLK_FREQ_ADDR = 0x10C
LOCKED_ADDR = 0x110
OVERRIDE_ADDR = 0x114
RST_RETRY_CNT_ADDR = 0x118
RETRY_CNT_ADDR = 0x11C
REF_CLK_FREQ_ADDR = 0x120

PHASE_HIST_BINS = 40

# DRP offset of COMMA_ALIGN_LATENCY. GTHE3 uses DRP address 0x150 and the other
# supported families use 0x250, both shifted left by two for the byte-addressed
# AXI-Lite view.
COMMA_ALIGN_LATENCY_OFFSET = {
    "GTHE3": 0x0000_0540,
    "GTYE3": 0x0000_0940,
    "GTHE4": 0x0000_0940,
    "GTYE4": 0x0000_0940,
}


def comma_align_latency_addr(gt_type: str, drp_base: int) -> int:
    """Return the AXI-Lite address the checker reads for the phase."""

    return (drp_base + COMMA_ALIGN_LATENCY_OFFSET[gt_type]) & 0xFFFF_FFFF


def config_word(*, target: int, mask: int, rst_len: int) -> int:
    """Pack the 0x100 configuration register."""

    return (target & 0x7F) | ((mask & 0x7F) << 8) | ((rst_len & 0xF) << 16)


def phase_hist_bin(index: int) -> tuple[int, int]:
    """Return the (offset, bit shift) of one phase histogram bin.

    The RTL maps bin `i` with `axiSlaveRegisterR(axilEp, toSlv(4*(i/4), 12),
    8*(i mod 4), ...)`, so four 8-bit bins are packed per 32-bit word.
    """

    if not 0 <= index < PHASE_HIST_BINS:
        raise ValueError(f"Phase histogram bin out of range: {index}")
    return PHASE_HIST_BASE + 4 * (index // 4), 8 * (index % 4)


class DrpAxiLiteSlave:
    """Master-side AXI-Lite slave that returns scripted phase values.

    The ready/valid stepping follows the `SimpleAxiLiteSlave` model already used
    by tests/axi/axi_lite/test_AxiLiteMaster.py. Reads pop the next entry from
    `phases`; once the list is exhausted the final value repeats, so a test can
    script a retry sequence and then let the DUT settle.
    """

    def __init__(self, dut, *, phases):
        self.dut = dut
        self.phases = list(phases)
        if not self.phases:
            raise ValueError("DrpAxiLiteSlave needs at least one phase value")
        self.read_addresses = []
        self.read_count = 0
        self.read_resp = AxiResp.OKAY

        dut.M_AXI_AWREADY.setimmediatevalue(0)
        dut.M_AXI_WREADY.setimmediatevalue(0)
        dut.M_AXI_BVALID.setimmediatevalue(0)
        dut.M_AXI_BRESP.setimmediatevalue(0)
        dut.M_AXI_ARREADY.setimmediatevalue(0)
        dut.M_AXI_RVALID.setimmediatevalue(0)
        dut.M_AXI_RRESP.setimmediatevalue(0)
        dut.M_AXI_RDATA.setimmediatevalue(0)

        # Lifetime DRP responder retained by its bus-model owner.
        self._responder_task = cocotb.start_soon(self._run_read())

    def set_phases(self, phases) -> None:
        """Replace the scripted phase sequence and restart from its head."""

        phases = list(phases)
        if not phases:
            raise ValueError("DrpAxiLiteSlave needs at least one phase value")
        self.phases = phases
        self.read_count = 0

    def _next_phase(self) -> int:
        # Hold the last scripted value so a settled DUT keeps reading the same
        # phase instead of running off the end of the list.
        index = min(self.read_count, len(self.phases) - 1)
        return self.phases[index]

    def in_reset(self) -> bool:
        try:
            return int(self.dut.axilRst.value) == 1
        except ValueError:
            return True

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await sample_after_tpd(self.dut.axilClk)

    async def _wait_while_reset(self) -> None:
        while self.in_reset():
            self.dut.M_AXI_ARREADY.value = 0
            self.dut.M_AXI_RVALID.value = 0
            await self.cycle(1)

    async def _run_read(self) -> None:
        """Lifetime agent: serve DRP reads until cocotb ends the test."""
        while True:
            await self._wait_while_reset()

            # Wait for the address phase of the checker's DRP read.
            while not int(self.dut.M_AXI_ARVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            araddr = int(self.dut.M_AXI_ARADDR.value)
            self.read_addresses.append(araddr)
            self.dut.M_AXI_ARREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_ARREADY.value = 0

            # Return the next scripted COMMA_ALIGN_LATENCY value. The checker
            # only consumes rdData[15:0], and rdData[6:0] is the phase.
            phase = self._next_phase()
            self.read_count += 1
            self.dut.M_AXI_RDATA.value = phase & 0xFFFF
            self.dut.M_AXI_RRESP.value = int(self.read_resp)
            self.dut.M_AXI_RVALID.value = 1
            while not int(self.dut.M_AXI_RREADY.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)
            await self.cycle(1)
            self.dut.M_AXI_RVALID.value = 0


class GtBuffBypassModel:
    """RX-clock-domain model of the GT RX buffer bypass helper block.

    TimingGtCoreWrapper drives `gtwiz_buffbypass_rx_reset_in` from the checker's
    `resetOut` through an `RstSync` in the RX clock domain, and both
    `gtwiz_buffbypass_rx_done_out` and `gtwiz_buffbypass_rx_error_out` are
    RX-domain status levels that stay asserted until that reset is pulsed.

    This model reproduces that contract:

    - `resetOut` asserted clears `resetDone` and `resetErr` after
      `reset_latency` RX clocks, standing in for the wrapper's RstSync.
    - After `resetOut` deasserts, the alignment procedure takes
      `align_latency` RX clocks and then asserts `resetDone`.
    - `error_mode` controls whether `resetErr` also asserts, and
      `err_lead_cycles` lets a test assert the error ahead of done so the
      done/error ordering across the clock domain crossing is controllable.
    """

    def __init__(
        self,
        dut,
        *,
        rx_clk,
        reset_latency: int = 2,
        align_latency: int = 6,
    ):
        self.dut = dut
        self.rx_clk = rx_clk
        self.reset_latency = reset_latency
        self.align_latency = align_latency

        # None means "never assert error". Set to an int to assert the error
        # that many RX clocks before resetDone rises; 0 means simultaneously.
        self.err_lead_cycles = None
        # When True the model asserts resetErr but never resetDone, which the
        # checker cannot act on because the error is gated by done.
        self.err_without_done = False

        self.done_assert_count = 0
        self.err_assert_count = 0

        dut.resetDone.setimmediatevalue(0)
        dut.resetErr.setimmediatevalue(0)

        # Lifetime GT peer retained by its model owner.
        self._model_task = cocotb.start_soon(self._run())

    def arm_error(self, *, lead_cycles: int = 0) -> None:
        """Make the next alignment attempt report an error."""

        self.err_lead_cycles = lead_cycles
        self.err_without_done = False

    def arm_error_without_done(self) -> None:
        """Assert resetErr but never resetDone on the next attempt."""

        self.err_lead_cycles = 0
        self.err_without_done = True

    def clear_error(self) -> None:
        """Let subsequent alignment attempts succeed."""

        self.err_lead_cycles = None
        self.err_without_done = False

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.rx_clk)

    async def _clear_status(self) -> None:
        await self.cycle(self.reset_latency)
        self.dut.resetDone.value = 0
        self.dut.resetErr.value = 0

    def _reset_requested(self) -> bool:
        try:
            return int(self.dut.resetOut.value) == 1
        except ValueError:
            # resetOut is still uninitialized this early in elaboration.
            return False

    async def _run(self) -> None:
        """Lifetime agent: model GT buffer bypass until cocotb ends the test."""
        while True:
            # Track the checker's reset request. resetOut is registered in the
            # axilClk domain, so sample it from the RX clock like real hardware.
            await self.cycle(1)
            if not self._reset_requested():
                continue

            # Reset asserted: drop both status levels.
            await self._clear_status()

            # Wait for the reset to be released before restarting the
            # alignment procedure.
            while self._reset_requested():
                await self.cycle(1)

            lead = self.err_lead_cycles
            if lead is None:
                # Nominal alignment: done rises, no error.
                await self.cycle(self.align_latency)
                self.dut.resetDone.value = 1
                self.done_assert_count += 1
                continue

            # Failing alignment. Assert the error `lead` RX clocks ahead of
            # done so the bench can exercise both orderings of the two
            # RX-domain levels as they cross into axilClk.
            await self.cycle(max(self.align_latency - lead, 1))
            self.dut.resetErr.value = 1
            self.err_assert_count += 1

            if self.err_without_done:
                # Leave done low. The checker gates the error with done, so
                # this attempt must not produce a reset.
                continue

            if lead > 0:
                await self.cycle(lead)
            self.dut.resetDone.value = 1
            self.done_assert_count += 1

            # One error per arming, so the retry that follows can succeed.
            self.clear_error()


class ResetOutMonitor:
    """Count and measure `resetOut` assertions in the axilClk domain."""

    def __init__(self, dut):
        self.dut = dut
        self.pulses = 0
        self.max_width = 0
        self._width = 0
        # Lifetime observer retained by its monitor owner.
        self._monitor_task = cocotb.start_soon(self._run())

    def reset_counts(self) -> None:
        self.pulses = 0
        self.max_width = 0
        self._width = 0

    async def _run(self) -> None:
        """Lifetime agent: monitor reset pulses until cocotb ends the test."""
        previous = 0
        while True:
            await sample_after_tpd(self.dut.axilClk)
            try:
                current = int(self.dut.resetOut.value)
            except ValueError:
                continue

            if current == 1:
                if previous == 0:
                    self.pulses += 1
                    self._width = 1
                else:
                    self._width += 1
                self.max_width = max(self.max_width, self._width)
            previous = current
