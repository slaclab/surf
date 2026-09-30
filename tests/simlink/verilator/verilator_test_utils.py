##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Shared helpers for the Verilator SimLink regression: tool discovery/skip
# (with a version floor since older Verilator builds lack --binary/--timing),
# the libRogueSimLinkDpi.so build fixture, and the build/run helpers, which
# serve any self-driving top under simlink/test/sv/.

import fcntl
import re
import shutil
import subprocess
from pathlib import Path

from tests.simlink.paths import SV_HDL_TEST_SOURCE_DIR, SV_SOURCE_DIR, VERILATOR_SOURCE_DIR

REQUIRED_TOOLS = ("make", "gcc", "pkg-config", "verilator")
MIN_VERILATOR = (5, 20)
BUILD_TIMEOUT_SECONDS = 300
RUN_TIMEOUT_SECONDS = 120

TB_TOP = "RogueSvTrafficTb"
TB_SOURCE = SV_HDL_TEST_SOURCE_DIR / f"{TB_TOP}.sv"
DPI_LIB = VERILATOR_SOURCE_DIR / "libRogueSimLinkDpi.so"

SKIP_REASON = (
    f"Verilator regression needs {', '.join(REQUIRED_TOOLS)} "
    f"(verilator >= {'.'.join(str(part) for part in MIN_VERILATOR)})"
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
    return (Path(root) / "include" / "vltstd" / "svdpi.h").exists()


def build_dpi_library():
    """Build libRogueSimLinkDpi.so and run the DPI ABI guard under a file
    lock so parallel pytest workers do not race on the shared build/
    output."""
    build_dir = VERILATOR_SOURCE_DIR / "build"
    build_dir.mkdir(parents=True, exist_ok=True)
    with open(build_dir / ".pytest-build.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(
            ["make", "-C", str(VERILATOR_SOURCE_DIR), "all", "abi-check"],
            check=True, timeout=BUILD_TIMEOUT_SECONDS,
        )


def hdl_sources(tb_source=TB_SOURCE):
    """Sorted sv/*.sv, sorted verilator/*.sv, then tb_source -- mirroring what
    ruckus's loadSource -dir collects per directory."""
    return [
        *sorted(SV_SOURCE_DIR.glob("*.sv")),
        *sorted(VERILATOR_SOURCE_DIR.glob("*.sv")),
        tb_source,
    ]


def build_tb(build_dir, parameters, top=TB_TOP):
    build_dir.mkdir(parents=True, exist_ok=True)
    source = SV_HDL_TEST_SOURCE_DIR / f"{top}.sv"
    command = [
        "verilator", "--binary", "--timing", "-j", "0",
        "--top-module", top,
    ]
    for name, value in parameters.items():
        command.append(f"-G{name}={value}")
    command.extend(["--Mdir", str(build_dir), "-o", f"V{top}"])
    command.extend(str(entry) for entry in hdl_sources(tb_source=source))
    command.append(str(DPI_LIB.resolve()))
    command.extend(["-LDFLAGS", f"-Wl,-rpath,{VERILATOR_SOURCE_DIR.resolve()}"])
    subprocess.run(command, check=True, cwd=build_dir, timeout=BUILD_TIMEOUT_SECONDS)
    return build_dir / f"V{top}"


def run_tb(build_dir, top=TB_TOP, plusargs=()):
    binary_path = build_dir / f"V{top}"
    return subprocess.run(
        [str(binary_path), *plusargs],
        capture_output=True, text=True, timeout=RUN_TIMEOUT_SECONDS,
    )
