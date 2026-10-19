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
# - Sweep: 125 MHz with a nonzero 8 KiB base on a common clock, 156.25 MHz
#   behind an independent management clock, and external support compiled out.
# - Stimulus: The real PtpPhcCore through AXI-Lite and its external command
#   port: identity/capabilities, manual SET/PHASE/RATE/VALID/PPS, non-owner
#   offers from both paths, owner commits swept against a continuously offering
#   client, cancellation/restart/abort/stale vetoes, AXI reset during PHASE
#   normalization and owner transition, snapshot/commit collisions,
#   VALID/clearValid/PPS commands landing on the second-rollover edge, and
#   system reset recovery.
# - Checks: A lockstep checker compares every PHC cycle with the independent
#   split-integer PhcModel, applying each command on the edge the core
#   acknowledges it and recording which path received the acknowledgement.
#   Capture inhibition must precede exactly the SET/PHASE commit edges; PPS
#   requires enable and qualification on both sides of rollover. A non-owner
#   request must never be admitted, acknowledged or inhibit captures.
#   Every admitted external command is acknowledged exactly once; owner changes
#   wait for the drain and reject the old owner afterwards.
# - Timing: Inputs change after a rising edge and are sampled by the next one;
#   the checker samples registered outputs between edges.

import os
import random
from dataclasses import dataclass

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_reference import NS, Q16, Q32, PhcCommand, PhcModel

KINDS = {"set": 0, "phase": 1, "rate": 2, "valid": 3, "pps": 4}
SECOND_Q32 = NS*Q32
VERSION = 0x00010000


@dataclass
class Inflight:
    kind: str
    value: int
    source: str  # "axi" or "external"


