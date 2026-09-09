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
# - Sweep: Compile all three VCS adapter ABIs, then initialize one generic
#   scalar/vector port set and drive its teardown path.
# - Stimulus: Build VhpiGeneric with a minimal Synopsys-style VHPI shim and a
#   common SimLink instance; call the exported VhpiGenericCleanup directly
#   (the end-of-simulation callback is deliberately not registered).
# - Checks: Adapter tables compile; teardown removes the value/error callbacks,
#   releases callback and port handles, and destroys the common instance once.
# - Timing: Native compile and execution only; no simulator or license is used.
#   This test exercises the VCS *adapter* C via gcc + a stub vhpi_user.h, so it
#   lives under native/ (not vcs/, which is gated on a real VCS toolchain) to
#   guarantee the default, non-licensed CI run collects it.

import shutil
import subprocess

import pytest

from tests.simlink.paths import (
    SHARED_SOURCE_DIR,
    SIMLINK_TEST_ROOT,
    VCS_SOURCE_DIR,
    sim_build_dir,
)

HERE = SIMLINK_TEST_ROOT / "native"
INCLUDE_DIR = HERE / "include"
SIM_BUILD = sim_build_dir("native", "VhpiGenericLifecycle")
HARNESS = SIM_BUILD / "vhpi_generic_lifecycle_harness"

pytestmark = pytest.mark.skipif(
    shutil.which("gcc") is None,
    reason="VhpiGeneric adapter lifecycle test needs gcc",
)


def _compile_args():
    return [
        "gcc",
        "-std=c11",
        "-Wall",
        "-Wextra",
        "-Werror",
        "-DVCS_VERSION=2025",
        f"-I{INCLUDE_DIR}",
        f"-I{VCS_SOURCE_DIR}",
        f"-I{SHARED_SOURCE_DIR}",
    ]


def test_vhpi_adapters_compile_with_declarative_port_specs():
    subprocess.run(
        [
            *_compile_args(),
            "-fsyntax-only",
            str(VCS_SOURCE_DIR / "RogueTcpStream.c"),
            str(VCS_SOURCE_DIR / "RogueTcpMemory.c"),
            str(VCS_SOURCE_DIR / "RogueSideBand.c"),
        ],
        check=True,
    )


def test_vhpi_generic_releases_instance_and_metadata():
    SIM_BUILD.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            *_compile_args(),
            str(VCS_SOURCE_DIR / "VhpiGeneric.c"),
            str(SHARED_SOURCE_DIR / "RogueSimLinkInstance.c"),
            str(HERE / "vhpi_generic_lifecycle_harness.c"),
            "-o",
            str(HARNESS),
        ],
        check=True,
    )
    subprocess.run([str(HARNESS)], check=True)
