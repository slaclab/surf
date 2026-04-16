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
# - Sweep: Use one pause-enabled, bypass-enabled TX loopback so the bench can
#   cover checksum repair, bypass arbitration, pause generation, remote-pause
#   gating, and link-not-ready handling in one checked-in wrapper.
# - Stimulus: Send one checksum-cleared primary IPv4/UDP frame, then launch
#   primary and bypass traffic together, request a local pause frame, inject a
#   short remote pause before another payload, and finally transmit while the
#   PHY is marked not ready.
# - Checks: The TX assembly must repair checksums before export, bypass traffic
#   must win arbitration over simultaneous primary traffic, local pause must
#   emit the standards-compliant frame, remote pause must delay client traffic,
#   and `txLinkNotReady` must pulse without leaking partial output.
# - Timing: The bench observes the imported loopback stream rather than fixed
#   cycle delays because the TX path includes arbitration, checksum, pause, and
#   export staging.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    ROCE_ANALYSIS_SOURCES,
    build_ethernet_frame,
    build_ipv4_udp_frame,
    build_pause_frame,
    cycle,
    expect_no_output,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
    pad_ethernet_frame_to_min_size,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
    wait_signal_pulse,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTxLoopbackWrapper.vhd"
LOCAL_MAC_CFG = mac_config_word_from_wire(0x001122334455)


@cocotb.test()
async def eth_mac_tx_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix=None,
        sink_prefix=None,
        initial_values={
            "ethClkEn": 1,
            "phyReady": 1,
            "clientPause": 0,
            "rxPauseReq": 0,
            "rxPauseValue": 0,
            "pauseEnable": 1,
            "pauseTime": 0x0002,
            "macAddress": LOCAL_MAC_CFG,
            "ipCsumEn": 1,
            "tcpCsumEn": 0,
            "udpCsumEn": 1,
        },
    )
    prim_source = FlatEmacEndpoint(dut, prefix="sPrim")
    byp_source = FlatEmacEndpoint(dut, prefix="sByp")
    sink = FlatEmacEndpoint(dut, prefix="mAxis")
    prim_source.set_idle()
    byp_source.set_idle()

    # Start with a checksum-cleared IPv4/UDP packet so the assembly path has
    # to repair both headers before the exported frame is looped back.
    repaired_frame = build_ipv4_udp_frame(
        dst_mac=0x112233445566,
        src_mac=0xAABBCCDDEEFF,
        src_ip="10.1.0.1",
        dst_ip="10.1.0.2",
        src_port=0x1001,
        dst_port=0x2002,
        payload=b"eth-mac-tx-assembly" + bytes(24),
    )
    repair_input = build_ipv4_udp_frame(
        dst_mac=0x112233445566,
        src_mac=0xAABBCCDDEEFF,
        src_ip="10.1.0.1",
        dst_ip="10.1.0.2",
        src_port=0x1001,
        dst_port=0x2002,
        payload=b"eth-mac-tx-assembly" + bytes(24),
        ip_checksum_override=0x0000,
        udp_checksum_override=0x0000,
    )
    repair_send = cocotb.start_soon(
        send_contiguous_frame(prim_source, frame_beats_from_bytes(repair_input), clk=bench.clk)
    )
    repair_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=256)
    await repair_send
    assert payload_from_beats(repair_observed) == repaired_frame

    # Launch primary and bypass sources together. The TxBypass assembly logic
    # should select bypass first and only forward the held primary frame after.
    primary_frame = build_ethernet_frame(
        dst_mac=0x010203040506,
        src_mac=0x0708090A0B0C,
        eth_type=0x0801,
        payload=bytes(range(48)),
    )
    bypass_frame = build_ethernet_frame(
        dst_mac=0x0D0E0F101112,
        src_mac=0x131415161718,
        eth_type=0x88B5,
        payload=bytes(range(32)),
    )
    primary_send = cocotb.start_soon(
        send_contiguous_frame(prim_source, frame_beats_from_bytes(primary_frame), clk=bench.clk)
    )
    bypass_send = cocotb.start_soon(
        send_contiguous_frame(byp_source, frame_beats_from_bytes(bypass_frame), clk=bench.clk)
    )
    first_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=256)
    second_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=256)
    await primary_send
    await bypass_send
    assert payload_from_beats(first_observed) == pad_ethernet_frame_to_min_size(bypass_frame)
    assert payload_from_beats(second_observed) == primary_frame

    # Local pause generation must inject the protocol-defined pause frame.
    pause_pulse = cocotb.start_soon(wait_signal_pulse(dut.pauseTx, clk=bench.clk, timeout_cycles=128))
    dut.clientPause.value = 1
    await cycle(bench.clk, 1)
    dut.clientPause.value = 0
    pause_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=256)
    await pause_pulse
    assert payload_from_beats(pause_observed) == build_pause_frame(0x0002)

    # A received pause request should hold off the next payload briefly before
    # it is finally allowed onto the wire.
    dut.rxPauseValue.value = 2
    dut.rxPauseReq.value = 1
    await cycle(bench.clk, 1)
    dut.rxPauseReq.value = 0

    gated_frame = build_ethernet_frame(
        dst_mac=0x212223242526,
        src_mac=0x313233343536,
        eth_type=0x9000,
        payload=b"gated-after-rx-pause" + bytes(24),
    )
    gated_send = cocotb.start_soon(
        send_contiguous_frame(prim_source, frame_beats_from_bytes(gated_frame), clk=bench.clk)
    )
    await expect_no_output(sink, clk=bench.clk, cycles=4)
    gated_observed = await recv_frame(sink, clk=bench.clk, timeout_cycles=256)
    await gated_send
    assert payload_from_beats(gated_observed) == pad_ethernet_frame_to_min_size(gated_frame)

    # When the link is not ready the exporter must flag the condition and
    # suppress visible output until the link recovers.
    dut.phyReady.value = 0
    blocked_frame = build_ethernet_frame(
        dst_mac=0x414243444546,
        src_mac=0x515253545556,
        eth_type=0x9001,
        payload=bytes(range(40)),
    )
    blocked_pulse = cocotb.start_soon(
        wait_signal_pulse(dut.txLinkNotReady, clk=bench.clk, timeout_cycles=128)
    )
    blocked_send = cocotb.start_soon(
        send_contiguous_frame(prim_source, frame_beats_from_bytes(blocked_frame), clk=bench.clk)
    )
    await blocked_send
    await blocked_pulse
    await expect_no_output(sink, clk=bench.clk, cycles=8)
    assert int(dut.txUnderRun.value) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="tx_assembly_loopback")])
def test_EthMacTx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactxloopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + ROCE_ANALYSIS_SOURCES + [WRAPPER_PATH]},
    )
