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
# - Sweep: Sweep the full 8-bit data space and the legal 8b10b K-code set for
#   both disparity seeds used by the package procedures.
# - Stimulus: Drive a combinational wrapper around `encode8b10b` and
#   `decode8b10b` with one symbol and one explicit `dispIn` seed at a time.
# - Checks: The decoded symbol, K flag, and next disparity must round-trip
#   with no code or disparity errors, adding direct package coverage beyond
#   the clocked encoder/decoder wrapper bench.
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
K_SYMBOLS_8B10B = [
    0x1C, 0x3C, 0x5C, 0x7C, 0x9C, 0xBC, 0xDC, 0xFC, 0xF7, 0xFB, 0xFD, 0xFE,
]


async def drive_package_symbol(dut, *, disp_in: int, data_in: int, data_k_in: int) -> None:
    dut.dispIn.value = disp_in
    dut.dataIn.value = data_in
    dut.dataKIn.value = data_k_in
    await settle_combinational_line_code_wrapper()


def assert_package_round_trip(dut, *, data_in: int, data_k_in: int) -> None:
    assert int(dut.decodedData.value) == data_in
    assert int(dut.decodedK.value) == data_k_in
    assert int(dut.codeError.value) == 0
    assert int(dut.dispError.value) == 0
    # The package wrapper decodes the just-encoded symbol with the same seed,
    # so the decoder's published next disparity should match the encoder's.
    assert int(dut.encodedDisp.value) == int(dut.decodedDisp.value)
    assert int(dut.encodedDisp.value) in {0, 1}


@cocotb.test()
async def code_8b10b_package_round_trip_test(dut):
    for disp_in in DISPARITY_SEEDS:
        for data_in in range(2**8):
            await drive_package_symbol(dut, disp_in=disp_in, data_in=data_in, data_k_in=0)
            assert_package_round_trip(dut, data_in=data_in, data_k_in=0)

        for data_in in K_SYMBOLS_8B10B:
            await drive_package_symbol(dut, disp_in=disp_in, data_in=data_in, data_k_in=1)
            assert_package_round_trip(dut, data_in=data_in, data_k_in=1)


PARAMETER_SWEEP = default_wrapper_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Code8b10bPkg(parameters):
    run_line_code_wrapper_test(
        test_file=__file__,
        toplevel="surf.code8b10bpkgwrapper",
        wrapper_source="protocols/line-codes/wrappers/Code8b10bPkgWrapper.vhd",
        parameters=parameters,
    )
