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
# - Sweep: Cover the RawEthFramerRx leaf across lookup-gated unicast decode,
#   broadcast bypass, short-frame trim behavior from the header `minByteCnt`,
#   and representative reject cases for malformed or mismatched traffic.
# - Stimulus: Drive curated raw-Ethernet wire frames into the flattened RX
#   wrapper, hold `ack` low until the DUT raises the exported lookup `req`,
#   then answer with either the matching remote MAC or leave the frame to the
#   broadcast/reject path without a lookup acknowledgement.
# - Checks: Valid unicast frames must request the expected `tDest`, wait for
#   the lookup handshake, trim padded bytes back to the encoded payload length,
#   preserve SOF/BCF/EOFE, accept broadcast frames without lookup, and drop
#   invalid EtherType, invalid broadcast metadata, and source-MAC mismatches.
# - Timing: The bench synchronizes to `req` and output handshakes because the
#   RX path has explicit header, lookup, and move states.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    expect_no_output,
    frame_beats_from_bytes,
    recv_frame,
    send_contiguous_frame,
)
from tests.ethernet.RawEthFramer.raw_eth_test_utils import (
    ETH_TYPE_CFG,
    LOCAL_MAC_CFG,
    LOCAL_MAC_WIRE,
    REMOTE_MAC_CFG,
    REMOTE_MAC_WIRE,
    ALT_REMOTE_MAC_WIRE,
    RAWETH_BEAT_BYTES,
    RAWETH_RTL_SOURCES,
    build_raw_eth_wire_frame,
    payload_from_raw_beats,
    pulse_signal,
    raweth_header_bytes,
    setup_raw_eth_rx_bench,
    wait_lookup_request,
)


WRAPPER_PATH = "ethernet/RawEthFramer/wrappers/RawEthFramerRxFlatWrapper.vhd"


@cocotb.test()
async def raw_eth_rx_waits_for_lookup_and_trims_short_frame_test(dut):
    bench = await setup_raw_eth_rx_bench(dut)

    actual_payload = b"rx-trim-test"
    padded_payload = actual_payload + bytes(16 - len(actual_payload))

    # Model the short-frame TX output form: a padded MAC beat sequence with the
    # real byte count carried in the raw-Ethernet header metadata.
    short_frame = build_raw_eth_wire_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=REMOTE_MAC_WIRE,
        dest=0x19,
        bcf=0,
        payload=padded_payload,
        min_byte_count=16 + len(actual_payload),
        eth_type_cfg=ETH_TYPE_CFG,
    )

    send_task = cocotb.start_soon(
        send_contiguous_frame(
            bench.source,
            frame_beats_from_bytes(short_frame, beat_bytes=RAWETH_BEAT_BYTES, eofe=1),
            clk=bench.clk,
        )
    )

    # The leaf should publish the requested lookup destination before any app
    # payload is released, which is the externally visible contract here.
    observed_dest = await wait_lookup_request(dut, clk=bench.clk)
    assert observed_dest == 0x19
    await expect_no_output(bench.sink, clk=bench.clk, cycles=4)

    dut.remoteMac.value = REMOTE_MAC_CFG
    await pulse_signal(dut.ack, clk=bench.clk)

    # After the lookup is acknowledged, the output stream should trim away the
    # padded zeros and recover the original short payload length.
    observed = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mAppTReady,
        timeout_cycles=128,
    )
    await send_task

    assert payload_from_raw_beats(observed) == actual_payload
    assert observed[0].dest == 0x19
    assert observed[0].bcf == 0
    assert observed[0].sof == 1
    assert observed[-1].eofe == 1


@cocotb.test()
async def raw_eth_rx_broadcast_bypass_and_reject_cases_test(dut):
    bench = await setup_raw_eth_rx_bench(dut)

    broadcast_payload = b"rx-broadcast"

    # Broadcast traffic should bypass the lookup handshake and emerge directly
    # on the app-side output with `BCF` asserted and `tDest` set to 0xFF.
    broadcast_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.source,
            frame_beats_from_bytes(
                build_raw_eth_wire_frame(
                    dst_mac=0xFFFF_FFFF_FFFF,
                    src_mac=ALT_REMOTE_MAC_WIRE,
                    dest=0xFF,
                    bcf=1,
                    payload=broadcast_payload,
                    min_byte_count=16 + len(broadcast_payload),
                    eth_type_cfg=ETH_TYPE_CFG,
                ),
                beat_bytes=RAWETH_BEAT_BYTES,
            ),
            clk=bench.clk,
        )
    )
    broadcast_observed = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mAppTReady,
        timeout_cycles=128,
    )
    await broadcast_send

    assert payload_from_raw_beats(broadcast_observed) == broadcast_payload
    assert broadcast_observed[0].dest == 0xFF
    assert broadcast_observed[0].bcf == 1
    assert int(dut.req.value) == 0

    # Wrong-EtherType traffic must be discarded before the lookup state.
    wrong_type = (
        LOCAL_MAC_WIRE.to_bytes(6, byteorder="big")
        + REMOTE_MAC_WIRE.to_bytes(6, byteorder="big")
        + b"\x08\x00"
        + raweth_header_bytes(dest=0x41, bcf=0, min_byte_count=0)
    )
    await send_contiguous_frame(
        bench.source,
        frame_beats_from_bytes(wrong_type, beat_bytes=RAWETH_BEAT_BYTES),
        clk=bench.clk,
    )
    await expect_no_output(bench.sink, clk=bench.clk, cycles=8)

    # A malformed broadcast marker must also be dropped without forwarding.
    bad_broadcast = build_raw_eth_wire_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=ALT_REMOTE_MAC_WIRE,
        dest=0x01,
        bcf=1,
        payload=b"",
        min_byte_count=0,
        eth_type_cfg=ETH_TYPE_CFG,
    )
    await send_contiguous_frame(
        bench.source,
        frame_beats_from_bytes(bad_broadcast, beat_bytes=RAWETH_BEAT_BYTES),
        clk=bench.clk,
    )
    await expect_no_output(bench.sink, clk=bench.clk, cycles=8)

    # A source-MAC mismatch should still make it through the lookup state, but
    # it must drop before payload release once the lookup result is checked.
    mismatch_frame = build_raw_eth_wire_frame(
        dst_mac=LOCAL_MAC_WIRE,
        src_mac=ALT_REMOTE_MAC_WIRE,
        dest=0x41,
        bcf=0,
        payload=b"",
        min_byte_count=0,
        eth_type_cfg=ETH_TYPE_CFG,
    )
    mismatch_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.source,
            frame_beats_from_bytes(mismatch_frame, beat_bytes=RAWETH_BEAT_BYTES),
            clk=bench.clk,
        )
    )
    assert await wait_lookup_request(dut, clk=bench.clk) == 0x41
    dut.remoteMac.value = REMOTE_MAC_CFG
    await pulse_signal(dut.ack, clk=bench.clk)
    await mismatch_send
    await expect_no_output(bench.sink, clk=bench.clk, cycles=8)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="raw_eth_framer_rx_flat_wrapper")])
def test_RawEthFramerRx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rawethframerrxflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": RAWETH_RTL_SOURCES + [WRAPPER_PATH]},
    )
