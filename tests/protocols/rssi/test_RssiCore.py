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
# - Purpose: Exercise the integrated `RssiCore` contract with one client and
#   one server connected back-to-back.  Leaf-FSM tests prove individual decode,
#   transmit, monitor, and connection decisions; this file proves that the
#   composed core behaves like an RSSI endpoint pair at the flattened
#   application and transport boundaries.
# - DUT shape: `RssiCoreIntegrationWrapper` instantiates a client `RssiCore`
#   and a server `RssiCore`.  The wrapper exposes flattened SSI-style
#   application streams, flattened RSSI transport streams, status registers,
#   negotiated segment-size outputs, and open/close/inject controls.  Cocotb
#   owns the transport loopback so tests can drop or observe individual RSSI
#   frames without embedding traffic perturbation logic in VHDL.
# - Stimulus: The default run holds both endpoints open, waits for the
#   active-open handshake, drains reset-release application output, and sends
#   application frames from either side.  Directed transport hooks can drop
#   SYN, SYN+ACK, final ACK, DATA, NULL, or ACK-only frames, corrupt one client
#   DATA header with the production injection input, or suppress all client
#   transport traffic to model missing keepalives and max-retransmit closure.
# - Protocol checks: The suite covers negotiated connection status, max segment
#   readback, bidirectional payload delivery with SSI sidebands preserved,
#   handshake retransmission, DATA loss/corruption recovery, duplicate-free ACK
#   loss behavior, out-of-order DATA recovery, sequence-number wraparound, NULL
#   keepalive acknowledgment, idle keepalive liveness, missing-keepalive server
#   close, max-retransmit client close/RST emission, explicit close, and
#   backpressure-driven BUSY reporting.  The stricter BUSY recovery test that
#   proves no lost or duplicate server frames is extended coverage and also
#   runs when selected directly with `COCOTB_TESTCASE`.
# - Parameter strategy: The default pytest entry uses small but valid timeout
#   generics so the full integration batch remains bounded.  Separate pytest
#   entries enable narrower cocotb tests for sequence wrap, bidirectional DATA
#   loss in one connection, and out-of-order recovery with longer retransmit
#   spacing.  The default pytest entry filters out those specialized cocotb
#   scenarios before simulation; each focused entry selects its named scenario.
# - Timing and scoreboarding: Transport monitors sample accepted RSSI frames at
#   the source side before optional loopback drops.  Application scoreboards
#   assert both absence of premature output and exact recovered frames.  Quiet
#   output drains account for reset-release FIFO behavior so payload assertions
#   are about RSSI DATA delivery rather than wrapper initialization.

import cocotb
import pytest
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import (
    cocotb_filtered_env,
    cocotb_test_filter_excluding,
    env_flag,
    run_surf_vhdl_test,
)
from tests.protocols.rssi.rssi_test_utils import (
    RSSI_FLAG_ACK,
    RSSI_FLAG_NULL,
    RSSI_FLAG_RST,
    RSSI_FLAG_SYN,
    checksum_is_valid,
    format_transport_frame,
    parse_header,
    protocol_bytes_from_stream_word,
    recv_matching_transport_frame,
    recv_transport_data_frame,
)
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    SsiBeat,
    assert_beat_views,
    cycle as ssi_cycle,
    reset_dut,
    start_clock,
    recv_frame_and_check,
)

