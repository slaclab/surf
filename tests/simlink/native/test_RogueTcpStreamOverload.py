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
# - Sweep: No-peer first send, late peer arrival, stopped peer/high-water-mark
#   saturation, disconnect/reconnect, reset/destroy with an unread frame, and
#   receive-cycle counts under two peer wall-clock delays, plus invalid
#   production timeout configuration. Existing lifecycle tests retain rebind
#   and multi-instance coverage.
# - Stimulus: Run the native xsim-compatible adapter in child processes so a
#   synchronous ZeroMQ send can be observed without blocking the pytest
#   process; connect deterministic pyzmq peers only at the declared points.
# - Checks: Bound every child wait, require no-peer and stalled-peer sends to
#   fail diagnostically, prove late connection releases the callback, and
#   require zero-linger destroy to finish normally.
# - Timing: Wall-clock limits characterize host transport only; they do not
#   represent simulated Stream latency or bandwidth.

import json
import select
import subprocess
import sys
import time

import pytest
import zmq

from tests.simlink.common.simlink_protocol import (
    decode_stream_frames,
    encode_stream_frame,
)
from tests.simlink.common.zmq_sockets import pull_socket
from tests.simlink.native.native_adapter_utils import (
    build_native_library,
    NATIVE_LIBRARY,
)

from tests.simlink.paths import REPO_ROOT, SIMLINK_TEST_ROOT
from tests.simlink.ports import NATIVE_STREAM_OVERLOAD

HERE = SIMLINK_TEST_ROOT / "native"
PROBE = HERE / "simlink_stream_overload_probe.py"


@pytest.fixture(scope="module")
def native_library_path():
    build_native_library()
    return NATIVE_LIBRARY


def _start_probe(
    library,
    mode,
    port,
    *,
    count=None,
    cycle_sleep=None,
    frame_size=None,
):
    command = [sys.executable, str(PROBE), str(library), mode, str(port)]
    if count is not None:
        command.extend(("--count", str(count)))
    if cycle_sleep is not None:
        command.extend(("--cycle-sleep", str(cycle_sleep)))
    if frame_size is not None:
        command.extend(("--frame-size", str(frame_size)))
    return subprocess.Popen(
        command,
        cwd=REPO_ROOT,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def _decode_events(output):
    events = []
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict) and "event" in event:
            events.append(event)
    return events


def _wait_for_event(process, expected, timeout=5.0):
    lines = []
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        ready, _, _ = select.select(
            [process.stdout], [], [], deadline - time.monotonic()
        )
        if not ready:
            break
        line = process.stdout.readline()
        if line == "":
            break
        lines.append(line)
        events = _decode_events(line)
        if events and events[-1]["event"] == expected:
            return events[-1], "".join(lines)
    stdout, stderr = process.communicate(timeout=5)
    pytest.fail(
        f"probe did not report {expected!r}; stdout={''.join(lines) + stdout!r}, "
        f"stderr={stderr!r}"
    )


def _terminate(process):
    process.kill()
    return process.communicate(timeout=5)


def _wait_for_stall(process, prefix, idle_timeout=0.5, total_timeout=10.0):
    output = [prefix]
    last_progress = time.monotonic()
    last_event = _decode_events(prefix)[-1]
    deadline = time.monotonic() + total_timeout

    while time.monotonic() < deadline:
        wait_time = min(
            idle_timeout - (time.monotonic() - last_progress),
            deadline - time.monotonic(),
        )
        if wait_time <= 0:
            return last_event, "".join(output)
        ready, _, _ = select.select([process.stdout], [], [], wait_time)
        if not ready:
            return last_event, "".join(output)
        line = process.stdout.readline()
        if line == "":
            stdout, stderr = process.communicate(timeout=5)
            return None, "".join(output) + stdout, stderr
        output.append(line)
        events = _decode_events(line)
        if events:
            last_event = events[-1]
            last_progress = time.monotonic()

    pytest.fail(f"probe did not stall or exit within {total_timeout} s")


def _pull_socket(context, port, receive_hwm=None):
    return pull_socket(context, port, receive_hwm=receive_hwm)


