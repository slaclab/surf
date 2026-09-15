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
# - Sweep: Run one RogueTcpMemoryWrap in two consecutive GHDL processes while
#   one external ZeroMQ peer process and its sockets remain alive.
# - Stimulus: The peer writes one value during the first run, waits for that
#   simulator to exit, queues a second write while no model owns the ports, and
#   receives its response after a fresh GHDL run binds the same pair.
# - Checks: Each fresh AXI-Lite RAM observes its phase's value, both Memory
#   completions preserve their transaction IDs, and the peer never restarts.
# - Timing: Peer readiness, simulator traffic, subprocess completion, and
#   teardown are bounded; a failure terminates the persistent peer.

import json
import os
from pathlib import Path
import subprocess
import sys
import time

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteRam

from tests.simlink.common.peer_orchestration import terminate_process
from tests.simlink.ghdl.simlink_test_utils import run_simlink_surf_test
from tests.simlink.paths import SIMLINK_TEST_ROOT, sim_build_dir
from tests.simlink.ports import GHDL_RELOAD


SIM_BUILD = sim_build_dir("ghdl", "RogueSimulatorRelaunch")
PEER = SIMLINK_TEST_ROOT / "common" / "persistent_memory_peer.py"
PORT_NUM = GHDL_RELOAD.port_pair(0).first
READY_PATH = SIM_BUILD / "peer.ready"
CONTINUE_PATH = SIM_BUILD / "continue"
RESULT_PATHS = (SIM_BUILD / "phase-1.json", SIM_BUILD / "phase-2.json")
VALUES = (0x10203040, 0x50607080)
MAX_EDGES = 200_000


def _wait_for_file(path, peer, description):
    deadline = time.monotonic() + 15.0
    while time.monotonic() < deadline:
        if path.exists():
            return
        if peer.poll() is not None:
            stdout, stderr = peer.communicate()
            raise RuntimeError(
                f"persistent peer exited before {description} "
                f"(rc={peer.returncode})\nstdout:\n{stdout}\nstderr:\n{stderr}"
            )
        time.sleep(0.01)
    raise TimeoutError(f"persistent peer did not reach {description}")


@cocotb.test()
async def memory_relaunch_phase(dut):
    result_path = os.environ["SIMLINK_RELAUNCH_RESULT"]
    expected_value = int(os.environ["SIMLINK_RELAUNCH_VALUE"], 0)

    cocotb.start_soon(Clock(dut.axilClk, 10, unit="ns").start())
    dut.axilRst.setimmediatevalue(1)
    for _ in range(3):
        await RisingEdge(dut.axilClk)
    dut.axilRst.value = 0
    for _ in range(3):
        await RisingEdge(dut.axilClk)

    ram = AxiLiteRam(
        AxiLiteBus.from_prefix(dut, "M_AXI"),
        dut.axilClk,
        dut.axilRst,
        size=2**16,
    )

    for _ in range(MAX_EDGES):
        await RisingEdge(dut.axilClk)
        if os.path.exists(result_path):
            break
    else:
        raise TimeoutError("persistent peer did not complete this simulator run")

    result = json.loads(Path(result_path).read_text())
    assert result["value"] == expected_value
    assert ram.read(result["address"], 4) == expected_value.to_bytes(4, "little")


def _run_phase(result_path, value):
    run_simlink_surf_test(
        test_file=__file__,
        toplevel="surf.roguetcpmemoryflatharness",
        sim_build=SIM_BUILD,
        parameters={"PORT_NUM_G": PORT_NUM},
        extra_env={
            "SIMLINK_RELAUNCH_RESULT": result_path,
            "SIMLINK_RELAUNCH_VALUE": hex(value),
        },
        extra_vhdl_sources={
            "surf": ["simlink/test/common/RogueTcpMemoryFlatHarness.vhd"],
        },
    )


def test_persistent_peer_survives_simulator_relaunch():
    SIM_BUILD.mkdir(parents=True, exist_ok=True)
    for path in (*RESULT_PATHS, READY_PATH, CONTINUE_PATH):
        path.unlink(missing_ok=True)

    peer = subprocess.Popen(
        [
            sys.executable,
            str(PEER),
            str(PORT_NUM),
            str(READY_PATH),
            str(CONTINUE_PATH),
            str(RESULT_PATHS[0]),
            str(RESULT_PATHS[1]),
            hex(VALUES[0]),
            hex(VALUES[1]),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    try:
        _wait_for_file(READY_PATH, peer, "readiness")
        _run_phase(RESULT_PATHS[0], VALUES[0])

        # The first simulator process has exited. Release the still-running
        # peer so it queues phase two before the replacement process starts.
        CONTINUE_PATH.write_text("continue\n")
        _run_phase(RESULT_PATHS[1], VALUES[1])

        stdout, stderr = peer.communicate(timeout=5)
        assert peer.returncode == 0, (
            f"persistent peer exited with {peer.returncode}\n"
            f"stdout:\n{stdout}\nstderr:\n{stderr}"
        )
        assert [json.loads(path.read_text())["id"] for path in RESULT_PATHS] == [1, 2]
    finally:
        terminate_process(peer)
