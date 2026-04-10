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
# - Sweep: Keep one IPv4/UDP checksum-enabled loopback case where the TX repair
#   block feeds the RX checker wrapper directly.
# - Stimulus: Send one IPv4/UDP packet with the IP and UDP checksum fields
#   cleared to zero.
# - Checks: The emitted packet bytes must match the software-computed checksum-
#   inserted frame, and the RX checker must report no terminal checksum errors.
# - Timing: The wrapper's internal RX checker absorbs the post-TX packet, so
#   the bench waits for the visible checked output frame rather than assuming a
#   fixed internal pipeline depth.

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


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTxCsumLoopbackWrapper.vhd"


@cocotb.test()
async def eth_mac_tx_csum_test(dut):
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

    payload = b"tx-checksum-fixup"
    repaired_frame = build_ipv4_udp_frame(
        dst_mac=0x112233445566,
        src_mac=0xAABBCCDDEEFF,
        src_ip="10.0.0.1",
        dst_ip="10.0.0.2",
        src_port=0x1001,
        dst_port=0x2002,
        payload=payload,
    )
    input_frame = build_ipv4_udp_frame(
        dst_mac=0x112233445566,
        src_mac=0xAABBCCDDEEFF,
        src_ip="10.0.0.1",
        dst_ip="10.0.0.2",
        src_port=0x1001,
        dst_port=0x2002,
        payload=payload,
        ip_checksum_override=0x0000,
        udp_checksum_override=0x0000,
    )

    send_task = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(input_frame), clk=bench.clk)
    )
    observed_beats = await recv_frame(sink, clk=bench.clk)
    await send_task

    assert payload_from_beats(observed_beats) == repaired_frame
    assert observed_beats[-1].iperr == 0
    assert observed_beats[-1].tcperr == 0
    assert observed_beats[-1].udperr == 0
    assert observed_beats[-1].eofe == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="ipv4_udp_checksum_insert")])
def test_EthMacTxCsum(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactxcsumloopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
