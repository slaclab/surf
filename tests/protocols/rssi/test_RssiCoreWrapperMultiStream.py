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
# - Purpose: Exercise the `RssiCoreWrapper` path that is most visible to users
#   with multiple application streams.  `test_RssiCoreWrapper.py` covers the
#   one-stream wrapper and segment-size sweeps; this file proves that the
#   packetizer2/depacketizer2 routing layer preserves RSSI reliability and
#   stream identity when `APP_STREAMS_G > 1`.
# - DUT shape: `RssiCoreWrapperMultiStreamIntegrationWrapper` instantiates a
#   client wrapper and a server wrapper, each with two flattened application
#   streams.  RSSI transport streams are exposed to cocotb and looped back in
#   Python so the tests can observe DATA frames and inject one transport loss
#   without adding behavior to the VHDL wrapper.
# - Stimulus: Hold both endpoints open, wait for the active-open handshake, and
#   then wait an additional initialization interval before sending payloads.
#   The extra wait lets `AxiStreamDepacketizer2` clear its per-`TDEST` route
#   state after RSSI link-up, avoiding a test race that is unrelated to RSSI
#   protocol behavior.
# - Checks: Default CI coverage runs one small packetizer2 parameter set and
#   one client-to-server routed payload cocotb test.  That test proves the
#   two-stream wrapper elaborates, connects, emits transport DATA, and delivers
#   independent client streams 0 and 1 to the expected server routes.  Extended
#   coverage adds partial-keep/EOFE preservation, bidirectional routing, and
#   one dropped client DATA transport frame that must retransmit with the same
#   RSSI sequence number and recover the stream-1 payload exactly once.
# - Parameter strategy: Use `APP_STREAMS_G=2`, explicit `APP_STREAM_ROUTES_G`,
#   `APP_ILEAVE_EN_G=true`, and the legacy packetizer/depacketizer path.  The
#   default pytest entry pins `COCOTB_TESTCASE` to the routed payload smoke
#   unless `RUN_RSSI_EXTENDED_TESTS=1` is set.  A focused pytest entry can still
#   run only the bidirectional route case for the small window/segment-size
#   parameter set when that nodeid is selected directly.
# - Timing: Event-driven receives wait for expected transport or application
#   frames with bounded timeouts.  Transport loopback drops only multi-beat DATA
#   frames after a test arms the hook, leaving ACK/NULL control traffic free to
#   maintain the connection.

import cocotb
import pytest
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import env_flag, run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import (
    format_transport_frame,
    parse_header,
    protocol_bytes_from_stream_word,
    recv_transport_data_frame,
)
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    SsiBeat,
    cycle as ssi_cycle,
    data_mask_from_keep,
    recv_frame,
    recv_frame_and_check,
    reset_dut,
    start_clock,
)


# RssiCoreWrapper uses TDEST_BITS_G=8 for AxiStreamDepacketizer2, which clears
# per-route state after link-up before it can safely accept routed DATA.
DEPACKETIZER2_INIT_WAIT_CYCLES = 1024


def _default_extra_env(parameters: dict[str, object]) -> dict[str, object]:
    if env_flag("RUN_RSSI_EXTENDED_TESTS", default=False):
        return parameters
    return {
        **parameters,
        "COCOTB_TESTCASE": "multi_stream_client_to_server_payload_routes_test",
    }


def _explicit_pytest_selection(request, test_name: str) -> bool:
    return any("::" in arg and test_name in arg for arg in request.config.args)


