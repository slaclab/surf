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
# - Sweep: Exercise the checked-in RawEthFramer wrapper across the major TX and
#   RX branches: unicast lookup, broadcast bypass, unknown-remote drops, valid
#   receive decode, and invalid receive filtering.
# - Stimulus: Drive app-side payload frames into the TX path, drive pre-framed
#   raw-Ethernet MAC packets into the RX path, and program the remote-MAC LUT
#   over AXI-Lite exactly as software would.
# - Checks: TX must prepend the raw-Ethernet header and route by `tDest`, RX
#   must strip that header back to the app payload and recover `tDest`/`BCF`,
#   missing LUT entries must drop traffic, and malformed or mismatched receive
#   packets must be discarded without wedging the datapath.
# - Timing: The bench waits on stream handshakes and frame completion instead of
#   fixed delays because both TX and RX include LUT-lookup sequencing.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    expect_no_output,
    frame_beats_from_bytes,
    mac_to_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
)
from tests.ethernet.RawEthFramer.raw_eth_test_utils import (
    ALT_REMOTE_MAC_WIRE,
    LOCAL_MAC_WIRE,
    RAWETH_BEAT_BYTES,
    RAWETH_RTL_SOURCES,
    REMOTE_MAC_CFG,
    REMOTE_MAC_WIRE,
    build_raw_eth_wire_frame,
    pad_to_raw_eth_lane_width,
    payload_from_raw_beats,
    program_remote_mac,
    raw_app_beats_from_bytes,
    raweth_header_bytes,
    read_remote_mac,
    setup_raw_eth_wrapper_bench,
)


WRAPPER_PATH = "ethernet/RawEthFramer/wrappers/RawEthFramerFlatWrapper.vhd"


@cocotb.test()
async def raw_eth_tx_unicast_and_broadcast_test(dut):
    bench = await setup_raw_eth_wrapper_bench(dut)

    await program_remote_mac(bench.axil, dest=0x2A, mac_cfg=REMOTE_MAC_CFG)
    assert await read_remote_mac(bench.axil, dest=0x2A) == REMOTE_MAC_CFG

    unicast_payload = b"raw-eth-tx-unicast"
    unicast_wire_payload = pad_to_raw_eth_lane_width(unicast_payload)
    unicast_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.app_source,
            raw_app_beats_from_bytes(unicast_payload, dest=0x2A),
            clk=bench.clk,
        )
    )
    unicast_observed = await recv_frame(
        bench.mac_sink,
        clk=bench.clk,
        ready_signal=dut.mMacTReady,
        timeout_cycles=128,
    )
    await unicast_send
    assert payload_from_beats(unicast_observed, lane_bytes=8) == build_raw_eth_wire_frame(
        dst_mac=REMOTE_MAC_WIRE,
        src_mac=LOCAL_MAC_WIRE,
        dest=0x2A,
        bcf=0,
        payload=unicast_wire_payload,
        min_byte_count=16 + len(unicast_payload),
    )
    assert unicast_observed[0].sof == 1
    assert unicast_observed[-1].eofe == 0

    broadcast_payload = b"raw-eth-tx-broadcast"
    broadcast_wire_payload = pad_to_raw_eth_lane_width(broadcast_payload)
    broadcast_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.app_source,
            raw_app_beats_from_bytes(broadcast_payload, dest=0xFF, bcf=1, eofe=1),
            clk=bench.clk,
        )
    )
    broadcast_observed = await recv_frame(
        bench.mac_sink,
        clk=bench.clk,
        ready_signal=dut.mMacTReady,
        timeout_cycles=128,
    )
    await broadcast_send
    assert payload_from_beats(broadcast_observed, lane_bytes=8) == build_raw_eth_wire_frame(
        dst_mac=0xFFFF_FFFF_FFFF,
        src_mac=LOCAL_MAC_WIRE,
        dest=0xFF,
        bcf=1,
        payload=broadcast_wire_payload,
        min_byte_count=16 + len(broadcast_payload),
    )
    assert broadcast_observed[0].sof == 1
    assert broadcast_observed[-1].eofe == 1


@cocotb.test()
async def raw_eth_tx_drops_unknown_dest_test(dut):
    bench = await setup_raw_eth_wrapper_bench(dut)

    missing_payload = b"lut-miss"
    missing_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.app_source,
            raw_app_beats_from_bytes(missing_payload, dest=0x33),
            clk=bench.clk,
        )
    )
    await missing_send
    await expect_no_output(bench.mac_sink, clk=bench.clk, cycles=12)

    recovery_payload = b"recovery"
    recovery_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.app_source,
            raw_app_beats_from_bytes(recovery_payload, dest=0xFF, bcf=1),
            clk=bench.clk,
        )
    )
    recovery_observed = await recv_frame(
        bench.mac_sink,
        clk=bench.clk,
        ready_signal=dut.mMacTReady,
        timeout_cycles=128,
    )
    await recovery_send
    assert payload_from_beats(recovery_observed, lane_bytes=8) == build_raw_eth_wire_frame(
        dst_mac=0xFFFF_FFFF_FFFF,
        src_mac=LOCAL_MAC_WIRE,
        dest=0xFF,
        bcf=1,
        payload=recovery_payload,
        min_byte_count=16 + len(recovery_payload),
    )


