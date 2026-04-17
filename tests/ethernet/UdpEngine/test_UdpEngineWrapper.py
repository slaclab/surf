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
# - Sweep: Exercise the wrapper-specific AXI-Lite register bank alongside one
#   inbound server-routing path through the integrated MAC/IPv4/UDP stack.
# - Stimulus: Program the client configuration and soft-IP registers through
#   AXI-Lite, then inject a UDP/IP/Ethernet frame addressed to the local host.
# - Checks: AXI-Lite writes and reads must reflect the programmed values, the
#   wrapper must route the UDP payload to the server output, and the server
#   debug readbacks must report the remote endpoint that sent the packet.
# - Timing: The test uses the wrapper's real AXI-Lite and AXIS interfaces so
#   register-bank behavior is verified in the same integration topology as RTL.

from __future__ import annotations

import cocotb
import pytest

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    build_ipv4_udp_frame,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
)
from tests.ethernet.IpV4Engine.ipv4_test_utils import IPV4_RTL_SOURCES
from tests.ethernet.UdpEngine.udp_test_utils import (
    LEGACY_IPS,
    LEGACY_MAC_WIRES,
    UDP_RTL_SOURCES,
    port_config_word,
    ipv4_config_word,
    setup_udp_wrapper_bench,
)


WRAPPER_PATH = "ethernet/UdpEngine/wrappers/UdpEngineWrapperFlatWrapper.vhd"


@cocotb.test()
async def udp_engine_wrapper_axil_and_server_path_test(dut):
    bench = await setup_udp_wrapper_bench(dut)

    await axil_write_u32(bench.axil, 0x000, 0x0020)
    await axil_write_u32(bench.axil, 0x004, ipv4_config_word(LEGACY_IPS[1]))
    await axil_write_u32(bench.axil, 0xFE4, ipv4_config_word("192.168.2.99"))

    assert await axil_read_u32(bench.axil, 0x000) == 0x0020
    assert await axil_read_u32(bench.axil, 0x004) == ipv4_config_word(LEGACY_IPS[1])
    assert await axil_read_u32(bench.axil, 0xFE4) == ipv4_config_word("192.168.2.99")
    assert int(dut.softIp.value) == ipv4_config_word("192.168.2.99")

    inbound_frame = build_ipv4_udp_frame(
        dst_mac=LEGACY_MAC_WIRES[0],
        src_mac=LEGACY_MAC_WIRES[1],
        src_ip=LEGACY_IPS[1],
        dst_ip=LEGACY_IPS[0],
        src_port=0x4567,
        dst_port=8192,
        payload=b"udp-wrapper-server-path",
    )
    inbound_send = cocotb.start_soon(
        send_contiguous_frame(bench.mac_source, frame_beats_from_bytes(inbound_frame), clk=bench.clk)
    )
    server_observed = await recv_frame(
        bench.server_sink,
        clk=bench.clk,
        ready_signal=dut.mServerTReady,
        timeout_cycles=128,
    )
    await inbound_send

    assert payload_from_beats(server_observed) == b"udp-wrapper-server-path"
    assert await axil_read_u32(bench.axil, 0x800) == port_config_word(0x4567)
    assert await axil_read_u32(bench.axil, 0x804) == ipv4_config_word(LEGACY_IPS[1])


@pytest.mark.parametrize("parameters", [pytest.param({}, id="udp_engine_wrapper_flat_wrapper")])
def test_UdpEngineWrapper(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.udpenginewrapperflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": IPV4_RTL_SOURCES + UDP_RTL_SOURCES + [WRAPPER_PATH]},
    )
