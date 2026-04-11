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
# - Sweep: Enable the checked-in top-level filter and pause generics so one
#   wrapper build can exercise the meaningful runtime configuration matrix.
# - Stimulus: Run three curated scenarios through the real XGMII loopback path:
#   filter plus backpressure behavior, TX checksum repair plus RX verification,
#   and remote pause reception followed by gated outbound traffic.
# - Checks: Filtering must pass local and broadcast traffic while dropping
#   foreign unicast, checksum-enabled packets must emerge repaired without RX
#   error flags, and a received pause frame must suppress subsequent traffic
#   until the pause interval expires.
# - Timing: The bench waits on visible AXIS/status behavior rather than assuming
#   fixed internal pipeline depth, because the top-level MAC includes FIFO,
#   pause, and import/export staging.

import cocotb
import pytest
from pathlib import Path

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    build_ethernet_frame,
    build_ipv4_udp_frame,
    build_pause_frame,
    cycle,
    expect_no_output,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    send_frame_burst,
    setup_flat_emac_testbench,
    wait_signal_pulse,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTopLoopbackWrapper.vhd"
ROCE_RTL_ROOT = Path(__file__).resolve().parents[3] / "ethernet" / "RoCEv2" / "rtl"
ROCE_ANALYSIS_SOURCES = [
    str(ROCE_RTL_ROOT / "RocePkg.vhd"),
    *(
        str(path)
        for path in sorted(ROCE_RTL_ROOT.glob("*.vhd"))
        if path.name != "RocePkg.vhd"
    ),
]

LOCAL_MAC_WIRE = 0x001122334455
LOCAL_MAC_CFG = mac_config_word_from_wire(LOCAL_MAC_WIRE)


@cocotb.test()
async def eth_mac_top_filter_and_backpressure_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "phyReady": 1,
            "mAxisTReady": 0,
            "localMac": LOCAL_MAC_CFG,
            "filtEnable": 1,
            "pauseEnable": 0,
            "pauseTime": 0x0020,
            "pauseThresh": 0x0008,
            "ipCsumEn": 0,
            "tcpCsumEn": 0,
            "udpCsumEn": 0,
            "dropOnPause": 0,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    local_frame = build_ethernet_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=0x660102030405,
        eth_type=0x88B5,
        payload=bytes(range(46)),
    )
    local_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(local_frame), clk=bench.clk)
    )

    # Hold the downstream ready low long enough to prove the top-level RX FIFO
    # can retain a valid local frame without corrupting it or flagging overflow.
    await sink.wait_valid(clk=bench.clk, timeout_cycles=256)
    await cycle(bench.clk, 4)
    assert int(dut.rxOverFlow.value) == 0

    local_observed = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=256,
    )
    await local_send
    assert payload_from_beats(local_observed) == local_frame

    foreign_frame = build_ethernet_frame(
        dst_mac=0x00AA00BB00CC,
        src_mac=0x660102030405,
        eth_type=0x88B5,
        payload=b"foreign-unicast-drop",
    )
    broadcast_frame = build_ethernet_frame(
        dst_mac=0xFFFFFFFFFFFF,
        src_mac=0x660102030405,
        eth_type=0x88B5,
        # Keep the payload at Ethernet's minimum so this scenario isolates the
        # filter decision instead of also depending on TX-side padding.
        payload=b"broadcast-pass-through" + bytes(24),
    )

    # Send a dropped foreign-unicast frame directly ahead of a broadcast frame
    # so the filter test also proves the RX state machine resets cleanly across
    # consecutive packets.
    burst_send = cocotb.start_soon(
        send_frame_burst(
            source,
            [
                frame_beats_from_bytes(foreign_frame),
                frame_beats_from_bytes(broadcast_frame),
            ],
            clk=bench.clk,
        )
    )
    broadcast_observed = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=512,
    )
    await burst_send

    assert payload_from_beats(broadcast_observed) == broadcast_frame
    await expect_no_output(sink, clk=bench.clk, cycles=8)


