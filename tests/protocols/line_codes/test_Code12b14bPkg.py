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
# - Sweep: Exhaustively sweep the full 12-bit data space, the legal K-code
#   table, explicit disparity seeds, and the legacy training/transition
#   sequences, then add dedicated malformed-decode and `invalidK` checks.
# - Stimulus: Use the package wrapper's encode ports to generate legal 14-bit
#   words, then drive the decode ports independently so round-trip and
#   malformed decoder behavior are both visible.
# - Checks: Legal encodes must round-trip with the expected next disparity,
#   illegal K requests must assert `invalidK`, and malformed decode words must
#   assert a code or disparity error.
# - Timing: The wrapper is combinational, so the bench yields one delta cycle
#   after each encode or decode update before sampling outputs.

import cocotb
import pytest

from tests.protocols.line_codes.line_code_test_utils import (
    DISPARITY_SEEDS_12B14B,
    K_SYMBOLS_12B14B,
    TRAINING_PATTERN_12B14B,
    TRANSITION_SMOKE_SEQUENCE_12B14B,
    all_ones,
    assert_package_decode_matches,
    default_parameter_sweep,
    error_detected,
    package_decode,
    package_encode,
    run_line_code_package_test,
)


ILLEGAL_K_SYMBOLS = [0x000, 0x001, 0x123, 0x800]
MALFORMED_SMOKE_SYMBOLS = [
    (0x000, 0),
    (0x0BD, 0),
    (0xEAD, 0),
    (0x5F8, 1),
    (0x078, 1),
    (0xFF8, 1),
]


async def assert_legal_round_trip(dut, *, disp_in: int, data_in: int, data_k_in: int) -> int:
    encoded_data, encoded_disp, invalid_k = await package_encode(
        dut,
        disp_in=disp_in,
        data_in=data_in,
        data_k_in=data_k_in,
    )
    assert invalid_k == 0
    await package_decode(dut, disp_in=disp_in, encoded_data=encoded_data)
    assert_package_decode_matches(
        dut,
        data_in=data_in,
        data_k_in=data_k_in,
        expected_disp=encoded_disp,
    )
    return encoded_disp


@cocotb.test()
async def code_12b14b_package_test(dut):
    for disp_in in DISPARITY_SEEDS_12B14B.values():
        for data_in in range(2**12):
            await assert_legal_round_trip(dut, disp_in=disp_in, data_in=data_in, data_k_in=0)

        for data_in in K_SYMBOLS_12B14B:
            await assert_legal_round_trip(dut, disp_in=disp_in, data_in=data_in, data_k_in=1)

        current_disp = disp_in
        for data_in, data_k_in in TRANSITION_SMOKE_SEQUENCE_12B14B:
            current_disp = await assert_legal_round_trip(
                dut,
                disp_in=current_disp,
                data_in=data_in,
                data_k_in=data_k_in,
            )

        for data_in, data_k_in in MALFORMED_SMOKE_SYMBOLS:
            encoded_data, _, _ = await package_encode(
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
                encoded_data ^ 0x2000,
            ):
                await package_decode(dut, disp_in=disp_in, encoded_data=malformed)
                malformed_detected.append(error_detected(dut))
            assert any(malformed_detected)

    current_disp = DISPARITY_SEEDS_12B14B[4]
    for data_in, data_k_in in TRAINING_PATTERN_12B14B:
        current_disp = await assert_legal_round_trip(
            dut,
            disp_in=current_disp,
            data_in=data_in,
            data_k_in=data_k_in,
        )

    for disp_in in DISPARITY_SEEDS_12B14B.values():
        for data_in in ILLEGAL_K_SYMBOLS:
            _, _, invalid_k = await package_encode(
                dut,
                disp_in=disp_in,
                data_in=data_in,
                data_k_in=1,
            )
            assert invalid_k == 1


PARAMETER_SWEEP = default_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Code12b14bPkg(parameters):
    run_line_code_package_test(
        test_file=__file__,
        toplevel="surf.code12b14bpkgwrapper",
        wrapper_source="protocols/line-codes/wrappers/Code12b14bPkgWrapper.vhd",
        parameters=parameters,
    )
