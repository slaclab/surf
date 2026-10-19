#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: pinned pre-timing RTL versus current default-mode RTL, side by side.
#   GMII/XGMII/XLGMII, filter/bypass/error-drop/jumbo both ways, common/async
#   primary and bypass clocks, plus the GMII exporter without a TX FIFO and
#   enable divisors 1/10/100. Baseline sources are renamed at run time.
# - Stimulus: seeded, framed primary/bypass transfers with stable stalled beats;
#   independent RX with both XGMII start lanes, bad FCS and GMII RX_ER; sink
#   stalls, mid-traffic reset and link changes. Leaf sources also starve the
#   exporter mid-frame. All traffic/control tasks have fixed cycle bounds.
# - Checks: every original top output bit, including invalid AXI cycles,
#   PHY pins, status and input-ready, before and after TPD on each clock domain.
#   Accepted traffic and wire activity counters prevent a vacuous comparison.
#   This proves compatibility for recorded stimuli, not correctness of retained
#   baseline defects or equivalence for all possible inputs.
# - Timing: inputs change on falling edges. Comparison monitors are test-owned
#   lifetime agents, sampled before sequential updates and after TPD_G=1 ns,
#   and cancelled/joined at completion. Clock enable gates the GMII RX symbols.

from collections import deque
import hashlib
import os
from pathlib import Path
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import pytest

from tests.common.regression_utils import (
    cancel_and_join_tasks,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    sample_after_tpd,
    start_lockstep_clocks,
)
from tests.ethernet.EthMacCore.ethmac_compatibility import compatibility_sources
from tests.ethernet.EthMacCore.ethmac_line_models import (
    GMII_IDLE, gmii_symbols, random_frame, xgmii_words,
)
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES, FlatEmacEndpoint, frame_beats_from_bytes,
)


