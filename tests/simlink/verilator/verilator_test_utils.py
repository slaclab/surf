##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Shared helpers for the Verilator SimLink regression: tool/ruckus discovery
# and skip (with a version floor since older Verilator builds lack
# --binary/--timing), the DPI ABI guard, and the build/run helpers, which
# drive any self-driving top under simlink/test/sv/ through ruckus's
# system_verilator.mk. abi-check runs under the same backend lock as the
# ruckus build, so a build never proceeds past a prototype drift between the
# SV import and the C definition.

import re
import shutil
import subprocess
from pathlib import Path

from tests.simlink.common import ruckus_verilog_flow as rf
from tests.simlink.paths import VERILATOR_SOURCE_DIR

REQUIRED_TOOLS = ("make", "gcc", "pkg-config", "verilator", "tclsh")
MIN_VERILATOR = (5, 20)
BUILD_TIMEOUT_SECONDS = 300
RUN_TIMEOUT_SECONDS = 120

TB_TOP = "RogueSvTrafficTb"

SKIP_REASON = (
    f"Verilator regression needs {', '.join(REQUIRED_TOOLS)} "
    f"(verilator >= {'.'.join(str(part) for part in MIN_VERILATOR)}) and a "
    f"ruckus checkout providing system_verilator.mk (RUCKUS_DIR, ./ruckus or ../ruckus)"
)


def _verilator_version():
    try:
        result = subprocess.run(
            ["verilator", "--version"], capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    match = re.search(r"Verilator (\d+)\.(\d+)", result.stdout)
    return (int(match.group(1)), int(match.group(2))) if match else None


def _verilator_root():
    try:
        result = subprocess.run(
            ["verilator", "--getenv", "VERILATOR_ROOT"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    root = result.stdout.strip()
    return root or None


def tools_available():
    if not all(shutil.which(tool) is not None for tool in REQUIRED_TOOLS):
        return False
    if subprocess.run(["pkg-config", "--exists", "libzmq"]).returncode != 0:
        return False
    version = _verilator_version()
    if version is None or version < MIN_VERILATOR:
        return False
    root = _verilator_root()
    if root is None:
        return False
    if not (Path(root) / "include" / "vltstd" / "svdpi.h").exists():
        return False
    return rf.find_ruckus_dir("system_verilator.mk") is not None


def build_tb(build_dir, parameters, top=TB_TOP):
    flags = "--binary --timing -j 0" + "".join(f" -G{name}={value}" for name, value in parameters.items())
    with rf.backend_lock("verilator"):
        subprocess.run(
            ["make", "-C", str(VERILATOR_SOURCE_DIR), "abi-check"],
            check=True, timeout=BUILD_TIMEOUT_SECONDS,
        )
        rf.make_build("verilator", build_dir, top, "VERILATOR_FLAGS", flags, BUILD_TIMEOUT_SECONDS)
    return build_dir / f"V{top}"


def run_tb(build_dir, top=TB_TOP, plusargs=()):
    return rf.make_tb("verilator", build_dir, top, plusargs, RUN_TIMEOUT_SECONDS)
