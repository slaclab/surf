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
# - Sweep: None -- a single fixed ZMQ port pair (9604/9605); this is a
#   round-trip regression, not a swept parameter matrix.
# - Stimulus: Spawn rogue_tcp_peer.py (--mode stream) as a separate OS
#   process before releasing reset, so the C model's first post-reset edge
#   binds its ZMQ sockets while the peer is already connecting. The peer
#   unconditionally pushes its own fixed frames (STREAM_SEND_FRAMES) into
#   the DUT over ZMQ; the cocotb AxiStreamSource on S_AXIS drives the frames
#   the peer expects the DUT to send back out over ZMQ (STREAM_EXPECT_FRAMES).
#   Both vectors are well-formed (contiguous data, proper lengths, no hand-
#   built sparse tKeep) so the green baseline stays clear of the
#   sparse-tKeep miscount.
# - Checks: The AxiStreamSink on M_AXIS must observe the peer's
#   STREAM_SEND_FRAMES payloads (peer -> ZMQ -> DUT -> M_AXIS); the peer's
#   JSON result file must show it received STREAM_EXPECT_FRAMES' payloads
#   back from the DUT (S_AXIS -> DUT -> ZMQ -> peer); the peer process must
#   exit 0.
# - Timing: No fixed timing contract -- the bench loops RisingEdge(axisClk)
#   up to a bounded edge count, breaking early once the peer process exits.
#   A `finally:` block terminates the peer on every path (including an
#   assertion failure) so nothing leaks across the xdist worker pool.
#
# Exercises the stream round trip in both directions, cocotbext.axi binding
# the flat wrapper's S_AXIS/M_AXIS scalar buses, and the separate-process
# Rogue-TCP peer protocol for RogueTcpStreamWrap. A standalone C harness also
# checks the MAX_FRAME boundary with trailing unkept lanes without simulating
# a 20 MB AXI Stream frame cycle by cycle.

import json
from pathlib import Path
import subprocess
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.axi.simlink.rogue_tcp_peer import STREAM_EXPECT_FRAMES, STREAM_SEND_FRAMES
from tests.axi.simlink.simlink_test_utils import build_and_stage_so
from tests.common.regression_utils import run_surf_vhdl_test

HERE = Path(__file__).resolve().parent
GHDL_DIR = Path(__file__).resolve().parents[3] / "axi" / "simlink" / "ghdl"
SHARED_DIR = Path(__file__).resolve().parents[3] / "axi" / "simlink" / "shared"
SIM_BUILD = HERE / "sim_build_RogueTcpStreamWrap"
STREAM_BOUNDARY_HARNESS = SIM_BUILD / "stream_max_frame_harness"

CLK_PERIOD_NS = 10
RST_EDGES = 2
MAX_EDGES = 5000
PORT_NUM = 9604


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
        # Pulse reset for a couple of edges, then release it so the DUT's
        # first post-reset edge latches the port and the GHDL-hosted C model
        # calls RogueTcpStreamRestart (binds ZMQ PULL/PUSH sockets).
        self.dut.axisRst.value = 1
        await self.cycle(RST_EDGES)
        self.dut.axisRst.value = 0
        await self.cycle(RST_EDGES)

    def start_agents(self):
        self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.axisClk, self.dut.axisRst)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)


async def _collect_frames(sink, count):
    return [await sink.recv() for _ in range(count)]


