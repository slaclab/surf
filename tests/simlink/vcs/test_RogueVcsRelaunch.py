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
# - Elaborate/run the VCS VHPI Memory leaf twice while one external peer process
#   and its ZeroMQ sockets remain alive.
# - Complete one write in run one, queue another after simv exits, then elaborate
#   and invoke a fresh simv that binds the same pair and drains the queued work.
# - Check peer transaction IDs and both VCS-side AXI address/data observations.
# - Gate the proprietary test explicitly and bound compilation, runs, peer
#   readiness, and teardown through the shared VCS/peer helpers.

import json
import subprocess
import sys
import time

import pytest

from tests.simlink.common.peer_orchestration import terminate_process
from tests.simlink.paths import (
    COMMON_HDL_TEST_SOURCE_DIR,
    SIMLINK_TEST_ROOT,
    VCS_HDL_TEST_SOURCE_DIR,
    sim_build_dir,
)
from tests.simlink.ports import VCS_RELAUNCH
from tests.simlink.vcs import vcs_test_utils as vu


SIM_BUILD = sim_build_dir("vcs", "RogueVcsRelaunch")
TOP = "RogueSimLinkMemoryRelaunchBridge"
COCOTB_MODULE = "tests.simlink.common.simlink_memory_relaunch_cocotb"
VHDL_SOURCES = [
    *vu.MODEL_VHDL_SOURCES,
    COMMON_HDL_TEST_SOURCE_DIR / "RogueSimLinkMemoryRelaunchHarness.vhd",
]
VERILOG_SOURCES = [VCS_HDL_TEST_SOURCE_DIR / "RogueSimLinkMemoryRelaunchBridge.sv"]
PEER = SIMLINK_TEST_ROOT / "common" / "persistent_memory_peer.py"
PORT_NUM = VCS_RELAUNCH.port_pair(0).first
READY_PATH = SIM_BUILD / "peer.ready"
CONTINUE_PATH = SIM_BUILD / "continue"
RESULT_PATHS = (SIM_BUILD / "phase-1.json", SIM_BUILD / "phase-2.json")
VALUES = (0x11223344, 0x55667788)

pytestmark = pytest.mark.skipif(not vu.tools_available(), reason=vu.SKIP_REASON)


def _wait_for_ready(peer):
    deadline = time.monotonic() + 15.0
    while time.monotonic() < deadline:
        if READY_PATH.exists():
            return
        if peer.poll() is not None:
            stdout, stderr = peer.communicate()
            raise RuntimeError(
                f"persistent peer exited before readiness (rc={peer.returncode})\n"
                f"stdout:\n{stdout}\nstderr:\n{stderr}"
            )
        time.sleep(0.01)
    raise TimeoutError("persistent peer did not signal readiness")


def _run_phase(result_path, value):
    return vu.run_cocotb(
        TOP,
        COCOTB_MODULE,
        VERILOG_SOURCES,
        SIM_BUILD,
        extra_env={
            "SIMLINK_RELAUNCH_RESULT": result_path,
            "SIMLINK_RELAUNCH_VALUE": hex(value),
            "SIMLINK_RELAUNCH_PORT": PORT_NUM,
        },
    )


def test_vcs_persistent_peer_survives_rebuild_and_relaunch():
    vu.build_vhpi_library()
    vu.compile_vhdl(VHDL_SOURCES, SIM_BUILD)
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
        _wait_for_ready(peer)
        print(_run_phase(RESULT_PATHS[0], VALUES[0]))
        CONTINUE_PATH.write_text("continue\n")
        print(_run_phase(RESULT_PATHS[1], VALUES[1]))

        stdout, stderr = peer.communicate(timeout=5)
        assert peer.returncode == 0, (
            f"persistent peer exited with {peer.returncode}\n"
            f"stdout:\n{stdout}\nstderr:\n{stderr}"
        )
        assert [json.loads(path.read_text())["id"] for path in RESULT_PATHS] == [1, 2]
    finally:
        terminate_process(peer)
