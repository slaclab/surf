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
# - Sweep: 125/156.25 MHz, synchronous high and asynchronous low reset.
# - Stimulus: AXI policy setup, full-epoch acquisition, signed phase/rate commands,
#   rollover, invalid/monotonic operations, registered cancellation/expiry,
#   and independent snapshot resets, including double-second phase carry
#   and all normalization branches at both epoch limits.
# - Checks: Every PHC cycle against the split-integer model; snapshot time/ticks
#   are coherent, old sessions cancel, and read reset preserves the PHC.
#   Cancellation after admission rejects commit; expiry overrides VALID commands.
#   RATE commits use the old increment on the commit edge and publish the new
#   value for following edges, including accepted/rejected increment limits.
#   Ready/completion/capture inhibition cannot respond combinationally to inputs.
# - Timing: Acceptance precedes commit by one edge; capture abort is inspected
#   before commit and registered time/ack after TPD. Read clock is asynchronous.

import os
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import pytest
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_reference import PhcModel, PhcCommand, NS, Q16, Q32

KINDS = {"set": 0, "phase": 1, "rate": 2, "valid": 3, "pps": 4}

class Bench:
    def __init__(self, d):
        self.d = d
        self.frequency = int(os.environ["FREQUENCY"])
        self.polarity = int(os.environ["POLARITY"])
        self.half = NS/self.frequency/2
        self.model = PhcModel(self.frequency)
        self.pps_enabled = False
        self.pending_command = None
        for name in ("clk", "commandValid", "commandCancel", "commandStale", "clearValid",
                     "commandKind", "commandGeneration", "commandSeconds",
                     "commandNanoseconds", "commandFraction", "phaseSeconds", "phaseFraction",
                     "commandRate", "commandValue", "readClk", "readRst", "readRequest",
                     "prepareConfig", "applyConfig", "snapshotCapture", "snapshotPublish", "snapshotSequence"):
            getattr(d, name).value = 0
        d.rst.value = 1-self.polarity
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(d, "axil"), d.clk, d.rst,
                                  reset_active_level=self.polarity)

    async def step(self, command=None, rejected=False, cancel=False, stale=False, clear_valid=False):
        d = self.d
        names = ("commandReady", "commandAck", "commandError", "captureAbort")
        published = tuple(int(getattr(d, name).value) for name in names)
        d.clk.value = 0
        d.commandValid.value = int(command is not None)
        d.commandCancel.value = int(cancel)
        d.commandStale.value = int(stale)
        d.clearValid.value = int(clear_valid)
        if command is not None:
            kind, value = command
            d.commandKind.value = KINDS[kind]
            d.commandGeneration.value = self.model.generation
            if kind == "set":
                sec, sub = divmod(value, NS*Q32)
                d.commandSeconds.value = sec
                d.commandNanoseconds.value = sub >> 32
                d.commandFraction.value = sub & (Q32-1)
            elif kind == "phase":
                sec = abs(value)//(NS*Q16) * (-1 if value < 0 else 1)
                d.phaseSeconds.value = sec & ((1 << 64)-1)
                d.phaseFraction.value = ((value-sec*NS*Q16)*Q16) & ((1 << 64)-1)
            elif kind == "rate":
                d.commandRate.value = value & ((1 << 64)-1)
            else:
                d.commandValue.value = value
        committing = self.pending_command
        if committing is not None and (cancel or stale):
            # Registered revocation arrives during the pending interval. The
            # clock advances normally, and the PHC acknowledges an error.
            self.model.pending = None
            committing = (committing[0], True)
        pending = self.model.pending
        await Timer(self.half, unit="ns")
        assert published == tuple(int(getattr(d, name).value) for name in names), "PHC output changed between edges"
        if pending is not None and pending.kind in ("set", "phase"):
            assert int(d.captureAbort.value), "abort must precede commit edge"
        # Registered ready promises capacity; shared cancel/stale still exclude
        # transfer at both endpoints without changing that promise mid-cycle.
        accepted = command is not None and bool(d.commandReady.value) and not cancel and not stale
        old_pps_enabled = self.pps_enabled
        d.clk.value = 1
        _, pps = self.model.tick()
        if clear_valid:
            self.model.valid = False
        if committing is not None and committing[0][0] == "pps" and not committing[1]:
            self.pps_enabled = bool(committing[0][1])
        self.pending_command = (command, rejected) if accepted else None
        if accepted and command[0] != "pps" and not rejected:
            self.model.submit(PhcCommand(command[0], command[1], self.model.generation))
        await Timer(self.half, unit="ns")
        got = ((int(d.timeSeconds.value)*NS + int(d.timeNanoseconds.value)) << 32) + int(d.timeFraction.value)
        assert got == self.model.time_q32, (got, self.model.time_q32)
        assert int(d.timeTicks.value) == self.model.ticks
        assert int(d.timeGeneration.value) == self.model.generation
        assert int(d.timeValid.value) == self.model.valid
        assert int(d.timeIncrement.value) == self.model.nominal+self.model.rate
        assert bool(d.commandAck.value) == (committing is not None)
        if committing is not None:
            assert bool(d.commandError.value) == committing[1]
        assert bool(d.pps.value) == bool(pps and old_pps_enabled and self.pps_enabled and self.model.valid)
        return accepted

    async def reset(self):
        self.d.rst.value = self.polarity
        for _ in range(3):
            self.d.clk.value = 0
            await Timer(self.half, unit="ns")
            self.d.clk.value = 1
            await Timer(self.half, unit="ns")
        self.d.rst.value = 1-self.polarity
        self.model = PhcModel(self.frequency)
        self.pending_command = None
        self.pps_enabled = False

    async def set_monotonic(self, enabled):
        # Advance the reference clock on every AXI and coordination cycle.
        transaction = cocotb.start_soon(self.axil.write(0x004, (int(enabled) << 3).to_bytes(4, "little")))
        for _ in range(100):
            await self.step()
            if transaction.done():
                assert transaction.result().resp == AxiResp.OKAY
                break
        else:
            assert False, "PHC AXI write timeout"
        self.d.prepareConfig.value = 1
        await self.step()
        self.d.prepareConfig.value = 0
        assert int(self.d.configValid.value)
        self.d.applyConfig.value = 1
        await self.step()
        self.d.applyConfig.value = 0

    async def command(self, kind, value, rejected=False):
        # The arbiter retains ownership through ACK. Hold the next request
        # stable across that release cycle instead of assuming immediate ready.
        for _ in range(20):
            if await self.step((kind, value), rejected=rejected):
                break
        else:
            assert False, "PHC command admission timeout"
        await self.step()

