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
# - Sweep: Keep one pause-enabled configuration and cover the three observable
#   behaviors of the block: normal pass-through, valid pause detection, and
#   EOFE-terminated pause rejection.
# - Stimulus: Send one ordinary Ethernet frame, one standards-compliant pause
#   frame, and one identical pause frame marked bad with `EOFE`.
# - Checks: Ordinary traffic must pass unchanged, valid pause traffic must be
#   dropped while pulsing the pause request/value outputs, and bad pause
#   traffic must be dropped without raising a pause request.
# - Timing: The output path has no backpressure, so the test launches each
#   frame continuously and watches the visible output beats directly.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.eth_mac.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    build_ethernet_frame,
    build_pause_frame,
    expect_no_output,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
    wait_signal_pulse,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxPauseWrapper.vhd"


@cocotb.test()
async def eth_mac_rx_pause_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    normal_frame = build_ethernet_frame(
        dst_mac=0xDA0203040506,
        src_mac=0x5A1122334455,
        eth_type=0x88B5,
        payload=bytes(range(20)),
    )
    normal_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(normal_frame), clk=bench.clk)
    )
    observed_normal = await recv_frame(sink, clk=bench.clk)
    await normal_send
    assert payload_from_beats(observed_normal) == normal_frame

    pause_value = 0x1234
    pause_frame = build_pause_frame(pause_value)
    pause_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(pause_frame), clk=bench.clk)
    )
    await wait_signal_pulse(dut.rxPauseReq, clk=bench.clk)
    await pause_send
    assert int(dut.rxPauseValue.value) == pause_value
    await expect_no_output(sink, clk=bench.clk, cycles=8)

    # Mark the final beat bad so the pause decoder sees the same header but
    # must suppress the resulting pause request.
    bad_pause_beats = frame_beats_from_bytes(build_pause_frame(0xBEEF), eofe=1)
    bad_pause_send = cocotb.start_soon(send_contiguous_frame(source, bad_pause_beats, clk=bench.clk))
    for _ in range(16):
        await Timer(1, unit="ns")
        assert int(dut.rxPauseReq.value) == 0
        await RisingEdge(bench.clk)
    await bad_pause_send
    await expect_no_output(sink, clk=bench.clk, cycles=8)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="pause_decode_and_drop")])
def test_EthMacRxPause(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxpausewrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
