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
# - Sweep: Cover the ICMP reply block with one valid local echo request plus
#   two representative reject cases: wrong destination IP and non-echo type.
# - Stimulus: Present ICMP pseudo-header traffic exactly as IpV4EngineRx would
#   emit it, including a valid echo request, a non-local request, and a
#   non-echo ICMP packet.
# - Checks: Only an echo request addressed to the configured local IP may
#   produce a response, and that response must be a correctly swapped echo
#   reply pseudo-frame.
# - Timing: The bench waits on AXIS visibility so the assertions remain stable
#   across internal pipeline depth changes.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    expect_no_output,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)
from tests.ethernet.IpV4Engine.ipv4_test_utils import (
    IPV4_RTL_SOURCES,
    build_icmp_echo_packet,
    build_icmp_echo_reply_packet,
    build_ipv4_rx_pseudo_frame,
    build_ipv4_tx_pseudo_frame,
    ipv4_config_word,
)


WRAPPER_PATH = "ethernet/IpV4Engine/wrappers/IcmpEngineWrapper.vhd"

LOCAL_IP = "192.168.20.10"
LOCAL_IP_CFG = ipv4_config_word(LOCAL_IP)
REMOTE_IP = "192.168.20.11"
REMOTE_MAC = 0x665544332211


@cocotb.test()
async def icmp_engine_reply_filtering_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "localIp": LOCAL_IP_CFG,
            "mAxisTReady": 0,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    echo_payload = b"icmp-echo-request-payload"
    echo_request = build_ipv4_rx_pseudo_frame(
        src_mac=REMOTE_MAC,
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
        protocol=0x01,
        payload=build_icmp_echo_packet(
            payload=echo_payload,
            identifier=0x3344,
            sequence=0x0102,
        ),
    )
    expected_reply = build_ipv4_tx_pseudo_frame(
        dst_mac=REMOTE_MAC,
        src_ip=LOCAL_IP,
        dst_ip=REMOTE_IP,
        protocol=0x01,
        payload=build_icmp_echo_reply_packet(
            payload=echo_payload,
            identifier=0x3344,
            sequence=0x0102,
        ),
    )

    reply_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(echo_request), clk=bench.clk)
    )
    reply_observed = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=128,
    )
    await reply_send
    assert payload_from_beats(reply_observed) == expected_reply

    non_local_request = build_ipv4_rx_pseudo_frame(
        src_mac=REMOTE_MAC,
        src_ip=REMOTE_IP,
        dst_ip="192.168.20.99",
        protocol=0x01,
        payload=build_icmp_echo_packet(payload=b"non-local"),
    )
    await send_contiguous_frame(source, frame_beats_from_bytes(non_local_request), clk=bench.clk)
    await expect_no_output(sink, clk=bench.clk, cycles=12)

    non_echo_message = build_ipv4_rx_pseudo_frame(
        src_mac=REMOTE_MAC,
        src_ip=REMOTE_IP,
        dst_ip=LOCAL_IP,
        protocol=0x01,
        payload=build_icmp_echo_packet(
            payload=b"not-an-echo-request",
            icmp_type=0x03,
            code=0x01,
        ),
    )
    await send_contiguous_frame(source, frame_beats_from_bytes(non_echo_message), clk=bench.clk)
    await expect_no_output(sink, clk=bench.clk, cycles=12)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="icmp_engine_wrapper")])
def test_IcmpEngine(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.icmpenginewrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": IPV4_RTL_SOURCES + [WRAPPER_PATH]},
    )
