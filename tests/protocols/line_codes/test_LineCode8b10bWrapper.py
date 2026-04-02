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
# - Sweep: Sweep one- and two-byte encoder/decoder round-trip cases.
# - Stimulus: Launch all data symbols followed by the supported K-code set.
# - Checks: The decoded symbol must match the launched value with no code or
#   disparity errors.
# - Timing: The test waits on `validOut` rather than assuming fixed latency.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.line_codes.line_code_test_utils import (
    run_line_code_round_trip_test,
    run_line_code_wrapper_test,
)


@cocotb.test()
async def line_code_8b10b_round_trip_test(dut):
    width = int(dut.NUM_BYTES_G.value)
    # The 8b10b wrapper exposes a byte-lane vector, so the exhaustive data
    # sweep scales with the configured lane count while the K-code set stays
    # lane-local and legal for each individual byte symbol.
    await run_line_code_round_trip_test(
        dut,
        normal_symbols=range(2 ** (8 * width)),
        k_symbols=[0x1C, 0x3C, 0x5C, 0x7C, 0x9C, 0xBC, 0xDC, 0xFC, 0xF7, 0xFB, 0xFD, 0xFE],
    )


PARAMETER_SWEEP = [
    parameter_case("single_byte", NUM_BYTES_G="1"),
    parameter_case("dual_byte", NUM_BYTES_G="2"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_LineCode8b10bWrapper(parameters):
    run_line_code_wrapper_test(
        test_file=__file__,
        toplevel="surf.linecode8b10bwrapper",
        wrapper_source="protocols/line-codes/wrappers/LineCode8b10bWrapper.vhd",
        parameters=parameters,
    )
