##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Real-Rogue Stream contract: a production rogue.interfaces.stream.TcpClient
# (separate process) exchanges one frame each direction with RogueTcpStreamWrap
# under GHDL. cocotb is the firmware-side AXI-Stream endpoint and drives the
# HDL->client frame first (the model's inbound PUSH sets ZMQ_IMMEDIATE so the
# client->HDL frame is not slow-joiner-dropped). Skips unless SIMLINK_ROGUE_PYTHON
# resolves to an interpreter with rogue+pyrogue.

import json
import os
import subprocess
import sys
import time

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
import pytest

from tests.simlink.common.peer_orchestration import terminate_process
from tests.simlink.ghdl.simlink_test_utils import build_and_stage_so, run_simlink_surf_test
from tests.simlink.paths import GHDL_SOURCE_DIR, SIMLINK_TEST_ROOT, sim_build_dir
from tests.simlink.ports import GHDL_ROGUE_STREAM

HERE = SIMLINK_TEST_ROOT / "rogue"
SIM_BUILD = sim_build_dir("rogue", "RogueStreamRogue")
CLIENT = HERE / "rogue_stream_client.py"
RESULT_PATH = SIM_BUILD / "rogue_stream_result.json"
READY_PATH = SIM_BUILD / "rogue_stream_ready.txt"

CLK_PERIOD_NS = 10
RST_EDGES = 3
MAX_EDGES = 200_000
PORT_NUM = GHDL_ROGUE_STREAM.port_pair(0).first
HDL_TO_CLIENT = bytes.fromhex("deadbeef")
CLIENT_TO_HDL = bytes.fromhex("12345678")


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
        "real-Rogue Stream SimLink contract requires SIMLINK_ROGUE_PYTHON pointing "
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
async def real_rogue_stream_contract(dut):
    cocotb.start_soon(Clock(dut.axisClk, CLK_PERIOD_NS, unit="ns").start())
    dut.axisRst.setimmediatevalue(1)
    dut.S_AXIS_TVALID.setimmediatevalue(0)
    dut.S_AXIS_TDATA.setimmediatevalue(0)
    dut.S_AXIS_TKEEP.setimmediatevalue(0)
    dut.S_AXIS_TLAST.setimmediatevalue(0)
    dut.S_AXIS_TDEST.setimmediatevalue(0)
    dut.S_AXIS_TUSER.setimmediatevalue(0)
    dut.M_AXIS_TREADY.setimmediatevalue(0)
    for _ in range(RST_EDGES):
        await RisingEdge(dut.axisClk)
    dut.axisRst.value = 0
    for _ in range(RST_EDGES):
        await RisingEdge(dut.axisClk)

    source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "S_AXIS"), dut.axisClk, dut.axisRst)
    sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "M_AXIS"), dut.axisClk, dut.axisRst)

    # HDL -> client first (warms the pipe), then receive client -> HDL.
    receive = cocotb.start_soon(sink.recv())
    await source.send(AxiStreamFrame(HDL_TO_CLIENT))

    for _ in range(MAX_EDGES):
        await RisingEdge(dut.axisClk)
        if RESULT_PATH.exists():
            break
    else:
        raise TimeoutError(f"real Rogue Stream client did not finish within {MAX_EDGES} clock edges")

    # The client has already written its result (the poll above broke on
    # RESULT_PATH), so the client->HDL frame is in flight; bound the wait so a
    # lost return frame fails cleanly instead of hanging to the CI job timeout.
    rx_frame = await with_timeout(receive, MAX_EDGES * CLK_PERIOD_NS, "ns")
    assert bytes(rx_frame.tdata) == CLIENT_TO_HDL, bytes(rx_frame.tdata).hex()

    result = json.loads(RESULT_PATH.read_text())
    assert result["ok"], result
    assert result["hdl_to_client_hex"] == HDL_TO_CLIENT.hex(), result
    assert result["client_to_hdl_hex"] == CLIENT_TO_HDL.hex(), result


def test_RogueStreamRogue():
    rogue_python = _check_rogue_python()
    build_and_stage_so(GHDL_SOURCE_DIR, SIM_BUILD)
    RESULT_PATH.unlink(missing_ok=True)
    READY_PATH.unlink(missing_ok=True)
    peer = subprocess.Popen(
        [rogue_python, str(CLIENT), str(PORT_NUM), CLIENT_TO_HDL.hex(), str(RESULT_PATH), str(READY_PATH)],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    try:
        _wait_for_ready(peer)
        run_simlink_surf_test(
            test_file=__file__,
            toplevel="surf.roguetcpstreamflatharness",
            sim_build=SIM_BUILD,
            parameters={"PORT_NUM_G": PORT_NUM},
            extra_vhdl_sources={"surf": ["simlink/test/common/RogueTcpStreamFlatHarness.vhd"]},
            stage_library=False,
        )
        stdout, stderr = peer.communicate(timeout=5)
        assert peer.returncode == 0, f"Rogue client exited with {peer.returncode}\nstdout:\n{stdout}\nstderr:\n{stderr}"
        result = json.loads(RESULT_PATH.read_text())
        assert result["ok"], result
        assert result["hdl_to_client_hex"] == HDL_TO_CLIENT.hex()
        assert result["client_to_hdl_hex"] == CLIENT_TO_HDL.hex()
    finally:
        terminate_process(peer)
