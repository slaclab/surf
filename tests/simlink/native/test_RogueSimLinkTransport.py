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
# - Sweep: Worker startup/bind failure, both socket orders, multipart traffic,
#   bounded queue ordering, timeout configuration, no/stalled-peer timeout,
#   and deterministic destroy.
# - Stimulus: Build the simulator-neutral transport as a native shared library,
#   create real loopback pyzmq peers, and exchange complete multipart messages.
# - Checks: Only the worker touches sockets; send rendezvous and shutdown are
#   bounded; received part boundaries survive; failures name model and port.
# - Timing: Host waits use short test-only millisecond bounds and do not model
#   simulated link bandwidth or latency.

import ctypes
import fcntl
import os
import shlex
import subprocess
import time

import pytest
import zmq

from tests.simlink.paths import SHARED_SOURCE_DIR, sim_build_dir
from tests.simlink.ports import NATIVE_TRANSPORT

SHARED_DIR = SHARED_SOURCE_DIR
SIM_BUILD = sim_build_dir("native", "RogueSimLinkTransport")
NATIVE_LIBRARY = SIM_BUILD / "libRogueSimLinkTransportNative.so"
MAX_PARTS = 6
MAX_INBOUND_BYTES = 1024 * 1024


class Message(ctypes.Structure):
    _fields_ = [
        ("size", ctypes.c_size_t * MAX_PARTS),
        ("data", ctypes.c_void_p * MAX_PARTS),
        ("count", ctypes.c_uint32),
        ("owned", ctypes.c_uint32),
    ]


