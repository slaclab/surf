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
# - Sweep: Keep filtering enabled in the wrapper and exercise all externally
#   visible runtime decisions: local pass, multicast pass, broadcast pass,
#   foreign-unicast drop, `filtEnable=0` bypass, and pause-driven drop.
# - Stimulus: Send both short and multi-beat frames, including a dropped
#   foreign unicast packet that is long enough to cross beat boundaries.
# - Checks: Accepted traffic must emerge byte-exact, dropped traffic must never
#   assert output valid, disabling filtering must pass a foreign unicast frame,
#   and a good frame sent after a dropped multi-beat packet must not inherit any
#   stale `TVALID` or payload from the discarded traffic.
# - Timing: The block has no output backpressure, so each frame is launched
#   continuously and the sink watches for visible output rather than handshakes.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    build_ethernet_frame,
    mac_config_word_from_wire,
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
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "mAxisPause": 0,
            "dropOnPause": 0,
            "macAddress": mac_config_word_from_wire(local_mac_wire),
            "filtEnable": 1,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    # Start with a multi-beat local-unicast frame so the pass path is checked
    # across the internal PASS state instead of only a one-beat decision.
    local_frame = build_ethernet_frame(
        dst_mac=local_mac_wire,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x88B5,
        payload=bytes(range(48)),
    )
    local_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(local_frame), clk=bench.clk)
    )
    local_observed = await recv_frame(sink, clk=bench.clk)
    await local_send
    assert payload_from_beats(local_observed) == local_frame

    multicast_frame = build_ethernet_frame(
        dst_mac=0x01005E000001,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x88B5,
        payload=b"multicast-pass-frame",
    )
    multicast_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(multicast_frame), clk=bench.clk)
    )
    multicast_observed = await recv_frame(sink, clk=bench.clk)
    await multicast_send
    assert payload_from_beats(multicast_observed) == multicast_frame

    broadcast_frame = build_ethernet_frame(
        dst_mac=0xFFFFFFFFFFFF,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x88B5,
        payload=b"broadcast-pass-frame" + bytes(range(24)),
    )
    broadcast_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(broadcast_frame), clk=bench.clk)
    )
    broadcast_observed = await recv_frame(sink, clk=bench.clk)
    await broadcast_send
    assert payload_from_beats(broadcast_observed) == broadcast_frame

    foreign_frame = build_ethernet_frame(
        dst_mac=0x00AA00BB00CC,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x88B5,
        payload=bytes(range(64)),
    )
    await send_contiguous_frame(source, frame_beats_from_bytes(foreign_frame), clk=bench.clk)
    await expect_no_output(sink, clk=bench.clk, cycles=16)

    # After dropping a multi-beat frame the output must stay idle until a fresh
    # accepted packet arrives; otherwise stale state would leak into the next
    # frame.
    post_drop_frame = build_ethernet_frame(
        dst_mac=0xFFFFFFFFFFFF,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x88B5,
        payload=b"post-drop-idle-check" + bytes(20),
    )
    post_drop_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(post_drop_frame), clk=bench.clk)
    )
    post_drop_observed = await recv_frame(sink, clk=bench.clk)
    await post_drop_send
    assert payload_from_beats(post_drop_observed) == post_drop_frame

    dut.filtEnable.value = 0
    filt_bypass_frame = build_ethernet_frame(
        dst_mac=0x00AA00BB00CC,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x9000,
        payload=b"filter-disabled-foreign-pass" + bytes(18),
    )
    filt_bypass_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(filt_bypass_frame), clk=bench.clk)
    )
    filt_bypass_observed = await recv_frame(sink, clk=bench.clk)
    await filt_bypass_send
    assert payload_from_beats(filt_bypass_observed) == filt_bypass_frame
    dut.filtEnable.value = 1

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
