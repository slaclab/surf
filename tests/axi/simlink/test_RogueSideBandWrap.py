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
# - Sweep: None -- a single fixed ZMQ port pair (9612/9613); this is a
#   round-trip regression, not a swept parameter matrix.
# - Stimulus: Spawn rogue_tcp_peer.py (--mode sideband) as a separate OS
#   process before releasing reset, so the C model's first post-reset edge
#   binds its ZMQ sockets while the peer is already connecting. The peer
#   pushes an opcode frame (SIDEBAND_PEER_TO_DUT) that the DUT surfaces on
#   rx*; the cocotb bench drives a txOpCodeEn strobe (SIDEBAND_TX_OPCODE)
#   and a txRemData change (SIDEBAND_TX_REMDATA) that the DUT transmits back
#   over ZMQ for the peer to verify.
# - Checks: The DUT's rx* outputs must latch the peer's opcode/remData
#   (peer -> ZMQ -> DUT); the peer must observe the DUT's transmitted opcode
#   and remData (tx* -> DUT -> ZMQ -> peer) and exit 0.
# - Timing: No fixed timing contract -- the bench loops RisingEdge(sysClk)
#   up to a bounded edge count, breaking early once the peer process exits.
#   A `finally:` block terminates the peer on every path (including an
#   assertion failure) so nothing leaks across the xdist worker pool.
#
# Exercises the side-band round trip in both directions and the
# separate-process Rogue-TCP peer protocol for RogueSideBandWrap.

import json
from pathlib import Path
import subprocess
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tests.axi.simlink.rogue_tcp_peer import (
    SIDEBAND_RX_OPCODE,
    SIDEBAND_RX_REMDATA,
    SIDEBAND_TX_OPCODE,
    SIDEBAND_TX_REMDATA,
)
from tests.axi.simlink.simlink_test_utils import build_and_stage_so
from tests.common.regression_utils import run_surf_vhdl_test

HERE = Path(__file__).resolve().parent
GHDL_DIR = Path(__file__).resolve().parents[3] / "axi" / "simlink" / "ghdl"
SIM_BUILD = HERE / "sim_build_RogueSideBandWrap"

CLK_PERIOD_NS = 10
RST_EDGES = 2
GAP_EDGES = 5
MAX_EDGES = 5000
PORT_NUM = 9612


@cocotb.test()
async def side_band_round_trip_test(dut):
    cocotb.start_soon(Clock(dut.sysClk, CLK_PERIOD_NS, unit="ns").start())
    result_path = SIM_BUILD / "sideband_peer_result.json"

    dut.sysRst.setimmediatevalue(1)
    dut.txOpCode.setimmediatevalue(0)
    dut.txOpCodeEn.setimmediatevalue(0)
    dut.txRemData.setimmediatevalue(0)

    # Spawn the peer as a genuinely separate OS process before releasing
    # reset -- a blocking pyzmq call inside this coroutine would deadlock the
    # shared GHDL/cocotb thread.
    peer = subprocess.Popen(
        [sys.executable, str(HERE / "rogue_tcp_peer.py"), "--mode", "sideband", str(PORT_NUM), str(result_path)]
    )

    try:
        # Pulse reset for a couple of edges, then release it so the DUT's
        # first post-reset edge latches the port and the GHDL-hosted C model
        # calls RogueSideBandRestart (binds ZMQ PULL/PUSH sockets).
        dut.sysRst.value = 1
        for _ in range(RST_EDGES):
            await RisingEdge(dut.sysClk)
        dut.sysRst.value = 0
        for _ in range(RST_EDGES):
            await RisingEdge(dut.sysClk)

        # DUT -> peer: a one-cycle opcode strobe, then (after a gap so the two
        # sends are distinct edges) a remData change.
        dut.txOpCode.value = SIDEBAND_TX_OPCODE
        dut.txOpCodeEn.value = 1
        await RisingEdge(dut.sysClk)
        dut.txOpCodeEn.value = 0
        dut.txOpCode.value = 0
        for _ in range(GAP_EDGES):
            await RisingEdge(dut.sysClk)
        dut.txRemData.value = SIDEBAND_TX_REMDATA

        # Await the round trip: loop clock edges (each edge polls the C
        # model's ZMQ sockets) until the peer process exits or the bound is
        # hit.
        for _ in range(MAX_EDGES):
            await RisingEdge(dut.sysClk)
            if peer.poll() is not None:
                break
        else:
            raise TimeoutError(f"peer process did not exit within {MAX_EDGES} clock edges")

        assert peer.returncode == 0, f"peer exited with code {peer.returncode}"

        # rx* must latch the opcode/remData the peer pushed in.
        assert int(dut.rxOpCode.value) == SIDEBAND_RX_OPCODE, "rxOpCode did not latch the peer's opcode"
        assert int(dut.rxRemData.value) == SIDEBAND_RX_REMDATA, "rxRemData did not latch the peer's remData"

        # The peer's diagnostics must show it received the DUT's tx opcode and
        # remData (peer already gates its exit code on this, checked above).
        observed = json.loads(result_path.read_text())
        assert any(f["opCodeEn"] == 1 and f["opCode"] == SIDEBAND_TX_OPCODE for f in observed["received"])
        assert any(f["remDataChanged"] == 1 and f["remData"] == SIDEBAND_TX_REMDATA for f in observed["received"])
    finally:
        if peer.poll() is None:
            peer.terminate()
            peer.wait(timeout=5)


def test_RogueSideBandWrap():
    build_and_stage_so(GHDL_DIR, "libRogueSideBand.so", SIM_BUILD)

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.roguesidebandwrapflatwrapper",
        parameters={"PORT_NUM_G": PORT_NUM},
        extra_env={"LD_LIBRARY_PATH": str(GHDL_DIR / "build")},
        extra_vhdl_sources={
            "surf": ["axi/simlink/wrappers/RogueSideBandWrapFlatWrapper.vhd"],
        },
        sim_build_key=str(SIM_BUILD),
    )