@cocotb.test()
async def raw_eth_rx_unicast_and_broadcast_test(dut):
    bench = await setup_raw_eth_wrapper_bench(dut)

    await program_remote_mac(bench.axil, dest=0x19, mac_cfg=REMOTE_MAC_CFG)

    unicast_payload = b"rx-unicast-payload"
    unicast_frame = build_raw_eth_wire_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=REMOTE_MAC_WIRE,
        dest=0x19,
        bcf=0,
        payload=unicast_payload,
        min_byte_count=16 + len(unicast_payload),
    )
    unicast_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.mac_source,
            frame_beats_from_bytes(unicast_frame, beat_bytes=RAWETH_BEAT_BYTES, eofe=1),
            clk=bench.clk,
        )
    )
    unicast_observed = await recv_frame(
        bench.app_sink,
        clk=bench.clk,
        ready_signal=dut.mAppTReady,
        timeout_cycles=128,
    )
    await unicast_send
    assert payload_from_raw_beats(unicast_observed) == unicast_payload
    assert unicast_observed[0].sof == 1
    assert unicast_observed[0].dest == 0x19
    assert unicast_observed[0].bcf == 0
    assert unicast_observed[-1].eofe == 1

    broadcast_payload = b"rx-broadcast"
    broadcast_frame = build_raw_eth_wire_frame(
        dst_mac=0xFFFF_FFFF_FFFF,
        src_mac=ALT_REMOTE_MAC_WIRE,
        dest=0xFF,
        bcf=1,
        payload=broadcast_payload,
        min_byte_count=16 + len(broadcast_payload),
    )
    broadcast_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.mac_source,
            frame_beats_from_bytes(broadcast_frame, beat_bytes=RAWETH_BEAT_BYTES),
            clk=bench.clk,
        )
    )
    broadcast_observed = await recv_frame(
        bench.app_sink,
        clk=bench.clk,
        ready_signal=dut.mAppTReady,
        timeout_cycles=128,
    )
    await broadcast_send
    assert payload_from_raw_beats(broadcast_observed) == broadcast_payload
    assert broadcast_observed[0].dest == 0xFF
    assert broadcast_observed[0].bcf == 1


@cocotb.test()
async def raw_eth_rx_rejects_invalid_frames_test(dut):
    bench = await setup_raw_eth_wrapper_bench(dut)

    await program_remote_mac(bench.axil, dest=0x41, mac_cfg=REMOTE_MAC_CFG)

    foreign_dest = mac_to_bytes(0x8899_AABB_CCDD) + mac_to_bytes(REMOTE_MAC_WIRE)[:2]
    foreign_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.mac_source,
            frame_beats_from_bytes(foreign_dest, beat_bytes=RAWETH_BEAT_BYTES),
            clk=bench.clk,
        )
    )
    await foreign_send
    await expect_no_output(bench.app_sink, clk=bench.clk, cycles=8)

    wrong_type = (
        mac_to_bytes(LOCAL_MAC_WIRE)
        + mac_to_bytes(REMOTE_MAC_WIRE)
        + b"\x08\x00"
        + raweth_header_bytes(dest=0x41, bcf=0, min_byte_count=0)
    )
    wrong_type_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.mac_source,
            frame_beats_from_bytes(wrong_type, beat_bytes=RAWETH_BEAT_BYTES),
            clk=bench.clk,
        )
    )
    await wrong_type_send
    await expect_no_output(bench.app_sink, clk=bench.clk, cycles=8)

    bad_broadcast = build_raw_eth_wire_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=ALT_REMOTE_MAC_WIRE,
        dest=0x01,
        bcf=1,
        payload=b"",
        min_byte_count=0,
    )
    bad_broadcast_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.mac_source,
            frame_beats_from_bytes(bad_broadcast, beat_bytes=RAWETH_BEAT_BYTES),
            clk=bench.clk,
        )
    )
    await bad_broadcast_send
    await expect_no_output(bench.app_sink, clk=bench.clk, cycles=8)

    src_mismatch = build_raw_eth_wire_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=ALT_REMOTE_MAC_WIRE,
        dest=0x41,
        bcf=0,
        payload=b"",
        min_byte_count=0,
    )
    src_mismatch_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.mac_source,
            frame_beats_from_bytes(src_mismatch, beat_bytes=RAWETH_BEAT_BYTES),
            clk=bench.clk,
        )
    )
    await src_mismatch_send
    await expect_no_output(bench.app_sink, clk=bench.clk, cycles=8)

    valid_payload = b"rx-recovery"
    valid_frame = build_raw_eth_wire_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=REMOTE_MAC_WIRE,
        dest=0x41,
        bcf=0,
        payload=valid_payload,
        min_byte_count=16 + len(valid_payload),
    )
    valid_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.mac_source,
            frame_beats_from_bytes(valid_frame, beat_bytes=RAWETH_BEAT_BYTES),
            clk=bench.clk,
        )
    )
    valid_observed = await recv_frame(
        bench.app_sink,
        clk=bench.clk,
        ready_signal=dut.mAppTReady,
        timeout_cycles=128,
    )
    await valid_send
    assert payload_from_raw_beats(valid_observed) == valid_payload
    assert valid_observed[0].dest == 0x41
    assert valid_observed[0].bcf == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="raw_eth_framer_flat_wrapper")])
def test_RawEthFramer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rawethframerflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": RAWETH_RTL_SOURCES + [WRAPPER_PATH]},
    )
