#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

"""Persistent Memory wire peer used by simulator relaunch regressions."""

import argparse
import json
import os
from pathlib import Path
import time

import zmq
from zmq.utils.monitor import recv_monitor_message

try:
    from tests.simlink.common.simlink_protocol import (
        decode_mem_response,
        encode_mem_request,
        T_WRITE,
    )
    from tests.simlink.common.zmq_sockets import make_socket
except ModuleNotFoundError as exc:
    # Fall back to the sibling modules whenever anything under the `tests`
    # package is unreachable, not only the top-level name. A site-packages
    # directory that ships its own top-level `tests` package (envyaml does)
    # shadows this repo's, so the failure surfaces as `tests.simlink` rather
    # than `tests` and the narrower check re-raised instead of falling back.
    if (exc.name or "").split(".")[0] != "tests":
        raise
    from simlink_protocol import decode_mem_response, encode_mem_request, T_WRITE
    from zmq_sockets import make_socket


# Wall-clock budget for every peer wait, including the receive timeout. This
# peer outlives the simulator by design, so each wait spans a full analyze,
# elaborate, and run cycle of the process that is about to bind the endpoint.
# GHDL gets there in seconds; a VCS elaboration of the same leaf takes minutes,
# so the VCS relaunch test raises this rather than letting the peer die before
# `simv` binds.
WAIT_SECONDS = float(os.environ.get("SIMLINK_PEER_WAIT_SECONDS", "60"))


def _wait_for_event(monitor, expected, description):
    deadline = time.monotonic() + WAIT_SECONDS
    while time.monotonic() < deadline:
        if monitor.poll(timeout=100):
            event = recv_monitor_message(monitor)["event"]
            if event & expected:
                return
    raise TimeoutError(f"peer did not observe {description}")


def _wait_for_file(path, description):
    deadline = time.monotonic() + WAIT_SECONDS
    while time.monotonic() < deadline:
        if path.exists():
            return
        time.sleep(0.01)
    raise TimeoutError(f"peer did not observe {description}")


def _write_result(path, result):
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(json.dumps(result, indent=2) + "\n")
    temporary.replace(path)


def _send_write(push, pull, txn_id, address, value, result_path):
    payload = value.to_bytes(4, byteorder="little")
    push.send_multipart(encode_mem_request(txn_id, address, 4, T_WRITE, payload))
    response = decode_mem_response(pull.recv_multipart())
    if response["id"] != txn_id or response["result"] != 0:
        raise RuntimeError(f"unexpected Memory response: {response!r}")
    _write_result(
        result_path,
        {"id": txn_id, "address": address, "value": value, "response": response},
    )


def run(port, ready_path, continue_path, result_paths, values):
    context = zmq.Context()
    push = make_socket(context, zmq.PUSH)
    monitor = push.get_monitor_socket(zmq.EVENT_CONNECTED | zmq.EVENT_DISCONNECTED)
    pull = make_socket(context, zmq.PULL, rcvtimeo_ms=int(WAIT_SECONDS * 1000))
    push.connect(f"tcp://127.0.0.1:{port}")
    pull.connect(f"tcp://127.0.0.1:{port + 1}")
    ready_path.write_text("ready\n")

    try:
        _wait_for_event(monitor, zmq.EVENT_CONNECTED, "the first simulator connection")
        _send_write(push, pull, 1, 0x100, values[0], result_paths[0])

        _wait_for_file(continue_path, "permission to queue the second transaction")
        _wait_for_event(monitor, zmq.EVENT_DISCONNECTED, "the first simulator teardown")

        # Deliberately queue this while no simulator owns the endpoint. The
        # unchanged peer socket should deliver it when the next run rebinds.
        _send_write(push, pull, 2, 0x104, values[1], result_paths[1])
    finally:
        push.disable_monitor()
        monitor.close(0)
        push.close(0)
        pull.close(0)
        context.term()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("port", type=int)
    parser.add_argument("ready", type=Path)
    parser.add_argument("continue_path", type=Path)
    parser.add_argument("result_one", type=Path)
    parser.add_argument("result_two", type=Path)
    parser.add_argument("value_one", type=lambda value: int(value, 0))
    parser.add_argument("value_two", type=lambda value: int(value, 0))
    args = parser.parse_args()
    run(
        args.port,
        args.ready,
        args.continue_path,
        (args.result_one, args.result_two),
        (args.value_one, args.value_two),
    )


if __name__ == "__main__":
    main()
