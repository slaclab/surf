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
# - Sweep: Exercise server routing, client routing, and DHCP routing through
#   the UDP RX path.
# - Stimulus: Inject pseudo-UDP frames targeted at the server port, the client
#   port, and the DHCP socket tuple.
# - Checks: Each frame must emerge on the correct output with the UDP header
#   stripped, and the server/client sideband metadata must latch the sender.
# - Timing: The sink-side assertions wait on real ready/valid handshakes so
#   the test observes the RX state machine rather than sampling combinationally.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
)
from tests.ethernet.UdpEngine.udp_test_utils import (
    DHCP_CLIENT_PORT,
    DHCP_SERVER_PORT,
    LEGACY_IPS,
    LEGACY_MAC_CFGS,
    LEGACY_MAC_WIRES,
    UDP_RTL_SOURCES,
    build_udp_rx_pseudo_frame,
    port_config_word,
    setup_udp_rx_bench,
    ipv4_config_word,
)


WRAPPER_PATH = "ethernet/UdpEngine/wrappers/UdpEngineRxFlatWrapper.vhd"


@cocotb.test()
async def udp_engine_rx_routes_server_payload_and_debug_test(dut):
    bench = await setup_udp_rx_bench(dut)

    # Drive one server-destined pseudo-UDP frame into the RX path so the DUT
    # has to strip the header and capture the sender debug metadata.
    server_payload = b"udp-rx-server-path"
    server_frame = build_udp_rx_pseudo_frame(
        remote_mac=LEGACY_MAC_WIRES[1],
        remote_ip=LEGACY_IPS[1],
        local_ip=LEGACY_IPS[0],
        remote_port=0x1234,
        local_port=8192,
        payload=server_payload,
    )

    server_send = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(server_frame), clk=bench.clk)
    )
    server_observed = await recv_frame(
        bench.server_sink,
        clk=bench.clk,
        ready_signal=dut.mServerTReady,
        timeout_cycles=64,
    )
    await server_send

    assert payload_from_beats(server_observed) == server_payload
    assert int(dut.serverRemotePort.value) == port_config_word(0x1234)
    assert int(dut.serverRemoteIp.value) == ipv4_config_word(LEGACY_IPS[1])
    assert int(dut.serverRemoteMac.value) == LEGACY_MAC_CFGS[1]


@cocotb.test()
async def udp_engine_rx_routes_client_payload_and_detection_test(dut):
    bench = await setup_udp_rx_bench(dut)

    # The client route uses the same on-wire format but a different local port,
    # so this packet should emerge on the client-side output instead.
    client_payload = b"udp-rx-client-path"
    client_frame = build_udp_rx_pseudo_frame(
        remote_mac=LEGACY_MAC_WIRES[1],
        remote_ip=LEGACY_IPS[1],
        local_ip=LEGACY_IPS[0],
        remote_port=0x5678,
        local_port=8193,
        payload=client_payload,
    )

    client_send = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(client_frame), clk=bench.clk)
    )
    client_observed = await recv_frame(
        bench.client_sink,
        clk=bench.clk,
        ready_signal=dut.mClientTReady,
        timeout_cycles=64,
    )
    await client_send

    assert payload_from_beats(client_observed) == client_payload


@cocotb.test()
async def udp_engine_rx_routes_dhcp_socket_test(dut):
    bench = await setup_udp_rx_bench(dut)

    # DHCP is recognized by its dedicated socket tuple even though it rides
    # through the shared UDP RX datapath.
    dhcp_payload = b"udp-rx-dhcp-path"
    dhcp_frame = build_udp_rx_pseudo_frame(
        remote_mac=LEGACY_MAC_WIRES[1],
        remote_ip=LEGACY_IPS[1],
        local_ip=LEGACY_IPS[0],
        remote_port=DHCP_SERVER_PORT,
        local_port=DHCP_CLIENT_PORT,
        payload=dhcp_payload,
    )

    dhcp_send = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(dhcp_frame), clk=bench.clk)
    )
    dhcp_observed = await recv_frame(
        bench.dhcp_sink,
        clk=bench.clk,
        ready_signal=dut.mDhcpTReady,
        timeout_cycles=64,
    )
    await dhcp_send

    assert payload_from_beats(dhcp_observed) == dhcp_payload


@pytest.mark.parametrize("parameters", [pytest.param({}, id="udp_engine_rx_flat_wrapper")])
def test_UdpEngineRx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.udpenginerxflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": UDP_RTL_SOURCES + [WRAPPER_PATH]},
    )