@pytest.fixture(scope="module")
def transport_library():
    try:
        zmq_flags = shlex.split(
            subprocess.run(
                ["pkg-config", "--cflags", "--libs", "libzmq"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        pytest.skip("native transport test needs pkg-config and libzmq")

    SIM_BUILD.mkdir(parents=True, exist_ok=True)
    with open(SIM_BUILD / ".build.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        # Compile to a temp path and os.replace() into place so a concurrent
        # xdist worker never dlopens a half-written .so (atomic on same FS).
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
                f"-I{SHARED_DIR}",
                str(SHARED_DIR / "RogueSimLinkTransport.c"),
                *zmq_flags,
                "-o",
                str(tmp_library),
            ],
            check=True,
        )
        os.replace(tmp_library, NATIVE_LIBRARY)

    lib = ctypes.CDLL(str(NATIVE_LIBRARY))
    lib.rogueSimLinkMessageInit.argtypes = [ctypes.POINTER(Message)]
    lib.rogueSimLinkMessageAdd.restype = ctypes.c_int
    lib.rogueSimLinkMessageAdd.argtypes = [
        ctypes.POINTER(Message),
        ctypes.c_void_p,
        ctypes.c_size_t,
    ]
    lib.rogueSimLinkMessageRelease.argtypes = [ctypes.POINTER(Message)]
    lib.rogueSimLinkTransportResolveTimeout.restype = ctypes.c_int
    lib.rogueSimLinkTransportResolveTimeout.argtypes = [
        ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.c_char_p,
        ctypes.c_size_t,
    ]
    lib.rogueSimLinkTransportCreate.restype = ctypes.c_void_p
    lib.rogueSimLinkTransportCreate.argtypes = [
        ctypes.c_uint16,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_size_t,
    ]
    lib.rogueSimLinkTransportStart.restype = ctypes.c_int
    lib.rogueSimLinkTransportStart.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    lib.rogueSimLinkTransportSend.restype = ctypes.c_int
    lib.rogueSimLinkTransportSend.argtypes = [
        ctypes.c_void_p,
        ctypes.POINTER(Message),
        ctypes.c_uint32,
    ]
    lib.rogueSimLinkTransportReceive.restype = ctypes.c_int
    lib.rogueSimLinkTransportReceive.argtypes = [
        ctypes.c_void_p,
        ctypes.POINTER(Message),
    ]
    lib.rogueSimLinkTransportCopyError.restype = ctypes.c_int
    lib.rogueSimLinkTransportCopyError.argtypes = [
        ctypes.c_void_p,
        ctypes.c_char_p,
        ctypes.c_size_t,
    ]
    lib.rogueSimLinkTransportDestroy.argtypes = [ctypes.c_void_p]
    return lib


def _resolve_timeout(lib, instance_timeout=0):
    timeout = ctypes.c_uint32()
    error = ctypes.create_string_buffer(512)
    result = lib.rogueSimLinkTransportResolveTimeout(
        instance_timeout, ctypes.byref(timeout), error, len(error)
    )
    return result, timeout.value, error.value


def test_transport_timeout_default_and_environment_override(
    transport_library, monkeypatch
):
    monkeypatch.delenv("SURF_SIMLINK_TRANSPORT_TIMEOUT_MS", raising=False)
    assert _resolve_timeout(transport_library) == (1, 30_000, b"")

    monkeypatch.setenv("SURF_SIMLINK_TRANSPORT_TIMEOUT_MS", "275")
    assert _resolve_timeout(transport_library) == (1, 275, b"")

    # A timeout already resolved for an instance remains stable if the
    # process-wide environment later changes.
    monkeypatch.setenv("SURF_SIMLINK_TRANSPORT_TIMEOUT_MS", "invalid")
    assert _resolve_timeout(transport_library, 125) == (1, 125, b"")


@pytest.mark.parametrize(
    "value", ("", "0", "-1", "+1", "1ms", "4294967296")
)
def test_transport_timeout_rejects_invalid_environment_value(
    transport_library, monkeypatch, value
):
    monkeypatch.setenv("SURF_SIMLINK_TRANSPORT_TIMEOUT_MS", value)
    result, _, error = _resolve_timeout(transport_library)
    assert result == 0
    assert b"SURF_SIMLINK_TRANSPORT_TIMEOUT_MS" in error
    assert b"1 through 4294967295 milliseconds" in error


def _message(lib, parts):
    message = Message()
    lib.rogueSimLinkMessageInit(ctypes.byref(message))
    for part in parts:
        data = ctypes.create_string_buffer(part)
        assert lib.rogueSimLinkMessageAdd(
            ctypes.byref(message), data, len(part)
        ) == 1
    return message


def _parts(message):
    return [
        ctypes.string_at(message.data[index], message.size[index])
        for index in range(message.count)
    ]


def _receive(lib, transport):
    deadline = time.monotonic() + 5.0
    while time.monotonic() < deadline:
        message = Message()
        result = lib.rogueSimLinkTransportReceive(
            transport, ctypes.byref(message)
        )
        assert result >= 0
        if result == 1:
            return message
        time.sleep(0.001)
    pytest.fail("transport did not receive multipart message")


def _receive_parts(lib, transport):
    message = _receive(lib, transport)
    try:
        return _parts(message)
    finally:
        lib.rogueSimLinkMessageRelease(ctypes.byref(message))


@pytest.mark.parametrize(
    ("base_port", "order", "peer_push_port", "peer_pull_port"),
    (
        pytest.param(
            NATIVE_TRANSPORT.port_pair(0).first,
            0,
            NATIVE_TRANSPORT.port_pair(0).first,
            NATIVE_TRANSPORT.port_pair(0).second,
            id="pull-base",
        ),
        pytest.param(
            NATIVE_TRANSPORT.port_pair(3).first,
            1,
            NATIVE_TRANSPORT.port_pair(3).second,
            NATIVE_TRANSPORT.port_pair(3).first,
            id="push-base",
        ),
    ),
)
def test_worker_exchanges_complete_multipart_messages(
    transport_library,
    base_port,
    order,
    peer_push_port,
    peer_pull_port,
):
    lib = transport_library
    transport = lib.rogueSimLinkTransportCreate(
        base_port, order, b"TransportTraffic", MAX_INBOUND_BYTES
    )
    assert transport
    assert lib.rogueSimLinkTransportStart(transport, 1000) == 1

    context = zmq.Context()
    push = context.socket(zmq.PUSH)
    pull = context.socket(zmq.PULL)
    for socket in (push, pull):
        socket.setsockopt(zmq.LINGER, 0)
    push.connect(f"tcp://127.0.0.1:{peer_push_port}")
    pull.connect(f"tcp://127.0.0.1:{peer_pull_port}")
    try:
        outbound = _message(lib, (b"header", b"payload"))
        assert lib.rogueSimLinkTransportSend(
            transport, ctypes.byref(outbound), 2000
        ) == 1
        assert pull.recv_multipart() == [b"header", b"payload"]
        lib.rogueSimLinkMessageRelease(ctypes.byref(outbound))

        push.send_multipart((b"request", b"data", b"tail"))
        inbound = _receive(lib, transport)
        assert _parts(inbound) == [b"request", b"data", b"tail"]
        lib.rogueSimLinkMessageRelease(ctypes.byref(inbound))
    finally:
        started = time.monotonic()
        lib.rogueSimLinkTransportDestroy(transport)
        assert time.monotonic() - started < 1.0
        push.close()
        pull.close()
        context.term()


@pytest.mark.parametrize(
    ("base_port", "order", "push_port"),
    (
        pytest.param(
            NATIVE_TRANSPORT.port_pair(1).first,
            0,
            NATIVE_TRANSPORT.port_pair(1).second,
            id="pull-base",
        ),
        pytest.param(
            NATIVE_TRANSPORT.port_pair(4).first,
            1,
            NATIVE_TRANSPORT.port_pair(4).first,
            id="push-base",
        ),
    ),
)
def test_no_peer_send_times_out_with_diagnostic(
    transport_library, base_port, order, push_port
):
    lib = transport_library
    transport = lib.rogueSimLinkTransportCreate(
        base_port, order, b"TimeoutModel", MAX_INBOUND_BYTES
    )
    assert transport
    assert lib.rogueSimLinkTransportStart(transport, 1000) == 1
    message = _message(lib, (b"blocked",))

    started = time.monotonic()
    assert lib.rogueSimLinkTransportSend(
        transport, ctypes.byref(message), 200
    ) == 0
    assert time.monotonic() - started < 1.0
    error = ctypes.create_string_buffer(512)
    assert lib.rogueSimLinkTransportCopyError(
        transport, error, len(error)
    ) == 1
    assert b"TimeoutModel" in error.value
    assert str(push_port).encode() in error.value
    assert b"timeout" in error.value

    lib.rogueSimLinkMessageRelease(ctypes.byref(message))
    started = time.monotonic()
    lib.rogueSimLinkTransportDestroy(transport)
    assert time.monotonic() - started < 1.0


def test_inbound_queue_preserves_messages_beyond_worker_depth(
    transport_library,
):
    lib = transport_library
    transport = lib.rogueSimLinkTransportCreate(
        NATIVE_TRANSPORT.port_pair(5).first, 0, b"InboundQueue", MAX_INBOUND_BYTES
    )
    assert transport
    assert lib.rogueSimLinkTransportStart(transport, 1000) == 1

    context = zmq.Context()
    push = context.socket(zmq.PUSH)
    push.setsockopt(zmq.LINGER, 0)
    push.connect(f"tcp://127.0.0.1:{NATIVE_TRANSPORT.port_pair(5).first}")
    expected = [index.to_bytes(2, "little") for index in range(20)]
    try:
        for part in expected:
            push.send(part)
        assert [_receive_parts(lib, transport) for _ in expected] == [
            [part] for part in expected
        ]
    finally:
        lib.rogueSimLinkTransportDestroy(transport)
        push.close()
        context.term()


@pytest.mark.parametrize(
    ("parts", "base_port"),
    (
        pytest.param(
            (b"123456789",), NATIVE_TRANSPORT.port_pair(7).first, id="single-part"
        ),
        pytest.param(
            (b"12345", b"6789"),
            NATIVE_TRANSPORT.port_pair(8).first,
            id="multipart-total",
        ),
    ),
)
def test_inbound_message_byte_limit_is_enforced_before_copy(
    transport_library, parts, base_port
):
    lib = transport_library
    transport = lib.rogueSimLinkTransportCreate(
        base_port, 0, b"InboundLimit", 8
    )
    assert transport
    assert lib.rogueSimLinkTransportStart(transport, 1000) == 1

    context = zmq.Context()
    push = context.socket(zmq.PUSH)
    push.setsockopt(zmq.LINGER, 0)
    push.connect(f"tcp://127.0.0.1:{base_port}")
    try:
        # Cover both a single oversized part and individually legal parts whose
        # cumulative size exceeds the complete-message allocation budget.
        push.send_multipart(parts)

        deadline = time.monotonic() + 2.0
        while time.monotonic() < deadline:
            message = Message()
            result = lib.rogueSimLinkTransportReceive(
                transport, ctypes.byref(message)
            )
            if result == -1:
                break
            assert result == 0
            time.sleep(0.001)
        else:
            pytest.fail("transport did not reject oversized inbound message")

        error = ctypes.create_string_buffer(512)
        assert lib.rogueSimLinkTransportCopyError(
            transport, error, len(error)
        ) == 1
        assert b"InboundLimit" in error.value
        assert b"exceeds 8 bytes" in error.value
        assert str(base_port).encode() in error.value
    finally:
        lib.rogueSimLinkTransportDestroy(transport)
        push.close()
        context.term()


def test_connected_stalled_peer_send_is_bounded(transport_library):
    lib = transport_library
    transport = lib.rogueSimLinkTransportCreate(
        NATIVE_TRANSPORT.port_pair(6).first, 0, b"StalledPeer", MAX_INBOUND_BYTES
    )
    assert transport
    assert lib.rogueSimLinkTransportStart(transport, 1000) == 1

    context = zmq.Context()
    pull = context.socket(zmq.PULL)
    pull.setsockopt(zmq.LINGER, 0)
    pull.setsockopt(zmq.RCVHWM, 1)
    pull.setsockopt(zmq.RCVBUF, 1024)
    pull.connect(f"tcp://127.0.0.1:{NATIVE_TRANSPORT.port_pair(6).second}")
    message = _message(lib, (bytes(64 * 1024),))
    try:
        time.sleep(0.05)
        started = time.monotonic()
        for completed in range(1100):
            if lib.rogueSimLinkTransportSend(
                transport, ctypes.byref(message), 300
            ) == 0:
                break
        else:
            pytest.fail("stalled peer did not saturate transport")
        assert completed < 1100
        assert time.monotonic() - started < 3.0
        error = ctypes.create_string_buffer(512)
        assert lib.rogueSimLinkTransportCopyError(
            transport, error, len(error)
        ) == 1
        assert b"StalledPeer" in error.value
        assert str(NATIVE_TRANSPORT.port_pair(6).second).encode() in error.value
        assert b"timeout" in error.value
    finally:
        lib.rogueSimLinkMessageRelease(ctypes.byref(message))
        lib.rogueSimLinkTransportDestroy(transport)
        pull.close()
        context.term()


def test_worker_bind_failure_is_bounded_and_diagnostic(transport_library):
    lib = transport_library
    blocker_context = zmq.Context()
    blocker = blocker_context.socket(zmq.PULL)
    blocker.setsockopt(zmq.LINGER, 0)
    blocker.bind(f"tcp://127.0.0.1:{NATIVE_TRANSPORT.port_pair(2).first}")
    transport = lib.rogueSimLinkTransportCreate(
        NATIVE_TRANSPORT.port_pair(2).first, 0, b"BindModel", MAX_INBOUND_BYTES
    )
    assert transport
    try:
        assert lib.rogueSimLinkTransportStart(transport, 1000) == 0
        error = ctypes.create_string_buffer(512)
        assert lib.rogueSimLinkTransportCopyError(
            transport, error, len(error)
        ) == 1
        assert b"BindModel" in error.value
        assert str(NATIVE_TRANSPORT.port_pair(2).first).encode() in error.value
        assert b"bind" in error.value
    finally:
        lib.rogueSimLinkTransportDestroy(transport)
        blocker.close()
        blocker_context.term()
