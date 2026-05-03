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

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.srp.srp_test_utils import (
    FOOTER_ADDRESS_ERROR,
    FOOTER_FRAME_ERROR,
    FlatSrpAxis,
    SRP_READ,
    SrpV3Request,
    assert_srpv3_response,
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


def _selected_cocotb_test(name: str) -> bool:
    return os.environ.get("SRP_CORE_COCOTB_TEST", "reset_idle") == name


@cocotb.test()
async def srpv3_core_reset_idle_smoke_test(dut):
    if not _selected_cocotb_test("reset_idle"):
        return

    tb = TB(dut)
    await tb.reset(settle_cycles=32)

    assert int(dut.SRP_REQ_REQUEST.value) == 0
    assert int(dut.M_AXIS_TVALID.value) == 0
    assert int(dut.WR_AXIS_TVALID.value) == 0


@cocotb.test()
async def srpv3_core_narrow_header_error_probes_test(dut):
    if not _selected_cocotb_test("narrow_fault_injection"):
        return

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


@cocotb.test()
async def srpv3_core_narrow_immediate_read_error_test(dut):
    if not _selected_cocotb_test("narrow_fault_injection"):
        return

    tb = TB(dut)
    await tb.reset()
    dut.M_AXIS_TREADY.value = 0

    request = SrpV3Request(SRP_READ, 0x6100_0001, 0x1_0000_0000, 4)
    await tb.axis.send_words(request.response_header, tdest=0x5)

    for _ in range(64):
        await RisingEdge(dut.AXIS_ACLK)
        if int(dut.SRP_REQ_REQUEST.value) == 1:
            break
    else:
        raise AssertionError("Timed out waiting for SRP_REQ_REQUEST")

    dut.SRP_ACK_RESP.value = FOOTER_ADDRESS_ERROR
    dut.SRP_ACK_DONE.value = 1
    for _ in range(8):
        await RisingEdge(dut.AXIS_ACLK)
        if int(dut.SRP_REQ_REQUEST.value) == 0:
            break
    else:
        raise AssertionError("Timed out waiting for SRP_REQ_REQUEST to release")
    dut.SRP_ACK_DONE.value = 0
    dut.SRP_ACK_RESP.value = 0

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
]


@pytest.mark.parametrize("parameters", CORE_PARAMETER_SWEEP)
def test_SrpV3Core(parameters):
    hdl_parameters = parameters["HDL_PARAMETERS"]
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.srpv3corewrapper",
        parameters=hdl_parameters,
        extra_env={"SRP_CORE_COCOTB_TEST": parameters["COCOTB_TEST"]},
        extra_vhdl_sources={"surf": ["protocols/srp/wrappers/SrpV3CoreWrapper.vhd"]},
    )
