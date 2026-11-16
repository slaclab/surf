##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the terms
## contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Purpose: Reproduce slaclab/surf#1542. A peer whose ACK-bearing segments
#   leave out of order (Rogue builds a header under its TX lock but sends it
#   after releasing the lock) can deliver an older ACK right behind a newer
#   one. The server must ignore the stale ACK instead of raising ackErr and
#   resetting the link.
# - DUT shape: The server in RssiCoreIntegrationWrapper uses production TX/RX,
#   checksum, monitor, connection logic, FIFOs and segment RAM. The RTL client
#   is held closed; an independent Python wire peer performs SYN/SYN+ACK/ACK
#   negotiation, checks outgoing DATA, and replies only with ACK segments.
# - Stimulus: For each trial the server sends three DATA segments. The peer
#   ACKs the second one, then after a swept idle gap sends the ACK it had
#   already sent before the trial (stale and older than the window base), and
#   finally ACKs the third segment. Sweeping the gap lands the stale header
#   both while RssiTxFsm walks its window and just after the walk completes.
# - Checks: Exact DATA payload and sequence, valid header checksums, no
#   ackErr or retransmission-limit status, and a continuously active
#   connection. Each trial reuses the four-entry window, so a window that
#   failed to drain stalls the next trial; a final idle period longer than the
#   retransmission timeout proves no segment was left unacknowledged.
# - Timing: The wrapper accelerates one timeout unit to one clock. Sources
#   drive on falling edges and sample acceptance at rising edges before
#   registered TREADY changes; they hold the beat through TPD_G. The collector
#   samples accepted transfers at rising edges.

from collections import deque

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from tests.common.regression_utils import (
    cancel_and_join_tasks,
    run_surf_vhdl_test,
    sample_after_tpd,
)
from tests.protocols.rssi.rssi_test_utils import (
    RSSI_FLAG_ACK,
    RSSI_FLAG_SYN,
    RssiParams,
    build_ack_header,
    build_syn_header,
    checksum_is_valid,
    parse_header,
    protocol_bytes_from_stream_word,
    stream_words_from_header,
)
from tests.protocols.ssi.ssi_test_utils import FlatSsiEndpoint, SsiBeat


PARAMETERS = {
    "WINDOW_ADDR_SIZE_G": 4,
    "SEGMENT_ADDR_SIZE_G": 5,
    "MAX_NUM_OUTS_SEG_G": 16,
    "MAX_SEG_SIZE_G": 32,
    "ACK_TOUT_G": 4,
    "RETRANS_TOUT_G": 512,
    "NULL_TOUT_G": 2048,
    "MAX_RETRANS_CNT_G": 16,
    "MAX_CUM_ACK_CNT_G": 1,
}
CLIENT_SEQUENCE = 0x20
SEGMENTS_PER_TRIAL = 15
BASE_INDEX = 4
NEWER_INDEX = 13
# s2 is older than the window base (s4) when it arrives, so it is a pure
# stale ACK. s8 lies between the base and the newer ACK (s13), so the RX
# range check accepts it while the TX FSM is still walking toward s13.
STALE_INDEXES = (2, 8)
STATUS_CONNECTED = 1 << 0
STATUS_RETRANS_MAX = 1 << 1
STATUS_ACK_ERR = 1 << 3


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.axisClk
        self.app = FlatSsiEndpoint(dut, prefix="srvSApp")
        self.peer = FlatSsiEndpoint(dut, prefix="srvSTsp")
        self.output = FlatSsiEndpoint(dut, prefix="srvMTsp")
        self.frames = deque()
        self.tick = 0
        self.require_connected = False
        self.failure = None
        self.tasks = []

    async def start(self):
        self.dut.axisRst.value = 1
        for prefix in ("cltSApp", "srvSApp", "cltSTsp", "srvSTsp"):
            FlatSsiEndpoint(self.dut, prefix=prefix).set_idle()
        for side in ("clt", "srv"):
            getattr(self.dut, side + "Open_i").value = int(side == "srv")
            getattr(self.dut, side + "Close_i").value = 0
            getattr(self.dut, side + "Inject_i").value = 0
            getattr(self.dut, side + "MAppTReady").value = 1
            getattr(self.dut, side + "MTspTReady").value = 1
        for suffix in ("AWADDR", "AWPROT", "AWVALID", "WDATA", "WSTRB", "WVALID",
                       "BREADY", "ARADDR", "ARPROT", "ARVALID", "RREADY"):
            getattr(self.dut, "S_AXI_" + suffix).value = 0

        self.tasks = [
            cocotb.start_soon(Clock(self.clk, 10, unit="ns").start()),
            cocotb.start_soon(self.collect()),
        ]
        await self.cycle(16)
        self.dut.axisRst.value = 0
        await self.cycle(16)

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.clk, propagation_time=2)
            self.check_link()

    def check_link(self):
        # The collector records link failures instead of raising them, so the
        # message reaches the test log rather than an unlabeled task error.
        if self.failure is not None:
            raise AssertionError(self.failure)

    async def collect(self):
        """Lifetime agent: observe accepted server frames until TB cleanup."""
        frame = []
        while True:
            await RisingEdge(self.clk)
            self.tick += 1
            if int(self.dut.axisRst.value):
                continue
            if self.require_connected and self.failure is None:
                status = int(self.dut.srvStatusReg_o.value)
                if status & STATUS_ACK_ERR:
                    self.failure = f"Server raised ackErr at cycle {self.tick}; status=0x{status:x}"
                elif not int(self.dut.srvConnected_o.value):
                    self.failure = f"Server disconnected at cycle {self.tick}; status=0x{status:x}"
            if int(self.dut.srvMTspTValid.value) and int(self.dut.srvMTspTReady.value):
                beat = self.output.snapshot()
                assert beat.sof == int(not frame), "Unexpected RSSI frame boundary"
                assert beat.keep == 0xFF and not beat.eofe, beat
                frame.append(beat)
                if beat.last:
                    wire = b"".join(protocol_bytes_from_stream_word(b.data) for b in frame)
                    header = parse_header(wire)
                    assert checksum_is_valid(wire[:header.header_length]), header
                    self.frames.append((header, frame))
                    frame = []

    async def send(self, endpoint, beats):
        # Sample the accepting edge, not TREADY for the following cycle. Hold
        # the source through the registered FIFO/RAM propagation delay.
        for beat in beats:
            await FallingEdge(self.clk)
            endpoint.drive(beat)
            for _ in range(1024):
                await RisingEdge(self.clk)
                if int(endpoint._sig("TReady").value):
                    break
            else:
                self.check_link()
                raise AssertionError(f"No accepted transfer on {endpoint.prefix}")
        await FallingEdge(self.clk)
        endpoint.set_idle()

    async def send_header(self, header):
        words = stream_words_from_header(header)
        await self.send(self.peer, [
            SsiBeat(data=word, keep=0xFF, last=int(i == len(words) - 1), sof=int(i == 0))
            for i, word in enumerate(words)
        ])

    async def receive(self):
        for _ in range(256):
            if self.frames:
                return self.frames.popleft()
            await self.cycle()
        self.check_link()
        raise AssertionError("Server did not emit the expected RSSI segment")

    async def connect(self):
        params = RssiParams(
            max_outs_seg=16, max_seg_size=32, retrans_tout=512,
            cumul_ack_tout=4, null_seg_tout=2048, max_retrans=16,
            max_cum_ack=1, timeout_unit=6,
        )
        await self.send_header(build_syn_header(
            sequence=CLIENT_SEQUENCE, acknowledge=0, params=params,
        ))
        header, beats = await self.receive()
        assert header.flags == RSSI_FLAG_SYN | RSSI_FLAG_ACK and len(beats) == 3
        assert header.acknowledge == CLIENT_SEQUENCE
        await self.ack(header.sequence)
        for _ in range(128):
            await self.cycle()
            if int(self.dut.srvConnected_o.value):
                break
        else:
            raise AssertionError("Server did not accept the final handshake ACK")
        self.require_connected = True
        return header.sequence

    async def ack(self, sequence):
        # A pure ACK does not consume the peer's next DATA sequence number.
        await self.send_header(build_ack_header(sequence=CLIENT_SEQUENCE + 1, acknowledge=sequence))


