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

from tests.protocols.line_codes.line_code_test_utils import (
    default_wrapper_parameter_sweep,
    run_line_code_round_trip_test,
    run_line_code_wrapper_test,
)


@cocotb.test()
async def line_code_12b14b_round_trip_test(dut):
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
    # The 12b14b family keeps the broadest historical coverage: the full data
    # space, the explicit legal K-code table, and the mixed-symbol training
    # pattern from the older VHDL regression.
    await run_line_code_round_trip_test(
        dut,
        normal_symbols=range(2**12),
        k_symbols=[
            0x078, 0x0F8, 0x178, 0x1F8, 0x278, 0x3F8, 0x478, 0x5F8,
            0x878, 0x9F8, 0xBF8, 0xC78, 0xDF8, 0xEF8, 0xF78, 0xFF8,
        ],
        extra_sequences=training_pattern,
    )


PARAMETER_SWEEP = default_wrapper_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_LineCode12b14bWrapper(parameters):
    run_line_code_wrapper_test(
        test_file=__file__,
        toplevel="surf.linecode12b14bwrapper",
        wrapper_source="protocols/line-codes/wrappers/LineCode12b14bWrapper.vhd",
        parameters=parameters,
    )
