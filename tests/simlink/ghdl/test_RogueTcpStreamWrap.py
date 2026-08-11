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
# - Sweep: Run one cocotb case for each 8-, 64-, and 128-byte AXI/foreign-
#   function width, plus an 8-byte half-rate paced case. Each pytest case owns
#   a distinct port pair and simulator build directory.
# - Stimulus: A separate Rogue-TCP peer pushes deterministic frames toward the
#   DUT while cocotbext.axi drives the return direction. Every case also sends
#   a sparse-TKEEP beat; the paced case additionally sends a three-beat frame.
# - Checks: Compare payloads in both directions, verify that sparse TKEEP keeps
#   only the selected lane, and require two cycles between paced transfers.
# - Timing: All cocotb source, sink, monitor, and peer waits are bounded. The
#   managed peer is terminated on every exit path so xdist workers cannot leak
#   subprocesses or sockets.
#
# Exercises the stream wrapper, width conversion, pacing, and separate-process
# Rogue-TCP protocol. A standalone C harness checks the MAX_FRAME boundary with
# trailing unkept lanes without simulating a 20 MB frame cycle by cycle.

import os
from pathlib import Path
import subprocess

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource
import pytest

from tests.simlink.common.peer_orchestration import managed_peer
from tests.simlink.common.simlink_protocol import (
    STREAM_EXPECT_FRAMES,
    STREAM_SEND_FRAMES,
)
from tests.simlink.ghdl.simlink_test_utils import run_simlink_surf_test
from tests.simlink.paths import GHDL_SOURCE_DIR, SHARED_SOURCE_DIR, SIMLINK_TEST_ROOT, sim_build_dir
from tests.simlink.ports import GHDL_CASES, GHDL_STREAM_MULTICHAN


HERE = SIMLINK_TEST_ROOT / "ghdl"
GHDL_DIR = GHDL_SOURCE_DIR
SHARED_DIR = SHARED_SOURCE_DIR

CLK_PERIOD_NS = 10
RST_EDGES = 2
MAX_EDGES = 5000
COCOTB_TIMEOUT_US = 100

CASES = {
    "default": {
        "build_name": "RogueTcpStreamWrap",
        "data_bytes": 8,
        "port": GHDL_CASES.port_pair(2).first,
        "paced": False,
    },
    "wide64": {
        "build_name": "RogueTcpStreamWrapWide64",
        "data_bytes": 64,
        "port": GHDL_CASES.port_pair(7).first,
        "paced": False,
    },
    "wide128": {
        "build_name": "RogueTcpStreamWrapWide128",
        "data_bytes": 128,
        "port": GHDL_CASES.port_pair(8).first,
        "paced": False,
    },
    "paced": {
        "build_name": "RogueTcpStreamWrapPaced",
        "data_bytes": 8,
        "port": GHDL_CASES.port_pair(9).first,
        "paced": True,
    },
    # Regression for the channelMap()/CHAN_MASK_C overflow: a non-power-of-two
    # CHAN_COUNT_G used to write past the CHAN_MAP_C array at elaboration. This
    # case only needs the design to elaborate and idle -- the bug fires when the
    # CHAN_MAP_C constant is evaluated, before any traffic -- so it drives no
    # peer. See RogueTcpStreamWrap.vhd channelMap().
    "chan3": {
        "build_name": "RogueTcpStreamWrapChan3",
        "data_bytes": 8,
        "port": GHDL_STREAM_MULTICHAN.port_pair(0).first,
        "paced": False,
        "chan_count": 3,
    },
}

