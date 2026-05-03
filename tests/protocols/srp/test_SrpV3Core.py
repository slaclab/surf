##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Cover the default 64-bit core-facing wrapper path with reset/idle
#   smoke, then use the same wrapper with `CORE_DATA_BYTES_G => 4` for direct
#   core-local fault injection.
# - Stimulus: Reset the wrapper with all exposed SRP, read-data, and stream
#   inputs held idle, or drive malformed/valid narrow SRPv3 request headers
#   while directly controlling downstream ack/read-data return signals.
# - Checks: The default wrapper must elaborate and stay idle after reset. The
#   narrow core mode must emit aligned error responses for truncated headers
#   and immediate downstream read rejection without requiring a read-data beat.
# - Timing: Sources obey ready/valid sampling, and the downstream ack path is
#   pulsed cycle-accurately to exercise the `READ_S` to `WAIT_ACK_S` corner.

import cocotb
import os
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tests.axi.utils import wait_sampled_ready
from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.srp.srp_test_utils import (
    FOOTER_ADDRESS_ERROR,
    FOOTER_EOFE,
    FOOTER_FRAME_ERROR,
    FOOTER_REQUEST_ERROR,
    FlatSrpAxis,
    SRP_READ,
    SRP_WRITE,
    SrpV3Request,
    assert_srpv3_response,
    srpv3_frame,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 10.0, unit="ns").start())
        self.axis = FlatSrpAxis(dut, clk=dut.AXIS_ACLK)
        self.read_axis = FlatSrpAxis(dut, clk=dut.AXIS_ACLK, source_prefix="RD_AXIS", sink_prefix="WR_AXIS")

    async def reset(self, *, settle_cycles: int = 8):
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        self.axis.init_source()
        self.axis.init_sink()
        self.read_axis.init_source(prefix="RD_AXIS")
        self.read_axis.init_sink(prefix="WR_AXIS")
        self.dut.SRP_ACK_DONE.setimmediatevalue(0)
        self.dut.SRP_ACK_RESP.setimmediatevalue(0)
        for _ in range(80):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(settle_cycles):
            await RisingEdge(self.dut.AXIS_ACLK)

    async def pulse_ack(self, *, resp: int = 0):
        self.dut.SRP_ACK_RESP.value = resp
        self.dut.SRP_ACK_DONE.value = 1
        for _ in range(8):
            await RisingEdge(self.dut.AXIS_ACLK)
            if int(self.dut.SRP_REQ_REQUEST.value) == 0:
                break
        else:
            raise AssertionError("Timed out waiting for SRP_REQ_REQUEST to release")
        self.dut.SRP_ACK_DONE.value = 0
        self.dut.SRP_ACK_RESP.value = 0

    async def wait_for_request(self):
        for _ in range(64):
            await RisingEdge(self.dut.AXIS_ACLK)
            if int(self.dut.SRP_REQ_REQUEST.value) == 1:
                return
        raise AssertionError("Timed out waiting for SRP_REQ_REQUEST")

    async def send_words_with_tuser(
        self,
        words: list[int],
        users: list[int],
        *,
        lasts: list[int] | None = None,
        tdest: int = 0,
        prefix: str = "S_AXIS",
    ):
        assert len(words) == len(users)
        if lasts is None:
            lasts = [int(index == len(words) - 1) for index in range(len(words))]
        assert len(words) == len(lasts)
        for index, (word, user) in enumerate(zip(words, users)):
            getattr(self.dut, f"{prefix}_TVALID").value = 1
            getattr(self.dut, f"{prefix}_TDATA").value = word & 0xFFFF_FFFF
            getattr(self.dut, f"{prefix}_TKEEP").value = 0xF
            getattr(self.dut, f"{prefix}_TLAST").value = lasts[index]
            if hasattr(self.dut, f"{prefix}_TDEST"):
                getattr(self.dut, f"{prefix}_TDEST").value = tdest
            if hasattr(self.dut, f"{prefix}_TID"):
                getattr(self.dut, f"{prefix}_TID").value = 0
            getattr(self.dut, f"{prefix}_TUSER").value = user
            await wait_sampled_ready(
                getattr(self.dut, f"{prefix}_TREADY"),
                clk=self.dut.AXIS_ACLK,
            )
        getattr(self.dut, f"{prefix}_TVALID").value = 0
        getattr(self.dut, f"{prefix}_TLAST").value = 0
        getattr(self.dut, f"{prefix}_TUSER").value = 0


def _selected_cocotb_test(name: str) -> bool:
    return os.environ.get("SRP_CORE_COCOTB_TEST", "reset_idle") == name