class Bench:
    def __init__(self, d):
        self.d = d
        self.frequency = int(os.environ["FREQUENCY"])
        self.base = int(os.environ["AXIL_BASE"])
        self.common = os.environ["COMMON_CLK"] == "1"
        self.has_external = os.environ["EXTERNAL"] == "1"
        self.period_ps = round(1e12/self.frequency)
        for name in ("rst", "regRst", "restart", "commandAbort", "commandValid", "commandCancel",
                     "commandStale", "commandKind", "commandGeneration", "commandSeconds",
                     "commandNanoseconds", "commandFraction", "phaseSeconds", "phaseFraction",
                     "commandRate", "commandValue", "clearValid", "axilRst", "axilClk"):
            getattr(d, name).value = 0
        bus_clk, bus_rst = (d.clk, d.rst) if self.common else (d.axilClk, d.axilRst)
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(d, "axil"), bus_clk, bus_rst,
                                  reset_active_level=True)
        self.model = None
        self.inflight = None
        self.acks = []
        self.history = {}
        self.pps_enabled = False
        self.pps_count = 0
        self.edge = 0
        self.paused = True
        self.accept_tick = None

    async def start(self):
        d = self.d
        cocotb.start_soon(Clock(d.clk, self.period_ps, unit="ps").start())
        cocotb.start_soon(Clock(d.axilClk, 10000, unit="ps").start())
        cocotb.start_soon(self.monitor())
        await self.system_reset()

    async def system_reset(self):
        d = self.d
        self.paused = True
        d.rst.value = 1
        d.axilRst.value = 1
        for _ in range(6):
            await RisingEdge(d.clk)
        d.rst.value = 0
        d.axilRst.value = 0
        self.model = None
        self.inflight = None
        self.pps_enabled = False
        self.paused = False
        # The management crossing answers locally until its FIFO reset has
        # resynchronized in both domains.
        for _ in range(4 if self.common else 64):
            await RisingEdge(d.clk)

    # ------------------------------------------------------------------
    # Lockstep checker
    # ------------------------------------------------------------------
    def sample(self):
        d = self.d
        return {
            "time": ((int(d.timeSeconds.value)*NS + int(d.timeNanoseconds.value)) << 32) + int(d.timeFraction.value),
            "seconds": int(d.timeSeconds.value),
            "ticks": int(d.timeTicks.value),
            "generation": int(d.timeGeneration.value),
            "increment": int(d.timeIncrement.value),
            "valid": int(d.timeValid.value),
            "ack": int(d.statusAck.value),
            "error": int(d.statusError.value),
            "commandAck": int(d.commandAck.value),
            "commandError": int(d.commandError.value),
            "ready": int(d.commandReady.value),
            "disc": int(d.discontinuity.value),
            "fault": int(d.fault.value),
            "abort": int(d.captureAbort.value),
            "pps": int(d.pps.value),
            "owner": int(d.externalOwner.value),
            "prepared": int(d.configPrepared.value),
            "clear": int(d.clearValid.value),
            "valid_in": int(d.commandValid.value),
            "cancel_in": int(d.commandCancel.value),
            "stale_in": int(d.commandStale.value),
        }

    def adopt(self, obs):
        model = PhcModel(self.frequency)
        whole_ns, model.fraction = divmod(obs["time"], Q32)
        model.seconds, model.nanoseconds = divmod(whole_ns, NS)
        model.ticks = obs["ticks"]
        model.generation = obs["generation"]
        model.valid = bool(obs["valid"])
        model.rate = obs["increment"]-model.nominal
        self.model = model

    async def monitor(self):
        d = self.d
        prev = None
        while True:
            await FallingEdge(d.clk)
            if self.paused or int(d.rst.value):
                prev = None
                continue
            obs = self.sample()
            self.edge += 1
            obs["edge"] = self.edge
            if prev is None or self.model is None:
                if self.model is None:
                    self.adopt(obs)
                    # Reset leaves capture inhibited for its first cycle.
                    obs["adopted"] = True
            else:
                self.check(prev, obs)
            self.history[obs["ticks"]] = obs["time"]
            prev = obs

    def check(self, prev, obs):
        model = self.model
        assert not obs["fault"], "unexpected PHC fault"
        # Admission is visible at the previous edge: valid/ready with no veto.
        admitted = prev["valid_in"] and prev["ready"] and not prev["cancel_in"] and not prev["stale_in"]
        if admitted:
            assert self.has_external and prev["owner"], "non-owner external command admitted"
        cmd = None
        if obs["ack"]:
            cmd = self.inflight
            assert cmd is not None, "unexpected PHC command acknowledgement"
            self.inflight = None
            self.acks.append((cmd, obs["error"], obs["edge"]))
            # Completion returns only to the owner that was accepted.
            assert obs["commandAck"] == int(cmd.source == "external"), (cmd, obs)
            if obs["commandAck"]:
                assert obs["commandError"] == obs["error"]
        else:
            assert not obs["commandAck"], "external acknowledgement without a commit"
        applied = cmd is not None and not obs["error"]
        valid_before = model.valid
        pps_before = self.pps_enabled
        if applied and cmd.kind != "pps":
            model.pending = PhcCommand(cmd.kind, cmd.value, model.generation)
        seconds_before = model.seconds
        model.tick()
        if prev["clear"] and prev["owner"]:
            model.valid = False
        if applied and cmd.kind == "pps":
            self.pps_enabled = bool(cmd.value)
        crossed = model.seconds > seconds_before and not (applied and cmd.kind in ("set", "phase"))
        assert obs["time"] == model.time_q32, (obs["edge"], obs["time"], model.time_q32)
        assert obs["ticks"] == model.ticks
        assert obs["generation"] == model.generation
        assert obs["valid"] == int(model.valid), (obs["edge"], cmd)
        assert obs["increment"] == model.nominal+model.rate
        assert obs["disc"] == int(applied and cmd.kind in ("set", "phase"))
        expected_pps = crossed and pps_before and self.pps_enabled and valid_before and model.valid
        assert obs["pps"] == int(expected_pps), (obs["edge"], crossed, pps_before, valid_before)
        self.pps_count += obs["pps"]
        # Inhibition is registered at SET/PHASE admission, one edge before the
        # commit (accepted or rejected there), and held with a discontinuity.
        expected_abort = prev["disc"] or (cmd is not None and cmd.kind in ("set", "phase"))
        if not prev.get("adopted"):
            assert prev["abort"] == int(expected_abort), (prev["edge"], cmd)

    # ------------------------------------------------------------------
    # AXI-Lite helpers
    # ------------------------------------------------------------------
    async def write(self, offset, value, resp=AxiResp.OKAY):
        result = await self.axil.write(self.base+offset, (value & 0xFFFFFFFF).to_bytes(4, "little"))
        assert result.resp == resp, (hex(offset), result.resp, resp)

    async def read(self, offset, resp=AxiResp.OKAY):
        result = await self.axil.read(self.base+offset, 4)
        assert result.resp == resp, (hex(offset), result.resp, resp)
        return int.from_bytes(result.data, "little")

    async def write_wide(self, offset, value, words):
        for i in range(words):
            await self.write(offset+4*i, (value >> (32*i)) & 0xFFFFFFFF)

    async def read_wide(self, offset, words):
        value = 0
        for i in range(words):
            value |= await self.read(offset+4*i) << (32*i)
        return value

    async def commit(self, owner=None, resp=AxiResp.OKAY):
        if owner is not None:
            await self.write(0x004, owner)
        sequence = await self.read(0x048)
        await self.write(0x03C, 1, resp)
        if resp != AxiResp.OKAY:
            return None
        for _ in range(200):
            state = await self.read(0x040)
            if not state & 2 and await self.read(0x048) != sequence:
                return state & 1
        assert False, "commit did not complete"

    async def manual(self, kind, value, resp=AxiResp.OKAY):
        if kind == "set":
            whole_ns, fraction = divmod(value, Q32)
            seconds, nanoseconds = divmod(whole_ns, NS)
            await self.write_wide(0x1028, seconds, 2)
            await self.write(0x1030, nanoseconds)
            await self.write(0x1034, fraction)
        elif kind == "phase":
            await self.write_wide(0x1038, value & ((1 << 128)-1), 4)
        elif kind == "rate":
            await self.write_wide(0x1048, value & ((1 << 64)-1), 2)
        bit = value if kind in ("valid", "pps") else 0
        if resp == AxiResp.OKAY:
            self.inflight = Inflight(kind, value, "axi")
        await self.write(0x1020, 0x80 | KINDS[kind] | (bit << 3), resp)
        if resp != AxiResp.OKAY:
            assert not await self.read(0x1024) & 1, "rejected submission left the command busy"
            return None
        for _ in range(400):
            state = await self.read(0x1024)
            if not state & 1 and state & 2:
                return (state >> 2) & 1
        assert False, "manual command did not complete"

    async def snapshot(self):
        sequence = await self.read(0x104)
        await self.write(0x100, 1)
        for _ in range(200):
            if not await self.read(0x108) & 1:
                break
        assert await self.read(0x104) == sequence+1
        assert await self.read(0x13FC) == sequence+1
        seconds = await self.read_wide(0x1008, 2)
        nanoseconds = await self.read(0x1010)
        fraction = await self.read(0x1014)
        ticks = await self.read_wide(0x1060, 2)
        return ((seconds*NS + nanoseconds) << 32) + fraction, ticks

    # ------------------------------------------------------------------
    # External client helpers (drive after an edge, sampled by the next)
    # ------------------------------------------------------------------
    def drive(self, kind, value, generation=None):
        d = self.d
        d.commandKind.value = KINDS[kind]
        d.commandGeneration.value = self.model.generation if generation is None else generation
        d.commandValue.value = value if kind in ("valid", "pps") else 0
        if kind == "set":
            seconds, sub = divmod(value, SECOND_Q32)
            d.commandSeconds.value = seconds
            d.commandNanoseconds.value = sub >> 32
            d.commandFraction.value = sub & (Q32-1)
        elif kind == "phase":
            seconds = abs(value)//(NS*Q16) * (-1 if value < 0 else 1)
            d.phaseSeconds.value = seconds & ((1 << 64)-1)
            d.phaseFraction.value = ((value-seconds*NS*Q16)*Q16) & ((1 << 64)-1)
        elif kind == "rate":
            d.commandRate.value = value & ((1 << 64)-1)

    async def offer(self, kind, value, generation=None, timeout=50):
        """Present one external command; return the edge count it was accepted."""
        d = self.d
        await RisingEdge(d.clk)
        self.drive(kind, value, generation)
        self.inflight = Inflight(kind, value, "external")
        d.commandValid.value = 1
        for _ in range(timeout):
            await RisingEdge(d.clk)
            if int(d.commandReady.value):
                d.commandValid.value = 0
                # Ticks registered by this acceptance edge.
                self.accept_tick = int(d.timeTicks.value)+1
                return True
        d.commandValid.value = 0
        self.inflight = None
        return False

    async def external(self, kind, value, generation=None):
        assert await self.offer(kind, value, generation), "external command not admitted"
        return await self.wait_ack()

    async def wait_ack(self):
        d = self.d
        for _ in range(10):
            await RisingEdge(d.clk)
            await Timer(2, unit="ns")
            if int(d.commandAck.value):
                return int(d.commandError.value)
        assert False, "external command not acknowledged"

    async def settle(self):
        # A crossing answers SLVERR locally until a reset has resynchronized.
        if not self.common:
            await self.cycles(64)

    async def cycles(self, count):
        for _ in range(count):
            await RisingEdge(self.d.clk)

    def live_time(self):
        d = self.d
        return ((int(d.timeSeconds.value)*NS + int(d.timeNanoseconds.value)) << 32) + int(d.timeFraction.value)

    def increment(self):
        return int(self.d.timeIncrement.value)


