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
# - Sweep: Sweep the full 10-bit data space and the legal K.28.x subset for
#   both legacy disparity seeds used by the VHDL package bench.
# - Stimulus: Drive the package-procedure wrapper combinationally with one
#   symbol and one explicit `dispIn` seed at a time.
# - Checks: The encoded symbol must decode back to the launched data and K
#   flag with no code or disparity errors, matching `Code10b12bTb.vhd`.
# - Timing: The wrapper is combinational, so the test yields one delta cycle
#   after each input update before sampling outputs.

import cocotb
import pytest

from tests.protocols.line_codes.line_code_test_utils import (
    default_wrapper_parameter_sweep,
    run_line_code_wrapper_test,
    settle_combinational_line_code_wrapper,
)


DISPARITY_SEEDS = [0, 1]
K_SYMBOLS_10B12B = [
    0x07C, 0x17C, 0x27C, 0x0BC, 0x0DC, 0x13C, 0x15C, 0x19C, 0x1BC,
    0x1DC, 0x23C, 0x25C, 0x29C, 0x2BC, 0x2DC, 0x33C, 0x35C,
]


async def drive_package_symbol(dut, *, disp_in: int, data_in: int, data_k_in: int) -> None:
    dut.dispIn.value = disp_in
    dut.dataIn.value = data_in
    dut.dataKIn.value = data_k_in
    await settle_combinational_line_code_wrapper()


def assert_package_round_trip(dut, *, disp_in: int, data_in: int, data_k_in: int) -> None:
    assert int(dut.decodedData.value) == data_in
    assert int(dut.decodedK.value) == data_k_in
    assert int(dut.codeError.value) == 0
    assert int(dut.dispError.value) == 0
    # The package bench explicitly decodes with the same seed that encoded the
    # word, so the decoder's next disparity should match the encoder's output.
    assert int(dut.encodedDisp.value) == int(dut.decodedDisp.value) == int(dut.encodedDisp.value)
    assert int(dut.encodedDisp.value) in {0, 1}


@cocotb.test()
async def code_10b12b_package_round_trip_test(dut):
    for disp_in in DISPARITY_SEEDS:
        for data_in in range(2**10):
            await drive_package_symbol(dut, disp_in=disp_in, data_in=data_in, data_k_in=0)
            assert_package_round_trip(dut, disp_in=disp_in, data_in=data_in, data_k_in=0)

        for data_in in K_SYMBOLS_10B12B:
            await drive_package_symbol(dut, disp_in=disp_in, data_in=data_in, data_k_in=1)
            assert_package_round_trip(dut, disp_in=disp_in, data_in=data_in, data_k_in=1)


PARAMETER_SWEEP = default_wrapper_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Code10b12bPkg(parameters):
    run_line_code_wrapper_test(
        test_file=__file__,
        toplevel="surf.code10b12bpkgwrapper",
        wrapper_source="protocols/line-codes/wrappers/Code10b12bPkgWrapper.vhd",
        parameters=parameters,
    )
