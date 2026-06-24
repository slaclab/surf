##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
"""Full-stack RoCEv2 engine retransmit trace (VCS mixed VHDL/Verilog + cocotb).

DUT: RoCEv2AxiStreamRdmaWrapper -> the REAL RoCEv2AxiStreamRdma (RoCEv2Engine
[blue-rdma Verilog] + RoCEv2Dcqcn + RoCEv2AxiStreamRdmaCore), i.e. exactly what
runs on the KCU105. Reproduces the hardware sticky-half measurement: the core's
DmaReadCount (one per SEND transmission, incl. retransmit) vs SuccessCounter
(one per completion). TX/comp==2.0 means every SEND is emitted twice.

Flow:
  1. QP bring-up over AXI-Lite metadata bus (PD->MR->QP->INIT->RTR->RTS, infinite
     RNR retry), driven via the firmware's own RoceConfigurator handshake.
  2. Arm the core (DispatchEnable @0x2000) + bypass DCQCN (@0x1024) for p2p.
  3. Drive a continuous PRBS payload stream into sAxis.
  4. Go-back-N responder on the UDP port (obUdp = responses in): observe each
     request packet on ibUdp, inject ACK / RNR-NAK during a window.
  5. Sample DmaReadCount (0x2110) and SuccessCounter (0x2100) over time -> TX/comp.

Run with VCS:
  source /sdf/group/faders/tools/synopsys/vcs/X-2025.06/settings.sh
  python3 test_RoCEv2EngineRetransmit.py
"""
import os

import cocotb
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.clock import Clock
from cocotbext.axi import (AxiLiteBus, AxiLiteMaster, AxiStreamBus,
                           AxiStreamSource, AxiStreamSink, AxiStreamFrame)

# Package-qualified under pytest collection (surf CI: `pytest tests/...`); bare
# module when cocotb re-imports this file inside the VCS sim (PYTHONPATH=test dir,
# COCOTB_TEST_MODULES=<basename>).
try:
    from tests.ethernet.RoCEv2 import roce_meta as rm
except ImportError:
    import roce_meta as rm

# ---- AXI-Lite register offsets (RoCEv2AxiStreamRdma crossbar map) ----
ENG = 0x0000   # RoCEv2Engine / RoceConfigurator
DCQCN = 0x1000
CORE = 0x2000
REG_SEND_META   = ENG + 0xF00   # bit0 SendMetaData, bit1 RecvMetaData(RO)
REG_META_TX     = ENG + 0xF04   # 303-bit, 10 words
REG_META_RX     = ENG + 0xF2C   # 276-bit, 9 words
REG_DCQCN_BYPASS = DCQCN + 0x024
REG_DISPATCH_EN = CORE + 0x000
REG_LKEY        = CORE + 0x00C
REG_SQPN        = CORE + 0x010
REG_ADDRWRAP    = CORE + 0x020
REG_SUCCESS     = CORE + 0x100
REG_RESETCNT    = CORE + 0x108
REG_DMAREADCNT  = CORE + 0x110
REG_MAXSIZE     = CORE + 0x004

# Match the hardware exactly: pmtu=MTU_4096, maxPayload=4096 (RoCEv2TransportCfg
# defaults / rocev2PrbsTest.py). A 4096B SEND is then ONE packet = ONE DMA-read,
# so DmaReadCount/SuccessCounter is the true retransmit ratio (HW baseline 1.0,
# stuck 2.0). Smaller PMTU splits a WR into multiple packets => multiple DMA-reads
# per WR, a structural ratio that masks the real signal.
PMTU_4096 = 5  # IBV_MTU_4096 (blue-rdma DataTypes.bsv)


async def axil_write(axil, addr, value):
    await axil.write_dword(addr, value & 0xFFFFFFFF)


async def axil_read(axil, addr):
    return int(await axil.read_dword(addr))


async def write_meta_tx(axil, busValue):
    # 303-bit value -> 10 little-endian 32-bit words at 0xF04.
    for i in range(10):
        await axil_write(axil, REG_META_TX + 4 * i, (busValue >> (32 * i)) & 0xFFFFFFFF)


async def read_meta_rx(axil):
    rx = 0
    for i in range(9):
        rx |= (await axil_read(axil, REG_META_RX + 4 * i)) << (32 * i)
    return rx


async def send_meta(axil, busValue):
    await axil_write(axil, REG_SEND_META, 0)      # clean rising edge
    await write_meta_tx(axil, busValue)
    await axil_write(axil, REG_SEND_META, 1)
    await axil_write(axil, REG_SEND_META, 0)


