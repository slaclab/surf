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
# - Sweep: Check the historical `genTKeep()` byte-count cases from the legacy
#   package testbench.
# - Stimulus: Drive the wrapper byte-count input combinationally.
# - Checks: The returned `tKeep` mask must match the expected packed width.
# - Timing: Sample one delta cycle after each input update.

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import run_surf_vhdl_test


CASES = [
    (0, 0x0),
    (1, 0x1),
    (31, 0x7FFF_FFFF),
    (32, 0xFFFF_FFFF),
    (64, 0xFFFF_FFFF_FFFF_FFFF),
]


@cocotb.test()
async def axi_stream_pkg_gen_tkeep_test(dut):
    for byte_count, expected in CASES:
        dut.bytes.value = byte_count
        await Timer(1, unit="ns")
        assert int(dut.tKeepResult.value) == expected


PARAMETER_SWEEP = [pytest.param({}, id="legacy_gen_tkeep_cases")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiStreamPkg(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreampkgwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["axi/axi-stream/wrappers/AxiStreamPkgWrapper.vhd"]},
    )