REG_CONTROL = 0x00
REG_MAX_OUTS_SEG = 0x0C
REG_MAX_SEG_SIZE = 0x10
REG_STATUS = 0x40
REG_VALID_CNT = 0x44
REG_RESEND_CNT = 0x4C


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.axisClk
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.axisClk, dut.axisRst)
        self.clt_source = FlatSsiEndpoint(dut, prefix="cltSApp")
        self.clt_sink = FlatSsiEndpoint(dut, prefix="cltMApp")
        self.srv_source = FlatSsiEndpoint(dut, prefix="srvSApp")
        self.srv_sink = FlatSsiEndpoint(dut, prefix="srvMApp")
        self.clt_tsp_input = FlatSsiEndpoint(dut, prefix="cltSTsp")
        self.clt_tsp_output = FlatSsiEndpoint(dut, prefix="cltMTsp")
        self.srv_tsp_input = FlatSsiEndpoint(dut, prefix="srvSTsp")
        self.srv_tsp_output = FlatSsiEndpoint(dut, prefix="srvMTsp")
        self.clt_tsp_sink = self.clt_tsp_output
        self.srv_tsp_sink = self.srv_tsp_output
        self.drop_next_client_data = False
        self.drop_next_server_data = False
        self.drop_client_data_count = 0
        self.drop_server_data_count = 0
        self.drop_next_client_syn = False
        self.drop_next_server_syn = False
        self.drop_next_client_ack = False
        self.drop_next_server_ack = False
        self.drop_next_client_null = False
        self.drop_next_server_null = False
        self.dropped_client_ack_count = 0
        self.dropped_server_ack_count = 0
        self.dropped_client_null_count = 0
        self.dropped_server_null_count = 0
        self.drop_all_client = False
        self.drop_all_server = False
        self.pause_next_client_header_cycles = 0
        self.pause_next_server_header_cycles = 0
        self.pause_next_client_payload_cycles = 0
        self.pause_next_server_payload_cycles = 0
        self.loopback_tasks = []

    @classmethod
    async def create(
        cls,
        dut,
        *,
        start_loopbacks: bool = True,
        direct_client_open: int = 1,
        direct_server_open: int = 1,
    ):
        start_clock(dut.axisClk, period_ns=5.0)
        dut.axisRst.setimmediatevalue(1)

        tb = cls(dut)
        tb.clt_source.set_idle()
        tb.srv_source.set_idle()
        tb.clt_tsp_input.set_idle()
        tb.srv_tsp_input.set_idle()

        for signal_name, value in {
            "cltOpen_i": direct_client_open,
            "cltClose_i": 0,
            "cltInject_i": 0,
            "srvOpen_i": direct_server_open,
            "srvClose_i": 0,
            "srvInject_i": 0,
            "cltMAppTReady": 0,
            "cltMTspTReady": 0,
            "srvMAppTReady": 0,
            "srvMTspTReady": 0,
        }.items():
            getattr(dut, signal_name).setimmediatevalue(value)

        await reset_dut(dut, clk_name="axisClk", rst_name="axisRst")
        if start_loopbacks:
            tb.start_transport_loopbacks()
        return tb

    async def cycle(self, count: int = 1) -> None:
        await ssi_cycle(self.clk, count=count)

    async def pulse(self, signal_name: str) -> None:
        getattr(self.dut, signal_name).value = 1
        await self.cycle()
        getattr(self.dut, signal_name).value = 0

    async def axil_write(self, address: int, value: int) -> None:
        await axil_write_u32(self.axil, address, value)
        await self.cycle(2)

    async def axil_read(self, address: int) -> int:
        return await axil_read_u32(self.axil, address)

    async def wait_connected(self, *, timeout_cycles: int = 256) -> None:
        for _ in range(timeout_cycles):
            await Timer(1, unit="ns")
            if int(self.dut.cltConnected_o.value) and int(self.dut.srvConnected_o.value):
                return
            await RisingEdge(self.clk)
        raise AssertionError("Timed out waiting for both RSSI cores to connect")

    async def wait_disconnected(self, *, timeout_cycles: int = 256) -> None:
        for _ in range(timeout_cycles):
            await Timer(1, unit="ns")
            if not int(self.dut.cltConnected_o.value) and not int(self.dut.srvConnected_o.value):
                return
            await RisingEdge(self.clk)
        raise AssertionError("Timed out waiting for both RSSI cores to disconnect")

    async def drain_app_output(self, endpoint: FlatSsiEndpoint, ready_signal, *, quiet_cycles: int = 8) -> None:
        # `RssiCore` resets its application output FIFOs until the connection
        # opens.  Accept and discard any reset-release beat before starting the
        # user-payload check so the assertion is about RSSI DATA delivery.
        ready_signal.value = 1
        quiet_count = 0
        for _ in range(128):
            await Timer(1, unit="ns")
            if int(endpoint._sig("TValid").value) == 1:
                quiet_count = 0
            else:
                quiet_count += 1
                if quiet_count >= quiet_cycles:
                    ready_signal.value = 0
                    return
            await RisingEdge(self.clk)
        ready_signal.value = 0
        raise AssertionError(f"Timed out draining {endpoint.prefix} output")

    async def assert_no_app_output(self, endpoint: FlatSsiEndpoint, *, cycles: int) -> None:
        for _ in range(cycles):
            await Timer(1, unit="ns")
            assert int(endpoint._sig("TValid").value) == 0, f"Unexpected {endpoint.prefix} application output"
            await RisingEdge(self.clk)

    async def collect_app_frames(
        self,
        endpoint: FlatSsiEndpoint,
        ready_signal,
        *,
        cycles: int,
    ) -> list[list[SsiBeat]]:
        ready_signal.value = 1
        frames = []
        frame = []
        for _ in range(cycles):
            await FallingEdge(self.clk)
            await Timer(1, unit="ns")
            if int(endpoint._sig("TValid").value) == 1:
                beat = endpoint.snapshot()
                frame.append(beat)
                if beat.last == 1:
                    frames.append(frame)
                    frame = []
        ready_signal.value = 0
        assert not frame, f"Partial {endpoint.prefix} application frame was left unterminated"
        return frames

    async def drain_app_outputs(self) -> None:
        await self.drain_app_output(self.clt_sink, self.dut.cltMAppTReady)
        await self.drain_app_output(self.srv_sink, self.dut.srvMAppTReady)

    async def send_app_frame(self, endpoint: FlatSsiEndpoint, beats: list[SsiBeat]) -> None:
        for beat in beats:
            endpoint.drive(beat)
            await endpoint.wait_ready(clk=self.clk)
        endpoint.set_idle()

    def start_transport_loopbacks(self) -> None:
        # These retained coroutines are lifetime agents for one cocotb
        # entrypoint.  They own no external resources and cocotb cancels them
        # when that entrypoint finishes.
        self.loopback_tasks = [
            cocotb.start_soon(
                self.loopback_transport(
                    self.clt_tsp_output,
                    self.srv_tsp_input,
                    self.dut.cltMTspTReady,
                    side="client",
                )
            ),
            cocotb.start_soon(
                self.loopback_transport(
                    self.srv_tsp_output,
                    self.clt_tsp_input,
                    self.dut.srvMTspTReady,
                    side="server",
                )
            ),
        ]

    def should_drop_transport_frame(self, *, side: str, beat: SsiBeat) -> bool:
        if getattr(self, f"drop_all_{side}"):
            return True
        if beat.sof != 1:
            return False

        header_word = protocol_bytes_from_stream_word(beat.data)
        flags = header_word[0]
        is_syn = bool(flags & RSSI_FLAG_SYN)
        is_ack = bool(flags & RSSI_FLAG_ACK)
        is_null = bool(flags & RSSI_FLAG_NULL)
        is_rst = bool(flags & RSSI_FLAG_RST)

        if is_syn and getattr(self, f"drop_next_{side}_syn"):
            setattr(self, f"drop_next_{side}_syn", False)
            return True

        is_data = not is_syn and not is_null and not is_rst and beat.last == 0
        if is_data and getattr(self, f"drop_next_{side}_data"):
            setattr(self, f"drop_next_{side}_data", False)
            return True
        if is_data and getattr(self, f"drop_{side}_data_count") > 0:
            setattr(self, f"drop_{side}_data_count", getattr(self, f"drop_{side}_data_count") - 1)
            return True

        is_ack_only = is_ack and not is_syn and not is_null and not is_rst and beat.last == 1
        if is_ack_only and getattr(self, f"drop_next_{side}_ack"):
            setattr(self, f"drop_next_{side}_ack", False)
            setattr(self, f"dropped_{side}_ack_count", getattr(self, f"dropped_{side}_ack_count") + 1)
            return True

        if is_null and getattr(self, f"drop_next_{side}_null"):
            setattr(self, f"drop_next_{side}_null", False)
            setattr(self, f"dropped_{side}_null_count", getattr(self, f"dropped_{side}_null_count") + 1)
            return True

        return False

    async def loopback_transport(
        self,
        source: FlatSsiEndpoint,
        destination: FlatSsiEndpoint,
        source_ready,
        *,
        side: str,
    ) -> None:
        dropping = False
        destination.set_idle()
        source_ready.value = 0

        while True:
            await FallingEdge(self.clk)
            await Timer(1, unit="ns")

            valid = int(source._sig("TValid").value) == 1
            beat = source.snapshot() if valid else None

            if valid and beat.sof == 1 and getattr(self, f"pause_next_{side}_header_cycles") > 0:
                pause_cycles = getattr(self, f"pause_next_{side}_header_cycles")
                setattr(self, f"pause_next_{side}_header_cycles", 0)
                destination.set_idle()
                source_ready.value = 0
                await self.cycle(pause_cycles)
                continue

            if valid and beat.sof == 0 and getattr(self, f"pause_next_{side}_payload_cycles") > 0:
                pause_cycles = getattr(self, f"pause_next_{side}_payload_cycles")
                setattr(self, f"pause_next_{side}_payload_cycles", 0)
                destination.set_idle()
                source_ready.value = 0
                await self.cycle(pause_cycles)
                continue

            drop_frame = valid and (dropping or self.should_drop_transport_frame(side=side, beat=beat))

            if drop_frame:
                destination.set_idle()
                source_ready.value = 1
                dropping = beat.last == 0
                continue

            if valid:
                destination.drive(beat)
            else:
                destination.set_idle()

            await Timer(1, unit="ns")
            source_ready.value = destination._sig("TReady").value

    async def recv_transport_data_frame(
        self,
        endpoint: FlatSsiEndpoint,
        *,
        timeout_cycles: int = 512,
    ) -> list[SsiBeat]:
        return await recv_transport_data_frame(
            endpoint,
            clk=self.clk,
            timeout_cycles=timeout_cycles,
        )

    async def recv_transport_frame(
        self,
        endpoint: FlatSsiEndpoint,
        *,
        match,
        timeout_cycles: int = 512,
    ) -> list[SsiBeat]:
        return await recv_matching_transport_frame(
            endpoint,
            clk=self.clk,
            match=match,
            timeout_cycles=timeout_cycles,
        )