async def wait_resp(axil, timeout_cycles=20000, clk=None):
    for _ in range(timeout_cycles):
        v = await axil_read(axil, REG_SEND_META)
        if (v >> 1) & 1:
            return await read_meta_rx(axil)
        await ClockCycles(clk, 5)
    raise TimeoutError("metaData response not ready")


BEAT_BYTES = 32   # S_AXIS / wrapper bus width (256-bit)

# ---- ibUdp / obUdp wire format (network-order IB, post RoceResizeAndSwap) ----
# Frame bytes are lane0-first. BTH (12B) + AETH/ImmDt follow.
OPC_SEND_LAST     = 0x02
OPC_SEND_LAST_IMM = 0x03
OPC_SEND_ONLY     = 0x04
OPC_SEND_ONLY_IMM = 0x05
OPC_ACKNOWLEDGE   = 0x11
WR_END_OPCODES = (OPC_SEND_LAST, OPC_SEND_LAST_IMM, OPC_SEND_ONLY, OPC_SEND_ONLY_IMM)
SOF_TUSER = 0b10   # tUser(1) = SOF (RoCEv2Engine.vhd: tFirst <= tUser(1))


def prbs_beat(seed):
    """32-byte payload beat; low 4 bytes carry a running counter so each beat is
    distinguishable in a capture (mirrors the core bench's beat_pattern)."""
    b = bytearray(BEAT_BYTES)
    b[0:4] = (seed & 0xFFFFFFFF).to_bytes(4, "little")
    return bytes(b)


def parse_bth(frame_bytes):
    """Return (opcode, destQpn, psn) from an ibUdp request packet (network order)."""
    b = frame_bytes
    opcode = b[0]
    destQpn = (b[5] << 16) | (b[6] << 8) | b[7]
    psn = (b[9] << 16) | (b[10] << 8) | b[11]
    return opcode, destQpn, psn


# AETH syndrome byte = [rsvd(1) code(2) value(5)]. code: ACK=00, RNR=01, NAK=11.
AETH_ACK     = 0x1F                  # code 00, value 0x1F (invalid credit count)
AETH_NAK_SEQ = (0b11 << 5) | 0x00    # code 11, value 0 = PSN Sequence Error


def build_ack(fpgaQpn, psn, syndrome=AETH_ACK):
    """Build a 16-byte AETH response packet (BTH ACKNOWLEDGE + AETH) for obUdp,
    addressed back to the FPGA's SQ (destQpn=fpgaQpn). Network-order bytes
    (lane0-first), symmetric with the parsed ibUdp layout. `syndrome` selects
    ACK / RNR-NAK / SEQ_ERR-NAK."""
    b = bytearray(16)
    b[0] = OPC_ACKNOWLEDGE
    b[1] = 0x00
    b[2] = 0xFF; b[3] = 0xFF          # P_KEY
    b[4] = 0x00
    b[5] = (fpgaQpn >> 16) & 0xFF; b[6] = (fpgaQpn >> 8) & 0xFF; b[7] = fpgaQpn & 0xFF
    b[8] = 0x00                       # ackReq=0 on a response
    b[9] = (psn >> 16) & 0xFF; b[10] = (psn >> 8) & 0xFF; b[11] = psn & 0xFF
    b[12] = syndrome & 0xFF
    b[13] = b[14] = b[15] = 0x00      # MSN
    return bytes(b)


def rnr_syndrome(rnr_timer=1):
    return (0x20 | (rnr_timer & 0x1F))   # code 01 RNR-NAK, value = timer


