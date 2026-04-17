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
# - Sweep: Exercise the UDP top across client TX/RX coverage and server TX/RX
#   coverage in the assembled ARP-integrated topology.
# - Stimulus: Allow the client side to request ARP resolution and acknowledge
#   it, inject server- and client-targeted pseudo-UDP frames into the inbound
#   path, and send one outbound server payload after the server metadata has
#   been learned.
# - Checks: The top must emit the expected ARP lookup and outbound client
#   pseudo-UDP frame, route inbound server and client traffic to the matching
#   outputs with the UDP header removed, and reuse learned server endpoint
#   metadata for an outbound server reply.
# - Timing: The bench waits on actual AXIS handshakes on all exposed streams so
#   the integrated ARP, TX, and RX state transitions are observed in flight.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    frame_beats_from_bytes,
    payload_from_beat,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    cycle,
)
from tests.ethernet.UdpEngine.udp_test_utils import (
    LEGACY_IPS,
    LEGACY_MAC_WIRES,
    UDP_RTL_SOURCES,
    build_udp_rx_pseudo_frame,
    build_udp_tx_pseudo_frame,
    ipv4_to_bytes,
    setup_udp_top_bench,
)


WRAPPER_PATH = "ethernet/UdpEngine/wrappers/UdpEngineTopFlatWrapper.vhd"


@cocotb.test()
async def udp_engine_client_arp_then_transmit_test(dut):
    bench = await setup_udp_top_bench(dut)

    # The integrated top first needs an ARP resolution for the configured
    # client remote IP before any outbound client payload can be emitted.
    arp_request = await bench.arp_req_sink.recv(
        clk=bench.clk,
        ready_signal=dut.arpReqTReady,
    )
    assert payload_from_beat(arp_request)[:4] == ipv4_to_bytes(LEGACY_IPS[1])

    # Feed back the learned MAC so the client-side transmit path can continue.
    arp_ack = frame_beats_from_bytes(LEGACY_MAC_WIRES[1].to_bytes(6, byteorder="big"))
    ack_send = cocotb.start_soon(send_contiguous_frame(bench.arp_ack_source, arp_ack, clk=bench.clk))
    await cycle(bench.clk, 6)
    await ack_send

    # Once ARP is resolved, the outbound client payload should emerge on the
    # shared UDP transmit stream with the expected pseudo-header fields.
    client_payload = b"udp-top-client-path"
    client_send = cocotb.start_soon(
        send_contiguous_frame(bench.client_source, frame_beats_from_bytes(client_payload), clk=bench.clk)
    )
    udp_observed = await recv_frame(
        bench.udp_sink,
        clk=bench.clk,
        ready_signal=dut.mUdpTReady,
        timeout_cycles=64,
    )
    await client_send

    assert payload_from_beats(udp_observed) == build_udp_tx_pseudo_frame(
        dst_mac=LEGACY_MAC_WIRES[1],
        src_ip=LEGACY_IPS[0],
        dst_ip=LEGACY_IPS[1],
        src_port=8193,
        dst_port=8192,
        payload=client_payload,
    )


@cocotb.test()
async def udp_engine_server_rx_path_test(dut):
    bench = await setup_udp_top_bench(dut)

    # The same top-level wrapper also exposes the inbound server-routing path,
    # so inject one server-targeted frame and confirm the UDP header is gone.
    server_payload = b"udp-top-server-path"
    server_frame = build_udp_rx_pseudo_frame(
        remote_mac=LEGACY_MAC_WIRES[1],
        remote_ip=LEGACY_IPS[1],
        local_ip=LEGACY_IPS[0],
        remote_port=0x4567,
        local_port=8192,
        payload=server_payload,
    )
    server_send = cocotb.start_soon(
        send_contiguous_frame(bench.udp_source, frame_beats_from_bytes(server_frame), clk=bench.clk)
    )
    server_observed = await recv_frame(
        bench.server_sink,
        clk=bench.clk,
        ready_signal=dut.mServerTReady,
        timeout_cycles=64,
    )
    await server_send

    assert payload_from_beats(server_observed) == server_payload


@cocotb.test()
async def udp_engine_client_rx_path_test(dut):
    bench = await setup_udp_top_bench(dut)

    client_payload = b"udp-top-client-rx-path"
    client_frame = build_udp_rx_pseudo_frame(
        remote_mac=LEGACY_MAC_WIRES[1],
        remote_ip=LEGACY_IPS[1],
        local_ip=LEGACY_IPS[0],
        remote_port=0x6789,
        local_port=8193,
        payload=client_payload,
    )
    client_send = cocotb.start_soon(
        send_contiguous_frame(bench.udp_source, frame_beats_from_bytes(client_frame), clk=bench.clk)
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
async def udp_engine_server_tx_path_test(dut):
    bench = await setup_udp_top_bench(dut)

    inbound_payload = b"udp-top-server-metadata"
    inbound_frame = build_udp_rx_pseudo_frame(
        remote_mac=LEGACY_MAC_WIRES[1],
        remote_ip=LEGACY_IPS[1],
        local_ip=LEGACY_IPS[0],
        remote_port=0x4567,
        local_port=8192,
        payload=inbound_payload,
    )
    inbound_send = cocotb.start_soon(
        send_contiguous_frame(bench.udp_source, frame_beats_from_bytes(inbound_frame), clk=bench.clk)
    )
    inbound_observed = await recv_frame(
        bench.server_sink,
        clk=bench.clk,
        ready_signal=dut.mServerTReady,
        timeout_cycles=64,
    )
    await inbound_send
    assert payload_from_beats(inbound_observed) == inbound_payload

    outbound_payload = b"udp-top-server-tx-path"
    outbound_send = cocotb.start_soon(
        send_contiguous_frame(bench.server_source, frame_beats_from_bytes(outbound_payload), clk=bench.clk)
    )
    outbound_observed = await recv_frame(
        bench.udp_sink,
        clk=bench.clk,
        ready_signal=dut.mUdpTReady,
        timeout_cycles=64,
    )
    await outbound_send

    assert payload_from_beats(outbound_observed) == build_udp_tx_pseudo_frame(
        dst_mac=LEGACY_MAC_WIRES[1],
        src_ip=LEGACY_IPS[0],
        dst_ip=LEGACY_IPS[1],
        src_port=8192,
        dst_port=0x4567,
        payload=outbound_payload,
    )


@pytest.mark.parametrize("parameters", [pytest.param({}, id="udp_engine_top_flat_wrapper")])
def test_UdpEngine(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.udpenginetopflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": UDP_RTL_SOURCES + [WRAPPER_PATH]},
    )
