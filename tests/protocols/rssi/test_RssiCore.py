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
# - Sweep: Run one client `RssiCore` and one server `RssiCore` through a thin
#   integration wrapper with their transport AXI streams connected directly.
# - Stimulus: Hold both endpoints open, wait for the active-open handshake, and
#   drive flattened SSI-style application frames into each core.
# - Checks: Both cores report connection-active status and negotiated segment
#   size, bidirectional application payloads are delivered with SSI sideband
#   fields preserved, dropped and corrupted client DATA frames are recovered by
#   retransmission, client NULL keepalive traffic keeps the idle server
#   connected, missing client keepalives close the server, and an explicit close
#   request tears the link down.
# - Timing: Small timeout generics keep connection, ACK, and NULL behavior
#   cycle-bounded while preserving the relative RSSI timeout relationships.

import cocotb
import pytest
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import (
    RSSI_CORE_VHDL_SOURCES,
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


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.axisClk
        self.clt_source = FlatSsiEndpoint(dut, prefix="cltSApp")
        self.clt_sink = FlatSsiEndpoint(dut, prefix="cltMApp")
        self.srv_source = FlatSsiEndpoint(dut, prefix="srvSApp")
        self.srv_sink = FlatSsiEndpoint(dut, prefix="srvMApp")
        self.clt_tsp_sink = FlatSsiEndpoint(dut, prefix="cltMTsp")
        self.srv_tsp_sink = FlatSsiEndpoint(dut, prefix="srvMTsp")

    @classmethod
    async def create(cls, dut):
        start_clock(dut.axisClk, period_ns=5.0)
        dut.axisRst.setimmediatevalue(1)

        tb = cls(dut)
        tb.clt_source.set_idle()
        tb.srv_source.set_idle()

        for signal_name, value in {
            "cltOpen_i": 1,
            "cltClose_i": 0,
            "cltInject_i": 0,
            "cltDropTsp_i": 0,
            "srvOpen_i": 1,
            "srvClose_i": 0,
            "srvInject_i": 0,
            "srvDropTsp_i": 0,
            "cltMAppTReady": 0,
            "srvMAppTReady": 0,
        }.items():
            getattr(dut, signal_name).setimmediatevalue(value)

        await reset_dut(dut, clk_name="axisClk", rst_name="axisRst")
        return tb

    async def cycle(self, count: int = 1) -> None:
        await ssi_cycle(self.clk, count=count)

    async def pulse(self, signal_name: str) -> None:
        getattr(self.dut, signal_name).value = 1
        await self.cycle()
        getattr(self.dut, signal_name).value = 0

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
async def dropped_client_data_retransmits_and_recovers_payload_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    payload = 0xCAFE_BABE_1234_5678

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
    dut.cltDropTsp_i.value = 1
    await tb.cycle()
    dut.cltDropTsp_i.value = 0

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

    frames = await tb.collect_app_frames(tb.srv_sink, dut.srvMAppTReady, cycles=128)
    assert len(frames) == 1, f"Unexpected server output frames after retransmission: {frames}"
    assert_beat_views(
        frames[0],
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(payload, 0xFF, 1, 1, 0)],
    )


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

    dut.cltDropTsp_i.value = 1
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
async def missing_client_keepalives_close_server_connection_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    dut.cltDropTsp_i.value = 1
    await tb.cycle(96)
    dut.cltDropTsp_i.value = 0

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


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiCore(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicoreintegrationwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                *RSSI_CORE_VHDL_SOURCES,
                "protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd",
            ],
        },
        force_compile=True,
    )
