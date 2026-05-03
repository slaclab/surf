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
# - Sweep: Exercise one checked-in SRPv3 AXI bridge wrapper in a directed
#   matrix covering reads, non-posted writes, posted writes, null requests, and
#   representative protocol-error footers.
# - Stimulus: Drive 32-bit SRPv3 request frames into the SSI-side stream with
#   varied transaction IDs, TDEST values, addresses, payload lengths, and
#   malformed header fields.
# - Checks: Scoreboard echoed headers, write echoes, read payloads from the
#   attached AXI RAM, posted-write silence, TDEST propagation, and footer bits
#   for version, framing, request-size/alignment, and downstream address errors.
# - Timing: All transfers are ready/valid driven, one read response is held
#   under output backpressure before release, and every expected or forbidden
#   response is bounded by an explicit timeout.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.srp.srp_test_utils import (
    FOOTER_ADDRESS_ERROR,
    FOOTER_FRAME_ERROR,
    FOOTER_REQUEST_ERROR,
    FOOTER_VERSION_MISMATCH,
    FlatSrpAxis,
    SRP_NULL,
    SRP_POSTED_WRITE,
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

    async def reset(self):
        # Initialize every driven bus field before the first clock edge so the
        # DUT never sees unknown stimulus during reset release.
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        self.axis.init_source()
        self.axis.init_sink()

        # Match the legacy benches by holding reset long enough for the SRP
        # FIFOs and attached RAM model to settle before the first frame.
        for _ in range(110):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(8):
            await RisingEdge(self.dut.AXIS_ACLK)

    async def wait_for_output_valid(self):
        # Used by the backpressure check: wait until the DUT has a response
        # pending while the sink is deliberately not ready.
        while int(self.dut.M_AXIS_TVALID.value) != 1:
            await with_timeout(RisingEdge(self.dut.AXIS_ACLK), 2, "ms")


async def issue_and_check_error(
    tb: TB,
    request: SrpV3Request,
    payload: list[int],
    *,
    expected_footer_bits: int,
):
    await tb.axis.send_words(srpv3_frame(request, payload))
    response = await tb.axis.recv_response()
    assert_srpv3_response(
        response,
        request,
        payload=payload,
        footer_mask=expected_footer_bits,
        footer_value=expected_footer_bits,
    )


@cocotb.test()
async def srpv3_axi_directed_protocol_matrix_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A non-posted write must echo the accepted data, complete with a clean
    # footer, and the same bytes must be readable from the attached AXI RAM.
    write_payload = [0x11223344, 0x55667788, 0xA5A55A5A]
    write_req = SrpV3Request(SRP_WRITE, 0x1000_0001, 0x40, 4 * len(write_payload))
    await tb.axis.send_words(srpv3_frame(write_req, write_payload), tdest=0x3)
    assert_srpv3_response(await tb.axis.recv_response(), write_req, write_payload, expected_tdest=0x3)

    # Hold the response sink not-ready until the first read beat is pending.
    # The first header beat must remain stable until the sink accepts it.
    read_req = SrpV3Request(SRP_READ, 0x1000_0002, 0x40, 4 * len(write_payload), prot=0x5)
    tb.dut.M_AXIS_TREADY.value = 0
    await tb.axis.send_words(srpv3_frame(read_req), tdest=0x5)
    await tb.wait_for_output_valid()
    held_word = int(tb.dut.M_AXIS_TDATA.value)
    for _ in range(5):
        await RisingEdge(tb.dut.AXIS_ACLK)
        assert int(tb.dut.M_AXIS_TVALID.value) == 1
        assert int(tb.dut.M_AXIS_TDATA.value) == held_word
    tb.dut.M_AXIS_TREADY.value = 1
    assert_srpv3_response(await tb.axis.recv_response(), read_req, write_payload, expected_tdest=0x5)

    # Posted writes are common in applications: they must not return a frame,
    # but a later read still has to observe the memory update.
    posted_payload = [0x01020304, 0xAABBCCDD, 0x0BADF00D, 0xCAFEBABE]
    posted_req = SrpV3Request(SRP_POSTED_WRITE, 0x2000_0001, 0x80, 4 * len(posted_payload))
    await tb.axis.send_words(srpv3_frame(posted_req, posted_payload), tdest=0x7)
    await tb.axis.expect_no_response()

    posted_read_req = SrpV3Request(SRP_READ, 0x2000_0002, 0x80, 4 * len(posted_payload))
    await tb.axis.send_words(srpv3_frame(posted_read_req), tdest=0x7)
    assert_srpv3_response(await tb.axis.recv_response(), posted_read_req, posted_payload, expected_tdest=0x7)

    # NULL requests exercise the header/footer-only path without touching the
    # AXI RAM. The request size is still echoed so software can correlate it.
    null_req = SrpV3Request(SRP_NULL, 0x3000_0001, 0x0000, 1)
    await tb.axis.send_words(srpv3_frame(null_req), tdest=0x1)
    assert_srpv3_response(await tb.axis.recv_response(), null_req, [], expected_tdest=0x1)

    # The footer matrix locks down common software-visible failure reporting:
    # bad version, malformed write framing, invalid alignment/size, and an AXI
    # address-range error returned from the bridge layer.
    bad_version_req = SrpV3Request(SRP_READ, 0x4000_0001, 0x40, 4, version=0x02)
    await issue_and_check_error(
        tb,
        bad_version_req,
        [],
        expected_footer_bits=FOOTER_VERSION_MISMATCH,
    )

    truncated_write_req = SrpV3Request(SRP_WRITE, 0x4000_0002, 0x40, 4)
    await issue_and_check_error(
        tb,
        truncated_write_req,
        [],
        expected_footer_bits=FOOTER_FRAME_ERROR,
    )

    unaligned_read_req = SrpV3Request(SRP_READ, 0x4000_0003, 0x42, 4)
    await issue_and_check_error(
        tb,
        unaligned_read_req,
        [],
        expected_footer_bits=FOOTER_REQUEST_ERROR,
    )

    short_read_req = SrpV3Request(SRP_READ, 0x4000_0004, 0x40, 2)
    await issue_and_check_error(
        tb,
        short_read_req,
        [],
        expected_footer_bits=FOOTER_REQUEST_ERROR,
    )

    out_of_range_write_req = SrpV3Request(SRP_WRITE, 0x4000_0005, 0x1000, 4)
    await issue_and_check_error(
        tb,
        out_of_range_write_req,
        [0xDEADBEEF],
        expected_footer_bits=FOOTER_ADDRESS_ERROR,
    )

    out_of_range_read_req = SrpV3Request(SRP_READ, 0x4000_0006, 0x1_0000_0000, 4)
    await issue_and_check_error(
        tb,
        out_of_range_read_req,
        [],
        expected_footer_bits=FOOTER_ADDRESS_ERROR,
    )


PARAMETER_SWEEP = [pytest.param({}, id="default_protocol_matrix")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SrpV3Axi(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.srpv3axiwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/srp/wrappers/SrpV3AxiWrapper.vhd"]},
    )
