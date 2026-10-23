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
# - Sweep: Four Stream and two each Memory and SideBand contexts, plus Memory
#   Read, Write, Verify, Post, readiness-probe, SLVERR, and DECERR behavior,
#   SideBand event-flag isolation, and null, fabricated, stale, wrong-model,
#   changed-port, and overlapping-port negative cases. One persistent peer is
#   also retained across Memory model destruction/recreation.
# - Stimulus: Build the xsim C adapters with host gcc and a minimal test-only
#   svdpi.h, create independent contexts, bind each endpoint pair, and exchange
#   tagged Stream, Memory, and SideBand traffic through real ZeroMQ peers.
# - Checks: Context pointers and traffic remain distinct; destroy permits
#   same-port reuse; a request queued while no model exists reaches its
#   replacement; invalid ownership/port operations return failure without
#   corrupting another context.
# - Timing: Peer receives and transport polling are bounded at five seconds;
#   no HDL simulator is required for this native adapter/lifecycle layer.

import ctypes
import time

import pytest
import zmq
from zmq.utils.monitor import recv_monitor_message

from tests.simlink.common.simlink_protocol import (
    decode_mem_response,
    decode_sideband_frame,
    decode_stream_frames,
    encode_mem_request,
    encode_sideband_frame,
    encode_stream_frame,
    T_POST,
    T_PROBE,
    T_READ,
    T_VERIFY,
    T_WRITE,
)
from tests.simlink.common.zmq_sockets import make_socket
from tests.simlink.native.native_adapter_utils import (
    Bit,
    BitVector,
    build_native_library,
    configure_library,
    NATIVE_LIBRARY,
    step_stream,
    stream_cycle,
)
from tests.simlink.ports import (
    NATIVE_DPI_ACTIVE,
    NATIVE_DPI_CONTEXTS,
    NATIVE_DPI_MEMORY_ERRORS,
    NATIVE_DPI_MEMORY_MULTIWORD,
    NATIVE_DPI_MEMORY_PROBE,
    NATIVE_DPI_RELOAD,
    NATIVE_DPI_SIDEBAND_FLAGS,
    NATIVE_DPI_VALIDATION,
    NATIVE_DPI_WIDE,
)


@pytest.fixture(scope="module")
def native_library():
    build_native_library()
    lib = ctypes.CDLL(str(NATIVE_LIBRARY))
    configure_library(lib)
    return lib


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


def _memory_cycle(
    lib,
    context,
    port,
    *,
    arready=0,
    rdata=0,
    rresp=0,
    rvalid=0,
    awready=0,
    wready=0,
    bresp=0,
    bvalid=0,
):
    port_num = BitVector(port)
    araddr = BitVector(0)
    arprot = BitVector(0)
    arvalid = Bit(0)
    rready = Bit(0)
    rdata_in = BitVector(rdata)
    rresp_in = BitVector(rresp)
    awaddr = BitVector(0)
    awprot = BitVector(0)
    awvalid = Bit(0)
    wdata = BitVector(0)
    wstrb = BitVector(0)
    wvalid = Bit(0)
    bready = Bit(0)
    bresp_in = BitVector(bresp)
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
        ctypes.byref(rresp_in),
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
        ctypes.byref(bresp_in),
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
    return make_socket(
        context, socket_type, endpoint=endpoint, rcvtimeo_ms=5000
    )


def _wait_for_socket_event(monitor, expected_event, description):
    deadline = time.monotonic() + 5.0
    while time.monotonic() < deadline:
        if monitor.poll(timeout=100):
            event = recv_monitor_message(monitor)["event"]
            if event & expected_event:
                return
    pytest.fail(f"peer socket did not report {description}")


def _wait_for_memory_outputs(lib, context, port, predicate, description):
    deadline = time.monotonic() + 5.0
    while time.monotonic() < deadline:
        outputs = _memory_cycle(lib, context, port)
        assert outputs["result"] == 1
        if predicate(outputs):
            return outputs
        time.sleep(0.001)
    pytest.fail(f"memory model did not issue {description}")


