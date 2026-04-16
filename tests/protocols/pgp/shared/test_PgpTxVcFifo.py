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
# - Sweep: Keep one async-clock checked-in wrapper around `PgpTxVcFifo` so the
#   bench exercises the real application-to-PGP CDC path plus the link-driven
#   flush logic.
# - Stimulus: Send good frames with both link-ready inputs asserted, send a
#   frame while both link-ready inputs are deasserted, and then drop link-ready
#   mid-frame during a longer transfer.
# - Checks: Good traffic must pass unchanged, link-down traffic must never
#   become visible at the PGP-side output, and a mid-frame link drop must
#   terminate the transmitted frame early instead of letting the original full
#   payload leak through.
# - Timing: The wrapper uses skewed source and sink clocks so the FIFO runs as
#   a real CDC bridge, and the link-drop test changes readiness immediately
#   after an accepted source beat so the flush path is exercised in flight.

import cocotb
import pytest

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test
from tests.protocols.pgp.shared.vc_fifo_test_utils import VcFifoTb


@cocotb.test()
async def pgp_tx_vc_fifo_test(dut):
    tb = VcFifoTb(
        dut,
        source_clk_name="axisClk",
        source_rst_name="axisRst",
        sink_clk_name="pgpClk",
        sink_rst_name="pgpRst",
    )
    await tb.reset(link_signals=("rxlinkReady", "txlinkReady"))

    tb.start_sink()
    assert tb.sink is not None

    dut.rxlinkReady.value = 1
    dut.txlinkReady.value = 1
    await tb.cycle_source(6)

    await tb.send_frame(bytes(range(1, 17)), tdest=1)
    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == bytes(range(1, 17))

    await tb.send_frame(bytes(range(0x21, 0x31)), tdest=0)
    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == bytes(range(0x21, 0x31))

    dut.rxlinkReady.value = 0
    dut.txlinkReady.value = 0
    await tb.cycle_source(6)
    await tb.send_frame(bytes(range(0x40, 0x50)), tdest=1)
    await tb.expect_no_output_valid(sink_cycles=24)

    dut.rxlinkReady.value = 1
    dut.txlinkReady.value = 1
    await tb.cycle_source(6)

    async def drop_link_after_first_beat(index: int):
        if index == 0:
            dut.rxlinkReady.value = 0
            dut.txlinkReady.value = 0

    payload = bytes(range(0x60, 0x90))
    await tb.send_frame(payload, tdest=1, on_handshake=drop_link_after_first_beat)
    leaked_frames = [await tb.sink.recv()]
    await tb.cycle_sink(24)
    while not tb.sink.empty():
        leaked_frames.append(await tb.sink.recv())

    leaked_payload = b"".join(frame.tdata for frame in leaked_frames)
    assert 0 < len(leaked_payload) < len(payload)
    assert leaked_payload == payload[: len(leaked_payload)]


PARAMETER_SWEEP = [parameter_case("shared_async_wrapper")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_PgpTxVcFifo(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgptxvcfifowrapper",
        wrapper_source="protocols/pgp/shared/wrappers/PgpTxVcFifoWrapper.vhd",
        extra_env=parameters,
    )
