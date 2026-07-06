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
# - Sweep: Sweep legacy inferred block vs distributed attributes, optional
#   `DOB` output registration, explicit inferred synthesis selection/read
#   latency, byte-write enable, and asynchronous plus active-low reset behavior.
# - Stimulus: Write through port A and read through port B, apply partial byte
#   masks to an existing word, optionally hold port-B enable low in direct and
#   registered-output modes, and then reset after a registered output has
#   captured data.
# - Checks: The bench checks basic dual-port readback, byte-write merging, hold
#   behavior of the optional B output register, and reset clearing of that
#   registered output.
# - Timing: The inferred SimpleDualPortRam implementation is synchronous-read
#   for every MEMORY_TYPE_G value. Latency is checked across separate A and B
#   clocks, with one additional cycle expected when the B-side output register
#   is enabled directly or through READ_LATENCY_G = 2.

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
        # This DUT has two independent clocks, so the cocotb testbench needs to
        # drive both domains explicitly.
        self.byte_write_enabled = env_flag("BYTE_WR_EN_G", default=False)
        self.read_latency = int(os.environ.get("READ_LATENCY_G", "1"))
        self.dob_reg_enabled = env_flag("DOB_REG_G", default=False) or self.read_latency == 2

        # Initialize every DUT input to a known idle state before time starts.
        dut.ena.value = 1
        dut.wea.value = 0
        dut.weaByte.value = 0
        dut.addra.value = 0
        dut.dina.value = 0
        dut.enb.value = 1
        dut.regceb.value = 1
        dut.rstb.value = self.reset_inactive_value()
        dut.addrb.value = 0

    async def write_word(self, addr: int, value: int, *, byte_mask: int | None = None) -> None:
        # Present address/data first, then pulse the write-enable for one
        # `clka` edge. That mirrors the synchronous write behavior of the RTL.
        self.dut.addra.value = addr
        self.dut.dina.value = value
        self.dut.wea.value = 1
        self.dut.weaByte.value = self.full_byte_mask("weaByte") if byte_mask is None else byte_mask
        await RisingEdge(self.dut.clka)
        await self.settle()
        # Drop the strobes after the write edge so the next cycle starts clean.
        self.dut.wea.value = 0
        self.dut.weaByte.value = 0

    async def read_word(self, addr: int, *, regceb: int = 1) -> int:
        # Set the port-B controls, then wait for the read pipeline to produce
        # data. The helper intentionally waits a little longer than the minimum
        # latency so one helper works for both direct and registered outputs.
        self.dut.addrb.value = addr
        self.dut.enb.value = 1
        self.dut.regceb.value = regceb

        # Sampling one extra clock keeps the helper stable across both the
        # direct and registered readback configurations.
        await RisingEdge(self.dut.clkb)
        await self.settle()
        await RisingEdge(self.dut.clkb)
        await self.settle()

        return int(self.dut.doutb.value)


@cocotb.test()
async def basic_read_write_test(dut):
    tb = TB(dut)
    # Give both clocks one warm-up cycle before the first transaction.
    await tb.cycle_a(1)
    await tb.cycle_b(1)

    # Write one word through port A and read it back through port B.
    await tb.write_word(1, 0x1234)
    await tb.cycle_a(1)
    assert await tb.read_word(1) == 0x1234


@cocotb.test()
async def byte_write_enable_test(dut):
    tb = TB(dut)
    if not tb.byte_write_enabled:
        return

    # First write a full word, then overwrite only one byte at a time to prove
    # the byte-mask wiring is being honored.
    await tb.write_word(2, 0xABCD)
    await tb.write_word(2, 0x00EF, byte_mask=0b01)
    assert await tb.read_word(2) == 0xABEF

    await tb.write_word(2, 0x1200, byte_mask=0b10)
    assert await tb.read_word(2) == 0x12EF


@cocotb.test()
async def read_enable_hold_test(dut):
    if not env_flag("CHECK_READ_ENABLE_HOLD", default=False):
        return

    tb = TB(dut)
    await tb.cycle_a(1)
    await tb.cycle_b(1)

    await tb.write_word(0, 0x1111)
    await tb.write_word(1, 0x2222)
    assert await tb.read_word(0) == 0x1111

    # Port B should hold its previous output while `enb` is low, even if the
    # address changes underneath it.
    dut.enb.value = 0
    dut.addrb.value = 1
    await tb.cycle_b(2)
    assert int(dut.doutb.value) == 0x1111

    dut.enb.value = 1
    assert await tb.read_word(1) == 0x2222


