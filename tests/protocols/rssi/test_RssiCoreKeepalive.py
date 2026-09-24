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
# - Purpose: Reproduce the server keepalive regression introduced by #1454:
#   an actively receiving peer sends ACKs frequently enough to defer NULLs.
# - DUT shape: The server in RssiCoreIntegrationWrapper uses production TX/RX,
#   checksum, monitor, connection logic, FIFOs and segment RAM. The RTL client
#   is held closed; an independent Python wire peer performs SYN/SYN+ACK/ACK
#   negotiation, checks outgoing DATA, and replies only with ACK segments.
#   This is core integration coverage, not a deployed Rogue/UDP test.
# - Stimulus: Send distinct one-, two- and four-word application frames for
#   at least four negotiated NULL timeouts, with no peer DATA or NULL traffic.
#   Then drain the acknowledged window and make the peer completely silent.
# - Checks: Exact payload/sequence/SSI framing, valid header checksums, ACK
#   spacing shorter than the client NULL interval, continuous connection,
#   and subsequent closure specifically from the server NULL timeout.
# - Timing: The wrapper accelerates one timeout unit to one clock. Sources
#   drive on falling edges and sample acceptance at rising edges before
#   registered TREADY changes;
#   they hold the beat through TPD_G. The collector samples accepted transfers
#   at rising edges. Status polling waits beyond the default 1 ns TPD_G.

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
    "WINDOW_ADDR_SIZE_G": 2,
    "SEGMENT_ADDR_SIZE_G": 5,
    "MAX_NUM_OUTS_SEG_G": 4,
    "MAX_SEG_SIZE_G": 32,
    "ACK_TOUT_G": 4,
    "RETRANS_TOUT_G": 256,
    "NULL_TOUT_G": 1024,
    "MAX_RETRANS_CNT_G": 16,
    "MAX_CUM_ACK_CNT_G": 1,
}
NULL_CYCLES = PARAMETERS["NULL_TOUT_G"]
CLIENT_SEQUENCE = 0x20


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
        self.ack_ticks = []
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

    async def collect(self):
        """Lifetime agent: observe accepted server frames until TB cleanup."""
        frame = []
        while True:
            await RisingEdge(self.clk)
            self.tick += 1
            if int(self.dut.axisRst.value):
                continue
            if self.require_connected:
                assert int(self.dut.srvConnected_o.value), (
                    f"Server disconnected during ACK-only streaming at cycle {self.tick}; "
                    f"status=0x{int(self.dut.srvStatusReg_o.value):x}"
                )
                assert not int(self.dut.srvMAppTValid.value), "Peer sent no application DATA"
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
        raise AssertionError("Server did not emit the expected RSSI segment")

    async def connect(self):
        params = RssiParams(
            max_outs_seg=4, max_seg_size=32, retrans_tout=256,
            cumul_ack_tout=4, null_seg_tout=1024, max_retrans=16,
            max_cum_ack=1, timeout_unit=6,
        )
        await self.send_header(build_syn_header(
            sequence=CLIENT_SEQUENCE, acknowledge=0, params=params,
        ))
        header, beats = await self.receive()
        assert header.flags == RSSI_FLAG_SYN | RSSI_FLAG_ACK and len(beats) == 3
        assert header.acknowledge == CLIENT_SEQUENCE
        assert header.params == params, "Server must accept the advertised timeout contract"
        await self.ack(header.sequence)
        for _ in range(128):
            await self.cycle()
            if int(self.dut.srvConnected_o.value):
                break
        else:
            raise AssertionError("Server did not accept the final handshake ACK")
        self.require_connected = True
        return (header.sequence + 1) & 0xFF

    async def ack(self, sequence):
        # A pure ACK does not consume the peer's next DATA sequence number.
        header = build_ack_header(sequence=CLIENT_SEQUENCE + 1, acknowledge=sequence)
        assert len(header) == 8 and header[0] == RSSI_FLAG_ACK
        await self.send_header(header)
        self.ack_ticks.append(self.tick)


@cocotb.test(timeout_time=200, timeout_unit="us")
async def server_stream_with_ack_only_peer_stays_connected_then_times_out(dut):
    tb = TB(dut)
    try:
        await tb.start()
        expected_sequence = await tb.connect()
        stream_start = tb.tick

        # Payload and sequence assertions prevent ACKs to phantom/duplicate
        # traffic from being counted as successful streaming coverage.
        for frame_index in range(1024):
            words = [
                0x1234_5678_0000_0000 | (frame_index << 8) | word_index
                for word_index in range((1, 2, 4)[frame_index % 3])
            ]
            await tb.send(tb.app, [
                SsiBeat(data=word, keep=0xFF, last=int(i == len(words) - 1), sof=int(i == 0))
                for i, word in enumerate(words)
            ])
            header, beats = await tb.receive()
            assert header.flags == RSSI_FLAG_ACK, header
            assert header.sequence == expected_sequence, header
            assert header.acknowledge == CLIENT_SEQUENCE, header
            assert [beat.data for beat in beats[1:]] == words, (
                f"Server DATA payload mismatch for frame {frame_index}: {beats}"
            )
            await tb.ack(header.sequence)
            expected_sequence = (expected_sequence + 1) & 0xFF
            if tb.tick - stream_start >= 4 * NULL_CYCLES:
                break
        else:
            raise AssertionError("Traffic did not span four NULL timeout intervals")

        max_ack_gap = max(b - a for a, b in zip(tb.ack_ticks, tb.ack_ticks[1:]))
        assert max_ack_gap < NULL_CYCLES // 3, max_ack_gap
        assert len(tb.ack_ticks) > PARAMETERS["MAX_NUM_OUTS_SEG_G"]
        dut._log.info("Delivered %d frames over %d clocks; max ACK gap %d, NULL timeout %d",
                      frame_index + 1, tb.tick - stream_start, max_ack_gap, NULL_CYCLES)

        # Let the final ACK reach the monitor and TX window, then send nothing.
        # With no outstanding DATA, closure must be liveness, not retransmission.
        await tb.cycle(32)
        assert not tb.frames, "Unexpected server traffic after the final DATA ACK"
        silence_start = tb.tick
        tb.require_connected = False
        for _ in range(NULL_CYCLES + 64):
            await tb.cycle()
            if not int(dut.srvConnected_o.value):
                break
        else:
            raise AssertionError("Silent peer did not trigger the server NULL timeout")
        assert tb.tick - silence_start >= NULL_CYCLES - 64, "Premature server timeout"
        await tb.cycle(2)
        status = int(dut.srvStatusReg_o.value)
        assert status & (1 << 2), f"Expected NULL timeout status, got 0x{status:x}"
        assert not status & ((1 << 1) | (1 << 3)), f"Unexpected retransmit/ACK error: 0x{status:x}"
    finally:
        await cancel_and_join_tasks(tb.tasks)


def test_RssiCoreKeepalive():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicoreintegrationwrapper",
        parameters=PARAMETERS,
    )
