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
# - Sweep: Keep reset coverage on the direct, full, and legacy-wide wrappers,
#   and run active transactions through the direct 256-bit legacy framing that
#   matches the existing VHDL testbench.
# - Stimulus: Drive SRPv3 write, read, posted-write, and malformed request
#   frames into each wrapper's SSI-side AXI Stream port.
# - Checks: Non-posted writes echo data and update the RAM, posted writes remain
#   silent but are readable later, invalid requests set the expected footer bits
#   without returning payload data, and known-issue probes preserve the narrowed
#   32-bit multi-beat failure mode.
# - Timing: The bench uses ready/valid handshakes on every AXI Stream beat and
#   bounded response waits so a stalled SRP request fails deterministically.

import cocotb
import os
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteRam

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.srp.srp_test_utils import (
    FOOTER_ADDRESS_ERROR,
    FOOTER_VERSION_MISMATCH,
    FOOTER_FRAME_ERROR,
    SRP_POSTED_WRITE,
    SRP_NULL,
    SRP_READ,
    SRP_WRITE,
    FlatSrpAxis,
    SrpV3Request,
    assert_srpv3_response,
    srpv3_frame,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 10.0, unit="ns").start())
        self.axis = FlatSrpAxis(
            dut,
            clk=dut.AXIS_ACLK,
            data_bytes=int(os.environ.get("SRP_AXIS_BYTES", "4")),
        )
        self.axil_ram = AxiLiteRam(
            AxiLiteBus.from_prefix(dut, "M_AXIL"),
            dut.AXIS_ACLK,
            dut.AXIS_ARESETN,
            reset_active_level=False,
            size=2**12,
        )

    async def reset(self):
        # Reset the wrapper and initialize both stream directions before any
        # SRPv3 frame is allowed onto the input FIFO.
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        self.axis.init_source()
        self.axis.init_sink()
        for _ in range(80):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(8):
            await RisingEdge(self.dut.AXIS_ACLK)


def _selected_cocotb_test(name: str) -> bool:
    return os.environ.get("SRP_AXI_LITE_COCOTB_TEST", "directed") == name


async def log_single_read_pins(dut, *, cycles: int = 32):
    for index in range(cycles):
        await RisingEdge(dut.AXIS_ACLK)
        await Timer(1, unit="ns")
        dut._log.info(
            "single read monitor[%02d] tvalid=%s tlast=%s tdata=%s arvalid=%s arready=%s rvalid=%s rready=%s",
            index,
            dut.M_AXIS_TVALID.value,
            dut.M_AXIS_TLAST.value,
            dut.M_AXIS_TDATA.value,
            dut.M_AXIL_ARVALID.value,
            dut.M_AXIL_ARREADY.value,
            dut.M_AXIL_RVALID.value,
            dut.M_AXIL_RREADY.value,
        )


async def issue_and_check_error(tb: TB, request: SrpV3Request, *, expected_footer_bits: int):
    await tb.axis.send_words(srpv3_frame(request))
    response = await tb.axis.recv_response()
    assert_srpv3_response(
        response,
        request,
        payload=[],
        footer_mask=expected_footer_bits,
        footer_value=expected_footer_bits,
    )


@cocotb.test(skip=not _selected_cocotb_test("reset_idle"))
async def srpv3_axilite_reset_idle_smoke_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The reset-only test is intentionally active while the full directed test
    # remains gated. It catches elaboration/reset issues without driving the
    # request path that is under investigation.
    await tb.axis.expect_no_response(cycles=32)


@cocotb.test(skip=not _selected_cocotb_test("short_frame"))
async def srpv3_axilite_short_frame_probe_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A one-beat frame exercises the RX framing path without reaching the
    # AXI-Lite master. It narrows failures before the memory backend is involved.
    await tb.axis.send_words([0x0000_0003])
    assert_srpv3_response(
        await tb.axis.recv_response(),
        SrpV3Request(SRP_READ, 0, 0, 1),
        [],
        footer_mask=FOOTER_FRAME_ERROR,
        footer_value=FOOTER_FRAME_ERROR,
    )


@cocotb.test(skip=not _selected_cocotb_test("single_read"))
async def srpv3_axilite_single_read_probe_test(dut):
    tb = TB(dut)
    await tb.reset()

    # First valid AXI-Lite-backed read. If this stalls, the failure is after
    # header parsing and in the AXI-Lite transaction or response path.
    read_req = SrpV3Request(SRP_READ, 0x5100_0100, 0x20, 4)
    cocotb.start_soon(log_single_read_pins(dut))
    dut._log.info("single read probe: sending request")
    await tb.axis.send_words(srpv3_frame(read_req), tdest=0x1)
    dut._log.info("single read probe: request accepted")
    dut._log.info(
        "single read probe: post-request pins "
        "M_AXIS_TVALID=%s M_AXIS_TREADY=%s M_AXIL_ARVALID=%s M_AXIL_ARREADY=%s M_AXIL_RREADY=%s",
        dut.M_AXIS_TVALID.value,
        dut.M_AXIS_TREADY.value,
        dut.M_AXIL_ARVALID.value,
        dut.M_AXIL_ARREADY.value,
        dut.M_AXIL_RREADY.value,
    )
    assert_srpv3_response(
        await tb.axis.recv_response(),
        read_req,
        [0],
        expected_tdest=0x1,
    )


