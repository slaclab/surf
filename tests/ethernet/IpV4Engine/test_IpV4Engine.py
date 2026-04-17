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
# - Sweep: Exercise the IPv4 top across one UDP receive path, one protocol TX
#   path, one ICMP echo-response path, and one ARP client lookup round-trip.
# - Stimulus: Exercise the full IPv4 top with four focused scenarios:
#   inbound UDP routing, outbound protocol transmission, inbound ICMP echo
#   handling, and ARP client lookup.
# - Checks: UDP traffic must emerge on the protocol output slot as the expected
#   pseudo-header frame, outbound protocol traffic must emerge as a wire-format
#   IPv4 frame on the MAC output, ICMP echo requests must produce outbound
#   reply frames, and ARP requests must round-trip through the top-level ARP
#   client ports.
# - Timing: Each scenario uses handshaked sources and sinks so the top-level
#   assembly is verified through its real interfaces instead of local shortcuts.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    FlatEmacEndpoint,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
    payload_from_beat,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)
from tests.ethernet.IpV4Engine.ipv4_test_utils import (
    ARP_BROADCAST_MAC,
    IP_PROTOCOL_ICMP,
    IP_PROTOCOL_UDP,
    IPV4_RTL_SOURCES,
    build_arp_frame,
    build_icmp_echo_frame,
    build_icmp_echo_reply_packet,
    build_ipv4_rx_pseudo_frame,
    build_ipv4_tx_pseudo_frame,
    build_ipv4_tx_wire_frame,
    build_ipv4_udp_payload,
    build_ipv4_frame,
    ipv4_config_word,
    ipv4_to_bytes,
)


WRAPPER_PATH = "ethernet/IpV4Engine/wrappers/IpV4EngineTopWrapper.vhd"

LOCAL_MAC_WIRE = 0x001122334455
LOCAL_MAC_CFG = mac_config_word_from_wire(LOCAL_MAC_WIRE)
REMOTE_MAC_WIRE = 0x665544332211
LOCAL_IP = "192.168.60.10"
LOCAL_IP_CFG = ipv4_config_word(LOCAL_IP)
REMOTE_IP = "192.168.60.11"


async def setup_top_bench(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sMac",
        initial_values={
            "localMac": LOCAL_MAC_CFG,
            "localIp": LOCAL_IP_CFG,
            "mMacTReady": 0,
            "mProtTReady": 0,
            "arpAckTReady": 0,
        },
    )
    assert bench.source is not None
    mac_sink = FlatEmacEndpoint(dut, prefix="mMac")
    prot_sink = FlatEmacEndpoint(dut, prefix="mProt")
    prot_source = FlatEmacEndpoint(dut, prefix="sProt")
    arp_req_source = FlatEmacEndpoint(dut, prefix="arpReq")
    arp_ack_sink = FlatEmacEndpoint(dut, prefix="arpAck")
    prot_source.set_idle()
    arp_req_source.set_idle()
    return bench, mac_sink, prot_sink, prot_source, arp_req_source, arp_ack_sink


@cocotb.test()
async def ipv4_top_udp_routing_test(dut):
    bench, _, prot_sink, _, _, _ = await setup_top_bench(dut)

    udp_payload = build_ipv4_udp_payload(
        src_port=0x2001,
        dst_port=0x2002,
        payload=b"top-level-udp-routing",
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
    )
    udp_frame = build_ipv4_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=REMOTE_MAC_WIRE,
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
        protocol=IP_PROTOCOL_UDP,
        payload=udp_payload,
    )
    udp_expected = build_ipv4_rx_pseudo_frame(
        src_mac=REMOTE_MAC_WIRE,
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
        protocol=IP_PROTOCOL_UDP,
        payload=udp_payload,
    )

    udp_send = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(udp_frame), clk=bench.clk)
    )
    udp_observed = await recv_frame(
        prot_sink,
        clk=bench.clk,
        ready_signal=dut.mProtTReady,
        timeout_cycles=256,
    )
    await udp_send
    assert payload_from_beats(udp_observed) == udp_expected


