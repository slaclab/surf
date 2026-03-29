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
# - Sweep: Sweep one- and two-byte encoder/decoder round-trip cases.
# - Stimulus: Launch all data symbols followed by the supported K-code set.
# - Checks: The decoded symbol must match the launched value with no code or
#   disparity errors.
# - Timing: The test waits on `validOut` rather than assuming fixed latency.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import hdl_parameters_from, parameter_case, run_surf_vhdl_test


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
async def line_code_8b10b_round_trip_test(dut):
    await initialize_dut(dut)
    width = int(dut.NUM_BYTES_G.value)
    for data_in in range(2 ** (8 * width)):
        await drive_symbol(dut, data_in, 0)
        assert_symbol_round_trip(dut, data_in, 0)

    for data_in in [0x1C, 0x3C, 0x5C, 0x7C, 0x9C, 0xBC, 0xDC, 0xFC, 0xF7, 0xFB, 0xFD, 0xFE]:
        await drive_symbol(dut, data_in, 1)
        assert_symbol_round_trip(dut, data_in, 1)


PARAMETER_SWEEP = [
    parameter_case("single_byte", NUM_BYTES_G="1"),
    parameter_case("dual_byte", NUM_BYTES_G="2"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_LineCode8b10b(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.linecode8b10bwrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/line-codes/wrappers/LineCode8b10bWrapper.vhd"]},
    )

