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
#   bypass, explicit user-header insertion, and a wider direct-path bypass
#   configuration.  All cases use TUSER_MASK_G=0 (no masking).
# - Stimulus: Drive short AXI-stream payloads beat by beat, stall the sink on
#   the first visible beat, and vary `mUserHdr` plus the wrapper width/FIFO
#   mode so the checks stay on the wrapper-facing contract instead of
#   re-proving FIFO internals.
# - Checks: The first emitted beat must always assert `SOF`, later payload
#   beats must clear `SOF`, optional header insertion must prepend exactly one
#   header beat, and the direct-path cases must preserve the inbound `EOFE`
#   markers while leaving the inserted `SOF` semantics intact.
# - Timing: The bench samples the first visible beat while stalled and then
#   consumes accepted transfers one beat at a time so output stability under
#   backpressure is part of the regression contract.

import cocotb
import pytest

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    assert_beat_view,
    cycle,
    env_data_bytes,
    keep_mask,
    recv_expected_beat,
    send_contiguous_frame,
    setup_flat_ssi_testbench,
    SsiBeat,
    wait_output_clear,
)


@cocotb.test()
async def ssi_insert_sof_test(dut):
    data_bytes = env_data_bytes(default=2)
    insert_user_header = env_flag("INSERT_USER_HDR_G", default=False)
    keep = keep_mask(data_bytes)

    # The wrapper turns SSI-specific SOF policy into flat ports that the test
    # can drive directly, so set up one source and one sink endpoint first.
    bench = await setup_flat_ssi_testbench(
        dut,
        period_ns=5.0,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={"mUserHdr": 0, "mAxisTReady": 0},
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    # The wrapper can either insert a new header beat or simply force `SOF` on
    # the first payload beat, depending on the generic under test.
    dut.mUserHdr.value = 0xBBAA

    if insert_user_header:
        # Run the source in the background so the test can first observe the
        # inserted header beat while the sink is still stalled.
        payload_send = cocotb.start_soon(
            source.send(
                SsiBeat(data=0x2211, keep=keep, last=1, dest=0x5, sof=0, eofe=1),
                clk=bench.clk,
            )
        )

        header = await sink.wait_valid(clk=bench.clk)
        held_header = sink.snapshot()
        assert held_header == header
        # Once the header is confirmed stable, accept the payload beat and
        # check that the original `EOFE` survives behind the new header.
        payload = await recv_expected_beat(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, expected_data=0x2211)
        await payload_send

        assert_beat_view(
            header,
            fields=("data", "keep", "last", "dest", "sof", "eofe"),
            expected=(0xBBAA, keep, 0, 0x5, 1, 0),
        )
        assert_beat_view(
            payload,
            fields=("data", "keep", "last", "dest", "sof", "eofe"),
            expected=(0x2211, keep, 1, 0x5, 0, 1),
        )
        await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)
    else:
        # In direct mode the wrapper should leave the payload ordering alone,
        # but it must still assert `SOF` on the first outgoing beat.
        frame_send = cocotb.start_soon(
            send_contiguous_frame(
                source,
                [
                    SsiBeat(data=0x2211, keep=keep, last=0, dest=0x5, sof=0, eofe=1),
                    SsiBeat(data=0x4433, keep=keep, last=1, dest=0x5, sof=0, eofe=1),
                ],
                clk=bench.clk,
            )
        )
        first = await sink.wait_valid(clk=bench.clk)
        held_first = sink.snapshot()
        assert held_first == first
        # Accept the final beat only after verifying the first beat stayed
        # stable while `TREADY` was low.
        second = await recv_expected_beat(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, expected_data=0x4433)
        await frame_send

        assert_beat_view(
            first,
            fields=("data", "keep", "last", "dest", "sof", "eofe"),
            expected=(0x2211, keep, 0, 0x5, 1, 1),
        )
        assert_beat_view(
            second,
            fields=("data", "keep", "last", "dest", "sof", "eofe"),
            expected=(0x4433, keep, 1, 0x5, 0, 1),
        )
        await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)

    # End with a short idle check so the wrapper proves it flushed the frame
    # cleanly.
    await cycle(bench.clk, 2)
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
