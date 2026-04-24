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
# - Sweep: Recreate the legacy RawEthFramerTb integration path with two
#   RawEthFramer instances cross-connected at the MAC boundary, then exercise
#   end-to-end transport in both directions through the combined TX and RX
#   datapaths.
# - Stimulus: Drive framed app payloads into the server side and then the
#   client side of the pair wrapper using the same direct remote-MAC topology
#   as the legacy VHDL bench.
# - Checks: The far-side receiver must recover the original payload, `tDest`,
#   SOF, BCF, and EOFE metadata after the frame traverses TX header insertion,
#   the MAC loopback link, and RX header stripping.
# - Timing: The bench waits on accepted AXIS handshakes and frame completion
#   instead of fixed delays because the two-node path adds both TX and RX state
#   machines to the transport latency.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    recv_frame,
    send_contiguous_frame,
)
from tests.ethernet.RawEthFramer.raw_eth_test_utils import (
    RAWETH_RTL_SOURCES,
    payload_from_raw_beats,
    raw_app_beats_from_bytes,
    setup_raw_eth_pair_bench,
)


WRAPPER_PATH = "ethernet/RawEthFramer/wrappers/RawEthFramerPairFlatWrapper.vhd"


@cocotb.test()
async def raw_eth_pair_matches_legacy_end_to_end_transport_test(dut):
    bench = await setup_raw_eth_pair_bench(dut)

    # Mirror the legacy testbench's main path: source traffic on the server
    # side and observe it emerge on the client side after both RawEthFramers.
    server_payload = b"legacy-server-to-client-transport"
    server_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.server_source,
            raw_app_beats_from_bytes(server_payload, dest=0x00, eofe=1),
            clk=bench.clk,
        )
    )
    client_observed = await recv_frame(
        bench.client_sink,
        clk=bench.clk,
        ready_signal=dut.mClientAppTReady,
        timeout_cycles=256,
    )
    await server_send

    assert payload_from_raw_beats(client_observed) == server_payload
    assert client_observed[0].dest == 0x00
    assert client_observed[0].bcf == 0
    assert client_observed[0].sof == 1
    assert client_observed[-1].eofe == 1

    # Run the reverse path as well so both instances prove TX and RX behavior
    # in the integrated topology instead of only one direction.
    client_payload = b"client-to-server-reverse-path"
    client_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.client_source,
            raw_app_beats_from_bytes(client_payload, dest=0x01, bcf=1),
            clk=bench.clk,
        )
    )
    server_observed = await recv_frame(
        bench.server_sink,
        clk=bench.clk,
        ready_signal=dut.mServerAppTReady,
        timeout_cycles=256,
    )
    await client_send

    assert payload_from_raw_beats(server_observed) == client_payload
    assert server_observed[0].dest == 0xFF
    assert server_observed[0].bcf == 1
    assert server_observed[0].sof == 1
    assert server_observed[-1].eofe == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="raw_eth_framer_pair_flat_wrapper")])
def test_RawEthFramerPair(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rawethframerpairflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": RAWETH_RTL_SOURCES + [WRAPPER_PATH]},
    )
