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
# - Sweep: Exchange one opcode and one remData value in each direction across a
#   real PyRogue SideBandSim process and the GHDL SimLink model.
# - Stimulus: Start the external client first, then drive the HDL-to-client
#   opcode before remData so the transport is warm before the reply.
# - Checks: Require the client's JSON result and the DUT's received opcode and
#   remData to match the independent constants in both directions.
# - Timing: Bound interpreter discovery, client readiness, result creation, and
#   reply observation; always terminate the child process in cleanup.
#
# Real-Rogue SideBand contract: a production pyrogue.interfaces.simulation.SideBandSim
# (separate process) exchanges one opcode and one remData each direction with
# RogueSideBandFlatHarness under GHDL. cocotb is the firmware-side sideband
# endpoint and drives the HDL->client opcode first (the HDL-first ordering warms
# the ZMQ pipe so the client's reply is not dropped). Skips unless
# SIMLINK_ROGUE_PYTHON resolves to an interpreter with rogue+pyrogue.
#
# Timing contract: the Rogue SideBandSim client has an internal 5-second
# HDL-arrival timeout, so the driver spawns the client before calling
# run_simlink_surf_test, and the cocotb test drives txOpCodeEn immediately after
# reset (within well under 5 real seconds of GHDL startup).

import json
import os
import subprocess
import sys
import time

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import pytest

from tests.simlink.common.peer_orchestration import terminate_process
from tests.simlink.ghdl.simlink_test_utils import build_and_stage_so, run_simlink_surf_test
from tests.simlink.paths import GHDL_SOURCE_DIR, SIMLINK_TEST_ROOT, sim_build_dir
from tests.simlink.ports import GHDL_ROGUE_SIDEBAND

HERE = SIMLINK_TEST_ROOT / "rogue"
SIM_BUILD = sim_build_dir("rogue", "RogueSideBandRogue")
CLIENT = HERE / "rogue_sideband_client.py"
RESULT_PATH = SIM_BUILD / "rogue_sideband_result.json"
READY_PATH = SIM_BUILD / "rogue_sideband_ready.txt"

CLK_PERIOD_NS = 10
RST_EDGES = 3
GAP_EDGES = 5
MAX_EDGES = 200_000
PORT_NUM = GHDL_ROGUE_SIDEBAND.port_pair(0).first

# HDL -> client direction (cocotb drives tx* signals, client receives via callback)
DUT_OPCODE = 0x2A
DUT_REMDATA = 0x3B

