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
# - Sweep: Cover single and high-occupancy traffic, response/work-request
#   backpressure, engine stall/restart, partial and oversized frames, dynamic
#   lengths, partial-byte enables, retry replay, ring wrap, and counter reset.
# - Stimulus: Push deterministic 32-byte AXI Stream beats while a configurable
#   in-order engine peer accepts work requests, issues DMA reads, drains their
#   responses, and returns work completions.
# - Checks: Scoreboard every replayed byte, first/last marker, byte enable,
#   opcode/immediate field, error indication, work-request length, and relevant
#   AXI-Lite success/error/oversize/frame counters.
# - Timing: Engine latency and backpressure build FIFO occupancy deliberately;
#   transaction progress has cycle limits and each liveness scenario has a
#   simulated-time watchdog so a datapath wedge fails diagnostically.
#
# RoCEv2AxiStreamRdma buffers an inbound AXI-Stream payload in a store-and-forward
# repack FIFO, issues one RDMA-SEND-with-immediate work request per complete packet,
# serves the engine's DMA read by draining that packet into the 290-bit dmaReadResp, counts
# work completions. This bench emulates the surf RoCEv2 engine side:
#   * accept each workReq (one-WR-at-a-time, in-order RC),
#   * after a configurable latency issue exactly one dmaReadReq for it,
#   * drain the multi-beat dmaReadResp (checking the byte-order/isFirst/isLast/byteEn pack),
#   * issue a success workComp.
# The slave payload is pushed back-to-back (full rate). The engine latency is the knob
# that makes the source outrun the drain so >=2 complete packets pile up in the FIFO —
# the exact occupancy regime that hard-wedges the (pre-consolidation) lockstep design on
# hardware. A watchdog turns any such wedge into a test timeout. The scoreboard verifies
# every drained beat against endianSwap(pushed-beat) with correct isFirst/isLast framing,
# so a lane-swap, drop, duplicate, or reorder all fail loudly.

from __future__ import annotations

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test

WRAPPER_PATH = "ethernet/RoCEv2/wrappers/RoCEv2AxiStreamRdmaCoreWrapper.vhd"

# AXI-Lite register map (must match RoCEv2AxiStreamRdma.vhd)
REG_DISPATCH_ENABLE = 0x000
REG_MAXSIZE = 0x004  # RO readback of the FW per-SEND byte cap (MAX_BEATS_C*32)
REG_RKEY = 0x008
REG_LKEY = 0x00C
REG_SQPN = 0x010
REG_REMADDR = 0x018  # 64-bit (0x018/0x01C)
REG_ADDRWRAP = 0x020
REG_SUCCESS = 0x100
REG_UNSUCCESS = 0x104
REG_RESET = 0x108
REG_OVERSIZE = 0x10C  # RO: count of over-cap frames dropped
REG_MON_FRAMECNT = 0x200  # AxiStreamMon frameCnt (64-bit; low word at 0x200)

BEAT_BYTES = 32
CLK_NS = 6.4
DATA_MASK = (1 << 256) - 1
DMA_RESPONSE_TIMEOUT_CYCLES = 65_536
PROGRESS_TIMEOUT_CYCLES = 65_536


def beat_pattern(counter: int) -> bytes:
    """32-byte beat: low 4 bytes = little-endian counter, upper bytes zero."""
    b = bytearray(BEAT_BYTES)
    b[0:4] = (counter & 0xFFFFFFFF).to_bytes(4, "little")
    return bytes(b)


def endian_swap_32(data: bytes) -> int:
    """Reverse the 32 byte lanes (matches the DUT's endianSwap) -> int."""
    return int.from_bytes(bytes(reversed(data)), "little")


class Cfg:
    def __init__(self, *, readreq_latency=20, workcomp_latency=4, resp_backpressure=0,
                 workreq_backpressure=0, stall_at=None, stall_cycles=0):
        self.readreq_latency = readreq_latency        # cycles WR-accept -> dmaReadReq (builds occupancy)
        self.workcomp_latency = workcomp_latency      # cycles drain-done -> workComp
        self.resp_backpressure = resp_backpressure    # de-assert resp ready every Nth cycle (0 = never)
        self.workreq_backpressure = workreq_backpressure  # cycles of workReq ready-low before each accept
        self.stall_at = stall_at                      # packet index at which the engine fully stalls
        self.stall_cycles = stall_cycles              # duration of that stall (models host-can't-keep-up)


