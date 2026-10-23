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
# - Sweep: Cover one UDP protocol route, one ICMP protocol route, and one
#   unsupported-protocol drop through the receive engine.
# - Stimulus: Drive complete Ethernet/IPv4 frames into IpV4EngineRx for one
#   UDP packet, one ICMP packet, and one unsupported protocol packet.
# - Checks: The UDP and ICMP cases must emerge as the expected pseudo-header
#   streams on their selected protocol slots, while the unsupported protocol
#   must be dropped.
# - Timing: The bench waits on the protocol output streams rather than fixed
#   latency assumptions because the receive engine has multiple header states.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    FlatEmacEndpoint,
    expect_no_output,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)
from tests.ethernet.IpV4Engine.ipv4_test_utils import (
    IP_PROTOCOL_ICMP,
    IP_PROTOCOL_UDP,
    IPV4_RTL_SOURCES,
    build_icmp_echo_packet,
    build_ipv4_frame,
    build_ipv4_rx_pseudo_frame,
    build_ipv4_udp_payload,
)


WRAPPER_PATH = "ethernet/IpV4Engine/wrappers/IpV4EngineRxWrapper.vhd"
UNSUPPORTED_PROTOCOL = 0x99
UDP_REMOTE_PORT = 0x1234
UDP_LOCAL_PORT = 0x5678

LOCAL_MAC = 0x001122334455
REMOTE_MAC = 0x665544332211
LOCAL_IP = "192.168.30.10"
REMOTE_IP = "192.168.30.11"


@cocotb.test()
async def ipv4_rx_routes_protocol_slots_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sIpv4",
        initial_values={
            "mUdpTReady": 0,
            "mIcmpTReady": 0,
        },
    )
    source = bench.source
    assert source is not None

    udp_sink = FlatEmacEndpoint(dut, prefix="mUdp")
    icmp_sink = FlatEmacEndpoint(dut, prefix="mIcmp")

    udp_payload = build_ipv4_udp_payload(
        src_port=UDP_REMOTE_PORT,
        dst_port=UDP_LOCAL_PORT,
        payload=b"udp-payload-through-rx",
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
    )
    udp_frame = build_ipv4_frame(
        dst_mac=LOCAL_MAC,
        src_mac=REMOTE_MAC,
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
        protocol=IP_PROTOCOL_UDP,
        payload=udp_payload,
    )
    udp_expected = build_ipv4_rx_pseudo_frame(
        src_mac=REMOTE_MAC,
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
        protocol=IP_PROTOCOL_UDP,
        payload=udp_payload,
    )

    udp_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(udp_frame), clk=bench.clk)
    )
    udp_observed = await recv_frame(
        udp_sink,
        clk=bench.clk,
        ready_signal=dut.mUdpTReady,
        timeout_cycles=128,
    )
    await udp_send
    assert payload_from_beats(udp_observed) == udp_expected
    await expect_no_output(icmp_sink, clk=bench.clk, cycles=8)

    icmp_payload = build_icmp_echo_packet(
        payload=b"icmp-through-rx",
        identifier=0x5566,
        sequence=0x0203,
    )
    icmp_frame = build_ipv4_frame(
        dst_mac=LOCAL_MAC,
        src_mac=REMOTE_MAC,
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
        protocol=IP_PROTOCOL_ICMP,
        payload=icmp_payload,
    )
    icmp_expected = build_ipv4_rx_pseudo_frame(
        src_mac=REMOTE_MAC,
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
        protocol=IP_PROTOCOL_ICMP,
        payload=icmp_payload,
    )

    icmp_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(icmp_frame), clk=bench.clk)
    )
    icmp_observed = await recv_frame(
        icmp_sink,
        clk=bench.clk,
        ready_signal=dut.mIcmpTReady,
        timeout_cycles=128,
    )
    await icmp_send
    assert payload_from_beats(icmp_observed) == icmp_expected
    await expect_no_output(udp_sink, clk=bench.clk, cycles=8)

    unsupported_frame = build_ipv4_frame(
        dst_mac=LOCAL_MAC,
        src_mac=REMOTE_MAC,
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
        # `0x99` is just an arbitrary unsupported protocol ID so the drop path
        # is clearly distinct from UDP (`0x11`) and ICMP (`0x01`).
        protocol=UNSUPPORTED_PROTOCOL,
        payload=b"unsupported-protocol-drop",
    )
    await send_contiguous_frame(source, frame_beats_from_bytes(unsupported_frame), clk=bench.clk)
    await expect_no_output(udp_sink, clk=bench.clk, cycles=12)
    await expect_no_output(icmp_sink, clk=bench.clk, cycles=12)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="ipv4_rx_wrapper")])
def test_IpV4EngineRx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ipv4enginerxwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": IPV4_RTL_SOURCES + [WRAPPER_PATH]},
    )