@cocotb.test()
async def eth_mac_top_checksum_loopback_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "phyReady": 1,
            "mAxisTReady": 0,
            "localMac": LOCAL_MAC_CFG,
            "filtEnable": 0,
            "pauseEnable": 0,
            "pauseTime": 0x0020,
            "pauseThresh": 0x0008,
            "ipCsumEn": 1,
            "tcpCsumEn": 0,
            "udpCsumEn": 1,
            "dropOnPause": 0,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    repaired_frame = build_ipv4_udp_frame(
        dst_mac=0x112233445566,
        src_mac=0xAABBCCDDEEFF,
        src_ip="10.0.0.1",
        dst_ip="10.0.0.2",
        src_port=0x1001,
        dst_port=0x2002,
        payload=b"eth-mac-top-fixup!",
    )
    checksum_clear_frame = build_ipv4_udp_frame(
        dst_mac=0x112233445566,
        src_mac=0xAABBCCDDEEFF,
        src_ip="10.0.0.1",
        dst_ip="10.0.0.2",
        src_port=0x1001,
        dst_port=0x2002,
        payload=b"eth-mac-top-fixup!",
        ip_checksum_override=0x0000,
        udp_checksum_override=0x0000,
    )
    already_valid_frame = build_ipv4_udp_frame(
        dst_mac=0x010203040506,
        src_mac=0xAABBCCDDEEFF,
        src_ip="10.0.0.3",
        dst_ip="10.0.0.4",
        src_port=0x3003,
        dst_port=0x4004,
        payload=b"second-frame-stays-valid",
    )

    burst_send = cocotb.start_soon(
        send_frame_burst(
            source,
            [
                frame_beats_from_bytes(checksum_clear_frame),
                frame_beats_from_bytes(already_valid_frame),
            ],
            clk=bench.clk,
        )
    )
    repaired_observed = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=512,
    )
    valid_observed = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=512,
    )
    await burst_send

    assert payload_from_beats(repaired_observed) == repaired_frame
    assert payload_from_beats(valid_observed) == already_valid_frame

    # The top-level loopback bench is stronger than the leaf checksum benches
    # because the repaired packet is immediately checked again by the RX path.
    for beat in (repaired_observed[-1], valid_observed[-1]):
        assert beat.iperr == 0
        assert beat.tcperr == 0
        assert beat.udperr == 0
        assert beat.eofe == 0


@cocotb.test()
async def eth_mac_top_pause_gate_test(dut):
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix="sAxis",
        sink_prefix="mAxis",
        initial_values={
            "phyReady": 1,
            "mAxisTReady": 0,
            "localMac": LOCAL_MAC_CFG,
            "filtEnable": 0,
            "pauseEnable": 1,
            "pauseTime": 0x0002,
            "pauseThresh": 0x0008,
            "ipCsumEn": 0,
            "tcpCsumEn": 0,
            "udpCsumEn": 0,
            "dropOnPause": 0,
        },
    )
    source = bench.source
    sink = bench.sink
    assert source is not None
    assert sink is not None

    pause_frame = build_pause_frame(1)
    pause_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(pause_frame), clk=bench.clk)
    )
    await wait_signal_pulse(dut.rxPauseCnt, clk=bench.clk, timeout_cycles=256)
    await pause_send

    # Pause control frames are consumed internally by the RX pause handler, so
    # the primary application stream should stay quiet.
    await expect_no_output(sink, clk=bench.clk, cycles=8)

    gated_frame = build_ethernet_frame(
        dst_mac=0x5A0102030405,
        src_mac=0x660102030405,
        eth_type=0x88B5,
        payload=b"pause-release-check" + bytes(27),
    )
    gated_send = cocotb.start_soon(
        send_contiguous_frame(source, frame_beats_from_bytes(gated_frame), clk=bench.clk)
    )

    # The received pause request should suppress the next outbound packet long
    # enough that it definitely does not appear immediately.
    await expect_no_output(sink, clk=bench.clk, cycles=4)
    gated_observed = await recv_frame(
        sink,
        clk=bench.clk,
        ready_signal=dut.mAxisTReady,
        timeout_cycles=512,
    )
    await gated_send

    assert payload_from_beats(gated_observed) == gated_frame
    assert int(dut.rxCrcErrorCnt.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "xgmii_feature_matrix",
        FILT_EN_G="true",
        PAUSE_EN_G="true",
        PAUSE_512BITS_G="8",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTop(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactoploopbackwrapper",
        parameters=parameters,
        extra_env=parameters,
        # `EthMacTx` and `EthMacRx` reference the RoCE helper entities during
        # analysis even when `ROCEV2_EN_G` is disabled in the loopback wrapper.
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + ROCE_ANALYSIS_SOURCES + [WRAPPER_PATH]},
    )
