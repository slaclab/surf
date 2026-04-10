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
# - Sweep: Keep filtering enabled and exercise the three key externally visible
#   decisions: accept local traffic, drop foreign unicast, and drop on pause.
# - Stimulus: Send one frame addressed to the configured local MAC, one frame
#   addressed elsewhere, and one local frame while the downstream pause flag is
#   asserted.
# - Checks: Local traffic must pass unchanged, foreign traffic must disappear,
#   and the pause-driven drop path must suppress output even for a local frame.
# - Timing: The block has no output backpressure, so each frame is launched
#   continuously and the sink watches for visible output rather than handshakes.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.eth_mac.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    build_ethernet_frame,
    expect_no_output,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxFilterWrapper.vhd"


@cocotb.test()
async def eth_mac_rx_filter_test(dut):
    local_mac_wire = 0x001122334455
    # EthMacPkg stores MAC addresses in the same little-endian byte order used
    # by the flattened EMAC data word, so the configured register image is the
    # reverse of the human-readable wire-order MAC address.
    local_mac_reg = 0x554433221100
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "mAxisPause": 0,
            "dropOnPause": 0,
            "macAddress": local_mac_reg,
            "filtEnable": 1,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    local_frame = build_ethernet_frame(
        dst_mac=local_mac_wire,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x88B5,
        payload=bytes(range(18)),
    )
    local_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(local_frame), clk=bench.clk)
    )
    local_observed = await recv_frame(sink, clk=bench.clk)
    await local_send
    assert payload_from_beats(local_observed) == local_frame

    foreign_frame = build_ethernet_frame(
        dst_mac=0x00AA00BB00CC,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x88B5,
        payload=b"foreign-unicast-drop",
    )
    await send_contiguous_frame(source, frame_beats_from_bytes(foreign_frame), clk=bench.clk)
    await expect_no_output(sink, clk=bench.clk, cycles=8)

    # The downstream pause indication is a separate control surface, so this
    # check proves the block can suppress even a local destination frame.
    dut.dropOnPause.value = 1
    dut.mAxisPause.value = 1
    await send_contiguous_frame(source, frame_beats_from_bytes(local_frame), clk=bench.clk)
    await expect_no_output(sink, clk=bench.clk, cycles=8)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="local_match_and_drop_paths")])
def test_EthMacRxFilter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxfilterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
