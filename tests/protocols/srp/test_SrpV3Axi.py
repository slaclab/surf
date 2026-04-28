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

from dataclasses import dataclass

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout

from tests.axi.utils import wait_sampled_ready
from tests.common.regression_utils import run_surf_vhdl_test


SRP_VERSION = 0x03
SRP_READ = 0x0
SRP_WRITE = 0x1
SRP_POSTED_WRITE = 0x2
SRP_NULL = 0x3

FOOTER_FRAME_ERROR = 1 << 10
FOOTER_VERSION_MISMATCH = 1 << 11
FOOTER_REQUEST_ERROR = 1 << 12
FOOTER_ADDRESS_ERROR = 1 << 7


@dataclass(frozen=True)
class SrpRequest:
    opcode: int
    tid: int
    address: int
    byte_count: int
    version: int = SRP_VERSION
    timeout: int = 0
    prot: int = 0
    spare: int = 0

    @property
    def req_size(self) -> int:
        return self.byte_count - 1

    @property
    def response_header(self) -> list[int]:
        # The response reports the local SRPv3 version while echoing the rest
        # of the request metadata that software uses to match transactions.
        return request_header(
            opcode=self.opcode,
            tid=self.tid,
            address=self.address,
            req_size=self.req_size,
            version=SRP_VERSION,
            timeout=self.timeout,
            prot=self.prot,
            spare=self.spare,
        )


@dataclass(frozen=True)
class SrpResponse:
    words: list[int]
    tdest: list[int]
    tuser: list[int]
    tkeep: list[int]

    @property
    def footer(self) -> int:
        return self.words[-1]


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 10.0, unit="ns").start())

    async def reset(self):
        # Initialize every driven bus field before the first clock edge so the
        # DUT never sees unknown stimulus during reset release.
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        self.dut.S_AXIS_TVALID.setimmediatevalue(0)
        self.dut.S_AXIS_TDATA.setimmediatevalue(0)
        self.dut.S_AXIS_TKEEP.setimmediatevalue(0xF)
        self.dut.S_AXIS_TLAST.setimmediatevalue(0)
        self.dut.S_AXIS_TDEST.setimmediatevalue(0)
        self.dut.S_AXIS_TID.setimmediatevalue(0)
        self.dut.S_AXIS_TUSER.setimmediatevalue(0)
        self.dut.M_AXIS_TREADY.setimmediatevalue(1)

        # Match the legacy benches by holding reset long enough for the SRP
        # FIFOs and attached RAM model to settle before the first frame.
        for _ in range(110):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(8):
            await RisingEdge(self.dut.AXIS_ACLK)

    async def send_words(self, words: list[int], *, tdest: int = 0):
        # Present one 32-bit SSI beat at a time and only advance after the DUT
        # accepts it. The first beat carries SOF in the flattened SSI TUSER bit.
        for index, word in enumerate(words):
            self.dut.S_AXIS_TVALID.value = 1
            self.dut.S_AXIS_TDATA.value = word & 0xFFFF_FFFF
            self.dut.S_AXIS_TKEEP.value = 0xF
            self.dut.S_AXIS_TLAST.value = int(index == len(words) - 1)
            self.dut.S_AXIS_TDEST.value = tdest
            self.dut.S_AXIS_TID.value = 0
            self.dut.S_AXIS_TUSER.value = 0x2 if index == 0 else 0x0

            await wait_sampled_ready(self.dut.S_AXIS_TREADY, clk=self.dut.AXIS_ACLK)

        self.dut.S_AXIS_TVALID.value = 0
        self.dut.S_AXIS_TLAST.value = 0
        self.dut.S_AXIS_TUSER.value = 0

    async def wait_for_output_valid(self):
        # Used by the backpressure check: wait until the DUT has a response
        # pending while the sink is deliberately not ready.
        while int(self.dut.M_AXIS_TVALID.value) != 1:
            await with_timeout(RisingEdge(self.dut.AXIS_ACLK), 2, "ms")

    async def recv_response(self) -> SrpResponse:
        words = []
        tdest = []
        tuser = []
        tkeep = []
        self.dut.M_AXIS_TREADY.value = 1

        # Capture exactly the beats that complete a ready/valid handshake.
        while True:
            await with_timeout(RisingEdge(self.dut.AXIS_ACLK), 2, "ms")
            if int(self.dut.M_AXIS_TVALID.value) != 1:
                continue

            words.append(int(self.dut.M_AXIS_TDATA.value))
            tdest.append(int(self.dut.M_AXIS_TDEST.value))
            tuser.append(int(self.dut.M_AXIS_TUSER.value))
            tkeep.append(int(self.dut.M_AXIS_TKEEP.value))
            if int(self.dut.M_AXIS_TLAST.value) == 1:
                return SrpResponse(words=words, tdest=tdest, tuser=tuser, tkeep=tkeep)

    async def expect_no_response(self, *, cycles: int = 80):
        # Posted writes are expected to update memory without producing any
        # outbound SRP frame. Keep the sink ready so a surprise response cannot
        # hide behind backpressure.
        self.dut.M_AXIS_TREADY.value = 1
        for _ in range(cycles):
            await RisingEdge(self.dut.AXIS_ACLK)
            assert int(self.dut.M_AXIS_TVALID.value) == 0


