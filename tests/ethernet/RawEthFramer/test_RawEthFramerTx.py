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
# - Sweep: Cover the RawEthFramerTx leaf across the lookup-facing request path,
#   the stable broadcast bypass path, and the drop path when a unicast lookup
#   resolves to zero.
# - Stimulus: Drive app-side raw-Ethernet payload frames into the flattened TX
#   wrapper, hold the lookup `ack` low while observing `req`/`tDest`, then use
#   the broadcast or zero-MAC miss branches for the complete on-wire checks.
# - Checks: Unicast traffic must expose the requested `tDest` and stall until
#   lookup completion, broadcast traffic must bypass lookup and emit the
#   expected padded wire image, and unicast traffic must drop when the resolved
#   remote MAC is zero.
# - Timing: The bench waits on the exported lookup request and on accepted AXIS
#   handshakes rather than assuming a fixed latency through the cache logic.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    expect_no_output,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
)
from tests.ethernet.RawEthFramer.raw_eth_test_utils import (
    ETH_TYPE_CFG,
    LOCAL_MAC_WIRE,
    RAWETH_BEAT_BYTES,
    RAWETH_RTL_SOURCES,
    build_raw_eth_wire_frame,
    pad_to_raw_eth_lane_width,
    pulse_signal,
    raw_app_beats_from_bytes,
    setup_raw_eth_tx_bench,
    wait_lookup_request,
)


WRAPPER_PATH = "ethernet/RawEthFramer/wrappers/RawEthFramerTxFlatWrapper.vhd"


@cocotb.test()
async def raw_eth_tx_exposes_lookup_request_before_forwarding_test(dut):
    bench = await setup_raw_eth_tx_bench(dut)

    payload = b"lookup1!"
    beat = raw_app_beats_from_bytes(payload, dest=0x2A, eofe=1)[0]

    # Present a unicast SOF beat and hold it visible. The TX leaf should raise
    # `req` with the selected `tDest` before it is allowed to forward anything.
    bench.source.drive(beat)

    # The leaf contract is the exported lookup handshake, so observe it
    # directly while `ack` remains low.
    observed_dest = await wait_lookup_request(dut, clk=bench.clk)
    assert observed_dest == 0x2A
    await expect_no_output(bench.sink, clk=bench.clk, cycles=4)
    bench.source.set_idle()


@cocotb.test()
async def raw_eth_tx_broadcast_bypasses_lookup_test(dut):
    bench = await setup_raw_eth_tx_bench(dut)

    broadcast_payload = b"broadcast-leaf-path"
    broadcast_wire_payload = pad_to_raw_eth_lane_width(broadcast_payload, lane_bytes=RAWETH_BEAT_BYTES)

    # Broadcast traffic should not need a lookup handshake at all; the module
    # can forward it immediately with the all-ones destination MAC.
    broadcast_send = cocotb.start_soon(
        send_contiguous_frame(
            bench.source,
            raw_app_beats_from_bytes(broadcast_payload, dest=0xFF, bcf=1),
            clk=bench.clk,
        )
    )
    broadcast_observed = await recv_frame(
        bench.sink,
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
        eth_type_cfg=ETH_TYPE_CFG,
    )
    assert int(dut.req.value) == 0


@cocotb.test()
async def raw_eth_tx_zero_mac_lookup_miss_drops_before_forwarding_test(dut):
    bench = await setup_raw_eth_tx_bench(dut)

    miss_beat = raw_app_beats_from_bytes(b"drop-miss", dest=0x33)[0]

    # Drive a unicast beat just far enough to reach the lookup state.
    bench.source.drive(miss_beat)
    assert await wait_lookup_request(dut, clk=bench.clk) == 0x33

    # A zero remote-MAC response should cause the DUT to abandon the frame
    # without ever presenting a MAC-side transfer.
    dut.remoteMac.value = 0
    await pulse_signal(dut.ack, clk=bench.clk)
    bench.source.set_idle()
    await expect_no_output(bench.sink, clk=bench.clk, cycles=12)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="raw_eth_framer_tx_flat_wrapper")])
def test_RawEthFramerTx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rawethframertxflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": RAWETH_RTL_SOURCES + [WRAPPER_PATH]},
    )
