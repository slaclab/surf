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
# - Sweep: Keep one async-clock checked-in wrapper around `PgpRxVcFifo` so the
#   bench covers the real PGP-to-application CDC path plus the wrapper-visible
#   pause interface.
# - Stimulus: Send good frames with `rxlinkReady=1`, send a frame with
#   `rxlinkReady=0`, and then hold the output side stalled long enough to cross
#   the small wrapper pause threshold.
# - Checks: Good traffic must pass unchanged, link-down traffic must be blown
#   off before it reaches the application side, and the exported pause flag
#   must assert under sustained output backpressure without raising overflow.
# - Timing: The wrapper uses skewed source and sink clocks so the FIFO does
#   real CDC work, and the pause check drives several accepted source beats
#   while the sink is stalled before releasing the output path and draining the
#   buffered data.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test
from tests.protocols.pgp.shared.vc_fifo_test_utils import VcFifoTb


@cocotb.test()
async def pgp_rx_vc_fifo_test(dut):
    tb = VcFifoTb(
        dut,
        source_clk_name="pgpClk",
        source_rst_name="pgpRst",
        sink_clk_name="axisClk",
        sink_rst_name="axisRst",
    )
    await tb.reset(link_signals=("rxlinkReady",))

    tb.start_sink()
    assert tb.sink is not None

    dut.rxlinkReady.value = 1
    await tb.cycle_source(6)

    await tb.send_frame(bytes(range(1, 17)), tdest=1)
    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == bytes(range(1, 17))

    dut.rxlinkReady.value = 0
    await tb.cycle_source(4)
    await tb.send_frame(bytes(range(0x20, 0x30)), tdest=0)
    await tb.expect_no_output_valid(sink_cycles=24)

    dut.rxlinkReady.value = 1
    await tb.cycle_source(4)

    # Stop the sink side so the small wrapper pause threshold can be crossed.
    dut.M_AXIS_TREADY.value = 0
    await tb.send_frame(bytes(range(0x40, 0x48)), tdest=1)
    await tb.send_frame(bytes(range(0x50, 0x58)), tdest=0)
    await tb.send_frame(bytes(range(0x60, 0x68)), tdest=1)

    for _ in range(32):
        if int(dut.pgpRxPause.value) == 1:
            break
        await tb.cycle_source()
    else:
        raise AssertionError("Timed out waiting for pgpRxPause assertion")

    assert int(dut.pgpRxOverflow.value) == 0
    assert int(dut.pgpRxReady.value) in (0, 1)

    # Release the output path and drain the buffered traffic to prove the
    # pause condition is temporary rather than a stuck state.
    dut.M_AXIS_TREADY.value = 1
    drained = [await tb.sink.recv(), await tb.sink.recv(), await tb.sink.recv()]
    assert [frame.tdata for frame in drained] == [
        bytes(range(0x40, 0x48)),
        bytes(range(0x50, 0x58)),
        bytes(range(0x60, 0x68)),
    ]

    for _ in range(64):
        if int(dut.pgpRxPause.value) == 0:
            break
        await tb.cycle_source()
    else:
        raise AssertionError("Timed out waiting for pgpRxPause deassertion")


PARAMETER_SWEEP = [parameter_case("shared_async_wrapper")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_PgpRxVcFifo(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgprxvcfifowrapper",
        wrapper_source="protocols/pgp/shared/wrappers/PgpRxVcFifoWrapper.vhd",
        extra_env=parameters,
    )