class Tb:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.clk
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXIL"), dut.clk, dut.rst, reset_active_level=True)
        self.payload = AxiStreamSource(AxiStreamBus.from_prefix(dut, "S_AXIS"), dut.clk, dut.rst, reset_active_level=True)
        self.ibudp = AxiStreamSink(AxiStreamBus.from_prefix(dut, "M_IBUDP"), dut.clk, dut.rst, reset_active_level=True)
        self.obudp = AxiStreamSource(AxiStreamBus.from_prefix(dut, "S_OBUDP"), dut.clk, dut.rst, reset_active_level=True)
        self.tx_pkts = 0
        self.cap = []        # captured ibUdp request frames (raw bytes), for wire-format study
        # responder knobs (set by the test before starting the responder)
        self.rnr_start = -1     # head-WR PSN at which the transient RNR burst starts
        self.rnr_naks = 0       # number of RNR-NAKs in the burst before the buffer posts
        self.lag_ack = False    # cumulative ACK lags by one PSN
        self.unified_nak = True # faithful RC: one NAK per gap; suppress redundant SEQ_ERR after an RNR
        self._seq_nakd = False  # legacy (unified_nak=0) per-gap SEQ_ERR coalesce flag
        self.wr_ends = 0        # request WR-ends observed
        self.completions = 0    # work completions (read via SuccessCounter)

    async def reset(self):
        cocotb.start_soon(Clock(self.clk, 10, "ns").start())
        self.dut.rst.value = 1
        await ClockCycles(self.clk, 10)
        self.dut.rst.value = 0
        await ClockCycles(self.clk, 10)

    async def bringup_qp(self):
        a = self.axil
        # PD
        await send_meta(a, rm.encode_alloc_pd(0xABCD1234))
        rx = await wait_resp(a, clk=self.clk)
        assert rm.decode_resp_type(rx) == rm.BUS_PD, f"PD resp type {rm.decode_resp_type(rx)}"
        ok, pd = rm.decode_pd_resp(rx); assert ok, "PD alloc failed"
        # MR
        await send_meta(a, rm.encode_alloc_mr(pd, 0, 0x100000, 0x111, 0x222))
        rx = await wait_resp(a, clk=self.clk)
        ok, lkey, rkey = rm.decode_mr_resp(rx); assert ok, "MR alloc failed"
        # QP create
        await send_meta(a, rm.encode_create_qp(pd))
        rx = await wait_resp(a, clk=self.clk)
        ok, fpgaQpn, _ = rm.decode_qp_resp(rx); assert ok, "QP create failed"
        # INIT
        await send_meta(a, rm.encode_modify_qp(fpgaQpn, rm.M_STATE | rm.M_PKEY_INDEX | rm.M_ACCESS_FLAGS, rm.QPS_INIT, PMTU_4096))
        ok, _, st = rm.decode_qp_resp(await wait_resp(a, clk=self.clk)); assert ok and st == rm.QPS_INIT, f"INIT st={st}"
        # RTR (dest = a fake host QPN)
        hostQpn = 0x222
        rtr = rm.M_STATE | rm.M_PATH_MTU | rm.M_DEST_QPN | rm.M_RQ_PSN | rm.M_MAX_DEST_RD_ATOMIC | rm.M_MIN_RNR_TIMER
        await send_meta(a, rm.encode_modify_qp(fpgaQpn, rtr, rm.QPS_RTR, PMTU_4096, dqpn=hostQpn, rqPsn=0, minRnrTimer=1))
        ok, _, st = rm.decode_qp_resp(await wait_resp(a, clk=self.clk)); assert ok and st == rm.QPS_RTR, f"RTR st={st}"
        # RTS — INFINITE RNR retry (7), infinite data retry (7)
        rts = rm.M_STATE | rm.M_SQ_PSN | rm.M_TIMEOUT | rm.M_RETRY_CNT | rm.M_RNR_RETRY | rm.M_MAX_QP_RD_ATOMIC
        await send_meta(a, rm.encode_modify_qp(fpgaQpn, rts, rm.QPS_RTS, PMTU_4096, sqPsn=0, minRnrTimer=1, rnrRetry=7, retryCount=7))
        ok, _, st = rm.decode_qp_resp(await wait_resp(a, clk=self.clk)); assert ok and st == rm.QPS_RTS, f"RTS st={st}"
        self.fpgaQpn, self.hostQpn, self.lkey = fpgaQpn, hostQpn, lkey
        cocotb.log.info(f"QP up: fpgaQpn=0x{fpgaQpn:x} hostQpn=0x{hostQpn:x} lkey=0x{lkey:x} (infinite RNR)")

    async def push_packets(self, num_packets, beats_per_packet):
        """Drive `num_packets` SEND payloads into sAxis; the core makes one
        RDMA-SEND WR per tLast-terminated packet. One AxiStreamFrame == one
        packet: the source spreads its bytes over beats and asserts tLast on the
        final beat."""
        ctr = 0
        for _ in range(num_packets):
            payload = bytearray()
            for _ in range(beats_per_packet):
                payload += prbs_beat(ctr)
                ctr += 1
            await self.payload.send(AxiStreamFrame(bytes(payload)))
        await self.payload.wait()

    async def inject_ack(self, psn, syndrome=AETH_ACK):
        """Inject one AETH response packet on obUdp (single 16-byte beat with SOF
        in tUser(1), addressed back to the FPGA SQ)."""
        frame = AxiStreamFrame(build_ack(self.fpgaQpn, psn, syndrome=syndrome), tuser=[SOF_TUSER])
        await self.obudp.send(frame)

    async def go_back_n_responder(self):
        """Faithful RC receive-queue: cumulative-ACK go-back-N keyed on PSN (NOT a
        WR-end packet count, which races ahead during a retry storm). At PMTU_4096
        each 4096B WR is exactly one packet => one PSN, so PSN directly indexes the
        WR.

        Models a TRANSIENT recv-buffer shortage: when the head WR first reaches
        PSN==rnr_start the recv queue is dry, so it RNR-NAKs the head (no advance)
        up to `rnr_naks` times; then the host posts a buffer and normal cumulative
        ACK resumes. This is the bounded backpressure-burst-then-clear the hardware
        reproduction exercises (checkPayload True for a window, then False).
        Duplicate/old retransmits re-ACK the cumulative high-water mark. If
        lag_ack, the cumulative ACK trails by one PSN."""
        ePsn = 0          # next in-order PSN the RQ expects
        ackHi = -1        # highest cumulatively acked PSN
        naks = 0          # RNR-NAKs issued so far in the burst
        nak_pending = False  # a NAK (RNR or SEQ_ERR) is outstanding for ePsn
        while True:
            frame = await self.ibudp.recv()
            self.tx_pkts += 1
            data = bytes(frame.tdata)
            self.cap.append(data)
            opcode, dqpn, psn = parse_bth(data)
            if opcode not in WR_END_OPCODES:
                continue
            self.wr_ends += 1
            if psn < ePsn:
                # duplicate / old retransmit: re-assert the cumulative ACK
                if ackHi >= 0:
                    await self.inject_ack(ackHi)
                continue
            if psn > ePsn:
                # FORWARD GAP: a real RC receiver sends ONE coalesced SEQ_ERR NAK at
                # the expected PSN, then silently discards further out-of-sequence
                # packets until the in-order one arrives. Forces the SQ to rewind to
                # ePsn. With unified_nak (faithful) a SEQ_ERR is suppressed while ANY
                # NAK is already outstanding for ePsn -- so an RNR-NAK at ePsn is NOT
                # followed by a redundant SEQ_ERR for the same gap (the old behavior,
                # unified_nak=0, set the SEQ_ERR coalesce flag independently of the
                # RNR -> a double NAK == nested retry, possibly a test artifact).
                already = nak_pending if self.unified_nak else self._seq_nakd
                if not already:
                    nak_pending = True
                    self._seq_nakd = True
                    await self.inject_ack(ePsn, syndrome=AETH_NAK_SEQ)
                continue
            # psn == ePsn (in order)
            self._seq_nakd = False
            if psn == self.rnr_start and naks < self.rnr_naks:
                # recv queue transiently empty -> RNR-NAK the head, do NOT advance.
                # Mark a NAK outstanding so the trailing out-of-sequence burst is
                # suppressed (unified) instead of generating a second SEQ_ERR.
                naks += 1
                nak_pending = True
                await self.inject_ack(psn, syndrome=rnr_syndrome())
                continue
            # in-order, recv buffer available: accept and advance
            ePsn = psn + 1
            ackHi = psn
            nak_pending = False
            ack_psn = (psn - 1) if (self.lag_ack and psn > 0) else psn
            if ack_psn >= 0:
                await self.inject_ack(ack_psn)


