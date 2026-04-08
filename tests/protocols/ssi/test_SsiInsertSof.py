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
# - Sweep: Cover a curated three-case wrapper matrix across true same-clock
#   bypass, explicit user-header insertion, and a direct-path user-mask case
#   that clears inbound `EOFE`.
# - Stimulus: Drive short AXI-stream payloads beat by beat, stall the sink on
#   the first visible beat, and vary `mUserHdr` plus the user mask so the
#   checks stay on the wrapper-facing contract instead of re-proving FIFO
#   internals.
# - Checks: The first emitted beat must always assert `SOF`, later payload
#   beats must clear `SOF`, optional header insertion must prepend exactly one
#   header beat, and the mask case must clear inbound `EOFE` while leaving the
#   inserted `SOF` semantics intact.
# - Timing: The bench samples the first visible beat while stalled and then
#   consumes accepted transfers one beat at a time so output stability under
#   backpressure is part of the regression contract.

import cocotb
import pytest

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    cycle,
    env_data_bytes,
    FlatSsiEndpoint,
    keep_mask,
    recv_expected_beat,
    reset_dut,
    send_contiguous_frame,
    SsiBeat,
    start_clock,
    wait_output_clear,
)


@cocotb.test()
async def ssi_insert_sof_test(dut):
    data_bytes = env_data_bytes(default=2)
    insert_user_header = env_flag("INSERT_USER_HDR_G", default=False)
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

    if insert_user_header:
        payload_send = cocotb.start_soon(
            source.send(
                SsiBeat(data=0x2211, keep=keep, last=1, dest=0x5, sof=0, eofe=1),
                clk=dut.axisClk,
            )
        )

        header = await sink.wait_valid(clk=dut.axisClk)
        held_header = sink.snapshot()
        assert held_header == header
        payload = await recv_expected_beat(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady, expected_data=0x2211)
        await payload_send

        assert (header.data, header.keep, header.last, header.dest, header.sof, header.eofe) == (0xBBAA, keep, 0, 0x5, 1, 0)
        assert (payload.data, payload.keep, payload.last, payload.dest, payload.sof, payload.eofe) == (0x2211, keep, 1, 0x5, 0, 1)
        await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)
    else:
        frame_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x2211, keep=keep, last=0, dest=0x5, sof=0, eofe=1),
                    SsiBeat(data=0x4433, keep=keep, last=1, dest=0x5, sof=0, eofe=1),
                ],
                clk=dut.axisClk,
            )
        )
        first = await sink.wait_valid(clk=dut.axisClk)
        held_first = sink.snapshot()
        assert held_first == first
        second = await recv_expected_beat(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady, expected_data=0x4433)
        await frame_send

        assert (first.data, first.keep, first.last, first.dest, first.sof, first.eofe) == (0x2211, keep, 0, 0x5, 1, 1)
        assert (second.data, second.keep, second.last, second.dest, second.sof, second.eofe) == (0x4433, keep, 1, 0x5, 0, 1)
        await wait_output_clear(sink, clk=dut.axisClk, ready_signal=dut.mAxisTReady)

    await cycle(dut.axisClk, 2)
    assert int(dut.mAxisTValid.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "direct_bypass",
        DATA_BYTES_G="2",
        TUSER_BITS_G="2",
        INSERT_USER_HDR_G="false",
        COMMON_CLK_G="true",
        SLAVE_FIFO_G="false",
        MASTER_FIFO_G="false",
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
        "direct_bypass_wide",
        DATA_BYTES_G="4",
        TUSER_BITS_G="2",
        INSERT_USER_HDR_G="false",
        COMMON_CLK_G="true",
        SLAVE_FIFO_G="false",
        MASTER_FIFO_G="false",
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