def _assert_bounded_completion(process, output, stderr, port):
    assert process.returncode is not None
    if process.returncode == 0:
        assert _decode_events(output)[-1]["event"] == "destroyed"
    else:
        diagnostic = stderr.lower()
        assert "roguetcpstream" in diagnostic
        assert str(port) in diagnostic
        assert "timeout" in diagnostic


def test_no_peer_outbound_operation_is_bounded(native_library_path):
    port = NATIVE_STREAM_OVERLOAD.port_pair(0).first
    process = _start_probe(native_library_path, "send", port)
    ready, prefix = _wait_for_event(process, "ready")
    try:
        stdout, stderr = process.communicate(timeout=1.0)
    except subprocess.TimeoutExpired:
        stdout, stderr = _terminate(process)
        pytest.fail(
            "no-peer Stream send remained blocked after 1.0 s; "
            f"last event={ready}"
        )

    _assert_bounded_completion(process, prefix + stdout, stderr, port + 1)


def test_invalid_timeout_configuration_fails_at_model_startup(
    native_library_path, monkeypatch
):
    monkeypatch.setenv("SURF_SIMLINK_TRANSPORT_TIMEOUT_MS", "invalid")
    process = _start_probe(
        native_library_path, "send", NATIVE_STREAM_OVERLOAD.port_pair(8).first
    )
    stdout, stderr = process.communicate(timeout=5)

    assert process.returncode != 0
    assert stdout == ""
    assert "SURF_SIMLINK_TRANSPORT_TIMEOUT_MS" in stderr
    assert "1 through 4294967295 milliseconds" in stderr
    assert "Listening on ports" not in stderr


def test_late_peer_releases_paused_callback(native_library_path):
    port = NATIVE_STREAM_OVERLOAD.port_pair(1).first
    process = _start_probe(native_library_path, "send-hold", port)
    ready, prefix = _wait_for_event(process, "ready")
    time.sleep(0.1)
    assert process.poll() is None
    assert ready["operation"] == "socket_bind"
    assert ready["completed_messages"] == 0

    context = zmq.Context()
    pull = context.socket(zmq.PULL)
    pull.setsockopt(zmq.LINGER, 0)
    pull.setsockopt(zmq.RCVTIMEO, 5000)
    pull.connect(f"tcp://127.0.0.1:{port + 1}")
    try:
        received = decode_stream_frames(pull.recv_multipart())
        process.stdin.write("release\n")
        process.stdin.flush()
        stdout, stderr = process.communicate(timeout=5)
    finally:
        if process.poll() is None:
            _terminate(process)
        pull.close()
        context.term()

    assert process.returncode == 0
    assert received["data_hex"] == "5a"
    events = _decode_events(prefix + stdout)
    assert [event["event"] for event in events] == [
        "ready",
        "sent",
        "destroyed",
    ]
    assert events[-1]["completed_messages"] == 1
    assert stderr == ""


def test_zero_linger_destroy_with_unread_frame_is_bounded(native_library_path):
    port = NATIVE_STREAM_OVERLOAD.port_pair(2).first
    process = _start_probe(native_library_path, "send", port)
    _, prefix = _wait_for_event(process, "ready")

    context = zmq.Context()
    pull = context.socket(zmq.PULL)
    pull.setsockopt(zmq.LINGER, 0)
    pull.connect(f"tcp://127.0.0.1:{port + 1}")
    try:
        stdout, stderr = process.communicate(timeout=5)
    finally:
        if process.poll() is None:
            _terminate(process)
        pull.close()
        context.term()

    assert process.returncode == 0
    events = _decode_events(prefix + stdout)
    assert [event["event"] for event in events] == [
        "ready",
        "sent",
        "destroyed",
    ]
    assert stderr == ""