# Client -> HDL direction (client sends via sideband.send(), DUT surfaces on rx*)
CLIENT_OPCODE = 0x5C
CLIENT_REMDATA = 0x6D


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
        "real-Rogue SideBand SimLink contract requires SIMLINK_ROGUE_PYTHON pointing "
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
async def real_rogue_sideband_contract(dut):
    cocotb.start_soon(Clock(dut.sysClk, CLK_PERIOD_NS, unit="ns").start())
    dut.sysRst.setimmediatevalue(1)
    dut.txOpCode.setimmediatevalue(0)
    dut.txOpCodeEn.setimmediatevalue(0)
    dut.txRemData.setimmediatevalue(0)

    for _ in range(RST_EDGES):
        await RisingEdge(dut.sysClk)
    dut.sysRst.value = 0
    for _ in range(RST_EDGES):
        await RisingEdge(dut.sysClk)

    # HDL -> client FIRST: a one-cycle opcode strobe, then (after a gap so the
    # two sends are distinct edges) a remData change.  Mirror the tx* drive
    # sequence from test_RogueSideBandWrap.py.  No artificial settle is needed:
    # the model's outbound PUSH sets ZMQ_IMMEDIATE and its send worker retries
    # on EAGAIN, so the first tx blocks until the client's PULL is connected
    # rather than being dropped (same HDL-first guarantee the Stream test uses).
    dut.txOpCode.value = DUT_OPCODE
    dut.txOpCodeEn.value = 1
    await RisingEdge(dut.sysClk)
    dut.txOpCodeEn.value = 0
    dut.txOpCode.value = 0
    for _ in range(GAP_EDGES):
        await RisingEdge(dut.sysClk)
    dut.txRemData.value = DUT_REMDATA

    # Poll for the client to finish writing its result file.  The client sends
    # CLIENT_OPCODE and CLIENT_REMDATA after receiving the DUT's first opcode
    # event, so the result file appearing means the client has dispatched its
    # reply ZMQ messages.
    for _ in range(MAX_EDGES):
        await RisingEdge(dut.sysClk)
        if RESULT_PATH.exists():
            break
    else:
        raise TimeoutError(
            f"real Rogue SideBand client did not finish within {MAX_EDGES} clock edges"
        )

    # Continue clocking so the C model processes the client's incoming ZMQ
    # messages and latches rxOpCode / rxRemData.  The result file is written
    # immediately after sideband.send() calls, so ZMQ delivery may still be
    # in transit when the poll loop above exits.
    for _ in range(MAX_EDGES):
        await RisingEdge(dut.sysClk)
        rx_op = int(dut.rxOpCode.value)
        rx_rem = int(dut.rxRemData.value)
        if rx_op == CLIENT_OPCODE and rx_rem == CLIENT_REMDATA:
            break
    else:
        rx_op = int(dut.rxOpCode.value)
        rx_rem = int(dut.rxRemData.value)
        raise TimeoutError(
            f"DUT rx* did not latch client values within {MAX_EDGES} additional edges: "
            f"rxOpCode={rx_op:#x} (expected {CLIENT_OPCODE:#x}), "
            f"rxRemData={rx_rem:#x} (expected {CLIENT_REMDATA:#x})"
        )

    assert int(dut.rxOpCode.value) == CLIENT_OPCODE, (
        f"rxOpCode={int(dut.rxOpCode.value):#x} expected {CLIENT_OPCODE:#x}"
    )
    assert int(dut.rxRemData.value) == CLIENT_REMDATA, (
        f"rxRemData={int(dut.rxRemData.value):#x} expected {CLIENT_REMDATA:#x}"
    )

    result = json.loads(RESULT_PATH.read_text())
    assert result["ok"], result

    # The DUT sent DUT_OPCODE on one ZMQ event and DUT_REMDATA on another;
    # both must appear somewhere in the received list.
    received = result["received"]
    assert any(entry["opCode"] == DUT_OPCODE for entry in received), (
        f"DUT_OPCODE {DUT_OPCODE:#x} not found in received: {received}"
    )
    assert any(entry["remData"] == DUT_REMDATA for entry in received), (
        f"DUT_REMDATA {DUT_REMDATA:#x} not found in received: {received}"
    )

    assert result["sent_opcode"] == CLIENT_OPCODE, result
    assert result["sent_remdata"] == CLIENT_REMDATA, result


def test_RogueSideBandRogue():
    rogue_python = _check_rogue_python()
    build_and_stage_so(GHDL_SOURCE_DIR, SIM_BUILD)
    RESULT_PATH.unlink(missing_ok=True)
    READY_PATH.unlink(missing_ok=True)
    peer = subprocess.Popen(
        [
            rogue_python,
            str(CLIENT),
            str(PORT_NUM),
            hex(CLIENT_OPCODE),
            hex(CLIENT_REMDATA),
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
            toplevel="surf.roguesidebandflatharness",
            sim_build=SIM_BUILD,
            parameters={"PORT_NUM_G": PORT_NUM},
            extra_vhdl_sources={"surf": ["simlink/test/common/RogueSideBandFlatHarness.vhd"]},
            stage_library=False,
        )
        stdout, stderr = peer.communicate(timeout=5)
        assert peer.returncode == 0, (
            f"Rogue client exited with {peer.returncode}\nstdout:\n{stdout}\nstderr:\n{stderr}"
        )
        result = json.loads(RESULT_PATH.read_text())
        assert result["ok"], result
        received = result["received"]
        assert any(entry["opCode"] == DUT_OPCODE for entry in received), (
            f"DUT_OPCODE {DUT_OPCODE:#x} not found in received: {received}"
        )
        assert any(entry["remData"] == DUT_REMDATA for entry in received), (
            f"DUT_REMDATA {DUT_REMDATA:#x} not found in received: {received}"
        )
        assert result["sent_opcode"] == CLIENT_OPCODE
        assert result["sent_remdata"] == CLIENT_REMDATA
    finally:
        terminate_process(peer)
