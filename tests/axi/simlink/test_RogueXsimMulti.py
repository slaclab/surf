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

import fcntl
from pathlib import Path
import shutil
import subprocess

import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
XSIM_DIR = REPO_ROOT / "axi" / "simlink" / "xsim"
HERE = Path(__file__).resolve().parent
TB_SOURCE = HERE / "RogueXsimMultiTb.vhd"
SIM_BUILD = HERE / "sim_build_RogueXsimMulti"

VHDL_SOURCES = [
    XSIM_DIR / "RogueTcpStream.vhd",
    XSIM_DIR / "RogueTcpMemory.vhd",
    XSIM_DIR / "RogueSideBand.vhd",
    TB_SOURCE,
]
SV_SOURCES = [
    XSIM_DIR / "RogueTcpStreamDpi.sv",
    XSIM_DIR / "RogueTcpMemoryDpi.sv",
    XSIM_DIR / "RogueSideBandDpi.sv",
]
REQUIRED_TOOLS = ("make", "xsc", "xvlog", "xvhdl", "xelab", "xsim")
BUILD_TIMEOUT_SECONDS = 300
RUN_TIMEOUT_SECONDS = 120

pytestmark = pytest.mark.skipif(
    any(shutil.which(tool) is None for tool in REQUIRED_TOOLS),
    reason="Vivado xsim multi-instance regression needs make/xsc/xvlog/xvhdl/xelab/xsim",
)


@pytest.fixture(scope="module", autouse=True)
def build_dpi_library():
    build_dir = XSIM_DIR / "xsim.dir"
    build_dir.mkdir(parents=True, exist_ok=True)
    with open(build_dir / ".pytest-build.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(
            ["make", "-C", str(XSIM_DIR), "all", "abi-check"],
            check=True,
            timeout=BUILD_TIMEOUT_SECONDS,
        )


def _run_top(top):
    build_dir = SIM_BUILD / top
    build_dir.mkdir(parents=True, exist_ok=True)

    subprocess.run(
        ["xvlog", "-sv", *(str(source) for source in SV_SOURCES)],
        cwd=build_dir,
        check=True,
        timeout=BUILD_TIMEOUT_SECONDS,
    )
    subprocess.run(
        ["xvhdl", "-2008", *(str(source) for source in VHDL_SOURCES)],
        cwd=build_dir,
        check=True,
        timeout=BUILD_TIMEOUT_SECONDS,
    )
    subprocess.run(
        [
            "xelab",
            "-debug",
            "typical",
            "-s",
            top,
            "-sv_root",
            str(XSIM_DIR),
            "-sv_lib",
            "RogueTcpDpi",
            f"work.{top}",
        ],
        cwd=build_dir,
        check=True,
        timeout=BUILD_TIMEOUT_SECONDS,
    )
    return subprocess.run(
        ["xsim", top, "-R"],
        cwd=build_dir,
        capture_output=True,
        text=True,
        timeout=RUN_TIMEOUT_SECONDS,
    )


def test_xsim_multi_instance_smoke():
    result = _run_top("RogueXsimMultiTb")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Rogue xsim multi-instance smoke test passed" in result.stdout


def test_xsim_rejects_duplicate_port_pair():
    result = _run_top("RogueXsimDuplicatePortTb")
    output = result.stdout + result.stderr
    assert result.returncode != 0, output
    assert "overlaps live RogueTcpStream port pair" in output
