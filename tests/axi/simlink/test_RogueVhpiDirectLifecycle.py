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
# - Sweep: Stream, Memory, and SideBand VHPIDIRECT shared libraries, plus
#   Stream negative paths shared by the common registry implementation.
# - Stimulus: Create one native instance, step it once to bind its endpoint
#   pair, destroy it, then create and bind a replacement on the same ports.
# - Checks: Both create calls return positive distinct handles and the second
#   bind succeeds. Isolated child processes must abort on a duplicate live port
#   and an invalid handle, proving those errors fail clearly without killing
#   the pytest controller.
# - Timing: No peer connects and all receive paths are nonblocking.

import ctypes
import multiprocessing
import os
from pathlib import Path
import resource
import signal
import sys

import pytest

from tests.axi.simlink.simlink_test_utils import build_and_stage_so

GHDL_DIR = Path(__file__).resolve().parents[3] / "axi" / "simlink" / "ghdl"
SIM_BUILD = Path(__file__).resolve().parent / "sim_build_RogueVhpiDirectLifecycle"

STD_LOGIC_0 = 2
PORTS = {
    "stream": 9640,
    "memory": 9642,
    "sideband": 9644,
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
        ctypes.c_ubyte,
        BitVector,
        ctypes.c_ubyte,
        ctypes.c_ubyte,
        ctypes.c_ubyte,
        BitVector,
        BitVector,
        BitVector,
        BitVector,
        BitVector,
        ctypes.c_ubyte,
    ]

    def step(handle, port):
        zero32 = _vector(0, 32)
        lib.rogueTcpStreamUpdate(
            handle,
            STD_LOGIC_0,
            _vector(port, 16),
            STD_LOGIC_0,
            STD_LOGIC_0,
            STD_LOGIC_0,
            zero32,
            zero32,
            zero32,
            zero32,
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
def libraries():
    library_names = (
        "libRogueTcpStream.so",
        "libRogueTcpMemory.so",
        "libRogueSideBand.so",
    )
    for library_name in library_names:
        build_and_stage_so(GHDL_DIR, library_name, SIM_BUILD)
    return {name: SIM_BUILD / name for name in library_names}


def test_vhpi_direct_destroy_releases_ports(libraries):

    models = (
        ("stream", "libRogueTcpStream.so", _configure_stream),
        ("memory", "libRogueTcpMemory.so", _configure_memory),
        ("sideband", "libRogueSideBand.so", _configure_sideband),
    )

    for name, library_name, configure in models:
        lib = ctypes.CDLL(str(libraries[library_name]))
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
def test_vhpi_direct_rejects_duplicate_live_port(libraries):
    _assert_worker_aborts(
        _duplicate_port_worker,
        str(libraries["libRogueTcpStream.so"]),
        9646,
    )


@pytest.mark.skipif(
    os.name != "posix" or sys.platform == "darwin",
    reason="SIGABRT regression is Linux-only to avoid macOS crash dialogs",
)
def test_vhpi_direct_rejects_invalid_handle(libraries):
    _assert_worker_aborts(
        _invalid_handle_worker,
        str(libraries["libRogueTcpStream.so"]),
    )
