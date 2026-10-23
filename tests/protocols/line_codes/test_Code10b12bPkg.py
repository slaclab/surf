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
# - Sweep: Exhaustively sweep the full 10-bit data space, the legal K.28.x
#   subset, and a curated malformed-decode subset for both package disparity
#   seeds.
# - Stimulus: Use the package wrapper's encode ports to generate legal 12-bit
#   words, then drive the decode ports independently so legal and malformed
#   decoder behavior are both exercised.
# - Checks: Legal encodes must round-trip with the expected next disparity and
#   no error flags, while malformed decode inputs must assert a code or
#   disparity error.
# - Timing: The wrapper is combinational, so the bench yields one delta cycle
#   after each input update before sampling outputs.

import cocotb
import pytest

from tests.protocols.line_codes.line_code_test_utils import (
    DISPARITY_SEEDS_1BIT,
    K_SYMBOLS_10B12B,
    all_ones,
    assert_package_decode_matches,
    default_parameter_sweep,
    error_detected,
    package_decode,
    package_encode,
    run_line_code_package_test,
)


MALFORMED_SMOKE_SYMBOLS = [
    (0x000, 0),
    (0x0E7, 0),
    (0x3FF, 0),
    (0x07C, 1),
    (0x1BC, 1),
    (0x35C, 1),
]


@cocotb.test()
async def code_10b12b_package_test(dut):
    for disp_in in DISPARITY_SEEDS_1BIT:
        for data_in in range(2**10):
            encoded_data, encoded_disp = await package_encode(
                dut,
                disp_in=disp_in,
                data_in=data_in,
                data_k_in=0,
            )
            await package_decode(dut, disp_in=disp_in, encoded_data=encoded_data)
            assert_package_decode_matches(
                dut,
                data_in=data_in,
                data_k_in=0,
                expected_disp=encoded_disp,
            )

        for data_in in K_SYMBOLS_10B12B:
            encoded_data, encoded_disp = await package_encode(
                dut,
                disp_in=disp_in,
                data_in=data_in,
                data_k_in=1,
            )
            await package_decode(dut, disp_in=disp_in, encoded_data=encoded_data)
            assert_package_decode_matches(
                dut,
                data_in=data_in,
                data_k_in=1,
                expected_disp=encoded_disp,
            )

        for data_in, data_k_in in MALFORMED_SMOKE_SYMBOLS:
            encoded_data, _ = await package_encode(
                dut,
                disp_in=disp_in,
                data_in=data_in,
                data_k_in=data_k_in,
            )
            malformed_detected = []
            for malformed in (
                0,
                all_ones(dut.decDataIn),
                encoded_data ^ 0x001,
                encoded_data ^ 0x800,
            ):
                await package_decode(dut, disp_in=disp_in, encoded_data=malformed)
                malformed_detected.append(error_detected(dut))
            assert any(malformed_detected)


PARAMETER_SWEEP = default_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Code10b12bPkg(parameters):
    run_line_code_package_test(
        test_file=__file__,
        toplevel="surf.code10b12bpkgwrapper",
        wrapper_source="protocols/line-codes/wrappers/Code10b12bPkgWrapper.vhd",
        parameters=parameters,
    )
