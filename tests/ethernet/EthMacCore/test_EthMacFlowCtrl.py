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
# - Sweep: Cover the default primary-only path and the bypass-enabled merge
#   path, since those are the only externally visible modes of this block.
# - Stimulus: Drive primary-only causes, bypass-only causes, sustained mixed
#   requests, and then clear all request sources back to zero.
# - Checks: Primary requests must always pass, bypass requests must only
#   contribute when `BYP_EN_G=true`, mixed requests must behave as a registered
#   OR of the active sources, and the output must return to zero once all
#   causes are removed.
# - Timing: The DUT is fully registered, so checks sample one clock after each
#   control update instead of relying on combinational observation.

from __future__ import annotations

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacFlowCtrlWrapper.vhd"


async def cycle(clk, count: int = 1) -> None:
    for _ in range(count):
        await sample_after_tpd(clk)


@cocotb.test()
async def eth_mac_flow_ctrl_test(dut):
    byp_en = env_flag("BYP_EN_G", default=False)

    cocotb.start_soon(Clock(dut.ethClk, 5.0, unit="ns").start())
    dut.ethRst.setimmediatevalue(1)
    dut.primPause.setimmediatevalue(0)
    dut.primOverflow.setimmediatevalue(0)
    dut.bypPause.setimmediatevalue(0)
    dut.bypOverflow.setimmediatevalue(0)

    await cycle(dut.ethClk, 4)
    dut.ethRst.value = 0
    await cycle(dut.ethClk, 2)

    # The wrapper flattens the record interface, so a reset sanity check proves
    # both the real DUT and the scalar mapping start from zero.
    assert int(dut.flowPause.value) == 0
    assert int(dut.flowOverflow.value) == 0

    dut.primPause.value = 1
    await cycle(dut.ethClk, 2)
    assert int(dut.flowPause.value) == 1
    assert int(dut.flowOverflow.value) == 0

    dut.primPause.value = 0
    dut.primOverflow.value = 1
    await cycle(dut.ethClk, 2)
    assert int(dut.flowPause.value) == 0
    assert int(dut.flowOverflow.value) == 1

    # Bypass requests are only legal contributors when the generic enables the
    # second control plane.
    dut.primOverflow.value = 0
    dut.bypPause.value = 1
    dut.bypOverflow.value = 1
    await cycle(dut.ethClk, 2)
    assert int(dut.flowPause.value) == (1 if byp_en else 0)
    assert int(dut.flowOverflow.value) == (1 if byp_en else 0)

    # When bypass is enabled the merge is bitwise OR, so mixed request sources
    # must both appear in the registered output on the next cycle.
    dut.primPause.value = 1
    dut.bypPause.value = 0
    dut.bypOverflow.value = 1
    await cycle(dut.ethClk, 2)
    assert int(dut.flowPause.value) == 1
    assert int(dut.flowOverflow.value) == (1 if byp_en else 0)

    # Hold multiple request causes high together for a few cycles so the test
    # proves the merged output remains stable rather than only pulsing once.
    dut.primOverflow.value = 1
    dut.bypPause.value = 1
    await cycle(dut.ethClk, 3)
    assert int(dut.flowPause.value) == 1
    assert int(dut.flowOverflow.value) == 1

    # Once every contributing request is removed, the registered flow-control
    # outputs must return cleanly to zero.
    dut.primPause.value = 0
    dut.primOverflow.value = 0
    dut.bypPause.value = 0
    dut.bypOverflow.value = 0
    await cycle(dut.ethClk, 2)
    assert int(dut.flowPause.value) == 0
    assert int(dut.flowOverflow.value) == 0


PARAMETER_SWEEP = [
    parameter_case("primary_only", BYP_EN_G="false"),
    parameter_case("bypass_enabled", BYP_EN_G="true"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacFlowCtrl(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacflowctrlwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
