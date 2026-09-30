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
# - Purpose: Local BUSY must advertise the application FIFO pause condition
#   that stops RX delivery, including when pause occurs below one segment.
# - DUT: Production server RssiCore, checksum, monitor, connection FSM, RAM
#   and FIFOs through RssiCoreIntegrationWrapper; unused RTL client stays closed.
#   Reuse the independent RSSI wire oracle and SSI endpoints for all transfers.
# - Sweep: Segment address widths 4 and 5, FIFO pause thresholds 8 and 16 words.
# - Stimulus: Negotiate a session; stall the application; fill through legal
#   DATA until BUSY; stop DATA and observe repeated BUSY ACKs; drain; probe
#   release with NULL; resume DATA; check cessation of periodic ACKs.
# - Checks: Exact payload/SSI delivery, stalled-beat stability, header checksum,
#   sequence/ACK progress, persistent BUSY advertisement and BUSY=0 recovery.
#   An explicit NULL probe is used; unsolicited falling-edge notification and
#   execution of a real Rogue peer are outside this regression.
# - Timing: One timeout unit per clock. NULL timeout exceeds the entire bounded
#   scenario so this test does not depend on pending #1489's ACK-based liveness
#   fix. Sources drive on falling edges and sample accepting rising edges;
#   status samples wait beyond TPD_G. TB owns and cancels all lifetime tasks.

from collections import deque

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from tests.common.regression_utils import (
    cancel_and_join_tasks,
    run_surf_vhdl_test,
    sample_after_tpd,
)
from tests.protocols.rssi.rssi_test_utils import (
    RSSI_FLAG_ACK,
    RSSI_FLAG_BUSY,
    RSSI_FLAG_SYN,
    RssiParams,
    build_ack_header,
    build_data_header,
    build_null_header,
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
    "NULL_TOUT_G": 8192,
    "MAX_RETRANS_CNT_G": 16,
    "MAX_CUM_ACK_CNT_G": 1,
}
CLIENT_SEQUENCE = 0x20


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.axisClk
        self.peer = FlatSsiEndpoint(dut, prefix="srvSTsp")
        self.output = FlatSsiEndpoint(dut, prefix="srvMTsp")
        self.frames = deque()
        self.wire_history = []
        self.received_app = []
        self.app_output = FlatSsiEndpoint(dut, prefix="srvMApp")
        self.tick = 0
        self.require_connected = False
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
        stalled_app = None
        while True:
            await RisingEdge(self.clk)
            self.tick += 1
            if int(self.dut.axisRst.value):
                continue
            if self.require_connected:
                assert int(self.dut.srvConnected_o.value), (
                    f"Server disconnected during checked traffic at cycle {self.tick}; "
                    f"status=0x{int(self.dut.srvStatusReg_o.value):x}"
                )
            app_valid = int(self.dut.srvMAppTValid.value)
            app_ready = int(self.dut.srvMAppTReady.value)
            if stalled_app is not None:
                assert app_valid and self.app_output.snapshot() == stalled_app, "Unstable stalled application beat"
            if app_valid and app_ready:
                self.received_app.append(self.app_output.snapshot())
            stalled_app = self.app_output.snapshot() if app_valid and not app_ready else None
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
                    self.wire_history.append((self.tick, header, frame))
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
            cumul_ack_tout=4, null_seg_tout=PARAMETERS["NULL_TOUT_G"], max_retrans=16,
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