class Scoreboard:
    def __init__(self, beats_per_packet: int):
        self.bpp = beats_per_packet
        self.ctr = 0
        self.packets = 0
        self.errors: list = []

    def record(self, beats, is_resp_err):
        idx = self.packets
        if is_resp_err:
            self.errors.append((idx, "isRespErr"))
        if len(beats) != self.bpp:
            self.errors.append((idx, f"beatcount={len(beats)} != {self.bpp}"))
        for i, (data, is_first, is_last) in enumerate(beats):
            exp = endian_swap_32(beat_pattern(self.ctr))
            self.ctr += 1
            if data != exp:
                self.errors.append((idx, i, f"data 0x{data:064x} != 0x{exp:064x}"))
            if bool(is_first) != (i == 0):
                self.errors.append((idx, i, f"isFirst={is_first}"))
            if bool(is_last) != (i == len(beats) - 1):
                self.errors.append((idx, i, f"isLast={is_last}"))
        self.packets += 1


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
        dut.rst.value = 1
        # TB-driven inputs to a known idle state
        dut.S_AXIS_TVALID.value = 0
        dut.S_AXIS_TDATA.value = 0
        dut.S_AXIS_TKEEP.value = 0
        dut.S_AXIS_TLAST.value = 0
        dut.M_WORKREQ_READY.value = 0
        dut.S_DMAREADREQ_VALID.value = 0
        dut.S_DMAREADREQ_INITIATOR.value = 0
        dut.S_DMAREADREQ_SQPN.value = 0
        dut.S_DMAREADREQ_WRID.value = 0
        dut.S_DMAREADREQ_STARTADDR.value = 0
        dut.S_DMAREADREQ_LEN.value = 0
        dut.S_DMAREADREQ_MRIDX.value = 0
        dut.M_DMAREADRESP_READY.value = 0
        dut.S_WORKCOMP_VALID.value = 0
        dut.S_WORKCOMP_STATUS.value = 0
        dut.S_WORKCOMP_ID.value = 0

    async def _edge(self):
        await sample_after_tpd(self.dut.clk)

    async def _wait_asserted(self, signal, name: str) -> None:
        for _ in range(PROGRESS_TIMEOUT_CYCLES):
            if int(signal.value):
                return
            await self._edge()
        raise AssertionError(
            f"Timed out after {PROGRESS_TIMEOUT_CYCLES} cycles waiting for {name}"
        )

    async def reset(self):
        self.dut.rst.value = 1
        for _ in range(8):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        for _ in range(4):
            await RisingEdge(self.dut.clk)
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXIL"), self.dut.clk, self.dut.rst)

    async def configure(self, length_bytes: int, *, addrwrap: int = 0x0001_0000):
        # length_bytes is informational only: the FW derives each SEND's length from
        # the inbound tLast (FILL.slotLen), and 0x04 is a read-only readback of the
        # per-SEND cap -- there is no writable length register. RKey/RemAddr are legacy
        # RETH registers, unused by RDMA-SEND (the FW drives rAddr/rKey to 0); written
        # here only to prove they are harmless. addrwrap still wraps the free-running
        # immDt slot field. Default large -> no early wrap.
        await axil_write_u32(self.axil, REG_RKEY, 0x0000_1234)
        await axil_write_u32(self.axil, REG_LKEY, 0x0000_5678)
        await axil_write_u32(self.axil, REG_SQPN, 0x10)
        await axil_write_u32(self.axil, REG_REMADDR, 0)
        await axil_write_u32(self.axil, REG_REMADDR + 4, 0)
        await axil_write_u32(self.axil, REG_ADDRWRAP, addrwrap)
        await axil_write_u32(self.axil, REG_DISPATCH_ENABLE, 1)

    # --- slave payload source (full rate, back-to-back) -------------------------
    async def push_packets(self, num_packets: int, beats_per_packet: int):
        dut = self.dut
        ctr = 0
        for _ in range(num_packets):
            for b in range(beats_per_packet):
                dut.S_AXIS_TDATA.value = int.from_bytes(beat_pattern(ctr), "little")
                dut.S_AXIS_TKEEP.value = (1 << BEAT_BYTES) - 1
                dut.S_AXIS_TLAST.value = 1 if b == beats_per_packet - 1 else 0
                dut.S_AXIS_TVALID.value = 1
                ctr += 1
                await self._edge()
                await self._wait_asserted(dut.S_AXIS_TREADY, "S_AXIS_TREADY")
        dut.S_AXIS_TVALID.value = 0
        dut.S_AXIS_TLAST.value = 0

    async def push_partial(self, nbeats: int):
        """Drive `nbeats` of a packet with NO tLast, then idle — leaves a partial
        packet stranded in the store-and-forward FIFO (models the source being cut
        mid-frame when TxEn drops)."""
        dut = self.dut
        for b in range(nbeats):
            dut.S_AXIS_TDATA.value = int.from_bytes(beat_pattern(0xDEAD_0000 + b), "little")
            dut.S_AXIS_TKEEP.value = (1 << BEAT_BYTES) - 1
            dut.S_AXIS_TLAST.value = 0
            dut.S_AXIS_TVALID.value = 1
            await self._edge()
            await self._wait_asserted(dut.S_AXIS_TREADY, "S_AXIS_TREADY")
        dut.S_AXIS_TVALID.value = 0

    # --- engine emulator (single, in-order) -------------------------------------
    async def _accept_workreq(self, backpressure=0):
        dut = self.dut
        # Hold ready low for `backpressure` cycles (engine busy / send queue full).
        dut.M_WORKREQ_READY.value = 0
        for _ in range(backpressure):
            await RisingEdge(dut.clk)
        dut.M_WORKREQ_READY.value = 1
        await self._edge()
        await self._wait_asserted(dut.M_WORKREQ_VALID, "M_WORKREQ_VALID")
        wr = {
            "id": int(dut.M_WORKREQ_ID.value),
            "opcode": int(dut.M_WORKREQ_OPCODE.value),
            "len": int(dut.M_WORKREQ_LEN.value),
            "raddr": int(dut.M_WORKREQ_RADDR.value),
            "rkey": int(dut.M_WORKREQ_RKEY.value),
            "immdt": int(dut.M_WORKREQ_IMMDT.value),
        }
        dut.M_WORKREQ_READY.value = 0
        return wr

    async def _issue_dmareadreq(self, wr):
        dut = self.dut
        dut.S_DMAREADREQ_VALID.value = 1
        dut.S_DMAREADREQ_LEN.value = wr["len"] & 0x1FFF
        dut.S_DMAREADREQ_WRID.value = wr["id"]
        dut.S_DMAREADREQ_SQPN.value = 0x10
        await self._edge()
        await self._wait_asserted(dut.S_DMAREADREQ_READY, "S_DMAREADREQ_READY")
        dut.S_DMAREADREQ_VALID.value = 0

    async def _drain_resp(self, cfg):
        dut = self.dut
        beats = []
        is_err = 0
        for n in range(DMA_RESPONSE_TIMEOUT_CYCLES):
            # optional backpressure
            if cfg.resp_backpressure and (n % cfg.resp_backpressure == cfg.resp_backpressure - 1):
                dut.M_DMAREADRESP_READY.value = 0
            else:
                dut.M_DMAREADRESP_READY.value = 1
            await self._edge()
            if int(dut.M_DMAREADRESP_VALID.value) == 1 and int(dut.M_DMAREADRESP_READY.value) == 1:
                ds = int(dut.M_DMAREADRESP_DATASTREAM.value)
                is_err |= int(dut.M_DMAREADRESP_ISRESPERR.value)
                data = (ds >> 34) & DATA_MASK
                is_first = (ds >> 1) & 1
                is_last = ds & 1
                beats.append((data, is_first, is_last))
                if is_last:
                    break
        else:
            dut.M_DMAREADRESP_READY.value = 0
            raise AssertionError(
                "Timed out waiting for final DMA read response beat; "
                f"received {len(beats)} beats"
            )
        dut.M_DMAREADRESP_READY.value = 0
        return beats, is_err

    async def _issue_workcomp(self, wr):
        dut = self.dut
        dut.S_WORKCOMP_VALID.value = 1
        dut.S_WORKCOMP_STATUS.value = 0
        dut.S_WORKCOMP_ID.value = wr["id"]
        await self._edge()
        await self._wait_asserted(dut.S_WORKCOMP_READY, "S_WORKCOMP_READY")
        dut.S_WORKCOMP_VALID.value = 0

    async def engine(self, cfg, sb=None):
        """Lifetime agent: service RDMA work until its owning test cancels it."""
        idx = 0
        while True:
            wr = await self._accept_workreq(cfg.workreq_backpressure)
            # Optional full engine stall mid-run (models host that cannot keep up):
            # the DUT must hold its packet(s) and resume cleanly — never wedge.
            if cfg.stall_at is not None and idx == cfg.stall_at:
                for _ in range(cfg.stall_cycles):
                    await RisingEdge(self.dut.clk)
            for _ in range(cfg.readreq_latency):
                await RisingEdge(self.dut.clk)
            await self._issue_dmareadreq(wr)
            beats, is_err = await self._drain_resp(cfg)
            if sb is not None:
                sb.record(beats, is_err)
            for _ in range(cfg.workcomp_latency):
                await RisingEdge(self.dut.clk)
            await self._issue_workcomp(wr)
            idx += 1


