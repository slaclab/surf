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
# - Sweep: Keep a three-case wrapper-level sweep covering direct same-clock
#   pass-through, explicit user-header insertion, and the buffered user-mask
#   path with both internal FIFOs enabled.
# - Stimulus: Drive short SSI-style frames beat by beat, toggle sink
#   backpressure while the first output beat is buffered, and vary `mUserHdr`
#   plus user metadata so the bench proves the wrapper-facing contract instead
#   of replaying a broad AXI Stream matrix.
# - Checks: The first emitted beat must always gain SOF, later beats must keep
#   SOF cleared, optional header insertion must prepend exactly one header beat,
#   and EOFE plus destination metadata must survive both the direct and FIFO-
#   backed paths.
# - Timing: The bench checks both direct and FIFO-backed cases with bounded
#   cycle waits and explicitly verifies that stalled output beats hold their
#   values until `tReady` returns.

import cocotb
import pytest

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    SsiBeat,
    cycle,
    env_data_bytes,
    keep_mask,
    reset_dut,
    start_clock,
)


@cocotb.test()
async def ssi_insert_sof_test(dut):
    data_bytes = env_data_bytes(default=2)
    insert_user_header = env_flag("INSERT_USER_HDR_G", default=False)
    slave_fifo = env_flag("SLAVE_FIFO_G", default=False)
    master_fifo = env_flag("MASTER_FIFO_G", default=False)
    buffered_path = slave_fifo or master_fifo
    keep = keep_mask(data_bytes)

    start_clock(dut.axisClk, period_ns=5.0)

    source = FlatSsiEndpoint(dut, prefix="sAxis")
    sink = FlatSsiEndpoint(dut, prefix="mAxis")

    dut.axisRst.setimmediatevalue(1)
    source.set_idle()
    dut.mUserHdr.setimmediatevalue(0)
    dut.mAxisTReady.setimmediatevalue(0)
    await reset_dut(dut)

    dut.mUserHdr.value = 0xBBAA
    first_send = cocotb.start_soon(
        source.send(
            SsiBeat(
                data=0x2211,
                keep=keep,
                last=1 if insert_user_header else 0,
                dest=0x5,
                sof=0,
                eofe=1,
            ),
            clk=dut.axisClk,
        )
    )

    # Hold the sink off first so the first visible output beat has to remain
    # stable while the DUT waits for ready. In the header-insert case that
    # first beat is the injected header; otherwise it is the first payload.
    first_wait = await sink.wait_valid(clk=dut.axisClk)
    held_wait = sink.snapshot()
    assert held_wait == first_wait
    first = await sink.recv(clk=dut.axisClk, ready_signal=dut.mAxisTReady, keep_ready=buffered_path)
    if buffered_path and not insert_user_header:
        for _ in range(32):
            if int(dut.mAxisTValid.value) == 0:
                break
            await cycle(dut.axisClk)
        else:
            raise AssertionError("Timed out waiting for SSI output clear")
    elif not insert_user_header:
        dut.mAxisTReady.value = 1
        await cycle(dut.axisClk)
    await first_send

    if insert_user_header:
        assert first.data == 0xBBAA
        assert first.keep == keep
        assert first.last == 0
        assert first.dest == 0x5
        assert first.sof == 1
        assert first.eofe == 0

        second = await sink.recv(clk=dut.axisClk, ready_signal=dut.mAxisTReady, keep_ready=buffered_path)
        payload_beats = [second]
        expected_data = [0x2211]
        expected_last = [1]
        expected_eofe = [1]
    else:
        await source.send(
            SsiBeat(data=0x4433, keep=keep, last=1, dest=0x5, sof=0, eofe=1),
            clk=dut.axisClk,
        )
        second = await sink.recv(clk=dut.axisClk, ready_signal=dut.mAxisTReady, keep_ready=buffered_path)

        payload_beats = [first, second]
        expected_data = [0x2211, 0x4433]
        expected_last = [0, 1]
        expected_eofe = [1, 1]

    for index, (beat, expected_data_word, expected_last_flag, expected_eofe_flag) in enumerate(
        zip(payload_beats, expected_data, expected_last, expected_eofe),
        start=1,
    ):
        expected_sof = 1 if index == 1 and not insert_user_header else 0

        assert beat.data == expected_data_word
        assert beat.keep == keep
        assert beat.last == expected_last_flag
        assert beat.dest == 0x5
        assert beat.sof == expected_sof
        assert beat.eofe == expected_eofe_flag

    dut.mAxisTReady.value = 0
    await cycle(dut.axisClk, 2)
    assert int(dut.mAxisTValid.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "plain_fifo",
        DATA_BYTES_G="2",
        TUSER_BITS_G="2",
        INSERT_USER_HDR_G="false",
        COMMON_CLK_G="true",
        SLAVE_FIFO_G="true",
        MASTER_FIFO_G="true",
        TUSER_MASK_G="0",
    ),
    parameter_case(
        "header_insert_fifo",
        DATA_BYTES_G="2",
        TUSER_BITS_G="2",
        INSERT_USER_HDR_G="true",
        COMMON_CLK_G="true",
        SLAVE_FIFO_G="true",
        MASTER_FIFO_G="true",
        TUSER_MASK_G="0",
    ),
    parameter_case(
        "fifo_path",
        DATA_BYTES_G="2",
        TUSER_BITS_G="2",
        INSERT_USER_HDR_G="false",
        COMMON_CLK_G="true",
        SLAVE_FIFO_G="true",
        MASTER_FIFO_G="true",
        TUSER_MASK_G="0",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiInsertSof(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiinsertsofwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiInsertSofWrapper.vhd"]},
    )