def assert_frame_preserves_valid_bytes(actual: list[SsiBeat], expected: list[SsiBeat]) -> None:
    assert len(actual) == len(expected), (
        f"frame beat count: expected {len(expected)}, got {len(actual)}"
    )
    for beat_index, (actual_beat, expected_beat) in enumerate(zip(actual, expected)):
        mask = data_mask_from_keep(expected_beat.keep)
        assert actual_beat.data & mask == expected_beat.data & mask, (
            f"beat {beat_index} payload: expected "
            f"{expected_beat.data & mask:#x}, got {actual_beat.data & mask:#x}"
        )
        assert actual_beat.keep == expected_beat.keep, (
            f"beat {beat_index} TKEEP: expected {expected_beat.keep:#x}, "
            f"got {actual_beat.keep:#x}"
        )
        assert actual_beat.last == expected_beat.last, (
            f"beat {beat_index} TLAST: expected {expected_beat.last}, got {actual_beat.last}"
        )
        assert actual_beat.sof == expected_beat.sof, (
            f"beat {beat_index} SOF: expected {expected_beat.sof}, got {actual_beat.sof}"
        )
        assert actual_beat.eofe == expected_beat.eofe, (
            f"beat {beat_index} EOFE: expected {expected_beat.eofe}, got {actual_beat.eofe}"
        )


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
        self.clt_tsp_input = FlatSsiEndpoint(dut, prefix="cltSTsp")
        self.clt_tsp_output = FlatSsiEndpoint(dut, prefix="cltMTsp")
        self.srv_tsp_input = FlatSsiEndpoint(dut, prefix="srvSTsp")
        self.srv_tsp_output = FlatSsiEndpoint(dut, prefix="srvMTsp")
        self.clt_tsp_monitor = self.clt_tsp_output
        self.srv_tsp_monitor = self.srv_tsp_output
        self.drop_next_client_data = False
        self.drop_next_server_data = False
        self.loopback_tasks = []

    @classmethod
    async def create(cls, dut):
        start_clock(dut.axisClk, period_ns=5.0)
        dut.axisRst.setimmediatevalue(1)

        tb = cls(dut)
        for endpoint in tb.clt_sources + tb.srv_sources + [tb.clt_tsp_input, tb.srv_tsp_input]:
            endpoint.set_idle()

        for signal_name, value in {
            "cltOpen_i": 1,
            "cltClose_i": 0,
            "srvOpen_i": 1,
            "srvClose_i": 0,
            "cltMApp0TReady": 0,
            "cltMApp1TReady": 0,
            "cltMTspTReady": 0,
            "srvMApp0TReady": 0,
            "srvMApp1TReady": 0,
            "srvMTspTReady": 0,
        }.items():
            getattr(dut, signal_name).setimmediatevalue(value)

        await reset_dut(dut, clk_name="axisClk", rst_name="axisRst")
        tb.start_transport_loopbacks()
        return tb

    async def cycle(self, count: int = 1) -> None:
        await ssi_cycle(self.clk, count=count)

    async def wait_connected(self, *, timeout_cycles: int = 1024) -> None:
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
                    drop_attr="drop_next_client_data",
                )
            ),
            cocotb.start_soon(
                self.loopback_transport(
                    self.srv_tsp_output,
                    self.clt_tsp_input,
                    self.dut.srvMTspTReady,
                    drop_attr="drop_next_server_data",
                )
            ),
        ]

    async def loopback_transport(
        self,
        source: FlatSsiEndpoint,
        destination: FlatSsiEndpoint,
        source_ready,
        *,
        drop_attr: str,
    ) -> None:
        """Lifetime agent: relay RSSI traffic until cocotb ends the test."""
        dropping = False
        destination.set_idle()
        source_ready.value = 0

        while True:
            await FallingEdge(self.clk)
            await Timer(1, unit="ns")

            valid = int(source._sig("TValid").value) == 1
            beat = source.snapshot() if valid else None

            if (
                valid
                and (dropping or (getattr(self, drop_attr) and beat.last == 0))
            ):
                destination.set_idle()
                source_ready.value = 1
                dropping = beat.last == 0
                setattr(self, drop_attr, False)
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
        timeout_cycles: int = 1024,
    ) -> list[SsiBeat]:
        return await recv_transport_data_frame(
            endpoint,
            clk=self.clk,
            timeout_cycles=timeout_cycles,
        )


@cocotb.test()
async def multi_stream_active_open_smoke_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()

    assert int(dut.cltStatusReg_o.value) & 0x1
    assert int(dut.srvStatusReg_o.value) & 0x1


