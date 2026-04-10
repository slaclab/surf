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
# - Sweep: Keep one TxCsum loopback instance but vary the runtime enable matrix
#   to cover full repair, already-valid no-op behavior, and IP-only repair with
#   UDP repair disabled.
# - Stimulus: Send one UDP frame with both checksums cleared, one already-valid
#   UDP frame, and then one more zeroed-checksum frame after disabling UDP
#   checksum insertion.
# - Checks: Full repair must insert both checksums, a valid packet must remain
#   unchanged, and when UDP insertion is disabled the block must only repair
#   the IPv4 header checksum while preserving the zero UDP checksum field.
# - Timing: The wrapper's internal RX checker consumes the repaired stream, so
#   the bench waits on the post-checker frame rather than assuming a fixed
#   internal pipeline delay.

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

    # A packet that already carries correct checksums should emerge unchanged,
    # which proves the repair path does not rewrite valid traffic unnecessarily.
    valid_frame = build_ipv4_udp_frame(
        dst_mac=0x010203040506,
        src_mac=0x112233445566,
        src_ip="10.1.0.1",
        dst_ip="10.1.0.2",
        src_port=0x1111,
        dst_port=0x2222,
        payload=b"already-valid-packet",
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

    # Disable UDP insertion at runtime to prove the block can selectively
    # repair only the IPv4 checksum while leaving the UDP checksum field alone.
    dut.udpCsumEn.value = 0
    ip_only_repaired_frame = build_ipv4_udp_frame(
        dst_mac=0x102030405060,
        src_mac=0xA1A2A3A4A5A6,
        src_ip="10.2.0.1",
        dst_ip="10.2.0.2",
        src_port=0x3003,
        dst_port=0x4004,
        payload=b"ip-only-repair-mode",
        udp_checksum_override=0x0000,
    )
    ip_only_input_frame = build_ipv4_udp_frame(
        dst_mac=0x102030405060,
        src_mac=0xA1A2A3A4A5A6,
        src_ip="10.2.0.1",
        dst_ip="10.2.0.2",
        src_port=0x3003,
        dst_port=0x4004,
        payload=b"ip-only-repair-mode",
        ip_checksum_override=0x0000,
        udp_checksum_override=0x0000,
    )
    ip_only_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(ip_only_input_frame), clk=bench.clk)
    )
    ip_only_observed = await recv_frame(sink, clk=bench.clk)
    await ip_only_send

    assert payload_from_beats(ip_only_observed) == ip_only_repaired_frame
    assert ip_only_observed[-1].iperr == 0
    assert ip_only_observed[-1].udperr == 0
    assert ip_only_observed[-1].eofe == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="ipv4_udp_checksum_insert")])
def test_EthMacTxCsum(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactxcsumloopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
