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
# - Sweep: Exhaustively sweep the full 8-bit data space, the legal K-code set,
#   and a curated malformed-decode subset across both package disparity seeds.
# - Stimulus: Use the checked-in package wrapper's encode ports to generate
#   legal 10-bit symbols, then drive the decode ports independently so the
#   decoder can be checked on both legal and malformed words.
# - Checks: Legal encodes must decode back to the launched data and K flag
#   with the expected next disparity, while malformed words must assert a code
#   or disparity error.
# - Timing: The wrapper is combinational, so the bench yields one delta cycle
#   after each encode or decode input update before sampling outputs.

import cocotb
import pytest

from tests.protocols.line_codes.line_code_test_utils import (
    DISPARITY_SEEDS_1BIT,
    K_SYMBOLS_8B10B,
    all_ones,
    assert_package_decode_matches,
    default_parameter_sweep,
    error_detected,
    package_decode,
    package_encode,
    run_line_code_package_test,
)


MALFORMED_SMOKE_SYMBOLS = [
    (0x00, 0),
    (0x4A, 0),
    (0xB5, 0),
    (0x1C, 1),
    (0xBC, 1),
    (0xFE, 1),
]


@cocotb.test()
async def code_8b10b_package_test(dut):
    for disp_in in DISPARITY_SEEDS_1BIT:
        for data_in in range(2**8):
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

        for data_in in K_SYMBOLS_8B10B:
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

        # Package-level decoder coverage matters most on malformed symbols,
        # because the integration smoke already proves legal end-to-end wiring.
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
                encoded_data ^ 0x200,
            ):
                await package_decode(dut, disp_in=disp_in, encoded_data=malformed)
                malformed_detected.append(error_detected(dut))
            assert any(malformed_detected)


PARAMETER_SWEEP = default_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Code8b10bPkg(parameters):
    run_line_code_package_test(
        test_file=__file__,
        toplevel="surf.code8b10bpkgwrapper",
        wrapper_source="protocols/line-codes/wrappers/Code8b10bPkgWrapper.vhd",
        parameters=parameters,
    )
