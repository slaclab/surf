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
        self.mode = os.environ["MODE_G"]
        self.reg_enabled = env_flag("REG_EN_G", default=True)
        self.byte_write_enabled = env_flag("BYTE_WR_EN_G", default=False)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.num_ports = int(os.environ["NUM_PORTS_G"])
        self.clka_period_ns = float(os.environ["CLKA_PERIOD_NS"])
        self.clkb_period_ns = float(os.environ["CLKB_PERIOD_NS"])
        self.clkc_period_ns = float(os.environ["CLKC_PERIOD_NS"])

        dut.en_a.value = 1
        dut.wea.value = 0
        dut.weaByte.value = 0
        dut.rsta.value = self.reset_inactive_value()
        dut.addra.value = 0
        dut.dina.value = 0

        dut.en_b.value = 1
        dut.rstb.value = self.reset_inactive_value()
        dut.addrb.value = 0

        if self.num_ports >= 3:
            dut.en_c.value = 1
            dut.rstc.value = self.reset_inactive_value()
            dut.addrc.value = 0

        cocotb.start_soon(Clock(dut.clka, self.clka_period_ns, unit="ns").start())
        cocotb.start_soon(Clock(dut.clkb, self.clkb_period_ns, unit="ns").start())
        if self.num_ports >= 3:
            cocotb.start_soon(Clock(dut.clkc, self.clkc_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def full_byte_mask(self) -> int:
        return (1 << len(self.dut.weaByte)) - 1

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

    async def cycle_c(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clkc)
            await self.settle()

    async def warmup(self) -> None:
        # Idle startup cycles make the first readback deterministic across the
        # independently running port clocks.
        await self.cycle_a(1)
        await self.cycle_b(1)
        if self.num_ports >= 3:
            await self.cycle_c(1)

    async def write_a(self, addr: int, value: int, *, byte_mask: int | None = None) -> None:
        self.dut.addra.value = addr
        self.dut.dina.value = value
        self.dut.wea.value = 1
        self.dut.weaByte.value = self.full_byte_mask() if byte_mask is None else byte_mask
        await RisingEdge(self.dut.clka)
        await self.settle()
        self.dut.wea.value = 0
        self.dut.weaByte.value = 0

    async def read_a(self, addr: int) -> int:
        self.dut.addra.value = addr
        if self.reg_enabled:
            await RisingEdge(self.dut.clka)
            await self.settle()
            await RisingEdge(self.dut.clka)
            await self.settle()
        else:
            await self.settle()
        return int(self.dut.douta.value)

    async def read_b(self, addr: int) -> int:
        self.dut.addrb.value = addr
        if self.reg_enabled:
            await RisingEdge(self.dut.clkb)
            await self.settle()
            await RisingEdge(self.dut.clkb)
            await self.settle()
        else:
            await self.settle()
        return int(self.dut.doutb.value)

    async def read_c(self, addr: int) -> int:
        self.dut.addrc.value = addr
        if self.reg_enabled:
            await RisingEdge(self.dut.clkc)
            await self.settle()
            await RisingEdge(self.dut.clkc)
            await self.settle()
        else:
            await self.settle()
        return int(self.dut.doutc.value)


@cocotb.test()
async def multiport_read_visibility_test(dut):
    tb = TB(dut)
    await tb.warmup()

    # Write one location, give the write side one more clock to settle, and
    # then read that location back through the read-only ports.
    await tb.write_a(1, 0x1234)
    await tb.cycle_a(1)

    # All read ports should observe the same stored contents even though only
    # port A has write capability.
    assert await tb.read_b(1) == 0x1234
    if tb.num_ports >= 3:
        assert await tb.read_c(1) == 0x1234


@cocotb.test()
async def mode_semantics_test(dut):
    tb = TB(dut)
    await tb.warmup()
    if not tb.reg_enabled:
        return

    await tb.write_a(0, 0x1111)
    await tb.write_a(1, 0xAAAA)
    assert await tb.read_a(1) == 0xAAAA

    tb.dut.addra.value = 0
    tb.dut.dina.value = 0x2222
    tb.dut.wea.value = 1
    tb.dut.weaByte.value = tb.full_byte_mask()
    await RisingEdge(dut.clka)
    await tb.settle()
    tb.dut.wea.value = 0
    tb.dut.weaByte.value = 0

    if tb.mode == "write-first" and not tb.reg_enabled:
        assert int(dut.douta.value) == 0x2222
    elif tb.mode in {"read-first", "write-first"}:
        assert int(dut.douta.value) == 0x1111
    else:
        assert int(dut.douta.value) == 0xAAAA

    assert await tb.read_b(0) == 0x2222


@cocotb.test()
async def byte_write_enable_test(dut):
    tb = TB(dut)
    await tb.warmup()
    if not tb.byte_write_enabled:
        return

    await tb.write_a(3, 0xABCD)
    await tb.write_a(3, 0x00EF, byte_mask=0b01)
    assert await tb.read_b(3) == 0xABEF

    await tb.write_a(3, 0x1200, byte_mask=0b10)
    assert await tb.read_b(3) == 0x12EF


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.warmup()
    if not tb.reg_enabled:
        return

    await tb.write_a(4, 0xCAFE)
    assert await tb.read_b(4) == 0xCAFE

    await FallingEdge(dut.clkb)
    await Timer(1, unit="ns")
    dut.rstb.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.doutb.value) == 0
    else:
        assert int(dut.doutb.value) == 0xCAFE
        await tb.cycle_b(1)
        assert int(dut.doutb.value) == 0

    dut.rstb.value = tb.reset_inactive_value()
    assert await tb.read_b(4) == 0xCAFE


PARAMETER_SWEEP = [
    parameter_case(
        "comb_multiport",
        REG_EN_G="false",
        MODE_G="no-change",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        NUM_PORTS_G="3",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="7",
        CLKC_PERIOD_NS="11",
    ),
    parameter_case(
        "reg_read_first",
        REG_EN_G="true",
        MODE_G="read-first",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        NUM_PORTS_G="3",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="7",
        CLKC_PERIOD_NS="11",
    ),
    parameter_case(
        "reg_write_first",
        REG_EN_G="true",
        MODE_G="write-first",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        NUM_PORTS_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
        CLKC_PERIOD_NS="5",
    ),
    parameter_case(
        "reg_no_change_byte_write",
        REG_EN_G="true",
        MODE_G="no-change",
        BYTE_WR_EN_G="true",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        NUM_PORTS_G="2",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
        CLKC_PERIOD_NS="5",
    ),
    parameter_case(
        "reg_async_active_low",
        REG_EN_G="true",
        MODE_G="read-first",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        NUM_PORTS_G="2",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="7",
        CLKC_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_LutRam(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.lutram",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
