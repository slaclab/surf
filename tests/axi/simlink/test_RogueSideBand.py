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
# - Sweep: None -- a single fixed ZMQ port (9610/9611) is used; this is an
#   elaboration/bind smoke test, not a swept regression.
# - Stimulus: Drive portNum to a fixed non-zero value and hold the tx*
#   inputs at benign defaults, pulse reset for a couple of edges, then
#   release it so the first post-reset edge latches the port and the
#   GHDL-hosted C model calls RogueSideBandRestart (binds ZMQ PULL on
#   port+1, PUSH on port). No external peer is spawned.
# - Checks: The design must elaborate under GHDL, the VHPIDIRECT foreign
#   symbols (rogueSideBandUpdate + the zero-arg getters) must resolve
#   against the staged libRogueSideBand.so, and the C's no-data Recv path
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

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb_test.simulator import run

from tests.axi.simlink.simlink_test_utils import build_and_stage_so
from tests.common.regression_utils import cocotb_module_name_from_test_file

GHDL_DIR = Path(__file__).resolve().parents[3] / "axi" / "simlink" / "ghdl"

CLK_PERIOD_NS = 10
RST_EDGES = 2
RUN_EDGES = 50
PORT_NUM = 9610


@cocotb.test()
async def rogue_side_band_smoke_test(dut):
    cocotb.start_soon(Clock(dut.clock, CLK_PERIOD_NS, unit="ns").start())

    # Benign defaults; no external peer, so no data ever moves.
    dut.portNum.value = PORT_NUM
    dut.txOpCode.value = 0
    dut.txOpCodeEn.value = 0
    dut.txRemData.value = 0

    # Reset phase, then release so the first post-reset edge latches the
    # port and RogueSideBandRestart binds the ZMQ sockets.
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
    sim_build = Path(__file__).resolve().parent / "sim_build_RogueSideBand"
    build_and_stage_so(GHDL_DIR, "libRogueSideBand.so", sim_build)

    run(
        module=cocotb_module_name_from_test_file(Path(__file__)),
        # GHDL folds VHDL identifiers to lower case internally (VHDL is
        # case-insensitive); the VPI root handle cocotb looks up is always
        # reported lower-case regardless of the case passed on the ghdl
        # command line, so COCOTB_TOPLEVEL (sourced from this toplevel=
        # kwarg) must match that lower-case form or root-handle lookup
        # fails.
        toplevel="roguesideband",
        toplevel_lang="vhdl",
        vhdl_sources=[str(GHDL_DIR / "RogueSideBand.vhd")],
        sim_build=str(sim_build),
        simulator="ghdl",
        vhdl_compile_args=["--std=08", "-fsynopsys"],
        # LD_LIBRARY_PATH only -- never -Wl,/-W-prefixed tokens in
        # extra_args/compile_args/vhdl_compile_args (ghdl -i rejects them).
        extra_env={"LD_LIBRARY_PATH": str(GHDL_DIR / "build")},
    )
