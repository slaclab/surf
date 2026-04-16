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
# - Sweep: Exercise the ARP engine across localhost resolution, remote lookup
#   plus reply handling, and inbound request-to-reply generation.
# - Stimulus: Exercise the ARP engine with a localhost lookup, a remote lookup
#   that requires an outbound request and inbound reply, and an inbound ARP
#   request addressed to the local host.
# - Checks: The localhost lookup must acknowledge immediately, the remote
#   lookup must emit the expected ARP request then acknowledge with the reply
#   MAC address, and an inbound request must generate a valid reply frame.
# - Timing: The test uses real ready/valid handshakes for both client and MAC
#   sides so request/ack routing remains visible.

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
    IPV4_RTL_SOURCES,
    build_arp_frame,
    ipv4_config_word,
    ipv4_to_bytes,
)


WRAPPER_PATH = "ethernet/IpV4Engine/wrappers/ArpEngineWrapper.vhd"

LOCAL_MAC_WIRE = 0x001122334455
LOCAL_MAC_CFG = mac_config_word_from_wire(LOCAL_MAC_WIRE)
REMOTE_MAC_WIRE = 0x665544332211
LOCAL_IP = "192.168.50.10"
LOCAL_IP_CFG = ipv4_config_word(LOCAL_IP)
REMOTE_IP = "192.168.50.11"


async def setup_arp_bench(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sArp",
        sink_prefix="mArp",
        initial_values={
            "localMac": LOCAL_MAC_CFG,
            "localIp": LOCAL_IP_CFG,
            "mArpTReady": 0,
            "ackTReady": 0,
        },
    )
    s_arp_source = bench.source
    m_arp_sink = bench.sink
    assert s_arp_source is not None
    assert m_arp_sink is not None

    req_source = FlatEmacEndpoint(dut, prefix="req")
    ack_sink = FlatEmacEndpoint(dut, prefix="ack")
    req_source.set_idle()
    return bench, s_arp_source, m_arp_sink, req_source, ack_sink


@cocotb.test()
async def arp_engine_localhost_lookup_test(dut):
    bench, _, _, req_source, ack_sink = await setup_arp_bench(dut)

    localhost_lookup = frame_beats_from_bytes(ipv4_to_bytes(LOCAL_IP))[0]
    req_source.drive(localhost_lookup)
    localhost_ack = await ack_sink.recv(
        clk=bench.clk,
        ready_signal=dut.ackTReady,
    )
    req_source.set_idle()
    assert payload_from_beat(localhost_ack)[:6] == LOCAL_MAC_WIRE.to_bytes(6, byteorder="big")


@cocotb.test()
async def arp_engine_remote_lookup_ack_test(dut):
    bench, s_arp_source, m_arp_sink, req_source, ack_sink = await setup_arp_bench(dut)

    remote_lookup = frame_beats_from_bytes(ipv4_to_bytes(REMOTE_IP))[0]
    # The ARP client request is level-sensitive until the engine resolves the
    # lookup, so hold it asserted across both the outbound request and reply.
    req_source.drive(remote_lookup)
    request_observed = await recv_frame(
        m_arp_sink,
        clk=bench.clk,
        ready_signal=dut.mArpTReady,
        timeout_cycles=256,
    )
    request_expected = build_arp_frame(
        opcode=1,
        sender_mac=LOCAL_MAC_WIRE,
        sender_ip=LOCAL_IP,
        target_mac=0xFFFFFFFFFFFF,
        target_ip=REMOTE_IP,
    )
    assert payload_from_beats(request_observed) == request_expected

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
        send_contiguous_frame(s_arp_source, frame_beats_from_bytes(arp_reply), clk=bench.clk)
    )
    remote_ack = await ack_sink.recv(
        clk=bench.clk,
        ready_signal=dut.ackTReady,
    )
    req_source.set_idle()
    await reply_send
    assert payload_from_beat(remote_ack)[:6] == REMOTE_MAC_WIRE.to_bytes(6, byteorder="big")


@cocotb.test()
async def arp_engine_inbound_request_reply_test(dut):
    bench, s_arp_source, m_arp_sink, _, _ = await setup_arp_bench(dut)

    inbound_request = build_arp_frame(
        opcode=1,
        sender_mac=REMOTE_MAC_WIRE,
        sender_ip=REMOTE_IP,
        target_mac=0xFFFFFFFFFFFF,
        target_ip=LOCAL_IP,
    )
    request_send = cocotb.start_soon(
        send_contiguous_frame(s_arp_source, frame_beats_from_bytes(inbound_request), clk=bench.clk)
    )
    reply_observed = await recv_frame(
        m_arp_sink,
        clk=bench.clk,
        ready_signal=dut.mArpTReady,
        timeout_cycles=256,
    )
    await request_send
    reply_expected = build_arp_frame(
        opcode=2,
        sender_mac=LOCAL_MAC_WIRE,
        sender_ip=LOCAL_IP,
        target_mac=REMOTE_MAC_WIRE,
        target_ip=REMOTE_IP,
        dst_mac=REMOTE_MAC_WIRE,
        src_mac=LOCAL_MAC_WIRE,
    )
    assert payload_from_beats(reply_observed) == reply_expected


@pytest.mark.parametrize("parameters", [pytest.param({}, id="arp_engine_wrapper")])
def test_ArpEngine(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.arpenginewrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": IPV4_RTL_SOURCES + [WRAPPER_PATH]},
    )
