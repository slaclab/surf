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
# - Stimulus: Feed the de-mux with full Ethernet frames that exercise the ARP,
#   IPv4, broadcast, foreign-destination, and bad-version cases.
# - Checks: ARP and IPv4 frames for the local or broadcast MAC must be
#   forwarded unchanged to the correct output, while foreign or malformed IPv4
#   headers must be dropped silently.
# - Timing: The test waits on visible AXIS transfers instead of fixed cycle
#   counts because the wrapper exposes real ready/valid behavior.

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
    build_arp_frame,
    build_ipv4_frame,
)


WRAPPER_PATH = "ethernet/IpV4Engine/wrappers/IpV4EngineDeMuxWrapper.vhd"

LOCAL_MAC_WIRE = 0x001122334455
LOCAL_MAC_CFG = mac_config_word_from_wire(LOCAL_MAC_WIRE)
REMOTE_MAC_WIRE = 0x665544332211


@cocotb.test()
async def ipv4_demux_routes_and_drops_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sMac",
        initial_values={
            "localMac": LOCAL_MAC_CFG,
            "mArpTReady": 0,
            "mIpv4TReady": 0,
        },
    )
    source = bench.source
    assert source is not None

    arp_sink = FlatEmacEndpoint(dut, prefix="mArp")
    ipv4_sink = FlatEmacEndpoint(dut, prefix="mIpv4")

    arp_frame = build_arp_frame(
        opcode=1,
        sender_mac=REMOTE_MAC_WIRE,
        sender_ip="192.168.10.10",
        target_mac=0xFFFFFFFFFFFF,
        target_ip="192.168.10.20",
    )
    arp_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(arp_frame), clk=bench.clk)
    )
    arp_observed = await recv_frame(
        arp_sink,
        clk=bench.clk,
        ready_signal=dut.mArpTReady,
        timeout_cycles=128,
    )
    await arp_send
    assert payload_from_beats(arp_observed) == arp_frame
    await expect_no_output(ipv4_sink, clk=bench.clk, cycles=8)

    broadcast_ipv4 = build_ipv4_frame(
        dst_mac=0xFFFFFFFFFFFF,
        src_mac=REMOTE_MAC_WIRE,
        src_ip="192.168.10.10",
        dst_ip="192.168.10.20",
        protocol=0x11,
        payload=b"demux-broadcast-ipv4-payload",
    )
    ipv4_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(broadcast_ipv4), clk=bench.clk)
    )
    ipv4_observed = await recv_frame(
        ipv4_sink,
        clk=bench.clk,
        ready_signal=dut.mIpv4TReady,
        timeout_cycles=128,
    )
    await ipv4_send
    assert payload_from_beats(ipv4_observed) == broadcast_ipv4
    await expect_no_output(arp_sink, clk=bench.clk, cycles=8)

    foreign_ipv4 = build_ipv4_frame(
        dst_mac=0x0A0B0C0D0E0F,
        src_mac=REMOTE_MAC_WIRE,
        src_ip="192.168.10.10",
        dst_ip="192.168.10.20",
        protocol=0x11,
        payload=b"foreign-destination-drop",
    )
    await send_contiguous_frame(source, frame_beats_from_bytes(foreign_ipv4), clk=bench.clk)
    await expect_no_output(arp_sink, clk=bench.clk, cycles=12)
    await expect_no_output(ipv4_sink, clk=bench.clk, cycles=12)

    bad_version_ipv4 = bytearray(
        build_ipv4_frame(
            dst_mac=LOCAL_MAC_WIRE,
            src_mac=REMOTE_MAC_WIRE,
            src_ip="192.168.10.10",
            dst_ip="192.168.10.20",
            protocol=0x11,
            payload=b"bad-version-drop",
        )
    )
    # The de-mux only accepts IPv4 version/header-length byte 0x45.
    bad_version_ipv4[14] = 0x46
    await send_contiguous_frame(source, frame_beats_from_bytes(bytes(bad_version_ipv4)), clk=bench.clk)
    await expect_no_output(arp_sink, clk=bench.clk, cycles=12)
    await expect_no_output(ipv4_sink, clk=bench.clk, cycles=12)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="ipv4_demux_wrapper")])
def test_IpV4EngineDeMux(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ipv4enginedemuxwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": IPV4_RTL_SOURCES + [WRAPPER_PATH]},
    )
