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
# - Sweep: One eight-instance mixed-model top and one duplicate-Stream-port
#   negative top under the actual Vivado xsim mixed-language/DPI flow.
# - Stimulus: Compile the VHDL forwarding entities and SystemVerilog leaves,
#   build RogueTcpDpi.so, pulse reset twice, and run bounded clocks with benign
#   model inputs and no external peer.
# - Checks: Four Stream and two each Memory and SideBand leaves elaborate,
#   retain independent chandle contexts, bind distinct endpoint pairs, finish
#   normally, and release resources; the duplicate pair terminates via $fatal.
# - Timing: Both VHDL tops contain bounded clock loops and subprocesses have
#   wall-clock timeouts. Tests skip explicitly when proprietary Vivado
#   simulator tools are not available on PATH.

import pytest

from tests.axi.simlink import xsim_test_utils as xu

HERE = xu.REPO_ROOT / "tests" / "axi" / "simlink"
TB_SOURCE = HERE / "RogueXsimMultiTb.vhd"
SIM_BUILD = HERE / "sim_build_RogueXsimMulti"
VHDL_SOURCES = [*xu.MODEL_VHDL_SOURCES, TB_SOURCE]

pytestmark = pytest.mark.skipif(not xu.tools_available(), reason=xu.SKIP_REASON)


@pytest.fixture(scope="module", autouse=True)
def build_dpi_library():
    xu.build_dpi_library()


def _run_top(top):
    return xu.run_top(top, VHDL_SOURCES, SIM_BUILD)


def test_xsim_multi_instance_smoke():
    result = _run_top("RogueXsimMultiTb")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Rogue xsim multi-instance smoke test passed" in result.stdout


def test_xsim_rejects_duplicate_port_pair():
    result = _run_top("RogueXsimDuplicatePortTb")
    output = result.stdout + result.stderr
    # xsim's $fatal exits 0 even in batch (-R) mode, so the return code cannot
    # distinguish rejection from success. The port-pair guard must fire (the
    # $fatal message is present) and the testbench's "not rejected" failure
    # branch must never be reached.
    assert "overlaps live RogueTcpStream port pair" in output, output
    assert "Duplicate xsim port pair was not rejected" not in output, output