@cocotb.test()
async def ipv4_top_protocol_tx_path_test(dut):
    bench, mac_sink, _, prot_source, _, _ = await setup_top_bench(dut)

    udp_payload = build_ipv4_udp_payload(
        src_port=0x2468,
        dst_port=0x1357,
        payload=b"top-level-protocol-tx",
        src_ip=LOCAL_IP,
        dst_ip=REMOTE_IP,
    )
    tx_request = build_ipv4_tx_pseudo_frame(
        dst_mac=REMOTE_MAC_WIRE,
        src_ip=LOCAL_IP,
        dst_ip=REMOTE_IP,
        protocol=IP_PROTOCOL_UDP,
        payload=udp_payload,
    )
    tx_expected = build_ipv4_tx_wire_frame(
        dst_mac=REMOTE_MAC_WIRE,
        src_mac=LOCAL_MAC_WIRE,
        src_ip=LOCAL_IP,
        dst_ip=REMOTE_IP,
        protocol=IP_PROTOCOL_UDP,
        payload=udp_payload,
    )

    tx_send = cocotb.start_soon(
        send_contiguous_frame(prot_source, frame_beats_from_bytes(tx_request), clk=bench.clk)
    )
    tx_observed = await recv_frame(
        mac_sink,
        clk=bench.clk,
        ready_signal=dut.mMacTReady,
        timeout_cycles=256,
    )
    await tx_send
    assert payload_from_beats(tx_observed) == tx_expected


@cocotb.test()
async def ipv4_top_icmp_echo_reply_test(dut):
    bench, mac_sink, _, _, _, _ = await setup_top_bench(dut)

    icmp_frame = build_icmp_echo_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=REMOTE_MAC_WIRE,
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
        payload=b"top-level-icmp",
        identifier=0x7788,
        sequence=0x0304,
    )
    expected_reply = build_ipv4_tx_wire_frame(
        dst_mac=REMOTE_MAC_WIRE,
        src_mac=LOCAL_MAC_WIRE,
        src_ip=LOCAL_IP,
        dst_ip=REMOTE_IP,
        protocol=IP_PROTOCOL_ICMP,
        payload=build_icmp_echo_reply_packet(
            payload=b"top-level-icmp",
            identifier=0x7788,
            sequence=0x0304,
        ),
    )

    icmp_send = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(icmp_frame), clk=bench.clk)
    )
    icmp_observed = await recv_frame(
        mac_sink,
        clk=bench.clk,
        ready_signal=dut.mMacTReady,
        timeout_cycles=256,
    )
    await icmp_send
    assert payload_from_beats(icmp_observed) == expected_reply


@cocotb.test()
async def ipv4_top_arp_client_round_trip_test(dut):
    bench, mac_sink, _, _, arp_req_source, arp_ack_sink = await setup_top_bench(dut)

    remote_lookup = frame_beats_from_bytes(ipv4_to_bytes(REMOTE_IP))[0]
    # The top-level ARP client port inherits the same level-sensitive request
    # semantics as the standalone ARP engine wrapper.
    arp_req_source.drive(remote_lookup)
    arp_request_observed = await recv_frame(
        mac_sink,
        clk=bench.clk,
        ready_signal=dut.mMacTReady,
        timeout_cycles=256,
    )
    arp_request_expected = build_arp_frame(
        opcode=1,
        sender_mac=LOCAL_MAC_WIRE,
        sender_ip=LOCAL_IP,
        target_mac=ARP_BROADCAST_MAC,
        target_ip=REMOTE_IP,
    )
    assert payload_from_beats(arp_request_observed) == arp_request_expected

    arp_reply = build_arp_frame(
        opcode=2,
        sender_mac=REMOTE_MAC_WIRE,
        sender_ip=REMOTE_IP,
        target_mac=LOCAL_MAC_WIRE,
        target_ip=LOCAL_IP,
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=REMOTE_MAC_WIRE,
    )
    reply_send = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(arp_reply), clk=bench.clk)
    )
    arp_ack = await arp_ack_sink.recv(
        clk=bench.clk,
        ready_signal=dut.arpAckTReady,
    )
    await reply_send
    arp_req_source.set_idle()
    assert payload_from_beat(arp_ack)[:6] == REMOTE_MAC_WIRE.to_bytes(6, byteorder="big")


@pytest.mark.parametrize("parameters", [pytest.param({}, id="ipv4_top_wrapper")])
def test_IpV4Engine(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ipv4enginetopwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": IPV4_RTL_SOURCES + [WRAPPER_PATH]},
    )
