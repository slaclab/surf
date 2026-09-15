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
import traceback

import pyrogue as pr
import rogue
import rogue.interfaces.memory


class SimLinkMemoryDevice(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name      = "Scratch",
            offset    = 0x0000,
            bitSize   = 32,
            bitOffset = 0,
            mode      = "RW",
            verify    = True,
        ))


class SimLinkMemoryRoot(pr.Root):
    def __init__(self, *, port):
        super().__init__(
            name        = "SimLinkMemoryRoot",
            description = "Real-Rogue SimLink memory contract test",
            timeout     = 2.0,
            pollEn      = False,
        )

        self.memClient = rogue.interfaces.memory.TcpClient(
            "127.0.0.1", port, True)
        self.addInterface(self.memClient)

        self.add(SimLinkMemoryDevice(
            name    = "Device",
            memBase = self.memClient,
        ))


def write_result(path, result):
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(json.dumps(result, indent=2) + "\n")
    temporary.replace(path)


def run(port, value, ready_path):
    root = SimLinkMemoryRoot(port=port)

    # Construction has imported Rogue, created the production TcpClient,
    # started its response thread, and issued both asynchronous ZMQ connect
    # calls. Tell the pytest parent it can now launch GHDL; Root.__enter__ will
    # wait on the production TcpBridgeProbe until SimLink binds its sockets.
    ready_path.write_text("ready\n")

    with root:
        assert root.memClient.waitReady(2.0, 0.05)

        # Make the operation sequence explicit: cache a value locally, issue
        # a production Rogue Write followed by Verify, then issue a separate
        # Read through the same PyRogue RemoteVariable.
        root.Device.Scratch.set(value, write=False)
        root.Device.writeAndVerifyBlocks(force=True)
        readback = root.Device.Scratch.get()

        assert readback == value

        # Rogue completes Post locally and does not retain its transaction ID.
        # SimLink historically still returns the AXI completion, which Rogue
        # discards; the following ordered Read proves the posted write reached
        # the RTL and that the unsolicited completion did not disrupt the next
        # tracked transaction.
        post_value = value ^ 0xFFFFFFFF
        root.Device.Scratch.post(post_value)
        post_readback = root.Device.Scratch.get()

        assert post_readback == post_value

    return {
        "ok": True,
        "rogue_version": rogue.Version.current(),
        "value": value,
        "readback": readback,
        "post_value": post_value,
        "post_readback": post_readback,
        "operations": ["waitReady", "Write", "Verify", "Read", "Post", "Read"],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("port", type=int)
    parser.add_argument("value", type=lambda value: int(value, 0))
    parser.add_argument("result", type=Path)
    parser.add_argument("ready", type=Path)
    args = parser.parse_args()

    try:
        result = run(args.port, args.value, args.ready)
    except Exception as exc:  # noqa: BLE001 - preserve child-process failure
        result = {
            "ok": False,
            "error": str(exc),
            "traceback": traceback.format_exc(),
        }
        write_result(args.result, result)
        raise

    write_result(args.result, result)


if __name__ == "__main__":
    main()
