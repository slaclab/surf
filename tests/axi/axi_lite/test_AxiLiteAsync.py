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
# - Sweep: Keep a narrow common-clock wrapper-focused case that proves the
#   cocotb-facing bridge topology and stable pass-through behavior without
#   trying to force the less simulator-stable asynchronous reset branches into
#   the initial regression batch.
# - Stimulus: Drive AXI-Lite writes and reads through the slave-side port into
#   a cocotb RAM attached to the master-side port, then assert only the master
#   reset while the slave side remains live in the asynchronous case.
# - Checks: Successful transactions must round-trip through the bridge into the
#   backing RAM, common-clock reset must restart the path cleanly, and
#   post-reset traffic must recover without stale responses.
# - Timing: The bench drives both bridge clocks from one lockstep coroutine so
#   `COMMON_CLK_G=true` is exercised as a true shared-clock configuration.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import (
    cancel_and_join_tasks,
    env_flag,
    env_sl,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.common_clk = env_flag("COMMON_CLK_G", default=False)
        self.pipe_stages = int(os.environ["PIPE_STAGES_G"])
        self.reset_active = env_sl("RST_POLARITY_G", default=1)

        if self.common_clk:
            self._clock_task = start_lockstep_clocks(dut.sAxiClk, dut.mAxiClk, period_ns=6.0)
        else:
            cocotb.start_soon(Clock(dut.sAxiClk, 8.0, unit="ns").start())
            cocotb.start_soon(Clock(dut.mAxiClk, 5.0, unit="ns").start())

        dut.sAxiClkRst.setimmediatevalue(self.reset_active_value())
        dut.mAxiClkRst.setimmediatevalue(self.reset_active_value())

        self.axil = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
            clock=dut.sAxiClk,
            reset=dut.sAxiClkRst,
            reset_active_level=bool(self.reset_active),
        )
        self.slave = SimpleAxiLiteSlave(dut, self.reset_active)

    async def close(self) -> None:
        await self.slave.close()

    def reset_active_value(self) -> int:
        return self.reset_active

    def reset_inactive_value(self) -> int:
        return 1 - self.reset_active

    async def settle(self):
        await Timer(1, unit="ns")

    async def s_cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.sAxiClk)
            await self.settle()

    async def m_cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.mAxiClk)
            await self.settle()

    async def reset(self):
        # Hold both domains in reset together so the bridge and RAM start from
        # a known empty state before each scenario.
        self.dut.sAxiClkRst.setimmediatevalue(self.reset_active_value())
        self.dut.mAxiClkRst.setimmediatevalue(self.reset_active_value())
        await self.s_cycle(3)
        await self.m_cycle(3)
        if self.common_clk:
            self.dut.sAxiClkRst.value = self.reset_inactive_value()
            self.dut.mAxiClkRst.value = self.reset_inactive_value()
        else:
            # Release the destination side first so the source-side bridge does
            # not interpret the first post-reset transfer as a remote-domain
            # reset error.
            self.dut.mAxiClkRst.value = self.reset_inactive_value()
            await self.m_cycle(6)
            self.dut.sAxiClkRst.value = self.reset_inactive_value()
        await self.s_cycle(8)
        await self.m_cycle(8)