async def _run(dut, *, cfg, num_packets, beats_per_packet, watchdog_ns):
    tb = TB(dut)
    await tb.reset()
    await tb.configure(beats_per_packet * BEAT_BYTES)
    sb = Scoreboard(beats_per_packet)
    engine_task = cocotb.start_soon(tb.engine(cfg, sb))
    producer_task = cocotb.start_soon(tb.push_packets(num_packets, beats_per_packet))

    async def wait_done():
        while sb.packets < num_packets:
            await RisingEdge(dut.clk)

    # A wedge in the DUT stalls dmaReadResp -> wait_done never completes -> timeout.
    try:
        await with_timeout(wait_done(), watchdog_ns, "ns")
        await producer_task

        for _ in range(64):  # let the final workComp settle
            await RisingEdge(dut.clk)
        succ = await axil_read_u32(tb.axil, REG_SUCCESS)
        unsucc = await axil_read_u32(tb.axil, REG_UNSUCCESS)

        assert not sb.errors, f"scoreboard errors (first 10): {sb.errors[:10]}"
        assert sb.packets == num_packets, f"only {sb.packets}/{num_packets} packets drained"
        assert succ == num_packets, f"SuccessCounter={succ} != {num_packets}"
        assert unsucc == 0, f"UnsuccessCounter={unsucc} != 0"
    finally:
        # The engine is a lifetime protocol peer; the producer is finite but
        # must also be cancelled if the watchdog aborts its transaction.
        engine_task.cancel()
        if not producer_task.done():
            producer_task.cancel()


@cocotb.test()
async def single_packet(dut):
    # Sanity: one packet, eager engine.
    await _run(dut, cfg=Cfg(readreq_latency=2, workcomp_latency=2),
               num_packets=1, beats_per_packet=4, watchdog_ns=50_000)


@cocotb.test()
async def full_rate_high_occupancy(dut):
    # The wedge regime: full-rate source + slow engine -> many packets pile up in the FIFO.
    # Pre-consolidation (lockstep) RTL hangs here -> watchdog timeout. Consolidated RTL passes.
    await _run(dut, cfg=Cfg(readreq_latency=40, workcomp_latency=4),
               num_packets=64, beats_per_packet=4, watchdog_ns=600_000)


@cocotb.test()
async def resp_backpressure(dut):
    # Engine backpressures dmaReadResp -> DUT must stall gracefully and resume (flow control).
    await _run(dut, cfg=Cfg(readreq_latency=16, workcomp_latency=4, resp_backpressure=3),
               num_packets=32, beats_per_packet=6, watchdog_ns=600_000)


