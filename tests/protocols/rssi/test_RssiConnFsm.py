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
# - Purpose: Verify RSSI connection-state behavior at the `RssiConnFsm` leaf
#   boundary before it is composed with TX, RX, monitor, and AXI-Lite logic in
#   `RssiCore`.  These tests focus on active/passive open, SYN negotiation,
#   retry/timeout behavior, and parameter rejection decisions.
# - DUT shape: Run the FSM through a thin wrapper in both server and client
#   modes.  The wrapper flattens `RssiParamType` and header flag records so the
#   test can drive exact peer proposals and observe accepted/current parameter
#   outputs without depending on the header decoder or register map.
# - Stimulus: Drive connection requests, received SYN/SYN+ACK/ACK/RST flags,
#   peer parameter records, and header-sent strobes directly.  Tests model the
#   minimum surrounding handshake needed to advance the FSM and intentionally
#   avoid sending SSI traffic or encoded header bytes.
# - Checks: Matching parameters open the connection.  Legal peer window and
#   segment-size proposals are accepted or clamped as the SURF hardware profile
#   defines.  Non-negotiable mismatches and out-of-range peer parameters reject
#   the proposal and, on the client side, request RST.  Retry cases verify that
#   missing peer responses cause bounded SYN retransmission attempts followed
#   by close rather than counter overflow.
# - Timing: Status checks wait past the default `TPD_G` output delay after each
#   clock edge.  Timeout generics are kept small so retries and peer-timeout
#   closure remain deterministic within a directed cocotb test.  The pytest
#   wrapper selects only server-named scenarios for `SERVER_G=true` and only
#   client-named scenarios for `SERVER_G=false`.

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import cocotb_filtered_env, run_surf_vhdl_test
from tests.protocols.rssi.rssi_test_utils import RssiParams
from tests.protocols.ssi.ssi_test_utils import (
    cycle as ssi_cycle,
    setup_flat_ssi_testbench,
)


PARAM_FIELDS = (
    ("Version", "version"),
    ("ChksumEn", "chksum_en"),
    ("TimeoutUnit", "timeout_unit"),
    ("MaxOutsSeg", "max_outs_seg"),
    ("MaxSegSize", "max_seg_size"),
    ("RetransTout", "retrans_tout"),
    ("CumulAckTout", "cumul_ack_tout"),
    ("NullSegTout", "null_seg_tout"),
    ("MaxRetrans", "max_retrans"),
    ("MaxCumAck", "max_cum_ack"),
    ("MaxOutofseq", "max_outofseq"),
    ("ConnectionId", "connection_id"),
)


class TB:
    def __init__(self, dut, bench):
        self.dut = dut
        self.clk = bench.clk

    @classmethod
    async def create(cls, dut):
        initial_values = {
            "connRq_i": 0,
            "closeRq_i": 0,
            "rxValid_i": 0,
            "synHeadSt_i": 0,
            "ackHeadSt_i": 0,
            "rstHeadSt_i": 0,
            "rxFlagsSyn_i": 0,
            "rxFlagsAck_i": 0,
            "rxFlagsEack_i": 0,
            "rxFlagsRst_i": 0,
            "rxFlagsNul_i": 0,
            "rxFlagsData_i": 0,
            "rxFlagsBusy_i": 0,
            "rxFlagsEofe_i": 0,
        }
        for prefix in ("appParam", "rxParam"):
            for suffix, _ in PARAM_FIELDS:
                initial_values[f"{prefix}{suffix}_i"] = 0

        bench = await setup_flat_ssi_testbench(
            dut,
            initial_values=initial_values,
        )
        tb = cls(dut, bench)
        tb.set_app_params(RssiParams(max_outs_seg=4, max_seg_size=64))
        tb.set_rx_params(RssiParams(max_outs_seg=2, max_seg_size=32))
        await tb.cycle()
        return tb

    async def cycle(self, count: int = 1) -> None:
        await ssi_cycle(self.clk, count=count)

    def set_params(self, prefix: str, params: RssiParams) -> None:
        for suffix, attr in PARAM_FIELDS:
            getattr(self.dut, f"{prefix}{suffix}_i").value = getattr(params, attr)

    def set_app_params(self, params: RssiParams) -> None:
        self.set_params("appParam", params)

    def set_rx_params(self, params: RssiParams) -> None:
        self.set_params("rxParam", params)

    def clear_rx_flags(self) -> None:
        for signal_name in (
            "rxFlagsSyn_i",
            "rxFlagsAck_i",
            "rxFlagsEack_i",
            "rxFlagsRst_i",
            "rxFlagsNul_i",
            "rxFlagsData_i",
            "rxFlagsBusy_i",
            "rxFlagsEofe_i",
        ):
            getattr(self.dut, signal_name).value = 0

    async def pulse(self, signal_name: str) -> None:
        getattr(self.dut, signal_name).value = 1
        await self.cycle()
        getattr(self.dut, signal_name).value = 0
        await self.cycle()

    async def receive_segment(self, *, syn: int = 0, ack: int = 0, rst: int = 0) -> None:
        self.clear_rx_flags()
        self.dut.rxFlagsSyn_i.value = syn
        self.dut.rxFlagsAck_i.value = ack
        self.dut.rxFlagsRst_i.value = rst
        self.dut.rxValid_i.value = 1
        await self.cycle()
        self.dut.rxValid_i.value = 0
        self.clear_rx_flags()
        await self.cycle()

    async def wait_high(self, signal_name: str, *, cycles: int = 16) -> None:
        signal = getattr(self.dut, signal_name)
        await Timer(1, unit="ns")
        if int(signal.value) == 1:
            return
        for _ in range(cycles):
            await self.cycle()
            if int(signal.value) == 1:
                return
        raise AssertionError(f"Timed out waiting for {signal_name}")

    async def wait_state(self, expected: int, *, cycles: int = 16) -> None:
        await Timer(1, unit="ns")
        if int(self.dut.connState_o.value) == expected:
            return
        for _ in range(cycles):
            await self.cycle()
            if int(self.dut.connState_o.value) == expected:
                return
        raise AssertionError(f"Timed out waiting for connState_o={expected:#x}")