async def arm_core(tb):
    """Bypass DCQCN (p2p), program the core, enable dispatch."""
    await axil_write(tb.axil, REG_DCQCN_BYPASS, 1)
    await axil_write(tb.axil, REG_LKEY, tb.lkey)
    await axil_write(tb.axil, REG_SQPN, tb.fpgaQpn)
    await axil_write(tb.axil, REG_ADDRWRAP, 256)
    await axil_write(tb.axil, REG_RESETCNT, 1)
    await axil_write(tb.axil, REG_RESETCNT, 0)
    await axil_write(tb.axil, REG_DISPATCH_EN, 1)


@cocotb.test(timeout_time=20_000_000, timeout_unit="ns")
async def engine_retransmit(dut):
    tb = Tb(dut)
    await tb.reset()
    await tb.bringup_qp()
    await arm_core(tb)

    # Transient RNR burst at the head WR PSN==rnr_start (rnr_naks NAKs, then the
    # host posts a buffer and ACKs resume) — mirrors the hardware checkPayload
    # True-then-False backpressure window. lag_ack (LAG_ACK=1) makes the cumulative
    # ACK trail by one WR — a one-behind ACK window hypothesis for TX/comp=2.0.
    tb.rnr_start = int(os.environ.get("RNR_START", "20"))
    tb.rnr_naks = int(os.environ.get("RNR_NAKS", "40"))
    tb.lag_ack = (os.environ.get("LAG_ACK", "0") == "1")
    tb.unified_nak = (os.environ.get("UNIFIED_NAK", "1") == "1")
    cocotb.start_soon(tb.go_back_n_responder())

    # beats_per_packet drives the SEND size. Hardware SENDs are 4096B (MonFrameSize)
    # at PMTU 4096 == ONE packet/WR == one DMA-read/WR -> TX/comp is the true
    # retransmit ratio. BPP=128 == 4096B == faithful HW regime.
    NUM = int(os.environ.get("NUM_WR", "400"))
    BPP = int(os.environ.get("BPP", "3"))
    cocotb.start_soon(tb.push_packets(num_packets=NUM, beats_per_packet=BPP))

    # Time-series sample of (DmaReadCount, SuccessCounter): a PLATEAU in succ while
    # dma keeps climbing == the latch (engine retransmits, completions stop); succ
    # climbing back to NUM == clean recovery. One end-sample can't tell these apart.
    prev = None
    for k in range(12):
        await ClockCycles(tb.clk, 8000)
        dma = await axil_read(tb.axil, REG_DMAREADCNT)
        succ = await axil_read(tb.axil, REG_SUCCESS)
        ratio = (dma / succ) if succ else 0.0
        dsucc = "-" if prev is None else str(succ - prev)
        print(f"ENGINE_RETX_TS k={k} DmaReadCount={dma} SuccessCounter={succ} "
              f"dSucc={dsucc} TX/comp={ratio:.3f}")
        prev = succ
    print(f"ENGINE_RETX unified_nak={int(tb.unified_nak)} lag_ack={int(tb.lag_ack)} "
          f"rnr_start={tb.rnr_start} rnr_naks={tb.rnr_naks} "
          f"bpp={BPP} num_wr={NUM} ibUdp_pkts={tb.tx_pkts} wr_ends={tb.wr_ends} "
          f"DmaReadCount={dma} SuccessCounter={succ} TX/comp={ratio:.3f}")
    # Full ibUdp PSN sequence: distinguishes a dispatch DEADLOCK (PSN climbs then
    # goes silent) from a retransmit STORM (PSN rewinds to the RNR point and loops).
    psns = [((fr[9] << 16) | (fr[10] << 8) | fr[11]) for fr in tb.cap]
    print(f"ENGINE_RETX_PSNSEQ n={len(psns)} seq={psns}")


