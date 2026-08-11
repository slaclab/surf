##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import fcntl
import os
import re
import shutil
import subprocess
from xml.etree import ElementTree

from cocotb_test.simulator import Vcs

from tests.simlink.paths import VCS_SOURCE_DIR

VCS_DIR = VCS_SOURCE_DIR

MODEL_VHDL_SOURCES = [
    VCS_DIR / "RogueTcpStream.vhd",
    VCS_DIR / "RogueTcpMemory.vhd",
    VCS_DIR / "RogueSideBand.vhd",
]

REQUIRED_TOOLS = ("gcc", "make", "pkg-config", "vcs", "vhdlan", "vlogan")
BUILD_TIMEOUT_SECONDS = 300
RUN_TIMEOUT_SECONDS = 120
SKIP_REASON = (
    "VCS regression requires Linux, SIMLINK_RUN_VCS=1, VCS_HOME "
    "(version auto-derived; override with VCS_VERSION=<year>), "
    "gcc/make/pkg-config, and licensed vcs/vhdlan/vlogan tools"
)


def vcs_version_year():
    """Integer VCS release year for the C -DVCS_VERSION feature gate.

    Explicit VCS_VERSION wins (must be a 4-digit year). Otherwise derive it from
    the VCS_HOME basename, which SLAC's VCS settings set to the full release name
    (e.g. .../vcs/W-2024.09 -> 2024, .../vcs/X-2025.06 -> 2025)."""
    explicit = os.getenv("VCS_VERSION")
    if explicit:
        if not re.fullmatch(r"\d{4}", explicit.strip()):
            raise ValueError(
                f"VCS_VERSION must be a 4-digit year, got {explicit!r}"
            )
        return int(explicit)
    vcs_home = os.getenv("VCS_HOME", "")
    match = re.search(r"(19|20)\d{2}", os.path.basename(vcs_home.rstrip("/")))
    if not match:
        raise ValueError(
            "cannot derive VCS version year: set VCS_VERSION to a 4-digit year, "
            f"or ensure VCS_HOME encodes it (got VCS_HOME={vcs_home!r})"
        )
    return int(match.group())


def tools_available():
    if not (
        os.name == "posix"
        and os.uname().sysname == "Linux"
        and os.getenv("SIMLINK_RUN_VCS") == "1"
        and bool(os.getenv("VCS_HOME"))
        and all(shutil.which(tool) is not None for tool in REQUIRED_TOOLS)
    ):
        return False
    try:
        vcs_version_year()
    except ValueError:
        return False
    return True


def vcs_environment_overrides():
    paths = [str(VCS_DIR)]
    if os.getenv("LD_LIBRARY_PATH"):
        paths.append(os.environ["LD_LIBRARY_PATH"])
    overrides = {"LD_LIBRARY_PATH": os.pathsep.join(paths)}
    if os.getenv("SIMLINK_VCS_LICENSE_FILE"):
        overrides["SNPSLMD_LICENSE_FILE"] = os.environ[
            "SIMLINK_VCS_LICENSE_FILE"
        ]
    return overrides


def build_vhpi_library():
    lock_path = VCS_DIR / ".pytest-build.lock"
    with open(lock_path, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(
            [
                "make",
                "-C",
                str(VCS_DIR),
                "all",
                f"SIMLINK_PWD={VCS_DIR}",
                f"VCS_HOME={os.environ['VCS_HOME']}",
                f"VCS_VERSION={vcs_version_year()}",
            ],
            check=True,
            timeout=BUILD_TIMEOUT_SECONDS,
            env={**os.environ, **vcs_environment_overrides()},
        )


def compile_vhdl(vhdl_sources, sim_build):
    sim_build.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["vhdlan", "-full64", "-vhdl08", *(str(src) for src in vhdl_sources)],
        cwd=sim_build,
        check=True,
        timeout=BUILD_TIMEOUT_SECONDS,
        env={**os.environ, **vcs_environment_overrides()},
    )


def compile_verilog(verilog_sources, sim_build):
    """Analyze the SystemVerilog bridge into the VHDL work library.

    VCS mixed-language binding of the SV top to the VHDL
    RogueSimLinkMultiInstanceHarness only resolves when both are pre-analyzed
    into work. Passing the .sv on the `vcs` command line instead makes VCS
    treat it as a standalone compile that cannot see the VHDL work library
    (Error-[CFCILFBI] Cannot find cell in liblist).
    """
    sim_build.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["vlogan", "-full64", "-sverilog", "+define+COCOTB_SIM=1",
         *(str(src) for src in verilog_sources)],
        cwd=sim_build,
        check=True,
        timeout=BUILD_TIMEOUT_SECONDS,
        env={**os.environ, **vcs_environment_overrides()},
    )


def _elaboration_only(command):
    """Drop vlogan parse-only options from a cocotb-built `vcs` command. In
    VCS's unified-use model the sources are pre-analyzed by vlogan/vhdlan, so
    the elaboration step rejects parse-only options such as `-sverilog` and
    `+define+` (Error-[PRS_OPT])."""
    filtered = []
    for argument in command:
        text = str(argument)
        if text == "-sverilog" or text.startswith("+define+"):
            continue
        filtered.append(text)
    return filtered


def run_cocotb(top, module, verilog_sources, sim_build, extra_env=None):
    results = sim_build / "results.xml"
    results.unlink(missing_ok=True)

    # Pre-analyze the SV bridge into work, then elaborate by top name with no
    # source arguments so VCS binds the SV top to the pre-compiled VHDL topology.
    compile_verilog(verilog_sources, sim_build)

    runner = Vcs(
        toplevel=top,
        module=module,
        verilog_sources=[],
        sim_build=str(sim_build),
        force_compile=True,
    )
    runner.set_env()
    runner.env.update(vcs_environment_overrides())
    runner.env["COCOTB_RESULTS_FILE"] = str(results)
    runner.env["SIMLINK_MULTI_INSTANCE_RESULT_DIR"] = str(sim_build)
    if extra_env:
        runner.env.update({key: str(value) for key, value in extra_env.items()})

    output = []
    for index, command in enumerate(runner.build_command()):
        command = [str(argument) for argument in command]
        # index 0 is the `vcs` elaboration step; its sources were pre-analyzed
        # by vhdlan/vlogan, so strip vlogan-only parse options it would reject.
        if index == 0:
            command = _elaboration_only(command)
        completed = subprocess.run(
            command,
            cwd=runner.work_dir,
            env=runner.env,
            capture_output=True,
            text=True,
            timeout=(BUILD_TIMEOUT_SECONDS if index == 0 else RUN_TIMEOUT_SECONDS),
        )
        output.extend((completed.stdout, completed.stderr))
        if completed.returncode != 0:
            raise AssertionError(
                f"{' '.join(command)} exited {completed.returncode}\n"
                + "".join(output)
            )

    if not results.exists():
        raise AssertionError(
            "VCS completed without a cocotb results file\n" + "".join(output)
        )
    failures = list(ElementTree.parse(results).iter("failure"))
    if failures:
        raise AssertionError("VCS cocotb test failed\n" + "".join(output))
    return "".join(output)
