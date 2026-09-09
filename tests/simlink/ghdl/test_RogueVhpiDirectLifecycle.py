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
# - Sweep: Stream, Memory, and SideBand entry points in the common VHPIDIRECT
#   library, including same-model and cross-model registry paths.
# - Stimulus: Create one native instance, step it once to bind its endpoint
#   pair, destroy it, then create and bind a replacement on the same ports.
# - Checks: Handles are unique across model types, destroy releases a pair
#   for reuse by another model, and isolated child processes abort on a same-
#   model duplicate, cross-model adjacent-pair overlap, or invalid handle. On
#   Linux, a standalone executable runs under Valgrind and fails on leaks.
# - Timing: No peer connects and all receive paths are nonblocking.

import ctypes
import multiprocessing
import os
import resource
import signal
import shutil
import subprocess
import sys

import pytest

from tests.simlink.ghdl.simlink_test_utils import build_and_stage_so
from tests.simlink.paths import (
    GHDL_SOURCE_DIR,
    SIMLINK_TEST_ROOT,
    sim_build_dir,
)
from tests.simlink.ports import GHDL_LIFECYCLE, GHDL_LIFECYCLE_HARNESS

GHDL_DIR = GHDL_SOURCE_DIR
SIM_BUILD = sim_build_dir("ghdl", "RogueVhpiDirectLifecycle")
VALGRIND_HARNESS = SIM_BUILD / "vhpi_direct_lifecycle_harness"
VALGRIND_HARNESS_SOURCE = (
    SIMLINK_TEST_ROOT / "ghdl" / "vhpi_direct_lifecycle_harness.c"
)

STD_LOGIC_0 = 2
PORTS = {
    "stream": GHDL_LIFECYCLE.port_pair(0).first,
    "memory": GHDL_LIFECYCLE.port_pair(1).first,
    "sideband": GHDL_LIFECYCLE.port_pair(2).first,
}

BitVector = ctypes.POINTER(ctypes.c_ubyte)


def _vector(value, width):
    return (ctypes.c_ubyte * width)(
        *(3 if value & (1 << bit) else 2 for bit in range(width - 1, -1, -1))
    )


def _configure_stream(lib):
    lib.rogueTcpStreamCreate.restype = ctypes.c_int32
    lib.rogueTcpStreamDestroy.argtypes = [ctypes.c_int32]
    lib.rogueTcpStreamUpdate.argtypes = [
        ctypes.c_int32,
        ctypes.c_int32,
        ctypes.c_ubyte,
        BitVector,
        ctypes.c_ubyte,
        ctypes.c_ubyte,
        ctypes.c_ubyte,
        BitVector,
        BitVector,
        BitVector,
        ctypes.c_ubyte,
    ]

    def step(handle, port):
        zero64 = _vector(0, 64)
        lib.rogueTcpStreamUpdate(
            handle,
            8,
            STD_LOGIC_0,
            _vector(port, 16),
            STD_LOGIC_0,
            STD_LOGIC_0,
            STD_LOGIC_0,
            zero64,
            zero64,
            _vector(0, 8),
            STD_LOGIC_0,
        )

    return lib.rogueTcpStreamCreate, lib.rogueTcpStreamDestroy, step


def _configure_memory(lib):
    lib.rogueTcpMemoryCreate.restype = ctypes.c_int32
    lib.rogueTcpMemoryDestroy.argtypes = [ctypes.c_int32]
    lib.rogueTcpMemoryUpdate.argtypes = [
        ctypes.c_int32,
        ctypes.c_ubyte,
        BitVector,
        ctypes.c_ubyte,
        BitVector,
        BitVector,
        ctypes.c_ubyte,
        ctypes.c_ubyte,
        ctypes.c_ubyte,
        BitVector,
        ctypes.c_ubyte,
    ]

    def step(handle, port):
        lib.rogueTcpMemoryUpdate(
            handle,
            STD_LOGIC_0,
            _vector(port, 16),
            STD_LOGIC_0,
            _vector(0, 32),
            _vector(0, 2),
            STD_LOGIC_0,
            STD_LOGIC_0,
            STD_LOGIC_0,
            _vector(0, 2),
            STD_LOGIC_0,
        )

    return lib.rogueTcpMemoryCreate, lib.rogueTcpMemoryDestroy, step


def _configure_sideband(lib):
    lib.rogueSideBandCreate.restype = ctypes.c_int32
    lib.rogueSideBandDestroy.argtypes = [ctypes.c_int32]
    lib.rogueSideBandUpdate.argtypes = [
        ctypes.c_int32,
        ctypes.c_ubyte,
        BitVector,
        BitVector,
        ctypes.c_ubyte,
        BitVector,
    ]

    def step(handle, port):
        lib.rogueSideBandUpdate(
            handle,
            STD_LOGIC_0,
            _vector(port, 16),
            _vector(0, 8),
            STD_LOGIC_0,
            _vector(0, 8),
        )

    return lib.rogueSideBandCreate, lib.rogueSideBandDestroy, step


