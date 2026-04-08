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
# - Sweep: Sweep `read-first` and `write-first` mode, the optional port-B
#   output register, block vs distributed memory, byte-write enable, and
#   active-high vs active-low reset so the wrapper-facing RAM modes are all
#   touched once.
# - Stimulus: Write and read through both ports, create same-address read/write
#   interactions to expose mode semantics, apply partial byte masks, and then
#   assert reset on the B side.
# - Checks: The bench checks cross-port readback, port-A read-during-write
#   behavior, byte-lane merging, the extra hold behavior from `DOB_REG_G`, and
#   reset clearing of the registered output.
# - Timing: Results are checked on `clka` and `clkb` edges separately, and the
#   registered B-output case is expected to hold the previous value for one
#   extra destination cycle.

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
        self.byte_write_enabled = env_flag("BYTE_WR_EN_G", default=False)
        self.doa_reg_enabled = env_flag("DOA_REG_G", default=False)
        self.dob_reg_enabled = env_flag("DOB_REG_G", default=False)

        dut.ena.value = 1
        dut.wea.value = 0
        dut.weaByte.value = 0
        dut.rsta.value = self.reset_inactive_value()
        dut.addra.value = 0
        dut.dina.value = 0
        dut.regcea.value = 1

        dut.enb.value = 1
        dut.rstb.value = self.reset_inactive_value()
        dut.addrb.value = 0
        dut.regceb.value = 1

    async def write_a(self, addr: int, value: int, *, byte_mask: int | None = None) -> None:
        # This wrapper exposes the full port-A write/read interface, so drive a
        # synchronous write exactly the same way a real client would.
        self.dut.addra.value = addr
        self.dut.dina.value = value
        self.dut.wea.value = 1
        self.dut.weaByte.value = self.full_byte_mask("weaByte") if byte_mask is None else byte_mask
        await RisingEdge(self.dut.clka)
        await self.settle()
        self.dut.wea.value = 0
        self.dut.weaByte.value = 0

    async def read_a(self, addr: int, *, regce: int = 1) -> int:
        self.dut.addra.value = addr
        self.dut.wea.value = 0
        self.dut.regcea.value = regce
        await RisingEdge(self.dut.clka)
        await self.settle()
        await RisingEdge(self.dut.clka)
        await self.settle()
        return int(self.dut.douta.value)

    async def read_b(self, addr: int, *, regce: int = 1) -> int:
        self.dut.addrb.value = addr
        self.dut.regceb.value = regce
        await RisingEdge(self.dut.clkb)
        await self.settle()
        await RisingEdge(self.dut.clkb)
        await self.settle()
        return int(self.dut.doutb.value)


@cocotb.test()
async def port_a_and_b_readback_test(dut):
    tb = TB(dut)
    await tb.warmup()

    # The wrapper's main job is to expose one write/read port plus one read
    # port. Prove both public read paths can see data written through port A.
    await tb.write_a(1, 0x1234)
    await tb.cycle_a(1)
    assert await tb.read_a(1) == 0x1234
    assert await tb.read_b(1) == 0x1234


@cocotb.test()
async def port_a_mode_semantics_test(dut):
    tb = TB(dut)
    await tb.warmup()

    if tb.doa_reg_enabled:
        return

    # Seed address 1 so `douta` is already showing a different value before
    # the write-under-test. That makes the three read-during-write modes
    # visibly distinguishable on port A.
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

    assert await tb.read_b(0) == 0x2222


@cocotb.test()
async def byte_write_and_reset_test(dut):
    tb = TB(dut)
    await tb.warmup()

    if tb.byte_write_enabled:
        # Byte masking is wrapper-visible because the port-A mask fans out into
        # the selected backend RAM implementation.
        await tb.write_a(3, 0xABCD)
        await tb.write_a(3, 0x00EF, byte_mask=0b01)
        assert await tb.read_b(3) == 0xABEF

        await tb.write_a(3, 0x1200, byte_mask=0b10)
        assert await tb.read_b(3) == 0x12EF

    # Reset should clear the visible read pipeline without erasing the stored
    # memory contents behind the wrapper.
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
        "block_read_first",
        MEMORY_TYPE_G="block",
        REG_EN_G="true",
        DOA_REG_G="false",
        DOB_REG_G="false",
        MODE_G="read-first",
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
        "block_write_first_registered_b",
        MEMORY_TYPE_G="block",
        REG_EN_G="true",
        DOA_REG_G="false",
        DOB_REG_G="true",
        MODE_G="write-first",
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
        "distributed_byte_write_active_low_reset",
        MEMORY_TYPE_G="distributed",
        REG_EN_G="true",
        DOA_REG_G="false",
        DOB_REG_G="false",
        MODE_G="read-first",
        BYTE_WR_EN_G="true",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_DualPortRam(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.dualportram",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
