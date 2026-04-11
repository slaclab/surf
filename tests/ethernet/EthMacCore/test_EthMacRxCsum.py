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
# - Sweep: Keep one checksum-enabled instance but cover valid UDP traffic, bad
#   UDP checksum, bad IPv4 header checksum, and a non-UDP IPv4 packet.
# - Stimulus: Send one good IPv4/UDP frame, one with a deliberately wrong UDP
#   checksum, one with a deliberately wrong IPv4 checksum, and one ICMP-style
#   IPv4 packet that should bypass transport checksum handling.
# - Checks: Good traffic must pass cleanly, bad UDP must assert `UDPERR` and
#   `EOFE`, bad IP must assert `IPERR`, and non-UDP traffic must not spuriously
#   set UDP/TCP error flags.
# - Timing: The RX checksum block has an internal pipeline, so every case waits
#   on the visible output frame instead of assuming a fixed internal latency.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    build_ethernet_frame,
    build_ipv4_header,
    build_ipv4_udp_frame,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxCsumWrapper.vhd"


@cocotb.test()
async def eth_mac_rx_csum_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "ipCsumEn": 1,
            "tcpCsumEn": 0,
            "udpCsumEn": 1,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    payload = b"rx-checksum-good"
    valid_frame = build_ipv4_udp_frame(
        dst_mac=0x020304050607,
        src_mac=0x0A0B0C0D0E0F,
        src_ip="192.168.1.10",
        dst_ip="192.168.1.20",
        src_port=0x1234,
        dst_port=0x5678,
        payload=payload,
    )
    valid_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(valid_frame), clk=bench.clk)
    )
    valid_observed = await recv_frame(sink, clk=bench.clk)
    await valid_send

    assert payload_from_beats(valid_observed) == valid_frame
    assert valid_observed[-1].iperr == 0
    assert valid_observed[-1].udperr == 0
    assert valid_observed[-1].eofe == 0

    bad_udp_frame = build_ipv4_udp_frame(
        dst_mac=0x020304050607,
        src_mac=0x0A0B0C0D0E0F,
        src_ip="192.168.1.10",
        dst_ip="192.168.1.20",
        src_port=0x1234,
        dst_port=0x5678,
        payload=payload,
        udp_checksum_override=0x0001,
    )
    bad_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(bad_udp_frame), clk=bench.clk)
    )
    bad_observed = await recv_frame(sink, clk=bench.clk)
    await bad_send

    assert payload_from_beats(bad_observed) == bad_udp_frame
    assert bad_observed[-1].iperr == 0
    assert bad_observed[-1].udperr == 1
    assert bad_observed[-1].eofe == 1

    bad_ip_frame = build_ipv4_udp_frame(
        dst_mac=0x020304050607,
        src_mac=0x0A0B0C0D0E0F,
        src_ip="192.168.1.10",
        dst_ip="192.168.1.20",
        src_port=0x1234,
        dst_port=0x5678,
        payload=payload,
        ip_checksum_override=0x0001,
    )
    bad_ip_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(bad_ip_frame), clk=bench.clk)
    )
    bad_ip_observed = await recv_frame(sink, clk=bench.clk)
    await bad_ip_send

    assert payload_from_beats(bad_ip_observed) == bad_ip_frame
    assert bad_ip_observed[-1].iperr == 1
    assert bad_ip_observed[-1].tcperr == 0
    assert bad_ip_observed[-1].udperr == 0

    icmp_payload = b"icmp-is-not-udp"
    icmp_frame = build_ethernet_frame(
        dst_mac=0x020304050607,
        src_mac=0x0A0B0C0D0E0F,
        eth_type=0x0800,
        payload=build_ipv4_header(
            src_ip="192.168.1.10",
            dst_ip="192.168.1.20",
            protocol=0x01,
            payload_length=len(icmp_payload),
        )
        + icmp_payload,
    )
    icmp_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(icmp_frame), clk=bench.clk)
    )
    icmp_observed = await recv_frame(sink, clk=bench.clk)
    await icmp_send

    assert payload_from_beats(icmp_observed) == icmp_frame
    assert icmp_observed[-1].iperr == 0
    assert icmp_observed[-1].tcperr == 0
    assert icmp_observed[-1].udperr == 0
    assert icmp_observed[-1].eofe == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="ipv4_udp_checksum_check")])
def test_EthMacRxCsum(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxcsumwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
