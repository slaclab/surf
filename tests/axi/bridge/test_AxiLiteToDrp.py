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
# - Sweep: Keep a narrow common-clock case without arbitration so the initial
#   bridge regression proves the AXI-to-DRP mapping and timeout behavior on a
#   simulator-stable path before revisiting the more timing-sensitive async
#   arbitration branch.
# - Stimulus: Drive AXI-Lite reads and writes into the bridge, observe the DRP
#   request/enable strobes directly, provide DRP grant and ready pulses from
#   cocotb, and then withhold grant or ready long enough to force a timeout.
# - Checks: Writes must present the aligned DRP address and low-word data,
#   reads must return the DRP data in the low AXI-Lite bytes, and timeout
#   completion must return `SLVERR` plus a `drpUsrRst` recovery pulse.
# - Timing: The bench drives AXI and DRP from one lockstep clock coroutine so
#   the common-clock path is exercised directly, and all DRP handshakes are
#   checked with bounded waits around `TIMEOUT_G`.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import (
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
        self.en_arbitration = env_flag("EN_ARBITRATION_G", default=False)
        self.timeout = int(os.environ["TIMEOUT_G"])
        self.reset_active = env_sl("RST_POLARITY_G", default=1)

        if self.common_clk:
            start_lockstep_clocks(dut.axilClk, dut.drpClk, period_ns=6.0)
        else:
            cocotb.start_soon(Clock(dut.axilClk, 8.0, unit="ns").start())
            cocotb.start_soon(Clock(dut.drpClk, 5.0, unit="ns").start())

        dut.axilRst.setimmediatevalue(self.reset_active_value())
        dut.drpRst.setimmediatevalue(self.reset_active_value())
        dut.drpGnt.setimmediatevalue(0)
        dut.drpRdy.setimmediatevalue(0)
        dut.drpDo.setimmediatevalue(0)

        self.axil = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
            clock=dut.axilClk,
            reset=dut.axilRst,
            reset_active_level=bool(self.reset_active),
        )

    def reset_active_value(self) -> int:
        return self.reset_active

    def reset_inactive_value(self) -> int:
        return 1 - self.reset_active

    async def settle(self):
        await Timer(1, unit="ns")

    async def axil_cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await self.settle()

    async def drp_cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.drpClk)
            await self.settle()

    async def reset(self):
        # Reset both sides together before each transaction sequence so timeout
        # counters and handshake strobes restart from their idle values.
        self.dut.axilRst.setimmediatevalue(self.reset_active_value())
        self.dut.drpRst.setimmediatevalue(self.reset_active_value())
        self.dut.drpGnt.value = 0
        self.dut.drpRdy.value = 0
        self.dut.drpDo.value = 0
        await self.axil_cycle(3)
        await self.drp_cycle(3)
        if self.common_clk:
            self.dut.axilRst.value = self.reset_inactive_value()
            self.dut.drpRst.value = self.reset_inactive_value()
        else:
            # Release the DRP side first so the async bridge has a live
            # destination before AXI-Lite traffic starts.
            self.dut.drpRst.value = self.reset_inactive_value()
            await self.drp_cycle(6)
            self.dut.axilRst.value = self.reset_inactive_value()
        await self.axil_cycle(8)
        await self.drp_cycle(8)

    async def wait_for_drp_req(self, timeout_cycles):
        for _ in range(timeout_cycles * 5):
            if int(self.dut.drpReq.value):
                return
            await Timer(1, unit="ns")
        raise AssertionError("Timed out waiting for DRP request")

    async def wait_for_drp_en(self, timeout_cycles):
        for _ in range(timeout_cycles * 5):
            if int(self.dut.drpEn.value):
                return
            await Timer(1, unit="ns")
        raise AssertionError("Timed out waiting for DRP enable")

    async def wait_for_usr_rst(self, timeout_cycles):
        for _ in range(timeout_cycles * 5):
            if int(self.dut.drpUsrRst.value):
                return
            await Timer(1, unit="ns")
        raise AssertionError("Timed out waiting for DRP user reset pulse")


@cocotb.test()
async def write_read_bridge_test(dut):
    tb = TB(dut)
    await tb.reset()

    write_addr = 0x24
    write_payload = b"\x78\x56"
    write_task = cocotb.start_soon(tb.axil.write(write_addr, write_payload))

    if tb.en_arbitration:
        await tb.wait_for_drp_req(timeout_cycles=tb.timeout + 4)
        tb.dut.drpGnt.value = 1

    await tb.wait_for_drp_en(timeout_cycles=tb.timeout + 4)
    assert int(tb.dut.drpWe.value) == 1
    assert int(tb.dut.drpAddr.value) == (write_addr >> 2)
    assert int(tb.dut.drpDi.value) == 0x5678
    tb.dut.drpRdy.value = 1
    await tb.drp_cycle(1)
    tb.dut.drpRdy.value = 0
    tb.dut.drpGnt.value = 0

    wr_txn = await write_task
    assert wr_txn.resp == AxiResp.OKAY

    read_addr = 0x28
    read_task = cocotb.start_soon(tb.axil.read(read_addr, 2))

    if tb.en_arbitration:
        await tb.wait_for_drp_req(timeout_cycles=tb.timeout + 4)
        tb.dut.drpGnt.value = 1

    await tb.wait_for_drp_en(timeout_cycles=tb.timeout + 4)
    assert int(tb.dut.drpWe.value) == 0
    assert int(tb.dut.drpAddr.value) == (read_addr >> 2)
    tb.dut.drpDo.value = 0xABCD
    tb.dut.drpRdy.value = 1
    await tb.drp_cycle(1)
    tb.dut.drpRdy.value = 0
    tb.dut.drpGnt.value = 0

    rd_txn = await read_task
    assert rd_txn.resp == AxiResp.OKAY
    assert rd_txn.data == b"\xCD\xAB"


@cocotb.test()
async def timeout_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    usr_rst_task = cocotb.start_soon(tb.wait_for_usr_rst(timeout_cycles=tb.timeout + 8))

    if tb.en_arbitration:
        txn_task = cocotb.start_soon(tb.axil.write(0x30, b"\xAA\x55"))
        await tb.wait_for_drp_req(timeout_cycles=tb.timeout + 4)
        txn = await txn_task
        assert txn.resp == AxiResp.SLVERR
    else:
        txn_task = cocotb.start_soon(tb.axil.read(0x34, 2))
        await tb.wait_for_drp_en(timeout_cycles=tb.timeout + 4)
        txn = await txn_task
        assert txn.resp == AxiResp.SLVERR

    await usr_rst_task


PARAMETER_SWEEP = [
    parameter_case(
        "common_clk_no_arb",
        COMMON_CLK_G="true",
        EN_ARBITRATION_G="false",
        TIMEOUT_G="4",
        ADDR_WIDTH_G="10",
        DATA_WIDTH_G="16",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiLiteToDrp(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitetodrpipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/bridge/ip_integrator/AxiLiteToDrpIpIntegrator.vhd"],
        },
    )