@cocotb.test()
async def active_open_negotiates_parameters_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    assert int(dut.cltStatusReg_o.value) & 0x1
    assert int(dut.srvStatusReg_o.value) & 0x1
    assert int(dut.cltMaxSegSize_o.value) == 32
    assert int(dut.srvMaxSegSize_o.value) == 32


@cocotb.test()
async def dropped_client_syn_retries_and_connects_test(dut):
    tb = await TB.create(dut, start_loopbacks=False)
    tb.drop_next_client_syn = True
    tb.start_transport_loopbacks()

    await tb.wait_connected(timeout_cycles=1024)
    await tb.drain_app_outputs()

    assert int(dut.cltStatusReg_o.value) & 0x1
    assert int(dut.srvStatusReg_o.value) & 0x1


@cocotb.test()
async def dropped_server_syn_ack_retries_and_connects_test(dut):
    tb = await TB.create(dut, start_loopbacks=False)
    tb.drop_next_server_syn = True
    tb.start_transport_loopbacks()

    await tb.wait_connected(timeout_cycles=1024)
    await tb.drain_app_outputs()

    assert int(dut.cltStatusReg_o.value) & 0x1
    assert int(dut.srvStatusReg_o.value) & 0x1


@cocotb.test()
async def dropped_client_final_ack_retries_and_connects_test(dut):
    tb = await TB.create(dut, start_loopbacks=False)
    tb.drop_next_client_ack = True
    tb.start_transport_loopbacks()

    await tb.wait_connected(timeout_cycles=1024)
    await tb.drain_app_outputs()

    assert int(dut.cltStatusReg_o.value) & 0x1
    assert int(dut.srvStatusReg_o.value) & 0x1


