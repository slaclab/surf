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
# - Sweep: Keep the narrow common-clock wrapper case that proves the cocotb-facing
#   bridge topology and stable pass-through behavior, and add one asynchronous
#   active-high case so the remote-reset path is covered without pulling the
#   less simulator-stable reset permutations into the regression batch.
# - Stimulus: Drive AXI-Lite writes and reads through the slave-side port into a
#   cocotb RAM attached to the master-side port, then assert only the master
#   reset while the slave side remains live in the asynchronous case.
# - Checks: Successful transactions must round-trip through the bridge into the
#   backing RAM, common-clock reset must restart the path cleanly, post-reset
#   traffic must recover without stale responses, and a transaction rejected
#   while the master domain is reset must never execute downstream afterwards.
# - Timing: The bench drives both bridge clocks from one lockstep coroutine so
#   `COMMON_CLK_G=true` is exercised as a true shared-clock configuration. The
#   asynchronous case drives mAxiClk from a gateable coroutine so the test can
#   hold the master domain still while the slave domain keeps running.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import (
    env_flag,
    env_sl,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)


# cocotb resolves `skip` when the decorator runs, so the configuration has to be
# read at import time rather than from inside a test body.
COMMON_CLK = env_flag("COMMON_CLK_G", default=False)

# Bound every slave-side transaction so a missing fail-fast response is reported
# as a test failure instead of hanging the regression.
TXN_TIMEOUT_US = 20

# Distinct addresses keep the baseline, rejected, and recovery accesses from
# aliasing each other in the backing RAM.
BASELINE_ADDR = 0x040
REJECTED_WRITE_ADDR = 0x044
REJECTED_READ_ADDR = 0x048
RECOVERY_ADDR = 0x04C


class GatedClock:
    """Free-running clock that the test can stop and restart.

    `cocotb.clock.Clock` cannot be paused, and the remote-reset scenario needs
    mAxiClk held low while sAxiClk keeps running.
    """

    def __init__(self, signal, period_ns):
        self.signal = signal
        self.half_period_ns = period_ns / 2
        self.enabled = True
        signal.setimmediatevalue(0)
        cocotb.start_soon(self._drive())

    async def _drive(self):
        while True:
            await Timer(self.half_period_ns, unit="ns")
            if not self.enabled:
                self.signal.value = 0
                continue
            self.signal.value = 1
            await Timer(self.half_period_ns, unit="ns")
            self.signal.value = 0

    def stop(self):
        self.enabled = False
        self.signal.value = 0

    def start(self):
        self.enabled = True


class SourcePortMonitor:
    """Counts handshakes on the slave-side AXI-Lite port.

    The bridge must never present a response that the slave side did not ask
    for, so the test compares accepted requests against completed responses.
    """

    def __init__(self, dut):
        self.dut = dut
        self.counts = {"AR": 0, "R": 0, "AW": 0, "W": 0, "B": 0}
        cocotb.start_soon(self._run())

    @staticmethod
    def _high(signal) -> bool:
        try:
            return int(signal.value) == 1
        except ValueError:
            return False

    def _handshake(self, valid, ready) -> bool:
        return self._high(valid) and self._high(ready)

    async def _run(self):
        dut = self.dut
        channels = (
            ("AR", dut.S_AXI_ARVALID, dut.S_AXI_ARREADY),
            ("R", dut.S_AXI_RVALID, dut.S_AXI_RREADY),
            ("AW", dut.S_AXI_AWVALID, dut.S_AXI_AWREADY),
            ("W", dut.S_AXI_WVALID, dut.S_AXI_WREADY),
            ("B", dut.S_AXI_BVALID, dut.S_AXI_BREADY),
        )
        while True:
            # Sample at the clock edge, before combinational logic reacts to it.
            await RisingEdge(dut.sAxiClk)
            for name, valid, ready in channels:
                if self._handshake(valid, ready):
                    self.counts[name] += 1


