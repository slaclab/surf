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
# - Sweep: XGMII EthMacTop with independent receive pins, asynchronous primary
#   clock, all runtime checksum enables set, and error dropping on/off.
# - Stimulus: Valid IPv4/UDP, IPv4/ICMP and fragmented UDP at short wire gaps,
#   both start lanes and 64/65-byte boundaries. A separate regression
#   injects bad Ethernet FCS into otherwise valid UDP and follows with a good
#   frame. This preserves the physical reproduction of catalog report #1.
# - Checks: Exact ordered payload, SOF/TKEEP, FRAG and checksum/error sidebands,
#   no unfinished output, exact importer CRC status. Bad FCS must retain EOFE
#   when forwarding or be discarded when error dropping is enabled.
# - Timing: PHY stimulus changes on falling edges, output accepts every beat;
#   drain is bounded and both entrypoints have a final watchdog. Four idle
#   octets after /T/ plus start-lane alignment exercise tight RX spacing.

import cocotb
import pytest

from tests.common.regression_utils import (
    cancel_and_join_tasks,
    cocotb_filtered_env,
    cocotb_test_filter,
    env_flag,
    run_surf_vhdl_test,
)
from tests.ethernet.EthMacCore.ethmac_line_models import (
    XGMII_IDLE,
    build_ipv4_frame,
    build_ipv4_packet,
    build_udp_segment,
    xgmii_lanes,
    xgmii_words,
)
from tests.ethernet.EthMacCore.ethmac_test_utils import ETHMAC_RTL_SOURCES, cycle
from tests.ethernet.EthMacCore.test_EthMacKnownIssues import (
    TOP_PHY_WRAPPER,
    start_top_phy_bench,
)


def ipv4_frame(length, *, fragment=False, udp=True):
    # Unique payload and a valid minimum IPv4 header, no Ethernet padding.
    src, dst = "192.168.1.10", "192.168.1.20"
    if udp:
        l4 = build_udp_segment(src_ip=src, dst_ip=dst, src_port=1234, dst_port=5678,
                               payload=bytes([length]) * (length - 42))
    else:
        l4 = bytes([length]) * (length - 34)
    packet = build_ipv4_packet(src_ip=src, dst_ip=dst, protocol=17 if udp else 1,
                               l4=l4, flags_fragment=0x2000 if fragment else 0)
    return build_ipv4_frame(dst_mac=0x001122334455, src_mac=0x660102030405, packet=packet)


async def start_checked_rx(dut):
    driver, collector, status = await start_top_phy_bench(dut)
    dut.ipCsumEn.value = 1
    dut.tcpCsumEn.value = 1
    dut.udpCsumEn.value = 1
    await cycle(dut.ethClk, 16)
    return driver, collector, status


def check_frame(out, expected, *, frag=0, eofe=0):
    assert out.payload == expected, out.describe()
    assert out.beats[0].sof == 1 and all(beat.sof == 0 for beat in out.beats[1:]), out.describe()
    for index, beat in enumerate(out.beats):
        remaining = len(expected) - 16 * index
        assert beat.keep == (1 << min(16, remaining)) - 1, (index, beat)
        assert beat.last == int(index == len(out.beats) - 1), (index, beat)
    assert out.beats[0].frag == frag, out.describe()
    last = out.beats[-1]
    assert (last.eofe, last.iperr, last.tcperr, last.udperr) == (eofe, 0, 0, 0), out.describe()


@cocotb.test(timeout_time=100, timeout_unit="us")
async def rx_checksums_from_phy_test(dut):
    driver, collector, status = await start_checked_rx(dut)
    try:
        # Short directed sequence covers minimum frames, both end alignments,
        # fragments and a following independent header checksum calculation.
        cases = [(60, False, True), (65, False, True), (64, True, True), (79, False, False),
                 (81, False, True), (80, True, True), (63, False, False), (66, False, True)]
        frames = [(ipv4_frame(length, fragment=fragment, udp=udp), fragment)
                  for length, fragment, udp in cases]
        lanes = []
        for frame, _ in frames:
            lanes.extend(xgmii_lanes(frame))
            lanes.extend([(XGMII_IDLE, 1)] * 4)
            lanes.extend([(XGMII_IDLE, 1)] * (-len(lanes) % 4))
        lanes.extend([(XGMII_IDLE, 1)] * (-len(lanes) % 8))
        words = [(sum(byte << (8 * lane) for lane, (byte, _) in enumerate(lanes[offset:offset + 8])),
                  sum(ctrl << lane for lane, (_, ctrl) in enumerate(lanes[offset:offset + 8])))
                 for offset in range(0, len(lanes), 8)]
        await driver.send(words)
        await cycle(dut.ethClk, 200)
        assert len(collector.frames) == len(frames), collector.describe()
        for out, (frame, fragment) in zip(collector.frames, frames, strict=True):
            check_frame(out, frame, frag=int(fragment))
        assert not collector.open_beats, collector.describe()
        assert status.counts["rxCrcErrorCnt"] == 0, status.snapshot()
        assert status.counts["rxCountEn"] == len(frames), status.snapshot()
    finally:
        await cancel_and_join_tasks([collector.task, status.task])


@cocotb.test(timeout_time=100, timeout_unit="us")
async def rx_bad_fcs_preserves_error_test(dut):
    driver, collector, status = await start_checked_rx(dut)
    try:
        errored, recovery = ipv4_frame(102), ipv4_frame(78)
        await driver.send(xgmii_words(errored, bad_fcs=True))
        await driver.send(xgmii_words(recovery))
        await cycle(dut.ethClk, 200)
        assert status.counts["rxCrcErrorCnt"] == 1, status.snapshot()
        drop = env_flag("DROP_ERR_PKT_G", default=True)
        expected = [(recovery, 0)] if drop else [(errored, 1), (recovery, 0)]
        assert len(collector.frames) == len(expected), (
            f"report #1: bad-FCS UDP must be dropped with DROP_ERR_PKT_G={drop}; {collector.describe()}"
        )
        for out, (frame, eofe) in zip(collector.frames, expected, strict=True):
            check_frame(out, frame, eofe=eofe)
        assert not collector.open_beats, collector.describe()
    finally:
        await cancel_and_join_tasks([collector.task, status.task])


@pytest.mark.parametrize("drop_err", ["true", "false"], ids=["drop_errors", "forward_errors"])
def test_EthMacRxChecksumIntegration(drop_err):
    parameters = {"PHY_TYPE_G": "XGMII", "JUMBO_G": "false", "DROP_ERR_PKT_G": drop_err}
    scenarios = ["rx_checksums_from_phy_test", "rx_bad_fcs_preserves_error_test"]
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactopphywrapper",
        parameters=parameters,
        extra_env=cocotb_filtered_env(parameters, cocotb_test_filter(*scenarios)),
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [TOP_PHY_WRAPPER]},
    )
