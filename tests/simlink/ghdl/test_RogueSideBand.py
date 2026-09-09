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
# - Sweep: None -- one centrally allocated ZMQ port pair is used; this is an
#   elaboration/bind smoke test, not a swept regression.
# - Stimulus: Drive portNum to a fixed non-zero value and hold the tx*
#   inputs at benign defaults, pulse reset for a couple of edges, then
#   release it so the first post-reset edge latches the port and the
#   GHDL-hosted C model calls RogueSideBandStartTransport (binds ZMQ PULL on
#   port+1, PUSH on port). No external peer is spawned.
# - Checks: The design must elaborate under GHDL, the VHPIDIRECT foreign
#   symbols (create, rogueSideBandUpdate, and the handle-based getters) resolve
#   against the staged libRogueSimLinkVhpiDirect.so, and the C's no-data Recv path
#   must run for a bounded number of edges without raising/hanging. The
#   getter-driven outputs (rxOpCode, rxOpCodeEn, rxRemData) must resolve to
#   driven values, confirming the foreign call actually ran rather than
#   leaving the ports undriven.
# - Timing: No fixed timing contract -- the bench loops RisingEdge(clock) a
#   bounded number of times with no peer connection to wait on.
#
# Proves elaborate + foreign-symbol resolve + ZMQ bind for RogueSideBand.
# Does NOT send/receive a ZMQ frame or assert marshalled data values -- a
# full Rogue round trip is out of scope for this smoke test.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tests.simlink.ghdl.simlink_test_utils import run_simlink_ghdl_test
from tests.simlink.paths import GHDL_SOURCE_DIR, sim_build_dir
from tests.simlink.ports import GHDL_CASES

GHDL_DIR = GHDL_SOURCE_DIR

CLK_PERIOD_NS = 10
RST_EDGES = 2
RUN_EDGES = 50
PORT_NUM = GHDL_CASES.port_pair(5).first


@cocotb.test()
async def rogue_side_band_smoke_test(dut):
    cocotb.start_soon(Clock(dut.clock, CLK_PERIOD_NS, unit="ns").start())

    # Benign defaults; no external peer, so no data ever moves.
    dut.portNum.value = PORT_NUM
    dut.txOpCode.value = 0
    dut.txOpCodeEn.value = 0
    dut.txRemData.value = 0

    # Reset phase, then release so the first post-reset edge latches the
    # port and RogueSideBandStartTransport binds the ZMQ sockets.
    dut.reset.value = 1
    for _ in range(RST_EDGES):
        await RisingEdge(dut.clock)
    dut.reset.value = 0

    for _ in range(RUN_EDGES):
        await RisingEdge(dut.clock)

    # Confirm the foreign getters actually ran and drove resolved values
    # (not left floating/undriven) -- proof the VHPIDIRECT bind worked.
    assert int(dut.rxOpCodeEn.value) in (0, 1), "rxOpCodeEn did not resolve to a driven value"
    assert 0 <= int(dut.rxOpCode.value) <= 0xFF, "rxOpCode did not resolve to a driven value"
    assert 0 <= int(dut.rxRemData.value) <= 0xFF, "rxRemData did not resolve to a driven value"


def test_rogue_side_band_smoke():
    sim_build = sim_build_dir("ghdl", "RogueSideBand")
    run_simlink_ghdl_test(
        test_file=__file__,
        toplevel="roguesideband",
        vhdl_sources=[str(GHDL_DIR / "RogueSideBand.vhd")],
        sim_build=sim_build,
    )