def _complete_memory_write(lib, context, port, response):
    outputs = _wait_for_memory_outputs(
        lib,
        context,
        port,
        lambda value: value["awvalid"] and value["wvalid"],
        "write address and data",
    )
    assert _memory_cycle(
        lib,
        context,
        port,
        awready=1,
        wready=1,
        bresp=response,
        bvalid=1,
    )["result"] == 1
    return outputs


def _complete_memory_read(lib, context, port, data, response):
    outputs = _wait_for_memory_outputs(
        lib,
        context,
        port,
        lambda value: value["arvalid"],
        "read address",
    )
    assert _memory_cycle(lib, context, port, arready=1)["result"] == 1
    assert _memory_cycle(
        lib,
        context,
        port,
        rdata=data,
        rresp=response,
        rvalid=1,
    )["result"] == 1
    return outputs


def test_dpi_instances_bind_independently_and_reuse_ports(native_library):
    lib = native_library
    specs = (
        [(lib.rogueTcpStreamCreate, lib.rogueTcpStreamDestroy, step_stream)] * 4
        + [(lib.rogueTcpMemoryCreate, lib.rogueTcpMemoryDestroy, _step_memory)] * 2
        + [(lib.rogueSideBandCreate, lib.rogueSideBandDestroy, _step_sideband)] * 2
    )
    ports = tuple(
        NATIVE_DPI_CONTEXTS.port_pair(index).first
        for index in range(len(specs))
    )
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


def test_persistent_peer_reconnects_after_model_recreation(native_library):
    """Exercise the transport contract beneath simulator module relaunch.

    The peer sockets remain alive while the first model is destroyed and a
    fresh model binds the same ports. A request queued while no model exists
    must reach the replacement, matching the historical Rogue-through-VCS
    debugging workflow.
    """
    lib = native_library
    port = NATIVE_DPI_RELOAD.port_pair(0).first
    zmq_context = zmq.Context()
    push = make_socket(zmq_context, zmq.PUSH)
    monitor = push.get_monitor_socket(zmq.EVENT_CONNECTED | zmq.EVENT_DISCONNECTED)
    pull = _peer_socket(zmq_context, zmq.PULL, f"tcp://127.0.0.1:{port + 1}")
    push.connect(f"tcp://127.0.0.1:{port}")
    model = None

    try:
        model = lib.rogueTcpMemoryCreate()
        assert model
        assert _step_memory(lib, model, port) == 1
        _wait_for_socket_event(monitor, zmq.EVENT_CONNECTED, "initial connection")

        first_payload = b"\x11\x22\x33\x44"
        push.send_multipart(encode_mem_request(1, 0x100, 4, T_WRITE, first_payload))
        first_outputs = _complete_memory_write(lib, model, port, 0)
        assert first_outputs["awaddr"] == 0x100
        assert first_outputs["wdata"] == int.from_bytes(first_payload, byteorder="little")
        assert decode_mem_response(pull.recv_multipart())["result"] == 0

        # Teardown represents the old simulator module/runtime disappearing.
        # Keep the software-side sockets intact and wait until ZeroMQ has
        # observed the loss before queueing work for the next run.
        lib.rogueTcpMemoryDestroy(model)
        model = None
        _wait_for_socket_event(monitor, zmq.EVENT_DISCONNECTED, "disconnect")

        second_payload = b"\x55\x66\x77\x88"
        push.send_multipart(encode_mem_request(2, 0x104, 4, T_WRITE, second_payload))

        model = lib.rogueTcpMemoryCreate()
        assert model
        assert _step_memory(lib, model, port) == 1
        _wait_for_socket_event(monitor, zmq.EVENT_CONNECTED, "reconnection")

        second_outputs = _complete_memory_write(lib, model, port, 0)
        assert second_outputs["awaddr"] == 0x104
        assert second_outputs["wdata"] == int.from_bytes(second_payload, byteorder="little")
        second_response = decode_mem_response(pull.recv_multipart())
        assert second_response["id"] == 2
        assert second_response["result"] == 0

        # Once a model has removed a request from the transport queue, teardown
        # does not replay it into the replacement. Interrupt transaction 3
        # after it reaches AXI but before returning BVALID, then verify that no
        # completion appears and a later transaction still succeeds.
        third_payload = b"\x99\xaa\xbb\xcc"
        push.send_multipart(encode_mem_request(3, 0x108, 4, T_WRITE, third_payload))
        third_outputs = _wait_for_memory_outputs(
            lib,
            model,
            port,
            lambda outputs: outputs["awvalid"] and outputs["wvalid"],
            "write interrupted by model teardown",
        )
        assert third_outputs["awaddr"] == 0x108
        assert third_outputs["wdata"] == int.from_bytes(third_payload, byteorder="little")

        lib.rogueTcpMemoryDestroy(model)
        model = None
        _wait_for_socket_event(monitor, zmq.EVENT_DISCONNECTED, "second disconnect")
        model = lib.rogueTcpMemoryCreate()
        assert model
        assert _step_memory(lib, model, port) == 1
        _wait_for_socket_event(monitor, zmq.EVENT_CONNECTED, "second reconnection")
        for _ in range(100):
            assert _step_memory(lib, model, port) == 1
        assert pull.poll(timeout=200) == 0

        fourth_payload = b"\xdd\xee\xf0\x12"
        push.send_multipart(encode_mem_request(4, 0x10C, 4, T_WRITE, fourth_payload))
        fourth_outputs = _complete_memory_write(lib, model, port, 0)
        assert fourth_outputs["awaddr"] == 0x10C
        assert fourth_outputs["wdata"] == int.from_bytes(fourth_payload, byteorder="little")
        fourth_response = decode_mem_response(pull.recv_multipart())
        assert fourth_response["id"] == 4
        assert fourth_response["result"] == 0
    finally:
        if model is not None:
            lib.rogueTcpMemoryDestroy(model)
        push.disable_monitor()
        monitor.close(0)
        push.close(0)
        pull.close(0)
        zmq_context.term()