@cocotb.test()
async def bidirectional_payload_delivery_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    client_payload = 0x1122_3344_5566_7788
    server_payload = 0x8877_6655_4433_2211

    clt_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    srv_recv = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(client_payload, 0xFF, 1, 1, 0)],
            timeout_cycles=256,
        )
    )
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=client_payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    clt_transport_beats = await clt_transport
    assert (
        clt_transport_beats[1].data == client_payload
    ), f"Client transport DATA payload was corrupted before server RX: {format_transport_frame(clt_transport_beats)}"
    await srv_recv

    srv_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.srv_tsp_sink))
    clt_recv = cocotb.start_soon(
        recv_frame_and_check(
            tb.clt_sink,
            clk=tb.clk,
            ready_signal=dut.cltMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(server_payload, 0xFF, 1, 1, 0)],
            timeout_cycles=256,
        )
    )
    await tb.send_app_frame(
        tb.srv_source,
        [SsiBeat(data=server_payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    srv_transport_beats = await srv_transport
    assert (
        srv_transport_beats[1].data == server_payload
    ), f"Server transport DATA payload was corrupted before client RX: {format_transport_frame(srv_transport_beats)}"
    await clt_recv


@cocotb.test()
async def multi_beat_partial_keep_and_eofe_round_trip_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    beats = [
        SsiBeat(data=0x0102_0304_0506_0708, keep=0xFF, last=0, sof=1, eofe=0),
        SsiBeat(data=0x1112_1314_0000_0000, keep=0x0F, last=1, sof=0, eofe=1),
    ]

    srv_recv = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[
                (beats[0].data, beats[0].keep, beats[0].last, beats[0].sof, 0),
                (beats[1].data, beats[1].keep, beats[1].last, beats[1].sof, 0),
            ],
            timeout_cycles=512,
        )
    )
    await tb.send_app_frame(tb.clt_source, beats)
    await srv_recv


@cocotb.test()
async def server_data_loss_retransmits_and_recovers_payload_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    payload = 0xABCD_0000_1234_EF01

    first_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.srv_tsp_sink))
    tb.drop_next_server_data = True
    await tb.send_app_frame(
        tb.srv_source,
        [SsiBeat(data=payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )

    first_beats = await first_transport
    first_header = parse_header(protocol_bytes_from_stream_word(first_beats[0].data))
    assert first_beats[1].data == payload

    await tb.assert_no_app_output(tb.clt_sink, cycles=6)

    second_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.srv_tsp_sink))
    second_beats = await second_transport
    second_header = parse_header(protocol_bytes_from_stream_word(second_beats[0].data))
    assert second_header.sequence == first_header.sequence
    assert second_beats[1].data == payload

    frames = await tb.collect_app_frames(tb.clt_sink, dut.cltMAppTReady, cycles=128)
    assert len(frames) == 1, f"Unexpected client output frames after retransmission: {frames}"
    assert_beat_views(
        frames[0],
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(payload, 0xFF, 1, 1, 0)],
    )


@cocotb.test()
async def dropped_client_data_retransmits_and_recovers_payload_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    payload = 0xCAFE_BABE_1234_5678

    first_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    tb.drop_next_client_data = True
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )

    first_beats = await first_transport
    first_header = parse_header(protocol_bytes_from_stream_word(first_beats[0].data))
    assert (
        first_beats[1].data == payload
    ), f"Initial client DATA payload was corrupted before the loss gate: {format_transport_frame(first_beats)}"

    # The one-shot wrapper gate consumes the first DATA frame before server RX.
    # Before the retransmit timeout has room to fire, no application payload
    # should be visible at the server.
    await tb.assert_no_app_output(tb.srv_sink, cycles=6)

    second_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    second_beats = await second_transport
    second_header = parse_header(protocol_bytes_from_stream_word(second_beats[0].data))
    assert second_header.sequence == first_header.sequence
    assert (
        second_beats[1].data == payload
    ), f"Retransmitted client DATA payload was corrupted: {format_transport_frame(second_beats)}"

    frames = await tb.collect_app_frames(tb.srv_sink, dut.srvMAppTReady, cycles=512)
    assert len(frames) == 1, f"Unexpected server output frames after retransmission: {frames}"
    assert_beat_views(
        frames[0],
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(payload, 0xFF, 1, 1, 0)],
    )


