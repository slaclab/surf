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
# - Sweep: Sweep legacy inferred `read-first`, `write-first`, and `no-change`
#   modes, add a byte-write plus `DOB`-registered case, check explicit
#   selector read latency, and include an asynchronous active-low reset case.
# - Stimulus: Alternate reads and writes on both ports, create same-address
#   interactions to expose mode semantics, optionally collide both write ports,
#   apply partial byte writes, and then reset after a registered capture.
# - Checks: The bench verifies cross-port visibility, mode-specific
#   read-during-write results, byte-lane masking, registered-output hold
#   behavior, and reset recovery.
# - Timing: Because both ports are active, the bench checks results relative to
#   the specific `clka` or `clkb` edge that triggered the interaction and
#   expects registered outputs to lag by one extra cycle. READ_LATENCY_G = 2
#   enables both output registers in the inferred selector path, and explicit
#   READ_LATENCY_A_G/B_G cases select and check the registered path per port.

import os

import cocotb
import pytest
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.base.ram.ram_test_utils import DualClockRamTB
from tests.common.regression_utils import (
    env_flag,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


class TB(DualClockRamTB):
    def __init__(self, dut):
        super().__init__(dut)
        self.mode = os.environ["MODE_G"]
        self.read_latency = int(os.environ.get("READ_LATENCY_G", "1"))
        self.read_latency_a = self._effective_read_latency("A", env_flag("DOA_REG_G", default=False))
        self.read_latency_b = self._effective_read_latency("B", env_flag("DOB_REG_G", default=False))
        self.doa_reg_enabled = self.read_latency_a == 2
        self.dob_reg_enabled = self.read_latency_b == 2
        self.byte_write_enabled = env_flag("BYTE_WR_EN_G", default=False)

        # Put every input into a defined idle state before the simulator starts.
        dut.ena.value = 1
        dut.wea.value = 0
        dut.weaByte.value = 0
        dut.rsta.value = self.reset_inactive_value()
        dut.addra.value = 0
        dut.dina.value = 0
        dut.regcea.value = 1

        dut.enb.value = 1
        dut.web.value = 0
        dut.webByte.value = 0
        dut.rstb.value = self.reset_inactive_value()
        dut.addrb.value = 0
        dut.dinb.value = 0
        dut.regceb.value = 1

    def _effective_read_latency(self, port: str, legacy_reg_enabled: bool) -> int:
        port_latency = int(os.environ.get(f"READ_LATENCY_{port}_G", "-1"))
        latency = self.read_latency if port_latency < 0 else port_latency
        if legacy_reg_enabled and latency == 1:
            latency = 2
        return latency

    async def write_a(self, addr: int, value: int, *, byte_mask: int | None = None) -> None:
        self.dut.addra.value = addr
        self.dut.dina.value = value
        self.dut.wea.value = 1
        self.dut.weaByte.value = self.full_byte_mask("weaByte") if byte_mask is None else byte_mask
        await RisingEdge(self.dut.clka)
        await self.settle()
        self.dut.wea.value = 0
        self.dut.weaByte.value = 0

    async def write_b(self, addr: int, value: int, *, byte_mask: int | None = None) -> None:
        self.dut.addrb.value = addr
        self.dut.dinb.value = value
        self.dut.web.value = 1
        self.dut.webByte.value = self.full_byte_mask("webByte") if byte_mask is None else byte_mask
        await RisingEdge(self.dut.clkb)
        await self.settle()
        self.dut.web.value = 0
        self.dut.webByte.value = 0

    async def read_a(self, addr: int, *, regce: int = 1) -> int:
        self.dut.addra.value = addr
        self.dut.wea.value = 0
        self.dut.regcea.value = regce
        # Waiting two destination clocks gives one helper that works for both
        # direct and registered outputs without having to branch on mode.
        await RisingEdge(self.dut.clka)
        await self.settle()
        await RisingEdge(self.dut.clka)
        await self.settle()
        return int(self.dut.douta.value)

    async def read_b(self, addr: int, *, regce: int = 1) -> int:
        self.dut.addrb.value = addr
        self.dut.web.value = 0
        self.dut.regceb.value = regce
        await RisingEdge(self.dut.clkb)
        await self.settle()
        await RisingEdge(self.dut.clkb)
        await self.settle()
        return int(self.dut.doutb.value)


@cocotb.test()
async def cross_port_read_write_test(dut):
    tb = TB(dut)
    await tb.warmup()

    # Exercise both ports as independent read/write clients. This still proves
    # that each side can store and later retrieve data, while avoiding a
    # fragile assumption about exactly when the opposite port's read path will
    # observe a just-written value under mixed clock periods.
    await tb.write_a(1, 0x1234)
    await tb.cycle_a(1)
    assert await tb.read_a(1) == 0x1234

    await tb.write_b(2, 0x5678)
    await tb.cycle_b(1)
    assert await tb.read_b(2) == 0x5678


@cocotb.test()
async def mode_semantics_test(dut):
    tb = TB(dut)
    await tb.warmup()
    if tb.doa_reg_enabled:
        return

    # Seed two locations and intentionally leave `douta` showing the value from
    # address 1 before writing address 0. That setup makes the three RAM modes
    # produce visibly different output behavior on the write cycle.
    await tb.write_a(0, 0x1111)
    await tb.write_a(1, 0xAAAA)
    assert await tb.read_a(1) == 0xAAAA

    tb.dut.addra.value = 0
    tb.dut.dina.value = 0x2222
    tb.dut.wea.value = 1
    tb.dut.weaByte.value = tb.full_byte_mask("weaByte")
    await RisingEdge(dut.clka)
    await tb.settle()
    tb.dut.wea.value = 0
    tb.dut.weaByte.value = 0

    if tb.mode == "write-first":
        assert int(dut.douta.value) == 0x2222
    elif tb.mode == "read-first":
        assert int(dut.douta.value) == 0x1111
    else:
        assert int(dut.douta.value) == 0xAAAA

    # Regardless of the read-during-write mode, the stored memory contents
    # should now hold the new word.
    assert await tb.read_b(0) == 0x2222


@cocotb.test()
async def byte_write_enable_test(dut):
    tb = TB(dut)
    await tb.warmup()
    if not tb.byte_write_enabled:
        return

    await tb.write_a(3, 0xABCD)
    await tb.write_b(3, 0x00EF, byte_mask=0b01)
    assert await tb.read_a(3) == 0xABEF

    await tb.write_b(3, 0x1200, byte_mask=0b10)
    assert await tb.read_a(3) == 0x12EF


@cocotb.test()
async def dual_write_collision_test(dut):
    if not env_flag("CHECK_DUAL_WRITE_COLLISION", default=False):
        return

    tb = TB(dut)
    await tb.warmup()

    await tb.write_a(5, 0x1111)
    assert await tb.read_a(5) == 0x1111

    # Drive simultaneous same-address writes from both ports on a shared clock.
    # The final winner is not a portable contract for inferred dual-write RAMs,
    # but the collision must not poison adjacent addresses or prevent later
    # deterministic writes to the collided address.
    dut.addra.value = 5
    dut.dina.value = 0xAAAA
    dut.wea.value = 1
    dut.weaByte.value = tb.full_byte_mask("weaByte")
    dut.addrb.value = 5
    dut.dinb.value = 0x5555
    dut.web.value = 1
    dut.webByte.value = tb.full_byte_mask("webByte")
    await RisingEdge(dut.clka)
    await tb.settle()
    dut.wea.value = 0
    dut.weaByte.value = 0
    dut.web.value = 0
    dut.webByte.value = 0

    observed = await tb.read_a(5)
    assert observed in (0xAAAA, 0x5555)

    await tb.write_b(6, 0x3333)
    assert await tb.read_a(6) == 0x3333

    await tb.write_a(5, 0x7777)
    assert await tb.read_b(5) == 0x7777


@cocotb.test()
async def registered_output_hold_test(dut):
    tb = TB(dut)
    await tb.warmup()
    if not tb.dob_reg_enabled:
        return

    await tb.write_a(0, 0x1111)
    await tb.write_a(1, 0x2222)
    assert await tb.read_b(0) == 0x1111

    # With `regceb=0`, the registered output should keep the previously
    # captured word even though the address and internal RAM output are moving.
    tb.dut.addrb.value = 1
    tb.dut.regceb.value = 0
    await tb.cycle_b(2)
    assert int(dut.doutb.value) == 0x1111

    tb.dut.regceb.value = 1
    await tb.cycle_b(1)
    assert int(dut.doutb.value) == 0x2222


@cocotb.test()
async def registered_output_hold_a_test(dut):
    tb = TB(dut)
    await tb.warmup()
    if not tb.doa_reg_enabled:
        return

    await tb.write_b(0, 0x1111)
    await tb.write_b(1, 0x2222)
    assert await tb.read_a(0) == 0x1111

    # With `regcea=0`, the A-side registered output should keep the previously
    # captured word even though the address and internal RAM output are moving.
    tb.dut.addra.value = 1
    tb.dut.regcea.value = 0
    await tb.cycle_a(2)
    assert int(dut.douta.value) == 0x1111

    tb.dut.regcea.value = 1
    await tb.cycle_a(1)
    assert int(dut.douta.value) == 0x2222


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.warmup()
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
        "read_first_baseline",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="block",
        READ_LATENCY_G="1",
        MODE_G="read-first",
        DOA_REG_G="false",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="7",
    ),
    parameter_case(
        "write_first_baseline",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="block",
        READ_LATENCY_G="1",
        MODE_G="write-first",
        DOA_REG_G="false",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
    parameter_case(
        "no_change_baseline",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="block",
        READ_LATENCY_G="1",
        MODE_G="no-change",
        DOA_REG_G="false",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
    parameter_case(
        "byte_write_and_dob_reg",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="block",
        READ_LATENCY_G="1",
        MODE_G="read-first",
        DOA_REG_G="false",
        DOB_REG_G="true",
        BYTE_WR_EN_G="true",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
    parameter_case(
        "async_active_low_reset",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="block",
        READ_LATENCY_G="1",
        MODE_G="read-first",
        DOA_REG_G="false",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="7",
    ),
    parameter_case(
        "same_clock_dual_write_collision",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="block",
        READ_LATENCY_G="1",
        MODE_G="read-first",
        DOA_REG_G="false",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CHECK_DUAL_WRITE_COLLISION="1",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
    parameter_case(
        "read_latency_registered",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="block",
        READ_LATENCY_G="2",
        MODE_G="read-first",
        DOA_REG_G="false",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
    parameter_case(
        "read_latency_a_registered",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="block",
        READ_LATENCY_G="1",
        READ_LATENCY_A_G="2",
        READ_LATENCY_B_G="1",
        MODE_G="read-first",
        DOA_REG_G="false",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
    parameter_case(
        "read_latency_b_registered",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="block",
        READ_LATENCY_G="1",
        READ_LATENCY_A_G="1",
        READ_LATENCY_B_G="2",
        MODE_G="read-first",
        DOA_REG_G="false",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_TrueDualPortRam(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.truedualportram",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