@cocotb.test()
async def adversarial_engine(dut):
    # Everything backpressured at once + deep occupancy: workReq ready-low gaps,
    # long read latency, and periodic dmaReadResp backpressure.
    await _run(dut, cfg=Cfg(readreq_latency=50, workcomp_latency=6,
                            resp_backpressure=2, workreq_backpressure=8),
               num_packets=48, beats_per_packet=5, watchdog_ns=1_500_000)


@cocotb.test()
async def stall_and_resume(dut):
    # Engine fully stalls mid-stream (host can't keep up) while the source keeps
    # flooding -> FIFO saturates -> engine resumes. DUT must drain everything, no wedge.
    await _run(dut, cfg=Cfg(readreq_latency=20, workcomp_latency=4,
                            stall_at=4, stall_cycles=4000),
               num_packets=40, beats_per_packet=4, watchdog_ns=2_000_000)


@cocotb.test()
async def engine_teardown_then_restart(dut):
    # Reproduces the hardware wedge. The engine accepts a work request and then
    # tears down (stops issuing dmaReadReq) while that packet is in flight — exactly
    # what a QP teardown on GUI close does. The lockstep dispatch FSM is left
    # stranded in ST2_DRAIN waiting for a tLast drain that never comes. The
    # documented software restart (clear, then re-assert DispatchEnable — the
    # stop()/relaunch path) must recover the datapath: a fresh, healthy engine
    # must be able to dispatch + drain NEW packets.
    #
    # Pre-fix RTL: clearing DispatchEnable never reaches ST2_DRAIN, so dispatch
    # never re-arms -> no work requests -> the healthy engine waits forever ->
    # watchdog timeout (RED). The DispatchEnable=0 reset/flush fixes it.
    #
    # NOTE: while disarmed, sAxisSlave is forced ready (AXI_STREAM_SLAVE_FORCE_C) so
    # the upstream source DRAINS rather than stalls — any in-flight/buffered payload
    # is dropped across the disarm window. The restart property is therefore proven
    # with a FRESH packet flood started after re-arm (a paused source would have its
    # backlog drained, not preserved).
    tb = TB(dut)
    await tb.reset()
    bpp = 4
    await tb.configure(bpp * BEAT_BYTES)

    # Flood the source up to the teardown.
    flood = cocotb.start_soon(tb.push_packets(32, bpp))

    # Serve one packet fully (proves the path works before the teardown).
    wr = await tb._accept_workreq()
    for _ in range(20):
        await RisingEdge(dut.clk)
    await tb._issue_dmareadreq(wr)
    await tb._drain_resp(Cfg())
    for _ in range(4):
        await RisingEdge(dut.clk)
    await tb._issue_workcomp(wr)

    # Accept the NEXT work request, then "tear down": never drain it. Dispatch is
    # now stranded in ST2_DRAIN.
    await tb._accept_workreq()
    for _ in range(50):
        await RisingEdge(dut.clk)

    # Software restart: clear then re-assert DispatchEnable, zero the counters. The
    # disarm window drains/drops whatever the source was pushing, so kill the old
    # flood and idle the bus before re-arming.
    await axil_write_u32(tb.axil, REG_DISPATCH_ENABLE, 0)
    flood.cancel()
    dut.S_AXIS_TVALID.value = 0
    dut.S_AXIS_TLAST.value = 0
    for _ in range(20):
        await RisingEdge(dut.clk)
    await axil_write_u32(tb.axil, REG_RESET, 1)
    await axil_write_u32(tb.axil, REG_RESET, 0)
    await axil_write_u32(tb.axil, REG_DISPATCH_ENABLE, 1)

    # A fresh, healthy engine takes over, fed by a fresh packet flood.
    engine_task = cocotb.start_soon(tb.engine(Cfg(readreq_latency=10, workcomp_latency=4)))
    refill_task = cocotb.start_soon(tb.push_packets(32, bpp))

    async def wait_live(n):
        while int(await axil_read_u32(tb.axil, REG_SUCCESS)) < n:
            await RisingEdge(dut.clk)

    # Liveness: at least 4 completions after the restart, or the wedge stands.
    try:
        await with_timeout(wait_live(4), 600_000, "ns")
    finally:
        # Both agents intentionally run only for the liveness window.
        engine_task.cancel()
        refill_task.cancel()


