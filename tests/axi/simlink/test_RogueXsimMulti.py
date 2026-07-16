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
import os
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


def _xsim_run_env():
    """Return the environment for running xsim's DPI-linked snapshot.

    Every Vivado release bundles its own (older) libstdc++ and puts it ahead of
    the system libraries at run time. When the host libzmq was built against a
    newer libstdc++ than Vivado's, xsimk fails to start with a "GLIBCXX_...
    not found (required by libzmq.so.5)" loader error. Preloading the system
    libstdc++ (located portably via gcc, matching the xsim Makefile's crti.o
    lookup) resolves the newer symbols without affecting the build steps.
    Harmless when Vivado's bundled libstdc++ is already new enough.
    """
    env = os.environ.copy()
    try:
        libstdcxx = subprocess.run(
            ["gcc", "-print-file-name=libstdc++.so.6"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return env
    # gcc prints the bare name back unchanged when it cannot resolve a path.
    if not libstdcxx or not os.path.isfile(libstdcxx):
        return env
    preload = [libstdcxx]
    if env.get("LD_PRELOAD"):
        preload.append(env["LD_PRELOAD"])
    env["LD_PRELOAD"] = os.pathsep.join(preload)
    return env


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
        env=_xsim_run_env(),
    )


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
