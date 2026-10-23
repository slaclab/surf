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
# - Sweep: Keep one single-VC `Pgp2fcLane` loopback wrapper instance and inject
#   one FC request into a quiescent link and into a link carrying AXIS traffic.
# - Stimulus: Calibrate `TX_FC_VALID -> RX_FC_VALID` once after link-up, then
#   repeat that measurement while a long frame is being looped back.
# - Checks: The FC word must survive the full lane loop, and the measured
#   end-to-end latency must remain identical even with user traffic active.
# - Timing: All measurements are made in clock cycles on the shared wrapper
#   clock domain, with bounded waits for the TX request and RX decode events.

import cocotb
from cocotbext.axi import AxiStreamFrame
from cocotb.triggers import RisingEdge

from tests.protocols.pgp.pgp2_test_utils import signal_int
from tests.protocols.pgp.pgp_test_utils import PgpLoopbackTB, incrementing_payload, pgp_family_sources, run_pgp_wrapper_test


async def measure_lane_fc_latency(tb: PgpLoopbackTB, *, fc_word: int):
    tb.dut.TX_FC_WORD.value = fc_word
    tb.dut.TX_FC_VALID.value = 1

    latency = None
    for cycle in range(1, 64):
        await RisingEdge(tb.dut.AXIS_ACLK)
        if cycle == 1:
            tb.dut.TX_FC_VALID.value = 0
        if signal_int(tb.dut, "RX_FC_VALID") == 1:
            latency = cycle
            break

    if latency is None:
        raise AssertionError("Timed out waiting for RX_FC_VALID")

    assert signal_int(tb.dut, "RX_FC_WORD") == fc_word
    return latency


@cocotb.test()
async def pgp2fc_lane_fc_latency_test(dut):
    tb = PgpLoopbackTB(dut)
    await tb.reset_and_wait_for_link()

    dut.TX_FC_VALID.value = 0
    dut.TX_FC_WORD.value = 0

    reference_latency = await measure_lane_fc_latency(tb, fc_word=0x4444)

    payload = incrementing_payload(64)
    send_task = cocotb.start_soon(tb.source.send(AxiStreamFrame(payload)))

    for _ in range(8):
        await RisingEdge(dut.AXIS_ACLK)

    active_latency = await measure_lane_fc_latency(tb, fc_word=0x5555)
    await send_task

    rx_frame = await tb.sink.recv()
    if rx_frame.tdata != payload:
        assert len(rx_frame.tdata) >= len(payload)
        assert rx_frame.tdata[: len(payload)] == payload
        assert all(byte == 0 for byte in rx_frame.tdata[len(payload) :])
    else:
        assert len(rx_frame.tdata) == len(payload)

    assert active_latency == reference_latency


def test_Pgp2fcLaneFcLatency():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fclanewrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcLaneWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
