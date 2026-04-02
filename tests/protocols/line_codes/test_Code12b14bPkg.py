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
# - Sweep: Sweep the full 12-bit data space and the legal K-code set across the
#   four explicit disparity seeds used in `Code12b14bTb.vhd`.
# - Stimulus: Drive a combinational wrapper around the `encode12b14b` and
#   `decode12b14b` package procedures, then run a curated two-symbol transition
#   subset plus the historical mixed training pattern.
# - Checks: The decoded symbol, K flag, and disparity state must round-trip
#   with no code or disparity errors across the same explicit disparity seeds
#   and preserved training/transition sequences used by the legacy bench.
# - Timing: The wrapper is combinational, so the test yields one delta cycle
#   after each input update before sampling outputs.

import cocotb
import pytest

from tests.protocols.line_codes.line_code_test_utils import (
    default_wrapper_parameter_sweep,
    run_line_code_wrapper_test,
    settle_combinational_line_code_wrapper,
)


DISPARITY_SEEDS_12B14B = {
    -2: 0b10,
    0: 0b11,
    2: 0b00,
    4: 0b01,
}
K_SYMBOLS_12B14B = [
    0x078, 0x0F8, 0x178, 0x1F8, 0x278, 0x3F8, 0x478, 0x5F8,
    0x878, 0x9F8, 0xBF8, 0xC78, 0xDF8, 0xEF8, 0xF78, 0xFF8,
]
TRANSITION_SMOKE_SEQUENCE = [
    (0x000, 0), (0xFFF, 0), (0x0BD, 0), (0xEAD, 0), (0x5F8, 1), (0x078, 1),
    (0x1F8, 1), (0x800, 0), (0x555, 0), (0xAAA, 0), (0xFF8, 1),
]
TRAINING_PATTERN = [
    (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1),
    (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1),
    (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x078, 1), (0x5F8, 1), (0xEAD, 0),
    (0x0BD, 0), (0xEAD, 0), (0x1BD, 0), (0xEAD, 0), (0x2BD, 0), (0xEAD, 0),
    (0x3BD, 0), (0xEAD, 0), (0x4BD, 0), (0xEAD, 0), (0x5BD, 0), (0xEAD, 0),
    (0x6BD, 0), (0xEAD, 0), (0x7BD, 0), (0xEAD, 0), (0x8BD, 0), (0xEAD, 0),
    (0x9BD, 0), (0xEAD, 0), (0xABD, 0), (0xEAD, 0), (0xBBD, 0), (0x5F8, 1),
    (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1), (0x5F8, 1),
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
    assert int(dut.encodedDisp.value) == int(dut.decodedDisp.value)


@cocotb.test()
async def code_12b14b_package_round_trip_test(dut):
    for disp_seed in DISPARITY_SEEDS_12B14B.values():
        for data_in in range(2**12):
            await drive_package_symbol(dut, disp_in=disp_seed, data_in=data_in, data_k_in=0)
            assert_package_round_trip(dut, data_in=data_in, data_k_in=0)

        for data_in in K_SYMBOLS_12B14B:
            await drive_package_symbol(dut, disp_in=disp_seed, data_in=data_in, data_k_in=1)
            assert_package_round_trip(dut, data_in=data_in, data_k_in=1)

        # The legacy VHDL bench also stresses chained transitions by feeding a
        # second symbol with the first symbol's resulting disparity. Use a
        # curated subset here to preserve that stateful behavior class without
        # reproducing the original impractically large Cartesian product.
        current_disp = disp_seed
        for data_in, data_k_in in TRANSITION_SMOKE_SEQUENCE:
            await drive_package_symbol(dut, disp_in=current_disp, data_in=data_in, data_k_in=data_k_in)
            assert_package_round_trip(dut, data_in=data_in, data_k_in=data_k_in)
            current_disp = int(dut.encodedDisp.value)

    current_disp = DISPARITY_SEEDS_12B14B[4]
    for data_in, data_k_in in TRAINING_PATTERN:
        await drive_package_symbol(dut, disp_in=current_disp, data_in=data_in, data_k_in=data_k_in)
        assert_package_round_trip(dut, data_in=data_in, data_k_in=data_k_in)
        current_disp = int(dut.encodedDisp.value)


PARAMETER_SWEEP = default_wrapper_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Code12b14bPkg(parameters):
    run_line_code_wrapper_test(
        test_file=__file__,
        toplevel="surf.code12b14bpkgwrapper",
        wrapper_source="protocols/line-codes/wrappers/Code12b14bPkgWrapper.vhd",
        parameters=parameters,
    )