class CompatibilityBench:
    def __init__(self, dut):
        self.dut = dut
        self.leaf = os.environ.get("LEAF", "0") == "1"
        self.phy = os.environ["PHY_TYPE_G"]
        self.seed = int(os.environ.get("SEED", "467"))
        self.divisor = int(os.environ.get("ENABLE_DIVISOR", "1"))
        self.cycles = 6000 if self.divisor == 1 else 240 * self.divisor
        self.tasks = []
        self.checks = 0
        self.accepted = 0
        self.tx_active = 0
        self.rx_active = 0
        self.mismatch = None

    def set(self, name, value):
        if hasattr(self.dut, name):
            getattr(self.dut, name).value = value

    async def start(self):
        for name, value in {
            "ethClk": 0, "primClk": 0, "bypClk": 0,
            "ethRst": 1, "primRst": 1, "bypRst": 1, "ethClkEn": 1,
            "phyReady": 1, "txPhyReady": 1, "rxPhyReady": 1,
            "gmiiRxDv": 0, "gmiiRxEr": 0, "gmiiRxd": 0,
            "xgmiiRxd": 0x0707070707070707, "xgmiiRxc": 0xff,
            "xlgmiiRxd": 0, "xlgmiiRxc": 0,
            "mAxisTReady": 1, "mBypTReady": 1,
            "localMac": 0x060504030201, "filtEnable": 1,
            "pauseEnable": 1, "pauseTime": 8, "pauseThresh": 256,
            "ipCsumEn": 0, "tcpCsumEn": 0, "udpCsumEn": 0, "dropOnPause": 0,
        }.items():
            self.set(name, value)
        FlatEmacEndpoint(self.dut, prefix="sAxis").set_idle()
        if not self.leaf:
            FlatEmacEndpoint(self.dut, prefix="sByp").set_idle()
        common = [self.dut.ethClk]
        clocks = [self.dut.ethClk]
        if not self.leaf:
            for prefix, period in (("prim", 9.2), ("byp", 11.6)):
                clock = getattr(self.dut, prefix + "Clk")
                clocks.append(clock)
                if os.environ.get(prefix.upper() + "_COMMON_CLK_G", "false").lower() == "true":
                    common.append(clock)
                else:
                    self.tasks.append(cocotb.start_soon(Clock(clock, period, unit="ns").start()))
        self.tasks.append(start_lockstep_clocks(*common, period_ns=8.0))
        for _ in range(16):
            await sample_after_tpd(self.dut.ethClk)
        for clock in clocks:
            self.tasks.append(cocotb.start_soon(self.compare(clock)))
        await FallingEdge(self.dut.ethClk)
        for name in ("ethRst", "primRst", "bypRst"):
            self.set(name, 0)

    def check(self, clock):
        actual = str(self.dut.actualObservation.value)
        expected = str(self.dut.baselineObservation.value)
        if actual != expected:
            self.mismatch = self.mismatch or (
                f"seed={self.seed} phy={self.phy} leaf={self.leaf} clock={clock._name} "
                f"sample={self.checks} differing bits="
                f"{[len(actual)-i-1 for i, (a, b) in enumerate(zip(actual, expected, strict=True)) if a != b][:32]}"
            )
            return False
        self.checks += 1
        return True

    async def compare(self, clock):
        """Lifetime agent: compare both designs until the bench cancels it."""
        while True:
            await RisingEdge(clock)
            if not self.check(clock):
                return
            # Propagation sampling: compare registered outputs after TPD_G=1 ns.
            await Timer(1.1, unit="ns")
            if not self.check(clock):
                return

    async def source(self, prefix, clock, salt):
        rng = random.Random(self.seed + salt)
        endpoint = FlatEmacEndpoint(self.dut, prefix=prefix)
        beats = deque()
        pending = None
        frames = 0
        for cycle in range(self.cycles):
            if self.mismatch is not None:
                break
            await FallingEdge(clock)
            if int(self.dut.ethRst.value):
                beats.clear()
                pending = None
                endpoint.set_idle()
            elif pending is None:
                if not beats:
                    lengths = [60, 61, 127, 1518]
                    if os.environ.get("JUMBO_G", "true").lower() == "true" and self.phy == "XGMII":
                        lengths.append(9000)
                    length = lengths[frames % len(lengths)]
                    frame = random_frame(rng, length, dst_mac=0x010203040506,
                                         eth_type=0x9000 if frames % 2 else 0x88b5)
                    beats.extend(frame_beats_from_bytes(frame, eofe=int(frames % 5 == 4)))
                    frames += 1
                # A leaf has no whole-frame TX FIFO, so these long gaps force
                # underrun at several positions. A held beat is never withdrawn.
                starve = self.leaf and 200 < cycle % 700 < 300
                if not starve and rng.random() < 0.85:
                    pending = beats.popleft()
                    endpoint.drive(pending)
                else:
                    endpoint.set_idle()
            await RisingEdge(clock)
            if pending is not None and int(endpoint._sig("TReady").value):
                self.accepted += 1
                pending = None
        await FallingEdge(clock)
        endpoint.set_idle()

    async def receive_and_control(self):
        rng = random.Random(self.seed + 100)
        incoming = deque()
        frames = 0
        for cycle in range(self.cycles):
            if self.mismatch is not None:
                break
            await FallingEdge(self.dut.ethClk)
            enable = int(cycle % self.divisor == 0)
            self.dut.ethClkEn.value = enable
            # Include a mid-traffic reset and bounded link interruptions.
            reset = int(cycle in range(self.cycles // 2, self.cycles // 2 + 16))
            link = int(not (cycle % 1300 in range(900, 932)))
            for name in ("ethRst", "primRst", "bypRst"):
                self.set(name, reset)
            for name in ("phyReady", "txPhyReady", "rxPhyReady"):
                self.set(name, link)
            self.set("mAxisTReady", int(rng.random() > 0.3))
            self.set("mBypTReady", int(rng.random() > 0.45))
            if not incoming:
                length = (60, 65, 127, 1518)[frames % 4]
                frame = random_frame(rng, length, dst_mac=0x010203040506,
                                     eth_type=0x9000 if frames % 2 else 0x88b5)
                if self.phy == "GMII":
                    incoming.extend(gmii_symbols(frame, bad_fcs=frames % 5 == 2,
                                                 er_at=25 if frames % 5 == 3 else None))
                else:
                    incoming.extend(xgmii_words(frame, start_lane=4 * (frames % 2), bad_fcs=frames % 5 == 2))
                frames += 1
            if self.phy == "GMII":
                symbol = incoming[0] if incoming else GMII_IDLE
                self.dut.gmiiRxDv.value = symbol.dv
                self.dut.gmiiRxEr.value = symbol.er
                self.dut.gmiiRxd.value = symbol.d
                if enable:
                    incoming.popleft()
            else:
                data, control = incoming.popleft()
                self.dut.xgmiiRxd.value = data
                self.dut.xgmiiRxc.value = control
            await RisingEdge(self.dut.ethClk)
            self.tx_active += int(self.dut.gmiiTxEn.value) if self.phy == "GMII" else int(int(self.dut.xgmiiTxc.value) != 0xff)
            self.rx_active += int(self.dut.mAxisTValid.value)
        await FallingEdge(self.dut.ethClk)
        self.set("gmiiRxDv", 0)
        self.set("gmiiRxEr", 0)
        self.set("xgmiiRxd", 0x0707070707070707)
        self.set("xgmiiRxc", 0xff)
        self.set("mAxisTReady", 1)
        self.set("mBypTReady", 1)
        self.dut.ethClkEn.value = 1


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def default_mode_matches_baseline(dut):
    bench = CompatibilityBench(dut)
    await bench.start()
    producers = [cocotb.start_soon(bench.source("sAxis", dut.ethClk if bench.leaf else dut.primClk, 1)),
                 cocotb.start_soon(bench.receive_and_control())]
    if not bench.leaf:
        producers.append(cocotb.start_soon(bench.source("sByp", dut.bypClk, 2)))
    try:
        for task in producers:
            await task
        assert bench.mismatch is None, bench.mismatch
        for _ in range(128):
            await sample_after_tpd(dut.ethClk)
        assert bench.mismatch is None, bench.mismatch
        assert bench.checks >= bench.cycles * 2
        assert bench.accepted >= 4
        if bench.phy != "XLGMII":
            assert bench.tx_active > 0, "No physical TX activity reached the comparator"
        dut._log.info("COMPATIBILITY seed=%d phy=%s leaf=%s cycles=%d comparisons=%d accepted=%d tx_active=%d rx_active=%d",
                      bench.seed, bench.phy, bench.leaf, bench.cycles, bench.checks,
                      bench.accepted, bench.tx_active, bench.rx_active)
    finally:
        await cancel_and_join_tasks([*producers, *bench.tasks])


TOP_CASES = [
    parameter_case("gmii_defaults", PHY_TYPE_G="GMII", SEED=467),
    parameter_case("gmii_modes", PHY_TYPE_G="GMII", SEED=468, FILT_EN_G=True, BYP_EN_G=True,
                   BYP_ETH_TYPE_G=0x0090, DROP_ERR_PKT_G=False, JUMBO_G=False, PRIM_COMMON_CLK_G=True, BYP_COMMON_CLK_G=True),
    parameter_case("gmii_clk_enable", PHY_TYPE_G="GMII", SEED=469, ENABLE_DIVISOR=10),
    parameter_case("xgmii_defaults", PHY_TYPE_G="XGMII", SEED=470),
    parameter_case("xgmii_modes", PHY_TYPE_G="XGMII", SEED=471, FILT_EN_G=True, BYP_EN_G=True,
                   BYP_ETH_TYPE_G=0x0090, DROP_ERR_PKT_G=False, JUMBO_G=False),
    parameter_case("xgmii_common", PHY_TYPE_G="XGMII", SEED=472, PRIM_COMMON_CLK_G=True, JUMBO_G=False),
    parameter_case("xlgmii_placeholder", PHY_TYPE_G="XLGMII", SEED=473),
]


@pytest.mark.skipif(os.environ.get("RUN_ETHMAC_COMPATIBILITY_TESTS") != "1",
                    reason="pinned-history comparison; set RUN_ETHMAC_COMPATIBILITY_TESTS=1")
@pytest.mark.parametrize("parameters", TOP_CASES)
def test_EthMacCompatibility(parameters):
    key = hashlib.sha256(repr(sorted(parameters.items())).encode()).hexdigest()[:16]
    generated = Path(__file__).resolve().parents[2] / "sim_build/ethmac_compatibility" / key
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.EthMacCompatibilityWrapper",
        parameters=hdl_parameters_from(parameters), extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + compatibility_sources(generated)},
    )


@pytest.mark.skipif(os.environ.get("RUN_ETHMAC_COMPATIBILITY_TESTS") != "1",
                    reason="pinned-history comparison; set RUN_ETHMAC_COMPATIBILITY_TESTS=1")
@pytest.mark.parametrize("divisor", [1, 10, 100])
def test_EthMacGmiiExporterCompatibility(divisor):
    generated = Path(__file__).resolve().parents[2] / f"sim_build/ethmac_compatibility/leaf-{divisor}"
    parameters = {"PHY_TYPE_G": "GMII", "LEAF": 1, "SEED": 600 + divisor, "ENABLE_DIVISOR": divisor}
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.EthMacLeafCompatibilityWrapper",
        parameters=hdl_parameters_from(parameters), extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + compatibility_sources(generated, leaf=True)},
    )
