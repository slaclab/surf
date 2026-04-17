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
# - Sweep: Exercise the UDP TX path across normal server traffic and DHCP
#   passthrough traffic.
# - Stimulus: Drive one application payload with a live remote endpoint, then
#   drive one DHCP payload through the dedicated DHCP ingress.
# - Checks: The emitted pseudo-UDP frames must contain the expected source and
#   destination metadata, and `linkUp` must assert once the endpoint is valid.
# - Timing: The tests wait on accepted AXIS transfers instead of assuming fixed
#   latency so the TX state machine and pipeline remain visible.

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
    LEGACY_MAC_WIRES,
    UDP_RTL_SOURCES,
    build_udp_tx_pseudo_frame,
    setup_udp_tx_bench,
    wait_for_link_up,
)


WRAPPER_PATH = "ethernet/UdpEngine/wrappers/UdpEngineTxFlatWrapper.vhd"


@cocotb.test()
async def udp_engine_tx_server_payload_header_test(dut):
    bench = await setup_udp_tx_bench(dut)

    # Wait for the wrapper-visible `linkUp` output before sending traffic so
    # the test matches the contract exposed to the integrated top-level logic.
    await wait_for_link_up(dut.linkUp, clk=bench.clk)

    payload = b"udp-tx-server-payload"
    send_task = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(payload), clk=bench.clk)
    )
    # The sink observes the internal pseudo-header stream, so compare against a
    # pseudo-header builder rather than a full Ethernet wire image.
    observed = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mUdpTReady,
        timeout_cycles=64,
    )
    await send_task

    assert payload_from_beats(observed) == build_udp_tx_pseudo_frame(
        dst_mac=LEGACY_MAC_WIRES[1],
        src_ip=LEGACY_IPS[0],
        dst_ip=LEGACY_IPS[1],
        src_port=8192,
        dst_port=8192,
        payload=payload,
    )


@cocotb.test()
async def udp_engine_tx_dhcp_passthrough_test(dut):
    bench = await setup_udp_tx_bench(dut)

    # DHCP bypasses the normal remote-endpoint registers and always targets
    # the broadcast client/server socket pair.
    dhcp_payload = b"dhcp-client-discover"
    dhcp_send = cocotb.start_soon(
        send_contiguous_frame(bench.dhcp_source, frame_beats_from_bytes(dhcp_payload), clk=bench.clk)
    )
    observed = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mUdpTReady,
        timeout_cycles=64,
    )
    await dhcp_send

    assert payload_from_beats(observed) == build_udp_tx_pseudo_frame(
        dst_mac=0xFFFFFFFFFFFF,
        src_ip="0.0.0.0",
        dst_ip="255.255.255.255",
        src_port=DHCP_CLIENT_PORT,
        dst_port=DHCP_SERVER_PORT,
        payload=dhcp_payload,
    )


@pytest.mark.parametrize("parameters", [pytest.param({}, id="udp_engine_tx_flat_wrapper")])
def test_UdpEngineTx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.udpenginetxflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": UDP_RTL_SOURCES + [WRAPPER_PATH]},
    )