@cocotb.test()
async def stream_round_trip_test(dut):
    tb = TB(dut)
    result_path = SIM_BUILD / "stream_peer_result.json"

    # Spawn the peer as a genuinely separate OS process before releasing
    # reset -- a blocking pyzmq call inside this coroutine would deadlock
    # the shared GHDL/cocotb thread.
    peer = subprocess.Popen(
        [sys.executable, str(HERE / "rogue_tcp_peer.py"), "--mode", "stream", str(PORT_NUM), str(result_path)]
    )

    try:
        await tb.reset()
        tb.start_agents()

        # M_AXIS: frames the peer pushes into the DUT over ZMQ
        # (STREAM_SEND_FRAMES) -- collected independently of what we drive
        # below, since the two directions are separate ZMQ flows.
        recv_task = cocotb.start_soon(_collect_frames(tb.sink, len(STREAM_SEND_FRAMES)))

        # S_AXIS: the frames the peer expects the DUT to send it back out
        # over ZMQ (STREAM_EXPECT_FRAMES) -- let cocotbext.axi derive
        # contiguous tKeep/tLast from the frame length (never a
        # hand-built sparse tKeep).
        for frame in STREAM_EXPECT_FRAMES:
            await tb.source.send(AxiStreamFrame(frame["data"]))
        await tb.source.wait()

        # Await the round trip: loop clock edges (each edge polls the C
        # model's ZMQ sockets) until the peer process exits or the bound is
        # hit.
        for _ in range(MAX_EDGES):
            await RisingEdge(dut.axisClk)
            if peer.poll() is not None:
                break
        else:
            raise TimeoutError(f"peer process did not exit within {MAX_EDGES} clock edges")

        assert peer.returncode == 0, f"peer exited with code {peer.returncode}"

        rx_frames = await recv_task
        assert len(rx_frames) == len(STREAM_SEND_FRAMES)
        for rx_frame, expected in zip(rx_frames, STREAM_SEND_FRAMES):
            assert bytes(rx_frame.tdata) == expected["data"]

        observed = json.loads(result_path.read_text())
        assert len(observed["received"]) == len(STREAM_EXPECT_FRAMES)
        for decoded, expected in zip(observed["received"], STREAM_EXPECT_FRAMES):
            assert decoded["data_hex"] == expected["data"].hex()
    finally:
        if peer.poll() is None:
            peer.terminate()
            peer.wait(timeout=5)


@cocotb.test()
async def stream_sparse_tkeep_test(dut):
    # Reproduces the sparse-tKeep miscount: RogueTcpStream.c's per-lane keep test used
    # `(keep >> x) && 1`, which is truthy for every lane at or below the
    # highest set bit, not just the lanes whose bit is actually set. A
    # single 8-lane beat with only the top lane kept drives that
    # distinction cleanly -- correct behavior forwards 1 byte, the bug
    # forwards 8.
    tb = TB(dut)
    result_path = SIM_BUILD / "stream_sparse_result.json"

    # Same PORT_NUM=9604 as stream_round_trip_test -- no new port needed,
    # since cocotb tears down the prior test's clock/coroutines between
    # @cocotb.test() functions in the same simulation node.
    peer = subprocess.Popen(
        [sys.executable, str(HERE / "rogue_tcp_peer.py"), "--mode", "stream-recv", str(PORT_NUM), str(result_path)]
    )

    try:
        await tb.reset()
        tb.start_agents()

        # Non-contiguous tKeep: only the highest lane (byte 7) is kept.
        await tb.source.send(AxiStreamFrame(tdata=bytes(range(8)), tkeep=[0, 0, 0, 0, 0, 0, 0, 1]))
        await tb.source.wait()

        for _ in range(MAX_EDGES):
            await RisingEdge(dut.axisClk)
            if peer.poll() is not None:
                break
        else:
            raise TimeoutError(f"peer process did not exit within {MAX_EDGES} clock edges")

        assert peer.returncode == 0, f"peer exited with code {peer.returncode}"

        observed = json.loads(result_path.read_text())
        assert len(observed["received"]) == 1
        assert len(observed["received"][0]["data_hex"]) // 2 == 1
    finally:
        if peer.poll() is None:
            peer.terminate()
            peer.wait(timeout=5)


def test_RogueTcpStreamWrap():
    build_and_stage_so(GHDL_DIR, "libRogueTcpStream.so", SIM_BUILD)

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.roguetcpstreamwrapflatwrapper",
        parameters={"PORT_NUM_G": PORT_NUM},
        extra_env={"LD_LIBRARY_PATH": str(GHDL_DIR / "build")},
        extra_vhdl_sources={
            "surf": ["axi/simlink/wrappers/RogueTcpStreamWrapFlatWrapper.vhd"],
        },
        sim_build_key=str(SIM_BUILD),
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
            "gcc", "-Wall", "-g", f"-I{GHDL_DIR}", f"-I{SHARED_DIR}", *cflags,
            str(HERE / "stream_max_frame_harness.c"),
            "-o", str(STREAM_BOUNDARY_HARNESS), *libs,
        ],
        check=True,
    )
    subprocess.run([str(STREAM_BOUNDARY_HARNESS)], check=True)