@cocotb.test()
async def server_accepts_syn_ack_and_opens_test(dut):
    tb = await TB.create(dut)
    tb.dut.connRq_i.value = 1
    await tb.cycle()

    await tb.receive_segment(syn=1)
    await tb.wait_high("sndSyn_o")

    assert int(dut.txAckF_o.value) == 1
    assert int(dut.paramReject_o.value) == 0
    assert int(dut.paramMaxOutsSeg_o.value) == 2
    assert int(dut.paramMaxSegSize_o.value) == 32
    assert int(dut.txWindowSize_o.value) == 2
    assert int(dut.txBufferSize_o.value) == 4

    await tb.pulse("synHeadSt_i")
    await tb.receive_segment(ack=1)
    await tb.wait_high("connActive_o")

    assert int(dut.connState_o.value) == 0x7


@cocotb.test()
async def server_proposes_local_required_parameters_on_mismatch_test(dut):
    tb = await TB.create(dut)
    app_params = RssiParams(
        version=1,
        chksum_en=1,
        timeout_unit=1,
        max_outs_seg=4,
        max_seg_size=64,
    )
    peer_params = RssiParams(
        version=2,
        chksum_en=0,
        timeout_unit=3,
        max_outs_seg=8,
        max_seg_size=128,
    )
    tb.set_app_params(app_params)
    tb.set_rx_params(peer_params)

    tb.dut.connRq_i.value = 1
    await tb.cycle()
    await tb.receive_segment(syn=1)

    assert int(dut.paramReject_o.value) == 1
    assert int(dut.paramVersion_o.value) == app_params.version
    assert int(dut.paramChksumEn_o.value) == app_params.chksum_en
    assert int(dut.paramTimeoutUnit_o.value) == app_params.timeout_unit
    assert int(dut.paramMaxOutsSeg_o.value) == app_params.max_outs_seg
    assert int(dut.paramMaxSegSize_o.value) == app_params.max_seg_size

    await tb.wait_high("sndSyn_o")
    assert int(dut.txAckF_o.value) == 1


@cocotb.test()
async def server_rejects_out_of_range_syn_parameters_test(dut):
    tb = await TB.create(dut)
    app_params = RssiParams(
        version=1,
        chksum_en=1,
        timeout_unit=1,
        max_outs_seg=4,
        max_seg_size=64,
        retrans_tout=12,
        cumul_ack_tout=4,
        null_seg_tout=24,
    )
    tb.set_app_params(app_params)
    tb.set_rx_params(
        RssiParams(
            version=1,
            chksum_en=1,
            timeout_unit=1,
            max_outs_seg=0,
            max_seg_size=4,
            retrans_tout=0,
            cumul_ack_tout=0,
            null_seg_tout=0,
        )
    )

    tb.dut.connRq_i.value = 1
    await tb.cycle()
    await tb.receive_segment(syn=1)

    assert int(dut.paramReject_o.value) == 1
    assert int(dut.paramMaxOutsSeg_o.value) == app_params.max_outs_seg
    assert int(dut.paramMaxSegSize_o.value) == app_params.max_seg_size
    assert int(dut.paramRetransTout_o.value) == app_params.retrans_tout
    assert int(dut.paramCumulAckTout_o.value) == app_params.cumul_ack_tout
    assert int(dut.paramNullSegTout_o.value) == app_params.null_seg_tout
    assert int(dut.txWindowSize_o.value) == app_params.max_outs_seg
    assert int(dut.txBufferSize_o.value) == app_params.max_seg_size // 8
    await tb.wait_high("sndSyn_o")


