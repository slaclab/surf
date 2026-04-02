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
# - Sweep: Sweep the full 10-bit data space plus the curated valid K-code set.
# - Stimulus: Pulse `validIn` for each launched symbol and wait for decode.
# - Checks: The decoded symbol and K flag must match, with no error flags set.
# - Timing: The test synchronizes on `validOut` for each decode result.

import cocotb
import pytest

from tests.protocols.line_codes.line_code_test_utils import (
    default_wrapper_parameter_sweep,
    run_line_code_round_trip_test,
    run_line_code_wrapper_test,
)


@cocotb.test()
async def line_code_10b12b_round_trip_test(dut):
    # The 10b12b K-symbol set follows the historical `x & 28` family captured
    # in the legacy VHDL bench, so keep that subset explicit instead of trying
    # to infer legality indirectly from the package tables at runtime.
    await run_line_code_round_trip_test(
        dut,
        normal_symbols=range(2**10),
        k_symbols=[
            0x07C, 0x17C, 0x27C, 0x0BC, 0x0DC, 0x13C, 0x15C, 0x19C, 0x1BC,
            0x1DC, 0x23C, 0x25C, 0x29C, 0x2BC, 0x2DC, 0x33C, 0x35C,
        ],
    )


PARAMETER_SWEEP = default_wrapper_parameter_sweep()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_LineCode10b12bWrapper(parameters):
    run_line_code_wrapper_test(
        test_file=__file__,
        toplevel="surf.linecode10b12bwrapper",
        wrapper_source="protocols/line-codes/wrappers/LineCode10b12bWrapper.vhd",
        parameters=parameters,
    )