def request_header(
    *,
    opcode: int,
    tid: int,
    address: int,
    req_size: int,
    version: int = SRP_VERSION,
    timeout: int = 0,
    prot: int = 0,
    spare: int = 0,
) -> list[int]:
    word0 = (
        (version & 0xFF)
        | ((opcode & 0x3) << 8)
        | ((spare & 0x7FF) << 10)
        | ((prot & 0x7) << 21)
        | ((timeout & 0xFF) << 24)
    )
    return [
        word0,
        tid & 0xFFFF_FFFF,
        address & 0xFFFF_FFFF,
        (address >> 32) & 0xFFFF_FFFF,
        req_size & 0xFFFF_FFFF,
    ]


def request_frame(request: SrpRequest, payload: list[int] | None = None) -> list[int]:
    payload = [] if payload is None else payload
    return request_header(
        opcode=request.opcode,
        tid=request.tid,
        address=request.address,
        req_size=request.req_size,
        version=request.version,
        timeout=request.timeout,
        prot=request.prot,
        spare=request.spare,
    ) + payload


def assert_response(
    response: SrpResponse,
    request: SrpRequest,
    payload: list[int],
    *,
    footer_mask: int = 0,
    footer_value: int = 0,
    expected_tdest: int | None = None,
):
    assert response.words[:5] == request.response_header
    assert response.words[5:-1] == [word & 0xFFFF_FFFF for word in payload]
    assert response.footer & footer_mask == footer_value

    if expected_tdest is not None:
        assert response.tdest == [expected_tdest] * len(response.words)

    # All curated responses are full 32-bit words, including the footer.
    assert response.tkeep == [0xF] * len(response.words)
    assert response.tuser[0] & 0x2 == 0x2


async def issue_and_check_error(
    tb: TB,
    request: SrpRequest,
    payload: list[int],
    *,
    expected_footer_bits: int,
):
    await tb.send_words(request_frame(request, payload))
    response = await tb.recv_response()
    assert_response(
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
    write_req = SrpRequest(SRP_WRITE, 0x1000_0001, 0x40, 4 * len(write_payload))
    await tb.send_words(request_frame(write_req, write_payload), tdest=0x3)
    assert_response(await tb.recv_response(), write_req, write_payload, expected_tdest=0x3)

    # Hold the response sink not-ready until the first read beat is pending.
    # The first header beat must remain stable until the sink accepts it.
    read_req = SrpRequest(SRP_READ, 0x1000_0002, 0x40, 4 * len(write_payload), prot=0x5)
    tb.dut.M_AXIS_TREADY.value = 0
    await tb.send_words(request_frame(read_req), tdest=0x5)
    await tb.wait_for_output_valid()
    held_word = int(tb.dut.M_AXIS_TDATA.value)
    for _ in range(5):
        await RisingEdge(tb.dut.AXIS_ACLK)
        assert int(tb.dut.M_AXIS_TVALID.value) == 1
        assert int(tb.dut.M_AXIS_TDATA.value) == held_word
    tb.dut.M_AXIS_TREADY.value = 1
    assert_response(await tb.recv_response(), read_req, write_payload, expected_tdest=0x5)

    # Posted writes are common in applications: they must not return a frame,
    # but a later read still has to observe the memory update.
    posted_payload = [0x01020304, 0xAABBCCDD, 0x0BADF00D, 0xCAFEBABE]
    posted_req = SrpRequest(SRP_POSTED_WRITE, 0x2000_0001, 0x80, 4 * len(posted_payload))
    await tb.send_words(request_frame(posted_req, posted_payload), tdest=0x7)
    await tb.expect_no_response()

    posted_read_req = SrpRequest(SRP_READ, 0x2000_0002, 0x80, 4 * len(posted_payload))
    await tb.send_words(request_frame(posted_read_req), tdest=0x7)
    assert_response(await tb.recv_response(), posted_read_req, posted_payload, expected_tdest=0x7)

    # NULL requests exercise the header/footer-only path without touching the
    # AXI RAM. The request size is still echoed so software can correlate it.
    null_req = SrpRequest(SRP_NULL, 0x3000_0001, 0x0000, 1)
    await tb.send_words(request_frame(null_req), tdest=0x1)
    assert_response(await tb.recv_response(), null_req, [], expected_tdest=0x1)

    # The footer matrix locks down common software-visible failure reporting:
    # bad version, malformed write framing, invalid alignment/size, and an AXI
    # address-range error returned from the bridge layer.
    bad_version_req = SrpRequest(SRP_READ, 0x4000_0001, 0x40, 4, version=0x02)
    await issue_and_check_error(
        tb,
        bad_version_req,
        [],
        expected_footer_bits=FOOTER_VERSION_MISMATCH,
    )

    truncated_write_req = SrpRequest(SRP_WRITE, 0x4000_0002, 0x40, 4)
    await issue_and_check_error(
        tb,
        truncated_write_req,
        [],
        expected_footer_bits=FOOTER_FRAME_ERROR,
    )

    unaligned_read_req = SrpRequest(SRP_READ, 0x4000_0003, 0x42, 4)
    await issue_and_check_error(
        tb,
        unaligned_read_req,
        [],
        expected_footer_bits=FOOTER_REQUEST_ERROR,
    )

    short_read_req = SrpRequest(SRP_READ, 0x4000_0004, 0x40, 2)
    await issue_and_check_error(
        tb,
        short_read_req,
        [],
        expected_footer_bits=FOOTER_REQUEST_ERROR,
    )

    out_of_range_write_req = SrpRequest(SRP_WRITE, 0x4000_0005, 0x1000, 4)
    await issue_and_check_error(
        tb,
        out_of_range_write_req,
        [0xDEADBEEF],
        expected_footer_bits=FOOTER_ADDRESS_ERROR,
    )

    out_of_range_read_req = SrpRequest(SRP_READ, 0x4000_0006, 0x1_0000_0000, 4)
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