@cocotb.test()
async def partial_packet_then_rearm(dut):
    # A partial packet (no tLast) stranded in the store-and-forward FIFO when the
    # source is cut mid-frame must not survive a restart. On the pre-fix RTL the
    # stale beats fuse with the first packet after re-arm (wrong length -> isRespErr
    # + data mismatch). The DispatchEnable=0 flush must discard it so the clean
    # stream validates exactly.
    tb = TB(dut)
    await tb.reset()
    bpp = 4
    await tb.configure(bpp * BEAT_BYTES)

    # Strand a 2-beat partial packet (no tLast) in the FIFO.
    await tb.push_partial(2)
    for _ in range(20):
        await RisingEdge(dut.clk)

    # Software restart: clear (flush) then re-assert DispatchEnable, zero counters.
    await axil_write_u32(tb.axil, REG_DISPATCH_ENABLE, 0)
    for _ in range(20):
        await RisingEdge(dut.clk)
    await axil_write_u32(tb.axil, REG_RESET, 1)
    await axil_write_u32(tb.axil, REG_RESET, 0)
    await axil_write_u32(tb.axil, REG_DISPATCH_ENABLE, 1)

    # The clean stream must validate exactly — the stale partial is gone.
    n = 8
    sb = Scoreboard(bpp)
    engine_task = cocotb.start_soon(tb.engine(Cfg(readreq_latency=8, workcomp_latency=4), sb))
    producer_task = cocotb.start_soon(tb.push_packets(n, bpp))

    async def wait_done():
        while sb.packets < n:
            await RisingEdge(dut.clk)

    try:
        await with_timeout(wait_done(), 600_000, "ns")
        await producer_task
        for _ in range(64):
            await RisingEdge(dut.clk)
        unsucc = int(await axil_read_u32(tb.axil, REG_UNSUCCESS))
        assert not sb.errors, f"partial packet fused into the stream: {sb.errors[:10]}"
        assert sb.packets == n, f"only {sb.packets}/{n} packets drained"
        assert unsucc == 0, f"UnsuccessCounter={unsucc} != 0"
    finally:
        engine_task.cancel()
        if not producer_task.done():
            producer_task.cancel()


@cocotb.test()
async def send_opcode_and_zeroed_reth(dut):
    # RDMA-SEND-with-immediate: the work request must carry opCode=0x3 and drive the
    # RETH fields (rAddr/rKey) to 0 (SEND is two-sided; the payload lands in the
    # host's posted recv-WQE buffer, not at a sender RETH address). This is the
    # change that makes the NIC RNR-NAK on a full RQ -> native FW<->NIC backpressure.
    tb = TB(dut)
    await tb.reset()
    bpp = 2
    n = 16
    await tb.configure(bpp * BEAT_BYTES)

    producer_task = cocotb.start_soon(tb.push_packets(n, bpp))
    for k in range(n):
        wr = await tb._accept_workreq()
        assert wr["opcode"] == 0x3, f"pkt {k}: opCode 0x{wr['opcode']:x} != 0x3 (SEND_WITH_IMM)"
        assert wr["raddr"] == 0, f"pkt {k}: rAddr 0x{wr['raddr']:x} != 0 (SEND has no RETH)"
        assert wr["rkey"] == 0, f"pkt {k}: rKey 0x{wr['rkey']:x} != 0 (SEND has no RETH)"
        # Service the WR so the lockstep dispatch advances to the next packet.
        for _ in range(4):
            await RisingEdge(dut.clk)
        await tb._issue_dmareadreq(wr)
        await tb._drain_resp(Cfg())
        for _ in range(2):
            await RisingEdge(dut.clk)
        await tb._issue_workcomp(wr)
    await producer_task


@cocotb.test()
async def immediate_carries_channel_and_slot(dut):
    # The immediate stamps bits[7:0]=channel (=1, the rogue stream channel) and
    # bits[31:8]=addrCount (the free-running n-mod-addrWrap ring position). With
    # RDMA-SEND the host locates the payload by the consumed recv-WR id, so the slot
    # field is informational only — but the channel byte still drives host routing,
    # and the free-running counter must still wrap correctly at addrWrapCount.
    tb = TB(dut)
    await tb.reset()
    bpp = 2
    wrap = 8
    n = 40
    length = bpp * BEAT_BYTES
    await tb.configure(length, addrwrap=wrap)

    producer_task = cocotb.start_soon(tb.push_packets(n, bpp))
    for k in range(n):
        wr = await tb._accept_workreq()
        immdt   = wr["immdt"]
        channel = immdt & 0xFF
        slot    = (immdt >> 8) & 0x00FFFFFF
        assert channel == 1, f"pkt {k}: immDt channel {channel} != 1"
        assert slot == (k % wrap), f"pkt {k}: immDt slot {slot} != ring pos {k % wrap}"
        # Service the WR so the lockstep dispatch advances to the next packet.
        for _ in range(4):
            await RisingEdge(dut.clk)
        await tb._issue_dmareadreq(wr)
        await tb._drain_resp(Cfg())
        for _ in range(2):
            await RisingEdge(dut.clk)
        await tb._issue_workcomp(wr)
    await producer_task


@cocotb.test()
async def retry_rereads_same_payload(dut):
    # The load-bearing property of the replay-RAM design. blue-rdma re-issues the
    # DMA read for the SAME wr_id on an RNR/timeout retry, so SERVE must return
    # BYTE-IDENTICAL payload when the same wr_id is read again (the old one-shot
    # streaming source returned the NEXT packet -> stream desync). Read one WR's
    # payload twice (back-to-back, before its workComp) and assert equality.
    tb = TB(dut)
    await tb.reset()
    bpp = 4
    await tb.configure(bpp * BEAT_BYTES)
    producer_task = cocotb.start_soon(tb.push_packets(8, bpp))

    wr = await tb._accept_workreq()
    # First read of this wr_id.
    await tb._issue_dmareadreq(wr)
    beats_a, err_a = await tb._drain_resp(Cfg())
    # Re-read the SAME wr_id (models the engine's RNR retry) BEFORE completing it.
    await tb._issue_dmareadreq(wr)
    beats_b, err_b = await tb._drain_resp(Cfg())

    assert err_a == 0 and err_b == 0, f"isRespErr set (a={err_a} b={err_b})"
    assert len(beats_a) == bpp and len(beats_b) == bpp, \
        f"beat count {len(beats_a)}/{len(beats_b)} != {bpp}"
    assert beats_a == beats_b, "retry re-read returned DIFFERENT payload (not re-readable!)"

    # Complete it (frees the slot) and confirm one success completion was counted.
    await tb._issue_workcomp(wr)
    await producer_task
    for _ in range(64):
        await RisingEdge(dut.clk)
    assert int(await axil_read_u32(tb.axil, REG_SUCCESS)) == 1
    assert int(await axil_read_u32(tb.axil, REG_UNSUCCESS)) == 0


