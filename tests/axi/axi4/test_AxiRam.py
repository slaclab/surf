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
# - Sweep: Reuse the existing self-checking `AxiRamTb` harness in its stable
#   inferred-BRAM configuration.
# - Stimulus: Let the bundled memory tester exercise the AXI RAM through full
#   read and write sequences.
# - Checks: The cocotb side only needs to watch the harness `passed/failed`
#   flags because the VHDL testbed already validates memory behavior.
# - Timing: A bounded wait keeps the harness from hanging silently.

import cocotb
import pytest
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import run_surf_vhdl_test


@cocotb.test()
async def legacy_harness_completion_test(dut):
    while dut.rst.value == 1:
        await RisingEdge(dut.clk)

    for _ in range(100000):
        await RisingEdge(dut.clk)
        if dut.passed.value == 1:
            return
        if dut.failed.value == 1:
            assert False

    assert False


@pytest.mark.parametrize("parameters", [pytest.param({}, id="legacy_tb_smoke")])
def test_AxiRam(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiramtb",
        parameters=parameters,
        extra_env=parameters,
    )
