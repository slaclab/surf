##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Shared helpers for the Icarus SimLink regression: tool discovery/skip (with
# a version floor since older Icarus builds lack the sysfunc argument writes
# and SV-2012 subset this backend needs), the RogueSimLink.vpi build fixture,
# and the RogueSvTrafficTb compile/run helpers.

import fcntl
import re
import shutil
import subprocess

from tests.simlink.paths import IVERILOG_SOURCE_DIR, SV_HDL_TEST_SOURCE_DIR, SV_SOURCE_DIR

REQUIRED_TOOLS = ("make", "gcc", "pkg-config", "iverilog", "iverilog-vpi", "vvp")
MIN_IVERILOG_MAJOR = 12
BUILD_TIMEOUT_SECONDS = 300
RUN_TIMEOUT_SECONDS = 120

TB_TOP = "RogueSvTrafficTb"
TB_SOURCE = SV_HDL_TEST_SOURCE_DIR / f"{TB_TOP}.sv"

SKIP_REASON = (
    f"Icarus regression needs {', '.join(REQUIRED_TOOLS)} "
    f"(iverilog >= {MIN_IVERILOG_MAJOR})"
)


def _iverilog_major_version():
    try:
        result = subprocess.run(
            ["iverilog", "-V"], capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    match = re.search(r"Icarus Verilog version (\d+)", result.stdout)
    return int(match.group(1)) if match else None


def tools_available():
    if not all(shutil.which(tool) is not None for tool in REQUIRED_TOOLS):
        return False
    if subprocess.run(["pkg-config", "--exists", "libzmq"]).returncode != 0:
        return False
    major = _iverilog_major_version()
    return major is not None and major >= MIN_IVERILOG_MAJOR


def build_vpi_module():
    """Build RogueSimLink.vpi under a file lock so parallel pytest workers do
    not race on the shared build/ output."""
    build_dir = IVERILOG_SOURCE_DIR / "build"
    build_dir.mkdir(parents=True, exist_ok=True)
    with open(build_dir / ".pytest-build.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(
            ["make", "-C", str(IVERILOG_SOURCE_DIR), "all"],
            check=True, timeout=BUILD_TIMEOUT_SECONDS,
        )


def hdl_sources():
    """Sorted sv/*.sv, sorted iverilog/*.sv, then the traffic TB -- mirroring
    what ruckus's loadSource -dir collects per directory."""
    return [
        *sorted(SV_SOURCE_DIR.glob("*.sv")),
        *sorted(IVERILOG_SOURCE_DIR.glob("*.sv")),
        TB_SOURCE,
    ]


def compile_tb(build_dir, parameters):
    build_dir.mkdir(parents=True, exist_ok=True)
    vvp_path = build_dir / f"{TB_TOP}.vvp"
    command = ["iverilog", "-g2012", "-o", str(vvp_path), "-s", TB_TOP]
    for name, value in parameters.items():
        command.append(f"-P{TB_TOP}.{name}={value}")
    command.extend(str(source) for source in hdl_sources())
    subprocess.run(command, check=True, timeout=BUILD_TIMEOUT_SECONDS)
    return vvp_path


def run_tb(build_dir):
    vvp_path = build_dir / f"{TB_TOP}.vvp"
    return subprocess.run(
        ["vvp", "-n", "-M", str(IVERILOG_SOURCE_DIR), "-mRogueSimLink", str(vvp_path)],
        capture_output=True, text=True, timeout=RUN_TIMEOUT_SECONDS,
    )