@cocotb.test()
async def phc_commands(d):
    b = Bench(d)
    await b.reset()
    await b.set_monotonic(False)
    for _ in range(30):
        await b.step()
    await b.command("set", (((1 << 40)*NS + NS-100) << 32) + 12345)
    await b.command("valid", 1)
    await b.command("pps", 1)
    for _ in range(30):
        await b.step()
    # Align revocation with natural seconds rollover. The clock still rolls,
    # but validity/PPS disable must suppress that edge's output pulse.
    await b.command("set", ((101*NS) << 32)-6*b.model.nominal)
    await b.command("valid", 1)
    await b.command("valid", 0)
    await b.command("set", ((102*NS) << 32)-6*b.model.nominal)
    await b.command("valid", 1)
    await b.command("pps", 0)
    await b.command("pps", 1)
    await b.command("phase", -(NS+3)*Q16-7)
    await b.command("phase", (2*NS+17)*Q16+13)
    # Alternate the smallest and largest legal increments with rejected values
    # on each boundary. The cycle oracle sees both commit-edge time and the
    # simultaneously published increment, catching an early or delayed switch.
    for increment in (1, NS*Q32-1, b.model.nominal+Q32//3, 1, b.model.nominal):
        await b.command("rate", increment-b.model.nominal)
        for _ in range(3):
            await b.step()
        for invalid in (0, -1, NS*Q32, NS*Q32+1):
            await b.command("rate", invalid-b.model.nominal, rejected=True)
            await b.step()
    rng = random.Random(1588)
    for index in range(100):
        if index % 3 == 0:
            await b.command("rate", rng.randrange(-1000000, 1000000))
        elif index % 3 == 1:
            await b.command("phase", rng.randrange(-3*NS*Q16, 3*NS*Q16))
        else:
            await b.command("valid", 1)
        for _ in range(rng.randrange(1, 8)):
            await b.step()
    # Rejected commands still acknowledge, but cannot change the timebase.
    await b.command("valid", 1)
    await b.set_monotonic(True)
    await b.command("phase", -Q16, rejected=True)
    assert int(d.commandAck.value) and int(d.commandError.value)
    await b.command("rate", -b.model.nominal, rejected=True)
    assert int(d.commandError.value)

@cocotb.test()
async def phase_normalization_limits(d):
    # A near-one-second rate plus a positive remainder can carry two seconds.
    # Exercise chunk carry/borrow boundaries and both signs using the same
    # independent integer clock oracle as every ordinary PHC cycle.
    b = Bench(d)
    await b.reset()
    await b.set_monotonic(False)
    for increment in (1, (1 << 32)-1, (1 << 48)+1, NS*Q32-1):
        await b.command("rate", increment-b.model.nominal)
        for remainder in (NS*Q16-1, -NS*Q16+1, 1, -1):
            await b.command("set", ((0xFFFF*NS+NS-1)*Q32)+0xFFFF)
            await b.command("phase", remainder)
            for _ in range(3):
                await b.step()


@cocotb.test()
async def phase_epoch_bounds(d):
    # Exercise every normalization branch at both epoch limits. Deliberately
    # use legal mixed-sign whole/remainder operands as well as normal producer
    # encodings, so the fault check cannot assume their signs match.
    b = Bench(d)
    second = NS*Q32
    limit = 1 << 48

    async def edge():
        """Real-time timing: drive one complete manual PHC clock cycle."""
        d.clk.value = 0
        await Timer(b.half, unit="ns")
        d.clk.value = 1
        await Timer(b.half, unit="ns")

    def time_value():
        return (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)

    for increment, subsecond, remainder in (
            (1, 0, -second+Q32),       # Borrow one second.
            (1, second//2, 0),         # No normalization carry.
            (1, second-1, second-Q32), # Carry one second.
            (second-1, second-1, second-Q32)):  # Carry two seconds.
        for base in (-2, -1, 0, 1, limit-3, limit-2, limit-1, limit, limit+1):
            await b.reset()
            await b.set_monotonic(False)
            await b.command("rate", increment-b.model.nominal)
            await b.command("set", 10*second+subsecond)
            for _ in range(5):
                if int(d.commandReady.value):
                    break
                await b.step()
            assert int(d.commandReady.value)
            initial = time_value()
            # The command commits after one admission edge. Pick the whole
            # seconds operand so the unnormalized commit base hits this bound.
            whole = base-(initial+increment)//second
            d.commandKind.value = KINDS["phase"]
            d.commandGeneration.value = int(d.timeGeneration.value)
            d.phaseSeconds.value = whole & ((1 << 64)-1)
            d.phaseFraction.value = remainder & ((1 << 64)-1)
            d.commandValid.value = 1
            await edge()
            assert time_value() == initial+increment
            d.commandValid.value = 0
            before = time_value()
            ticks = int(d.timeTicks.value)
            generation = int(d.timeGeneration.value)
            expected = before+increment+whole*second+remainder
            fault = not 0 <= expected < limit*second
            await edge()
            assert int(d.commandAck.value)
            assert bool(int(d.fault.value)) == fault, (base, increment, remainder)
            assert bool(int(d.commandError.value)) == fault
            assert time_value() == (before if fault else expected)
            assert int(d.timeTicks.value) == ticks+(not fault)
            assert int(d.timeGeneration.value) == generation+1
            assert not int(d.timeValid.value)
            assert int(d.captureAbort.value)
            if not fault and expected+increment >= limit*second:
                # The next ordinary tick must also fault closed at rollover.
                ticks = int(d.timeTicks.value)
                await edge()
                assert int(d.fault.value)
                assert time_value() == expected
                assert int(d.timeTicks.value) == ticks
                assert int(d.captureAbort.value)


@cocotb.test()
async def registered_command_lifecycle(d):
    b = Bench(d)
    await b.reset()
    await b.set_monotonic(False)
    # Exercise each registered revoke flag both before admission and after
    # acceptance. Neither a time step nor a rate/valid update may leak through.
    for revoke in ("cancel", "stale"):
        for command in (("phase", NS*Q16), ("rate", Q32), ("valid", 1)):
            for _ in range(3):
                assert not await b.step(command, **{revoke: True})
            assert await b.step(command)
            await b.step(**{revoke: True})
            assert int(d.commandAck.value) and int(d.commandError.value)
            await b.step(**{revoke: True})
            await b.step()
    # A successful phase commit must not be undone by the subsequent
    # generation-change cancellation emitted by the servo.
    await b.command("phase", NS*Q16)
    generation = b.model.generation
    await b.step(cancel=True)
    assert b.model.generation == generation
    await b.step()
    await b.command("valid", 1)
    await b.step()
    # A registered expiry arriving at commit wins over VALID=1. The level
    # stays effective while held and permits reacquisition after release.
    assert await b.step(("valid", 1))
    await b.step(clear_valid=True)
    assert not int(d.timeValid.value)
    await b.step(clear_valid=True)
    await b.step()
    await b.command("valid", 1)
    assert int(d.timeValid.value)


@cocotb.test()
async def register_snapshot_edges(d):
    # Drive the production bank's private capture/publish handshake explicitly
    # to land capture on a command commit, validity loss and configuration apply.
    # Every intervening PHC cycle still runs the independent clock oracle.
    b = Bench(d)
    await b.reset()
    await b.set_monotonic(False)
    await b.command("set", ((100*NS+123) << 32)+17)
    await b.command("valid", 1)

    async def read(address, size=4):
        transaction = cocotb.start_soon(b.axil.read(address, size))
        for _ in range(100):
            await b.step()
            if transaction.done():
                assert transaction.result().resp == AxiResp.OKAY
                return int.from_bytes(transaction.result().data, "little")
        assert False, "PHC register snapshot read timeout"

    events = (("set", (222*NS+7)*Q32+123), ("phase", -NS*Q16+7),
              ("rate", Q32//3), ("valid", 0), "invalidate", "apply")
    for sequence, event in enumerate(events, 1):
        await b.command("valid", 1)
        await b.step()
        if isinstance(event, tuple):
            assert await b.step(event)
        elif event == "apply":
            d.prepareConfig.value = 1
            await b.step()
            d.prepareConfig.value = 0
            d.applyConfig.value = 1
        expected = (b.model.time_q32, b.model.ticks, b.model.generation,
                    int(b.model.valid), b.model.rate)
        d.snapshotSequence.value = sequence
        d.snapshotCapture.value = 1
        await b.step(clear_valid=event == "invalidate")
        d.snapshotCapture.value = 0
        d.applyConfig.value = 0
        assert not int(d.snapshotPrepared.value)
        for _ in range(12):
            await b.step()
            if int(d.snapshotPrepared.value):
                break
        assert int(d.snapshotPrepared.value)
        assert await read(0x3FC) == sequence-1
        d.snapshotPublish.value = 1
        await b.step()
        d.snapshotPublish.value = 0
        seconds = await read(0x008, 8)
        nanoseconds = await read(0x010)
        fraction = await read(0x014)
        observed = (((seconds*NS+nanoseconds) << 32)+fraction,
                    await read(0x060, 8), await read(0x018),
                    await read(0x01C), await read(0x058, 8))
        assert observed == expected, (event, observed, expected)
        assert await read(0x3FC) == sequence


@cocotb.test()
async def snapshot_sessions(d):
    b = Bench(d)
    await b.reset()
    # Free-running clocks expose coherent time/tick arithmetic without a shared
    # sampling phase. The read mailbox has its own reset and request lifecycle.
    phc_clock = cocotb.start_soon(Clock(d.clk, 2*b.half, unit="ns").start())
    read_clock = cocotb.start_soon(Clock(d.readClk, 11, unit="ns").start())
    d.readRst.value = 1
    await Timer(200, unit="ns")
    d.readRst.value = 0
    async def read_edge():
        await RisingEdge(d.readClk)
        await Timer(2, unit="ns")
    async def request():
        for _ in range(100):
            await read_edge()
            if int(d.readReady.value):
                break
        else:
            assert False, "mailbox ready timeout"
        d.readRequest.value = 1
        await read_edge()
        d.readRequest.value = 0
    for _ in range(12):
        await request()
        for _ in range(100):
            await read_edge()
            if int(d.readValid.value):
                break
        else:
            assert False, "snapshot timeout"
        ticks = int(d.readTicks.value)
        value = ((int(d.readSeconds.value)*NS + int(d.readNanoseconds.value)) << 32) + int(d.readFraction.value)
        assert value == ticks*b.model.nominal
        assert int(d.readGeneration.value) == 0
    await request()
    before = int(d.timeTicks.value)
    d.readRst.value = 1
    await Timer(100, unit="ns")
    assert int(d.timeTicks.value) > before
    assert not int(d.readValid.value)
    d.readRst.value = 0
    for _ in range(30):
        await read_edge()
        assert not int(d.readValid.value), "cancelled request returned"
    await request()
    # PHC reset cancels an outstanding session as well as resetting time.
    d.rst.value = b.polarity
    await Timer(100, unit="ns")
    d.rst.value = 1-b.polarity
    for _ in range(30):
        await read_edge()
        assert not int(d.readValid.value)
    # Reset the mailbox while the PHC clock is stopped, then accept a request
    # before that clock restarts. FIFO full deassertion alone is not a write ack.
    phc_clock.cancel()
    d.clk.value = 0
    d.readRst.value = 1
    await Timer(100, unit="ns")
    d.readRst.value = 0
    await request()
    for _ in range(20):
        await read_edge()
        assert not int(d.readValid.value)
    phc_clock = cocotb.start_soon(Clock(d.clk, 2*b.half, unit="ns").start())
    for _ in range(100):
        await read_edge()
        if int(d.readValid.value):
            break
    else:
        assert False, "stopped-peer request was lost before FIFO reset recovery"
    ticks = int(d.readTicks.value)
    value = ((int(d.readSeconds.value)*NS + int(d.readNanoseconds.value)) << 32) + int(d.readFraction.value)
    assert value == ticks*b.model.nominal
    phc_clock.cancel()
    read_clock.cancel()

@pytest.mark.parametrize("frequency,polarity,async_reset", [(125000000, 1, False), (156250000, 0, True)])
def test_ptp_phc(frequency, polarity, async_reset):
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.ptpphcwrapper",
        extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpPhcWrapper.vhd"]},
        parameters={"CLK_FREQ_G": frequency, "RST_POLARITY_G": f"'{polarity}'", "RST_ASYNC_G": async_reset},
        extra_env={"FREQUENCY": frequency, "POLARITY": polarity})
