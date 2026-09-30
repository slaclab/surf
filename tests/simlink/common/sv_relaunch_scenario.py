##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Backend-neutral persistent-peer relaunch orchestration for
RogueSvMemoryRelaunchTb, shared by the Icarus and Verilator runners."""

import json
import subprocess
import sys
import time

from tests.simlink.common.peer_orchestration import terminate_process
from tests.simlink.paths import SIMLINK_TEST_ROOT

SV_RELAUNCH_TOP = "RogueSvMemoryRelaunchTb"
SV_RELAUNCH_BANNER = "RogueSvMemoryRelaunchTb passed"
PEER = SIMLINK_TEST_ROOT / "common" / "persistent_memory_peer.py"

# The two addresses the peer writes are fixed inside persistent_memory_peer.py
# itself; these constants mirror them so a peer edit fails loudly here first.
RELAUNCH_ADDRESSES = (0x100, 0x104)
RELAUNCH_VALUES = (0x11223344, 0x55667788)


def relaunch_plusargs(result_path, address, value):
    return [
        f"+RELAUNCH_RESULT={result_path}",
        f"+RELAUNCH_ADDR={address:08x}",
        f"+RELAUNCH_VALUE={value:08x}",
    ]


def _wait_for_ready(peer, ready_path):
    deadline = time.monotonic() + 15.0
    while time.monotonic() < deadline:
        if ready_path.exists():
            return
        if peer.poll() is not None:
            stdout, stderr = peer.communicate()
            raise RuntimeError(
                f"persistent peer exited before readiness (rc={peer.returncode})\n"
                f"stdout:\n{stdout}\nstderr:\n{stderr}"
            )
        time.sleep(0.01)
    raise TimeoutError("persistent peer did not signal readiness")


def run_sv_relaunch(run_sim, port, build_dir):
    """Spawn the persistent Memory peer, run two separate simulator
    invocations of RogueSvMemoryRelaunchTb via run_sim(plusargs), and
    validate the banner, addr/value lines, and the peer's two result files.

    run_sim(plusargs) must return a subprocess.CompletedProcess."""
    ready_path = build_dir / "peer.ready"
    continue_path = build_dir / "continue"
    result_paths = (build_dir / "phase-1.json", build_dir / "phase-2.json")
    for path in (ready_path, continue_path, *result_paths):
        path.unlink(missing_ok=True)

    peer = subprocess.Popen(
        [
            sys.executable,
            str(PEER),
            str(port),
            str(ready_path),
            str(continue_path),
            str(result_paths[0]),
            str(result_paths[1]),
            hex(RELAUNCH_VALUES[0]),
            hex(RELAUNCH_VALUES[1]),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    try:
        _wait_for_ready(peer, ready_path)

        for index in range(2):
            result = run_sim(relaunch_plusargs(
                result_paths[index], RELAUNCH_ADDRESSES[index], RELAUNCH_VALUES[index],
            ))
            output = result.stdout + result.stderr
            print(output)
            expected_line = (
                f"addr={RELAUNCH_ADDRESSES[index]:08x} value={RELAUNCH_VALUES[index]:08x}"
            )
            if (
                result.returncode != 0
                or SV_RELAUNCH_BANNER not in output
                or expected_line not in output
            ):
                dump = ""
                if result_paths[index].exists():
                    dump = f"\n\n{result_paths[index].name}:\n{result_paths[index].read_text()}"
                raise AssertionError(output + dump)
            if index == 0:
                continue_path.write_text("continue\n")

        stdout, stderr = peer.communicate(timeout=10)
        if peer.returncode != 0:
            raise AssertionError(
                f"persistent peer exited with {peer.returncode}\n"
                f"stdout:\n{stdout}\nstderr:\n{stderr}"
            )

        results = [json.loads(path.read_text()) for path in result_paths]
        if [entry["id"] for entry in results] != [1, 2]:
            raise AssertionError(f"unexpected peer result ids: {results}")
        for index, entry in enumerate(results):
            if entry["address"] != RELAUNCH_ADDRESSES[index] or entry["value"] != RELAUNCH_VALUES[index]:
                raise AssertionError(f"unexpected peer result at index {index}: {entry}")
    finally:
        terminate_process(peer)
