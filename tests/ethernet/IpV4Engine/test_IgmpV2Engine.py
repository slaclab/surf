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
# - Sweep: Cover the IGMPv2 leaf across the main transmit and receive branches:
#   power-up membership reports, general-query-triggered reports, and report
#   suppression when another host has already advertised the same group.
# - Stimulus: Present IGMP pseudo-header traffic exactly as IpV4EngineRx would
#   emit it, including valid membership reports and queries plus an invalid
#   checksum query that should be ignored.
# - Checks: Configured multicast groups must emit the expected pseudo-header
#   report frames, a valid general query must re-arm reporting, and an inbound
#   membership report with a matching group address must suppress the local
#   pending report for that group.
# - Timing: The wrapper runs the engine at a tiny simulated `CLK_FREQ_G` so the
#   100 ms tick is one cycle, but the bench still waits on AXIS visibility
#   rather than assuming exact internal cycle counts for report emission.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    cycle,
    expect_no_output,
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    setup_flat_emac_testbench,
)
from tests.ethernet.IpV4Engine.ipv4_test_utils import (
    IP_PROTOCOL_IGMP,
    IPV4_RTL_SOURCES,
    build_igmp_membership_query_packet,
    build_igmp_membership_report_packet,
    build_ipv4_rx_pseudo_frame,
    igmp_group_mac,
    ipv4_config_word,
    ipv4_to_bytes,
)


WRAPPER_PATH = "ethernet/IpV4Engine/wrappers/IgmpV2EngineWrapper.vhd"

LOCAL_IP = "192.168.70.10"
LOCAL_IP_CFG = ipv4_config_word(LOCAL_IP)
ROUTER_IP = "192.168.70.1"
GROUP0 = "239.1.2.3"
GROUP0_CFG = ipv4_config_word(GROUP0)
GROUP1 = "239.9.8.7"
GROUP1_CFG = ipv4_config_word(GROUP1)
OTHER_HOST_IP = "192.168.70.44"
ROUTER_MAC = 0x665544332211
OTHER_HOST_MAC = 0x112233445566


async def setup_igmp_bench(dut, *, group0_cfg: int, group1_cfg: int):
    bench = await setup_flat_emac_testbench(
        dut,
        clk_name="clk",
        rst_name="rst",
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "localIp": LOCAL_IP_CFG,
            "igmpIp0": group0_cfg,
            "igmpIp1": group1_cfg,
            "mAxisTReady": 0,
        },
    )
    assert bench.source is not None
    assert bench.sink is not None
    return bench


def expected_report_frame(*, group_ip: str) -> bytes:
    group_mac = igmp_group_mac(group_ip).to_bytes(6, byteorder="big")
    return (
        group_mac
        + b"\x00\x00"
        + ipv4_to_bytes(LOCAL_IP)
        + ipv4_to_bytes(group_ip)
        # IgmpV2Engine leaves the low 32 bits of beat 1 untouched, and the
        # downstream IPv4 TX path ignores them. At the leaf boundary they still
        # appear as the carried-over low 32 bits of the multicast MAC.
        + group_mac[:4]
        + build_igmp_membership_report_packet(group_ip=group_ip)
    )


def assert_report_frame(frame: bytes, *, group_ip: str) -> None:
    expected = expected_report_frame(group_ip=group_ip)
    assert len(frame) == len(expected)
    assert frame[:6] == expected[:6]
    assert frame[8:16] == expected[8:16]
    assert frame[16:20] == expected[16:20]
    assert frame[20:] == expected[20:]


def general_query_frame(*, checksum_override: int | None = None) -> bytes:
    return build_ipv4_rx_pseudo_frame(
        src_mac=ROUTER_MAC,
        src_ip=ROUTER_IP,
        dst_ip="224.0.0.1",
        protocol=IP_PROTOCOL_IGMP,
        payload=build_igmp_membership_query_packet(
            max_resp_time=0x02,
            group_ip="0.0.0.0",
            checksum_override=checksum_override,
        ),
    )


def inbound_membership_report_frame(*, group_ip: str) -> bytes:
    return build_ipv4_rx_pseudo_frame(
        src_mac=OTHER_HOST_MAC,
        src_ip=OTHER_HOST_IP,
        dst_ip=group_ip,
        protocol=IP_PROTOCOL_IGMP,
        payload=build_igmp_membership_report_packet(group_ip=group_ip),
    )


@cocotb.test()
async def igmp_engine_power_up_reports_all_groups_test(dut):
    bench = await setup_igmp_bench(dut, group0_cfg=GROUP0_CFG, group1_cfg=GROUP1_CFG)

    first_report = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=768,
    )
    assert_report_frame(payload_from_beats(first_report), group_ip=GROUP0)
    assert first_report[0].sof == 1
    assert first_report[-1].last == 1

    second_report = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=64,
    )
    assert_report_frame(payload_from_beats(second_report), group_ip=GROUP1)
    assert second_report[0].sof == 1
    assert second_report[-1].last == 1


@cocotb.test()
async def igmp_engine_general_query_rearms_report_test(dut):
    bench = await setup_igmp_bench(dut, group0_cfg=GROUP0_CFG, group1_cfg=0)

    initial_report = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=768,
    )
    assert_report_frame(payload_from_beats(initial_report), group_ip=GROUP0)
    await expect_no_output(bench.sink, clk=bench.clk, cycles=12)

    # Let the random counter advance beyond the query's max-response time so
    # the engine keeps the deterministic two-tick timeout set by the query.
    await cycle(bench.clk, 10)

    query_send = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(general_query_frame()), clk=bench.clk)
    )
    query_report = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=64,
    )
    await query_send
    assert_report_frame(payload_from_beats(query_report), group_ip=GROUP0)
    await expect_no_output(bench.sink, clk=bench.clk, cycles=12)


@cocotb.test()
async def igmp_engine_report_suppression_and_bad_checksum_ignore_test(dut):
    bench = await setup_igmp_bench(dut, group0_cfg=GROUP0_CFG, group1_cfg=GROUP1_CFG)

    suppression_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.source,
            frame_beats_from_bytes(inbound_membership_report_frame(group_ip=GROUP0)),
            clk=bench.clk,
        )
    )
    await suppression_send

    bad_query_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.source,
            frame_beats_from_bytes(general_query_frame(checksum_override=0x0000)),
            clk=bench.clk,
        )
    )
    await bad_query_send

    surviving_report = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=768,
    )
    assert_report_frame(payload_from_beats(surviving_report), group_ip=GROUP1)

    # Group 0 was explicitly suppressed and the bad query must not re-arm it.
    await expect_no_output(bench.sink, clk=bench.clk, cycles=24)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="igmp_v2_engine_wrapper")])
def test_IgmpV2Engine(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.igmpv2enginewrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": IPV4_RTL_SOURCES + [WRAPPER_PATH]},
    )
