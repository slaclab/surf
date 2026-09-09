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

import pyrogue.interfaces.simulation as pis


def write_result(path, result):
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(json.dumps(result, indent=2) + "\n")
    temporary.replace(path)


def run(port, send_opcode, send_remdata, ready_path):
    received = []
    event = threading.Event()

    def on_sideband(op_code, remote_data):
        # Rogue passes None for the field a given event does not carry (the
        # DUT sends the opcode strobe and the remData change as separate
        # events), so record None rather than coercing to an integer.
        received.append({
            "opCode": int(op_code) if op_code is not None else None,
            "remData": int(remote_data) if remote_data is not None else None,
        })
        event.set()

    with pis.SideBandSim("127.0.0.1", port) as sideband:
        sideband.setRecvCb(on_sideband)
        ready_path.write_text("ready\n")

        # HDL -> client first (the DUT drives its tx opcode/remData), proving the
        # pipe before we send client -> HDL. The ready file is written (above)
        # BEFORE the parent starts GHDL, so this deadline must cover GHDL
        # analyze + elaborate + sim boot + reset -- generous for a cold/loaded
        # CI runner, still bounded so a stuck peer fails rather than hangs.
        if not event.wait(60.0):
            raise TimeoutError("no HDL-to-Rogue sideband event within 60 s")

        sideband.send(opCode=send_opcode)
        sideband.send(remData=send_remdata)

    return {
        "ok": True,
        "received": received,
        "sent_opcode": send_opcode,
        "sent_remdata": send_remdata,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("port", type=int)
    parser.add_argument("opcode", type=lambda v: int(v, 0))
    parser.add_argument("remdata", type=lambda v: int(v, 0))
    parser.add_argument("result", type=Path)
    parser.add_argument("ready", type=Path)
    args = parser.parse_args()
    try:
        result = run(args.port, args.opcode, args.remdata, args.ready)
    except Exception as exc:  # noqa: BLE001
        result = {"ok": False, "error": str(exc), "traceback": traceback.format_exc()}
        write_result(args.result, result)
        raise
    write_result(args.result, result)


if __name__ == "__main__":
    main()