def test_stalled_peer_high_water_mark_operation_is_bounded(native_library_path):
    process = _start_probe(
        native_library_path,
        "send-many",
        NATIVE_STREAM_OVERLOAD.port_pair(3).first,
        count=10_000,
        frame_size=65536,
    )
    _, prefix = _wait_for_event(process, "ready")

    context = zmq.Context()
    pull = _pull_socket(
        context, NATIVE_STREAM_OVERLOAD.port_pair(3).second, receive_hwm=1
    )
    try:
        pull.recv_multipart()
        result = _wait_for_stall(process, prefix)
        if len(result) == 2:
            last_event, stdout = result
            stdout, stderr = _terminate(process)
            pytest.fail(
                "stalled-peer Stream send made no progress for 0.5 s; "
                f"last event={last_event}"
            )
        _, stdout, stderr = result
    finally:
        if process.poll() is None:
            _terminate(process)
        pull.close()
        context.term()

    _assert_bounded_completion(
        process,
        prefix + stdout,
        stderr,
        NATIVE_STREAM_OVERLOAD.port_pair(3).second,
    )


def test_peer_disconnect_reconnect_preserves_next_frame(native_library_path):
    port = NATIVE_STREAM_OVERLOAD.port_pair(4).first
    process = _start_probe(native_library_path, "send-reconnect", port)
    _, prefix = _wait_for_event(process, "ready")

    context = zmq.Context()
    first_pull = _pull_socket(context, port + 1)
    try:
        first = decode_stream_frames(first_pull.recv_multipart())
        first_pull.close()

        second_pull = _pull_socket(context, port + 1)
        time.sleep(0.2)
        process.stdin.write("reconnect\n")
        process.stdin.flush()
        second = decode_stream_frames(second_pull.recv_multipart())
        stdout, stderr = process.communicate(timeout=5)
    finally:
        if process.poll() is None:
            _terminate(process)
        if not first_pull.closed:
            first_pull.close()
        if "second_pull" in locals():
            second_pull.close()
        context.term()

    assert first["data_hex"] == "5a"
    assert second["data_hex"] == "a5"
    events = _decode_events(prefix + stdout)
    assert [event["event"] for event in events] == [
        "ready",
        "sent",
        "resent",
        "destroyed",
    ]
    assert stderr == ""


def test_reset_and_destroy_with_unread_frame_are_bounded(native_library_path):
    port = NATIVE_STREAM_OVERLOAD.port_pair(5).first
    process = _start_probe(native_library_path, "send-reset", port)
    _, prefix = _wait_for_event(process, "ready")

    context = zmq.Context()
    pull = _pull_socket(context, port + 1)
    try:
        stdout, stderr = process.communicate(timeout=5)
    finally:
        if process.poll() is None:
            _terminate(process)
        pull.close()
        context.term()

    events = _decode_events(prefix + stdout)
    assert [event["event"] for event in events] == [
        "ready",
        "sent",
        "reset",
        "destroyed",
    ]
    assert stderr == ""


def _receive_cycle_after_delay(native_library_path, port, delay):
    process = _start_probe(
        native_library_path,
        "receive",
        port,
        cycle_sleep=0.001,
    )
    _, prefix = _wait_for_event(process, "ready")

    context = zmq.Context()
    push = context.socket(zmq.PUSH)
    push.setsockopt(zmq.LINGER, 0)
    push.connect(f"tcp://127.0.0.1:{port}")
    try:
        time.sleep(0.1 + delay)
        push.send_multipart(encode_stream_frame(0, 0, 0, b"\x3c"))
        stdout, stderr = process.communicate(timeout=5)
    finally:
        if process.poll() is None:
            _terminate(process)
        push.close()
        context.term()

    events = _decode_events(prefix + stdout)
    received = next(event for event in events if event["event"] == "received")
    assert stderr == ""
    return received["cycles"]


def test_peer_wall_clock_delay_changes_current_receive_cycle(native_library_path):
    fast_cycles = _receive_cycle_after_delay(
        native_library_path, NATIVE_STREAM_OVERLOAD.port_pair(6).first, 0.02
    )
    slow_cycles = _receive_cycle_after_delay(
        native_library_path, NATIVE_STREAM_OVERLOAD.port_pair(7).first, 0.12
    )

    # The model keeps advancing its receive cycle while it waits on the peer,
    # so a longer wall-clock delay must land on a strictly later cycle. Assert
    # that monotonic property rather than an absolute cycle-count margin: on a
    # loaded runner each busy-poll iteration takes longer than its nominal 1 ms,
    # which compresses the count difference below any fixed threshold.
    assert fast_cycles > 0
    assert slow_cycles > fast_cycles
