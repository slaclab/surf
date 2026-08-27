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
# - Sweep: Keep a wrapper-focused sweep covering AXI-writeable RAM, dual-port
#   RAM with byte-enabled system writes, latency-3 output-register behavior,
#   and AXI read-only behavior with error responses exposed through the
#   existing IP-integrator wrapper.
# - Stimulus: Drive AXI-Lite reads and writes through the flat wrapper port,
#   read the same locations back through the system-side port, and in writable
#   system-port cases issue full-word and partial-byte writes from the system
#   side before reading them back over AXI-Lite.
# - Checks: AXI writes must update RAM contents when enabled, system-side reads
#   must see those updates, byte-masked system writes must only update the
#   selected bytes, and AXI writes must return `SLVERR` when `AXI_WR_EN` is
#   disabled and wrapper error responses are enabled.
# - Timing: Common-clock cases use one shared clock coroutine, asynchronous
#   cases use separate AXI and system clocks, and system-side read visibility
#   is checked after bounded waits derived from `READ_LATENCY`.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import (
    env_flag,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.common_clk = env_flag("COMMON_CLK", default=False)
        self.axi_wr_en = env_flag("AXI_WR_EN", default=True)
        self.sys_wr_en = env_flag("SYS_WR_EN", default=False)
        self.sys_byte_wr_en = env_flag("SYS_BYTE_WR_EN", default=False)
        self.read_latency = int(os.environ["READ_LATENCY"])
        self.data_width = int(os.environ["DATA_WIDTH"])
        self.byte_count = self.data_width // 8

        if self.common_clk:
            start_lockstep_clocks(dut.S_AXI_ACLK, dut.CLK, period_ns=6.0)
        else:
            cocotb.start_soon(Clock(dut.S_AXI_ACLK, 8.0, unit="ns").start())
            cocotb.start_soon(Clock(dut.CLK, 5.0, unit="ns").start())

        dut.S_AXI_ARESETN.setimmediatevalue(0)
        dut.RST.setimmediatevalue(1)
        dut.EN.setimmediatevalue(1)
        dut.WE.setimmediatevalue(0)
        dut.ADDR.setimmediatevalue(0)
        dut.DIN.setimmediatevalue(0)

        self.axil = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
            clock=dut.S_AXI_ACLK,
            reset=dut.S_AXI_ARESETN,
            reset_active_level=False,
        )

    async def settle(self):
        await Timer(1, unit="ns")

    async def axi_cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.S_AXI_ACLK)
            await self.settle()

    async def sys_cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.CLK)
            await self.settle()

    async def reset(self):
        # Drive both ports into reset so AXI traffic and the system-side port
        # begin each scenario from the same empty RAM image.
        self.dut.S_AXI_ARESETN.setimmediatevalue(0)
        self.dut.RST.setimmediatevalue(1)
        self.dut.WE.value = 0
        await self.axi_cycle(3)
        await self.sys_cycle(3)
        self.dut.S_AXI_ARESETN.value = 1
        if not self.common_clk:
            await self.axi_cycle(2)
        self.dut.RST.value = 0
        await self.axi_cycle(4)
        await self.sys_cycle(4)

    async def sys_read(self, addr):
        self.dut.EN.value = 1
        self.dut.WE.value = 0
        self.dut.ADDR.value = addr
        await self.sys_cycle(self.read_latency + 2)
        return int(self.dut.DOUT.value)

    async def sys_write(self, addr, data, we_mask):
        self.dut.EN.value = 1
        self.dut.ADDR.value = addr
        self.dut.DIN.value = data
        self.dut.WE.value = we_mask
        await self.sys_cycle(1)
        self.dut.WE.value = 0
        await self.sys_cycle(self.read_latency + 1)


@cocotb.test()
async def axi_round_trip_and_sys_read_test(dut):
    tb = TB(dut)
    await tb.reset()

    addr = 0x10
    payload = (0x11223344).to_bytes(4, "little")

    wr_txn = await tb.axil.write(addr, payload)
    expected_resp = AxiResp.OKAY if tb.axi_wr_en else AxiResp.SLVERR
    assert wr_txn.resp == expected_resp

    rd_txn = await tb.axil.read(addr, 4)
    assert rd_txn.resp == AxiResp.OKAY
    expected_data = payload if tb.axi_wr_en else b"\x00\x00\x00\x00"
    assert rd_txn.data == expected_data

    sys_data = await tb.sys_read(addr >> 2)
    assert sys_data == int.from_bytes(expected_data, "little")


@cocotb.test(skip=not env_flag("SYS_WR_EN", default=False))
async def sys_write_visibility_test(dut):
    tb = TB(dut)
    await tb.reset()

    await tb.sys_write(addr=6, data=0xAABBCCDD, we_mask=(1 << tb.byte_count) - 1)
    rd_txn = await tb.axil.read(6 << 2, 4)
    assert rd_txn.resp == AxiResp.OKAY
    assert rd_txn.data == b"\xDD\xCC\xBB\xAA"

    if tb.sys_byte_wr_en:
        # Update only the low two bytes from the system port so the test proves
        # the wrapper preserves byte write enables when requested.
        await tb.sys_write(addr=6, data=0x11223344, we_mask=0x3)
        rd_txn = await tb.axil.read(6 << 2, 4)
        assert rd_txn.resp == AxiResp.OKAY
        assert rd_txn.data == b"\x44\x33\xBB\xAA"


PARAMETER_SWEEP = [
    parameter_case(
        "axi_rw_common_clk",
        EN_ERROR_RESP="true",
        SYNTH_MODE="inferred",
        MEMORY_TYPE="block",
        READ_LATENCY="2",
        AXI_WR_EN="true",
        SYS_WR_EN="false",
        SYS_BYTE_WR_EN="false",
        COMMON_CLK="true",
        ADDR_WIDTH="6",
        DATA_WIDTH="32",
    ),
    parameter_case(
        "dual_port_byte_write_async",
        EN_ERROR_RESP="true",
        SYNTH_MODE="inferred",
        MEMORY_TYPE="block",
        READ_LATENCY="2",
        AXI_WR_EN="true",
        SYS_WR_EN="true",
        SYS_BYTE_WR_EN="true",
        COMMON_CLK="false",
        ADDR_WIDTH="6",
        DATA_WIDTH="32",
    ),
    parameter_case(
        "dual_port_byte_write_latency3_async",
        EN_ERROR_RESP="true",
        SYNTH_MODE="inferred",
        MEMORY_TYPE="block",
        READ_LATENCY="3",
        AXI_WR_EN="true",
        SYS_WR_EN="true",
        SYS_BYTE_WR_EN="true",
        COMMON_CLK="false",
        ADDR_WIDTH="6",
        DATA_WIDTH="32",
    ),
    parameter_case(
        "axi_read_only",
        EN_ERROR_RESP="true",
        SYNTH_MODE="inferred",
        MEMORY_TYPE="block",
        READ_LATENCY="1",
        AXI_WR_EN="false",
        SYS_WR_EN="true",
        SYS_BYTE_WR_EN="false",
        COMMON_CLK="true",
        ADDR_WIDTH="6",
        DATA_WIDTH="32",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiDualPortRam(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axidualportramipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
