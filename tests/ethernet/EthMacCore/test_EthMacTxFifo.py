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
# - Sweep: Keep one asynchronous primary-path instance so the bench exercises
#   the actual AXI Stream FIFO rather than the common-clock bypass shortcut.
# - Stimulus: Send one ordinary frame across the clock crossing, then hold the
#   sink stalled while streaming a longer frame that can fill the FIFO deeply
#   enough to deassert source `TREADY`.
# - Checks: Ordinary traffic must emerge unchanged, source backpressure must
#   assert while the sink is blocked, and the queued frame must recover cleanly
#   once downstream readiness returns.
# - Timing: The two clocks intentionally run at different periods, so the test
#   waits on visible handshakes instead of assuming synchronous phasing.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    build_ethernet_frame,
    cycle,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    start_clock,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTxFifoWrapper.vhd"


async def reset_async_fifo(dut) -> None:
    dut.sPrimRst.value = 1
    dut.mRst.value = 1
    await cycle(dut.sPrimClk, 4)
    await cycle(dut.mClk, 2)
    dut.sPrimRst.value = 0
    dut.mRst.value = 0
    await cycle(dut.sPrimClk, 2)
    await cycle(dut.mClk, 2)


@cocotb.test()
async def eth_mac_tx_fifo_test(dut):
    start_clock(dut.sPrimClk, period_ns=4.0)
    start_clock(dut.mClk, period_ns=6.0)

    dut.mAxisTReady.setimmediatevalue(0)

    source = FlatEmacEndpoint(dut, prefix="sAxis")
    sink = FlatEmacEndpoint(dut, prefix="mAxis")
    source.set_idle()

    await reset_async_fifo(dut)

    # First prove the simple async path works when the sink is ready.
    dut.mAxisTReady.value = 1
    clean_frame = build_ethernet_frame(
        dst_mac=0x001122334455,
        src_mac=0x66778899AABB,
        eth_type=0x9000,
        payload=bytes(range(80)),
    )
    clean_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(clean_frame), clk=dut.sPrimClk)
    )
    clean_observed = await recv_frame(
        sink,
        clk=dut.mClk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=256,
    )
    await clean_send
    assert payload_from_beats(clean_observed) == clean_frame

    # Stall the sink and stream enough data to fill the small TX FIFO so the
    # source-side `TREADY` must eventually deassert.
    dut.mAxisTReady.value = 0
    queued_frame = build_ethernet_frame(
        dst_mac=0x123456789ABC,
        src_mac=0x0F1E2D3C4B5A,
        eth_type=0x9001,
        payload=bytes((index % 256 for index in range(640))),
    )
    queued_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(queued_frame), clk=dut.sPrimClk)
    )
    for _ in range(512):
        await cycle(dut.sPrimClk, 1)
        if int(dut.sAxisTReady.value) == 0:
            break
    else:
        raise AssertionError("Timed out waiting for TX FIFO backpressure")

    # Once downstream readiness returns, the blocked send coroutine should
    # drain and the queued frame should appear intact on the MAC-facing side.
    dut.mAxisTReady.value = 1
    queued_observed = await recv_frame(
        sink,
        clk=dut.mClk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=512,
    )
    await queued_send
    assert payload_from_beats(queued_observed) == queued_frame


@pytest.mark.parametrize("parameters", [pytest.param({}, id="tx_fifo_async_primary")])
def test_EthMacTxFifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactxfifowrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