CASE_NAME = os.environ.get("SIMLINK_CASE", "default")
CASE = CASES[CASE_NAME]
SIM_BUILD = Path(os.environ.get(
    "SIMLINK_SIM_BUILD",
    sim_build_dir("ghdl", CASE["build_name"]),
))
PORT_NUM = int(os.environ.get("SIMLINK_PORT", CASE["port"]))
STREAM_BOUNDARY_HARNESS = SIM_BUILD / "stream_max_frame_harness"


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = None
        self.sink = None

        cocotb.start_soon(Clock(dut.axisClk, CLK_PERIOD_NS, unit="ns").start())

        dut.axisRst.setimmediatevalue(1)
        dut.S_AXIS_TVALID.setimmediatevalue(0)
        dut.S_AXIS_TDATA.setimmediatevalue(0)
        dut.S_AXIS_TKEEP.setimmediatevalue(0)
        dut.S_AXIS_TLAST.setimmediatevalue(0)
        dut.S_AXIS_TDEST.setimmediatevalue(0)
        dut.S_AXIS_TUSER.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)

    async def reset(self):
        self.dut.axisRst.value = 1
        await self.cycle(RST_EDGES)
        self.dut.axisRst.value = 0
        await self.cycle(RST_EDGES)

    def start_agents(self):
        self.source = AxiStreamSource(
            AxiStreamBus.from_prefix(self.dut, "S_AXIS"),
            self.dut.axisClk,
            self.dut.axisRst,
        )
        self.sink = AxiStreamSink(
            AxiStreamBus.from_prefix(self.dut, "M_AXIS"),
            self.dut.axisClk,
            self.dut.axisRst,
        )


async def _collect_frames(sink, count):
    return [await sink.recv() for _ in range(count)]


async def _wait_for_peer(dut, peer):
    for _ in range(MAX_EDGES):
        await RisingEdge(dut.axisClk)
        if peer.poll() is not None:
            assert peer.returncode == 0, f"peer exited with code {peer.returncode}"
            return
    raise TimeoutError(f"peer process did not exit within {MAX_EDGES} clock edges")


async def _run_round_trip(tb):
    dut = tb.dut
    result_path = SIM_BUILD / "stream_peer_result.json"

    with managed_peer("stream", PORT_NUM, result_path) as peer:
        await tb.reset()
        tb.start_agents()
        receive = cocotb.start_soon(
            _collect_frames(tb.sink, len(STREAM_SEND_FRAMES))
        )

        for frame in STREAM_EXPECT_FRAMES:
            await with_timeout(
                tb.source.send(AxiStreamFrame(frame["data"])),
                COCOTB_TIMEOUT_US,
                "us",
            )
        await with_timeout(tb.source.wait(), COCOTB_TIMEOUT_US, "us")
        await _wait_for_peer(dut, peer)

        received = await with_timeout(receive, COCOTB_TIMEOUT_US, "us")
        assert len(received) == len(STREAM_SEND_FRAMES)
        for rx_frame, expected in zip(received, STREAM_SEND_FRAMES):
            assert bytes(rx_frame.tdata) == expected["data"]

        observed = peer.read_result()
        assert len(observed["received"]) == len(STREAM_EXPECT_FRAMES)
        for decoded, expected in zip(observed["received"], STREAM_EXPECT_FRAMES):
            assert decoded["data_hex"] == expected["data"].hex()


async def _run_sparse_tkeep(tb):
    dut = tb.dut
    result_path = SIM_BUILD / "stream_sparse_result.json"

    with managed_peer("stream-recv", PORT_NUM, result_path) as peer:
        await tb.reset()

        await with_timeout(
            tb.source.send(AxiStreamFrame(
                tdata=bytes(range(8)),
                tkeep=[0, 0, 0, 0, 0, 0, 0, 1],
            )),
            COCOTB_TIMEOUT_US,
            "us",
        )
        await with_timeout(tb.source.wait(), COCOTB_TIMEOUT_US, "us")
        await _wait_for_peer(dut, peer)

        observed = peer.read_result()
        assert len(observed["received"]) == 1
        assert len(observed["received"][0]["data_hex"]) // 2 == 1