@pytest.mark.parametrize(
    ("data_bytes", "port"),
    (
        (64, NATIVE_DPI_WIDE.port_pair(0).first),
        (128, NATIVE_DPI_WIDE.port_pair(1).first),
    ),
)
def test_dpi_stream_wide_beat_round_trip(native_library, data_bytes, port):
    lib = native_library
    peer_to_model = bytes(range(data_bytes))
    model_to_peer = bytes(reversed(range(data_bytes)))
    zmq_context = zmq.Context()
    context = lib.rogueTcpStreamCreate()
    push = _peer_socket(zmq_context, zmq.PUSH, f"tcp://127.0.0.1:{port}")
    pull = _peer_socket(zmq_context, zmq.PULL, f"tcp://127.0.0.1:{port + 1}")

    try:
        assert context
        assert stream_cycle(
            lib, context, port, data_bytes=data_bytes
        )[0] == 1
        push.send_multipart(encode_stream_frame(0, 0, 0, peer_to_model))

        received = None
        deadline = time.monotonic() + 5.0
        cycle = 0
        while time.monotonic() < deadline:
            result, valid, payload = stream_cycle(
                lib,
                context,
                port,
                payload=model_to_peer if cycle == 0 else b"",
                data_bytes=data_bytes,
            )
            assert result == 1
            cycle += 1
            if valid:
                received = payload
                break
            time.sleep(0.001)

        assert received == peer_to_model
        assert decode_stream_frames(pull.recv_multipart())["data_hex"] == model_to_peer.hex()
    finally:
        lib.rogueTcpStreamDestroy(context)
        push.close(0)
        pull.close(0)
        zmq_context.term()


