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
# - Stimulus: Full-epoch acquisition, signed phase/rate commands, stale commands,
#   rollover, invalid/monotonic operations, and independent snapshot resets.
# - Checks: Every PHC cycle against the split-integer model; snapshot time/ticks
#   are coherent, old sessions cancel, and read reset preserves the PHC.
# - Timing: Acceptance precedes commit by one edge; capture abort is inspected
#   before commit and registered time/ack after TPD. Read clock is asynchronous.

import os
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import pytest
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
        for name in ("clk", "commandValid", "commandKind", "commandGeneration", "commandSeconds",
                     "commandNanoseconds", "commandFraction", "phaseSeconds", "phaseFraction",
                     "commandRate", "commandValue", "readClk", "readRst", "readRequest"):
            getattr(d, name).value = 0
        d.rst.value = 1-self.polarity
        d.monotonic.value = 0

    async def step(self, command=None, rejected=False):
        d = self.d
        d.clk.value = 0
        d.commandValid.value = int(command is not None)
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
        pending = self.model.pending
        await Timer(self.half, unit="ns")
        if pending is not None and pending.kind in ("set", "phase"):
            assert int(d.captureAbort.value), "abort must precede commit edge"
        d.clk.value = 1
        _, pps = self.model.tick()
        if command is not None and command[0] != "pps" and not rejected:
            self.model.submit(PhcCommand(command[0], command[1], self.model.generation))
        await Timer(self.half, unit="ns")
        got = ((int(d.timeSeconds.value)*NS + int(d.timeNanoseconds.value)) << 32) + int(d.timeFraction.value)
        assert got == self.model.time_q32, (got, self.model.time_q32)
        assert int(d.timeTicks.value) == self.model.ticks
        assert int(d.timeGeneration.value) == self.model.generation
        assert int(d.timeValid.value) == self.model.valid
        assert int(d.timeIncrement.value) == self.model.nominal+self.model.rate
        if pending:
            assert int(d.commandAck.value)
            assert not int(d.commandError.value)
        assert bool(d.pps.value) == bool(pps and self.pps_enabled and self.model.valid)

    async def reset(self):
        self.d.rst.value = self.polarity
        for _ in range(3):
            self.d.clk.value = 0
            await Timer(self.half, unit="ns")
            self.d.clk.value = 1
            await Timer(self.half, unit="ns")
        self.d.rst.value = 1-self.polarity
        self.model = PhcModel(self.frequency)

    async def command(self, kind, value):
        await self.step((kind, value))
        await self.step()

@cocotb.test()
async def phc_commands(d):
    b = Bench(d)
    await b.reset()
    for _ in range(30):
        await b.step()
    await b.command("set", (((1 << 40)*NS + NS-100) << 32) + 12345)
    await b.command("valid", 1)
    await b.command("pps", 1)
    b.pps_enabled = True
    for _ in range(30):
        await b.step()
    # Align revocation with natural seconds rollover. The clock still rolls,
    # but validity/PPS disable must suppress that edge's output pulse.
    await b.command("set", ((101*NS) << 32)-4*b.model.nominal)
    await b.command("valid", 1)
    await b.command("valid", 0)
    await b.command("set", ((102*NS) << 32)-4*b.model.nominal)
    await b.command("valid", 1)
    await b.step(("pps", 0))
    b.pps_enabled = False
    await b.step()
    await b.command("pps", 1)
    b.pps_enabled = True
    await b.command("phase", -(NS+3)*Q16-7)
    await b.command("phase", (2*NS+17)*Q16+13)
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
    d.monotonic.value = 1
    await b.step(("phase", -Q16), rejected=True)
    await b.step()
    assert int(d.commandAck.value) and int(d.commandError.value)
    await b.step(("rate", -b.model.nominal), rejected=True)
    await b.step()
    assert int(d.commandError.value)

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
        parameters={"CLK_FREQ_G": frequency, "RST_POLARITY_G": f"'{polarity}'", "RST_ASYNC_G": async_reset},
        extra_env={"FREQUENCY": frequency, "POLARITY": polarity})
