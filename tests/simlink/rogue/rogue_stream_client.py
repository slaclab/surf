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

import argparse
import json
from pathlib import Path
import threading
import traceback

import rogue.interfaces.stream as ris


class Capture(ris.Slave):
    def __init__(self):
        super().__init__()
        self.frames = []
        self.received = threading.Event()

    def _acceptFrame(self, frame):
        self.frames.append(bytes(frame.getBa()))
        self.received.set()


def write_result(path, result):
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(json.dumps(result, indent=2) + "\n")
    temporary.replace(path)


def run(port, payload, ready_path):
    source = ris.Master()
    sink = Capture()
    tcp = ris.TcpClient("127.0.0.1", port)
    source >> tcp
    tcp >> sink

    # Client constructed and its asynchronous ZMQ connects issued; tell the
    # parent it may start GHDL. HDL-first: the DUT drives the first frame, which
    # proves the pipe is connected before we send our client->HDL frame (the
    # model's inbound PUSH sets ZMQ_IMMEDIATE so it will not drop it).
    ready_path.write_text("ready\n")

    try:
        # The parent writes the ready file (above) BEFORE it starts GHDL, so
        # this deadline must cover GHDL analyze + elaborate + sim boot + reset
        # before the DUT drives its first frame -- generous for a cold or loaded
        # CI runner, still bounded so a genuinely stuck peer fails rather than
        # hangs.
        if not sink.received.wait(60.0):
            raise TimeoutError("no HDL-to-Rogue frame received within 60 s")
        hdl_to_client = sink.frames[0]

        frame = source._reqFrame(len(payload), True)
        frame.write(payload, 0)
        frame.setFirstUser(0x00)
        frame.setLastUser(0x00)
        source._sendFrame(frame)
    finally:
        tcp.close()

    return {
        "ok": True,
        "hdl_to_client_hex": hdl_to_client.hex(),
        "client_to_hdl_hex": payload.hex(),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("port", type=int)
    parser.add_argument("payload_hex")
    parser.add_argument("result", type=Path)
    parser.add_argument("ready", type=Path)
    args = parser.parse_args()

    payload = bytes.fromhex(args.payload_hex)
    try:
        result = run(args.port, payload, args.ready)
    except Exception as exc:  # noqa: BLE001 - preserve child-process failure
        result = {"ok": False, "error": str(exc),
                  "traceback": traceback.format_exc()}
        write_result(args.result, result)
        raise
    write_result(args.result, result)


if __name__ == "__main__":
    main()
