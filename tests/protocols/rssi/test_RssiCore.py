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
#   size, bidirectional application payloads are delivered exactly once with SSI
#   sideband fields preserved, client NULL keepalive traffic keeps the idle
#   server connected, and an explicit close request tears the link down.
# - Timing: Small timeout generics keep connection, ACK, and NULL behavior
#   cycle-bounded while preserving the relative RSSI timeout relationships.

import cocotb
import pytest
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import parse_header
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    SsiBeat,
    cycle as ssi_cycle,
    reset_dut,
    start_clock,
    recv_frame_and_check,
)


def _protocol_bytes_from_stream_word(word: int) -> bytes:
    # RSSI transport headers are byte-swapped onto the 64-bit stream.
    return word.to_bytes(8, "big")[::-1]


def _transport_frame_view(beats: list[SsiBeat]) -> str:
    header = parse_header(_protocol_bytes_from_stream_word(beats[0].data))
    return (
        f"flags=0x{header.flags:02x}, seq={header.sequence}, "
        f"ack={header.acknowledge}, beats={[f'0x{beat.data:016x}' for beat in beats]}"
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
            "srvOpen_i": 1,
            "srvClose_i": 0,
            "srvInject_i": 0,
            "cltMAppTReady": 0,
            "srvMAppTReady": 0,
        }.items():
            getattr(dut, signal_name).setimmediatevalue(value)

        await reset_dut(dut, clk_name="axisClk", rst_name="axisRst")
        return tb

    async def cycle(self, count: int = 1) -> None:
        await ssi_cycle(self.clk, count=count)

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

    async def drain_app_outputs(self) -> None:
        await self.drain_app_output(self.clt_sink, self.dut.cltMAppTReady)
        await self.drain_app_output(self.srv_sink, self.dut.srvMAppTReady)

    async def send_app_frame(self, endpoint: FlatSsiEndpoint, beats: list[SsiBeat]) -> None:
        # RssiTxFsm's application ingress is sensitive to the local `after
        # TPD_G` timing in GHDL.  Keep the accepted beat stable for a few
        # additional cycles so this integration test exercises RSSI payload
        # delivery rather than a cocotb/VHDL delta-cycle race at the source.
        for beat in beats:
            endpoint.drive(beat)
            for _ in range(256):
                await RisingEdge(self.clk)
                await Timer(2, unit="ns")
                if int(endpoint._sig("TReady").value) == 1:
                    break
            else:
                raise AssertionError(f"Timed out waiting for {endpoint.prefix}TReady")
            await self.cycle(8)
        endpoint.set_idle()

    async def recv_transport_data_frame(
        self,
        endpoint: FlatSsiEndpoint,
        *,
        timeout_cycles: int = 512,
    ) -> list[SsiBeat]:
        beats = []
        seen = []
        for _ in range(timeout_cycles):
            await FallingEdge(self.clk)
            await Timer(1, unit="ns")
            if int(endpoint._sig("TValid").value) == 1 and int(endpoint._sig("TReady").value) == 1:
                beat = endpoint.snapshot()
                if not beats and beat.sof != 1:
                    continue
                beats.append(beat)
                if beat.last == 1:
                    try:
                        header = parse_header(_protocol_bytes_from_stream_word(beats[0].data))
                    except ValueError:
                        seen.append(f"malformed beats={[f'0x{item.data:016x}' for item in beats]}")
                    else:
                        seen.append(_transport_frame_view(beats))
                        if not header.syn and not header.nul and len(beats) > 1:
                            return beats
                    beats = []
        raise AssertionError(f"Timed out waiting for {endpoint.prefix} DATA frame; seen={seen}")


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
    ), f"Client transport DATA payload was corrupted before server RX: {_transport_frame_view(clt_transport_beats)}"
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
    ), f"Server transport DATA payload was corrupted before client RX: {_transport_frame_view(srv_transport_beats)}"
    await clt_recv


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
                "protocols/rssi/v1/rtl/RssiConnFsm.vhd",
                "protocols/rssi/v1/rtl/RssiMonitor.vhd",
                "protocols/rssi/v1/rtl/RssiRxFsm.vhd",
                "protocols/rssi/v1/rtl/RssiTxFsm.vhd",
                "protocols/rssi/v1/rtl/RssiCore.vhd",
                "protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd",
            ],
        },
        force_compile=True,
    )
