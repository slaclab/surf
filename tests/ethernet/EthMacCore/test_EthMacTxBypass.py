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
# - Sweep: Exercise both `BYP_EN_G=true` and `BYP_EN_G=false`.
# - Stimulus: Start primary and bypass traffic together to test selection from
#   idle, then launch a bypass frame while a primary frame is already active.
# - Checks: With bypass enabled the bypass frame must win arbitration at idle
#   but must not preempt an already-active primary frame; with bypass disabled
#   the primary path must pass through unchanged and bypass traffic must be
#   dropped.
# - Timing: The bench uses real ready/valid handshakes on both sources so the
#   mux arbitration is checked under the DUT's own acceptance rules.
# - Sustained load: both sources offer four back-to-back frames from the same
#   cycle under seeded sink backpressure; frames must not interleave, each
#   source keeps its order, and with bypass enabled the strict bypass
#   priority sends every bypass frame before the first primary frame.

from __future__ import annotations

import cocotb
import os
import pytest
import random
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test, sample_after_tpd
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    FlatEmacEndpoint,
    assert_beat_list,
    build_ethernet_frame,
    cycle,
    expect_no_output,
    frame_beats_from_bytes,
    recv_frame,
    send_contiguous_frame,
    send_frame_burst,
    setup_flat_emac_testbench,
)
from tests.ethernet.EthMacCore.ethmac_line_models import resolved_int


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacTxBypassWrapper.vhd"
BYPASS_ETH_TYPE = 0x9000
PRIMARY_DEST_TAG_IDLE = 0x31
BYPASS_DEST_TAG_IDLE = 0x72
PRIMARY_DEST_TAG_BUSY = 0x44
BYPASS_DEST_TAG_BUSY = 0x55


@cocotb.test()
async def eth_mac_tx_bypass_arbitration_test(dut):
    bypass_enabled = os.environ["BYP_EN_G"].lower() == "true"
    bench = await setup_flat_emac_testbench(
        dut,
        source_prefix=None,
        initial_values={
            "mAxisTReady": 0,
        },
    )
    prim_source = FlatEmacEndpoint(dut, prefix="sPrim")
    byp_source = FlatEmacEndpoint(dut, prefix="sByp")
    sink = FlatEmacEndpoint(dut, prefix="mAxis")
    prim_source.set_idle()
    byp_source.set_idle()

    primary_frame = build_ethernet_frame(
        dst_mac=0x010203040506,
        src_mac=0x111213141516,
        eth_type=0x88B5,
        payload=b"tx-bypass-primary-idle" + bytes(range(28)),
    )
    bypass_frame = build_ethernet_frame(
        dst_mac=0x212223242526,
        src_mac=0x313233343536,
        # `0x9000` is the wrapper's configured bypass EtherType on the wire.
        eth_type=BYPASS_ETH_TYPE,
        payload=b"tx-bypass-wins-idle" + bytes(range(29)),
    )
    # The wrapper exports distinct destination tags for the primary and bypass
    # ingress ports so arbitration decisions are visible in the captured beats.
    primary_expected = frame_beats_from_bytes(primary_frame, dest=PRIMARY_DEST_TAG_IDLE)
    bypass_expected = frame_beats_from_bytes(bypass_frame, dest=BYPASS_DEST_TAG_IDLE, eofe=1)

    primary_send = cocotb.start_soon(send_contiguous_frame(prim_source, primary_expected, clk=bench.clk))
    bypass_send = cocotb.start_soon(send_contiguous_frame(byp_source, bypass_expected, clk=bench.clk))
    first_observed = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=96)

    if bypass_enabled:
        assert_beat_list(first_observed, bypass_expected)
        second_observed = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=96)
        assert_beat_list(second_observed, primary_expected)
    else:
        assert_beat_list(first_observed, primary_expected)
        await expect_no_output(sink, clk=bench.clk, cycles=8)

    await primary_send
    await bypass_send

    long_primary = build_ethernet_frame(
        dst_mac=0x414243444546,
        src_mac=0x515253545556,
        eth_type=0x88B5,
        payload=bytes(range(80)),
    )
    late_bypass = build_ethernet_frame(
        dst_mac=0x616263646566,
        src_mac=0x717273747576,
        eth_type=BYPASS_ETH_TYPE,
        payload=b"late-bypass-frame" + bytes(range(24)),
    )
    long_primary_expected = frame_beats_from_bytes(long_primary, dest=PRIMARY_DEST_TAG_BUSY)
    late_bypass_expected = frame_beats_from_bytes(late_bypass, dest=BYPASS_DEST_TAG_BUSY)

    long_primary_send = cocotb.start_soon(send_contiguous_frame(prim_source, long_primary_expected, clk=bench.clk))
    await cycle(bench.clk, 2)
    late_bypass_send = cocotb.start_soon(send_contiguous_frame(byp_source, late_bypass_expected, clk=bench.clk))
    first_sequence = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=128)
    assert_beat_list(first_sequence, long_primary_expected)

    if bypass_enabled:
        second_sequence = await recv_frame(sink, clk=bench.clk, ready_signal=dut.mAxisTReady, timeout_cycles=96)
        assert_beat_list(second_sequence, late_bypass_expected)
    else:
        await expect_no_output(sink, clk=bench.clk, cycles=8)

    await long_primary_send
    await late_bypass_send