@pytest.fixture(scope="module")
def library_path():
    build_and_stage_so(GHDL_DIR, SIM_BUILD)
    return SIM_BUILD / "libRogueSimLinkVhpiDirect.so"


def test_vhpi_direct_destroy_releases_ports(library_path):

    models = (
        ("stream", _configure_stream),
        ("memory", _configure_memory),
        ("sideband", _configure_sideband),
    )
    lib = ctypes.CDLL(str(library_path))

    for name, configure in models:
        create, destroy, step = configure(lib)

        first_handle = create()
        assert first_handle > 0
        step(first_handle, PORTS[name])
        destroy(first_handle)

        second_handle = create()
        assert second_handle > 0
        assert second_handle != first_handle
        step(second_handle, PORTS[name])
        destroy(second_handle)


def test_vhpi_direct_registry_is_shared_across_models(library_path):
    lib = ctypes.CDLL(str(library_path))
    stream_create, stream_destroy, stream_step = _configure_stream(lib)
    memory_create, memory_destroy, memory_step = _configure_memory(lib)

    stream_handle = stream_create()
    memory_handle = memory_create()
    assert stream_handle > 0
    assert memory_handle > 0
    assert stream_handle != memory_handle

    stream_step(stream_handle, GHDL_LIFECYCLE_HARNESS.port_pair(3).first)
    stream_destroy(stream_handle)
    memory_step(memory_handle, GHDL_LIFECYCLE_HARNESS.port_pair(3).first)
    memory_destroy(memory_handle)


def _disable_core_dumps():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def _duplicate_port_worker(library_path, port):
    _disable_core_dumps()
    lib = ctypes.CDLL(library_path)
    create, _, step = _configure_stream(lib)
    first_handle = create()
    second_handle = create()
    step(first_handle, port)
    step(second_handle, port)


def _invalid_handle_worker(library_path):
    _disable_core_dumps()
    lib = ctypes.CDLL(library_path)
    _configure_stream(lib)
    lib.rogueTcpStreamDestroy(123456)


def _cross_model_overlap_worker(library_path, port):
    _disable_core_dumps()
    lib = ctypes.CDLL(library_path)
    stream_create, _, stream_step = _configure_stream(lib)
    memory_create, _, memory_step = _configure_memory(lib)
    stream_handle = stream_create()
    memory_handle = memory_create()
    stream_step(stream_handle, port)
    memory_step(memory_handle, port + 1)


def _assert_worker_aborts(target, *args):
    context = multiprocessing.get_context("spawn")
    process = context.Process(target=target, args=args)
    process.start()
    process.join(timeout=10)
    if process.is_alive():
        process.terminate()
        process.join(timeout=5)
        pytest.fail("negative VHPIDIRECT lifecycle worker hung")
    assert process.exitcode == -signal.SIGABRT


@pytest.mark.skipif(
    os.name != "posix" or sys.platform == "darwin",
    reason="SIGABRT regression is Linux-only to avoid macOS crash dialogs",
)
def test_vhpi_direct_rejects_duplicate_live_port(library_path):
    _assert_worker_aborts(
        _duplicate_port_worker,
        str(library_path),
        GHDL_LIFECYCLE.port_pair(3).first,
    )


@pytest.mark.skipif(
    os.name != "posix" or sys.platform == "darwin",
    reason="SIGABRT regression is Linux-only to avoid macOS crash dialogs",
)
def test_vhpi_direct_rejects_cross_model_port_pair_overlap(library_path):
    _assert_worker_aborts(
        _cross_model_overlap_worker,
        str(library_path),
        GHDL_LIFECYCLE.port_pair(4).first,
    )


@pytest.mark.skipif(
    os.name != "posix" or sys.platform == "darwin",
    reason="SIGABRT regression is Linux-only to avoid macOS crash dialogs",
)
def test_vhpi_direct_rejects_invalid_handle(library_path):
    _assert_worker_aborts(
        _invalid_handle_worker,
        str(library_path),
    )


@pytest.mark.skipif(
    sys.platform != "linux" or shutil.which("valgrind") is None,
    reason="native lifecycle leak check is Linux-only and needs valgrind on PATH",
)
def test_vhpi_direct_lifecycle_valgrind(library_path):
    subprocess.run(
        [
            "gcc",
            "-Wall",
            "-Wextra",
            "-Werror",
            str(VALGRIND_HARNESS_SOURCE),
            f"-L{SIM_BUILD}",
            f"-Wl,-rpath,{SIM_BUILD}",
            "-lRogueSimLinkVhpiDirect",
            "-o",
            str(VALGRIND_HARNESS),
        ],
        check=True,
    )
    subprocess.run(
        [
            "valgrind",
            "--tool=memcheck",
            "--leak-check=full",
            "--show-leak-kinds=definite,indirect",
            "--errors-for-leak-kinds=definite,indirect",
            "--error-exitcode=99",
            str(VALGRIND_HARNESS),
        ],
        check=True,
    )
