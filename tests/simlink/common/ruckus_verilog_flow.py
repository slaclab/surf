##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Drives simlink/test/sv through ruckus's system_iverilog.mk and
# system_verilator.mk. Builds are serialized per backend because ruckus's
# SimLink library build runs make and then make clean inside the shared surf
# backend directory; each launch runs ruckus's own tb recipe with build
# marked old (`make -o build tb`) so it reuses the OUT_DIR artifacts without
# re-running dir, clean, load_source_code or build. make runs in its own
# session so a timeout or interrupt kills the whole process group, including
# the simulator make spawned.

import contextlib
import fcntl
import os
import shlex
import signal
import subprocess

from tests.simlink.paths import REPO_ROOT, SIM_BUILD_ROOT, SV_HDL_TEST_SOURCE_DIR

PROJECT_DIR = SV_HDL_TEST_SOURCE_DIR


def find_ruckus_dir(flow_makefile):
    """Return the first candidate ruckus checkout providing flow_makefile, or
    None. When RUCKUS_DIR is set and non-empty it is the only candidate;
    otherwise the CI layout (REPO_ROOT/ruckus) is tried, then the sibling
    layout (REPO_ROOT.parent/ruckus)."""
    env_ruckus_dir = os.environ.get("RUCKUS_DIR")
    if env_ruckus_dir:
        candidates = [env_ruckus_dir]
    else:
        candidates = [REPO_ROOT / "ruckus", REPO_ROOT.parent / "ruckus"]
    for candidate in candidates:
        candidate = os.path.realpath(candidate)
        if os.path.isfile(os.path.join(candidate, flow_makefile)):
            return candidate
    return None


@contextlib.contextmanager
def backend_lock(backend):
    """Serialize ruckus builds for one backend: the SimLink library build
    runs `make` then `make clean` inside the shared surf backend directory,
    so concurrent pytest-xdist workers must not overlap a build for the same
    backend. The lock file lives outside every directory ruckus's `make
    clean` removes, so its inode survives across builds. Callers take this
    lock themselves; flock is per open file description, so taking it twice
    in one process deadlocks."""
    SIM_BUILD_ROOT.mkdir(parents=True, exist_ok=True)
    lock_path = SIM_BUILD_ROOT / f".{backend}-ruckus-build.lock"
    with open(lock_path, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def _build_env(backend, out_dir, top, flow_makefile, overrides):
    ruckus_dir = find_ruckus_dir(flow_makefile)
    if ruckus_dir is None:
        raise RuntimeError(
            f"no ruckus checkout providing {flow_makefile} found via RUCKUS_DIR, "
            f"{REPO_ROOT / 'ruckus'} or {REPO_ROOT.parent / 'ruckus'}"
        )
    env = os.environ.copy()
    env["RUCKUS_DIR"] = ruckus_dir
    env["RUCKUS_SIM_BACKEND"] = backend
    env["OUT_DIR"] = str(out_dir)
    env["SIM_TOP"] = top
    env["SIM_PLUSARGS"] = ""
    env.update(overrides)
    return env


def _run_make(args, env, timeout, capture=False):
    """Run make in its own process group so a timeout or interrupt can kill
    the whole group, including any simulator make spawns."""
    popen_kwargs = {}
    if capture:
        popen_kwargs.update(stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    proc = subprocess.Popen(
        ["make", "-C", str(PROJECT_DIR), *args],
        env=env, start_new_session=True, **popen_kwargs,
    )
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
    except BaseException:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.communicate()
        raise
    return subprocess.CompletedProcess(proc.args, proc.returncode, stdout, stderr)


def make_build(backend, out_dir, top, flags_var, flags, timeout):
    """Run ruckus's build target (dir/clean, load_source_code, build). Caller
    must hold backend_lock(backend). Output streams to pytest's captured fds
    like the old hand-built helpers."""
    out_dir.parent.mkdir(parents=True, exist_ok=True)
    env = _build_env(backend, out_dir, top, f"system_{backend}.mk", {flags_var: flags})
    result = _run_make(["build"], env, timeout)
    if result.returncode != 0:
        raise subprocess.CalledProcessError(result.returncode, result.args)
    return result


def make_tb(backend, out_dir, top, plusargs, timeout):
    """Run ruckus's tb target with build marked old, reusing the OUT_DIR
    artifacts without re-running dir, clean, load_source_code or build."""
    plusargs_str = " ".join(shlex.quote(str(arg)) for arg in plusargs)
    env = _build_env(backend, out_dir, top, f"system_{backend}.mk", {"SIM_PLUSARGS": plusargs_str})
    return _run_make(["-o", "build", "tb"], env, timeout, capture=True)