class AcceptedOutputMonitor:
    """Record beats accepted on the mux output (`TVALID` and `TREADY`)."""

    def __init__(self, clk, endpoint: FlatEmacEndpoint, ready_signal):
        self.clk = clk
        self.endpoint = endpoint
        self.ready = ready_signal
        self.frames = []
        self.partial = []
        self.task = cocotb.start_soon(self._run())

    async def _run(self) -> None:
        """Lifetime agent: record accepted mux output beats until the test ends."""
        while True:
            await RisingEdge(self.clk)
            if resolved_int(self.endpoint._sig("TValid")) and resolved_int(self.ready):
                self.partial.append(self.endpoint.snapshot())
                if self.partial[-1].last:
                    self.frames.append(self.partial)
                    self.partial = []


async def drive_random_ready(ready_signal, *, clk, rng: random.Random, cycles: int) -> None:
    # Seeded sink backpressure for a bounded number of cycles, then ready.
    for _ in range(cycles):
        await sample_after_tpd(clk)
        ready_signal.value = 1 if rng.random() < 0.6 else 0
    await sample_after_tpd(clk)
    ready_signal.value = 1


@cocotb.test()
async def eth_mac_tx_bypass_sustained_load_test(dut):
    bypass_enabled = os.environ["BYP_EN_G"].lower() == "true"
    seed = int(os.environ.get("ETHMAC_TX_BYPASS_SEED", "4242"))
    rng = random.Random(seed)
    bench = await setup_flat_emac_testbench(dut, source_prefix=None, initial_values={"mAxisTReady": 0})
    prim_source = FlatEmacEndpoint(dut, prefix="sPrim")
    byp_source = FlatEmacEndpoint(dut, prefix="sByp")
    prim_source.set_idle()
    byp_source.set_idle()
    out = AcceptedOutputMonitor(bench.clk, FlatEmacEndpoint(dut, prefix="mAxis"), dut.mAxisTReady)

    def make_frames(tag: int, eth_type: int) -> list:
        frames = []
        for index in range(4):
            length = rng.randint(14, 80)
            frame = build_ethernet_frame(
                dst_mac=0x020000000000 | (tag << 8) | index,
                src_mac=0x020000000099,
                eth_type=eth_type,
                payload=bytes(rng.getrandbits(8) for _ in range(length - 14)),
            )
            frames.append(frame_beats_from_bytes(frame, dest=tag + index))
        return frames

    # Both sources offer four back-to-back frames from the same cycle while
    # the sink applies seeded backpressure.
    prim_frames = make_frames(0x10, 0x88B5)
    byp_frames = make_frames(0x80, BYPASS_ETH_TYPE)
    ready_task = cocotb.start_soon(drive_random_ready(dut.mAxisTReady, clk=bench.clk, rng=rng, cycles=120))
    prim_send = cocotb.start_soon(send_frame_burst(prim_source, prim_frames, clk=bench.clk))
    byp_send = cocotb.start_soon(send_frame_burst(byp_source, byp_frames, clk=bench.clk))
    await ready_task
    await prim_send
    await byp_send
    await cycle(bench.clk, 16)

    # Frames never interleave and each source keeps its order. With bypass
    # enabled the arbitration is strict priority (IDLE_S checks bypass
    # first), so back-to-back bypass frames all go before any primary frame;
    # with bypass disabled the bypass port is discarded (ready forced high).
    expected = (byp_frames + prim_frames) if bypass_enabled else prim_frames
    assert not out.partial, f"seed={seed}: partial output frame"
    assert len(out.frames) == len(expected), f"BYP_EN_G={bypass_enabled} seed={seed}: {len(out.frames)} frames"
    for observed, frame in zip(out.frames, expected, strict=True):
        assert_beat_list(observed, frame)


PARAMETER_SWEEP = [
    parameter_case("bypass_enabled", BYP_EN_G=True),
    parameter_case("bypass_disabled", BYP_EN_G=False),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacTxBypass(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmactxbypasswrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
