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
# - Sweep: Keep one IPv4/UDP checksum-enabled configuration and exercise both a
#   valid packet and an invalid-UDP-checksum packet.
# - Stimulus: Send one correctly checksummed IPv4/UDP Ethernet frame and then
#   send the same packet shape with a deliberately wrong UDP checksum.
# - Checks: The valid packet must pass without error bits, while the bad packet
#   must still pass through but mark the terminal beat with `UDPERR` and
#   `EOFE`, matching the public RX checksum contract.
# - Timing: The RX checksum block has an internal pipeline, so the test waits
#   for the visible output frame rather than assuming a fixed beat delay.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.eth_mac.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
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


@pytest.mark.parametrize("parameters", [pytest.param({}, id="ipv4_udp_checksum_check")])
def test_EthMacRxCsum(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxcsumwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
