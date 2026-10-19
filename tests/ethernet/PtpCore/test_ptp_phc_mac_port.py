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
# - Sweep: The real PtpPhcCore driving PtpMacPortEthMac and both passive
#   adapter oracles, GMII at 125 MHz and XGMII at 156.25 MHz.
# - Stimulus: AXI commits the external owner with monotonic policy off; the
#   external command port then places RATE, SET, PHASE and VALID commits at
#   exact cycles relative to a looped-back TX frame's pin cycle (two before
#   through two after, plus mid-frame for steps). Frames are also sent before
#   the clock is ever qualified.
# - Checks: Commits land on the scheduled edge. RATE never invalidates a
#   capture; port captures equal the oracles bit for bit. A SET/PHASE whose
#   admission or commit inhibition covers the pin cycle marks RX capture.error
#   and clears TX captureValid, as the oracle error does; a later step before
#   done invalidates TX and RX captures without changing the outcome. Every
#   request completes exactly once, SENT, never before its wire done. Captures
#   with timeValid = 0 are usable and match the oracles.
# - Timing: Observations carry the bench cycle; an oracle SOF seen at cycle j
#   was computed from the tuple of cycle j - 1.

from __future__ import annotations

import os

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES
from tests.ethernet.PtpCore.ptp_mac_port_test_utils import NS_PER_SECOND, Q32, PortBench, port_frame


WRAPPERS = ["ethernet/PtpCore/wrappers/PtpMacPortEthMacWrapper.vhd",
            "ethernet/PtpCore/wrappers/PtpPhcMacPortWrapper.vhd"]
PHY = os.environ.get("PHY_TYPE_G", "GMII")
KINDS = {"SET": 0, "PHASE": 1, "RATE": 2, "VALID": 3}
Q16 = 1 << 16


class CorePhc:
    """PortBench's PHC interface, backed by the real core's external port.

    advance() runs 1 ns after each edge, so cycle c is the tuple registered by
    edge c. A command scheduled for cycle C is presented after edge C-2,
    admitted by edge C-1 and committed by edge C.
    """

    def __init__(self, dut):
        self.dut = dut
        self.cycle = 0
        self.schedule: dict[int, str] = {}
        self.events: list[tuple[int, str]] = []
        self.inflight = None
        self.withdraw = None
        self.rate_steps = 0

    @property
    def generation(self) -> int:
        return int(self.dut.phcGeneration.value)

    def drive(self) -> None:
        pass  # The core drives the tuple.

    def present(self, kind: str) -> None:
        d = self.dut
        d.commandKind.value = KINDS[kind]
        d.commandGeneration.value = int(d.phcGeneration.value)
        d.commandValue.value = 1
        if kind == "SET":
            now = ((int(d.phcSeconds.value)*NS_PER_SECOND + int(d.phcNanoseconds.value)) << 32)
            target = now + 37*NS_PER_SECOND*Q32 + (12345 << 16)
            seconds, sub = divmod(target, NS_PER_SECOND*Q32)
            d.commandSeconds.value = seconds
            d.commandNanoseconds.value = sub >> 32
            d.commandFraction.value = sub & (Q32-1)
        elif kind == "PHASE":
            # -987654 ns: whole seconds zero, signed Q32 remainder.
            d.phaseSeconds.value = 0
            d.phaseFraction.value = (-987654*Q32) & ((1 << 64)-1)
        elif kind == "RATE":
            # Each RATE raises the applied addend by another 2**18 Q32 ns.
            self.rate_steps += 1
            d.commandRate.value = self.rate_steps << 18
        d.commandValid.value = 1

    def advance(self) -> None:
        self.cycle += 1
        if self.withdraw == self.cycle:
            self.dut.commandValid.value = 0
            self.withdraw = None
        kind = self.schedule.pop(self.cycle+2, None)
        if kind is not None:
            assert self.inflight is None, "overlapping scheduled commits"
            self.present(kind)
            self.inflight = kind
            self.withdraw = self.cycle+1

    async def watch(self) -> None:
        """Lifetime agent: record the edge on which each command committed."""
        d = self.dut
        while True:
            await RisingEdge(d.clk)
            await Timer(2, unit="ns")
            if int(d.statusAck.value):
                assert self.inflight is not None, "unexpected PHC commit"
                assert not int(d.commandError.value), f"{self.inflight} rejected"
                self.events.append((self.cycle, self.inflight))
                self.inflight = None


class CoreBench(PortBench):
    def __init__(self, dut):
        super().__init__(dut, phy=PHY)
        self.phc = CorePhc(dut)

    async def start(self) -> None:
        d = self.dut
        for name in ("commandValid", "commandKind", "commandGeneration", "commandSeconds",
                     "commandNanoseconds", "commandFraction", "phaseSeconds", "phaseFraction",
                     "commandRate", "commandValue"):
            getattr(d, name).setimmediatevalue(0)
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(d, "axil"), d.clk, d.rst, reset_active_level=True)
        await super().start(open_admission=False)
        cocotb.start_soon(self.phc.watch())
        # External owner, monotonic policy off, one local commit.
        await self.write(0x1004, 0)
        await self.write(0x004, 1)
        await self.write(0x03C, 1)
        for _ in range(50):
            if await self.read(0x044) & 1:
                break
        assert int(d.externalOwner.value)
        await self.open()

    async def write(self, offset, value):
        result = await self.axil.write(offset, value.to_bytes(4, "little"))
        assert result.resp == AxiResp.OKAY

    async def read(self, offset):
        result = await self.axil.read(offset, 4)
        assert result.resp == AxiResp.OKAY
        return int.from_bytes(result.data, "little")

    async def commit_now(self, kind: str) -> None:
        self.phc.schedule[self.phc.cycle + 4] = kind
        await self.wait_for(lambda: self.phc.inflight is None and not self.phc.schedule, what=kind)


