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
# - Sweep: Exercise the DHCP engine across the full discover/offer/request/ack
#   exchange that establishes a leased address.
# - Stimulus: Allow the engine to emit its initial discover, inject a matching
#   DHCP offer, capture the resulting request, then inject the matching ack.
# - Checks: The outbound discover and request must advertise the correct DHCP
#   message type and XID continuity, and the final ack must update `dhcpIp`.
# - Timing: The test relies on the wrapper's shortened timers so the protocol
#   steps occur through the real timeout logic rather than direct state forcing.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    cycle,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
)
from tests.ethernet.UdpEngine.udp_test_utils import (
    DHCP_ACK,
    DHCP_BOOTP_FLAG_BROADCAST,
    DHCP_DISCOVER,
    DHCP_OFFER,
    DHCP_REQUEST,
    LEGACY_IPS,
    LEGACY_MAC_WIRES,
    UDP_RTL_SOURCES,
    build_dhcp_reply_payload,
    extract_dhcp_bootp_flags,
    extract_dhcp_message_type,
    extract_dhcp_requested_ip,
    extract_dhcp_server_identifier,
    extract_dhcp_xid,
    ipv4_config_word,
    setup_udp_dhcp_bench,
)


WRAPPER_PATH = "ethernet/UdpEngine/wrappers/UdpEngineDhcpFlatWrapper.vhd"
DHCP_ACK_PUBLISH_TIMEOUT_CYCLES = 128


@cocotb.test()
async def udp_engine_dhcp_offer_ack_sequence_test(dut):
    bench = await setup_udp_dhcp_bench(dut)

    # Let the engine boot through its shortened timeout logic and emit the
    # first discover message on the dedicated DHCP stream.
    discover_observed = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mDhcpTReady,
        timeout_cycles=256,
    )
    discover_payload = payload_from_beats(discover_observed)
    discover_xid = extract_dhcp_xid(discover_payload)
    assert extract_dhcp_message_type(discover_payload) == DHCP_DISCOVER

    # RFC 2131 4.1: a client that cannot receive unicast datagrams before its IP
    # is configured must set the BOOTP broadcast flag (bit 15, 0x8000). With the
    # flag clear, a spec-compliant server unicasts its Offer to the not-yet-leased
    # yiaddr, which may never be delivered to the client (observed in the field as
    # an endless Discover/Offer loop), so the client never sends a Request.
    # RFC 2131 also requires the remaining 15 flag bits to be zero, so check
    # for exact equality rather than just the broadcast bit.
    discover_flags = extract_dhcp_bootp_flags(discover_payload)
    assert discover_flags == DHCP_BOOTP_FLAG_BROADCAST, (
        f"Unexpected BOOTP flags in Discover: flags=0x{discover_flags:04x} "
        f"(expected 0x{DHCP_BOOTP_FLAG_BROADCAST:04x})"
    )

    # A matching offer should move the state machine into the request phase
    # while preserving the same DHCP transaction identifier.
    offer_payload = build_dhcp_reply_payload(
        message_type=DHCP_OFFER,
        xid=discover_xid,
        client_mac=LEGACY_MAC_WIRES[0],
        yiaddr="192.168.2.44",
        siaddr=LEGACY_IPS[1],
    )
    offer_send = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(offer_payload), clk=bench.clk)
    )
    request_observed = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mDhcpTReady,
        timeout_cycles=256,
    )
    await offer_send
    request_payload = payload_from_beats(request_observed)
    request_xid = extract_dhcp_xid(request_payload)
    assert extract_dhcp_message_type(request_payload) == DHCP_REQUEST
    assert extract_dhcp_requested_ip(request_payload) == "192.168.2.44"
    assert extract_dhcp_server_identifier(request_payload) == LEGACY_IPS[1]

    request_flags = extract_dhcp_bootp_flags(request_payload)
    assert request_flags == DHCP_BOOTP_FLAG_BROADCAST, (
        f"Unexpected BOOTP flags in Request: flags=0x{request_flags:04x} "
        f"(expected 0x{DHCP_BOOTP_FLAG_BROADCAST:04x})"
    )

    # The ack is the step that should finally publish the leased IP address on
    # the wrapper-visible `dhcpIp` output.
    ack_payload = build_dhcp_reply_payload(
        message_type=DHCP_ACK,
        xid=request_xid,
        client_mac=LEGACY_MAC_WIRES[0],
        yiaddr="192.168.2.44",
        siaddr=LEGACY_IPS[1],
    )
    ack_send = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(ack_payload), clk=bench.clk)
    )
    await ack_send
    # The wrapper uses shortened DHCP timers, but the published lease still
    # appears asynchronously a few cycles after the ACK frame is accepted.
    for _ in range(DHCP_ACK_PUBLISH_TIMEOUT_CYCLES):
        await cycle(bench.clk, 1)
        if int(dut.dhcpIp.value) == ipv4_config_word("192.168.2.44"):
            break
    assert int(dut.dhcpIp.value) == ipv4_config_word("192.168.2.44")


@pytest.mark.parametrize("parameters", [pytest.param({}, id="udp_engine_dhcp_flat_wrapper")])
def test_UdpEngineDhcp(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.udpenginedhcpflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": UDP_RTL_SOURCES + [WRAPPER_PATH]},
    )
