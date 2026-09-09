##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import ctypes
import fcntl
import os
import shlex
import shutil
import subprocess

import pytest

from tests.simlink.paths import (
    SHARED_SOURCE_DIR,
    SIMLINK_TEST_ROOT,
    XSIM_SOURCE_DIR,
    sim_build_dir,
)

XSIM_DIR = XSIM_SOURCE_DIR
SHARED_DIR = SHARED_SOURCE_DIR
NATIVE_TEST_DIR = SIMLINK_TEST_ROOT / "native"
TEST_INCLUDE_DIR = NATIVE_TEST_DIR / "include"
NATIVE_PROBE_SOURCE = NATIVE_TEST_DIR / "native_stream_transport_probe.c"
SIM_BUILD = sim_build_dir("native", "RogueDpiInstance")
NATIVE_LIBRARY = SIM_BUILD / "libRogueSimLinkDpiNative.so"

Bit = ctypes.c_ubyte
BitPointer = ctypes.POINTER(Bit)
BitVector = ctypes.c_uint32
BitVectorPointer = ctypes.POINTER(BitVector)
Context = ctypes.c_void_p


def build_native_library():
    if shutil.which("gcc") is None or shutil.which("pkg-config") is None:
        pytest.skip("native DPI ownership test needs gcc and pkg-config")

    try:
        zmq_flags = shlex.split(
            subprocess.run(
                ["pkg-config", "--cflags", "--libs", "libzmq"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout
        )
    except subprocess.CalledProcessError:
        pytest.skip("native DPI ownership test needs libzmq development files")

    sources = [
        SHARED_DIR / "RogueSimLinkInstance.c",
        SHARED_DIR / "RogueSimLinkTransport.c",
        XSIM_DIR / "RogueDpiInstance.c",
        XSIM_DIR / "RogueTcpStream.c",
        SHARED_DIR / "RogueTcpStreamCore.c",
        XSIM_DIR / "RogueTcpMemory.c",
        SHARED_DIR / "RogueTcpMemoryCore.c",
        XSIM_DIR / "RogueSideBand.c",
        SHARED_DIR / "RogueSideBandCore.c",
        NATIVE_PROBE_SOURCE,
    ]

    SIM_BUILD.mkdir(parents=True, exist_ok=True)
    with open(SIM_BUILD / ".build.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        # Compile to a private temp path, then atomically rename into place.
        # gcc writes the output object in place, so a plain `-o NATIVE_LIBRARY`
        # lets a concurrent reader (another xdist worker's ctypes.CDLL or probe
        # subprocess) dlopen a half-written file ("invalid ELF header" /
        # "file too short"). os.replace() is atomic on the same filesystem, so
        # readers always see either the old or a complete new library.
        tmp_library = NATIVE_LIBRARY.with_name(
            f"{NATIVE_LIBRARY.name}.{os.getpid()}.tmp")
        subprocess.run(
            [
                "gcc",
                "-std=c11",
                "-Wall",
                "-Wextra",
                "-Werror",
                "-fPIC",
                "-shared",
                "-pthread",
                "-DROGUE_SIM_LINK_NATIVE_TEST",
                f"-I{TEST_INCLUDE_DIR}",
                f"-I{XSIM_DIR}",
                f"-I{SHARED_DIR}",
                *(str(source) for source in sources),
                *zmq_flags,
                "-o",
                str(tmp_library),
            ],
            check=True,
        )
        os.replace(tmp_library, NATIVE_LIBRARY)


def configure_library(lib):
    lib.rogueTcpStreamCreate.restype = Context
    lib.rogueTcpStreamDestroy.argtypes = [Context]
    lib.rogueTcpStreamUpdate.restype = ctypes.c_int
    lib.rogueTcpStreamUpdate.argtypes = [
        Context,
        ctypes.c_int,
        Bit,
        BitVectorPointer,
        Bit,
        Bit,
        BitPointer,
        BitVectorPointer,
        BitVectorPointer,
        BitVectorPointer,
        BitPointer,
        Bit,
        BitPointer,
        BitVectorPointer,
        BitVectorPointer,
        BitVectorPointer,
        Bit,
    ]

    lib.rogueTcpMemoryCreate.restype = Context
    lib.rogueTcpMemoryDestroy.argtypes = [Context]
    lib.rogueTcpMemoryUpdate.restype = ctypes.c_int
    lib.rogueTcpMemoryUpdate.argtypes = [
        Context,
        Bit,
        BitVectorPointer,
        BitVectorPointer,
        BitVectorPointer,
        BitPointer,
        BitPointer,
        Bit,
        BitVectorPointer,
        BitVectorPointer,
        Bit,
        BitVectorPointer,
        BitVectorPointer,
        BitPointer,
        BitVectorPointer,
        BitVectorPointer,
        BitPointer,
        BitPointer,
        Bit,
        Bit,
        BitVectorPointer,
        Bit,
    ]

    lib.rogueSideBandCreate.restype = Context
    lib.rogueSideBandDestroy.argtypes = [Context]
    lib.rogueSideBandUpdate.restype = ctypes.c_int
    lib.rogueSideBandUpdate.argtypes = [
        Context,
        Bit,
        BitVectorPointer,
        BitVectorPointer,
        Bit,
        BitVectorPointer,
        BitVectorPointer,
        BitPointer,
        BitVectorPointer,
    ]

    lib.simLinkNativeStreamSend.restype = ctypes.c_int
    lib.simLinkNativeStreamSend.argtypes = [Context, ctypes.c_uint32]


def step_stream(lib, context, port, reset=0):
    port_num = BitVector(port)
    ob_data = (BitVector * 2)()
    ob_user = (BitVector * 2)()
    ob_keep = BitVector(0)
    ib_data = (BitVector * 2)()
    ib_user = (BitVector * 2)()
    ib_keep = BitVector(0)
    ob_valid = Bit(0)
    ob_last = Bit(0)
    ib_ready = Bit(0)
    return lib.rogueTcpStreamUpdate(
        context,
        8,
        Bit(reset),
        ctypes.byref(port_num),
        Bit(0),
        Bit(0),
        ctypes.byref(ob_valid),
        ob_data,
        ob_user,
        ctypes.byref(ob_keep),
        ctypes.byref(ob_last),
        Bit(0),
        ctypes.byref(ib_ready),
        ib_data,
        ib_user,
        ctypes.byref(ib_keep),
        Bit(0),
    )


def stream_cycle(lib, context, port, payload=b"", ob_ready=0, data_bytes=8):
    if len(payload) > data_bytes:
        raise ValueError("payload does not fit in one native Stream beat")
    port_num = BitVector(port)
    data_words = (data_bytes + 3) // 4
    keep_words = (data_bytes + 31) // 32
    padded = payload.ljust(data_words * 4, b"\x00")
    ib_data = (BitVector * data_words)(*(
        int.from_bytes(padded[index:index + 4], byteorder="little")
        for index in range(0, len(padded), 4)
    ))
    ib_user = (BitVector * data_words)()
    ib_keep = (BitVector * keep_words)()
    for index in range(len(payload)):
        ib_keep[index // 32] |= 1 << (index % 32)
    ob_valid = Bit(0)
    ob_data = (BitVector * data_words)()
    ob_user = (BitVector * data_words)()
    ob_keep = (BitVector * keep_words)()
    ob_last = Bit(0)
    ib_ready = Bit(0)
    result = lib.rogueTcpStreamUpdate(
        context,
        data_bytes,
        Bit(0),
        ctypes.byref(port_num),
        Bit(0),
        Bit(ob_ready),
        ctypes.byref(ob_valid),
        ob_data,
        ob_user,
        ob_keep,
        ctypes.byref(ob_last),
        Bit(bool(payload)),
        ctypes.byref(ib_ready),
        ib_data,
        ib_user,
        ib_keep,
        Bit(bool(payload)),
    )
    output = bytes(
        (ob_data[index // 4] >> (8 * (index % 4))) & 0xFF
        for index in range(data_bytes)
        if (ob_keep[index // 32] >> (index % 32)) & 1
    )
    return result, bool(ob_valid.value), output