@cocotb.test()
async def ring_backpressure(dut):
    # The replay ring bounds in-flight (un-ACKed) SENDs to RING_SLOTS: with
    # completions stalled, FILL stops at a full ring and the dispatcher issues at
    # most RING_SLOTS work requests (it can never overwrite an un-ACKed slot).
    # Releasing completions advances freePtr and the remaining packets drain. This
    # is the FW-internal, ACK-paced flow-control bound. RING_SLOTS_G defaults to 16.
    RING_SLOTS = 16
    tb = TB(dut)
    await tb.reset()
    bpp = 2
    total = RING_SLOTS + 6
    await tb.configure(bpp * BEAT_BYTES)
    producer_task = cocotb.start_soon(tb.push_packets(total, bpp))

    # Accept WRs WITHOUT completing them (freePtr frozen) -> the ring fills to
    # RING_SLOTS and the dispatcher must then stall.
    accepted = []
    for _ in range(RING_SLOTS):
        wr = await with_timeout(tb._accept_workreq(), 200_000, "ns")
        accepted.append(wr)

    # No (RING_SLOTS+1)th WR may appear while the ring is full and uncompleted.
    extra_seen = {"hit": False}

    async def watch_extra():
        await tb._accept_workreq()
        extra_seen["hit"] = True

    extra_watch_task = cocotb.start_soon(watch_extra())
    try:
        for _ in range(3000):
            await RisingEdge(dut.clk)
        assert not extra_seen["hit"], \
            f"dispatch exceeded the ring bound: a {RING_SLOTS + 1}th WR issued with the ring full"
    finally:
        extra_watch_task.cancel()
    dut.M_WORKREQ_READY.value = 0

    # Release the gate: complete the held WRs -> freePtr advances -> ring drains.
    for wr in accepted:
        await tb._issue_workcomp(wr)

    # The remaining packets now dispatch + complete.
    for _ in range(total - RING_SLOTS):
        wr = await with_timeout(tb._accept_workreq(), 400_000, "ns")
        await tb._issue_workcomp(wr)

    await producer_task

    for _ in range(64):
        await RisingEdge(dut.clk)
    assert int(await axil_read_u32(tb.axil, REG_SUCCESS)) == total, \
        f"SuccessCounter {int(await axil_read_u32(tb.axil, REG_SUCCESS))} != {total}"


@cocotb.test()
async def oversized_packet_dropped_and_reframes(dut):
    # A packet longer than MAX_BEATS_C beats (> the per-SEND cap / one PMTU) is DROPPED:
    # the FW flushes its tail and does NOT publish the slot, so NO workReq is dispatched
    # for it (an errored isRespErr SEND would put the blue-rdma SQ into its ERROR state,
    # which only a QP reset clears). OversizeCount increments, and the NEXT packet frames
    # + dispatches cleanly with its own bytes -- proving the datapath self-heals after an
    # over-cap frame with no SQ wedge and no SW involvement.
    MAX_BEATS = 128            # RoCEv2AxiStreamRdma.vhd MAX_BEATS_C
    tb = TB(dut)
    await tb.reset()
    normal_bpp = 4
    await tb.configure(normal_bpp * BEAT_BYTES)

    over_beats = MAX_BEATS + 3   # 3 beats past the slot -> over-cap, dropped

    async def push_seq():
        d = tb.dut
        ctr = 0
        for nbeats in (over_beats, normal_bpp):
            for b in range(nbeats):
                d.S_AXIS_TDATA.value = int.from_bytes(beat_pattern(ctr), "little")
                d.S_AXIS_TKEEP.value = (1 << BEAT_BYTES) - 1
                d.S_AXIS_TLAST.value = 1 if b == nbeats - 1 else 0
                d.S_AXIS_TVALID.value = 1
                ctr += 1
                await tb._edge()
                await tb._wait_asserted(d.S_AXIS_TREADY, "S_AXIS_TREADY")
        d.S_AXIS_TVALID.value = 0
        d.S_AXIS_TLAST.value = 0

    producer_task = cocotb.start_soon(push_seq())

    # The over-cap packet produces NO workReq (dropped). The first (and only) workReq is
    # the FOLLOWING normal packet -- it must dispatch cleanly carrying ITS bytes (proving
    # the dropped frame was fully flushed and the slot reused, not leaked).
    wr = await with_timeout(tb._accept_workreq(), 600_000, "ns")
    assert wr["len"] == normal_bpp * BEAT_BYTES, \
        f"workReq.len {wr['len']} != {normal_bpp * BEAT_BYTES} (dropped frame leaked?)"
    await tb._issue_dmareadreq(wr)
    beats, err = await tb._drain_resp(Cfg())
    assert err == 0, "following packet wrongly flagged errored"
    assert len(beats) == normal_bpp, f"following packet {len(beats)} beats != {normal_bpp}"
    assert beats[0][1] == 1 and beats[-1][2] == 1, "isFirst/isLast framing wrong"
    for i, (data, _f, _l) in enumerate(beats):
        exp = endian_swap_32(beat_pattern(over_beats + i))
        assert data == exp, f"following pkt beat {i}: 0x{data:064x} != 0x{exp:064x}"
    await tb._issue_workcomp(wr)
    await producer_task

    for _ in range(64):
        await RisingEdge(dut.clk)
    # Over-cap frame dropped+counted, NOT dispatched: OversizeCount=1, exactly one
    # successful SEND (the normal packet), zero unsuccessful (the SQ was never poisoned).
    assert int(await axil_read_u32(tb.axil, REG_OVERSIZE)) == 1, "OversizeCount != 1"
    assert int(await axil_read_u32(tb.axil, REG_SUCCESS)) == 1, "SuccessCounter != 1"
    assert int(await axil_read_u32(tb.axil, REG_UNSUCCESS)) == 0, "UnsuccessCounter != 0"


