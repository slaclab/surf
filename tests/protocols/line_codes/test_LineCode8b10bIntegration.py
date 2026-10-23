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
# - Sweep: Run a small one- and two-byte end-to-end smoke through the legacy
#   `LineCode8b10bTb` adapter rather than a duplicated wrapper copy.
# - Stimulus: Launch a short mix of data and K-symbol traffic, including
#   explicit per-lane K masks in the two-byte case.
# - Checks: The decoded symbol and K mask must round-trip with no decoder
#   errors.
# - Timing: The bench waits on `validOut` for each returned symbol.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.line_codes.line_code_test_utils import (
    run_integration_round_trip_test,
    run_line_code_integration_test,
)


@cocotb.test()
async def line_code_8b10b_integration_smoke_test(dut):
    width = int(dut.NUM_BYTES_G.value)
    if width == 1:
        sequences = [
            (0x00, 0x0),
            (0x4A, 0x0),
            (0xBC, 0x1),
            (0xFE, 0x1),
        ]
    else:
        sequences = [
            (0x0000, 0x0),
            (0x4A55, 0x0),
            (0xBC4A, 0x2),
            (0x3C1C, 0x3),
        ]

    await run_integration_round_trip_test(dut, sequences=sequences)


PARAMETER_SWEEP = [
    parameter_case("single_byte", NUM_BYTES_G="1"),
    parameter_case("dual_byte", NUM_BYTES_G="2"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_LineCode8b10bIntegration(parameters):
    run_line_code_integration_test(
        test_file=__file__,
        toplevel="surf.linecode8b10btb",
        parameters=parameters,
    )