def test_dpi_instances_exchange_isolated_active_traffic(native_library):
    lib = native_library
    zmq_context = zmq.Context()
    contexts = []
    sockets = []

    try:
        stream_models = []
        for tag in range(4):
            port = NATIVE_DPI_ACTIVE.port_pair(tag).first
            context = lib.rogueTcpStreamCreate()
            assert context
            contexts.append((context, lib.rogueTcpStreamDestroy))
            push = _peer_socket(zmq_context, zmq.PUSH, f"tcp://127.0.0.1:{port}")
            pull = _peer_socket(zmq_context, zmq.PULL, f"tcp://127.0.0.1:{port + 1}")
            sockets.extend((push, pull))
            assert step_stream(lib, context, port) == 1
            stream_models.append((tag, port, context, push, pull))

        for tag, _, _, push, _ in stream_models:
            push.send_multipart(encode_stream_frame(0, 0, 0, bytes([0x10 + tag] * 4)))

        for tag, port, context, _, pull in stream_models:
            outbound = bytes([0x80 + tag] * 4)
            received = None
            cycle = 0
            deadline = time.monotonic() + 5.0
            while time.monotonic() < deadline:
                result, valid, payload = stream_cycle(
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
            port = NATIVE_DPI_ACTIVE.port_pair(4 + tag).first
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
            assert read_response["result"] == 0

        sideband_models = []
        for tag in range(2):
            port = NATIVE_DPI_ACTIVE.port_pair(6 + tag).first
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


def test_sideband_sent_flags_do_not_leak_into_later_events(native_library):
    lib = native_library
    port = NATIVE_DPI_SIDEBAND_FLAGS.port_pair(0).first
    context = lib.rogueSideBandCreate()
    assert context
    zmq_context = zmq.Context()
    pull = _peer_socket(zmq_context, zmq.PULL, f"tcp://127.0.0.1:{port}")

    try:
        assert _step_sideband(lib, context, port) == 1

        assert _sideband_cycle(
            lib, context, port, tx_opcode=0xA5, tx_enable=1
        )[0] == 1
        opcode_event = decode_sideband_frame(pull.recv())
        assert opcode_event["opCodeEn"] == 1
        assert opcode_event["opCode"] == 0xA5
        assert opcode_event["remDataChanged"] == 0

        assert _sideband_cycle(
            lib, context, port, tx_remdata=0x3C
        )[0] == 1
        remdata_event = decode_sideband_frame(pull.recv())
        assert remdata_event["opCodeEn"] == 0
        assert remdata_event["remDataChanged"] == 1
        assert remdata_event["remData"] == 0x3C

        assert _sideband_cycle(
            lib, context, port, tx_opcode=0x5A, tx_enable=1, tx_remdata=0x3C
        )[0] == 1
        later_opcode_event = decode_sideband_frame(pull.recv())
        assert later_opcode_event["opCodeEn"] == 1
        assert later_opcode_event["opCode"] == 0x5A
        assert later_opcode_event["remDataChanged"] == 0
    finally:
        pull.close()
        zmq_context.term()
        lib.rogueSideBandDestroy(context)


def test_memory_bridge_probe_and_ascii_status(native_library):
    lib = native_library
    port = NATIVE_DPI_MEMORY_PROBE.port_pair(0).first
    context = lib.rogueTcpMemoryCreate()
    assert context
    zmq_context = zmq.Context()
    push = _peer_socket(zmq_context, zmq.PUSH, f"tcp://127.0.0.1:{port}")
    pull = _peer_socket(zmq_context, zmq.PULL, f"tcp://127.0.0.1:{port + 1}")

    try:
        assert _step_memory(lib, context, port) == 1

        # This is the exact control request emitted by Rogue TcpClient's
        # waitReady(). It must complete locally without issuing AXI traffic.
        push.send_multipart(encode_mem_request(0xA5, 0, 0, T_PROBE))
        deadline = time.monotonic() + 5.0
        while time.monotonic() < deadline:
            outputs = _memory_cycle(lib, context, port)
            assert outputs["result"] == 1
            assert not outputs["arvalid"]
            assert not outputs["awvalid"]
            assert not outputs["wvalid"]
            if pull.poll(timeout=0):
                break
            time.sleep(0.001)
        else:
            pytest.fail("memory readiness probe did not receive a response")

        probe_response = decode_mem_response(pull.recv_multipart())
        assert probe_response == {
            "id": 0xA5,
            "addr": 0,
            "size": 0,
            "type": T_PROBE,
            "data_hex": "",
            "result": "OK",
        }

        # Ordinary transactions retain the historical numeric response frame
        # for compatibility with existing Rogue/SURF deployments.
        payload = bytes.fromhex("12345678")
        push.send_multipart(encode_mem_request(0xA6, 0x200, 4, T_WRITE, payload))
        deadline = time.monotonic() + 5.0
        while time.monotonic() < deadline:
            outputs = _memory_cycle(lib, context, port)
            assert outputs["result"] == 1
            if outputs["awvalid"] and outputs["wvalid"]:
                break
            time.sleep(0.001)
        else:
            pytest.fail("memory transaction did not issue its write")

        assert _memory_cycle(
            lib,
            context,
            port,
            awready=1,
            wready=1,
            bresp=2,
            bvalid=1,
        )["result"] == 1
        error_response = decode_mem_response(pull.recv_multipart())
        assert error_response["result"] == 2
    finally:
        push.close()
        pull.close()
        zmq_context.term()
        lib.rogueTcpMemoryDestroy(context)


@pytest.mark.parametrize(
    "txn_type,axi_response,port",
    [
        (T_WRITE, 2, NATIVE_DPI_MEMORY_ERRORS.port_pair(0).first),
        (T_WRITE, 3, NATIVE_DPI_MEMORY_ERRORS.port_pair(1).first),
        (T_READ, 2, NATIVE_DPI_MEMORY_ERRORS.port_pair(2).first),
        (T_READ, 3, NATIVE_DPI_MEMORY_ERRORS.port_pair(3).first),
        (T_VERIFY, 2, NATIVE_DPI_MEMORY_ERRORS.port_pair(4).first),
        (T_VERIFY, 3, NATIVE_DPI_MEMORY_ERRORS.port_pair(5).first),
        (T_POST, 2, NATIVE_DPI_MEMORY_ERRORS.port_pair(6).first),
        (T_POST, 3, NATIVE_DPI_MEMORY_ERRORS.port_pair(7).first),
    ],
)
def test_memory_operation_error_matrix(
    native_library, txn_type, axi_response, port
):
    lib = native_library
    context = lib.rogueTcpMemoryCreate()
    assert context
    zmq_context = zmq.Context()
    push = _peer_socket(zmq_context, zmq.PUSH, f"tcp://127.0.0.1:{port}")
    pull = _peer_socket(zmq_context, zmq.PULL, f"tcp://127.0.0.1:{port + 1}")
    address = 0x300
    payload = bytes.fromhex("12345678")

    try:
        assert _step_memory(lib, context, port) == 1
        push.send_multipart(
            encode_mem_request(
                0xB0 + txn_type,
                address,
                len(payload),
                txn_type,
                payload if txn_type in (T_WRITE, T_POST) else b"",
            )
        )

        if txn_type in (T_WRITE, T_POST):
            outputs = _complete_memory_write(
                lib, context, port, axi_response
            )
            assert outputs["awaddr"] == address
            assert outputs["wdata"] == int.from_bytes(payload, byteorder="little")
        else:
            outputs = _complete_memory_read(
                lib,
                context,
                port,
                int.from_bytes(payload, byteorder="little"),
                axi_response,
            )
            assert outputs["araddr"] == address

        decoded = decode_mem_response(pull.recv_multipart())
        assert decoded["type"] == txn_type
        assert decoded["result"] == axi_response
        if txn_type in (T_READ, T_VERIFY):
            assert decoded["data_hex"] == payload.hex()
    finally:
        push.close()
        pull.close()
        zmq_context.term()
        lib.rogueTcpMemoryDestroy(context)


@pytest.mark.parametrize(
    "txn_type,first_response,port",
    [
        (T_WRITE, 3, NATIVE_DPI_MEMORY_MULTIWORD.port_pair(0).first),
        (T_READ, 2, NATIVE_DPI_MEMORY_MULTIWORD.port_pair(1).first),
    ],
)
def test_memory_multiword_preserves_first_error(
    native_library, txn_type, first_response, port
):
    lib = native_library
    context = lib.rogueTcpMemoryCreate()
    assert context
    zmq_context = zmq.Context()
    push = _peer_socket(zmq_context, zmq.PUSH, f"tcp://127.0.0.1:{port}")
    pull = _peer_socket(zmq_context, zmq.PULL, f"tcp://127.0.0.1:{port + 1}")
    address = 0x400
    payload = bytes.fromhex("0123456789abcdef")

    try:
        assert _step_memory(lib, context, port) == 1
        push.send_multipart(
            encode_mem_request(
                0xC0 + txn_type,
                address,
                len(payload),
                txn_type,
                payload if txn_type == T_WRITE else b"",
            )
        )

        for index, response in enumerate((first_response, 0)):
            word = payload[index * 4:(index + 1) * 4]
            if txn_type == T_WRITE:
                outputs = _complete_memory_write(lib, context, port, response)
                assert outputs["awaddr"] == address + (index * 4)
                assert outputs["wdata"] == int.from_bytes(word, byteorder="little")
            else:
                outputs = _complete_memory_read(
                    lib,
                    context,
                    port,
                    int.from_bytes(word, byteorder="little"),
                    response,
                )
                assert outputs["araddr"] == address + (index * 4)

        decoded = decode_mem_response(pull.recv_multipart())
        assert decoded["result"] == first_response
        if txn_type == T_READ:
            assert decoded["data_hex"] == payload.hex()
    finally:
        push.close()
        pull.close()
        zmq_context.term()
        lib.rogueTcpMemoryDestroy(context)


def test_dpi_rejects_overlapping_and_changed_ports(native_library):
    lib = native_library
    stream = lib.rogueTcpStreamCreate()
    memory = lib.rogueTcpMemoryCreate()
    sideband = lib.rogueSideBandCreate()
    assert stream and memory and sideband

    try:
        assert step_stream(lib, stream, NATIVE_DPI_VALIDATION.port_pair(0).first) == 1
        assert _step_memory(lib, memory, NATIVE_DPI_VALIDATION.port_pair(0).second) == 0
        assert step_stream(lib, stream, NATIVE_DPI_VALIDATION.port_pair(1).first) == 0
        assert _step_sideband(lib, sideband, 0) == 0
        assert _step_sideband(lib, sideband, 0xFFFF) == 0
    finally:
        lib.rogueSideBandDestroy(sideband)
        lib.rogueTcpMemoryDestroy(memory)
        lib.rogueTcpStreamDestroy(stream)


def test_dpi_rejects_invalid_and_wrong_model_contexts(native_library):
    lib = native_library
    stream = lib.rogueTcpStreamCreate()
    assert stream

    try:
        assert step_stream(lib, None, NATIVE_DPI_VALIDATION.port_pair(2).first) == 0
        assert step_stream(
            lib,
            ctypes.c_void_p(1),
            NATIVE_DPI_VALIDATION.port_pair(2).first,
        ) == 0
        assert _step_memory(lib, stream, NATIVE_DPI_VALIDATION.port_pair(3).first) == 0
    finally:
        lib.rogueTcpStreamDestroy(stream)

    assert step_stream(
        lib,
        ctypes.c_void_p(stream),
        NATIVE_DPI_VALIDATION.port_pair(3).first,
    ) == 0
