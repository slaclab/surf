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
# - Sweep: Cover both meaningful TX routes in one build: remote wire output
#   and localhost short-circuit output.
# - Stimulus: Feed the TX engine with curated pseudo-header traffic for one
#   remote UDP packet and one localhost-routed UDP packet.
# - Checks: The remote packet must emerge as a fully framed Ethernet/IPv4
#   stream on the wire output, and the localhost packet must be diverted to the
#   localhost output instead of the wire output.
# - Timing: The test drives one packet at a time and waits on the selected
#   output stream so route-selection bugs are obvious in waveforms.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    FlatEmacEndpoint,
    expect_no_output,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)
from tests.ethernet.IpV4Engine.ipv4_test_utils import (
    IPV4_RTL_SOURCES,
    build_ipv4_tx_pseudo_frame,
    build_ipv4_tx_wire_frame,
    build_ipv4_udp_payload,
)


WRAPPER_PATH = "ethernet/IpV4Engine/wrappers/IpV4EngineTxWrapper.vhd"

LOCAL_MAC_WIRE = 0x001122334455
LOCAL_MAC_CFG = mac_config_word_from_wire(LOCAL_MAC_WIRE)
REMOTE_MAC_WIRE = 0x665544332211
LOCAL_IP = "192.168.40.10"
REMOTE_IP = "192.168.40.11"


@cocotb.test()
async def ipv4_tx_generates_wire_and_localhost_paths_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sProt",
        initial_values={
            "localMac": LOCAL_MAC_CFG,
            "mIpv4TReady": 0,
            "mLocalTReady": 0,
        },
    )
    source = bench.source
    assert source is not None

    wire_sink = FlatEmacEndpoint(dut, prefix="mIpv4")
    local_sink = FlatEmacEndpoint(dut, prefix="mLocal")

    udp_payload = build_ipv4_udp_payload(
        src_port=0x1357,
        dst_port=0x2468,
        payload=b"tx-remote-path-payload",
        src_ip=LOCAL_IP,
        dst_ip=REMOTE_IP,
    )
    remote_request = build_ipv4_tx_pseudo_frame(
        dst_mac=REMOTE_MAC_WIRE,
        src_ip=LOCAL_IP,
        dst_ip=REMOTE_IP,
        protocol=0x11,
        payload=udp_payload,
    )
    remote_expected = build_ipv4_tx_wire_frame(
        dst_mac=REMOTE_MAC_WIRE,
        src_mac=LOCAL_MAC_WIRE,
        src_ip=LOCAL_IP,
        dst_ip=REMOTE_IP,
        protocol=0x11,
        payload=udp_payload,
    )

    remote_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(remote_request), clk=bench.clk)
    )
    remote_observed = await recv_frame(
        wire_sink,
        clk=bench.clk,
        ready_signal=dut.mIpv4TReady,
        timeout_cycles=128,
    )
    await remote_send
    assert payload_from_beats(remote_observed) == remote_expected
    await expect_no_output(local_sink, clk=bench.clk, cycles=8)

    localhost_payload = build_ipv4_udp_payload(
        src_port=0x1001,
        dst_port=0x1002,
        payload=b"tx-localhost-shortcut",
        src_ip=LOCAL_IP,
        dst_ip="192.168.40.99",
    )
    localhost_request = build_ipv4_tx_pseudo_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_ip=LOCAL_IP,
        dst_ip="192.168.40.99",
        protocol=0x11,
        payload=localhost_payload,
    )
    localhost_expected = build_ipv4_tx_wire_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=LOCAL_MAC_WIRE,
        src_ip=LOCAL_IP,
        dst_ip="192.168.40.99",
        protocol=0x11,
        payload=localhost_payload,
        identification=0x0001,
    )

    local_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(localhost_request), clk=bench.clk)
    )
    local_observed = await recv_frame(
        local_sink,
        clk=bench.clk,
        ready_signal=dut.mLocalTReady,
        timeout_cycles=128,
    )
    await local_send
    assert payload_from_beats(local_observed) == localhost_expected
    await expect_no_output(wire_sink, clk=bench.clk, cycles=8)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="ipv4_tx_wrapper")])
def test_IpV4EngineTx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ipv4enginetxwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": IPV4_RTL_SOURCES + [WRAPPER_PATH]},
    )
