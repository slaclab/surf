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
# - Sweep: None -- one centrally allocated ZMQ port pair; this is a
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

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tests.simlink.common.peer_orchestration import managed_peer
from tests.simlink.common.simlink_protocol import (
    SIDEBAND_RX_OPCODE,
    SIDEBAND_RX_REMDATA,
    SIDEBAND_TX_OPCODE,
    SIDEBAND_TX_REMDATA,
)
from tests.simlink.ghdl.simlink_test_utils import run_simlink_surf_test
from tests.simlink.paths import (
    sim_build_dir,
)
from tests.simlink.ports import GHDL_CASES

SIM_BUILD = sim_build_dir("ghdl", "RogueSideBandWrap")
CLK_PERIOD_NS = 10
RST_EDGES = 2
GAP_EDGES = 5
MAX_EDGES = 5000
PORT_NUM = GHDL_CASES.port_pair(6).first


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
    with managed_peer("sideband", PORT_NUM, result_path) as peer:
        # Pulse reset for a couple of edges, then release it so the DUT's
        # first post-reset edge latches the port and the GHDL-hosted C model
        # calls RogueSideBandStartTransport (binds ZMQ PULL/PUSH sockets).
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
        observed = peer.read_result()
        assert any(f["opCodeEn"] == 1 and f["opCode"] == SIDEBAND_TX_OPCODE for f in observed["received"])
        assert any(f["remDataChanged"] == 1 and f["remData"] == SIDEBAND_TX_REMDATA for f in observed["received"])


def test_RogueSideBandWrap():
    run_simlink_surf_test(
        test_file=__file__,
        toplevel="surf.roguesidebandflatharness",
        sim_build=SIM_BUILD,
        parameters={"PORT_NUM_G": PORT_NUM},
        extra_vhdl_sources={
            "surf": ["simlink/test/common/RogueSideBandFlatHarness.vhd"],
        },
    )
