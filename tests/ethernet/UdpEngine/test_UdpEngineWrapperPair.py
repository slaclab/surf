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
# - Sweep: Recreate the legacy `UdpEngineTb` topology with one client wrapper
#   talking to three server wrappers through a selectable link.
# - Stimulus: Send client traffic after learning server 0, switch the remote IP
#   and physical link to learn server 1, then send a third packet with `tDest`
#   selecting the cached server-0 ARP entry while server 1 remains configured.
# - Checks: The first packet must arrive at server 0, the second at server 1,
#   and the indexed-route packet must return to server 0 just like the legacy
#   bench's post-switch `tDest <= x"01"` case.
# - Timing: The test waits for the integrated wrappers to resolve ARP through
#   their real MAC-side cross-link before launching each UDP payload.

from __future__ import annotations

import cocotb
import pytest
from cocotb.triggers import with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    ROCE_ANALYSIS_SOURCES,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    cycle,
)
from tests.ethernet.IpV4Engine.ipv4_test_utils import IPV4_RTL_SOURCES
from tests.ethernet.UdpEngine.udp_test_utils import (
    LEGACY_IP_CFGS,
    UDP_RTL_SOURCES,
    setup_udp_wrapper_pair_bench,
    wait_for_pair_arp_resolution,
)


WRAPPER_PATH = "ethernet/UdpEngine/wrappers/UdpEngineWrapperPairFlatWrapper.vhd"


@cocotb.test()
async def udp_engine_wrapper_pair_matches_legacy_route_switching_test(dut):
    bench = await setup_udp_wrapper_pair_bench(dut)

    # The legacy bench learns server 0 first, so leave time for the client
    # wrapper to emit and resolve its initial ARP transaction.
    await wait_for_pair_arp_resolution(clk=bench.clk)
    payload0 = b"legacy-path-server0"
    send0 = cocotb.start_soon(
        send_contiguous_frame(bench.client_source, frame_beats_from_bytes(payload0), clk=bench.clk)
    )
    observed0 = await with_timeout(
        recv_frame(
            bench.server_sinks[0],
            clk=bench.clk,
            ready_signal=dut.mServer0TReady,
            timeout_cycles=1024,
        ),
        10,
        "us",
    )
    await with_timeout(send0, 10, "us")
    assert payload_from_beats(observed0) == payload0

    # Now retarget the remote IP and the selected physical link so the second
    # transfer follows server 1, matching the route switch in `UdpEngineTb`.
    dut.clientRemoteIp.value = LEGACY_IP_CFGS[2]
    dut.selectedServer.value = 2
    await wait_for_pair_arp_resolution(clk=bench.clk)
    payload1 = b"legacy-path-server1"
    send1 = cocotb.start_soon(
        send_contiguous_frame(bench.client_source, frame_beats_from_bytes(payload1), clk=bench.clk)
    )
    observed1 = await with_timeout(
        recv_frame(
            bench.server_sinks[1],
            clk=bench.clk,
            ready_signal=dut.mServer1TReady,
            timeout_cycles=1024,
        ),
        10,
        "us",
    )
    await with_timeout(send1, 10, "us")
    assert payload_from_beats(observed1) == payload1

    # Finally switch only the physical link back to server 0 and use `tDest=1`
    # so the client reuses its cached indexed ARP entry from the first route.
    dut.selectedServer.value = 1
    await cycle(bench.clk, 8)
    payload2 = b"legacy-indexed-server0"
    send2 = cocotb.start_soon(
        send_contiguous_frame(
            bench.client_source,
            frame_beats_from_bytes(payload2, dest=1),
            clk=bench.clk,
        )
    )
    observed2 = await with_timeout(
        recv_frame(
            bench.server_sinks[0],
            clk=bench.clk,
            ready_signal=dut.mServer0TReady,
            timeout_cycles=1024,
        ),
        10,
        "us",
    )
    await with_timeout(send2, 10, "us")
    assert payload_from_beats(observed2) == payload2


@pytest.mark.parametrize("parameters", [pytest.param({}, id="udp_engine_wrapper_pair_flat_wrapper")])
def test_UdpEngineWrapperPair(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.udpenginewrapperpairflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ETHMAC_RTL_SOURCES + ROCE_ANALYSIS_SOURCES + IPV4_RTL_SOURCES + UDP_RTL_SOURCES + [WRAPPER_PATH]
        },
    )
