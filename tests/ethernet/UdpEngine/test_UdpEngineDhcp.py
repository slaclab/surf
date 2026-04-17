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
    FlatEmacEndpoint,
    cycle,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)
from tests.ethernet.UdpEngine.udp_test_utils import (
    LEGACY_IPS,
    LEGACY_MAC_CFGS,
    LEGACY_MAC_WIRES,
    UDP_RTL_SOURCES,
    build_dhcp_reply_payload,
    extract_dhcp_message_type,
    extract_dhcp_requested_ip,
    extract_dhcp_server_identifier,
    extract_dhcp_xid,
    ipv4_config_word,
)


WRAPPER_PATH = "ethernet/UdpEngine/wrappers/UdpEngineDhcpFlatWrapper.vhd"


async def setup_udp_dhcp_bench(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sDhcp",
        initial_values={
            "localMac": LEGACY_MAC_CFGS[0],
            "localIp": 0,
            "mDhcpTReady": 0,
        },
    )
    assert bench.source is not None
    return bench, bench.source, FlatEmacEndpoint(dut, prefix="mDhcp")


@cocotb.test()
async def udp_engine_dhcp_offer_ack_sequence_test(dut):
    bench, dhcp_source, dhcp_sink = await setup_udp_dhcp_bench(dut)

    discover_observed = await recv_frame(
        dhcp_sink,
        clk=bench.clk,
        ready_signal=dut.mDhcpTReady,
        timeout_cycles=256,
    )
    discover_payload = payload_from_beats(discover_observed)
    discover_xid = extract_dhcp_xid(discover_payload)
    assert extract_dhcp_message_type(discover_payload) == 1

    offer_payload = build_dhcp_reply_payload(
        message_type=2,
        xid=discover_xid,
        client_mac=LEGACY_MAC_WIRES[0],
        yiaddr="192.168.2.44",
        siaddr=LEGACY_IPS[1],
    )
    offer_send = cocotb.start_soon(
        send_contiguous_frame(dhcp_source, frame_beats_from_bytes(offer_payload), clk=bench.clk)
    )
    request_observed = await recv_frame(
        dhcp_sink,
        clk=bench.clk,
        ready_signal=dut.mDhcpTReady,
        timeout_cycles=256,
    )
    await offer_send
    request_payload = payload_from_beats(request_observed)
    request_xid = extract_dhcp_xid(request_payload)
    assert extract_dhcp_message_type(request_payload) == 3
    assert extract_dhcp_requested_ip(request_payload) == "192.168.2.44"
    assert extract_dhcp_server_identifier(request_payload) == LEGACY_IPS[1]

    ack_payload = build_dhcp_reply_payload(
        message_type=5,
        xid=request_xid,
        client_mac=LEGACY_MAC_WIRES[0],
        yiaddr="192.168.2.44",
        siaddr=LEGACY_IPS[1],
    )
    ack_send = cocotb.start_soon(
        send_contiguous_frame(dhcp_source, frame_beats_from_bytes(ack_payload), clk=bench.clk)
    )
    await ack_send
    for _ in range(128):
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
