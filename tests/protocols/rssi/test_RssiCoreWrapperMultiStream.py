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
# - Sweep: Run one client `RssiCoreWrapper` and one server `RssiCoreWrapper`
#   through a two-application-stream integration wrapper with routed stream
#   destinations.
# - Stimulus: Hold both endpoints open and wait for the active-open handshake.
# - Checks: Both wrappers report connected status with the two-stream wrapper
#   path elaborated and active. An opt-in known-issue payload characterization
#   sends independent routed frames on both client streams, confirms the client
#   emits transport DATA, and records that the server application streams do
#   not yet receive those frames.
# - Parameters: Exercise the user-facing multi-stream wrapper path with
#   `APP_STREAMS_G=2`, `APP_STREAM_ROUTES_G`, `APP_ILEAVE_EN_G=true`, and the
#   legacy packetizer/depacketizer path. Single-stream and segment-size sweeps
#   remain in `test_RssiCoreWrapper.py`.

import os

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    SsiBeat,
    capture_accepted_beats,
    cycle as ssi_cycle,
    reset_dut,
    start_clock,
)


def _beat_summary(beats: list[SsiBeat], *, limit: int = 16) -> list[tuple[int, int, int, int, int]]:
    return [
        (beat.data, beat.keep, beat.last, beat.sof, beat.eofe)
        for beat in beats[:limit]
    ]


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.axisClk
        self.clt_sources = [
            FlatSsiEndpoint(dut, prefix="cltSApp0"),
            FlatSsiEndpoint(dut, prefix="cltSApp1"),
        ]
        self.clt_sinks = [
            FlatSsiEndpoint(dut, prefix="cltMApp0"),
            FlatSsiEndpoint(dut, prefix="cltMApp1"),
        ]
        self.srv_sources = [
            FlatSsiEndpoint(dut, prefix="srvSApp0"),
            FlatSsiEndpoint(dut, prefix="srvSApp1"),
        ]
        self.srv_sinks = [
            FlatSsiEndpoint(dut, prefix="srvMApp0"),
            FlatSsiEndpoint(dut, prefix="srvMApp1"),
        ]
        self.clt_tsp_monitor = FlatSsiEndpoint(dut, prefix="cltMTsp")
        self.srv_tsp_monitor = FlatSsiEndpoint(dut, prefix="srvMTsp")

    @classmethod
    async def create(cls, dut):
        start_clock(dut.axisClk, period_ns=5.0)
        dut.axisRst.setimmediatevalue(1)

        tb = cls(dut)
        for endpoint in tb.clt_sources + tb.srv_sources:
            endpoint.set_idle()

        for signal_name, value in {
            "cltOpen_i": 1,
            "cltClose_i": 0,
            "srvOpen_i": 1,
            "srvClose_i": 0,
            "cltMApp0TReady": 0,
            "cltMApp1TReady": 0,
            "srvMApp0TReady": 0,
            "srvMApp1TReady": 0,
        }.items():
            getattr(dut, signal_name).setimmediatevalue(value)

        await reset_dut(dut, clk_name="axisClk", rst_name="axisRst")
        return tb

    async def cycle(self, count: int = 1) -> None:
        await ssi_cycle(self.clk, count=count)

    async def wait_connected(self, *, timeout_cycles: int = 512) -> None:
        for _ in range(timeout_cycles):
            await Timer(1, unit="ns")
            if int(self.dut.cltConnected_o.value) and int(self.dut.srvConnected_o.value):
                return
            await RisingEdge(self.clk)
        raise AssertionError("Timed out waiting for both RSSI core wrappers to connect")

    async def drain_app_output(self, endpoint: FlatSsiEndpoint, ready_signal, *, quiet_cycles: int = 8) -> None:
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
        for index, endpoint in enumerate(self.clt_sinks):
            await self.drain_app_output(endpoint, getattr(self.dut, f"cltMApp{index}TReady"))
        for index, endpoint in enumerate(self.srv_sinks):
            await self.drain_app_output(endpoint, getattr(self.dut, f"srvMApp{index}TReady"))

    async def send_app_frame(self, endpoint: FlatSsiEndpoint, beats: list[SsiBeat]) -> None:
        for beat in beats:
            await endpoint.send(beat, clk=self.clk)
        endpoint.set_idle()