@cocotb.test()
async def maxsize_reads_fw_constant(dut):
    # 0x04 is a READ-ONLY readback of the FW per-SEND byte cap (MAX_BEATS_C*32 = one
    # PMTU). Software no longer programs the frame size; it can only query the limit.
    tb = TB(dut)
    await tb.reset()
    val = int(await axil_read_u32(tb.axil, REG_MAXSIZE))
    assert val == 128 * BEAT_BYTES, f"MaxSize {val} != {128 * BEAT_BYTES} (FW per-SEND cap)"


@cocotb.test()
async def dynamic_frame_size(dut):
    # The SEND length is derived PER-PACKET from the inbound tLast (FILL.slotLen), NOT
    # from any software register. Inject back-to-back packets of DIFFERENT beat counts
    # WITHOUT reconfiguring anything, and assert each dispatched workReq.len matches that
    # packet's actual byte count, every beat replays correctly (right isFirst/isLast and
    # data), and no packet is flagged errored. This is the real-life dynamic-frame case
    # the live PacketLength change exercises on hardware.
    tb = TB(dut)
    await tb.reset()
    await tb.configure(0)   # length arg is informational; the FW self-frames from tLast

    sizes = [2, 7, 3, 8, 1, 5, 4]   # beats/packet (each <= MAX_BEATS, whole 32-byte beats)

    async def push_seq():
        d = tb.dut
        ctr = 0
        for nbeats in sizes:
            for b in range(nbeats):
                d.S_AXIS_TDATA.value = int.from_bytes(beat_pattern(ctr), "little")
                d.S_AXIS_TKEEP.value = (1 << BEAT_BYTES) - 1
                d.S_AXIS_TLAST.value = 1 if b == nbeats - 1 else 0
                d.S_AXIS_TVALID.value = 1
                ctr += 1
                await tb._edge()
                await tb._wait_asserted(d.S_AXIS_TREADY, "S_AXIS_TREADY")
        d.S_AXIS_TVALID.value = 0
        d.S_AXIS_TLAST.value = 0

    producer_task = cocotb.start_soon(push_seq())

    ctr = 0
    for k, nbeats in enumerate(sizes):
        wr = await with_timeout(tb._accept_workreq(), 600_000, "ns")
        assert wr["len"] == nbeats * BEAT_BYTES, \
            f"pkt {k}: workReq.len {wr['len']} != {nbeats * BEAT_BYTES} (dynamic length wrong)"
        await tb._issue_dmareadreq(wr)
        beats, err = await tb._drain_resp(Cfg())
        assert err == 0, f"pkt {k}: isRespErr set on a valid dynamic-length frame"
        assert len(beats) == nbeats, f"pkt {k}: replayed {len(beats)} != {nbeats} beats"
        assert beats[0][1] == 1 and beats[-1][2] == 1, f"pkt {k}: isFirst/isLast framing wrong"
        for i, (data, _f, _l) in enumerate(beats):
            exp = endian_swap_32(beat_pattern(ctr))
            ctr += 1
            assert data == exp, f"pkt {k} beat {i}: 0x{data:064x} != 0x{exp:064x}"
        await tb._issue_workcomp(wr)

    await producer_task

    for _ in range(64):
        await RisingEdge(dut.clk)
    succ = int(await axil_read_u32(tb.axil, REG_SUCCESS))
    unsucc = int(await axil_read_u32(tb.axil, REG_UNSUCCESS))
    assert succ == len(sizes), f"SuccessCounter {succ} != {len(sizes)}"
    assert unsucc == 0, f"UnsuccessCounter {unsucc} != 0"