@cocotb.test(timeout_time=200, timeout_unit="us")
async def sustained_local_busy_ack_and_release_preserves_data(dut):
    tb = TB(dut)
    try:
        await tb.start()
        server_next = await tb.connect()
        scenario_start = tb.tick
        dut.srvMAppTReady.value = 0
        next_sequence = CLIENT_SEQUENCE + 1
        expected = []

        async def send_data(frame_index):
            nonlocal next_sequence
            payload = [SsiBeat(data=0xB057_0000_0000_0000 | (frame_index << 8) | i,
                               keep=0xFF, sof=int(i == 0), last=int(i == 3))
                       for i in range(4)]
            header = build_data_header(sequence=next_sequence,
                                       acknowledge=(server_next - 1) & 0xFF)
            words = stream_words_from_header(header)
            await tb.send(tb.peer, [SsiBeat(data=words[0], keep=0xFF, sof=1, last=0)] + [
                SsiBeat(data=b.data, keep=b.keep, sof=0, last=b.last) for b in payload
            ])
            expected.extend(payload)
            next_sequence = (next_sequence + 1) & 0xFF

        # Fill the application FIFO through validated DATA. Respect peer BUSY
        # as soon as it appears; all traffic is within the negotiated window.
        for frame_index in range(20):
            await send_data(frame_index)
            header, beats = await tb.receive()
            assert header.flags in (RSSI_FLAG_ACK, RSSI_FLAG_ACK | RSSI_FLAG_BUSY)
            assert len(beats) == 1 and header.sequence == server_next
            if header.busy:
                assert ((next_sequence - 1 - header.acknowledge) & 0xFF) <= 1, header
                break
            assert header.acknowledge == (next_sequence - 1) & 0xFF
        else:
            raise AssertionError("Application backpressure never produced a BUSY ACK")
        assert not tb.received_app, "Application consumed DATA while stalled"

        # Let the last DATA settle before checking a stable acknowledgment.
        # Plain peer ACKs exercise control reception without requesting a
        # response. Observe several retransmission periods well inside the
        # NULL timeout; ACK-based receive liveness is not required here.
        await tb.cycle(64)
        busy_ack = tb.wire_history[-1][1].acknowledge
        history_start = len(tb.wire_history)
        for _ in range(12):
            await tb.send_header(build_ack_header(
                sequence=next_sequence, acknowledge=(server_next - 1) & 0xFF))
            await tb.cycle(64)
        repeats = tb.wire_history[history_start:]
        assert len(repeats) >= 4, "Persistent BUSY did not produce repeated wire ACKs"
        for _, header, beats in repeats:
            assert header.flags == RSSI_FLAG_ACK | RSSI_FLAG_BUSY, header
            assert len(beats) == 1 and header.sequence == server_next, header
            assert header.acknowledge == busy_ack, header
        half_retrans = PARAMETERS["RETRANS_TOUT_G"] // 2
        for first, second in zip(repeats, repeats[1:]):
            gap = second[0] - first[0]
            # Timer starts at header construction, not wire acceptance. Allow
            # bounded core pipeline/arbitration latency while distinguishing
            # the 128-cycle policy from the 4-cycle cumulative-ACK timeout.
            assert half_retrans <= gap <= half_retrans + 48, gap
        assert not tb.received_app, "Application backpressure was not held"

        # Drain every buffered frame and check no loss, duplication or damage.
        dut.srvMAppTReady.value = 1
        for _ in range(256):
            await tb.cycle()
            if len(tb.received_app) == len(expected):
                break
        else:
            raise AssertionError("Buffered application DATA did not drain")
        assert tb.received_app == expected
        await tb.cycle(32)
        # Only control replies may be queued before the fresh NULL probe.
        for header, beats in tb.frames:
            assert header.flags in (RSSI_FLAG_ACK, RSSI_FLAG_ACK | RSSI_FLAG_BUSY), header
            assert len(beats) == 1 and header.sequence == server_next, header
        tb.frames.clear()

        # A NULL is a legal sequenced keepalive while the peer still remembers
        # BUSY. Its reply communicates current BUSY=0 without requiring a
        # falling-edge notification that this monitor does not implement.
        await tb.send_header(build_null_header(
            sequence=next_sequence, acknowledge=(server_next - 1) & 0xFF))
        next_sequence = (next_sequence + 1) & 0xFF
        header, beats = await tb.receive()
        assert header.flags == RSSI_FLAG_ACK and len(beats) == 1, header
        assert header.sequence == server_next
        assert header.acknowledge == (next_sequence - 1) & 0xFF, header

        # Resume only after observing BUSY=0 and verify the complete stream.
        await send_data(100)
        header, beats = await tb.receive()
        assert header.flags == RSSI_FLAG_ACK and len(beats) == 1, header
        assert header.acknowledge == (next_sequence - 1) & 0xFF, header
        await tb.cycle(64)
        assert tb.received_app == expected, "Lost, duplicated or corrupted application DATA"
        quiet_start = len(tb.wire_history)
        await tb.cycle(2 * PARAMETERS["RETRANS_TOUT_G"])
        assert len(tb.wire_history) == quiet_start, "Periodic ACKs continued after BUSY cleared"
        assert tb.received_app == expected
        assert tb.tick - scenario_start < PARAMETERS["NULL_TOUT_G"], "BUSY scenario exceeded its liveness margin"
        dut._log.info("Checked %d periodic BUSY ACKs and %d application beats through release",
                      len(repeats), len(expected))
    finally:
        await cancel_and_join_tasks(tb.tasks)


@pytest.mark.parametrize("segment_addr_size", [4, 5], ids=["pause8", "pause16"])
def test_RssiCoreBusy(segment_addr_size):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicoreintegrationwrapper",
        parameters={**PARAMETERS, "SEGMENT_ADDR_SIZE_G": segment_addr_size},
    )