@cocotb.test(timeout_time=400, timeout_unit="us")
async def reordered_stale_ack_does_not_reset_connection_test(dut):
    tb = TB(dut)
    try:
        await tb.start()
        next_sequence = (await tb.connect() + 1) & 0xFF

        trials = [(stale, gap) for stale in STALE_INDEXES for gap in range(0, 20)]
        for trial, (stale_index, gap) in enumerate(trials):
            sequences = []
            for index in range(SEGMENTS_PER_TRIAL):
                word = 0xACE0_0000_0000_0000 | (trial << 8) | index
                await tb.send(tb.app, [SsiBeat(data=word, keep=0xFF, last=1, sof=1)])
                header, beats = await tb.receive()
                assert header.flags == RSSI_FLAG_ACK, f"trial={trial}: expected DATA, got {header}"
                assert header.sequence == next_sequence, f"trial={trial}: {header}"
                assert [beat.data for beat in beats[1:]] == [word], f"trial={trial}: {beats}"
                sequences.append(header.sequence)
                next_sequence = (next_sequence + 1) & 0xFF

            # Move the window base, then deliver a newer ACK followed by an
            # older one the peer built earlier but sent late.
            await tb.ack(sequences[BASE_INDEX])
            await tb.cycle(16)
            await tb.ack(sequences[NEWER_INDEX])
            await tb.cycle(gap)
            await tb.ack(sequences[stale_index])
            await tb.cycle(8)
            await tb.ack(sequences[-1])
            await tb.cycle(16)

            status = int(dut.srvStatusReg_o.value)
            context = f"trial={trial} stale=s{stale_index} gap={gap}"
            tb.check_link()
            assert status & STATUS_CONNECTED, f"{context}: status=0x{status:x}"
            assert not status & (STATUS_RETRANS_MAX | STATUS_ACK_ERR), (
                f"{context}: status=0x{status:x}"
            )
            assert not tb.frames, f"{context}: unexpected server traffic {list(tb.frames)}"

        # Every DATA segment was ACKed, so a drained window must stay silent
        # past the retransmission timeout.
        await tb.cycle(PARAMETERS["RETRANS_TOUT_G"] + 64)
        assert not tb.frames, f"Unexpected retransmission: {list(tb.frames)}"
    finally:
        await cancel_and_join_tasks(tb.tasks)


def test_RssiCoreStaleAck():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicoreintegrationwrapper",
        parameters=PARAMETERS,
    )
