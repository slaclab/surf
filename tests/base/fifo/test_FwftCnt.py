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
# - Sweep: Cover the legacy FWFT FIFO count sweep across sync/async and
#   block/distributed memory configurations.
# - Stimulus: Fill the FIFO with an incrementing sequence, allow counts to
#   settle, then drain it while checking the FWFT data path.
# - Checks: No overflow/underflow may occur, data ordering must match, and
#   the write/read counters must return to zero.
# - Timing: One write or read decision is made per clock edge after reset.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test


class TB:
    def __init__(self, dut, depth):
        self.dut = dut
        self.depth = depth
        cocotb.start_soon(Clock(dut.clk, 10.0, unit="ns").start())

    async def reset(self):
        self.dut.rst.setimmediatevalue(1)
        self.dut.wr_en.setimmediatevalue(0)
        self.dut.rd_en.setimmediatevalue(0)
        self.dut.din.setimmediatevalue(0)
        for _ in range(110):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        for _ in range(4):
            await RisingEdge(self.dut.clk)


@cocotb.test()
async def fwft_fifo_count_test(dut):
    memory_type = os.getenv("MEMORY_TYPE_G", "block")
    depth = 2 ** (5 if memory_type == "distributed" else 9)
    tb = TB(dut, depth)
    await tb.reset()

    for value in range(1, depth + 1):
        while int(dut.full.value) == 1:
            await RisingEdge(dut.clk)
        dut.din.value = value
        dut.wr_en.value = 1
        await RisingEdge(dut.clk)
        dut.wr_en.value = 0
        assert int(dut.overflow.value) == 0

    for _ in range(4):
        await RisingEdge(dut.clk)

    for _ in range(16):
        await RisingEdge(dut.clk)

    assert int(dut.wr_data_count.value) >= depth - 1
    assert int(dut.rd_data_count.value) >= depth - 2

    expected = 1
    while expected <= depth:
        while int(dut.valid.value) != 1:
            await RisingEdge(dut.clk)
        assert int(dut.dout.value) == expected
        dut.rd_en.value = 1
        await RisingEdge(dut.clk)
        dut.rd_en.value = 0
        assert int(dut.underflow.value) == 0
        await RisingEdge(dut.clk)
        expected += 1

    for _ in range(4):
        await RisingEdge(dut.clk)

    assert int(dut.wr_data_count.value) == 0
    assert int(dut.rd_data_count.value) == 0
    assert int(dut.empty.value) == 1


PARAMETER_SWEEP = [
    parameter_case("sync_block", GEN_SYNC_FIFO_G=True, MEMORY_TYPE_G="block"),
    parameter_case("sync_distributed", GEN_SYNC_FIFO_G=True, MEMORY_TYPE_G="distributed"),
    parameter_case("async_block", GEN_SYNC_FIFO_G=False, MEMORY_TYPE_G="block"),
    parameter_case("async_distributed", GEN_SYNC_FIFO_G=False, MEMORY_TYPE_G="distributed"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_FwftCnt(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.fwftcntwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["base/fifo/wrappers/FwftCntWrapper.vhd"]},
    )
