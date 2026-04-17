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
# - Sweep: Exercise the UDP top across the client ARP-assisted TX path and the
#   server RX path.
# - Stimulus: Allow the client side to request ARP resolution, acknowledge it,
#   then send an outbound client payload while separately injecting a server-
#   targeted pseudo-UDP frame into the inbound path.
# - Checks: The top must emit the expected ARP lookup and outbound pseudo-UDP
#   frame on the client side, and must route inbound server traffic to the
#   exposed server output with the header removed.
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
    LEGACY_MAC_CFGS,
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

    arp_request = await bench.arp_req_sink.recv(
        clk=bench.clk,
        ready_signal=dut.arpReqTReady,
    )
    assert payload_from_beat(arp_request)[:4] == ipv4_to_bytes(LEGACY_IPS[1])

    arp_ack = frame_beats_from_bytes(LEGACY_MAC_WIRES[1].to_bytes(6, byteorder="big"))
    ack_send = cocotb.start_soon(send_contiguous_frame(bench.arp_ack_source, arp_ack, clk=bench.clk))
    await cycle(bench.clk, 6)
    await ack_send

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


@pytest.mark.parametrize("parameters", [pytest.param({}, id="udp_engine_top_flat_wrapper")])
def test_UdpEngine(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.udpenginetopflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": UDP_RTL_SOURCES + [WRAPPER_PATH]},
    )
