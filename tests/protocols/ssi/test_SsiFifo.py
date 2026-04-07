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
# - Sweep: Keep the first checked-in pass to one same-clock, equal-width FIFO
#   configuration with the stable `VALID_THOLD_G=1` path.
# - Stimulus: Drive one good single-beat frame and one missing-SOF frame.
# - Checks: The valid frame must emerge intact, and the missing-SOF frame must
#   not emerge.
# - Timing: Keep the first pass in steady streaming mode so the checked-in
#   regression proves the combined filter-plus-FIFO data path before adding
#   deeper buffering or threshold-specific cases.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    SsiBeat,
    cycle,
    env_data_bytes,
    expect_no_output,
    keep_mask,
    reset_dut,
    send_contiguous_frame,
    start_clock,
)


async def wait_count_zero(signal, clk, cycles=64):
    for _ in range(cycles):
        await cycle(clk)
        if int(signal.value) == 0:
            return
    raise AssertionError("Timed out waiting for fifoWrCnt to return to zero")


async def recv_expected_beat(sink, dut, expected_data):
    dut.mAxisTReady.value = 1
    last_seen = None
    for _ in range(64):
        await cycle(dut.axisClk)
        if int(dut.mAxisTValid.value) == 1:
            beat = sink.snapshot()
            last_seen = beat
            if beat.data == expected_data:
                return beat
    raise AssertionError(f"Timed out waiting for SSI output data 0x{expected_data:04x}, last_seen={last_seen}")


async def wait_output_clear(dut, cycles=16):
    dut.mAxisTReady.value = 1
    for _ in range(cycles):
        await cycle(dut.axisClk)
        if int(dut.mAxisTValid.value) == 0:
            dut.mAxisTReady.value = 0
            return
    dut.mAxisTReady.value = 0
    raise AssertionError("Timed out waiting for SSI output to clear")


@cocotb.test()
async def ssi_fifo_test(dut):
    data_bytes = env_data_bytes(default=2)
    keep = keep_mask(data_bytes)

    start_clock(dut.axisClk, period_ns=5.0)

    source = FlatSsiEndpoint(dut, prefix="sAxis")
    sink = FlatSsiEndpoint(dut, prefix="mAxis")

    dut.axisRst.setimmediatevalue(1)
    source.set_idle()
    dut.fifoPauseThresh.setimmediatevalue(3)
    dut.mAxisTReady.setimmediatevalue(1)
    await reset_dut(dut)

    await send_contiguous_frame(
        source,
        [SsiBeat(data=0x1111, keep=keep, last=1, dest=0x2, sof=1)],
        clk=dut.axisClk,
    )

    beat = await recv_expected_beat(sink, dut, 0x1111)
    dut.mAxisTReady.value = 0

    assert beat.data == 0x1111
    assert beat.keep == keep
    assert beat.last == 1
    assert beat.dest == 0x2
    assert beat.sof == 1
    assert beat.eofe == 0
    await wait_count_zero(dut.fifoWrCnt, dut.axisClk)
    await wait_output_clear(dut)
    assert int(dut.lockupRstEvent.value) == 0

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x3333, keep=keep, last=0, dest=0x1),
            SsiBeat(data=0x4444, keep=keep, last=1, dest=0x1),
        ],
        clk=dut.axisClk,
    )
    await expect_no_output(sink, clk=dut.axisClk)
    await wait_count_zero(dut.fifoWrCnt, dut.axisClk)
    assert int(dut.lockupRstEvent.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "default_configuration",
        DATA_BYTES_G="2",
        FIFO_ADDR_WIDTH_G="4",
        SLAVE_READY_EN_G="true",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiFifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssififowrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiFifoWrapper.vhd"]},
    )