async def bench_for(dut) -> CoreBench:
    bench = CoreBench(dut)
    await bench.start()
    return bench


async def send_and_settle(bench, frame, cookie):
    count = len(bench.obs.completions)
    rx = len(bench.obs.rx_frames)
    await bench.send(frame, cookie)
    await bench.wait_for(lambda: len(bench.obs.completions) > count, what=f"completion {cookie:#x}")
    await bench.wait_for(lambda: len(bench.obs.rx_frames) > rx, what="loopback delivery")
    await bench.edge(40)


def same_except_error(a, b) -> bool:
    return (a.timestamp, a.ticks, a.tick_phase, a.generation, a.increment, a.time_valid) == (
        b.timestamp, b.ticks, b.tick_phase, b.generation, b.increment, b.time_valid)


def wire_cycles(frame: bytes) -> int:
    # From the first destination octet (the pin cycle) through the FCS.
    octets = max(len(frame), 60) + 4
    return octets if PHY == "GMII" else octets // 8


@cocotb.test(timeout_time=3, timeout_unit="ms")
async def unqualified_captures_are_usable(dut):
    bench = await bench_for(dut)
    obs = bench.obs
    frame = port_frame(5, 90)
    assert not int(dut.phcTimeValid.value)
    for cookie in (0x10, 0x11, 0x12):
        tx_before = len(obs.tx_oracle)
        await send_and_settle(bench, frame, cookie)
        completion = obs.completions[-1][1]
        oracle = obs.tx_oracle[tx_before][1]
        rx = obs.rx_frames[-1]["meta"].capture
        assert completion.outcome == "SENT" and completion.capture_valid == 1
        assert completion.capture == oracle and oracle.time_valid == 0 and oracle.error == 0
        assert rx == oracle
    await bench.commit_now("VALID")
    tx_before = len(obs.tx_oracle)
    await send_and_settle(bench, frame, 0x13)
    assert obs.completions[-1][1].capture == obs.tx_oracle[tx_before][1]
    assert obs.tx_oracle[tx_before][1].time_valid == 1


@cocotb.test(timeout_time=6, timeout_unit="ms")
async def capture_alignment_at_core_commits(dut):
    bench = await bench_for(dut)
    obs = bench.obs
    frame = port_frame(3, 100)
    await bench.commit_now("VALID")

    # Calibrate the idle send-to-pin latency for this frame length.
    start = bench.phc.cycle
    await send_and_settle(bench, frame, 0x100)
    latency = obs.tx_oracle[0][0] - 1 - start

    mid = 50 if PHY == "GMII" else 6
    cases = [(kind, off) for kind in ("RATE", "SET", "PHASE") for off in (-2, -1, 0, 1, 2)]
    cases += [("SET", mid), ("PHASE", mid), ("RATE", mid)]
    results = []
    for index, (kind, off) in enumerate(cases):
        start = bench.phc.cycle
        bench.phc.schedule[start + latency + off] = kind
        tx_before = len(obs.tx_oracle)
        cookie = 0x200 + index
        await send_and_settle(bench, frame, cookie)
        tuple_cycle = obs.tx_oracle[tx_before][0] - 1
        commit_cycle = [c for c, k in bench.phc.events if k == kind][-1]
        assert commit_cycle - tuple_cycle == off, f"{kind}{off:+d} landed at {commit_cycle - tuple_cycle:+d}"
        done_cycle, completion = obs.completions[-1]
        results.append((kind, off, cookie, tuple_cycle, done_cycle, completion,
                        obs.tx_oracle[tx_before][1], obs.rx_frames[-1], bench.phc.generation))

    cookies = [completion.cookie for _, completion in obs.completions]
    assert len(cookies) == len(set(cookies)), "a request completed more than once"
    for kind, off, cookie, tuple_cycle, done_cycle, completion, oracle, rx, generation in results:
        name = f"{kind}{off:+d}"
        step = kind in ("SET", "PHASE")
        inhibited = step and off in (0, 1)  # admission/commit inhibition covers the pin
        invalid = step and off >= 0         # inhibited, or the generation changed before done
        assert completion.cookie == cookie and completion.outcome == "SENT", name
        # Ownership is released only by the terminal disposition after done.
        assert done_cycle >= tuple_cycle + wire_cycles(frame), f"{name}: completed before wire done"
        assert completion.capture_valid == int(not invalid), f"{name}: captureValid"
        if invalid:
            assert completion.capture.generation == generation, name
        else:
            assert completion.capture == oracle, f"{name}: TX capture differs from the TX tap"
        assert oracle.error == int(inhibited), f"{name}: oracle error"
        assert rx["data"] == frame
        capture = rx["meta"].capture
        assert same_except_error(capture, oracle), f"{name}: RX capture differs from the pin oracle"
        assert capture.error == int(invalid), f"{name}: RX capture.error"

    # Where the RX adapter kept a frame, it agrees with the port as well.
    by_ticks = {capture.ticks: capture for _, capture in obs.rx_oracle}
    for *_, oracle, rx, _ in results:
        if oracle.ticks in by_ticks:
            assert same_except_error(rx["meta"].capture, by_ticks[oracle.ticks])


PARAMETER_SWEEP = [
    parameter_case("gmii", PHY_TYPE_G="GMII", CLK_FREQ_G=125000000),
    parameter_case("xgmii", PHY_TYPE_G="XGMII", CLK_FREQ_G=156250000),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_ptp_phc_mac_port(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ptpphcmacportwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + WRAPPERS},
    )
