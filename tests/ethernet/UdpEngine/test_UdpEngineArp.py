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
# - Sweep: Exercise the UDP ARP helper across a table-hit path and a miss path
#   that requires an outbound request and inbound acknowledgement.
# - Stimulus: Present a configured remote IP with either an already-populated
#   ARP-table hit or an empty table entry followed by an ARP-ack beat.
# - Checks: Table hits must publish the cached remote MAC without emitting a
#   request, while misses must raise a request for the configured IP and then
#   latch/write back the acknowledged MAC.
# - Timing: The tests keep the ARP request asserted until the helper reaches a
#   stable outcome, matching the level-sensitive contract used in the real top.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    FlatEmacEndpoint,
    frame_beats_from_bytes,
    payload_from_beat,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
    cycle,
)
from tests.ethernet.UdpEngine.udp_test_utils import (
    LEGACY_IP_CFGS,
    LEGACY_IPS,
    LEGACY_MAC_CFGS,
    LEGACY_MAC_WIRES,
    UDP_RTL_SOURCES,
    ipv4_to_bytes,
)


WRAPPER_PATH = "ethernet/UdpEngine/wrappers/UdpEngineArpFlatWrapper.vhd"


async def setup_udp_arp_bench(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        initial_values={
            "localIp": LEGACY_IP_CFGS[0],
            "arpTabFound": 0,
            "arpTabMacAddr": 0,
            "clientRemoteDetValid": 0,
            "clientRemoteDetIp": 0,
            "clientRemoteIp": 0,
            "arpReqTReady": 0,
            "arpAckTValid": 0,
            "arpAckTData": 0,
            "arpAckTKeep": 0,
            "arpAckTLast": 0,
            "arpAckSof": 0,
            "arpAckEofe": 0,
        },
    )
    arp_req_sink = FlatEmacEndpoint(dut, prefix="arpReq")
    arp_ack_source = FlatEmacEndpoint(dut, prefix="arpAck")
    arp_ack_source.set_idle()
    return bench, arp_req_sink, arp_ack_source


@cocotb.test()
async def udp_engine_arp_uses_cached_mac_without_request_test(dut):
    bench, _, _ = await setup_udp_arp_bench(dut)

    dut.clientRemoteIp.value = LEGACY_IP_CFGS[1]
    dut.arpTabFound.value = 1
    dut.arpTabMacAddr.value = LEGACY_MAC_CFGS[1]
    await cycle(bench.clk, 6)

    assert int(dut.clientRemoteMac.value) == LEGACY_MAC_CFGS[1]
    assert int(dut.arpReqTValid.value) == 0
    assert int(dut.arpTabIpWe.value) == 0


@cocotb.test()
async def udp_engine_arp_request_ack_round_trip_test(dut):
    bench, arp_req_sink, arp_ack_source = await setup_udp_arp_bench(dut)

    dut.clientRemoteIp.value = LEGACY_IP_CFGS[1]
    await cycle(bench.clk, 6)

    # A miss should emit an outbound ARP request carrying the configured
    # remote IP in the low 32 bits.
    request_observed = await arp_req_sink.recv(
        clk=bench.clk,
        ready_signal=dut.arpReqTReady,
    )
    assert payload_from_beat(request_observed)[:4] == ipv4_to_bytes(LEGACY_IPS[1])

    arp_ack = frame_beats_from_bytes(LEGACY_MAC_WIRES[1].to_bytes(6, byteorder="big"))
    ack_send = cocotb.start_soon(send_contiguous_frame(arp_ack_source, arp_ack, clk=bench.clk))
    await cycle(bench.clk, 4)
    await ack_send

    assert int(dut.clientRemoteMac.value) == LEGACY_MAC_CFGS[1]
    assert int(dut.arpTabMacAddrW.value) == LEGACY_MAC_CFGS[1]


@pytest.mark.parametrize("parameters", [pytest.param({}, id="udp_engine_arp_flat_wrapper")])
def test_UdpEngineArp(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.udpenginearpflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": UDP_RTL_SOURCES + [WRAPPER_PATH]},
    )
