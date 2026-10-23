##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Backend-neutral real-Rogue orchestration for RogueSvRogueTb, shared by the
Icarus and Verilator contracts. Spawns the unchanged production Rogue clients
(rogue_memory_client.py, rogue_stream_client.py, rogue_sideband_client.py)
against one self-driving SV top and validates the same JSON contracts the
GHDL real-Rogue tests assert."""

import json
import os
import subprocess
import sys
import time

from tests.simlink.common.peer_orchestration import terminate_process
from tests.simlink.paths import SIMLINK_TEST_ROOT

import pytest

HERE = SIMLINK_TEST_ROOT / "rogue"
MEMORY_CLIENT = HERE / "rogue_memory_client.py"
STREAM_CLIENT = HERE / "rogue_stream_client.py"
SIDEBAND_CLIENT = HERE / "rogue_sideband_client.py"

SV_ROGUE_TOP = "RogueSvRogueTb"
SV_ROGUE_BANNER = "RogueSvRogueTb passed"

# Fixed port offsets from BASE_PORT_G, matching RogueSvRogueTb.sv's port map.
MEMORY_OFFSET = 0
STREAM_OFFSET = 2
SIDEBAND_OFFSET = 4

# Real-Rogue contract constants. These equal the GHDL real-Rogue contract
# constants in test_RogueTcpMemoryRogue.py, test_RogueStreamRogue.py and
# test_RogueSideBandRogue.py.
MEMORY_TEST_VALUE = 0x14521450
MEMORY_POST_VALUE = MEMORY_TEST_VALUE ^ 0xFFFFFFFF
HDL_TO_CLIENT = bytes.fromhex("deadbeef")
CLIENT_TO_HDL = bytes.fromhex("12345678")
DUT_OPCODE = 0x2A
DUT_REMDATA = 0x3B
CLIENT_OPCODE = 0x5C
CLIENT_REMDATA = 0x6D


def check_rogue_python():
    candidates = []
    configured = os.environ.get("SIMLINK_ROGUE_PYTHON")
    if configured:
        candidates.append(configured)
    candidates.append(sys.executable)

    failures = []
    for candidate in dict.fromkeys(candidates):
        try:
            subprocess.run(
                [candidate, "-c", "import rogue, pyrogue"],
                check=True,
                capture_output=True,
                text=True,
                timeout=30,
            )
            return candidate
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
            failures.append(f"{candidate}: {exc}")

    pytest.skip(
        "real-Rogue SimLink contract requires SIMLINK_ROGUE_PYTHON pointing "
        f"to an interpreter with rogue and pyrogue ({'; '.join(failures)})"
    )


def sv_rogue_summary():
    return (
        f"RogueSvRogueTb memory word0={MEMORY_POST_VALUE:08x} "
        f"stream rx={CLIENT_TO_HDL.hex()} "
        f"sideband opcode={CLIENT_OPCODE:02x} remdata={CLIENT_REMDATA:02x}"
    )


def rogue_plusargs(memory_result, stream_result, sideband_result):
    return [
        f"+ROGUE_MEMORY_RESULT={memory_result}",
        f"+ROGUE_STREAM_RESULT={stream_result}",
        f"+ROGUE_SIDEBAND_RESULT={sideband_result}",
    ]


def _wait_for_ready(peer, ready_path, name):
    # Matches the SIMLINK_MULTI_MAX_TRAFFIC_SECONDS/SIMLINK_PEER_WAIT_SECONDS
    # "loaded host" default of 60s already established elsewhere in this
    # test suite: under pytest-xdist, client process startup (import
    # rogue/pyrogue, construct the TcpClient) competes with concurrent
    # ruckus builds in sibling workers.
    deadline = time.monotonic() + 60.0
    while time.monotonic() < deadline:
        if ready_path.exists():
            return
        if peer.poll() is not None:
            stdout, stderr = peer.communicate()
            raise RuntimeError(
                f"{name} client exited before ready (rc={peer.returncode})\n"
                f"stdout:\n{stdout}\nstderr:\n{stderr}"
            )
        time.sleep(0.02)
    raise TimeoutError(f"{name} client did not become ready within 60 seconds")


# rogue.interfaces.memory.TcpClient's readiness probe (started when the
# client's `with root:` block enters, right after it signals ready) times out
# after a fixed 10 s baked into the compiled Rogue library, not configurable
# from this side of the binding. Launching the simulator through ruckus's tb
# recipe (make parses the Makefile and system_iverilog.mk/system_verilator.mk
# on every invocation, including their own tool-version and git shell calls)
# adds real fork/exec/parse overhead between "clients ready" and "simulator
# actually listening" that a direct exec did not have; under pytest-xdist
# contention that overhead occasionally exceeds the fixed 10 s budget. A
# retry is the correct mitigation here, not a longer timeout: the timeout
# cannot be lengthened, and the clients must start between build and run, so
# the order that creates this race cannot change.
ROGUE_READINESS_RETRY_SIGNATURE = "Timed out waiting for remote TcpServer readiness"
ROGUE_RUN_ATTEMPTS = 3


def run_sv_rogue(run_sim, base_port, build_dir, rogue_python):
    """Spawn the three production Rogue clients, run one simulator invocation
    of RogueSvRogueTb via run_sim(plusargs), and validate the banner, summary
    line, and every client's result JSON exactly as the GHDL real-Rogue
    contracts assert them.

    run_sim(plusargs) must return a subprocess.CompletedProcess. Retries on
    the specific transient SimLink-readiness race described above; any other
    failure (wrong values, missing banner, non-transient client error) is
    raised on the first attempt."""
    for attempt in range(1, ROGUE_RUN_ATTEMPTS + 1):
        try:
            _attempt_sv_rogue(run_sim, base_port, build_dir, rogue_python)
            return
        except AssertionError as exc:
            if ROGUE_READINESS_RETRY_SIGNATURE not in str(exc) or attempt == ROGUE_RUN_ATTEMPTS:
                raise
            print(
                f"run_sv_rogue: attempt {attempt} hit the transient SimLink "
                f"readiness race under load, retrying: {exc}"
            )


def _attempt_sv_rogue(run_sim, base_port, build_dir, rogue_python):
    build_dir.mkdir(parents=True, exist_ok=True)

    memory_result = build_dir / "rogue_memory_result.json"
    memory_ready = build_dir / "rogue_memory_ready.txt"
    stream_result = build_dir / "rogue_stream_result.json"
    stream_ready = build_dir / "rogue_stream_ready.txt"
    sideband_result = build_dir / "rogue_sideband_result.json"
    sideband_ready = build_dir / "rogue_sideband_ready.txt"

    for path in (
        memory_result, memory_ready,
        stream_result, stream_ready,
        sideband_result, sideband_ready,
    ):
        path.unlink(missing_ok=True)

    memory_port = base_port + MEMORY_OFFSET
    stream_port = base_port + STREAM_OFFSET
    sideband_port = base_port + SIDEBAND_OFFSET

    memory_peer = subprocess.Popen(
        [
            rogue_python, str(MEMORY_CLIENT), str(memory_port),
            hex(MEMORY_TEST_VALUE), str(memory_result), str(memory_ready),
        ],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    stream_peer = subprocess.Popen(
        [
            rogue_python, str(STREAM_CLIENT), str(stream_port),
            CLIENT_TO_HDL.hex(), str(stream_result), str(stream_ready),
        ],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    sideband_peer = subprocess.Popen(
        [
            rogue_python, str(SIDEBAND_CLIENT), str(sideband_port),
            hex(CLIENT_OPCODE), hex(CLIENT_REMDATA),
            str(sideband_result), str(sideband_ready),
        ],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )

    peers = (
        ("memory", memory_peer, memory_ready, memory_result),
        ("stream", stream_peer, stream_ready, stream_result),
        ("sideband", sideband_peer, sideband_ready, sideband_result),
    )

    try:
        for name, peer, ready_path, _ in peers:
            _wait_for_ready(peer, ready_path, name)

        result = run_sim(rogue_plusargs(memory_result, stream_result, sideband_result))
        output = result.stdout + result.stderr
        print(output)

        if (
            result.returncode != 0
            or SV_ROGUE_BANNER not in output
            or sv_rogue_summary().lower() not in output.lower()
        ):
            dump = ""
            for name, _, _, result_path in peers:
                if result_path.exists():
                    dump += f"\n\n{name} result:\n{result_path.read_text()}"
            raise AssertionError(output + dump)

        for name, peer, _, _ in peers:
            stdout, stderr = peer.communicate(timeout=10)
            if peer.returncode != 0:
                raise AssertionError(
                    f"{name} client exited with {peer.returncode}\n"
                    f"stdout:\n{stdout}\nstderr:\n{stderr}"
                )

        memory_json = json.loads(memory_result.read_text())
        assert memory_json["ok"], memory_json
        assert memory_json["value"] == MEMORY_TEST_VALUE
        assert memory_json["readback"] == MEMORY_TEST_VALUE
        assert memory_json["post_value"] == MEMORY_POST_VALUE
        assert memory_json["post_readback"] == MEMORY_POST_VALUE
        assert memory_json["operations"] == [
            "waitReady", "Write", "Verify", "Read", "Post", "Read"
        ]
        assert memory_json["rogue_version"]

        stream_json = json.loads(stream_result.read_text())
        assert stream_json["ok"], stream_json
        assert stream_json["hdl_to_client_hex"] == HDL_TO_CLIENT.hex()
        assert stream_json["client_to_hdl_hex"] == CLIENT_TO_HDL.hex()

        sideband_json = json.loads(sideband_result.read_text())
        assert sideband_json["ok"], sideband_json
        received = sideband_json["received"]
        assert any(entry["opCode"] == DUT_OPCODE for entry in received), (
            f"DUT_OPCODE {DUT_OPCODE:#x} not found in received: {received}"
        )
        assert any(entry["remData"] == DUT_REMDATA for entry in received), (
            f"DUT_REMDATA {DUT_REMDATA:#x} not found in received: {received}"
        )
        assert sideband_json["sent_opcode"] == CLIENT_OPCODE
        assert sideband_json["sent_remdata"] == CLIENT_REMDATA
    finally:
        for _, peer, _, _ in peers:
            terminate_process(peer)