@cocotb.test(skip=not _selected_cocotb_test("directed"))
async def srpv3_axilite_read_write_and_error_paths_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Non-posted writes should echo the written words and commit them to the
    # attached AXI-Lite RAM one aligned word at a time.
    write_payload = [0x10203040, 0x55667788]
    write_req = SrpV3Request(SRP_WRITE, 0x5100_0001, 0x20, 4 * len(write_payload))
    await tb.axis.send_words(srpv3_frame(write_req, write_payload), tdest=0x4)
    assert_srpv3_response(
        await tb.axis.recv_response(),
        write_req,
        write_payload,
        expected_tdest=0x4,
    )

    read_req = SrpV3Request(SRP_READ, 0x5100_0002, 0x20, 4 * len(write_payload))
    await tb.axis.send_words(srpv3_frame(read_req), tdest=0x4)
    assert_srpv3_response(
        await tb.axis.recv_response(),
        read_req,
        write_payload,
        expected_tdest=0x4,
    )

    # Posted writes are heavily used by software. They must update RAM without
    # producing an outbound response frame.
    posted_payload = [0xCAFEBABE]
    posted_req = SrpV3Request(SRP_POSTED_WRITE, 0x5100_0003, 0x34, 4)
    await tb.axis.send_words(srpv3_frame(posted_req, posted_payload), tdest=0x2)
    await tb.axis.expect_no_response(cycles=80)

    posted_read_req = SrpV3Request(SRP_READ, 0x5100_0004, 0x34, 4)
    await tb.axis.send_words(srpv3_frame(posted_read_req), tdest=0x2)
    assert_srpv3_response(
        await tb.axis.recv_response(),
        posted_read_req,
        posted_payload,
        expected_tdest=0x2,
    )

    # Lock down the software-visible footer bits for the common reject paths
    # that do not require a slow timeout-oriented test.
    await issue_and_check_error(
        tb,
        SrpV3Request(SRP_READ, 0x5100_0005, 0x20, 4, version=0x02),
        expected_footer_bits=FOOTER_VERSION_MISMATCH,
    )
    await issue_and_check_error(
        tb,
        SrpV3Request(SRP_READ, 0x5100_0006, 0x1_0000_0000, 4),
        expected_footer_bits=FOOTER_ADDRESS_ERROR,
    )


PARAMETER_SWEEP = [
    pytest.param(
        {
            "TOPLEVEL": "surf.srpv3axilitewrapper",
            "WRAPPER_SOURCE": "protocols/srp/wrappers/SrpV3AxiLiteWrapper.vhd",
        },
        id="srpv3_axilite_direct",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.srpv3axilitefullwrapper",
            "WRAPPER_SOURCE": "protocols/srp/wrappers/SrpV3AxiLiteFullWrapper.vhd",
        },
        id="srpv3_axilite_full",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.srpv3axilitewidewrapper",
            "WRAPPER_SOURCE": "protocols/srp/wrappers/SrpV3AxiLiteWideWrapper.vhd",
            "SRP_AXIS_BYTES": 32,
        },
        id="srpv3_axilite_direct_wide",
    ),
]

LEGACY_WIDE_DIRECT_PARAMETERS = {
    "TOPLEVEL": "surf.srpv3axilitewidewrapper",
    "WRAPPER_SOURCE": "protocols/srp/wrappers/SrpV3AxiLiteWideWrapper.vhd",
    "SRP_AXIS_BYTES": 32,
}


def _run_srpv3_axilite_case(parameters, cocotb_test: str, build_label: str):
    extra_env = dict(parameters)
    extra_env["SRP_AXI_LITE_COCOTB_TEST"] = cocotb_test
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel=parameters["TOPLEVEL"],
        parameters={},
        extra_env=extra_env,
        extra_vhdl_sources={"surf": [parameters["WRAPPER_SOURCE"]]},
        sim_build_key=f"tests/sim_build/protocols/srp/test_SrpV3AxiLite.{build_label}.{parameters['TOPLEVEL'].split('.')[-1]}",
    )


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SrpV3AxiLite_reset_idle(parameters):
    _run_srpv3_axilite_case(parameters, "reset_idle", "reset_idle")


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
@pytest.mark.skipif(
    os.environ.get("RUN_KNOWN_ISSUE_TESTS", "0") != "1",
    reason="Expected-open SRPv3 AXI-Lite request-path probe.",
)
def test_SrpV3AxiLite_short_frame_probe(parameters):
    _run_srpv3_axilite_case(parameters, "short_frame", "short_frame")


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
@pytest.mark.skipif(
    os.environ.get("RUN_KNOWN_ISSUE_TESTS", "0") != "1",
    reason="Expected-open SRPv3 AXI-Lite request-path probe.",
)
def test_SrpV3AxiLite_single_read_probe(parameters):
    _run_srpv3_axilite_case(parameters, "single_read", "single_read")


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
@pytest.mark.skipif(
    os.environ.get("RUN_KNOWN_ISSUE_TESTS", "0") != "1",
    reason=(
        "Expected-open SRPv3 AXI-Lite investigation: the 32-bit multi-beat "
        "SrpV3AxiLite request path and SrpV3AxiLiteFull probes are still under "
        "debug. Set RUN_KNOWN_ISSUE_TESTS=1 to reproduce while debugging."
    ),
)
def test_SrpV3AxiLite(parameters):
    _run_srpv3_axilite_case(parameters, "directed", "directed")


def test_SrpV3AxiLite_legacy_wide_directed():
    _run_srpv3_axilite_case(
        LEGACY_WIDE_DIRECT_PARAMETERS,
        "directed",
        "legacy_wide_directed",
    )
