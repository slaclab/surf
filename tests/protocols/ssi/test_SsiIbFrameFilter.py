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
# - Sweep: Keep the narrow first pass to one same-clock, `SLAVE_READY_EN_G`
#   enabled configuration.
# - Stimulus: Drive one valid frame, one missing-SOF frame, and one frame that
#   changes `TDEST` mid-packet.
# - Checks: Valid frames must pass with metadata intact, missing-SOF traffic
#   must be dropped completely, and the `TDEST` violation must terminate the
#   visible output frame with `EOFE` asserted on the terminating beat.
# - Timing: The sink is deliberately held not-ready on the first visible beat
#   of each accepted frame so the wrapper contract proves that the DUT exposes
#   stable SSI-side outputs before the beat is consumed.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import (
    FlatSsiEndpoint,
    SsiBeat,
    env_data_bytes,
    expect_no_output,
    keep_mask,
    reset_dut,
    send_frame,
    start_clock,
)


@cocotb.test()
async def ssi_ib_frame_filter_test(dut):
    data_bytes = env_data_bytes(default=2)
    keep = keep_mask(data_bytes)

    start_clock(dut.axisClk, period_ns=5.0)

    source = FlatSsiEndpoint(dut, prefix="sAxis")
    sink = FlatSsiEndpoint(dut, prefix="mAxis")

    source.set_idle()
    dut.mAxisTReady.setimmediatevalue(0)
    await reset_dut(dut)

    valid_task = cocotb.start_soon(
        send_frame(
            source,
            [
                SsiBeat(data=0x1111, keep=keep, last=0, dest=0x4, sof=1),
                SsiBeat(data=0x2222, keep=keep, last=1, dest=0x4),
            ],
            clk=dut.axisClk,
        )
    )

    first = await sink.wait_valid(clk=dut.axisClk)
    assert first.data == 0x1111
    assert first.sof == 1
    assert first.eofe == 0

    frame = [
        await sink.recv(clk=dut.axisClk, ready_signal=dut.mAxisTReady, keep_ready=True),
        await sink.recv(clk=dut.axisClk, ready_signal=dut.mAxisTReady, keep_ready=True),
    ]
    dut.mAxisTReady.value = 0
    await valid_task

    assert [beat.data for beat in frame] == [0x1111, 0x2222]
    assert [beat.dest for beat in frame] == [0x4, 0x4]
    assert [beat.sof for beat in frame] == [1, 0]
    assert [beat.eofe for beat in frame] == [0, 0]
    assert int(dut.sAxisDropWord.value) == 0
    assert int(dut.sAxisDropFrame.value) == 0

    await send_frame(
        source,
        [
            SsiBeat(data=0x3333, keep=keep, last=0, dest=0x1, sof=0),
            SsiBeat(data=0x4444, keep=keep, last=1, dest=0x1),
        ],
        clk=dut.axisClk,
    )
    await expect_no_output(sink, clk=dut.axisClk)

    malformed_task = cocotb.start_soon(
        send_frame(
            source,
            [
                SsiBeat(data=0x5555, keep=keep, last=0, dest=0x2, sof=1),
                SsiBeat(data=0x6666, keep=keep, last=0, dest=0x3),
                SsiBeat(data=0x7777, keep=keep, last=1, dest=0x3),
            ],
            clk=dut.axisClk,
        )
    )

    first = await sink.wait_valid(clk=dut.axisClk)
    assert first.data == 0x5555
    assert first.sof == 1
    assert first.eofe == 0

    frame = [
        await sink.recv(clk=dut.axisClk, ready_signal=dut.mAxisTReady, keep_ready=True),
        await sink.recv(clk=dut.axisClk, ready_signal=dut.mAxisTReady, keep_ready=True),
    ]
    dut.mAxisTReady.value = 0
    await malformed_task

    assert [beat.data for beat in frame] == [0x5555, 0x6666]
    assert [beat.last for beat in frame] == [0, 1]
    assert [beat.dest for beat in frame] == [0x2, 0x3]
    assert [beat.sof for beat in frame] == [1, 0]
    assert [beat.eofe for beat in frame] == [0, 1]
    await expect_no_output(sink, clk=dut.axisClk)


PARAMETER_SWEEP = [
    parameter_case(
        "default_configuration",
        DATA_BYTES_G="2",
        SLAVE_READY_EN_G="true",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiIbFrameFilter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiibframefilterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiIbFrameFilterWrapper.vhd"]},
    )
