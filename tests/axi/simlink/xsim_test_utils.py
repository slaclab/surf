##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Shared helpers for the Vivado xsim DPI regressions (test_RogueXsimMulti.py
# and test_RogueXsimTraffic.py): tool discovery/skip, the system-libstdc++
# LD_PRELOAD workaround, the RogueTcpDpi.so build fixture, and the
# xvlog/xvhdl/xelab/xsim compile-and-run helper.

import fcntl
import os
from pathlib import Path
import shutil
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[3]
XSIM_DIR = REPO_ROOT / "axi" / "simlink" / "xsim"

SV_SOURCES = [
    XSIM_DIR / "RogueTcpStreamDpi.sv",
    XSIM_DIR / "RogueTcpMemoryDpi.sv",
    XSIM_DIR / "RogueSideBandDpi.sv",
]
MODEL_VHDL_SOURCES = [
    XSIM_DIR / "RogueTcpStream.vhd",
    XSIM_DIR / "RogueTcpMemory.vhd",
    XSIM_DIR / "RogueSideBand.vhd",
]

# Ordered (leaves-first) surf source list needed to compile surf.AxiDualPortRam
# into a `surf` library. RogueXsimTrafficTb.vhd instantiates AxiDualPortRam as
# the real AXI-Lite RAM slave for each Memory instance, so xelab must see this
# library. AxiDualPortRam defaults to SYNTH_MODE_G="inferred", so the XPM/
# AlteraMf dummies satisfy the entity references and no vendor libraries are
# needed. This exact order compiles clean under `xvhdl -2008 -work surf`.
SURF_AXI_RAM_SOURCES = [
    REPO_ROOT / "base" / "general" / "rtl" / "StdRtlPkg.vhd",
    REPO_ROOT / "base" / "general" / "rtl" / "TextUtilPkg.vhd",
    REPO_ROOT / "base" / "sync" / "rtl" / "Synchronizer.vhd",
    REPO_ROOT / "base" / "sync" / "rtl" / "RstSync.vhd",
    REPO_ROOT / "base" / "sync" / "rtl" / "SynchronizerVector.vhd",
    REPO_ROOT / "base" / "ram" / "inferred" / "LutRam.vhd",
    REPO_ROOT / "base" / "ram" / "rtl" / "SimpleDualPortRam.vhd",
    REPO_ROOT / "base" / "ram" / "inferred" / "TrueDualPortRamInferred.vhd",
    REPO_ROOT / "base" / "ram" / "dummy" / "TrueDualPortRamXpmAlteraMfDummy.vhd",
    REPO_ROOT / "base" / "ram" / "xilinx" / "TrueDualPortRamXpm.vhd",
    REPO_ROOT / "base" / "ram" / "rtl" / "TrueDualPortRam.vhd",
    REPO_ROOT / "base" / "ram" / "inferred" / "DualPortRam.vhd",
    REPO_ROOT / "base" / "fifo" / "rtl" / "FifoOutputPipeline.vhd",
    REPO_ROOT / "base" / "fifo" / "rtl" / "inferred" / "FifoWrFsm.vhd",
    REPO_ROOT / "base" / "fifo" / "rtl" / "inferred" / "FifoRdFsm.vhd",
    REPO_ROOT / "base" / "fifo" / "rtl" / "inferred" / "FifoAsync.vhd",
    REPO_ROOT / "base" / "sync" / "rtl" / "SynchronizerFifo.vhd",
    REPO_ROOT / "axi" / "axi-lite" / "rtl" / "AxiLitePkg.vhd",
    REPO_ROOT / "axi" / "axi-lite" / "rtl" / "AxiDualPortRam.vhd",
]

REQUIRED_TOOLS = ("make", "xsc", "xvlog", "xvhdl", "xelab", "xsim")
BUILD_TIMEOUT_SECONDS = 300
RUN_TIMEOUT_SECONDS = 120

SKIP_REASON = "Vivado xsim regression needs make/xsc/xvlog/xvhdl/xelab/xsim"


