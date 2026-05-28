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
# - Purpose: Verify that the user-facing `RssiCoreWrapper` preserves the
#   already-tested `RssiCore` behavior while adding the wrapper's application
#   mux/demux, chunker bypass, legacy packetizer/depacketizer, and derived
#   buffer sizing.  This file is intentionally a wrapper smoke/regression layer,
#   not a replay of the full RSSI protocol matrix in `test_RssiCore.py`.
# - DUT shape: `RssiCoreWrapperIntegrationWrapper` instantiates one client
#   wrapper and one server wrapper with one flattened application stream on each
#   side.  RSSI transport is connected directly between wrappers, while cocotb
#   drives only the application streams and observes wrapper status registers.
# - Stimulus: Hold both endpoints open, wait for active-open connection, drain
#   reset-release application output, and send SSI-style payload frames through
#   each wrapper's application boundary.  The backpressure case holds server
#   application output stalled long enough to exercise the wrapper/core BUSY
#   reporting path.
# - Checks: Both wrappers must report connected status.  Bidirectional payload
#   delivery must preserve valid DATA bytes, TKEEP, TLAST, and SOF.  Focused
#   partial-keep coverage pins the current RSSI v1 behavior that application
#   EOFE is cleared on receive.  The focused backpressure run verifies that
#   stalled server output is advertised through the client-visible BUSY status
#   bit.
# - Parameter strategy: Sweep bypass-chunker and packetizer modes across
#   multiple `WINDOW_ADDR_SIZE_G` and `MAX_SEG_SIZE_G` values.  This catches
#   wrapper elaboration and derived RSSI FIFO/pause-threshold issues without
#   requiring an exhaustive Cartesian product.
# - Timing: Small timeout generics keep the wrapper checks bounded.  If a
#   protocol-level failure appears here, reproduce it in `test_RssiCore.py`
#   unless the failure is clearly caused by wrapper-only packetizer, chunker, or
#   route logic.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import env_flag, run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import RSSI_CORE_WRAPPER_VHDL_SOURCES
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    SsiBeat,
    cycle as ssi_cycle,
    data_mask_from_keep,
    recv_frame,
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
            "srvOpen_i": 1,
            "srvClose_i": 0,
            "cltMAppTReady": 0,
            "srvMAppTReady": 0,
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
        await self.drain_app_output(self.clt_sink, self.dut.cltMAppTReady)
        await self.drain_app_output(self.srv_sink, self.dut.srvMAppTReady)

    async def send_app_frame(self, endpoint: FlatSsiEndpoint, beats: list[SsiBeat]) -> None:
        for beat in beats:
            endpoint.drive(beat)
            await endpoint.wait_ready(clk=self.clk)
        endpoint.set_idle()


def assert_frame_preserves_valid_bytes(actual: list[SsiBeat], expected: list[SsiBeat]) -> None:
    assert len(actual) == len(expected)
    for actual_beat, expected_beat in zip(actual, expected):
        mask = data_mask_from_keep(expected_beat.keep)
        assert actual_beat.data & mask == expected_beat.data & mask
        assert actual_beat.keep == expected_beat.keep
        assert actual_beat.last == expected_beat.last
        assert actual_beat.sof == expected_beat.sof
        assert actual_beat.eofe == 0


@cocotb.test()
async def wrapper_active_open_and_bidirectional_payload_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    assert int(dut.cltStatusReg_o.value) & 0x1
    assert int(dut.srvStatusReg_o.value) & 0x1

    client_payload = 0x1020_3040_5060_7080
    server_payload = 0x8070_6050_4030_2010

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


@cocotb.test()
async def wrapper_partial_keep_and_eofe_payload_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    beats = [
        SsiBeat(data=0x3300_0000_0000_0001, keep=0xFF, last=0, sof=1, eofe=0),
        SsiBeat(data=0x3300_0000_0000_0002, keep=0x03, last=1, sof=0, eofe=1),
    ]

    srv_recv = cocotb.start_soon(
        recv_frame(
            tb.srv_sink,
            clk=tb.clk,
            ready_signal=dut.srvMAppTReady,
            timeout_cycles=1024,
        )
    )
    await tb.send_app_frame(tb.clt_source, beats)
    assert_frame_preserves_valid_bytes(await srv_recv, beats)


@cocotb.test()
async def wrapper_server_backpressure_advertises_busy_test(dut):
    if not env_flag("RSSI_WRAPPER_BACKPRESSURE_CASE", default=False):
        return

    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    for index in range(40):
        await tb.send_app_frame(
            tb.clt_source,
            [SsiBeat(data=0xBEEF_0000_0000_0000 | index, keep=0xFF, last=1, sof=1, eofe=0)],
        )
        await tb.cycle(4)
        if int(dut.cltStatusReg_o.value) & (1 << 8):
            break

    assert int(dut.cltStatusReg_o.value) & (1 << 8)


BASE_PARAMETERS = {
    "ACK_TOUT_G": 4,
    "RETRANS_TOUT_G": 16,
    "NULL_TOUT_G": 48,
    "MAX_RETRANS_CNT_G": 2,
    "MAX_CUM_ACK_CNT_G": 2,
}


PARAMETER_SWEEP = [
    pytest.param(
        {
            **BASE_PARAMETERS,
            "BYPASS_CHUNKER_G": True,
            "WINDOW_ADDR_SIZE_G": 1,
            "MAX_SEG_SIZE_G": 64,
        },
        id="bypass_chunker_window1_seg64",
    ),
    pytest.param(
        {
            **BASE_PARAMETERS,
            "BYPASS_CHUNKER_G": True,
            "WINDOW_ADDR_SIZE_G": 3,
            "MAX_SEG_SIZE_G": 256,
        },
        id="bypass_chunker_window3_seg256",
    ),
    pytest.param(
        {
            **BASE_PARAMETERS,
            "BYPASS_CHUNKER_G": False,
            "WINDOW_ADDR_SIZE_G": 2,
            "MAX_SEG_SIZE_G": 128,
        },
        id="packetizer_window2_seg128",
    ),
    pytest.param(
        {
            **BASE_PARAMETERS,
            "BYPASS_CHUNKER_G": False,
            "WINDOW_ADDR_SIZE_G": 3,
            "MAX_SEG_SIZE_G": 64,
        },
        id="packetizer_window3_seg64",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiCoreWrapper(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicorewrapperintegrationwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                *RSSI_CORE_WRAPPER_VHDL_SOURCES,
                "protocols/rssi/v1/wrappers/RssiCoreWrapperIntegrationWrapper.vhd",
            ],
        },
        force_compile=True,
    )


def test_RssiCoreWrapper_backpressure():
    parameters = {
        **BASE_PARAMETERS,
        "BYPASS_CHUNKER_G": True,
        "WINDOW_ADDR_SIZE_G": 2,
        "MAX_SEG_SIZE_G": 128,
    }
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicorewrapperintegrationwrapper",
        parameters=parameters,
        extra_env={
            **parameters,
            "COCOTB_TESTCASE": "wrapper_server_backpressure_advertises_busy_test",
            "RSSI_WRAPPER_BACKPRESSURE_CASE": 1,
        },
        extra_vhdl_sources={
            "surf": [
                *RSSI_CORE_WRAPPER_VHDL_SOURCES,
                "protocols/rssi/v1/wrappers/RssiCoreWrapperIntegrationWrapper.vhd",
            ],
        },
        force_compile=True,
    )
