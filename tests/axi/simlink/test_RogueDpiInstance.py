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
# - Sweep: Four Stream and two each Memory and SideBand contexts, plus null,
#   wrong-model, changed-port, and overlapping-port negative cases.
# - Stimulus: Build the xsim C adapters with host gcc and a minimal test-only
#   svdpi.h, create independent contexts, bind each endpoint pair, and exchange
#   tagged Stream, Memory, and SideBand traffic through real ZeroMQ peers.
# - Checks: Context pointers and traffic remain distinct; destroy permits
#   same-port reuse; invalid ownership/port operations return failure without
#   corrupting another context.
# - Timing: Peer receives and transport polling are bounded at five seconds;
#   no HDL simulator is required for this native adapter/lifecycle layer.

import ctypes
import fcntl
from pathlib import Path
import shlex
import shutil
import subprocess
import time

import pytest
import zmq

from tests.axi.simlink.rogue_tcp_peer import (
    decode_mem_response,
    decode_sideband_frame,
    decode_stream_frames,
    encode_mem_request,
    encode_sideband_frame,
    encode_stream_frame,
    T_READ,
    T_WRITE,
)

REPO_ROOT = Path(__file__).resolve().parents[3]
XSIM_DIR = REPO_ROOT / "axi" / "simlink" / "xsim"
SHARED_DIR = REPO_ROOT / "axi" / "simlink" / "shared"
TEST_INCLUDE_DIR = Path(__file__).resolve().parent / "include"
SIM_BUILD = Path(__file__).resolve().parent / "sim_build_RogueDpiInstance"
NATIVE_LIBRARY = SIM_BUILD / "libRogueTcpDpiNative.so"

Bit = ctypes.c_ubyte
BitPointer = ctypes.POINTER(Bit)
BitVector = ctypes.c_uint32
BitVectorPointer = ctypes.POINTER(BitVector)
Context = ctypes.c_void_p


def _build_native_library():
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
        XSIM_DIR / "RogueDpiInstance.c",
        XSIM_DIR / "RogueTcpStream.c",
        XSIM_DIR / "RogueTcpMemory.c",
        XSIM_DIR / "RogueSideBand.c",
    ]

    SIM_BUILD.mkdir(parents=True, exist_ok=True)
    with open(SIM_BUILD / ".build.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(
            [
                "gcc",
                "-std=c11",
                "-Wall",
                "-Wextra",
                "-Werror",
                "-fPIC",
                "-shared",
                f"-I{TEST_INCLUDE_DIR}",
                f"-I{XSIM_DIR}",
                f"-I{SHARED_DIR}",
                *(str(source) for source in sources),
                *zmq_flags,
                "-o",
                str(NATIVE_LIBRARY),
            ],
            check=True,
        )