def tools_available():
    return all(shutil.which(tool) is not None for tool in REQUIRED_TOOLS)


def xsim_run_env():
    """Environment for running xsim's DPI-linked snapshot.

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
            check=True, capture_output=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return env
    if not libstdcxx or not os.path.isfile(libstdcxx):
        return env
    preload = [libstdcxx]
    if env.get("LD_PRELOAD"):
        preload.append(env["LD_PRELOAD"])
    env["LD_PRELOAD"] = os.pathsep.join(preload)
    return env


def build_dpi_library():
    """Build RogueTcpDpi.so and run the DPI-header ABI check, under a file lock
    so parallel pytest workers do not race on the shared xsim.dir output."""
    build_dir = XSIM_DIR / "xsim.dir"
    build_dir.mkdir(parents=True, exist_ok=True)
    with open(build_dir / ".pytest-build.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(
            ["make", "-C", str(XSIM_DIR), "all", "abi-check"],
            check=True, timeout=BUILD_TIMEOUT_SECONDS,
        )


def compile_surf_library(build_dir):
    """Compile the ordered surf source list into a `surf` library under
    `build_dir` (its xsim.dir/surf), so xelab can resolve surf.AxiDualPortRam and
    its dependencies. Must run in the same cwd/build_dir as the subsequent
    `work` xvhdl/xelab steps so the shared xsim.dir holds both libraries. Cheap
    (~19 inferred RTL files) and harmless for tops that do not use surf."""
    subprocess.run(
        ["xvhdl", "-2008", "-work", "surf",
         *(str(s) for s in SURF_AXI_RAM_SOURCES)],
        cwd=build_dir, check=True, timeout=BUILD_TIMEOUT_SECONDS,
    )


def compile_and_elaborate(top, vhdl_sources, sim_build_dir):
    """Compile the SV leaves + given VHDL sources and elaborate `top`, leaving a
    ready-to-run snapshot in `sim_build_dir / top`. Split out of run_top so a
    caller can spawn its live ZMQ peers AFTER the (multi-second) elaboration and
    just before the run -- otherwise a peer's RCVTIMEO budget is consumed by
    elaboration and the peer exits before the sim ever produces traffic."""
    build_dir = sim_build_dir / top
    build_dir.mkdir(parents=True, exist_ok=True)

    # Compile the surf library first so xelab can link surf.AxiDualPortRam (used
    # by RogueXsimTrafficTb). Harmless for tops that do not reference surf.
    compile_surf_library(build_dir)

    subprocess.run(
        ["xvlog", "-sv", *(str(s) for s in SV_SOURCES)],
        cwd=build_dir, check=True, timeout=BUILD_TIMEOUT_SECONDS,
    )
    subprocess.run(
        ["xvhdl", "-2008", *(str(s) for s in vhdl_sources)],
        cwd=build_dir, check=True, timeout=BUILD_TIMEOUT_SECONDS,
    )
    subprocess.run(
        ["xelab", "-debug", "typical", "-s", top,
         "-sv_root", str(XSIM_DIR), "-sv_lib", "RogueTcpDpi", f"work.{top}"],
        cwd=build_dir, check=True, timeout=BUILD_TIMEOUT_SECONDS,
    )


def run_elaborated(top, sim_build_dir):
    """Run the already-elaborated `top` snapshot under xsim -R with the
    libstdc++ preload, and return the CompletedProcess."""
    build_dir = sim_build_dir / top
    return subprocess.run(
        ["xsim", top, "-R"],
        cwd=build_dir, capture_output=True, text=True,
        timeout=RUN_TIMEOUT_SECONDS, env=xsim_run_env(),
    )


def run_top(top, vhdl_sources, sim_build_dir):
    """Compile the SV leaves + given VHDL sources, elaborate `top`, run it under
    xsim -R with the libstdc++ preload, and return the CompletedProcess."""
    compile_and_elaborate(top, vhdl_sources, sim_build_dir)
    return run_elaborated(top, sim_build_dir)