async def _run_pacing(tb):
    dut = tb.dut
    result_path = SIM_BUILD / "stream_pacing_result.json"

    with managed_peer("stream-recv", PORT_NUM, result_path) as peer:
        await tb.reset()
        transfer_cycles = []

        async def monitor_transfers():
            cycle = 0
            while len(transfer_cycles) < 3:
                await RisingEdge(dut.axisClk)
                cycle += 1
                if int(dut.S_AXIS_TVALID.value) and int(dut.S_AXIS_TREADY.value):
                    transfer_cycles.append(cycle)

        monitor = cocotb.start_soon(monitor_transfers())
        await with_timeout(
            tb.source.send(AxiStreamFrame(bytes(range(24)))),
            COCOTB_TIMEOUT_US,
            "us",
        )
        await with_timeout(tb.source.wait(), COCOTB_TIMEOUT_US, "us")
        await with_timeout(monitor, COCOTB_TIMEOUT_US, "us")

        assert [b - a for a, b in zip(transfer_cycles, transfer_cycles[1:])] == [2, 2]
        await _wait_for_peer(dut, peer)
        observed = peer.read_result()
        assert observed["received"][0]["data_hex"] == bytes(range(24)).hex()


async def _run_elaboration_only(tb):
    # The channelMap overflow is an elaboration-time array-bounds error, so
    # simply reaching a running simulation (clock plus a reset) proves the
    # CHAN_MAP_C constant was built within bounds for this CHAN_COUNT_G. No peer
    # or traffic is needed, which also keeps the multi-core case free of the
    # asynchronous-connect races the single-channel round-trip cases guard for.
    await tb.reset()
    await tb.cycle(RST_EDGES)


@cocotb.test()
async def stream_wrapper_test(dut):
    tb = TB(dut)
    if CASE.get("chan_count", 1) != 1:
        await _run_elaboration_only(tb)
        return
    await _run_round_trip(tb)
    await _run_sparse_tkeep(tb)
    if CASE["paced"]:
        await _run_pacing(tb)


@pytest.mark.parametrize("case_name", CASES)
def test_RogueTcpStreamWrap(case_name):
    case = CASES[case_name]
    sim_build = sim_build_dir("ghdl", case["build_name"])
    parameters = {
        "PORT_NUM_G": case["port"],
        "DATA_BYTES_G": case["data_bytes"],
    }
    if case.get("chan_count", 1) != 1:
        parameters["CHAN_COUNT_G"] = case["chan_count"]
    if case["paced"]:
        parameters.update({
            "AXIS_CLK_FREQ_HZ_G": 100_000_000,
            "S_AXIS_PAYLOAD_RATE_KBPS_G": 3_200_000,
            "M_AXIS_PAYLOAD_RATE_KBPS_G": 3_200_000,
        })

    run_simlink_surf_test(
        test_file=__file__,
        toplevel="surf.roguetcpstreamflatharness",
        sim_build=sim_build,
        parameters=parameters,
        extra_env={
            "SIMLINK_CASE": case_name,
            "SIMLINK_PORT": case["port"],
            "SIMLINK_SIM_BUILD": sim_build,
        },
        extra_vhdl_sources={
            "surf": ["simlink/test/common/RogueTcpStreamFlatHarness.vhd"],
        },
    )


def test_RogueTcpStream_max_frame_sparse_tail():
    SIM_BUILD.mkdir(parents=True, exist_ok=True)

    cflags = subprocess.run(
        ["pkg-config", "--cflags", "libzmq"], check=True, capture_output=True, text=True
    ).stdout.split()
    libs = subprocess.run(
        ["pkg-config", "--libs", "libzmq"], check=True, capture_output=True, text=True
    ).stdout.split()

    subprocess.run(
        [
            "gcc", "-Wall", "-g", "-pthread",
            f"-I{GHDL_DIR}", f"-I{SHARED_DIR}", *cflags,
            str(HERE / "stream_max_frame_harness.c"),
            str(SHARED_DIR / "RogueSimLinkTransport.c"),
            str(SHARED_DIR / "RogueTcpStreamCore.c"),
            "-o", str(STREAM_BOUNDARY_HARNESS), *libs,
        ],
        check=True,
    )
    subprocess.run([str(STREAM_BOUNDARY_HARNESS)], check=True)
