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
# - Sweep: Sweep the full 10-bit data space plus the curated valid K-code set.
# - Stimulus: Pulse `validIn` for each launched symbol and wait for decode.
# - Checks: The decoded symbol and K flag must match, with no error flags set.
# - Timing: The test synchronizes on `validOut` for each decode result.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import run_surf_vhdl_test


async def initialize_dut(dut) -> None:
    dut.rst.value = 1
    dut.validIn.value = 0
    dut.dataIn.value = 0
    dut.dataKIn.value = 0
    cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def drive_symbol(dut, data_in: int, data_k_in: int) -> None:
    dut.dataIn.value = data_in
    dut.dataKIn.value = data_k_in
    dut.validIn.value = 1
    await RisingEdge(dut.clk)
    dut.validIn.value = 0
    while int(dut.validOut.value) != 1:
        await RisingEdge(dut.clk)


def assert_symbol_round_trip(dut, data_in: int, data_k_in: int) -> None:
    assert int(dut.dataOut.value) == data_in
    assert int(dut.dataKOut.value) == data_k_in
    assert int(dut.codeErr.value) == 0
    assert int(dut.dispErr.value) == 0


@cocotb.test()
async def line_code_10b12b_round_trip_test(dut):
    await initialize_dut(dut)
    for data_in in range(2**10):
        await drive_symbol(dut, data_in, 0)
        assert_symbol_round_trip(dut, data_in, 0)

    for data_in in [0x07C, 0x17C, 0x27C, 0x0BC, 0x0DC, 0x13C, 0x15C, 0x19C, 0x1BC, 0x1DC, 0x23C, 0x25C, 0x29C, 0x2BC, 0x2DC, 0x33C, 0x35C]:
        await drive_symbol(dut, data_in, 1)
        assert_symbol_round_trip(dut, data_in, 1)


PARAMETER_SWEEP = [pytest.param({}, id="default_configuration")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_LineCode10b12b(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.linecode10b12bwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/line-codes/wrappers/LineCode10b12bWrapper.vhd"]},
    )

