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
# - Sweep: Exercise the narrow multi-beat frame-preservation regression through
#   both common-clock `SsiFrameLimiter` ingress modes: the slave FIFO path and
#   the bypass path.
# - Stimulus: Drive the five-beat 32-bit SSI frame shape that the SRPv3
#   AXI-Lite wrapper depends on, with `SOF` only on the first beat and `TLAST`
#   only on the final beat.
# - Checks: The limiter must preserve beat count, payload, `SOF`, `TLAST`,
#   `EOFE`, and `TDEST` exactly in both topologies.
# - Timing: The sink capture is whole-frame and bounded, so the checks do not
#   depend on any fixed internal latency or specific ready polarity.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    assert_beat_list,
    keep_mask,
    recv_frame,
    SsiBeat,
    send_contiguous_frame,
    setup_flat_ssi_testbench,
    wait_output_clear,
)


@cocotb.test()
async def preserves_multi_beat_shape(dut):
    keep = keep_mask(4)

    bench = await setup_flat_ssi_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={"mAxisTReady": 0},
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    expected = [
        SsiBeat(data=0x0000_0003, keep=keep, last=0, dest=0x3, sof=1, eofe=0),
        SsiBeat(data=0x5100_0200, keep=keep, last=0, dest=0x3, sof=0, eofe=0),
        SsiBeat(data=0x0000_0020, keep=keep, last=0, dest=0x3, sof=0, eofe=0),
        SsiBeat(data=0x0000_0000, keep=keep, last=0, dest=0x3, sof=0, eofe=0),
        SsiBeat(data=0x0000_0000, keep=keep, last=1, dest=0x3, sof=0, eofe=0),
    ]
    send_task = cocotb.start_soon(send_contiguous_frame(source, expected, clk=bench.clk))
    frame = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=64,
    )
    await send_task
    assert_beat_list(frame, expected)
    await wait_output_clear(sink, clk=bench.clk, ready_signal=dut.mAxisTReady)


PARAMETER_SWEEP = [
    pytest.param(
        {
            "DATA_BYTES_G": "4",
            "FRAME_LIMIT_G": "8",
            "EN_TIMEOUT_G": "false",
            "SLAVE_FIFO_G": "true",
            "MASTER_FIFO_G": "false",
        },
        id="fifo_preserve",
    ),
    pytest.param(
        {
            "DATA_BYTES_G": "4",
            "FRAME_LIMIT_G": "8",
            "EN_TIMEOUT_G": "false",
            "SLAVE_FIFO_G": "false",
            "MASTER_FIFO_G": "false",
        },
        id="bypass_preserve",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiFrameLimiterPreserve(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiframelimiterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiFrameLimiterWrapper.vhd"]},
    )