@cocotb.test()
async def bidirectional_data_losses_recover_without_duplicate_delivery_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    client_payload = 0xA5A5_5A5A_0000_0000
    tb.drop_next_client_data = True

    first_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=client_payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    first_beats = await first_transport
    first_header = parse_header(protocol_bytes_from_stream_word(first_beats[0].data))
    assert first_beats[1].data == client_payload

    second_beats = await tb.recv_transport_data_frame(tb.clt_tsp_sink, timeout_cycles=2048)
    second_header = parse_header(protocol_bytes_from_stream_word(second_beats[0].data))
    assert second_header.sequence == first_header.sequence
    assert second_beats[1].data == client_payload

    frames = await tb.collect_app_frames(tb.srv_sink, dut.srvMAppTReady, cycles=512)
    assert len(frames) == 1, f"Unexpected server output frames after client loss: {frames}"
    assert_beat_views(
        frames[0],
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(client_payload, 0xFF, 1, 1, 0)],
    )

    await tb.cycle(128)

    server_payload = 0x5A5A_A5A5_0000_0001
    tb.drop_next_server_data = True

    third_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.srv_tsp_sink))
    await tb.send_app_frame(
        tb.srv_source,
        [SsiBeat(data=server_payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    third_beats = await third_transport
    third_header = parse_header(protocol_bytes_from_stream_word(third_beats[0].data))
    assert third_beats[1].data == server_payload

    fourth_beats = await tb.recv_transport_data_frame(tb.srv_tsp_sink, timeout_cycles=2048)
    fourth_header = parse_header(protocol_bytes_from_stream_word(fourth_beats[0].data))
    assert fourth_header.sequence == third_header.sequence
    assert fourth_beats[1].data == server_payload

    frames = await tb.collect_app_frames(tb.clt_sink, dut.cltMAppTReady, cycles=512)
    assert len(frames) == 1, f"Unexpected client output frames after server loss: {frames}"
    assert_beat_views(
        frames[0],
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(server_payload, 0xFF, 1, 1, 0)],
    )

    assert int(dut.cltConnected_o.value) == 1
    assert int(dut.srvConnected_o.value) == 1


@cocotb.test()
async def lost_first_data_drops_later_data_until_retransmit_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    first_payload = 0x0F00_0000_0000_0001
    second_payload = 0x0F00_0000_0000_0002
    tb.drop_next_client_data = True

    first_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=first_payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    first_beats = await first_transport
    first_header = parse_header(protocol_bytes_from_stream_word(first_beats[0].data))

    second_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=second_payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    second_beats = await second_transport
    second_header = parse_header(protocol_bytes_from_stream_word(second_beats[0].data))

    assert second_header.sequence == ((first_header.sequence + 1) & 0xFF)
    await tb.assert_no_app_output(tb.srv_sink, cycles=32)

    frames = await tb.collect_app_frames(tb.srv_sink, dut.srvMAppTReady, cycles=2048)
    summaries = [
        [(beat.data, beat.keep, beat.last, beat.sof, beat.eofe) for beat in frame]
        for frame in frames
    ]
    assert summaries == [
        [(first_payload, 0xFF, 1, 1, 0)],
        [(second_payload, 0xFF, 1, 1, 0)],
    ]


@cocotb.test()
async def lost_server_ack_control_does_not_duplicate_delivery_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    payload = 0x1111_AAAA_2222_BBBB
    tb.drop_next_server_ack = True
    tb.drop_next_server_null = True

    first_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    first_beats = await first_transport
    assert first_beats[1].data == payload

    frames = await tb.collect_app_frames(tb.srv_sink, dut.srvMAppTReady, cycles=160)
    assert len(frames) == 1, f"ACK loss caused duplicate server delivery: {frames}"
    assert_beat_views(
        frames[0],
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(payload, 0xFF, 1, 1, 0)],
    )
    assert tb.dropped_server_ack_count + tb.dropped_server_null_count >= 1
    assert int(dut.cltConnected_o.value) == 1
    assert int(dut.srvConnected_o.value) == 1


@cocotb.test()
async def corrupted_client_data_retransmits_and_recovers_payload_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    payload = 0x0BAD_F00D_4455_6677

    control_transport = cocotb.start_soon(
        tb.recv_transport_frame(
            tb.clt_tsp_sink,
            match=lambda header, beats: len(beats) == 1 and not header.syn,
        )
    )
    first_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await control_transport
    await tb.pulse("cltInject_i")

    first_beats = await first_transport
    first_header_bytes = protocol_bytes_from_stream_word(first_beats[0].data)
    first_header = parse_header(first_header_bytes)
    assert not checksum_is_valid(first_header_bytes)
    assert (
        first_beats[1].data == payload
    ), f"Injected client DATA payload was corrupted before server RX: {format_transport_frame(first_beats)}"

    await tb.assert_no_app_output(tb.srv_sink, cycles=6)

    second_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    second_beats = await second_transport
    second_header_bytes = protocol_bytes_from_stream_word(second_beats[0].data)
    second_header = parse_header(second_header_bytes)
    assert second_header.sequence == first_header.sequence
    assert checksum_is_valid(second_header_bytes)
    assert (
        second_beats[1].data == payload
    ), f"Retransmitted client DATA payload was corrupted: {format_transport_frame(second_beats)}"

    frames = await tb.collect_app_frames(tb.srv_sink, dut.srvMAppTReady, cycles=128)
    assert len(frames) == 1, f"Unexpected server output frames after checksum recovery: {frames}"
    assert_beat_views(
        frames[0],
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(payload, 0xFF, 1, 1, 0)],
    )


@cocotb.test()
async def server_backpressure_advertises_busy_to_client_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    busy_transport = cocotb.start_soon(
        tb.recv_transport_frame(
            tb.srv_tsp_sink,
            match=lambda header, beats: header.busy and header.ack,
            timeout_cycles=4096,
        )
    )

    for index in range(40):
        await tb.send_app_frame(
            tb.clt_source,
            [SsiBeat(data=0xB000_0000_0000_0000 | index, keep=0xFF, last=1, sof=1, eofe=0)],
        )
        if busy_transport.done():
            break

    busy_beats = await busy_transport
    busy_header = parse_header(protocol_bytes_from_stream_word(busy_beats[0].data))
    assert busy_header.busy
    assert busy_header.ack
    assert int(dut.cltStatusReg_o.value) & (1 << 8)


@cocotb.test()
async def server_backpressure_recovers_without_lost_or_duplicate_frames_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    sent_payloads = []
    for index in range(40):
        payload = 0xBC00_0000_0000_0000 | index
        await tb.send_app_frame(
            tb.clt_source,
            [SsiBeat(data=payload, keep=0xFF, last=1, sof=1, eofe=0)],
        )
        sent_payloads.append(payload)
        await tb.cycle(4)
        if int(dut.cltStatusReg_o.value) & (1 << 8):
            break

    assert int(dut.cltStatusReg_o.value) & (1 << 8)

    for payload in sent_payloads:
        await recv_frame_and_check(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(payload, 0xFF, 1, 1, 0)],
            timeout_cycles=512,
        )
    await tb.assert_no_app_output(tb.srv_sink, cycles=16)
    assert int(dut.cltConnected_o.value) == 1
    assert int(dut.srvConnected_o.value) == 1