async def issue_and_check_error(
    tb: TB,
    request: SrpV3Request,
    payload: list[int] | None = None,
    *,
    expected_footer_bits: int,
    expected_tdest: int | None = None,
):
    payload = [] if payload is None else payload
    response_task = cocotb.start_soon(tb.axis.recv_response())
    await tb.axis.send_words(
        srpv3_frame(request, payload),
        tdest=0 if expected_tdest is None else expected_tdest,
    )
    assert_srpv3_response(
        await response_task,
        request,
        payload=payload if expected_footer_bits in (FOOTER_FRAME_ERROR, FOOTER_EOFE) else [],
        footer_mask=expected_footer_bits,
        footer_value=expected_footer_bits,
        expected_tdest=expected_tdest,
    )


@cocotb.test(skip=not _selected_cocotb_test("reset_idle"))
async def srpv3_core_reset_idle_smoke_test(dut):
    tb = TB(dut)
    await tb.reset(settle_cycles=32)

    assert int(dut.SRP_REQ_REQUEST.value) == 0
    assert int(dut.M_AXIS_TVALID.value) == 0
    assert int(dut.WR_AXIS_TVALID.value) == 0


@cocotb.test(skip=not _selected_cocotb_test("narrow_fault_injection"))
async def srpv3_core_narrow_header_error_probes_test(dut):
    tb = TB(dut)
    await tb.reset()

    await tb.axis.send_words([0x0000_0003])
    short_response = await tb.axis.recv_response()
    assert_srpv3_response(
        short_response,
        SrpV3Request(SRP_READ, 0, 0, 1),
        payload=[],
        footer_mask=FOOTER_FRAME_ERROR,
        footer_value=FOOTER_FRAME_ERROR,
    )
    assert int(dut.SRP_REQ_REQUEST.value) == 0

    await tb.axis.send_words(
        [
            0x0000_0003,
            0x5100_0200,
            0x0000_0020,
            0x0000_0000,
        ],
        tdest=0x3,
    )
    four_beat_response = await tb.axis.recv_response()
    assert_srpv3_response(
        four_beat_response,
        SrpV3Request(SRP_READ, 0x5100_0200, 0x20, 1),
        payload=[],
        footer_mask=FOOTER_FRAME_ERROR,
        footer_value=FOOTER_FRAME_ERROR,
        expected_tdest=0x3,
    )
    assert int(dut.SRP_REQ_REQUEST.value) == 0


@cocotb.test(skip=not _selected_cocotb_test("narrow_fault_injection"))
async def srpv3_core_narrow_immediate_read_error_test(dut):
    tb = TB(dut)
    await tb.reset()
    dut.M_AXIS_TREADY.value = 0

    request = SrpV3Request(SRP_READ, 0x6100_0001, 0x1_0000_0000, 4)
    await tb.axis.send_words(request.response_header, tdest=0x5)

    await tb.wait_for_request()
    await tb.pulse_ack(resp=FOOTER_ADDRESS_ERROR)

    for _ in range(64):
        await RisingEdge(dut.AXIS_ACLK)
        if int(dut.M_AXIS_TVALID.value) == 1:
            break
    else:
        raise AssertionError("Timed out waiting for response header to become visible")

    response = await tb.axis.recv_response()
    assert_srpv3_response(
        response,
        request,
        payload=[],
        footer_mask=FOOTER_ADDRESS_ERROR,
        footer_value=FOOTER_ADDRESS_ERROR,
        expected_tdest=0x5,
    )
    assert int(dut.RD_AXIS_TREADY.value) == 0


@cocotb.test(skip=not _selected_cocotb_test("disabled_op"))
async def srpv3_core_disabled_operation_test(dut):
    tb = TB(dut)
    await tb.reset()

    mode = os.environ["SRP_CORE_DISABLED_OP"]
    if mode == "read":
        request = SrpV3Request(SRP_READ, 0x7100_0001, 0x20, 4)
        await issue_and_check_error(
            tb,
            request,
            expected_footer_bits=FOOTER_REQUEST_ERROR,
            expected_tdest=0x2,
        )
    else:
        request = SrpV3Request(SRP_WRITE, 0x7100_0002, 0x20, 4)
        await issue_and_check_error(
            tb,
            request,
            [0x1357_9BDF],
            expected_footer_bits=FOOTER_REQUEST_ERROR,
            expected_tdest=0x3,
        )
    assert int(dut.SRP_REQ_REQUEST.value) == 0