def _build_simv(build_dir):
    """Manual vhdlan/vlogan/vcs build (cocotb_test's Vcs runner is broken under
    cocotb 2.0). Returns path to simv. Mixed VHDL+Verilog, all into lib 'surf'."""
    import subprocess, glob
    test_dir = os.path.abspath(os.path.dirname(__file__))
    surf = os.path.abspath(os.path.join(test_dir, "../../.."))
    R = f"{surf}/ethernet/RoCEv2/rtl"
    W = f"{surf}/ethernet/RoCEv2/wrappers"
    cocotb_vpi = os.path.join(os.path.dirname(__import__("cocotb").__file__), "libs", "libcocotbvpi_vcs.so")

    os.makedirs(build_dir, exist_ok=True)
    with open(os.path.join(build_dir, "synopsys_sim.setup"), "w") as f:
        f.write("WORK > DEFAULT\nDEFAULT : ./work\nsurf : ./surf_lib\n")
    os.makedirs(os.path.join(build_dir, "work"), exist_ok=True)
    os.makedirs(os.path.join(build_dir, "surf_lib"), exist_ok=True)

    # base surf VHDL (pruned: drop ip_integrator except the 3 shims) in dep order
    base = []
    with open(f"{surf}/build/SRC_VHDL/order") as f:
        for line in f:
            p = line.split()
            if len(p) >= 4 and p[3].endswith(".vhd"):
                path = p[3]
                if "/sim/" in path or path.endswith("Tb.vhd"):
                    continue
                if "ip_integrator" in path and not any(s in path for s in
                        ("SlaveAxiLiteIpIntegrator", "MasterAxiStreamIpIntegrator", "SlaveAxiStreamIpIntegrator")):
                    continue
                base.append(path)
    roce = [f"{R}/RoCEv2Pkg.vhd", f"{R}/RoCEv2AlphaUpdate.vhd", f"{R}/RoCEv2RateDecProc.vhd",
            f"{R}/RoCEv2RateIncProc.vhd", f"{R}/RoCEv2TokenCalc.vhd", f"{R}/RoCEv2AxisBucket.vhd",
            f"{R}/RoCEv2TokenBucket.vhd", f"{R}/RoCEv2Dcqcn.vhd", f"{R}/RoCEv2AxiStreamRdmaCore.vhd",
            f"{R}/RoceResizeAndSwap.vhd", f"{R}/RoceConfigurator.vhd", f"{R}/RoCEv2Engine.vhd",
            f"{R}/RoCEv2AxiStreamRdma.vhd", f"{W}/RoCEv2AxiStreamRdmaWrapper.vhd"]
    verilog = (glob.glob(f"{surf}/ethernet/RoCEv2/blue-lib/*.v")
               + glob.glob(f"{surf}/ethernet/RoCEv2/blue-crc/*.v")
               + glob.glob(f"{surf}/ethernet/RoCEv2/blue-rdma/*.v"))
    # Thin Verilog top shim: VCS mixed-lang VPI only roots on Verilog instances,
    # so cocotb binds here; this module passes through to the VHDL wrapper.
    shim = os.path.join(test_dir, "RoCEv2EngineTbTop.v")

    def sh(cmd):
        print("RUN:", " ".join(cmd[:6]), "...")
        r = subprocess.run(cmd, cwd=build_dir, capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stdout[-3000:]); print(r.stderr[-3000:])
            raise RuntimeError(f"{cmd[0]} failed rc={r.returncode}")
        return r

    sh(["vlogan", "-full64", "-nc", "-q", "-work", "surf"] + verilog)
    sh(["vhdlan", "-full64", "-nc", "-q", "-work", "surf", "-vhdl08"] + base + roce)
    # Compile the Verilog top shim last (it instantiates the VHDL wrapper by name).
    sh(["vlogan", "-full64", "-nc", "-q", "-work", "surf", shim])
    sh(["vcs", "-full64", "-nc", "-q", "surf.RoCEv2EngineTbTop",
        "-timescale=1ns/1ps", "-debug_access+all",
        "+vpi", "-P", "pli.tab", "-load", f"{cocotb_vpi}:vlog_startup_routines_bootstrap",
        "-o", "simv"])
    return os.path.join(build_dir, "simv")