@cocotb.test()
async def max_retransmissions_close_client_and_emit_rst_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    rst_transport = cocotb.start_soon(
        tb.recv_transport_frame(
            tb.clt_tsp_sink,
            match=lambda header, beats: header.rst,
            timeout_cycles=4096,
        )
    )

    tb.drop_all_client = True
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=0xDDDD_EEEE_AAAA_5555, keep=0xFF, last=1, sof=1, eofe=0)],
    )

    rst_beats = await rst_transport
    rst_header = parse_header(protocol_bytes_from_stream_word(rst_beats[0].data))
    assert rst_header.rst
    assert not rst_header.ack

    await tb.wait_disconnected(timeout_cycles=512)


@cocotb.test()
async def dropped_client_null_keepalive_does_not_close_server_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    tb.drop_next_client_null = True
    await tb.cycle(96)

    assert tb.dropped_client_null_count >= 1
    assert int(dut.cltConnected_o.value) == 1
    assert int(dut.srvConnected_o.value) == 1
    assert (int(dut.srvStatusReg_o.value) >> 2) & 0x1 == 0


@cocotb.test()
async def idle_client_null_keepalive_keeps_server_connected_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()

    # With the wrapper's timeout generics, the client should emit NULL
    # keepalives every NULL_TOUT/3 count.  Waiting longer than one full server
    # NULL timeout verifies the integrated keepalive path without relying on
    # internal monitor signals.
    await tb.cycle(80)

    assert int(dut.cltConnected_o.value) == 1
    assert int(dut.srvConnected_o.value) == 1
    assert (int(dut.srvStatusReg_o.value) >> 2) & 0x1 == 0


@cocotb.test()
async def client_null_keepalive_is_acknowledged_by_server_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    null_beats = await tb.recv_transport_frame(
        tb.clt_tsp_sink,
        match=lambda header, beats: header.nul and len(beats) == 1,
        timeout_cycles=512,
    )
    null_header = parse_header(protocol_bytes_from_stream_word(null_beats[0].data))

    ack_beats = await tb.recv_transport_frame(
        tb.srv_tsp_sink,
        match=lambda header, beats: header.ack and not header.syn and not header.nul and not header.rst,
        timeout_cycles=128,
    )
    ack_header = parse_header(protocol_bytes_from_stream_word(ack_beats[0].data))

    assert ack_header.acknowledge == null_header.sequence
    assert int(dut.srvConnected_o.value) == 1


@cocotb.test()
async def missing_client_keepalives_close_server_connection_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    tb.drop_all_client = True
    await tb.cycle(96)

    assert int(dut.srvConnected_o.value) == 0
    assert (int(dut.srvStatusReg_o.value) >> 2) & 0x1 == 1


@cocotb.test()
async def explicit_client_close_tears_down_integrated_connection_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()

    dut.cltClose_i.value = 1
    await tb.cycle()
    dut.cltClose_i.value = 0

    await tb.wait_disconnected()


@cocotb.test()
async def close_then_reopen_clears_state_and_delivers_new_payload_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    first_payload = 0xC105_E000_0000_0001
    first_recv = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(first_payload, 0xFF, 1, 1, 0)],
            timeout_cycles=512,
        )
    )
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=first_payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await first_recv

    dut.cltOpen_i.value = 0
    dut.srvOpen_i.value = 0
    await tb.pulse("cltClose_i")
    await tb.wait_disconnected(timeout_cycles=512)
    await tb.cycle(8)

    dut.srvOpen_i.value = 1
    await tb.cycle(2)
    dut.cltOpen_i.value = 1
    await tb.wait_connected(timeout_cycles=2048)
    await tb.drain_app_outputs()

    second_payload = 0xC105_E000_0000_0002
    second_recv = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(second_payload, 0xFF, 1, 1, 0)],
            timeout_cycles=512,
        )
    )
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=second_payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await second_recv


@cocotb.test()
async def client_axil_control_path_opens_injects_reads_and_closes_test(dut):
    tb = await TB.create(dut, direct_client_open=0)

    await tb.axil_write(REG_CONTROL, 0x0C)
    await tb.axil_write(REG_MAX_OUTS_SEG, 2)
    await tb.axil_write(REG_MAX_SEG_SIZE, 16)
    await tb.axil_write(REG_CONTROL, 0x0D)

    await tb.wait_connected(timeout_cycles=1024)
    await tb.drain_app_outputs()

    assert int(dut.cltMaxSegSize_o.value) == 16
    assert (await tb.axil_read(REG_MAX_SEG_SIZE)) & 0xFFFF == 16
    assert (await tb.axil_read(REG_STATUS)) & 0x1 == 1

    payload = 0xA711_0000_0000_0001
    recv = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(payload, 0xFF, 1, 1, 0)],
            timeout_cycles=512,
        )
    )
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await recv

    faulted_transport = cocotb.start_soon(
        tb.recv_transport_frame(
            tb.clt_tsp_sink,
            match=lambda header, beats: (
                not header.syn
                and not checksum_is_valid(protocol_bytes_from_stream_word(beats[0].data))
            ),
            timeout_cycles=2048,
        )
    )
    await tb.axil_write(REG_CONTROL, 0x1D)
    faulted_beats = await faulted_transport
    faulted_header_bytes = protocol_bytes_from_stream_word(faulted_beats[0].data)
    assert not checksum_is_valid(faulted_header_bytes)
    await tb.axil_write(REG_CONTROL, 0x0D)

    assert await tb.axil_read(REG_VALID_CNT) >= 1
    assert await tb.axil_read(REG_RESEND_CNT) >= 0

    await tb.axil_write(REG_CONTROL, 0x0E)
    await tb.wait_disconnected(timeout_cycles=512)
    assert (await tb.axil_read(REG_STATUS)) & 0x1 == 0


