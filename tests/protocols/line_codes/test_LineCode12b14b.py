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
# - Sweep: Sweep the full 12-bit data space, the supported K-code set, and the
#   historical mixed data/control training pattern.
# - Stimulus: Launch one symbol at a time with a one-cycle `validIn` pulse.
# - Checks: The symbol and K flag must round-trip exactly with no decode errors.
# - Timing: The test waits for `validOut` before every result check.

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
async def line_code_12b14b_round_trip_test(dut):
    await initialize_dut(dut)
    for data_in in range(2**12):
        await drive_symbol(dut, data_in, 0)
        assert_symbol_round_trip(dut, data_in, 0)

    for data_in in [0x078, 0x0F8, 0x178, 0x1F8, 0x278, 0x3F8, 0x478, 0x5F8, 0x878, 0x9F8, 0xBF8, 0xC78, 0xDF8, 0xEF8, 0xF78, 0xFF8]:
        await drive_symbol(dut, data_in, 1)
        assert_symbol_round_trip(dut, data_in, 1)

    training_pattern = [
        (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1),
        (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1),
        (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x078, 1), (0x5F8, 1), (0xEAD, 0),
        (0x0BD, 0), (0xEAD, 0), (0x1BD, 0), (0xEAD, 0), (0x2BD, 0), (0xEAD, 0),
        (0x3BD, 0), (0xEAD, 0), (0x4BD, 0), (0xEAD, 0), (0x5BD, 0), (0xEAD, 0),
        (0x6BD, 0), (0xEAD, 0), (0x7BD, 0), (0xEAD, 0), (0x8BD, 0), (0xEAD, 0),
        (0x9BD, 0), (0xEAD, 0), (0xABD, 0), (0xEAD, 0), (0xBBD, 0), (0x5F8, 1),
        (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1),
    ]
    for data_in, data_k_in in training_pattern:
        await drive_symbol(dut, data_in, data_k_in)
        assert_symbol_round_trip(dut, data_in, data_k_in)


PARAMETER_SWEEP = [pytest.param({}, id="default_configuration")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_LineCode12b14b(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.linecode12b14bwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/line-codes/wrappers/LineCode12b14bWrapper.vhd"]},
    )
