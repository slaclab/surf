##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import argparse
import ctypes
import json
import os
from pathlib import Path
import sys
import time

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT))

from tests.simlink.native.native_adapter_utils import (  # noqa: E402
    configure_library,
    step_stream,
    stream_cycle,
)

START_TIME = time.monotonic()
EVENT_STREAM = os.fdopen(os.dup(sys.stdout.fileno()), "w", buffering=1)
NULL_FD = os.open(os.devnull, os.O_WRONLY)
os.dup2(NULL_FD, sys.stdout.fileno())
os.close(NULL_FD)


def _emit(event, operation, completed_messages, **fields):
    fields.update(
        {
            "event": event,
            "operation": operation,
            "completed_messages": completed_messages,
            "elapsed_seconds": time.monotonic() - START_TIME,
        }
    )
    print(
        json.dumps(fields, sort_keys=True),
        file=EVENT_STREAM,
        flush=True,
    )


def _create(lib, port):
    context = lib.rogueTcpStreamCreate()
    if not context:
        raise RuntimeError("failed to create Stream model")
    if step_stream(lib, context, port) != 1:
        raise RuntimeError("failed to bind Stream model")
    return context


def _send_probe(lib, port, hold):
    context = _create(lib, port)
    _emit("ready", "socket_bind", 0)
    try:
        if stream_cycle(lib, context, port, payload=b"\x5a")[0] != 1:
            raise RuntimeError("Stream update failed")
        _emit("sent", "synchronous_send", 1)
        if hold:
            if sys.stdin.readline() == "":
                raise RuntimeError("control pipe closed before release")
    finally:
        lib.rogueTcpStreamDestroy(context)
    _emit("destroyed", "socket_cleanup", 1)


def _send_many(lib, port, count, frame_size):
    context = _create(lib, port)
    _emit("ready", "socket_bind", 0)
    try:
        for index in range(count):
            if lib.simLinkNativeStreamSend(context, frame_size) != 1:
                raise RuntimeError("native Stream send failed")
            _emit("progress", "synchronous_send", index + 1)
    finally:
        lib.rogueTcpStreamDestroy(context)
    _emit("destroyed", "socket_cleanup", count)


def _send_reconnect(lib, port):
    context = _create(lib, port)
    _emit("ready", "socket_bind", 0)
    try:
        if stream_cycle(lib, context, port, payload=b"\x5a")[0] != 1:
            raise RuntimeError("first Stream update failed")
        _emit("sent", "synchronous_send", 1)
        if sys.stdin.readline() == "":
            raise RuntimeError("control pipe closed before reconnect send")
        if stream_cycle(lib, context, port, payload=b"\xa5")[0] != 1:
            raise RuntimeError("second Stream update failed")
        _emit("resent", "synchronous_send", 2)
    finally:
        lib.rogueTcpStreamDestroy(context)
    _emit("destroyed", "socket_cleanup", 2)


def _send_reset(lib, port):
    context = _create(lib, port)
    _emit("ready", "socket_bind", 0)
    try:
        if stream_cycle(lib, context, port, payload=b"\x5a")[0] != 1:
            raise RuntimeError("Stream update failed")
        _emit("sent", "synchronous_send", 1)
        if step_stream(lib, context, port, reset=1) != 1:
            raise RuntimeError("Stream reset update failed")
        _emit("reset", "model_reset", 1)
    finally:
        lib.rogueTcpStreamDestroy(context)
    _emit("destroyed", "socket_cleanup", 1)


def _receive_probe(lib, port, cycle_sleep):
    context = _create(lib, port)
    _emit("ready", "socket_bind", 0)
    cycles = 0
    try:
        while True:
            result, valid, _ = stream_cycle(lib, context, port, ob_ready=1)
            if result != 1:
                raise RuntimeError("Stream update failed")
            cycles += 1
            if valid:
                _emit("received", "nonblocking_receive", 1, cycles=cycles)
                break
            time.sleep(cycle_sleep)
    finally:
        lib.rogueTcpStreamDestroy(context)
    _emit("destroyed", "socket_cleanup", 1, cycles=cycles)


def main():
    os.environ.setdefault("SURF_SIMLINK_TRANSPORT_TIMEOUT_MS", "400")

    parser = argparse.ArgumentParser()
    parser.add_argument("library")
    parser.add_argument(
        "mode",
        choices=(
            "receive",
            "send",
            "send-hold",
            "send-many",
            "send-reconnect",
            "send-reset",
        ),
    )
    parser.add_argument("port", type=int)
    parser.add_argument("--count", type=int, default=1)
    parser.add_argument("--cycle-sleep", type=float, default=0.001)
    parser.add_argument("--frame-size", type=int, default=65536)
    args = parser.parse_args()

    lib = ctypes.CDLL(args.library)
    configure_library(lib)
    if args.mode in ("send", "send-hold"):
        _send_probe(lib, args.port, args.mode == "send-hold")
    elif args.mode == "send-many":
        _send_many(lib, args.port, args.count, args.frame_size)
    elif args.mode == "send-reconnect":
        _send_reconnect(lib, args.port)
    elif args.mode == "send-reset":
        _send_reset(lib, args.port)
    else:
        _receive_probe(lib, args.port, args.cycle_sleep)


if __name__ == "__main__":
    main()
