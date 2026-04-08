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
# - Sweep: Cover two same-clock wrapper configurations: the normal
#   `VALID_THOLD_G=1` path and the cached-last-user `VALID_THOLD_G=0` path.
# - Stimulus: Drive one well-formed frame, one missing-SOF frame, one
#   interleaved-`TDEST` frame, one repeated-`SOF` frame, and one cached-EOFE
#   frame through the flat SSI wrapper contract.
# - Checks: Good traffic must pass unchanged, missing-SOF traffic must be
#   dropped, `TDEST` and repeated-`SOF` violations must terminate on the
#   violating beat with `EOFE`, and the cached-EOFE path must drop the frame
#   before any output becomes visible.
# - Timing: The bench samples the first visible beat while the sink is stalled,
#   then consumes the frame one accepted transfer at a time so the checks stay
#   aligned with wrapper-visible framing policy instead of fixed latency.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    cycle,
    env_data_bytes,
    env_int,
    expect_no_output,
    FlatSsiEndpoint,
    reset_dut,
    send_contiguous_frame,
    SsiBeat,
    start_clock,
)


async def wait_output_clear(dut, *, cycles: int = 16):
    dut.mAxisTReady.value = 1
    for _ in range(cycles):
        await cycle(dut.axisClk)
        if int(dut.mAxisTValid.value) == 0:
            dut.mAxisTReady.value = 0
            return
    dut.mAxisTReady.value = 0
    raise AssertionError("Timed out waiting for SSI output to clear")


async def recv_expected_beat(sink, dut, expected_data):
    dut.mAxisTReady.value = 1
    for _ in range(64):
        await Timer(2, unit="ns")
        if int(dut.mAxisTValid.value) == 1:
            candidate = sink.snapshot()
            if candidate.data == expected_data:
                await RisingEdge(dut.axisClk)
                await Timer(2, unit="ns")
                dut.mAxisTReady.value = 0
                return candidate
        await RisingEdge(dut.axisClk)
        await Timer(2, unit="ns")
    dut.mAxisTReady.value = 0
    raise AssertionError(f"Timed out waiting for SSI output data 0x{expected_data:04x}")


async def expect_no_output_data(sink, dut, forbidden_data, cycles=8):
    for _ in range(cycles):
        await Timer(2, unit="ns")
        if int(dut.mAxisTValid.value) == 1:
            assert sink.snapshot().data != forbidden_data
        await RisingEdge(dut.axisClk)


@cocotb.test()
async def ssi_ob_frame_filter_test(dut):
    data_bytes = env_data_bytes(default=2)
    valid_thold = env_int("VALID_THOLD_G", default=1)
    keep = (1 << data_bytes) - 1

    start_clock(dut.axisClk, period_ns=5.0)

    source = FlatSsiEndpoint(dut, prefix="sAxis")
    sink = FlatSsiEndpoint(dut, prefix="mAxis")

    dut.axisRst.setimmediatevalue(1)
    source.set_idle()
    dut.sTLastEofe.setimmediatevalue(0)
    dut.mAxisTReady.setimmediatevalue(0)
    await reset_dut(dut)

    good_send = cocotb.start_soon(
        send_contiguous_frame(
            source,
            [
                SsiBeat(data=0x1111, keep=keep, last=0, dest=0x2, sof=1),
                SsiBeat(data=0x2222, keep=keep, last=1, dest=0x2),
            ],
            clk=dut.axisClk,
        )
    )
    first = await sink.wait_valid(clk=dut.axisClk)
    assert (first.data, first.keep, first.last, first.dest, first.sof, first.eofe) == (0x1111, keep, 0, 0x2, 1, 0)
    second = await recv_expected_beat(sink, dut, 0x2222)
    await good_send
    assert (second.data, second.keep, second.last, second.dest, second.sof, second.eofe) == (0x2222, keep, 1, 0x2, 0, 0)
    await wait_output_clear(dut)

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x3001, keep=keep, last=0, dest=0x1),
            SsiBeat(data=0x3002, keep=keep, last=1, dest=0x1),
        ],
        clk=dut.axisClk,
    )
    await expect_no_output(sink, clk=dut.axisClk)

    if valid_thold == 0:
        dut.sTLastEofe.value = 1
        await send_contiguous_frame(
            source,
            [
                SsiBeat(data=0x4001, keep=keep, last=1, dest=0x3, sof=1),
            ],
            clk=dut.axisClk,
        )
        dut.sTLastEofe.value = 0
        await expect_no_output(sink, clk=dut.axisClk)
    else:
        tdest_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x5001, keep=keep, last=0, dest=0x4, sof=1),
                    SsiBeat(data=0x5002, keep=keep, last=0, dest=0x5),
                    SsiBeat(data=0x5003, keep=keep, last=1, dest=0x5),
                ],
                clk=dut.axisClk,
            )
        )
        first = await sink.wait_valid(clk=dut.axisClk)
        second = await recv_expected_beat(sink, dut, 0x5002)
        await tdest_send
        assert (first.data, first.last, first.dest, first.sof, first.eofe) == (0x5001, 0, 0x4, 1, 0)
        assert (second.data, second.last, second.dest, second.sof, second.eofe) == (0x5002, 1, 0x5, 0, 1)
        await expect_no_output_data(sink, dut, 0x5003)
        await wait_output_clear(dut)

        repeated_sof_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x6001, keep=keep, last=0, dest=0x6, sof=1),
                    SsiBeat(data=0x6002, keep=keep, last=0, dest=0x6, sof=1),
                    SsiBeat(data=0x6003, keep=keep, last=1, dest=0x6),
                ],
                clk=dut.axisClk,
            )
        )
        first = await sink.wait_valid(clk=dut.axisClk)
        second = await recv_expected_beat(sink, dut, 0x6002)
        await repeated_sof_send
        assert (first.data, first.last, first.dest, first.sof, first.eofe) == (0x6001, 0, 0x6, 1, 0)
        assert (second.data, second.last, second.dest, second.sof, second.eofe) == (0x6002, 1, 0x6, 0, 1)
        await expect_no_output_data(sink, dut, 0x6003)
        await wait_output_clear(dut)

    await cycle(dut.axisClk, 2)
    assert int(dut.mAxisTValid.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "default_configuration",
        DATA_BYTES_G="2",
        VALID_THOLD_G="1",
        PIPE_STAGES_G="0",
    ),
    parameter_case(
        "cached_last_user_path",
        DATA_BYTES_G="2",
        VALID_THOLD_G="0",
        PIPE_STAGES_G="0",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiObFrameFilter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiobframefilterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiObFrameFilterWrapper.vhd"]},
    )