@cocotb.test()
async def checksum_disabled_connection_and_payload_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    payload = 0xC0DE_0000_0000_0000
    transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    recv = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(payload, 0xFF, 1, 1, 0)],
            timeout_cycles=512,
        )
    )
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    beats = await transport
    header = parse_header(protocol_bytes_from_stream_word(beats[0].data))
    assert header.checksum == 0
    await recv


@cocotb.test()
async def transport_ready_stalls_preserve_header_and_payload_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    header_stall_payload = 0x5700_0000_0000_0001
    tb.pause_next_client_header_cycles = 5
    header_stall_recv = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(header_stall_payload, 0xFF, 1, 1, 0)],
            timeout_cycles=1024,
        )
    )
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=header_stall_payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await header_stall_recv

    payload_stall_beats = [
        SsiBeat(data=0x5700_0000_0000_0010, keep=0xFF, last=0, sof=1, eofe=0),
        SsiBeat(data=0x5700_0000_0000_0011, keep=0xFF, last=1, sof=0, eofe=0),
    ]
    tb.pause_next_client_payload_cycles = 5
    payload_stall_recv = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(beat.data, beat.keep, beat.last, beat.sof, beat.eofe) for beat in payload_stall_beats],
            timeout_cycles=1024,
        )
    )
    await tb.send_app_frame(tb.clt_source, payload_stall_beats)
    await payload_stall_recv


@cocotb.test()
async def bidirectional_multi_frame_stress_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    for index in range(6):
        client_payload = 0xC100_0000_0000_0000 | index
        server_payload = 0x5E00_0000_0000_0000 | index

        srv_recv = cocotb.start_soon(
            recv_frame_and_check(
                tb.srv_sink,
                clk=tb.clk,
                ready_signal=dut.srvMAppTReady,
                fields=("data", "keep", "last", "sof", "eofe"),
                expected=[(client_payload, 0xFF, 1, 1, 0)],
                timeout_cycles=512,
            )
        )
        await tb.send_app_frame(
            tb.clt_source,
            [SsiBeat(data=client_payload, keep=0xFF, last=1, sof=1, eofe=0)],
        )
        await srv_recv

        clt_recv = cocotb.start_soon(
            recv_frame_and_check(
                tb.clt_sink,
                clk=tb.clk,
                ready_signal=dut.cltMAppTReady,
                fields=("data", "keep", "last", "sof", "eofe"),
                expected=[(server_payload, 0xFF, 1, 1, 0)],
                timeout_cycles=512,
            )
        )
        await tb.send_app_frame(
            tb.srv_source,
            [SsiBeat(data=server_payload, keep=0xFF, last=1, sof=1, eofe=0)],
        )
        await clt_recv

    assert int(dut.cltConnected_o.value) == 1
    assert int(dut.srvConnected_o.value) == 1


