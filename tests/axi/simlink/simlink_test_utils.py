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


def build_and_stage_so(ghdl_dir: Path, so_name: str, sim_build: Path) -> None:
    build_dir = ghdl_dir / "build"

    # CI runs the simlink suite under pytest-xdist (`-n auto --dist=worksteal`),
    # so several workers can enter build_and_stage_so() at once, and `make`
    # rebuilds every module .so into the one shared ghdl/build dir. Serialize
    # the make + copy with an exclusive file lock so two workers never link (or
    # copy) the same .so concurrently -- otherwise a worker can stage a
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
        shutil.copy(build_dir / so_name, sim_build / so_name)

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
