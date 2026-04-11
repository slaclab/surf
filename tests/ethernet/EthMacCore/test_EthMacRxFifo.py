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
# - Sweep: Keep one asynchronous primary-path FIFO instance because that is the
#   most behavior-rich configuration and reuses the real SsiFifo crossing.
# - Stimulus: Send one clean frame across the clock boundary, then hold the
#   output side stalled while injecting a longer frame to trip the pause
#   threshold, and finally send a bad frame marked with `EOFE`.
# - Checks: Clean traffic must emerge intact, the source-side pause flag must
#   assert while the sink is blocked, and the bad frame must be dropped while
#   pulsing `rxFifoDrop`.
# - Timing: The test uses distinct source and sink clocks, and waits on the
#   visible FIFO controls instead of assuming a fixed occupancy latency.

import cocotb
import pytest

from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    build_ethernet_frame,
    cycle,
    expect_no_output,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    start_clock,
    wait_signal_pulse,
)
from tests.common.regression_utils import run_surf_vhdl_test


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxFifoWrapper.vhd"


async def reset_async_fifo(dut) -> None:
    dut.sRst.value = 1
    dut.mPrimRst.value = 1
    await cycle(dut.sClk, 4)
    await cycle(dut.mPrimClk, 2)
    dut.sRst.value = 0
    dut.mPrimRst.value = 0
    await cycle(dut.sClk, 2)
    await cycle(dut.mPrimClk, 2)


@cocotb.test()
async def eth_mac_rx_fifo_test(dut):
    start_clock(dut.sClk, period_ns=4.0)
    start_clock(dut.mPrimClk, period_ns=6.0)

    dut.phyReady.setimmediatevalue(1)
    dut.pauseThresh.setimmediatevalue(1)
    dut.mAxisTReady.setimmediatevalue(0)

    source = FlatEmacEndpoint(dut, prefix="sAxis")
    sink = FlatEmacEndpoint(dut, prefix="mAxis")
    source.set_idle()

    await reset_async_fifo(dut)

    # A basic async transfer proves the wrapper flattening and the FIFO path
    # both preserve the EMAC framing and user bits.
    dut.mAxisTReady.value = 1
    clean_frame = build_ethernet_frame(
        dst_mac=0x001122334455,
        src_mac=0x66778899AABB,
        eth_type=0x9000,
        payload=bytes(range(64)),
    )
    clean_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(clean_frame), clk=dut.sClk)
    )
    clean_observed = await recv_frame(
        sink,
        clk=dut.mPrimClk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=256,
    )
    await clean_send
    assert payload_from_beats(clean_observed) == clean_frame

    # Holding the sink stalled should eventually raise the pause hint on the
    # source side once the FIFO occupancy crosses the programmed threshold.
    dut.mAxisTReady.value = 0
    long_frame = build_ethernet_frame(
        dst_mac=0x102132435465,
        src_mac=0x203142536475,
        eth_type=0x9001,
        payload=bytes(range(160)),
    )
    long_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(long_frame), clk=dut.sClk)
    )
    for _ in range(64):
        if int(dut.sAxisPause.value) == 1:
            break
        await cycle(dut.sClk, 1)
    else:
        raise AssertionError("Timed out waiting for RX FIFO pause assertion")

    dut.mAxisTReady.value = 1
    long_observed = await recv_frame(
        sink,
        clk=dut.mPrimClk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=512,
    )
    await long_send
    assert payload_from_beats(long_observed) == long_frame

    # The RX FIFO inherits the SSI inbound frame filter, so a missing opening
    # SOF is a real drop condition that should only report the side effect.
    bad_frame = build_ethernet_frame(
        dst_mac=0xABCDEF123456,
        src_mac=0x112233445566,
        eth_type=0x88B5,
        payload=bytes(range(48)),
    )
    bad_beats = frame_beats_from_bytes(bad_frame)
    bad_beats[0].sof = 0
    bad_send = cocotb.start_soon(
        send_contiguous_frame(source, bad_beats, clk=dut.sClk)
    )
    await wait_signal_pulse(dut.rxFifoDrop, clk=dut.sClk, timeout_cycles=128)
    await bad_send
    await expect_no_output(sink, clk=dut.mPrimClk, cycles=16)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="rx_fifo_async_primary")])
def test_EthMacRxFifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxfifowrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