def test_RoCEv2EngineRetransmit():
    import shutil
    import subprocess
    # Mixed-language (VHDL+Verilog) DUT requires Synopsys VCS; the public surf CI
    # runner has no VCS, so skip there (same spirit as the rogue importorskip in
    # test_RoCEv2Engine.py). Run locally after sourcing the VCS settings.sh.
    if shutil.which("vcs") is None:
        import pytest
        pytest.skip("VCS not on PATH (mixed-language RoCEv2 engine trace needs Synopsys VCS)")
    test_dir = os.path.abspath(os.path.dirname(__file__))
    build_dir = os.path.join(test_dir, "sim_build_vcs_engine")
    cocotb_vpi = os.path.join(os.path.dirname(__import__("cocotb").__file__), "libs", "libcocotbvpi_vcs.so")
    # pli.tab in build dir
    os.makedirs(build_dir, exist_ok=True)
    with open(os.path.join(build_dir, "pli.tab"), "w") as f:
        f.write("acc+=rw,wn:*\n")
    simv = _build_simv(build_dir)

    import sys
    env = dict(os.environ)
    env["COCOTB_TEST_MODULES"] = os.path.splitext(os.path.basename(__file__))[0]
    env["COCOTB_TOPLEVEL"] = "RoCEv2EngineTbTop"
    env["COCOTB_TOPLEVEL_LANG"] = "verilog"
    env["PYTHONPATH"] = test_dir + os.pathsep + env.get("PYTHONPATH", "")
    # cocotb 2.0 embeds Python via PYGPI_PYTHON_BIN (the runner normally sets it).
    env["PYGPI_PYTHON_BIN"] = sys.executable
    r = subprocess.run([simv, "-licqueue"], cwd=build_dir, env=env)
    raise SystemExit(r.returncode)


if __name__ == "__main__":
    test_RoCEv2EngineRetransmit()