def _configure_library(lib):
    lib.rogueTcpStreamCreate.restype = Context
    lib.rogueTcpStreamDestroy.argtypes = [Context]
    lib.rogueTcpStreamUpdate.restype = ctypes.c_int
    lib.rogueTcpStreamUpdate.argtypes = [
        Context,
        Bit,
        BitVectorPointer,
        Bit,
        Bit,
        BitPointer,
        BitVectorPointer,
        BitVectorPointer,
        BitVectorPointer,
        BitVectorPointer,
        BitVectorPointer,
        BitPointer,
        Bit,
        BitPointer,
        BitVectorPointer,
        BitVectorPointer,
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


@pytest.fixture(scope="module")
def native_library():
    _build_native_library()
    lib = ctypes.CDLL(str(NATIVE_LIBRARY))
    _configure_library(lib)
    return lib


def _step_stream(lib, context, port):
    port_num = BitVector(port)
    zero = BitVector(0)
    ob_valid = Bit(0)
    ob_last = Bit(0)
    ib_ready = Bit(0)
    return lib.rogueTcpStreamUpdate(
        context,
        Bit(0),
        ctypes.byref(port_num),
        Bit(0),
        Bit(0),
        ctypes.byref(ob_valid),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(ob_last),
        Bit(0),
        ctypes.byref(ib_ready),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(zero),
        Bit(0),
    )


def _step_memory(lib, context, port):
    port_num = BitVector(port)
    zero = BitVector(0)
    ar_valid = Bit(0)
    r_ready = Bit(0)
    aw_valid = Bit(0)
    w_valid = Bit(0)
    b_ready = Bit(0)
    return lib.rogueTcpMemoryUpdate(
        context,
        Bit(0),
        ctypes.byref(port_num),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(ar_valid),
        ctypes.byref(r_ready),
        Bit(0),
        ctypes.byref(zero),
        ctypes.byref(zero),
        Bit(0),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(aw_valid),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(w_valid),
        ctypes.byref(b_ready),
        Bit(0),
        Bit(0),
        ctypes.byref(zero),
        Bit(0),
    )


def _step_sideband(lib, context, port):
    port_num = BitVector(port)
    zero = BitVector(0)
    rx_enable = Bit(0)
    return lib.rogueSideBandUpdate(
        context,
        Bit(0),
        ctypes.byref(port_num),
        ctypes.byref(zero),
        Bit(0),
        ctypes.byref(zero),
        ctypes.byref(zero),
        ctypes.byref(rx_enable),
        ctypes.byref(zero),
    )


def _stream_cycle(lib, context, port, payload=b"", ob_ready=0):
    port_num = BitVector(port)
    data = int.from_bytes(payload.ljust(8, b"\x00"), byteorder="little")
    data_low = BitVector(data & 0xFFFFFFFF)
    data_high = BitVector(data >> 32)
    zero_in = BitVector(0)
    ob_valid = Bit(0)
    ob_data_low = BitVector(0)
    ob_data_high = BitVector(0)
    ob_user_low = BitVector(0)
    ob_user_high = BitVector(0)
    ob_keep = BitVector(0)
    ob_last = Bit(0)
    ib_ready = Bit(0)
    result = lib.rogueTcpStreamUpdate(
        context,
        Bit(0),
        ctypes.byref(port_num),
        Bit(0),
        Bit(ob_ready),
        ctypes.byref(ob_valid),
        ctypes.byref(ob_data_low),
        ctypes.byref(ob_data_high),
        ctypes.byref(ob_user_low),
        ctypes.byref(ob_user_high),
        ctypes.byref(ob_keep),
        ctypes.byref(ob_last),
        Bit(bool(payload)),
        ctypes.byref(ib_ready),
        ctypes.byref(data_low),
        ctypes.byref(data_high),
        ctypes.byref(zero_in),
        ctypes.byref(zero_in),
        ctypes.byref(BitVector((1 << len(payload)) - 1 if payload else 0)),
        Bit(bool(payload)),
    )
    output_word = ob_data_low.value | (ob_data_high.value << 32)
    output = bytes(
        (output_word >> (8 * index)) & 0xFF
        for index in range(8)
        if (ob_keep.value >> index) & 1
    )
    return result, bool(ob_valid.value), output


def _memory_cycle(
    lib,
    context,
    port,
    *,
    arready=0,
    rdata=0,
    rvalid=0,
    awready=0,
    wready=0,
    bvalid=0,
):
    port_num = BitVector(port)
    araddr = BitVector(0)
    arprot = BitVector(0)
    arvalid = Bit(0)
    rready = Bit(0)
    rdata_in = BitVector(rdata)
    rresp = BitVector(0)
    awaddr = BitVector(0)
    awprot = BitVector(0)
    awvalid = Bit(0)
    wdata = BitVector(0)
    wstrb = BitVector(0)
    wvalid = Bit(0)
    bready = Bit(0)
    bresp = BitVector(0)
    result = lib.rogueTcpMemoryUpdate(
        context,
        Bit(0),
        ctypes.byref(port_num),
        ctypes.byref(araddr),
        ctypes.byref(arprot),
        ctypes.byref(arvalid),
        ctypes.byref(rready),
        Bit(arready),
        ctypes.byref(rdata_in),
        ctypes.byref(rresp),
        Bit(rvalid),
        ctypes.byref(awaddr),
        ctypes.byref(awprot),
        ctypes.byref(awvalid),
        ctypes.byref(wdata),
        ctypes.byref(wstrb),
        ctypes.byref(wvalid),
        ctypes.byref(bready),
        Bit(awready),
        Bit(wready),
        ctypes.byref(bresp),
        Bit(bvalid),
    )
    return {
        "result": result,
        "araddr": araddr.value,
        "arvalid": bool(arvalid.value),
        "awaddr": awaddr.value,
        "awvalid": bool(awvalid.value),
        "wdata": wdata.value,
        "wvalid": bool(wvalid.value),
    }


def _sideband_cycle(lib, context, port, tx_opcode=0, tx_enable=0, tx_remdata=0):
    port_num = BitVector(port)
    tx_opcode_in = BitVector(tx_opcode)
    tx_remdata_in = BitVector(tx_remdata)
    rx_opcode = BitVector(0)
    rx_enable = Bit(0)
    rx_remdata = BitVector(0)
    result = lib.rogueSideBandUpdate(
        context,
        Bit(0),
        ctypes.byref(port_num),
        ctypes.byref(tx_opcode_in),
        Bit(tx_enable),
        ctypes.byref(tx_remdata_in),
        ctypes.byref(rx_opcode),
        ctypes.byref(rx_enable),
        ctypes.byref(rx_remdata),
    )
    return result, bool(rx_enable.value), rx_opcode.value, rx_remdata.value


def _peer_socket(context, socket_type, endpoint):
    socket = context.socket(socket_type)
    socket.setsockopt(zmq.LINGER, 0)
    socket.setsockopt(zmq.RCVTIMEO, 5000)
    socket.connect(endpoint)
    return socket


def test_dpi_instances_bind_independently_and_reuse_ports(native_library):
    lib = native_library
    specs = (
        [(lib.rogueTcpStreamCreate, lib.rogueTcpStreamDestroy, _step_stream)] * 4
        + [(lib.rogueTcpMemoryCreate, lib.rogueTcpMemoryDestroy, _step_memory)] * 2
        + [(lib.rogueSideBandCreate, lib.rogueSideBandDestroy, _step_sideband)] * 2
    )
    ports = tuple(19600 + (index * 2) for index in range(len(specs)))
    contexts = []

    try:
        for (create, destroy, step), port in zip(specs, ports):
            context = create()
            assert context
            assert step(lib, context, port) == 1
            contexts.append((context, destroy))

        assert len({int(context) for context, _ in contexts}) == len(contexts)
    finally:
        for context, destroy in reversed(contexts):
            destroy(context)

    for (create, destroy, step), port in zip(specs, ports):
        replacement = create()
        assert replacement
        try:
            assert step(lib, replacement, port) == 1
        finally:
            destroy(replacement)


def test_dpi_instances_exchange_isolated_active_traffic(native_library):
    lib = native_library
    zmq_context = zmq.Context()
    contexts = []
    sockets = []

    try:
        stream_models = []
        for tag in range(4):
            port = 19680 + (2 * tag)
            context = lib.rogueTcpStreamCreate()
            assert context
            contexts.append((context, lib.rogueTcpStreamDestroy))
            push = _peer_socket(zmq_context, zmq.PUSH, f"tcp://127.0.0.1:{port}")
            pull = _peer_socket(zmq_context, zmq.PULL, f"tcp://127.0.0.1:{port + 1}")
            sockets.extend((push, pull))
            assert _step_stream(lib, context, port) == 1
            stream_models.append((tag, port, context, push, pull))

        for tag, _, _, push, _ in stream_models:
            push.send_multipart(encode_stream_frame(0, 0, 0, bytes([0x10 + tag] * 4)))

        for tag, port, context, _, pull in stream_models:
            outbound = bytes([0x80 + tag] * 4)
            received = None
            cycle = 0
            deadline = time.monotonic() + 5.0
            while time.monotonic() < deadline:
                result, valid, payload = _stream_cycle(
                    lib,
                    context,
                    port,
                    payload=outbound if cycle == 0 else b"",
                )
                assert result == 1
                cycle += 1
                if valid:
                    received = payload
                    break
                time.sleep(0.001)
            assert received == bytes([0x10 + tag] * 4)
            assert decode_stream_frames(pull.recv_multipart())["data_hex"] == outbound.hex()

        memory_models = []
        for tag in range(2):
            port = 19688 + (2 * tag)
            context = lib.rogueTcpMemoryCreate()
            assert context
            contexts.append((context, lib.rogueTcpMemoryDestroy))
            push = _peer_socket(zmq_context, zmq.PUSH, f"tcp://127.0.0.1:{port}")
            pull = _peer_socket(zmq_context, zmq.PULL, f"tcp://127.0.0.1:{port + 1}")
            sockets.extend((push, pull))
            assert _step_memory(lib, context, port) == 1
            memory_models.append((tag, port, context, push, pull))

        for tag, port, context, push, pull in memory_models:
            address = 0x100 + (tag * 0x10)
            payload = bytes([0x40 + tag, 0x50 + tag, 0x60 + tag, 0x70 + tag])
            push.send_multipart(encode_mem_request(1, address, 4, T_WRITE, payload))

            deadline = time.monotonic() + 5.0
            while time.monotonic() < deadline:
                outputs = _memory_cycle(lib, context, port)
                assert outputs["result"] == 1
                if outputs["awvalid"] and outputs["wvalid"]:
                    break
                time.sleep(0.001)
            else:
                pytest.fail(f"memory instance {tag} did not issue its write")

            assert outputs["awaddr"] == address
            assert outputs["wdata"] == int.from_bytes(payload, byteorder="little")
            assert _memory_cycle(
                lib,
                context,
                port,
                awready=1,
                wready=1,
                bvalid=1,
            )["result"] == 1
            write_response = decode_mem_response(pull.recv_multipart())
            assert write_response["result"] == 0

            push.send_multipart(encode_mem_request(2, address, 4, T_READ))
            deadline = time.monotonic() + 5.0
            while time.monotonic() < deadline:
                outputs = _memory_cycle(lib, context, port)
                assert outputs["result"] == 1
                if outputs["arvalid"]:
                    break
                time.sleep(0.001)
            else:
                pytest.fail(f"memory instance {tag} did not issue its read")

            assert outputs["araddr"] == address
            assert _memory_cycle(lib, context, port, arready=1)["result"] == 1
            assert _memory_cycle(
                lib,
                context,
                port,
                rdata=int.from_bytes(payload, byteorder="little"),
                rvalid=1,
            )["result"] == 1
            read_response = decode_mem_response(pull.recv_multipart())
            assert read_response["data_hex"] == payload.hex()

        sideband_models = []
        for tag in range(2):
            port = 19692 + (2 * tag)
            context = lib.rogueSideBandCreate()
            assert context
            contexts.append((context, lib.rogueSideBandDestroy))
            push = _peer_socket(zmq_context, zmq.PUSH, f"tcp://127.0.0.1:{port + 1}")
            pull = _peer_socket(zmq_context, zmq.PULL, f"tcp://127.0.0.1:{port}")
            sockets.extend((push, pull))
            assert _step_sideband(lib, context, port) == 1
            sideband_models.append((tag, port, context, push, pull))

        for tag, _, _, push, _ in sideband_models:
            push.send(encode_sideband_frame(1, 0x20 + tag, 0, 0))
            push.send(encode_sideband_frame(0, 0, 1, 0x40 + tag))

        for tag, port, context, _, pull in sideband_models:
            received_opcode = None
            received_remdata = None
            cycle = 0
            deadline = time.monotonic() + 5.0
            while time.monotonic() < deadline:
                result, enabled, opcode, remdata = _sideband_cycle(
                    lib,
                    context,
                    port,
                    tx_opcode=0x60 + tag,
                    tx_enable=1 if cycle == 0 else 0,
                    tx_remdata=0x70 + tag,
                )
                assert result == 1
                if enabled:
                    received_opcode = opcode
                if remdata != 0:
                    received_remdata = remdata
                if received_opcode is not None and received_remdata is not None:
                    break
                cycle += 1
                time.sleep(0.001)
            assert received_opcode == 0x20 + tag
            assert received_remdata == 0x40 + tag
            outbound = decode_sideband_frame(pull.recv())
            assert outbound["opCode"] == 0x60 + tag
            assert outbound["remData"] == 0x70 + tag
    finally:
        for context, destroy in reversed(contexts):
            destroy(context)
        for socket in sockets:
            socket.close()
        zmq_context.term()


def test_dpi_rejects_overlapping_and_changed_ports(native_library):
    lib = native_library
    stream = lib.rogueTcpStreamCreate()
    memory = lib.rogueTcpMemoryCreate()
    sideband = lib.rogueSideBandCreate()
    assert stream and memory and sideband

    try:
        assert _step_stream(lib, stream, 19640) == 1
        assert _step_memory(lib, memory, 19641) == 0
        assert _step_stream(lib, stream, 19642) == 0
        assert _step_sideband(lib, sideband, 0) == 0
        assert _step_sideband(lib, sideband, 0xFFFF) == 0
    finally:
        lib.rogueSideBandDestroy(sideband)
        lib.rogueTcpMemoryDestroy(memory)
        lib.rogueTcpStreamDestroy(stream)


def test_dpi_rejects_null_and_wrong_model_contexts(native_library):
    lib = native_library
    stream = lib.rogueTcpStreamCreate()
    assert stream

    try:
        assert _step_stream(lib, None, 19650) == 0
        assert _step_memory(lib, stream, 19652) == 0
    finally:
        lib.rogueTcpStreamDestroy(stream)