async def setup(d):
    b = Bench(d)
    await b.start()
    return b


async def take_external(b):
    assert await b.commit(owner=1) == 0
    assert await b.read(0x044) & 1
    assert int(b.d.externalOwner.value)


@cocotb.test()
async def identity_and_map(d):
    b = await setup(d)
    assert await b.read(0x000) == VERSION
    capabilities = 0x1F | (int(b.has_external) << 8) | (int(not b.common) << 10)
    assert await b.read(0x008) == capabilities
    assert await b.read(0x004) == 0
    assert await b.read(0x044) == 0x10  # AXI owner, command slot idle.
    assert await b.read(0x1080) == b.frequency
    assert await b.read_wide(0x1050, 2) == b.model.nominal
    assert await b.read(0x1004) == 8  # Monotonic policy shadow resets enabled.
    await b.write(0x000, 0, AxiResp.DECERR)
    await b.read(0x00C, AxiResp.DECERR)
    await b.read(0x13F0, AxiResp.DECERR)
    # The aperture ends at 8 KiB; the next slot does not alias the control bank.
    await b.read(0x2000, AxiResp.DECERR)
    if b.base:
        result = await b.axil.read(0x000, 4)
        assert result.resp == AxiResp.DECERR


@cocotb.test()
async def manual_commands(d):
    b = await setup(d)
    start = 7*SECOND_Q32 - 5000*b.model.nominal
    assert await b.manual("set", start) == 0
    assert await b.manual("valid", 1) == 0
    assert await b.manual("pps", 1) == 0
    # Wait through the rollover so the checker confirms the PPS edge.
    while b.live_time() < 7*SECOND_Q32 + 4*b.increment():
        await b.cycles(16)
    assert b.pps_count == 1
    assert await b.manual("phase", 1500*Q16 + 3) == 0
    assert await b.manual("rate", 12345) == 0
    assert await b.manual("rate", -(b.model.nominal//4)) == 0
    # Monotonic policy rejects a backward step on valid time without effect.
    assert await b.manual("valid", 1) == 0
    assert await b.manual("phase", -5*Q16) == 1
    assert await b.manual("set", start) == 1
    # A full-second negative step is accepted once qualification is withdrawn.
    assert await b.manual("valid", 0) == 0
    assert await b.manual("phase", -(NS+250)*Q16) == 0
    snapshot_time, snapshot_ticks = await b.snapshot()
    assert b.history[snapshot_ticks] == snapshot_time
    assert int(d.externalOwner.value) == 0


@cocotb.test()
async def non_owner_requests_have_no_effect(d):
    b = await setup(d)
    assert await b.manual("valid", 1) == 0
    generation = int(d.timeGeneration.value)
    # Hold external SET/PHASE/RATE offers while the AXI bank owns the clock.
    for kind, value in (("set", 3*SECOND_Q32), ("phase", 100*Q16), ("rate", 7)):
        await RisingEdge(d.clk)
        b.drive(kind, value)
        d.commandValid.value = 1
        for _ in range(48):
            await RisingEdge(d.clk)
            assert not int(d.commandReady.value)
            assert not int(d.captureAbort.value)
        d.commandValid.value = 0
    # An inactive controller cannot revoke qualification.
    d.clearValid.value = 1
    await b.cycles(8)
    d.clearValid.value = 0
    await b.cycles(2)
    assert int(d.timeValid.value) == 1
    assert int(d.timeGeneration.value) == generation
    assert not [ack for ack in b.acks if ack[0].source == "external"]


@cocotb.test()
async def external_owner_commands(d):
    b = await setup(d)
    if not b.has_external:
        assert await b.commit(owner=1) == 1
        assert await b.read(0x044) & 1 == 0
        assert await b.read(0x040) & 1
        assert await b.manual("set", 2*SECOND_Q32) == 0
        return
    await take_external(b)
    # AXI steering is refused before operands freeze; PPS stays available.
    for kind in ("set", "phase", "rate", "valid"):
        await b.manual(kind, 1, AxiResp.SLVERR)
    assert await b.manual("pps", 1) == 0
    assert await b.external("set", 9*SECOND_Q32 + 17) == 0
    assert await b.external("rate", -321) == 0
    assert await b.external("phase", -40*Q16 - 5) == 0
    assert await b.external("valid", 1) == 0
    # A stale generation is acknowledged with an error and no effect.
    assert await b.external("rate", 99, generation=b.model.generation-1) == 1
    # Registered cancel and restart veto an accepted command before commit.
    for veto in ("commandCancel", "restart"):
        assert await b.offer("rate", 555)
        getattr(d, veto).value = 1
        assert await b.wait_ack() == 1
        getattr(d, veto).value = 0
    # Restart after the commit edge cannot undo it.
    assert await b.offer("rate", 777)
    await RisingEdge(d.clk)
    d.restart.value = 1
    await b.cycles(2)
    d.restart.value = 0
    assert b.acks[-1][1] == 0
    # A controller abort rising inside the commit window vetoes once; later
    # commands proceed while it stays held.
    assert await b.offer("rate", 888)
    d.commandAbort.value = 1
    assert await b.wait_ack() == 1
    assert await b.external("rate", 889) == 0
    d.commandAbort.value = 0
    # The owning client's expiry revokes qualification without a step.
    generation = int(d.timeGeneration.value)
    d.clearValid.value = 1
    await b.cycles(3)
    d.clearValid.value = 0
    await b.cycles(2)
    assert int(d.timeValid.value) == 0
    assert int(d.timeGeneration.value) == generation


@cocotb.test()
async def owner_transition_drains(d):
    b = await setup(d)
    if not b.has_external:
        return
    race_seen = False
    for delay in range(10):
        await take_external(b)
        admitted = []
        prepared_fall = []
        stop = False

        async def client():
            # Offer back-to-back RATE commands until the owner changes.
            value = 1
            while not stop:
                if not await b.offer("rate", value, timeout=6):
                    await RisingEdge(d.clk)
                    continue
                admitted.append(b.accept_tick)
                assert await b.wait_ack() == 0
                value += 1

        async def watch():
            last = 1
            while not stop:
                await FallingEdge(d.clk)
                now = int(d.configPrepared.value)
                if last and not now:
                    prepared_fall.append(int(d.timeTicks.value))
                last = now

        tasks = [cocotb.start_soon(client()), cocotb.start_soon(watch())]
        await b.cycles(delay)
        assert await b.commit(owner=0) == 0
        assert int(d.externalOwner.value) == 0
        await b.cycles(20)
        stop = True
        await b.cycles(12)
        for task in tasks:
            task.cancel()
        d.commandValid.value = 0
        b.inflight = None
        external = [ack for ack in b.acks if ack[0].source == "external"]
        assert len(external) == len(admitted)
        # An admission on the edge where prepared falls used a ready
        # published before busy: the drain race.
        race_seen |= any(edge in prepared_fall for edge in admitted)
        b.acks.clear()
        # The old owner is now refused and AXI steering works again.
        assert not await b.offer("rate", 1, timeout=8)
        assert await b.manual("rate", delay) == 0
    assert race_seen, "no sweep admitted a command on the prepare edge"


@cocotb.test()
async def axi_reset_preserves_work(d):
    b = await setup(d)
    # Start a wide PHASE and reset the bus while it normalizes.
    await b.write_wide(0x1038, (3*NS+77)*Q16, 4)
    b.inflight = Inflight("phase", (3*NS+77)*Q16, "axi")
    await b.write(0x1020, 0x81)
    assert await b.read(0x1024) & 1, "normalization finished before the reset"
    d.regRst.value = 1
    await b.cycles(3)
    d.regRst.value = 0
    await b.settle()
    for _ in range(100):
        state = await b.read(0x1024)
        if state & 2:
            break
    assert state == 2, state
    assert any(ack[0].kind == "phase" and not ack[1] for ack in b.acks)
    if not b.common:
        # The management reset alone leaves the clock and its owner running.
        d.axilRst.value = 1
        await b.cycles(10)
        d.axilRst.value = 0
        await b.settle()
        assert await b.read(0x000) == VERSION
    if b.has_external:
        # Reset the bus right after an owner commit is accepted.
        await b.write(0x004, 1)
        await b.write(0x03C, 1)
        d.regRst.value = 1
        await b.cycles(2)
        d.regRst.value = 0
        await b.cycles(20)
        await b.settle()
        assert int(d.externalOwner.value) == 1
        assert await b.read(0x044) & 1
        assert await b.external("rate", 5) == 0


@cocotb.test()
async def snapshot_commit_collisions(d):
    b = await setup(d)
    rng = random.Random(1588)
    for delay in range(8):
        owner = int(b.has_external) & (delay & 1 ^ 1)
        await b.write(0x004, owner)
        snapshot_sequence = await b.read(0x104)
        config_sequence = await b.read(0x048)
        prepared_low = []

        async def watch():
            while True:
                await FallingEdge(d.clk)
                if not int(d.configPrepared.value):
                    prepared_low.append(int(d.timeTicks.value))

        watcher = cocotb.start_soon(watch())
        commit = cocotb.start_soon(b.write(0x03C, 1))
        await b.cycles(delay + rng.randrange(2))
        await b.write(0x100, 1)
        await commit
        for _ in range(100):
            if not await b.read(0x108) & 1 and not await b.read(0x040) & 2:
                break
        watcher.cancel()
        assert await b.read(0x104) == snapshot_sequence+1
        assert await b.read(0x13FC) == snapshot_sequence+1
        assert await b.read(0x048) == config_sequence+1
        assert await b.read(0x044) & 1 == owner
        ticks = await b.read_wide(0x1060, 2)
        seconds = await b.read_wide(0x1008, 2)
        stamp = ((seconds*NS + await b.read(0x1010)) << 32) + await b.read(0x1014)
        assert b.history[ticks] == stamp
        # A snapshot is never captured while the transaction is draining.
        assert ticks not in prepared_low


@cocotb.test()
async def pps_rollover_edges(d):
    b = await setup(d)
    if not b.has_external:
        return
    # Re-arming each second uses SET on qualified time, so commit the
    # monotonic policy off together with external ownership.
    await b.write(0x1004, 0)
    await take_external(b)

    async def approach(second):
        assert await b.external("set", second*SECOND_Q32 - 120*b.model.nominal) == 0
        assert await b.external("valid", 1) == 0
        assert await b.external("pps", 1) == 0

    async def land_on_rollover(action):
        # Read live time after an edge; rollover happens on edge R.
        await RisingEdge(d.clk)
        await Timer(2, unit="ns")
        now, increment = b.live_time(), b.increment()
        remaining = -(-(SECOND_Q32 - now % SECOND_Q32) // increment)
        assert remaining > 6
        await b.cycles(remaining-3)  # Now just after edge R-3.
        await action()
        await b.cycles(6)

    async def accept_before_rollover(kind, value):
        # Drive after R-3 is not used; drive after R-2 so R-1 admits.
        await RisingEdge(d.clk)
        b.drive(kind, value)
        b.inflight = Inflight(kind, value, "external")
        d.commandValid.value = 1
        await RisingEdge(d.clk)
        assert int(d.commandReady.value)
        d.commandValid.value = 0

    async def clear_on_rollover():
        await b.cycles(2)  # Now just after R-1; R samples the level.
        d.clearValid.value = 1
        await RisingEdge(d.clk)
        d.clearValid.value = 0

    second = 11
    await approach(second)
    count = b.pps_count
    await land_on_rollover(lambda: b.cycles(0))
    assert b.pps_count == count+1
    for name, action in (("valid0", lambda: accept_before_rollover("valid", 0)),
                         ("pps0", lambda: accept_before_rollover("pps", 0)),
                         ("clear", clear_on_rollover)):
        second += 2
        await approach(second)
        count = b.pps_count
        await land_on_rollover(action)
        assert b.pps_count == count, name
        assert b.model.seconds == second
    # VALID(1) on the rollover edge first qualifies the following second.
    second += 2
    assert await b.external("set", second*SECOND_Q32 - 120*b.model.nominal) == 0
    assert await b.external("pps", 1) == 0
    count = b.pps_count
    await land_on_rollover(lambda: accept_before_rollover("valid", 1))
    assert b.pps_count == count
    assert int(d.timeValid.value) == 1


@cocotb.test()
async def system_reset_recovery(d):
    b = await setup(d)
    if b.has_external:
        await take_external(b)
        assert await b.external("set", 4*SECOND_Q32) == 0
    else:
        assert await b.manual("set", 4*SECOND_Q32) == 0
    await b.system_reset()
    await b.cycles(2)
    assert int(d.externalOwner.value) == 0
    assert int(d.timeGeneration.value) == 0
    assert int(d.timeValid.value) == 0
    assert b.live_time() == int(d.timeTicks.value)*b.model.nominal
    assert await b.read(0x004) == 0
    assert await b.read(0x044) == 0x10
    assert await b.manual("set", 2*SECOND_Q32) == 0


CASES = [
    pytest.param(125000000, 0x00016000, True, True, id="125MHz-common-base"),
    pytest.param(156250000, 0x00002000, False, True, id="156MHz-async"),
    pytest.param(125000000, 0x00000000, True, False, id="125MHz-no-external"),
]


@pytest.mark.parametrize("frequency,base,common,external", CASES)
def test_ptp_phc_core(frequency, base, common, external):
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.ptpphccorewrapper",
        extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpPhcCoreWrapper.vhd"]},
        parameters={"CLK_FREQ_G": frequency, "AXIL_BASE_ADDR_G": f"{base:032b}",
                    "COMMON_CLK_G": common, "EXT_COMMAND_EN_G": external},
        extra_env={"FREQUENCY": frequency, "AXIL_BASE": base,
                   "COMMON_CLK": int(common), "EXTERNAL": int(external)})