@cocotb.test()
async def partial_final_beat_byteen(dut):
    # A frame whose byte length is NOT a multiple of 32 has a PARTIAL final replay beat.
    # It must (a) dispatch with the byte-exact length, (b) NOT be flagged isRespErr, and
    # (c) have its final beat's byteEn = bitReverse(tKeep) so the valid bytes — which the
    # SERVE endianSwap moves to the HIGH lanes — are marked there. Full beats keep
    # byteEn = 0xFFFFFFFF (bitReverse is a no-op on all-ones). SsiPrbsTx only produces a
    # partial beat as the FINAL beat (whole 8-byte words), so k is a multiple of 8.
    tb = TB(dut)
    await tb.reset()
    await tb.configure(0)

    full = 3                          # full 32-byte beats
    kbytes = 8                        # valid bytes in the partial final beat (1 PRBS word)
    total_bytes = full * BEAT_BYTES + kbytes
    last_tkeep = (1 << kbytes) - 1    # valid bytes in the LOW lanes (as the repack emits)

    async def push_frame():
        d = tb.dut
        for b in range(full + 1):
            last = (b == full)
            d.S_AXIS_TDATA.value = int.from_bytes(beat_pattern(b), "little")
            d.S_AXIS_TKEEP.value = last_tkeep if last else (1 << BEAT_BYTES) - 1
            d.S_AXIS_TLAST.value = 1 if last else 0
            d.S_AXIS_TVALID.value = 1
            await tb._edge()
            await tb._wait_asserted(d.S_AXIS_TREADY, "S_AXIS_TREADY")
        d.S_AXIS_TVALID.value = 0
        d.S_AXIS_TLAST.value = 0

    producer_task = cocotb.start_soon(push_frame())

    wr = await with_timeout(tb._accept_workreq(), 200_000, "ns")
    assert wr["len"] == total_bytes, f"workReq.len {wr['len']} != {total_bytes} (byte-exact)"

    # Drain, capturing byteEn (dataStream[33:2]) and data (dataStream[289:34]) per beat.
    dut.S_DMAREADREQ_VALID.value = 1
    dut.S_DMAREADREQ_LEN.value = wr["len"] & 0x1FFF
    dut.S_DMAREADREQ_WRID.value = wr["id"]
    dut.S_DMAREADREQ_SQPN.value = 0x10
    await tb._edge()
    await tb._wait_asserted(dut.S_DMAREADREQ_READY, "S_DMAREADREQ_READY")
    dut.S_DMAREADREQ_VALID.value = 0

    beats = []
    is_err = 0
    for _ in range(DMA_RESPONSE_TIMEOUT_CYCLES):
        dut.M_DMAREADRESP_READY.value = 1
        await tb._edge()
        if int(dut.M_DMAREADRESP_VALID.value) and int(dut.M_DMAREADRESP_READY.value):
            ds = int(dut.M_DMAREADRESP_DATASTREAM.value)
            is_err |= int(dut.M_DMAREADRESP_ISRESPERR.value)
            beats.append(((ds >> 34) & DATA_MASK, (ds >> 2) & 0xFFFFFFFF, ds & 1))
            if ds & 1:
                break
    else:
        dut.M_DMAREADRESP_READY.value = 0
        raise AssertionError(
            "Timed out waiting for partial-frame DMA response; "
            f"received {len(beats)} beats"
        )
    dut.M_DMAREADRESP_READY.value = 0
    await producer_task

    def bitrev32(x):
        return int(f"{x:032b}"[::-1], 2)

    assert is_err == 0, "partial final beat wrongly flagged isRespErr"
    assert len(beats) == full + 1, f"replayed {len(beats)} != {full + 1} beats"
    for i in range(full):
        assert beats[i][1] == 0xFFFFFFFF, f"full beat {i} byteEn {beats[i][1]:08x} != ffffffff"
        assert beats[i][0] == endian_swap_32(beat_pattern(i)), f"full beat {i} data mismatch"
    # Final beat: byteEn = bitReverse(tKeep) (marks the high lanes), data = endianSwap.
    assert beats[-1][1] == bitrev32(last_tkeep), \
        f"final byteEn {beats[-1][1]:08x} != bitReverse(tKeep) {bitrev32(last_tkeep):08x}"
    assert beats[-1][0] == endian_swap_32(beat_pattern(full)), "final beat data mismatch"

    await tb._issue_workcomp(wr)
    for _ in range(64):
        await RisingEdge(dut.clk)
    assert int(await axil_read_u32(tb.axil, REG_SUCCESS)) == 1
    assert int(await axil_read_u32(tb.axil, REG_UNSUCCESS)) == 0


@cocotb.test()
async def reset_counters_clears_axistreammon(dut):
    # AxiStreamMon monitors the FIFO drain stream; its statistics (frameCnt + min/max)
    # must zero on a ResetCounters (0x108) write -- the monitor reset is gated on
    # roceRst OR resetCounters. FILL drains each pushed packet into a ring slot
    # (frameCnt++), needing no dispatch/completion while n < RING_SLOTS, so we can
    # build a non-zero frameCnt, reset it, and confirm it clears.
    tb = TB(dut)
    await tb.reset()
    bpp = 3
    n = 8                       # < RING_SLOTS (16): all drain without completions
    await tb.configure(bpp * BEAT_BYTES)

    await tb.push_packets(n, bpp)
    for _ in range(500):        # let FILL drain every packet out of the FIFO
        await RisingEdge(dut.clk)
    cnt = int(await axil_read_u32(tb.axil, REG_MON_FRAMECNT))
    assert cnt == n, f"MonFrameCnt {cnt} != {n} (monitor did not count the drained packets)"

    # ResetCounters: toggle 1 -> 0 (RemoteCommand.toggle semantics) clears the monitor.
    await axil_write_u32(tb.axil, REG_RESET, 1)
    await axil_write_u32(tb.axil, REG_RESET, 0)
    for _ in range(64):
        await RisingEdge(dut.clk)
    cnt2 = int(await axil_read_u32(tb.axil, REG_MON_FRAMECNT))
    assert cnt2 == 0, f"MonFrameCnt {cnt2} != 0 after ResetCounters (stats not reset)"


@pytest.mark.parametrize("parameters", [pytest.param({}, id="rocev2_axistream_rdma")])
def test_RoCEv2AxiStreamRdmaCore(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rocev2axistreamrdmacorewrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": [WRAPPER_PATH]},
    )
