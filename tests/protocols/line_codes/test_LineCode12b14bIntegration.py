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
# - Sweep: Run a compact end-to-end smoke through the legacy `LineCode12b14bTb`
#   adapter rather than a duplicated checked-in wrapper.
# - Stimulus: Launch a short mix of data words, legal K words, and a brief
#   training-pattern prefix.
# - Checks: The decoded symbol and K flag must round-trip with no decoder
#   errors.
# - Timing: The bench waits for each registered decode result on `validOut`.

import cocotb
import pytest

from tests.protocols.line_codes.line_code_test_utils import (
    TRAINING_PATTERN_12B14B,
    run_integration_round_trip_test,
    run_line_code_integration_test,
)


@cocotb.test()
async def line_code_12b14b_integration_smoke_test(dut):
    await run_integration_round_trip_test(
        dut,
        sequences=[
            (0x000, 0),
            (0x0BD, 0),
            (0xEAD, 0),
            (0x5F8, 1),
            (0x078, 1),
            *TRAINING_PATTERN_12B14B[:6],
        ],
    )


PARAMETER_SWEEP = [{}]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_LineCode12b14bIntegration(parameters):
    run_line_code_integration_test(
        test_file=__file__,
        toplevel="surf.linecode12b14btb",
        tb_source="protocols/line-codes/tb/LineCode12b14bTb.vhd",
        parameters=parameters,
    )
