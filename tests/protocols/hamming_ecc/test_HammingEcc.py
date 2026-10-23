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
# - Sweep: Exhaustively sweep all 8-bit payloads across injected 0, 1, and 2
#   bit error masks.
# - Stimulus: Drive one encoder input word per transaction with a selected
#   corruption mask applied between encoder and decoder.
# - Checks: Zero-error and one-bit-error cases must recover data correctly;
#   two-bit-error cases must raise the double-bit flag.
# - Timing: Each transaction waits for decoder `obValid` before checking.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import run_surf_vhdl_test


def error_masks(width):
    masks = [0]
    masks.extend(1 << bit for bit in range(width))
    for first in range(width):
        for second in range(first + 1, width):
            masks.append((1 << first) | (1 << second))
    return masks


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.clk, 4.0, unit="ns").start())

    async def reset(self):
        self.dut.rst.setimmediatevalue(1)
        self.dut.ibValid.setimmediatevalue(0)
        self.dut.ibData.setimmediatevalue(0)
        self.dut.bitErrorMask.setimmediatevalue(0)
        for _ in range(4):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        for _ in range(2):
            await RisingEdge(self.dut.clk)

    async def transact(self, data, mask):
        self.dut.ibData.value = data
        self.dut.bitErrorMask.value = mask
        self.dut.ibValid.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.ibValid.value = 0
        while int(self.dut.obValid.value) != 1:
            await RisingEdge(self.dut.clk)
        return (
            int(self.dut.obData.value),
            int(self.dut.obErrSbit.value),
            int(self.dut.obErrDbit.value),
        )


@cocotb.test()
async def hamming_ecc_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()
    mask_width = len(dut.bitErrorMask)

    for data in range(1 << len(dut.ibData)):
        for mask in error_masks(mask_width):
            ob_data, err_sbit, err_dbit = await tb.transact(data, mask)
            bit_count = mask.bit_count()
            if bit_count == 0:
                assert ob_data == data
                assert err_sbit == 0
                assert err_dbit == 0
            elif bit_count == 1:
                assert ob_data == data
                assert err_sbit == 1
                assert err_dbit == 0
            else:
                assert err_dbit == 1


PARAMETER_SWEEP = [pytest.param({}, id="default_data_width")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_HammingEcc(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.hammingeccwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/hamming-ecc/wrappers/HammingEccWrapper.vhd"]},
    )
