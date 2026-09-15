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
# - Sweep: Keep a two-case leaf sweep covering synchronous active-high reset
#   and asynchronous active-low reset with small multi-register maps so the
#   bench proves both address windows without exploding the generic space.
# - Stimulus: Drive AXI-Lite reads from the read-register window, issue full
#   and partial writes into the write-register window, and then reassert reset
#   after the write outputs have taken visible state.
# - Checks: Read transactions must return the flattened input registers, write
#   transactions must update the correct output register bytes at `0x100+4*i`,
#   unmapped accesses must return `DECERR`, and reset must restore the write
#   outputs to their initialized zero state.
# - Timing: The bench samples outputs after bounded clock waits around each
#   AXI-Lite completion so the checks line up with the registered endpoint
#   behavior instead of assuming combinational updates.

import os

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import env_flag, env_sl, parameter_case, run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.num_write_regs = int(os.environ["NUM_WRITE_REG_G"])
        self.num_read_regs = int(os.environ["NUM_READ_REG_G"])
        self.reset_async = env_flag("RST_ASYNC_G", default=False)
        self.reset_active = env_sl("RST_POLARITY_G", default=1)

        cocotb.start_soon(Clock(dut.axilClk, 5.0, unit="ns").start())

        dut.axilRst.setimmediatevalue(self.reset_active_value())
        dut.readRegisterIn.setimmediatevalue(0)

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

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axilClk)

    async def reset(self):
        # Hold the flattened register inputs stable while reset is asserted so
        # the endpoint comes out of reset with a deterministic register image.
        self.dut.axilRst.setimmediatevalue(self.reset_active_value())
        await self.cycle(3)
        self.dut.axilRst.value = self.reset_inactive_value()
        await self.cycle(3)

    def set_read_regs(self, values):
        packed = 0
        for index, value in enumerate(values):
            packed |= (value & 0xFFFF_FFFF) << (index * 32)
        self.dut.readRegisterIn.value = packed

    def get_write_reg(self, index):
        packed = int(self.dut.writeRegisterOut.value)
        return (packed >> (index * 32)) & 0xFFFF_FFFF


@cocotb.test()
async def read_and_write_window_test(dut):
    tb = TB(dut)
    read_values = [0x11223344, 0x55667788, 0xAABBCCDD][: tb.num_read_regs]
    tb.set_read_regs(read_values)
    await tb.reset()

    for index in range(tb.num_read_regs):
        rd_txn = await tb.axil.read(index * 4, 4)
        assert rd_txn.resp == AxiResp.OKAY
        assert rd_txn.data == read_values[index].to_bytes(4, "little")

    wr_txn = await tb.axil.write(0x100, b"\x44\x33\x22\x11")
    assert wr_txn.resp == AxiResp.OKAY
    await tb.cycle(2)
    assert tb.get_write_reg(0) == 0x11223344

    if tb.num_write_regs > 1:
        wr_txn = await tb.axil.write(0x104, b"\xAA\xBB\xCC\xDD")
        assert wr_txn.resp == AxiResp.OKAY
        await tb.cycle(2)
        assert tb.get_write_reg(1) == 0xDDCC_BBAA

    rd_txn = await tb.axil.read(0x080, 4)
    assert rd_txn.resp == AxiResp.DECERR


@cocotb.test()
async def reset_clears_write_outputs_test(dut):
    tb = TB(dut)
    tb.set_read_regs([0x01020304] * tb.num_read_regs)
    await tb.reset()

    await tb.axil.write(0x100, b"\xEF\xBE\xAD\xDE")
    if tb.num_write_regs > 1:
        await tb.axil.write(0x104, b"\x78\x56\x34\x12")
    await tb.cycle(2)

    assert tb.get_write_reg(0) == 0xDEADBEEF

    tb.dut.axilRst.value = tb.reset_active_value()
    await tb.cycle(3)
    assert tb.get_write_reg(0) == 0
    if tb.num_write_regs > 1:
        assert tb.get_write_reg(1) == 0

    tb.dut.axilRst.value = tb.reset_inactive_value()
    await tb.cycle(3)


PARAMETER_SWEEP = [
    parameter_case(
        "sync_active_high",
        NUM_WRITE_REG_G="2",
        NUM_READ_REG_G="3",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "async_active_low",
        NUM_WRITE_REG_G="1",
        NUM_READ_REG_G="2",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiLiteRegs(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiliteregsipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