class TB:
    def __init__(self, dut, drive_master=True):
        self.dut = dut
        self.common_clk = COMMON_CLK
        self.pipe_stages = int(os.environ["PIPE_STAGES_G"])
        self.reset_active = env_sl("RST_POLARITY_G", default=1)
        self.m_clk = None

        if self.common_clk:
            start_lockstep_clocks(dut.sAxiClk, dut.mAxiClk, period_ns=6.0)
        else:
            cocotb.start_soon(Clock(dut.sAxiClk, 8.0, unit="ns").start())
            # Gateable so the remote-reset test can hold the master domain still.
            self.m_clk = GatedClock(dut.mAxiClk, 5.0)

        dut.sAxiClkRst.setimmediatevalue(self.reset_active_value())
        dut.mAxiClkRst.setimmediatevalue(self.reset_active_value())

        if drive_master:
            self.axil = AxiLiteMaster(
                bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
                clock=dut.sAxiClk,
                reset=dut.sAxiClkRst,
                reset_active_level=bool(self.reset_active),
            )
        else:
            # Channel level tests drive the slave side port by hand, so the
            # cocotbext master must not be driving the same signals.
            self.axil = None
            for signal in (
                dut.S_AXI_AWADDR, dut.S_AXI_AWPROT, dut.S_AXI_AWVALID,
                dut.S_AXI_WDATA, dut.S_AXI_WSTRB, dut.S_AXI_WVALID,
                dut.S_AXI_BREADY,
                dut.S_AXI_ARADDR, dut.S_AXI_ARPROT, dut.S_AXI_ARVALID,
                dut.S_AXI_RREADY,
            ):
                signal.setimmediatevalue(0)

        self.slave = SimpleAxiLiteSlave(dut, self.reset_active)
        self.source = SourcePortMonitor(dut)

    def reset_active_value(self) -> int:
        return self.reset_active

    def reset_inactive_value(self) -> int:
        return 1 - self.reset_active

    async def settle(self):
        await Timer(1, unit="ns")

    async def s_cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.sAxiClk)
            await self.settle()

    async def m_cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.mAxiClk)
            await self.settle()

    async def write(self, addr, payload):
        # Every slave-side access is bounded; a bridge that never answers is a
        # failure, not a reason to stall the regression.
        return await with_timeout(
            self.axil.write(addr, payload), TXN_TIMEOUT_US, "us"
        )

    async def read(self, addr, length):
        return await with_timeout(
            self.axil.read(addr, length), TXN_TIMEOUT_US, "us"
        )

    async def drive_handshake(self, valid, ready, what, limit=64):
        # Hold valid until the edge where ready is also high, sampling ready
        # before the clock edge so the check matches the transfer itself.
        valid.value = 1
        for _ in range(limit):
            await RisingEdge(self.dut.sAxiClk)
            accepted = int(ready.value) == 1
            await self.settle()
            if accepted:
                valid.value = 0
                return
        valid.value = 0
        raise AssertionError(f"{what} was never accepted")

    async def await_high(self, signal, what, limit=64):
        for _ in range(limit):
            await self.s_cycle()
            if int(signal.value) == 1:
                return
        raise AssertionError(f"{what} never asserted")

    async def consume(self, valid, ready, what, limit=128):
        # Mirror of drive_handshake for the response direction: raise ready until
        # the edge where valid is also high, then drop it again.
        ready.value = 1
        for _ in range(limit):
            await RisingEdge(self.dut.sAxiClk)
            taken = int(valid.value) == 1
            await self.settle()
            if taken:
                ready.value = 0
                await self.settle()
                return
        ready.value = 0
        raise AssertionError(f"{what} was never returned")

    async def reset(self):
        # Hold both domains in reset together so the bridge and RAM start from
        # a known empty state before each scenario.
        self.dut.sAxiClkRst.setimmediatevalue(self.reset_active_value())
        self.dut.mAxiClkRst.setimmediatevalue(self.reset_active_value())
        await self.s_cycle(3)
        await self.m_cycle(3)
        if self.common_clk:
            self.dut.sAxiClkRst.value = self.reset_inactive_value()
            self.dut.mAxiClkRst.value = self.reset_inactive_value()
        else:
            # Release the destination side first so the source-side bridge does
            # not interpret the first post-reset transfer as a remote-domain
            # reset error.
            self.dut.mAxiClkRst.value = self.reset_inactive_value()
            await self.m_cycle(6)
            self.dut.sAxiClkRst.value = self.reset_inactive_value()
        await self.s_cycle(8)
        await self.m_cycle(8)