@cocotb.test()
async def registered_read_enable_hold_test(dut):
    if not env_flag("CHECK_REGISTERED_ENB_HOLD", default=False):
        return

    tb = TB(dut)
    await tb.cycle_a(1)
    await tb.cycle_b(1)
    assert tb.dob_reg_enabled

    await tb.write_word(0, 0x1111)
    await tb.write_word(1, 0x2222)
    assert await tb.read_word(0) == 0x1111

    # With DOB_REG_G enabled, `enb=0` should hold the registered B output even
    # while the address changes and port A updates the addressed memory word.
    dut.enb.value = 0
    dut.addrb.value = 1
    await tb.write_word(1, 0x3333)
    await tb.cycle_b(3)
    assert int(dut.doutb.value) == 0x1111

    dut.enb.value = 1
    assert await tb.read_word(1) == 0x3333


@cocotb.test()
async def registered_output_hold_test(dut):
    tb = TB(dut)
    if not tb.dob_reg_enabled:
        return

    # Seed two addresses so we can prove the output register can hold its old
    # value even after the read address changes.
    await tb.write_word(0, 0x1111)
    await tb.write_word(1, 0x2222)

    assert await tb.read_word(0) == 0x1111

    # With `regceb=0`, the registered output should keep presenting the old
    # value even though the address has changed underneath it.
    tb.dut.addrb.value = 1
    tb.dut.regceb.value = 0
    await tb.cycle_b(2)
    assert int(tb.dut.doutb.value) == 0x1111

    # Re-enabling `regceb` should allow the new address's value to appear.
    tb.dut.regceb.value = 1
    await tb.cycle_b(1)
    assert int(tb.dut.doutb.value) == 0x2222


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)

    # Load one known value so reset behavior can be observed clearly.
    await tb.write_word(4, 0xCAFE)
    assert await tb.read_word(4) == 0xCAFE

    # Assert reset away from the active clock edge so sync and async reset
    # styles can be distinguished.
    await FallingEdge(dut.clkb)
    await Timer(1, unit="ns")
    dut.rstb.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        # Async reset should clear the read datapath immediately.
        assert int(dut.doutb.value) == 0
    else:
        # Sync reset should not take effect until the next clock edge.
        assert int(dut.doutb.value) == 0xCAFE
        await tb.cycle_b(1)
        assert int(dut.doutb.value) == 0

    # Reset only clears the output pipeline; the RAM contents should still be
    # readable after reset releases.
    dut.rstb.value = tb.reset_inactive_value()
    assert await tb.read_word(4) == 0xCAFE


PARAMETER_SWEEP = [
    parameter_case(
        "block_baseline",
        MEMORY_TYPE_G="block",
        SYNTH_MODE_G="inferred",
        READ_LATENCY_G="1",
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
        "distributed_dob_reg",
        MEMORY_TYPE_G="distributed",
        SYNTH_MODE_G="inferred",
        READ_LATENCY_G="1",
        DOB_REG_G="true",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CHECK_REGISTERED_ENB_HOLD="1",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
    parameter_case(
        "byte_write_enable",
        MEMORY_TYPE_G="block",
        SYNTH_MODE_G="inferred",
        READ_LATENCY_G="1",
        DOB_REG_G="false",
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
        "async_reset",
        MEMORY_TYPE_G="distributed",
        SYNTH_MODE_G="inferred",
        READ_LATENCY_G="1",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="7",
    ),
    parameter_case(
        "active_low_reset",
        MEMORY_TYPE_G="block",
        SYNTH_MODE_G="inferred",
        READ_LATENCY_G="1",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
    parameter_case(
        "read_enable_hold",
        MEMORY_TYPE_G="block",
        SYNTH_MODE_G="inferred",
        READ_LATENCY_G="1",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CHECK_READ_ENABLE_HOLD="1",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
    parameter_case(
        "block_read_latency_registered",
        MEMORY_TYPE_G="block",
        SYNTH_MODE_G="inferred",
        READ_LATENCY_G="2",
        DOB_REG_G="false",
        BYTE_WR_EN_G="false",
        DATA_WIDTH_G="16",
        BYTE_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CHECK_REGISTERED_ENB_HOLD="1",
        CLKA_PERIOD_NS="5",
        CLKB_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SimpleDualPortRam(parameters):
    # Launch one simulator run for each interesting generic combination.
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.simpledualportram",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
