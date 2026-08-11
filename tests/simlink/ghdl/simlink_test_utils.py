##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from pathlib import Path
import fcntl
import os
import shutil
import subprocess

from cocotb_test.simulator import run

from tests.common.regression_utils import (
    cocotb_module_name_from_test_file,
    run_surf_vhdl_test,
)
from tests.simlink.paths import GHDL_SOURCE_DIR


GHDL_COMPILE_ARGS = ["--std=08", "-fsynopsys"]


def build_and_stage_so(ghdl_dir: Path, sim_build: Path) -> None:
    build_dir = ghdl_dir / "build"

    # CI runs the simlink suite under pytest-xdist (`-n auto --dist=worksteal`),
    # so several workers can enter build_and_stage_so() at once, and `make`
    # rebuilds the common .so in the one shared ghdl/build dir. Serialize the
    # make + copy with an exclusive file lock so two workers never link or copy
    # the same .so concurrently -- otherwise a worker can stage a
    # partially-written library and GHDL elaboration fails to load it. The
    # builds are idempotent, so after the first worker links the outputs the
    # rest just hit an up-to-date no-op make while holding the lock.
    build_dir.mkdir(parents=True, exist_ok=True)
    with open(build_dir / ".build.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(["make", "-C", str(ghdl_dir)], check=True)
        sim_build.mkdir(parents=True, exist_ok=True)

        # On this sandbox's llvm-backend GHDL, `ghdl -m` performs a real cc/ld
        # link step at elaborate time and needs the VHPIDIRECT library staged
        # into its own cwd (sim_build) in addition to LD_LIBRARY_PATH for the
        # runtime loader (an mcode+llvm loader superset confirmed during
        # bring-up).
        #
        # Stage through a temporary name and rename into place. A plain copy
        # truncates and rewrites the destination, which corrupts the mapping
        # any process already holds on it: the ctypes lifecycle tests dlopen
        # the staged library, and under `--dist=worksteal` a worker can leave
        # that module and come back, re-running this module-scoped staging
        # while its earlier handle is still resident. The rewrite then
        # segfaults the next dlsym. os.replace() installs a new inode instead,
        # so live mappings of the old one stay valid.
        staged = sim_build / "libRogueSimLinkVhpiDirect.so"
        pending = staged.with_name(f".{staged.name}.{os.getpid()}.tmp")
        shutil.copy(build_dir / "libRogueSimLinkVhpiDirect.so", pending)
        os.replace(pending, staged)

    # Export the build dir on LD_LIBRARY_PATH through os.environ, not only via
    # cocotb-test's `extra_env=`: cocotb-test copies the whole os.environ over
    # its extra_env *after* applying it, so a LD_LIBRARY_PATH already present in
    # the environment (actions/setup-python exports one pointing at the
    # interpreter lib dir on the CI runners) clobbers the extra_env value. When
    # that happens the apt mcode `ghdl -r` loader can no longer dlopen the
    # VHPIDIRECT .so and elaboration dies with "cannot load VHPIDIRECT shared
    # library". Prepend so the build dir and any pre-existing entries both stay
    # on the search path.
    existing = os.environ.get("LD_LIBRARY_PATH", "")
    os.environ["LD_LIBRARY_PATH"] = os.pathsep.join(
        [str(build_dir)] + ([existing] if existing else [])
    )


def run_simlink_ghdl_test(
    *,
    test_file,
    toplevel,
    vhdl_sources,
    sim_build,
    module=None,
    extra_env=None,
):
    """Run a backend-leaf GHDL test with the shared VHPIDIRECT library."""
    sim_build = Path(sim_build)
    build_and_stage_so(GHDL_SOURCE_DIR, sim_build)
    simulator_env = {
        "LD_LIBRARY_PATH": str(GHDL_SOURCE_DIR / "build"),
        **(extra_env or {}),
    }
    run(
        module=(
            module
            if module is not None
            else cocotb_module_name_from_test_file(test_file)
        ),
        toplevel=toplevel,
        toplevel_lang="vhdl",
        vhdl_sources=[str(source) for source in vhdl_sources],
        sim_build=str(sim_build),
        simulator="ghdl",
        vhdl_compile_args=GHDL_COMPILE_ARGS,
        extra_env={key: str(value) for key, value in simulator_env.items()},
    )


def run_simlink_surf_test(
    *,
    test_file,
    toplevel,
    sim_build,
    parameters=None,
    extra_env=None,
    extra_vhdl_sources=None,
    stage_library=True,
):
    """Run an imported-SURF wrapper test with the SimLink library staged."""
    sim_build = Path(sim_build)
    if stage_library:
        build_and_stage_so(GHDL_SOURCE_DIR, sim_build)
    run_surf_vhdl_test(
        test_file=test_file,
        toplevel=toplevel,
        parameters=parameters,
        extra_env={
            "LD_LIBRARY_PATH": str(GHDL_SOURCE_DIR / "build"),
            **(extra_env or {}),
        },
        extra_vhdl_sources=extra_vhdl_sources,
        sim_build_key=str(sim_build),
    )