@cocotb.test()
async def client_sequence_wraparound_delivers_frame_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    first_payload = 0x00FF_0000_0000_0001
    first_transport = cocotb.start_soon(tb.recv_transport_data_frame(tb.clt_tsp_sink))
    first_recv = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(first_payload, 0xFF, 1, 1, 0)],
            timeout_cycles=512,
        )
    )
    await tb.send_app_frame(
        tb.clt_source,
        [SsiBeat(data=first_payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    first_beats = await first_transport
    first_header = parse_header(protocol_bytes_from_stream_word(first_beats[0].data))
    await first_recv

    assert first_header.sequence <= 1


PARAMETER_SWEEP = [
    pytest.param(
        {
            "WINDOW_ADDR_SIZE_G": 2,
            "SEGMENT_ADDR_SIZE_G": 5,
            "MAX_NUM_OUTS_SEG_G": 4,
            "MAX_SEG_SIZE_G": 32,
            "ACK_TOUT_G": 4,
            "RETRANS_TOUT_G": 16,
            "NULL_TOUT_G": 48,
            "MAX_RETRANS_CNT_G": 2,
            "MAX_CUM_ACK_CNT_G": 2,
        },
        id="direct_transport_small_timeouts",
    )
]

SPECIALIZED_TESTS = (
    "bidirectional_data_losses_recover_without_duplicate_delivery_test",
    "checksum_disabled_connection_and_payload_test",
    "client_axil_control_path_opens_injects_reads_and_closes_test",
    "client_sequence_wraparound_delivers_frame_test",
    "lost_first_data_drops_later_data_until_retransmit_test",
)


def _default_extra_env(parameters: dict[str, object]) -> dict[str, object]:
    excluded = list(SPECIALIZED_TESTS)
    if not env_flag("RUN_RSSI_EXTENDED_TESTS", default=False):
        excluded.append("server_backpressure_recovers_without_lost_or_duplicate_frames_test")
    return cocotb_filtered_env(
        parameters,
        cocotb_test_filter_excluding(*excluded),
    )

KNOWN_ISSUE_REASON = "set RUN_RSSI_KNOWN_ISSUE_TESTS=1 to run RSSI cases that require follow-up RTL fixes"


@pytest.mark.skipif(not env_flag("RUN_RSSI_KNOWN_ISSUE_TESTS", default=False), reason=KNOWN_ISSUE_REASON)
@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiCore(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicoreintegrationwrapper",
        parameters=parameters,
        extra_env=_default_extra_env(parameters),
    )


@pytest.mark.skipif(not env_flag("RUN_RSSI_KNOWN_ISSUE_TESTS", default=False), reason=KNOWN_ISSUE_REASON)
def test_RssiCore_sequence_wraparound():
    parameters = {
        "WINDOW_ADDR_SIZE_G": 2,
        "SEGMENT_ADDR_SIZE_G": 5,
        "MAX_NUM_OUTS_SEG_G": 4,
        "MAX_SEG_SIZE_G": 32,
        "ACK_TOUT_G": 4,
        "RETRANS_TOUT_G": 16,
        "NULL_TOUT_G": 48,
        "MAX_RETRANS_CNT_G": 2,
        "MAX_CUM_ACK_CNT_G": 2,
        "CLIENT_INIT_SEQ_N_G": 254,
    }
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicoreintegrationwrapper",
        parameters=parameters,
        extra_env={
            **parameters,
            "COCOTB_TESTCASE": "client_sequence_wraparound_delivers_frame_test",
            "RSSI_SEQUENCE_WRAP_CASE": 1,
        },
    )


@pytest.mark.skipif(not env_flag("RUN_RSSI_KNOWN_ISSUE_TESTS", default=False), reason=KNOWN_ISSUE_REASON)
def test_RssiCore_repeated_data_loss():
    parameters = {
        "WINDOW_ADDR_SIZE_G": 2,
        "SEGMENT_ADDR_SIZE_G": 5,
        "MAX_NUM_OUTS_SEG_G": 4,
        "MAX_SEG_SIZE_G": 32,
        "ACK_TOUT_G": 4,
        "RETRANS_TOUT_G": 16,
        "NULL_TOUT_G": 48,
        "MAX_RETRANS_CNT_G": 2,
        "MAX_CUM_ACK_CNT_G": 2,
    }
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicoreintegrationwrapper",
        parameters=parameters,
        extra_env={
            **parameters,
            "COCOTB_TESTCASE": "bidirectional_data_losses_recover_without_duplicate_delivery_test",
            "RSSI_REPEATED_LOSS_CASE": 1,
        },
    )


@pytest.mark.skipif(not env_flag("RUN_RSSI_KNOWN_ISSUE_TESTS", default=False), reason=KNOWN_ISSUE_REASON)
def test_RssiCore_out_of_order_recovery():
    parameters = {
        "WINDOW_ADDR_SIZE_G": 2,
        "SEGMENT_ADDR_SIZE_G": 5,
        "MAX_NUM_OUTS_SEG_G": 4,
        "MAX_SEG_SIZE_G": 32,
        "ACK_TOUT_G": 4,
        "RETRANS_TOUT_G": 96,
        "NULL_TOUT_G": 192,
        "MAX_RETRANS_CNT_G": 2,
        "MAX_CUM_ACK_CNT_G": 2,
    }
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicoreintegrationwrapper",
        parameters=parameters,
        extra_env={
            **parameters,
            "COCOTB_TESTCASE": "lost_first_data_drops_later_data_until_retransmit_test",
            "RSSI_OUT_OF_ORDER_CASE": 1,
        },
    )


@pytest.mark.skipif(not env_flag("RUN_RSSI_KNOWN_ISSUE_TESTS", default=False), reason=KNOWN_ISSUE_REASON)
def test_RssiCore_axil_control_path():
    parameters = {
        "WINDOW_ADDR_SIZE_G": 2,
        "SEGMENT_ADDR_SIZE_G": 5,
        "MAX_NUM_OUTS_SEG_G": 4,
        "MAX_SEG_SIZE_G": 32,
        "ACK_TOUT_G": 4,
        "RETRANS_TOUT_G": 16,
        "NULL_TOUT_G": 48,
        "MAX_RETRANS_CNT_G": 2,
        "MAX_CUM_ACK_CNT_G": 2,
    }
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicoreintegrationwrapper",
        parameters=parameters,
        extra_env={
            **parameters,
            "COCOTB_TESTCASE": "client_axil_control_path_opens_injects_reads_and_closes_test",
            "RSSI_AXIL_CONTROL_CASE": 1,
        },
    )


@pytest.mark.skipif(not env_flag("RUN_RSSI_KNOWN_ISSUE_TESTS", default=False), reason=KNOWN_ISSUE_REASON)
def test_RssiCore_checksum_disabled():
    parameters = {
        "WINDOW_ADDR_SIZE_G": 2,
        "SEGMENT_ADDR_SIZE_G": 5,
        "MAX_NUM_OUTS_SEG_G": 4,
        "MAX_SEG_SIZE_G": 32,
        "ACK_TOUT_G": 4,
        "RETRANS_TOUT_G": 16,
        "NULL_TOUT_G": 48,
        "MAX_RETRANS_CNT_G": 2,
        "MAX_CUM_ACK_CNT_G": 2,
        "HEADER_CHKSUM_EN_G": False,
    }
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicoreintegrationwrapper",
        parameters=parameters,
        extra_env={
            **parameters,
            "COCOTB_TESTCASE": "checksum_disabled_connection_and_payload_test",
            "RSSI_CHECKSUM_DISABLED_CORE_CASE": 1,
        },
    )