@cocotb.test()
async def server_retries_syn_ack_then_times_out_waiting_for_ack_test(dut):
    tb = await TB.create(dut)
    tb.dut.connRq_i.value = 1
    await tb.cycle()

    await tb.receive_segment(syn=1)
    await tb.wait_high("sndSyn_o")
    await tb.pulse("synHeadSt_i")
    await tb.wait_state(0x6)

    await tb.wait_high("closed_o", cycles=10)
    assert int(dut.peerTout_o.value) == 0
    await tb.wait_high("sndSyn_o", cycles=4)

    await tb.pulse("synHeadSt_i")
    tb.dut.connRq_i.value = 0
    await tb.wait_state(0x6)
    await tb.wait_high("peerTout_o", cycles=10)
    await tb.cycle()

    assert int(dut.connActive_o.value) == 0
    assert int(dut.closed_o.value) == 1


@cocotb.test()
async def client_accepts_syn_ack_clamps_and_opens_test(dut):
    tb = await TB.create(dut)
    app_params = RssiParams(max_outs_seg=4, max_seg_size=64)
    peer_params = RssiParams(max_outs_seg=8, max_seg_size=128)
    tb.set_app_params(app_params)
    tb.set_rx_params(peer_params)

    tb.dut.connRq_i.value = 1
    await tb.wait_high("sndSyn_o")
    await tb.pulse("synHeadSt_i")

    await tb.receive_segment(syn=1, ack=1)
    await tb.wait_high("sndAck_o")

    assert int(dut.paramReject_o.value) == 0
    assert int(dut.paramMaxOutsSeg_o.value) == app_params.max_outs_seg
    assert int(dut.paramMaxSegSize_o.value) == app_params.max_seg_size
    assert int(dut.txWindowSize_o.value) == app_params.max_outs_seg
    assert int(dut.txBufferSize_o.value) == app_params.max_seg_size // 8

    await tb.pulse("ackHeadSt_i")
    await tb.wait_high("connActive_o")

    assert int(dut.connState_o.value) == 0x7


@cocotb.test()
async def client_rejects_mismatched_syn_ack_with_rst_test(dut):
    tb = await TB.create(dut)
    tb.set_app_params(RssiParams(version=1, chksum_en=1, timeout_unit=1))
    tb.set_rx_params(RssiParams(version=2, chksum_en=1, timeout_unit=1))

    tb.dut.connRq_i.value = 1
    await tb.wait_high("sndSyn_o")
    await tb.pulse("synHeadSt_i")

    reject_wait = cocotb.start_soon(tb.wait_high("paramReject_o"))
    await tb.receive_segment(syn=1, ack=1)
    await reject_wait
    await tb.wait_high("sndRst_o")

    await tb.pulse("rstHeadSt_i")
    await tb.wait_high("closed_o")

    assert int(dut.connActive_o.value) == 0


@cocotb.test()
async def client_rejects_out_of_range_syn_ack_with_rst_test(dut):
    tb = await TB.create(dut)
    tb.set_app_params(RssiParams(version=1, chksum_en=1, timeout_unit=1))
    tb.set_rx_params(
        RssiParams(
            version=1,
            chksum_en=1,
            timeout_unit=1,
            max_outs_seg=0,
            max_seg_size=4,
            retrans_tout=0,
            cumul_ack_tout=0,
            null_seg_tout=0,
        )
    )

    tb.dut.connRq_i.value = 1
    await tb.wait_high("sndSyn_o")
    await tb.pulse("synHeadSt_i")

    reject_wait = cocotb.start_soon(tb.wait_high("paramReject_o"))
    await tb.receive_segment(syn=1, ack=1)
    await reject_wait
    await tb.wait_high("sndRst_o")

    await tb.pulse("rstHeadSt_i")
    await tb.wait_high("closed_o")
    assert int(dut.connActive_o.value) == 0


@cocotb.test()
async def client_retries_syn_then_times_out_waiting_for_syn_ack_test(dut):
    tb = await TB.create(dut)
    tb.dut.connRq_i.value = 1
    await tb.wait_high("sndSyn_o")
    await tb.pulse("synHeadSt_i")
    await tb.wait_state(0x2)

    await tb.wait_high("closed_o", cycles=10)
    assert int(dut.peerTout_o.value) == 0
    await tb.wait_high("sndSyn_o", cycles=4)

    await tb.pulse("synHeadSt_i")
    tb.dut.connRq_i.value = 0
    await tb.wait_state(0x2)
    await tb.wait_high("peerTout_o", cycles=10)
    await tb.cycle()

    assert int(dut.connActive_o.value) == 0
    assert int(dut.closed_o.value) == 1


PARAMETER_SWEEP = [
    pytest.param({"SERVER_G": True}, id="server"),
    pytest.param({"SERVER_G": False}, id="client"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiConnFsm(parameters):
    role = "server" if parameters["SERVER_G"] else "client"
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssiconnfsmwrapper",
        parameters=parameters,
        extra_env=cocotb_filtered_env(parameters, rf"{role}_.*_test$"),
        extra_vhdl_sources={
            "surf": [
                "protocols/rssi/v1/rtl/RssiConnFsm.vhd",
                "protocols/rssi/v1/wrappers/RssiConnFsmWrapper.vhd",
            ],
        },
        force_compile=True,
    )