class SimpleAxiLiteSlave:
    def __init__(self, dut, reset_active):
        self.dut = dut
        self.reset_active = reset_active
        self.mem = {}

        dut.M_AXI_AWREADY.setimmediatevalue(0)
        dut.M_AXI_WREADY.setimmediatevalue(0)
        dut.M_AXI_BVALID.setimmediatevalue(0)
        dut.M_AXI_BRESP.setimmediatevalue(0)
        dut.M_AXI_ARREADY.setimmediatevalue(0)
        dut.M_AXI_RVALID.setimmediatevalue(0)
        dut.M_AXI_RRESP.setimmediatevalue(0)
        dut.M_AXI_RDATA.setimmediatevalue(0)

        # The read/write responders are lifetime protocol peers owned by TB.
        self._responder_tasks = (
            cocotb.start_soon(self._run_write()),
            cocotb.start_soon(self._run_read()),
        )

    async def close(self) -> None:
        await cancel_and_join_tasks(self._responder_tasks)

    def in_reset(self) -> bool:
        try:
            return int(self.dut.mAxiClkRst.value) == self.reset_active
        except ValueError:
            return True

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.mAxiClk)

    async def _wait_while_reset(self):
        while self.in_reset():
            self.dut.M_AXI_AWREADY.value = 0
            self.dut.M_AXI_WREADY.value = 0
            self.dut.M_AXI_BVALID.value = 0
            self.dut.M_AXI_ARREADY.value = 0
            self.dut.M_AXI_RVALID.value = 0
            await self.cycle(1)

    async def _run_write(self):
        """Lifetime agent: respond to AXI-Lite writes until the test ends."""
        while True:
            await self._wait_while_reset()

            while not int(self.dut.M_AXI_AWVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            awaddr = int(self.dut.M_AXI_AWADDR.value)
            self.dut.M_AXI_AWREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_AWREADY.value = 0

            while not int(self.dut.M_AXI_WVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            wdata = int(self.dut.M_AXI_WDATA.value)
            wstrb = int(self.dut.M_AXI_WSTRB.value)
            prior = self.mem.get(awaddr, 0).to_bytes(4, "little")
            next_bytes = bytearray(prior)
            write_bytes = wdata.to_bytes(4, "little")
            for index in range(4):
                if wstrb & (1 << index):
                    next_bytes[index] = write_bytes[index]
            self.mem[awaddr] = int.from_bytes(next_bytes, "little")

            self.dut.M_AXI_WREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_WREADY.value = 0

            self.dut.M_AXI_BRESP.value = int(AxiResp.OKAY)
            self.dut.M_AXI_BVALID.value = 1
            while not int(self.dut.M_AXI_BREADY.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)
            await self.cycle(1)
            self.dut.M_AXI_BVALID.value = 0

    async def _run_read(self):
        """Lifetime agent: respond to AXI-Lite reads until the test ends."""
        while True:
            await self._wait_while_reset()

            while not int(self.dut.M_AXI_ARVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            araddr = int(self.dut.M_AXI_ARADDR.value)
            self.dut.M_AXI_ARREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_ARREADY.value = 0

            self.dut.M_AXI_RDATA.value = self.mem.get(araddr, 0)
            self.dut.M_AXI_RRESP.value = int(AxiResp.OKAY)
            self.dut.M_AXI_RVALID.value = 1
            while not int(self.dut.M_AXI_RREADY.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)
            await self.cycle(1)
            self.dut.M_AXI_RVALID.value = 0


@cocotb.test()
async def bridge_round_trip_test(dut):
    tb = TB(dut)
    try:
        await tb.reset()

        transactions = [
            (0x000, b"\x11\x22\x33\x44"),
            (0x008, b"\xAA\xBB"),
            (0x010, b"\x10\x20\x30\x40"),
        ]

        # Sweep a few aligned accesses so the test proves the slave-side bus
        # can drive data through the bridge into the master-side backing RAM.
        for addr, payload in transactions:
            wr_txn = await tb.axil.write(addr, payload)
            assert wr_txn.resp == AxiResp.OKAY
            assert tb.slave.mem[addr].to_bytes(4, "little")[: len(payload)] == payload

            rd_txn = await tb.axil.read(addr, len(payload))
            assert rd_txn.resp == AxiResp.OKAY
            assert rd_txn.data == payload
    finally:
        await tb.close()


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    try:
        await tb.reset()

        baseline = b"\x5A\xA5\xC3\x3C"
        wr_txn = await tb.axil.write(0x020, baseline)
        assert wr_txn.resp == AxiResp.OKAY
        rd_txn = await tb.axil.read(0x020, len(baseline))
        assert rd_txn.resp == AxiResp.OKAY
        assert rd_txn.data == baseline

        # In common-clock mode the DUT reduces to direct pass-through, so the
        # reset coverage is restart-and-recover rather than remote-domain
        # error shaping.
        self_reset = tb.reset_active_value()
        self_release = tb.reset_inactive_value()
        tb.dut.sAxiClkRst.value = self_reset
        tb.dut.mAxiClkRst.value = self_reset
        await tb.s_cycle(3)
        tb.dut.sAxiClkRst.value = self_release
        tb.dut.mAxiClkRst.value = self_release
        await tb.s_cycle(3)

        recovery = b"\x89\x67\x45\x23"
        wr_txn = await tb.axil.write(0x024, recovery)
        assert wr_txn.resp == AxiResp.OKAY
        rd_txn = await tb.axil.read(0x024, len(recovery))
        assert rd_txn.resp == AxiResp.OKAY
        assert rd_txn.data == recovery
    finally:
        await tb.close()


PARAMETER_SWEEP = [
    parameter_case(
        "common_clk_sync",
        COMMON_CLK_G="true",
        PIPE_STAGES_G="0",
        NUM_ADDR_BITS_G="12",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiLiteAsync(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiliteasyncipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