@cocotb.test()
async def multi_stream_client_to_server_payload_routes_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()
    await tb.cycle(DEPACKETIZER2_INIT_WAIT_CYCLES)

    assert int(dut.cltStatusReg_o.value) & 0x1
    assert int(dut.srvStatusReg_o.value) & 0x1

    payload0 = 0x1111_2222_3333_4444
    payload1 = 0xAAAA_BBBB_CCCC_DDDD

    clt_tsp_data = cocotb.start_soon(
        tb.recv_transport_data_frame(tb.clt_tsp_monitor, timeout_cycles=1024)
    )
    srv_out0 = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sinks[0],
            clk=tb.clk,
            ready_signal=dut.srvMApp0TReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(payload0, 0xFF, 1, 1, 0)],
            timeout_cycles=1024,
        )
    )
    srv_out1 = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sinks[1],
            clk=tb.clk,
            ready_signal=dut.srvMApp1TReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(payload1, 0xFF, 1, 1, 0)],
            timeout_cycles=1024,
        )
    )

    await tb.send_app_frame(
        tb.clt_sources[0],
        [SsiBeat(data=payload0, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await tb.send_app_frame(
        tb.clt_sources[1],
        [SsiBeat(data=payload1, keep=0xFF, last=1, sof=1, eofe=0)],
    )

    await clt_tsp_data
    await srv_out0
    await srv_out1


@cocotb.test()
async def multi_stream_bidirectional_payload_routes_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()
    await tb.cycle(DEPACKETIZER2_INIT_WAIT_CYCLES)

    client_payload0 = 0x1111_0000_0000_0000
    client_payload1 = 0x1111_0000_0000_0001
    server_payload0 = 0x2222_0000_0000_0000
    server_payload1 = 0x2222_0000_0000_0001

    srv_out0 = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sinks[0],
            clk=tb.clk,
            ready_signal=dut.srvMApp0TReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(client_payload0, 0xFF, 1, 1, 0)],
            timeout_cycles=1024,
        )
    )
    srv_out1 = cocotb.start_soon(
        recv_frame_and_check(
            tb.srv_sinks[1],
            clk=tb.clk,
            ready_signal=dut.srvMApp1TReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(client_payload1, 0xFF, 1, 1, 0)],
            timeout_cycles=1024,
        )
    )
    await tb.send_app_frame(
        tb.clt_sources[0],
        [SsiBeat(data=client_payload0, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await tb.send_app_frame(
        tb.clt_sources[1],
        [SsiBeat(data=client_payload1, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await srv_out0
    await srv_out1

    clt_out0 = cocotb.start_soon(
        recv_frame_and_check(
            tb.clt_sinks[0],
            clk=tb.clk,
            ready_signal=dut.cltMApp0TReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(server_payload0, 0xFF, 1, 1, 0)],
            timeout_cycles=1024,
        )
    )
    clt_out1 = cocotb.start_soon(
        recv_frame_and_check(
            tb.clt_sinks[1],
            clk=tb.clk,
            ready_signal=dut.cltMApp1TReady,
            fields=("data", "keep", "last", "sof", "eofe"),
            expected=[(server_payload1, 0xFF, 1, 1, 0)],
            timeout_cycles=1024,
        )
    )
    await tb.send_app_frame(
        tb.srv_sources[0],
        [SsiBeat(data=server_payload0, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await tb.send_app_frame(
        tb.srv_sources[1],
        [SsiBeat(data=server_payload1, keep=0xFF, last=1, sof=1, eofe=0)],
    )
    await clt_out0
    await clt_out1


@cocotb.test()
async def multi_stream_partial_keep_and_eofe_routes_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()
    await tb.cycle(DEPACKETIZER2_INIT_WAIT_CYCLES)

    beats = [
        SsiBeat(data=0x4400_0000_0000_0001, keep=0xFF, last=0, sof=1, eofe=0),
        SsiBeat(data=0x4400_0000_0000_0002, keep=0x1F, last=1, sof=0, eofe=1),
    ]

    srv_recv = cocotb.start_soon(
        recv_frame(
            tb.srv_sinks[1],
            clk=tb.clk,
            ready_signal=dut.srvMApp1TReady,
            timeout_cycles=2048,
        )
    )
    await tb.send_app_frame(tb.clt_sources[1], beats)
    assert_frame_preserves_valid_bytes(await srv_recv, beats)


@cocotb.test()
async def multi_stream_dropped_client_data_retransmits_to_route_test(dut):
    tb = await TB.create(dut)

    await tb.wait_connected()
    await tb.drain_app_outputs()
    await tb.cycle(DEPACKETIZER2_INIT_WAIT_CYCLES)

    payload = 0xDEAD_BEEF_0102_0304

    first_transport = cocotb.start_soon(
        tb.recv_transport_data_frame(tb.clt_tsp_monitor, timeout_cycles=2048)
    )
    tb.drop_next_client_data = True
    await tb.send_app_frame(
        tb.clt_sources[1],
        [SsiBeat(data=payload, keep=0xFF, last=1, sof=1, eofe=0)],
    )

    first_beats = await first_transport
    first_header = parse_header(protocol_bytes_from_stream_word(first_beats[0].data))

    second_transport = cocotb.start_soon(
        tb.recv_transport_data_frame(tb.clt_tsp_monitor, timeout_cycles=2048)
    )
    second_beats = await second_transport
    second_header = parse_header(protocol_bytes_from_stream_word(second_beats[0].data))

    assert second_header.sequence == first_header.sequence, (
        "Retransmitted wrapper DATA did not reuse the dropped sequence; "
        f"first={format_transport_frame(first_beats)} "
        f"second={format_transport_frame(second_beats)}"
    )

    await recv_frame_and_check(
        tb.srv_sinks[1],
        clk=tb.clk,
        ready_signal=dut.srvMApp1TReady,
        fields=("data", "keep", "last", "sof", "eofe"),
        expected=[(payload, 0xFF, 1, 1, 0)],
        timeout_cycles=1024,
    )


PARAMETER_SWEEP = [
    pytest.param(
        {
            "BYPASS_CHUNKER_G": False,
            "APP_ILEAVE_EN_G": True,
            "WINDOW_ADDR_SIZE_G": 2,
            "MAX_SEG_SIZE_G": 64,
            "ACK_TOUT_G": 4,
            "RETRANS_TOUT_G": 16,
            "NULL_TOUT_G": 48,
            "MAX_RETRANS_CNT_G": 2,
            "MAX_CUM_ACK_CNT_G": 2,
        },
        id="packetizer2_two_streams_window2_seg64",
    ),
]


EXTENDED_PARAMETER_SWEEP = [
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

KNOWN_ISSUE_REASON = "set RUN_RSSI_KNOWN_ISSUE_TESTS=1 to run RSSI cases that require follow-up RTL fixes"


@pytest.mark.skipif(not env_flag("RUN_RSSI_KNOWN_ISSUE_TESTS", default=False), reason=KNOWN_ISSUE_REASON)
@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiCoreWrapperMultiStream(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicorewrappermultistreamintegrationwrapper",
        parameters=parameters,
        extra_env=_default_extra_env(parameters),
    )


@pytest.mark.skipif(not env_flag("RUN_RSSI_KNOWN_ISSUE_TESTS", default=False), reason=KNOWN_ISSUE_REASON)
@pytest.mark.skipif(
    not env_flag("RUN_RSSI_EXTENDED_TESTS", default=False),
    reason="set RUN_RSSI_EXTENDED_TESTS=1 to run extended RSSI multi-stream wrapper coverage",
)
@pytest.mark.parametrize("parameters", EXTENDED_PARAMETER_SWEEP)
def test_RssiCoreWrapperMultiStream_extended(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicorewrappermultistreamintegrationwrapper",
        parameters=parameters,
        extra_env={
            **parameters,
            "RUN_RSSI_EXTENDED_TESTS": 1,
        },
    )


@pytest.mark.skipif(not env_flag("RUN_RSSI_KNOWN_ISSUE_TESTS", default=False), reason=KNOWN_ISSUE_REASON)
def test_RssiCoreWrapperMultiStream_bidirectional_packetizer2(request):
    if (
        not env_flag("RUN_RSSI_EXTENDED_TESTS", default=False)
        and not _explicit_pytest_selection(
            request,
            "test_RssiCoreWrapperMultiStream_bidirectional_packetizer2",
        )
    ):
        pytest.skip(
            "set RUN_RSSI_EXTENDED_TESTS=1 or run this nodeid explicitly for "
            "focused bidirectional packetizer2 route coverage"
        )

    parameters = {
        "BYPASS_CHUNKER_G": False,
        "APP_ILEAVE_EN_G": True,
        "WINDOW_ADDR_SIZE_G": 2,
        "MAX_SEG_SIZE_G": 64,
        "ACK_TOUT_G": 4,
        "RETRANS_TOUT_G": 16,
        "NULL_TOUT_G": 48,
        "MAX_RETRANS_CNT_G": 2,
        "MAX_CUM_ACK_CNT_G": 2,
    }
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssicorewrappermultistreamintegrationwrapper",
        parameters=parameters,
        extra_env={
            **parameters,
            "COCOTB_TESTCASE": "multi_stream_bidirectional_payload_routes_test",
        },
    )