class SimpleAxiLiteSlave:
    def __init__(self, dut, reset_active):
        self.dut = dut
        self.reset_active = reset_active
        self.mem = {}
        # Ordered record of everything this slave accepted, so the test can
        # prove a rejected request never reached the far side of the bridge.
        self.handshakes = []

        dut.M_AXI_AWREADY.setimmediatevalue(0)
        dut.M_AXI_WREADY.setimmediatevalue(0)
        dut.M_AXI_BVALID.setimmediatevalue(0)
        dut.M_AXI_BRESP.setimmediatevalue(0)
        dut.M_AXI_ARREADY.setimmediatevalue(0)
        dut.M_AXI_RVALID.setimmediatevalue(0)
        dut.M_AXI_RRESP.setimmediatevalue(0)
        dut.M_AXI_RDATA.setimmediatevalue(0)

        cocotb.start_soon(self._run_write())
        cocotb.start_soon(self._run_read())

    def in_reset(self) -> bool:
        try:
            return int(self.dut.mAxiClkRst.value) == self.reset_active
        except ValueError:
            return True

    def addresses_seen(self, channel) -> list:
        return [value for kind, value in self.handshakes if kind == channel]

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.mAxiClk)
            await Timer(1, unit="ns")

    async def _wait_while_reset(self):
        while self.in_reset():
            self.dut.M_AXI_AWREADY.value = 0
            self.dut.M_AXI_WREADY.value = 0
            self.dut.M_AXI_BVALID.value = 0
            self.dut.M_AXI_ARREADY.value = 0
            self.dut.M_AXI_RVALID.value = 0
            await self.cycle(1)

    async def _run_write(self):
        while True:
            await self._wait_while_reset()

            while not int(self.dut.M_AXI_AWVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            awaddr = int(self.dut.M_AXI_AWADDR.value)
            self.dut.M_AXI_AWREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_AWREADY.value = 0
            self.handshakes.append(("AW", awaddr))

            while not int(self.dut.M_AXI_WVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            wdata = int(self.dut.M_AXI_WDATA.value)
            wstrb = int(self.dut.M_AXI_WSTRB.value)
            prior = self.mem.get(awaddr, 0).to_bytes(4, "little")
            next_bytes = bytearray(prior)
            write_bytes = wdata.to_bytes(4, "little")
            for index in range(4):
                if wstrb & (1 << index):
                    next_bytes[index] = write_bytes[index]
            self.mem[awaddr] = int.from_bytes(next_bytes, "little")

            self.dut.M_AXI_WREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_WREADY.value = 0
            self.handshakes.append(("W", wdata))

            self.dut.M_AXI_BRESP.value = int(AxiResp.OKAY)
            self.dut.M_AXI_BVALID.value = 1
            while not int(self.dut.M_AXI_BREADY.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)
            await self.cycle(1)
            self.dut.M_AXI_BVALID.value = 0

    async def _run_read(self):
        while True:
            await self._wait_while_reset()

            while not int(self.dut.M_AXI_ARVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            araddr = int(self.dut.M_AXI_ARADDR.value)
            self.dut.M_AXI_ARREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_ARREADY.value = 0
            self.handshakes.append(("AR", araddr))

            self.dut.M_AXI_RDATA.value = self.mem.get(araddr, 0)
            self.dut.M_AXI_RRESP.value = int(AxiResp.OKAY)
            self.dut.M_AXI_RVALID.value = 1
            while not int(self.dut.M_AXI_RREADY.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)
            await self.cycle(1)
            self.dut.M_AXI_RVALID.value = 0


@cocotb.test()
async def bridge_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()

    transactions = [
        (0x000, b"\x11\x22\x33\x44"),
        (0x008, b"\xAA\xBB"),
        (0x010, b"\x10\x20\x30\x40"),
    ]

    # Sweep a few aligned accesses so the test proves the slave-side bus can
    # drive data through the bridge into the master-side backing RAM.
    for addr, payload in transactions:
        wr_txn = await tb.write(addr, payload)
        assert wr_txn.resp == AxiResp.OKAY
        assert tb.slave.mem[addr].to_bytes(4, "little")[: len(payload)] == payload

        rd_txn = await tb.read(addr, len(payload))
        assert rd_txn.resp == AxiResp.OKAY
        assert rd_txn.data == payload


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    baseline = b"\x5A\xA5\xC3\x3C"
    wr_txn = await tb.write(0x020, baseline)
    assert wr_txn.resp == AxiResp.OKAY
    rd_txn = await tb.read(0x020, len(baseline))
    assert rd_txn.resp == AxiResp.OKAY
    assert rd_txn.data == baseline

    # In common-clock mode the DUT reduces to direct pass-through, so the
    # reset coverage is restart-and-recover rather than remote-domain error
    # shaping.
    self_reset = tb.reset_active_value()
    self_release = tb.reset_inactive_value()
    tb.dut.sAxiClkRst.value = self_reset
    tb.dut.mAxiClkRst.value = self_reset
    await tb.s_cycle(3)
    tb.dut.sAxiClkRst.value = self_release
    tb.dut.mAxiClkRst.value = self_release
    # Both resets are released together here, so in the asynchronous case each
    # one still has to cross into the opposite domain before the bridge stops
    # reporting the remote side as reset. Wait out that release on both clocks,
    # otherwise the next access is legitimately answered with AXI_ERROR_RESP_G.
    await tb.s_cycle(16)
    await tb.m_cycle(16)

    recovery = b"\x89\x67\x45\x23"
    wr_txn = await tb.write(0x024, recovery)
    assert wr_txn.resp == AxiResp.OKAY
    rd_txn = await tb.read(0x024, len(recovery))
    assert rd_txn.resp == AxiResp.OKAY
    assert rd_txn.data == recovery


@cocotb.test(skip=COMMON_CLK)
async def remote_reset_ghost_test(dut):
    """A transaction rejected while the remote domain is reset must never run.

    `COMMON_CLK_G=true` reduces the bridge to direct pass-through with no request
    FIFOs, so this scenario only exists in the asynchronous configuration.
    """
    tb = TB(dut)
    await tb.reset()

    # Prove the bridge is healthy before the fault is injected.
    baseline = b"\x01\x02\x03\x04"
    wr_txn = await tb.write(BASELINE_ADDR, baseline)
    assert wr_txn.resp == AxiResp.OKAY
    rd_txn = await tb.read(BASELINE_ADDR, len(baseline))
    assert rd_txn.resp == AxiResp.OKAY
    assert rd_txn.data == baseline

    # Let the downstream slave model return to its idle state before its clock
    # is taken away.
    await tb.m_cycle(4)

    # Stop the master clock, then assert only the master reset. The slave domain
    # keeps running, so the bridge has to fail these accesses locally.
    tb.m_clk.stop()
    tb.dut.mAxiClkRst.value = tb.reset_active_value()

    # Give mAxiClkRst time to synchronize into the slave domain.
    await tb.s_cycle(16)

    downstream_before = list(tb.slave.handshakes)
    mem_before = dict(tb.slave.mem)

    # Both accesses must fail fast, inside the bounded transaction timeout.
    rejected = b"\xDE\xAD\xBE\xEF"
    wr_txn = await tb.write(REJECTED_WRITE_ADDR, rejected)
    assert wr_txn.resp == AxiResp.SLVERR, (
        f"write during remote reset returned {wr_txn.resp!r}, expected SLVERR"
    )
    rd_txn = await tb.read(REJECTED_READ_ADDR, 4)
    assert rd_txn.resp == AxiResp.SLVERR, (
        f"read during remote reset returned {rd_txn.resp!r}, expected SLVERR"
    )

    # Nothing can have reached the downstream slave yet: its clock is stopped.
    assert tb.slave.handshakes == downstream_before, (
        "downstream slave saw activity while mAxiClk was stopped"
    )
    assert tb.slave.mem == mem_before, (
        "downstream memory changed while mAxiClk was stopped"
    )

    # Restart the master clock while the master reset is still asserted.
    tb.m_clk.start()
    await tb.m_cycle(8)

    # Release the master reset and let both sides finish coming out of reset.
    tb.dut.mAxiClkRst.value = tb.reset_inactive_value()
    await tb.m_cycle(16)
    await tb.s_cycle(16)

    # The rejected requests must not have been replayed downstream.
    replayed = [
        entry
        for entry in tb.slave.handshakes[len(downstream_before):]
        if entry in (("AW", REJECTED_WRITE_ADDR), ("AR", REJECTED_READ_ADDR))
    ]
    assert not replayed, (
        f"request rejected with SLVERR was replayed downstream after recovery: {replayed}"
    )
    assert REJECTED_WRITE_ADDR not in tb.slave.mem, (
        "write rejected with SLVERR modified downstream memory after recovery"
    )
    assert tb.slave.mem == mem_before, (
        "downstream memory changed after recovery without a new transaction"
    )

    # A fresh access must still work, and must not consume a stale response left
    # over from the rejected pair.
    recovery = b"\x0F\x1E\x2D\x3C"
    wr_txn = await tb.write(RECOVERY_ADDR, recovery)
    assert wr_txn.resp == AxiResp.OKAY
    rd_txn = await tb.read(RECOVERY_ADDR, len(recovery))
    assert rd_txn.resp == AxiResp.OKAY
    assert rd_txn.data == recovery
    assert tb.slave.mem[RECOVERY_ADDR].to_bytes(4, "little") == recovery

    # Every response the bridge produced has to map to a request it accepted.
    counts = tb.source.counts
    assert counts["R"] == counts["AR"], (
        f"bridge returned {counts['R']} read responses for {counts['AR']} accepted "
        "read requests"
    )
    assert counts["B"] == counts["AW"], (
        f"bridge returned {counts['B']} write responses for {counts['AW']} accepted "
        "write addresses"
    )
    assert counts["W"] == counts["AW"], (
        f"bridge accepted {counts['W']} write data beats for {counts['AW']} accepted "
        "write addresses"
    )


@cocotb.test(skip=COMMON_CLK)
async def remote_reset_write_order_test(dut):
    """A local write response must wait for both AW and W, arriving separately.

    The bridge carries the write address and the write data in separate FIFOs, so
    the error response has to be paired explicitly instead of being asserted as
    soon as the remote domain resets.
    """
    tb = TB(dut, drive_master=False)
    await tb.reset()

    # Hold the remote domain still and in reset.
    tb.m_clk.stop()
    dut.mAxiClkRst.value = tb.reset_active_value()
    await tb.s_cycle(16)

    # Present the write address on its own.
    dut.S_AXI_AWADDR.value = REJECTED_WRITE_ADDR
    await tb.drive_handshake(
        dut.S_AXI_AWVALID, dut.S_AXI_AWREADY, "AW during remote reset"
    )

    # No write data has been accepted yet, so there must be no write response.
    for _ in range(8):
        await tb.s_cycle()
        assert int(dut.S_AXI_BVALID.value) == 0, (
            "write response asserted before any write data was accepted"
        )

    # Now present the write data.
    dut.S_AXI_WDATA.value = 0xA5A5A5A5
    dut.S_AXI_WSTRB.value = 0xF
    await tb.drive_handshake(
        dut.S_AXI_WVALID, dut.S_AXI_WREADY, "W during remote reset"
    )

    # The paired response must appear, and must carry the error code.
    await tb.await_high(dut.S_AXI_BVALID, "write response during remote reset")
    assert int(dut.S_AXI_BRESP.value) == int(AxiResp.SLVERR), (
        f"write response during remote reset carried {int(dut.S_AXI_BRESP.value)}, "
        f"expected {int(AxiResp.SLVERR)}"
    )

    # Accept it, then confirm a single write produced a single response.
    dut.S_AXI_BREADY.value = 1
    await tb.s_cycle()
    dut.S_AXI_BREADY.value = 0
    for _ in range(8):
        await tb.s_cycle()
        assert int(dut.S_AXI_BVALID.value) == 0, (
            "write response repeated for a single accepted write"
        )

    # The same pairing rule applies to reads: no response without an accepted AR.
    for _ in range(8):
        await tb.s_cycle()
        assert int(dut.S_AXI_RVALID.value) == 0, (
            "read response asserted with no read address accepted"
        )

    dut.S_AXI_ARADDR.value = REJECTED_READ_ADDR
    await tb.drive_handshake(
        dut.S_AXI_ARVALID, dut.S_AXI_ARREADY, "AR during remote reset"
    )
    await tb.await_high(dut.S_AXI_RVALID, "read response during remote reset")
    assert int(dut.S_AXI_RRESP.value) == int(AxiResp.SLVERR)

    dut.S_AXI_RREADY.value = 1
    await tb.s_cycle()
    dut.S_AXI_RREADY.value = 0
    for _ in range(8):
        await tb.s_cycle()
        assert int(dut.S_AXI_RVALID.value) == 0, (
            "read response repeated for a single accepted read"
        )

    # Nothing may have reached the master side, and nothing may be replayed once
    # the remote domain recovers.
    assert tb.slave.handshakes == [], (
        f"master side saw activity while held in reset: {tb.slave.handshakes}"
    )

    tb.m_clk.start()
    await tb.m_cycle(8)
    dut.mAxiClkRst.value = tb.reset_inactive_value()
    await tb.m_cycle(16)
    await tb.s_cycle(16)

    assert tb.slave.handshakes == [], (
        f"rejected request replayed downstream after recovery: {tb.slave.handshakes}"
    )
    assert tb.slave.mem == {}, (
        f"rejected write reached downstream memory: {tb.slave.mem}"
    )


@cocotb.test(skip=COMMON_CLK)
async def remote_reset_inflight_flush_test(dut):
    """A request queued before the remote reset must not survive it.

    The request FIFOs are written from the slave domain but drained from the
    master domain, so a transaction can already be sitting in them when
    mAxiClkRst asserts. Gating new requests is not enough; the queued one has to
    be discarded rather than replayed once the remote domain recovers.
    """
    tb = TB(dut, drive_master=False)
    await tb.reset()

    # Freeze the master domain while its reset is still released, so the bridge
    # accepts and queues the write but cannot forward it yet.
    tb.m_clk.stop()
    await tb.s_cycle(4)

    dut.S_AXI_AWADDR.value = REJECTED_WRITE_ADDR
    await tb.drive_handshake(
        dut.S_AXI_AWVALID, dut.S_AXI_AWREADY, "AW before remote reset"
    )
    dut.S_AXI_WDATA.value = 0xDEADBEEF
    dut.S_AXI_WSTRB.value = 0xF
    await tb.drive_handshake(
        dut.S_AXI_WVALID, dut.S_AXI_WREADY, "W before remote reset"
    )

    # The write is queued and still unanswered, and cannot have reached the far
    # side because that clock is stopped.
    assert int(dut.S_AXI_BVALID.value) == 0, (
        "write answered while the master domain was still expected to handle it"
    )
    assert tb.slave.handshakes == [], (
        f"master side saw activity with its clock stopped: {tb.slave.handshakes}"
    )

    # Now reset the remote domain underneath the queued write.
    dut.mAxiClkRst.value = tb.reset_active_value()
    await tb.s_cycle(16)

    # The bridge still owes a response for it, and it must be the error response.
    await tb.await_high(dut.S_AXI_BVALID, "write response after remote reset")
    assert int(dut.S_AXI_BRESP.value) == int(AxiResp.SLVERR), (
        f"queued write answered with {int(dut.S_AXI_BRESP.value)}, "
        f"expected {int(AxiResp.SLVERR)}"
    )
    dut.S_AXI_BREADY.value = 1
    await tb.s_cycle()
    dut.S_AXI_BREADY.value = 0

    # Recover and confirm the queued write was discarded, not replayed.
    tb.m_clk.start()
    await tb.m_cycle(8)
    dut.mAxiClkRst.value = tb.reset_inactive_value()
    await tb.m_cycle(16)
    await tb.s_cycle(16)

    assert tb.slave.handshakes == [], (
        f"write queued before the remote reset was replayed downstream: "
        f"{tb.slave.handshakes}"
    )
    assert tb.slave.mem == {}, (
        f"write queued before the remote reset reached memory: {tb.slave.mem}"
    )


@cocotb.test(skip=COMMON_CLK)
async def remote_reset_orphan_pairing_test(dut):
    """An orphaned write address must not pair with a later write data beat.

    The write address and the write data cross the bridge in separate FIFOs, so a
    write that straddles the remote reset can leave an address queued with no
    data behind it. If that address is not discarded, the next write's data is
    committed to the wrong location.
    """
    tb = TB(dut, drive_master=False)
    await tb.reset()

    # Queue the address only, with the master domain frozen.
    tb.m_clk.stop()
    await tb.s_cycle(4)
    dut.S_AXI_AWADDR.value = REJECTED_WRITE_ADDR
    await tb.drive_handshake(dut.S_AXI_AWVALID, dut.S_AXI_AWREADY, "orphan AW")

    # Reset the remote domain with that address queued and no data sent yet.
    dut.mAxiClkRst.value = tb.reset_active_value()
    await tb.s_cycle(16)

    # Supply the data now. The bridge answers locally and both halves are dropped.
    dut.S_AXI_WDATA.value = 0xDEADBEEF
    dut.S_AXI_WSTRB.value = 0xF
    await tb.drive_handshake(
        dut.S_AXI_WVALID, dut.S_AXI_WREADY, "W during remote reset"
    )
    await tb.await_high(dut.S_AXI_BVALID, "write response during remote reset")
    assert int(dut.S_AXI_BRESP.value) == int(AxiResp.SLVERR)
    dut.S_AXI_BREADY.value = 1
    await tb.s_cycle()
    dut.S_AXI_BREADY.value = 0

    # Recover.
    tb.m_clk.start()
    await tb.m_cycle(8)
    dut.mAxiClkRst.value = tb.reset_inactive_value()
    await tb.m_cycle(16)
    await tb.s_cycle(16)

    # Issue a fresh write to a different address.
    dut.S_AXI_AWADDR.value = RECOVERY_ADDR
    await tb.drive_handshake(dut.S_AXI_AWVALID, dut.S_AXI_AWREADY, "recovery AW")
    dut.S_AXI_WDATA.value = 0x0F1E2D3C
    dut.S_AXI_WSTRB.value = 0xF
    await tb.drive_handshake(dut.S_AXI_WVALID, dut.S_AXI_WREADY, "recovery W")

    # Let the master side act before checking, so a misdirected write is reported
    # as exactly that rather than as a missing response.
    await tb.m_cycle(64)

    assert ("AW", REJECTED_WRITE_ADDR) not in tb.slave.handshakes, (
        f"abandoned write address reached the master side: {tb.slave.handshakes}"
    )
    assert REJECTED_WRITE_ADDR not in tb.slave.mem, (
        f"recovery write data was committed to the abandoned address: {tb.slave.mem}"
    )
    assert tb.slave.mem == {RECOVERY_ADDR: 0x0F1E2D3C}, (
        f"recovery write did not land correctly: {tb.slave.mem}"
    )

    await tb.await_high(dut.S_AXI_BVALID, "recovery write response", limit=128)
    assert int(dut.S_AXI_BRESP.value) == int(AxiResp.OKAY)
    dut.S_AXI_BREADY.value = 1
    await tb.s_cycle()
    dut.S_AXI_BREADY.value = 0


@cocotb.test(skip=COMMON_CLK)
async def source_reset_stale_response_test(dut):
    """A response queued when the slave domain resets must be discarded.

    The response FIFOs are written from the master domain, so a completed
    response can still be queued when sAxiClkRst asserts. If it survives the
    reset, the next read after recovery consumes it and returns another
    address's data.
    """
    tb = TB(dut, drive_master=False)
    await tb.reset()

    # Seed two addresses with distinct data.
    seeds = ((BASELINE_ADDR, 0x11111111), (RECOVERY_ADDR, 0x22222222))
    for addr, data in seeds:
        dut.S_AXI_AWADDR.value = addr
        await tb.drive_handshake(
            dut.S_AXI_AWVALID, dut.S_AXI_AWREADY, f"seed AW {addr:#05x}"
        )
        dut.S_AXI_WDATA.value = data
        dut.S_AXI_WSTRB.value = 0xF
        await tb.drive_handshake(
            dut.S_AXI_WVALID, dut.S_AXI_WREADY, f"seed W {addr:#05x}"
        )
        await tb.await_high(dut.S_AXI_BVALID, f"seed B {addr:#05x}", limit=128)
        dut.S_AXI_BREADY.value = 1
        await tb.s_cycle()
        dut.S_AXI_BREADY.value = 0

    # Read one address but never take the response, so it sits in the response
    # FIFO on the slave side.
    dut.S_AXI_ARADDR.value = BASELINE_ADDR
    await tb.drive_handshake(dut.S_AXI_ARVALID, dut.S_AXI_ARREADY, "stale AR")
    await tb.await_high(dut.S_AXI_RVALID, "stale read response", limit=128)

    # Reset the slave domain with that response still queued.
    dut.sAxiClkRst.value = tb.reset_active_value()
    await tb.s_cycle(8)
    dut.sAxiClkRst.value = tb.reset_inactive_value()
    await tb.s_cycle(16)
    await tb.m_cycle(16)

    # A fresh read must return its own data, not the abandoned response.
    dut.S_AXI_ARADDR.value = RECOVERY_ADDR
    await tb.drive_handshake(dut.S_AXI_ARVALID, dut.S_AXI_ARREADY, "recovery AR")
    await tb.await_high(dut.S_AXI_RVALID, "recovery read response", limit=128)
    assert int(dut.S_AXI_RDATA.value) == 0x22222222, (
        f"read after a slave-domain reset returned "
        f"{int(dut.S_AXI_RDATA.value):#010x}, expected 0x22222222 for its own "
        "address"
    )


@cocotb.test(skip=COMMON_CLK)
async def source_reset_clears_outstanding_test(dut):
    """A slave-domain reset must clear the bridge's outstanding transaction state.

    The outstanding counts decide whether the bridge owes a local error response.
    If a slave-domain reset leaves them stale, the next remote reset answers a
    transaction the slave side already abandoned, which is a response with no
    request behind it.

    This is the case that actually exercises the reset path of the registered
    logic, through the sequential process when RST_ASYNC_G is true and through
    the combinational next-state path when it is false.
    """
    tb = TB(dut, drive_master=False)
    await tb.reset()

    # Freeze the master domain so no real response can ever be produced, then
    # leave a read accepted and unanswered.
    tb.m_clk.stop()
    await tb.s_cycle(4)
    dut.S_AXI_ARADDR.value = REJECTED_READ_ADDR
    await tb.drive_handshake(
        dut.S_AXI_ARVALID, dut.S_AXI_ARREADY, "AR before slave reset"
    )
    assert int(dut.S_AXI_RVALID.value) == 0, (
        "read answered while the master domain was frozen"
    )

    # Reset the slave domain. That abandons the read, so the bridge no longer
    # owes anything for it.
    dut.sAxiClkRst.value = tb.reset_active_value()
    await tb.s_cycle(8)
    dut.sAxiClkRst.value = tb.reset_inactive_value()
    await tb.s_cycle(16)

    # Now reset the remote domain, which puts the bridge into local-answer mode.
    dut.mAxiClkRst.value = tb.reset_active_value()
    await tb.s_cycle(16)

    # With the outstanding state cleared there is nothing to answer.
    for _ in range(16):
        await tb.s_cycle()
        assert int(dut.S_AXI_RVALID.value) == 0, (
            "bridge answered a read that was abandoned by the slave-domain reset"
        )
        assert int(dut.S_AXI_BVALID.value) == 0, (
            "bridge produced a write response with no write outstanding"
        )

    # And nothing may reach the master side once it recovers.
    tb.m_clk.start()
    await tb.m_cycle(8)
    dut.mAxiClkRst.value = tb.reset_inactive_value()
    await tb.m_cycle(16)
    await tb.s_cycle(16)
    assert tb.slave.handshakes == [], (
        f"abandoned read reached the master side after recovery: "
        f"{tb.slave.handshakes}"
    )


@cocotb.test(skip=COMMON_CLK)
async def single_outstanding_bound_test(dut):
    """The bridge allows one transaction per channel in flight, like the crossbar.

    AxiLiteCrossbar does not release a slave slot until the response completes,
    so AxiLiteAsync matches that bound. It enforces the bound with its own ready
    outputs rather than trusting the master to honour it, which is what lets the
    remote-reset responder be a single flag per channel and still answer exactly
    once per accepted request.
    """
    tb = TB(dut, drive_master=False)
    await tb.reset()

    # Normal operation: a second read must not be accepted while the first is
    # still unanswered.
    dut.S_AXI_RREADY.value = 0
    dut.S_AXI_ARADDR.value = BASELINE_ADDR
    await tb.drive_handshake(dut.S_AXI_ARVALID, dut.S_AXI_ARREADY, "first AR")

    dut.S_AXI_ARADDR.value = REJECTED_READ_ADDR
    dut.S_AXI_ARVALID.value = 1
    for _ in range(32):
        await tb.s_cycle()
        assert int(dut.S_AXI_ARREADY.value) == 0, (
            "bridge accepted a second read while the first was still unanswered"
        )
    dut.S_AXI_ARVALID.value = 0
    await tb.settle()

    # Answer the first read, after which the next one is accepted normally.
    await tb.await_high(dut.S_AXI_RVALID, "first read response", limit=128)
    await tb.consume(dut.S_AXI_RVALID, dut.S_AXI_RREADY, "first read response")

    dut.S_AXI_ARADDR.value = BASELINE_ADDR
    await tb.drive_handshake(dut.S_AXI_ARVALID, dut.S_AXI_ARREADY, "second AR")
    await tb.await_high(dut.S_AXI_RVALID, "second read response", limit=128)
    await tb.consume(dut.S_AXI_RVALID, dut.S_AXI_RREADY, "second read response")

    # The same bound applies to writes: no second address while one is pending.
    dut.S_AXI_AWADDR.value = BASELINE_ADDR
    await tb.drive_handshake(dut.S_AXI_AWVALID, dut.S_AXI_AWREADY, "first AW")
    dut.S_AXI_AWADDR.value = RECOVERY_ADDR
    dut.S_AXI_AWVALID.value = 1
    for _ in range(16):
        await tb.s_cycle()
        assert int(dut.S_AXI_AWREADY.value) == 0, (
            "bridge accepted a second write address while one was still pending"
        )
    dut.S_AXI_AWVALID.value = 0
    await tb.settle()
    dut.S_AXI_WDATA.value = 0x5A5A5A5A
    dut.S_AXI_WSTRB.value = 0xF
    await tb.drive_handshake(dut.S_AXI_WVALID, dut.S_AXI_WREADY, "first W")
    await tb.await_high(dut.S_AXI_BVALID, "first write response", limit=128)
    await tb.consume(dut.S_AXI_BVALID, dut.S_AXI_BREADY, "first write response")

    # Error mode: the same bound holds, and the accepted read is answered once.
    tb.m_clk.stop()
    dut.mAxiClkRst.value = tb.reset_active_value()
    await tb.s_cycle(16)

    dut.S_AXI_ARADDR.value = REJECTED_READ_ADDR
    await tb.drive_handshake(
        dut.S_AXI_ARVALID, dut.S_AXI_ARREADY, "AR during remote reset"
    )

    dut.S_AXI_ARVALID.value = 1
    for _ in range(16):
        await tb.s_cycle()
        assert int(dut.S_AXI_ARREADY.value) == 0, (
            "bridge accepted a second read during remote reset while the first "
            "was still unanswered"
        )
    dut.S_AXI_ARVALID.value = 0
    await tb.settle()

    await tb.await_high(dut.S_AXI_RVALID, "error response during remote reset")
    assert int(dut.S_AXI_RRESP.value) == int(AxiResp.SLVERR), (
        f"remote-reset read answered with {int(dut.S_AXI_RRESP.value)}, "
        f"expected {int(AxiResp.SLVERR)}"
    )
    await tb.consume(dut.S_AXI_RVALID, dut.S_AXI_RREADY, "error response")

    for _ in range(16):
        await tb.s_cycle()
        assert int(dut.S_AXI_RVALID.value) == 0, (
            "error response repeated for a single accepted read"
        )


PARAMETER_SWEEP = [
    parameter_case(
        "common_clk_sync",
        COMMON_CLK_G="true",
        PIPE_STAGES_G="0",
        NUM_ADDR_BITS_G="12",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "async_active_high",
        COMMON_CLK_G="false",
        PIPE_STAGES_G="0",
        NUM_ADDR_BITS_G="12",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    # Active LOW covers the reset-polarity handling in the bridge; the remote
    # reset comparisons are only exercised for one sense per case.
    parameter_case(
        "async_active_low",
        COMMON_CLK_G="false",
        PIPE_STAGES_G="0",
        NUM_ADDR_BITS_G="12",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'0'",
    ),
    # Asynchronous reset reaches the registered logic through the sequential
    # process instead of the combinational next-state path, so it needs its own
    # case to be executed at all.
    parameter_case(
        "async_rst_async",
        COMMON_CLK_G="false",
        PIPE_STAGES_G="0",
        NUM_ADDR_BITS_G="12",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
    ),
    # A non-zero PIPE_STAGES_G adds output registers to every channel FIFO and
    # widens the worst-case outstanding transaction count.
    parameter_case(
        "async_pipelined",
        COMMON_CLK_G="false",
        PIPE_STAGES_G="2",
        NUM_ADDR_BITS_G="12",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiLiteAsync(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiliteasyncipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/axi-lite/ip_integrator/AxiLiteAsyncIpIntegrator.vhd"],
        },
    )
