##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Shared helpers for the Icarus SimLink regression: tool/ruckus discovery and
# skip (with a version floor since older Icarus builds lack the sysfunc
# argument writes and SV-2012 subset this backend needs), and the build/run
# helpers, which drive any self-driving top under simlink/test/sv/ through
# ruckus's system_iverilog.mk.

import re
import shutil
import subprocess

from tests.simlink.common import ruckus_verilog_flow as rf

REQUIRED_TOOLS = ("make", "gcc", "pkg-config", "iverilog", "iverilog-vpi", "vvp", "tclsh")
MIN_IVERILOG_MAJOR = 12
BUILD_TIMEOUT_SECONDS = 300
RUN_TIMEOUT_SECONDS = 120

TB_TOP = "RogueSvTrafficTb"

SKIP_REASON = (
    f"Icarus regression needs {', '.join(REQUIRED_TOOLS)} "
    f"(iverilog >= {MIN_IVERILOG_MAJOR}) and a ruckus checkout providing "
    f"system_iverilog.mk (RUCKUS_DIR, ./ruckus or ../ruckus)"
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
    if major is None or major < MIN_IVERILOG_MAJOR:
        return False
    return rf.find_ruckus_dir("system_iverilog.mk") is not None


def compile_tb(build_dir, parameters, top=TB_TOP):
    flags = "-g2012" + "".join(f" -P{top}.{name}={value}" for name, value in parameters.items())
    with rf.backend_lock("iverilog"):
        rf.make_build("iverilog", build_dir, top, "IVERILOG_FLAGS", flags, BUILD_TIMEOUT_SECONDS)
    return build_dir / f"{top}.vvp"


def run_tb(build_dir, top=TB_TOP, plusargs=()):
    return rf.make_tb("iverilog", build_dir, top, plusargs, RUN_TIMEOUT_SECONDS)
