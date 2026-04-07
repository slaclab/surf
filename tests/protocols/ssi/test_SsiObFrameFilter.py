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
# - Sweep: Keep the first pass to one same-clock wrapper configuration with
#   the normal `VALID_THOLD_G=1` path.
# - Stimulus: Drive one well-formed frame and one malformed frame with a
#   repeated `SOF` in the middle.
# - Checks: Good traffic must pass unchanged, and the repeated-`SOF` case must
#   end on the violating beat with `EOFE` asserted and `SOF` cleared.
# - Timing: Keep the first pass in steady streaming mode and capture accepted
#   beats by expected payload value so the bench stays aligned with the filter
#   policy checks instead of overfitting to the downstream pipeline latency.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    SsiBeat,
    cycle,
    env_data_bytes,
    keep_mask,
    reset_dut,
    send_contiguous_frame,
    start_clock,
)


async def recv_expected_beat(sink, dut, expected_data):
    # The curated stimulus uses unique payload words, so wait for the exact
    # word value before sampling the sidebands on the accepted transfer.
    dut.mAxisTReady.value = 1
    for _ in range(64):
        await Timer(2, unit="ns")
        if int(dut.mAxisTValid.value) == 1:
            candidate = sink.snapshot()
            if candidate.data == expected_data:
                await RisingEdge(dut.axisClk)
                await Timer(2, unit="ns")
                return candidate
        await RisingEdge(dut.axisClk)
        await Timer(2, unit="ns")
    raise AssertionError(f"Timed out waiting for SSI output data 0x{expected_data:04x}")


async def expect_no_output_data(sink, dut, forbidden_data, cycles=8):
    for _ in range(cycles):
        await Timer(2, unit="ns")
        if int(dut.mAxisTValid.value) == 1:
            assert sink.snapshot().data != forbidden_data
        await RisingEdge(dut.axisClk)


async def wait_output_clear(dut, max_cycles=8):
    dut.mAxisTReady.value = 1
    for _ in range(max_cycles):
        await Timer(2, unit="ns")
        if int(dut.mAxisTValid.value) == 0:
            dut.mAxisTReady.value = 0
            return
        await RisingEdge(dut.axisClk)
    dut.mAxisTReady.value = 0
    raise AssertionError("Timed out waiting for SSI output to clear")


@cocotb.test()
async def ssi_ob_frame_filter_test(dut):
    data_bytes = env_data_bytes(default=2)
    keep = keep_mask(data_bytes)

    start_clock(dut.axisClk, period_ns=5.0)

    source = FlatSsiEndpoint(dut, prefix="sAxis")
    sink = FlatSsiEndpoint(dut, prefix="mAxis")

    dut.axisRst.setimmediatevalue(1)
    source.set_idle()
    dut.sTLastEofe.setimmediatevalue(0)
    dut.mAxisTReady.setimmediatevalue(0)
    await reset_dut(dut)

    valid_task = cocotb.start_soon(
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
    assert first.data == 0x1111
    assert first.keep == keep
    assert first.last == 0
    assert first.dest == 0x2
    assert first.sof == 1
    assert first.eofe == 0

    dut.mAxisTReady.value = 1
    await RisingEdge(dut.axisClk)
    await Timer(2, unit="ns")
    second = await recv_expected_beat(sink, dut, 0x2222)
    dut.mAxisTReady.value = 0
    await valid_task

    frame = [first, second]

    assert [beat.data for beat in frame] == [0x1111, 0x2222]
    assert [beat.keep for beat in frame] == [keep, keep]
    assert [beat.last for beat in frame] == [0, 1]
    assert [beat.dest for beat in frame] == [0x2, 0x2]
    assert [beat.sof for beat in frame] == [1, 0]
    assert [beat.eofe for beat in frame] == [0, 0]
    await wait_output_clear(dut)

    malformed_task = cocotb.start_soon(
        send_contiguous_frame(
            source,
            [
                SsiBeat(data=0x3333, keep=keep, last=0, dest=0x1, sof=1),
                SsiBeat(data=0x4444, keep=keep, last=0, dest=0x1, sof=1),
                SsiBeat(data=0x5555, keep=keep, last=1, dest=0x1),
            ],
            clk=dut.axisClk,
        )
    )

    first = await sink.wait_valid(clk=dut.axisClk)
    assert first.data == 0x3333
    assert first.keep == keep
    assert first.last == 0
    assert first.dest == 0x1
    assert first.sof == 1
    assert first.eofe == 0

    dut.mAxisTReady.value = 1
    await RisingEdge(dut.axisClk)
    await Timer(2, unit="ns")
    second = await recv_expected_beat(sink, dut, 0x4444)
    dut.mAxisTReady.value = 0
    await malformed_task

    frame = [first, second]

    assert [beat.data for beat in frame] == [0x3333, 0x4444]
    assert [beat.last for beat in frame] == [0, 1]
    assert [beat.dest for beat in frame] == [0x1, 0x1]
    assert [beat.sof for beat in frame] == [1, 0]
    assert [beat.eofe for beat in frame] == [0, 1]
    await expect_no_output_data(sink, dut, 0x5555)
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