@cocotb.test()
async def multi_stream_active_open_smoke_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    assert int(dut.cltStatusReg_o.value) & 0x1
    assert int(dut.srvStatusReg_o.value) & 0x1


@cocotb.test(skip=os.getenv("RUN_RSSI_KNOWN_ISSUE_TESTS") != "1")
async def multi_stream_client_to_server_payload_routes_known_issue_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()
    await tb.cycle(512)

    payload0 = 0x1111_2222_3333_4444
    payload1 = 0xAAAA_BBBB_CCCC_DDDD

    dut.srvMApp0TReady.value = 1
    dut.srvMApp1TReady.value = 1

    clt_tsp_capture = cocotb.start_soon(
        capture_accepted_beats(tb.clt_tsp_monitor, clk=tb.clk, cycles=1024)
    )
    srv_out0_capture = cocotb.start_soon(
        capture_accepted_beats(tb.srv_sinks[0], clk=tb.clk, cycles=1024)
    )
    srv_out1_capture = cocotb.start_soon(
        capture_accepted_beats(tb.srv_sinks[1], clk=tb.clk, cycles=1024)
    )

    await tb.send_app_frame(
        tb.clt_sources[0],
        [SsiBeat(data=payload0, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await tb.send_app_frame(
        tb.clt_sources[1],
        [SsiBeat(data=payload1, keep=0xFF, last=1, sof=1, eofe=0)],
    )

    clt_tsp_beats = await clt_tsp_capture
    srv_out0_beats = await srv_out0_capture
    srv_out1_beats = await srv_out1_capture

    assert clt_tsp_beats, "Client wrapper accepted application frames but emitted no transport beats"
    assert _beat_summary(srv_out0_beats) == [(payload0, 0xFF, 1, 1, 0)], (
        "Server stream 0 did not receive the expected routed payload; "
        f"clt_tsp={_beat_summary(clt_tsp_beats)} "
        f"srv0={_beat_summary(srv_out0_beats)} "
        f"srv1={_beat_summary(srv_out1_beats)}"
    )
    assert _beat_summary(srv_out1_beats) == [(payload1, 0xFF, 1, 1, 0)], (
        "Server stream 1 did not receive the expected routed payload; "
        f"clt_tsp={_beat_summary(clt_tsp_beats)} "
        f"srv0={_beat_summary(srv_out0_beats)} "
        f"srv1={_beat_summary(srv_out1_beats)}"
    )


PARAMETER_SWEEP = [
    pytest.param(
        {
            "BYPASS_CHUNKER_G": False,
            "APP_ILEAVE_EN_G": True,
            "WINDOW_ADDR_SIZE_G": 3,
            "MAX_SEG_SIZE_G": 128,
            "ACK_TOUT_G": 4,
            "RETRANS_TOUT_G": 16,
            "NULL_TOUT_G": 48,
            "MAX_RETRANS_CNT_G": 2,
            "MAX_CUM_ACK_CNT_G": 2,
        },
        id="packetizer2_two_streams_window3_seg128",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiCoreWrapperMultiStream(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicorewrappermultistreamintegrationwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "protocols/rssi/v1/rtl/RssiConnFsm.vhd",
                "protocols/rssi/v1/rtl/RssiMonitor.vhd",
                "protocols/rssi/v1/rtl/RssiRxFsm.vhd",
                "protocols/rssi/v1/rtl/RssiTxFsm.vhd",
                "protocols/rssi/v1/rtl/RssiCore.vhd",
                "protocols/rssi/v1/rtl/RssiCoreWrapper.vhd",
                "protocols/rssi/v1/wrappers/RssiCoreWrapperMultiStreamIntegrationWrapper.vhd",
            ],
        },
        force_compile=True,
    )