@cocotb.test(skip=not _selected_cocotb_test("narrow_protocol_edges"))
async def srpv3_core_narrow_protocol_edge_cases_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Frames without SOF should be discarded rather than interpreted as a
    # request.
    no_sof_request = SrpV3Request(SRP_READ, 0x7200_0001, 0x20, 4)
    await tb.send_words_with_tuser(srpv3_frame(no_sof_request), [0, 0, 0, 0, 0])
    await tb.axis.expect_no_response(cycles=96)
    assert int(dut.SRP_REQ_REQUEST.value) == 0

    # A write that terminates before the requested byte count reports a framing
    # error while still echoing the data word that was accepted.
    short_write_request = SrpV3Request(SRP_WRITE, 0x7200_0003, 0x28, 8)
    short_write_payload = [0xDEAD_BEEF]
    response_task = cocotb.start_soon(tb.axis.recv_response())
    await tb.axis.send_words(
        srpv3_frame(short_write_request, short_write_payload),
        tdest=0x5,
    )
    await tb.wait_for_request()
    await tb.pulse_ack()
    assert_srpv3_response(
        await response_task,
        short_write_request,
        payload=short_write_payload,
        footer_mask=FOOTER_FRAME_ERROR,
        footer_value=FOOTER_FRAME_ERROR,
        expected_tdest=0x5,
    )

    # A read-data stream that asserts TLAST before the requested byte count is
    # surfaced as EOFE in the response footer after the downstream ack.
    early_read_request = SrpV3Request(SRP_READ, 0x7200_0004, 0x2C, 8)
    early_read_payload = [0xCAFE_BABE]
    response_task = cocotb.start_soon(tb.axis.recv_response())
    await tb.axis.send_words(srpv3_frame(early_read_request), tdest=0x6)
    await tb.wait_for_request()
    await tb.read_axis.send_words(early_read_payload, prefix="RD_AXIS")
    await tb.pulse_ack()
    assert_srpv3_response(
        await response_task,
        early_read_request,
        payload=early_read_payload,
        footer_mask=FOOTER_EOFE,
        footer_value=FOOTER_EOFE,
        expected_tdest=0x6,
    )

    # A read-data stream that omits TLAST when the requested byte count is
    # reached also reports EOFE, then blows off the trailing data beat.
    late_read_request = SrpV3Request(SRP_READ, 0x7200_0005, 0x30, 4)
    late_read_payload = [0x0BAD_C0DE]
    response_task = cocotb.start_soon(tb.axis.recv_response())
    await tb.axis.send_words(srpv3_frame(late_read_request), tdest=0x7)
    await tb.wait_for_request()
    read_data_task = cocotb.start_soon(
        tb.send_words_with_tuser(
            late_read_payload + [0xFEED_FACE],
            [0x2, 0],
            lasts=[0, 1],
            prefix="RD_AXIS",
        ),
    )
    assert_srpv3_response(
        await response_task,
        late_read_request,
        payload=late_read_payload,
        footer_mask=FOOTER_EOFE,
        footer_value=FOOTER_EOFE,
        expected_tdest=0x7,
    )
    await read_data_task


CORE_PARAMETER_SWEEP = [
    pytest.param(
        {
            "COCOTB_TEST": "reset_idle",
            "HDL_PARAMETERS": {},
        },
        id="direct_core_reset_idle",
    ),
    pytest.param(
        {
            "COCOTB_TEST": "narrow_fault_injection",
            "HDL_PARAMETERS": {"CORE_DATA_BYTES_G": 4},
        },
        id="direct_core_narrow_fault_injection",
    ),
    pytest.param(
        {
            "COCOTB_TEST": "narrow_protocol_edges",
            "HDL_PARAMETERS": {"CORE_DATA_BYTES_G": 4},
        },
        id="direct_core_narrow_protocol_edges",
    ),
    pytest.param(
        {
            "COCOTB_TEST": "disabled_op",
            "DISABLED_OP": "read",
            "HDL_PARAMETERS": {"CORE_DATA_BYTES_G": 4, "READ_EN_G": False},
        },
        id="direct_core_read_disabled",
    ),
    pytest.param(
        {
            "COCOTB_TEST": "disabled_op",
            "DISABLED_OP": "write",
            "HDL_PARAMETERS": {"CORE_DATA_BYTES_G": 4, "WRITE_EN_G": False},
        },
        id="direct_core_write_disabled",
    ),
]


@pytest.mark.parametrize("parameters", CORE_PARAMETER_SWEEP)
def test_SrpV3Core(parameters):
    hdl_parameters = parameters["HDL_PARAMETERS"]
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.srpv3corewrapper",
        parameters=hdl_parameters,
        extra_env={
            "SRP_CORE_COCOTB_TEST": parameters["COCOTB_TEST"],
            "SRP_CORE_DISABLED_OP": parameters.get("DISABLED_OP", ""),
        },
        extra_vhdl_sources={"surf": ["protocols/srp/wrappers/SrpV3CoreWrapper.vhd"]},
    )
