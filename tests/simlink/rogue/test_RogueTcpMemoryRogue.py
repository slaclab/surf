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
# - Sweep: None -- one GHDL RogueTcpMemoryWrap instance uses a centrally
#   allocated local port pair and one 32-bit scratch register value.
# - Stimulus: A separate process running the configured production Rogue
#   Python creates memory.TcpClient(waitReady=True), a PyRogue Root, and a
#   RemoteVariable. It executes waitReady, Write, Verify, Read, Post, and a
#   second Read while GHDL clocks the real SimLink C model against
#   cocotbext.axi.AxiLiteRam. The child publishes its JSON result by atomic
#   rename.
# - Checks: The child reports successful readiness and equal PyRogue readbacks;
#   cocotb independently checks the final posted AxiLiteRam word. The pytest
#   parent checks the child exit code, operation sequence, values, and Rogue
#   version; result-file existence therefore means the complete JSON is ready.
# - Timing: The client is fully imported and has issued asynchronous ZeroMQ
#   connect calls before GHDL starts. Cocotb advances at most 200,000 clock
#   edges waiting for a result. Parent-side startup and shutdown waits are
#   bounded and terminate the child on every failure path.

import json
import os
import subprocess
import sys
import time

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteRam
import pytest

from tests.simlink.common.peer_orchestration import terminate_process
from tests.simlink.ghdl.simlink_test_utils import (
    build_and_stage_so,
    run_simlink_surf_test,
)
from tests.simlink.paths import (
    GHDL_SOURCE_DIR,
    SIMLINK_TEST_ROOT,
    sim_build_dir,
)
from tests.simlink.ports import GHDL_ROGUE_MEMORY


HERE = SIMLINK_TEST_ROOT / "rogue"
SIM_BUILD = sim_build_dir("rogue", "RogueTcpMemoryRogue")
CLIENT = HERE / "rogue_memory_client.py"
RESULT_PATH = SIM_BUILD / "rogue_memory_result.json"
READY_PATH = SIM_BUILD / "rogue_memory_ready.txt"

CLK_PERIOD_NS = 10
RST_EDGES = 3
MAX_EDGES = 200_000
PORT_NUM = GHDL_ROGUE_MEMORY.port_pair(0).first
TEST_VALUE = 0x14521450
POST_VALUE = TEST_VALUE ^ 0xFFFFFFFF


def _check_rogue_python():
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
                timeout=15,
            )
            return candidate
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
            failures.append(f"{candidate}: {exc}")

    pytest.skip(
        "real-Rogue SimLink contract requires SIMLINK_ROGUE_PYTHON pointing "
        f"to an interpreter with rogue and pyrogue ({'; '.join(failures)})"
    )


def _wait_for_ready(peer):
    deadline = time.monotonic() + 15.0
    while time.monotonic() < deadline:
        if READY_PATH.exists():
            return
        if peer.poll() is not None:
            stdout, stderr = peer.communicate()
            raise RuntimeError(
                f"Rogue client exited before ready (rc={peer.returncode})\n"
                f"stdout:\n{stdout}\nstderr:\n{stderr}"
            )
        time.sleep(0.02)
    raise TimeoutError("Rogue client did not become ready within 15 seconds")


@cocotb.test()
async def real_rogue_memory_contract(dut):
    cocotb.start_soon(Clock(dut.axilClk, CLK_PERIOD_NS, unit="ns").start())
    dut.axilRst.setimmediatevalue(1)

    for _ in range(RST_EDGES):
        await RisingEdge(dut.axilClk)
    dut.axilRst.value = 0
    for _ in range(RST_EDGES):
        await RisingEdge(dut.axilClk)

    # Match the established Memory-wrapper test sequence: let reset initialize
    # every flattened AXI signal before cocotbext.axi samples the interface.
    # If Rogue has already issued a request, AXI valid remains asserted until
    # this subordinate accepts it.
    ram = AxiLiteRam(
        AxiLiteBus.from_prefix(dut, "M_AXI"),
        dut.axilClk,
        dut.axilRst,
        size=2**16,
    )

    for _ in range(MAX_EDGES):
        await RisingEdge(dut.axilClk)
        if RESULT_PATH.exists():
            break
    else:
        raise TimeoutError(
            f"real Rogue client did not finish within {MAX_EDGES} clock edges"
        )

    result = json.loads(RESULT_PATH.read_text())
    assert result["ok"], result
    assert result["readback"] == TEST_VALUE
    assert result["post_readback"] == POST_VALUE
    assert ram.read(0, 4) == POST_VALUE.to_bytes(4, byteorder="little")


def test_RogueTcpMemoryRogue():
    rogue_python = _check_rogue_python()
    build_and_stage_so(GHDL_SOURCE_DIR, SIM_BUILD)

    RESULT_PATH.unlink(missing_ok=True)
    READY_PATH.unlink(missing_ok=True)

    peer = subprocess.Popen(
        [
            rogue_python,
            str(CLIENT),
            str(PORT_NUM),
            hex(TEST_VALUE),
            str(RESULT_PATH),
            str(READY_PATH),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    try:
        _wait_for_ready(peer)
        run_simlink_surf_test(
            test_file=__file__,
            toplevel="surf.roguetcpmemoryflatharness",
            sim_build=SIM_BUILD,
            parameters={"PORT_NUM_G": PORT_NUM},
            extra_vhdl_sources={
                "surf": ["simlink/test/common/RogueTcpMemoryFlatHarness.vhd"],
            },
            stage_library=False,
        )

        stdout, stderr = peer.communicate(timeout=5)
        assert peer.returncode == 0, (
            f"Rogue client exited with {peer.returncode}\n"
            f"stdout:\n{stdout}\nstderr:\n{stderr}"
        )

        result = json.loads(RESULT_PATH.read_text())
        assert result["ok"], result
        assert result["value"] == TEST_VALUE
        assert result["readback"] == TEST_VALUE
        assert result["post_value"] == POST_VALUE
        assert result["post_readback"] == POST_VALUE
        assert result["operations"] == [
            "waitReady", "Write", "Verify", "Read", "Post", "Read"
        ]
        assert result["rogue_version"]
    finally:
        terminate_process(peer)
