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
# - Sweep: `FILT_EN_G` true (runtime filter) and false (the filter is not
#   instantiated). test_EthMacRxFilter keeps the original directed walk; this
#   file adds the address-class matrix and the frame-boundary rules.
# - DUT shape: EthMacRxFilterWrapper; the stage has no backpressure, so frames
#   are driven back to back with no gap and every output beat is recorded.
# - Stimulus: seeded shuffles of eight destination classes (local, local with
#   one bit flipped, foreign unicast, locally administered unicast, broadcast,
#   IPv4 and IPv6 multicast, MAC control) in one- to five-beat frames, with
#   `filtEnable` 1 and 0; `filtEnable`, `mAxisPause` and `dropOnPause`
#   changed on a middle beat of a frame; and pause-drop precedence checks.
# - Checks: delivered frames match the expected subset beat for beat (data,
#   keep, SOF, EOFE, last), in order, with nothing from a dropped frame. The
#   pass/drop decision is taken on the SOF beat only.
# - Timing: output beats are sampled on rising edges before the registered
#   `TPD_G` update; inputs change after the sampled edge.
# - Baseline: with `FILT_EN_G=false`, `dropOnPause` has no effect (the
#   pause drop lives inside the generated filter).

from __future__ import annotations

import os
import random

import cocotb
import pytest
from cocotb.triggers import RisingEdge

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test, sample_after_tpd
from tests.ethernet.EthMacCore.ethmac_line_models import describe_case, resolved_int
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES,
    EmacBeat,
    FlatEmacEndpoint,
    build_ethernet_frame,
    cycle,
    frame_beats_from_bytes,
    mac_config_word_from_wire,
    setup_flat_emac_testbench,
)


WRAPPER_PATH = "ethernet/EthMacCore/wrappers/EthMacRxFilterWrapper.vhd"
SEED = int(os.environ.get("ETHMAC_RX_FILTER_SEED", "1588"))
LOCAL_MAC = 0x0A1122334455

# Destination classes and whether an enabled filter passes them.
ADDRESS_CLASSES = {
    "local": (LOCAL_MAC, True),
    "local_bit_flip": (LOCAL_MAC ^ 0x000000000100, False),
    "foreign_unicast": (0x00AA00BB00CC, False),
    "locally_administered": (0x02AA00BB00CC, False),
    "broadcast": (0xFFFFFFFFFFFF, True),
    "ipv4_multicast": (0x01005E0000FB, True),
    "ipv6_multicast": (0x333300000001, True),
    "mac_control": (0x0180C2000001, True),
}


class OutputMonitor:
    """Record every output beat; the filter output has no `TREADY`."""

    def __init__(self, clk, endpoint: FlatEmacEndpoint):
        self.clk = clk
        self.endpoint = endpoint
        self.frames: list[list[EmacBeat]] = []
        self.partial: list[EmacBeat] = []
        self.task = cocotb.start_soon(self._run())

    async def _run(self) -> None:
        """Lifetime agent: record output beats until the test ends."""
        while True:
            await RisingEdge(self.clk)
            if resolved_int(self.endpoint._sig("TValid")):
                self.partial.append(self.endpoint.snapshot())
                if self.partial[-1].last:
                    self.frames.append(self.partial)
                    self.partial = []


class FilterBench:
    def __init__(self, dut, bench):
        self.dut = dut
        self.clk = bench.clk
        self.source = bench.source
        self.out = OutputMonitor(self.clk, bench.sink)
        self.filt_generic = env_flag("FILT_EN_G", default=True)
        self.rng = random.Random(SEED)

    @classmethod
    async def create(cls, dut):
        bench = await setup_flat_emac_testbench(
            dut,
            source_prefix="sAxis",
            sink_prefix="mAxis",
            initial_values={
                "mAxisPause": 0,
                "dropOnPause": 0,
                "macAddress": mac_config_word_from_wire(LOCAL_MAC),
                "filtEnable": 1,
            },
        )
        return cls(dut, bench)

    def frame(self, dst_mac: int, beats: int) -> list[EmacBeat]:
        # 14-byte header plus payload sized to land in `beats` 16-byte beats.
        length = max(14, beats * 16 - self.rng.randrange(0, 12))
        payload = bytes(self.rng.getrandbits(8) for _ in range(length - 14))
        beat_list = frame_beats_from_bytes(build_ethernet_frame(dst_mac=dst_mac, src_mac=0x0A0B0C0D0E0F, eth_type=0x88B5, payload=payload))
        assert len(beat_list) == beats
        return beat_list

    async def drive(self, frames: list[list[EmacBeat]], actions: dict[tuple[int, int], dict[str, int]] | None = None) -> None:
        """Drive frames back to back, one beat per cycle.

        `actions[(frame, beat)]` sets control inputs together with that beat,
        so they are sampled on the same edge.
        """
        actions = actions or {}
        for frame_index, frame in enumerate(frames):
            for beat_index, beat in enumerate(frame):
                await sample_after_tpd(self.clk)
                self.source.drive(beat)
                for name, value in actions.get((frame_index, beat_index), {}).items():
                    getattr(self.dut, name).value = value
        await sample_after_tpd(self.clk)
        self.source.set_idle()
        await cycle(self.clk, 4)

    def check(self, expected: list[list[EmacBeat]], context: str) -> None:
        observed, self.out.frames = self.out.frames, []
        assert not self.out.partial, f"{context}: partial frame {self.out.partial}"
        assert len(observed) == len(expected), f"{context}: {len(observed)} frames delivered, {len(expected)} expected"
        for index, (obs, exp) in enumerate(zip(observed, expected, strict=True)):
            assert obs == exp, f"{context}: delivered frame {index} differs"


@cocotb.test()
async def rx_filter_address_class_test(dut):
    tb = await FilterBench.create(dut)

    for filt_enable in (1, 0):
        # Three seeded shuffles of every class, mixing one- to five-beat
        # frames, driven with no gap between frames.
        await sample_after_tpd(tb.clk)
        dut.filtEnable.value = filt_enable
        plan = [name for _ in range(3) for name in ADDRESS_CLASSES]
        tb.rng.shuffle(plan)
        frames = [tb.frame(ADDRESS_CLASSES[name][0], tb.rng.randint(1, 5)) for name in plan]
        await tb.drive(frames)
        passes = [not (tb.filt_generic and filt_enable) or ADDRESS_CLASSES[name][1] for name in plan]
        expected = [frame for frame, keep in zip(frames, passes, strict=True) if keep]
        context = f"FILT_EN_G={tb.filt_generic} filtEnable={filt_enable} seed={SEED} plan={plan}"
        tb.check(expected, context)


@cocotb.test()
async def rx_filter_decision_at_sof_test(dut):
    tb = await FilterBench.create(dut)
    foreign = ADDRESS_CLASSES["foreign_unicast"][0]
    gen = tb.filt_generic

    # `filtEnable` falling during a foreign frame does not rescue its tail,
    # and rising during a foreign frame accepted with the filter off does not
    # cut it short. The frame after each follows the new setting.
    frames = [tb.frame(foreign, 4), tb.frame(foreign, 3), tb.frame(foreign, 4), tb.frame(foreign, 2)]
    await tb.drive(frames, {(0, 2): {"filtEnable": 0}, (2, 1): {"filtEnable": 1}})
    expected = frames if not gen else [frames[1], frames[2]]
    tb.check(expected, f"filtEnable mid-frame {describe_case(SEED, 0)}")

    # Pause rising during a passing frame (with `dropOnPause`) does not
    # truncate it; pause falling during a dropped frame does not leak its
    # tail. The decision is taken on the SOF beat.
    await sample_after_tpd(tb.clk)
    dut.dropOnPause.value = 1
    local = ADDRESS_CLASSES["local"][0]
    frames = [tb.frame(local, 4), tb.frame(local, 4), tb.frame(local, 3)]
    await tb.drive(frames, {(0, 2): {"mAxisPause": 1}, (1, 2): {"mAxisPause": 0}})
    expected = frames if not gen else [frames[0], frames[2]]
    tb.check(expected, f"pause mid-frame {describe_case(SEED, 1)}")

    # `dropOnPause` drops every class while pause is high, even with
    # `filtEnable=0`. Without `dropOnPause`, pause has no effect. Baseline:
    # with FILT_EN_G=false neither setting drops anything.
    broadcast = ADDRESS_CLASSES["broadcast"][0]
    await sample_after_tpd(tb.clk)
    dut.filtEnable.value = 0
    dut.mAxisPause.value = 1
    frames = [tb.frame(broadcast, 2), tb.frame(foreign, 1), tb.frame(local, 3)]
    await tb.drive(frames)
    tb.check(frames if not gen else [], f"dropOnPause with filtEnable=0 {describe_case(SEED, 2)}")
    await sample_after_tpd(tb.clk)
    dut.dropOnPause.value = 0
    frames = [tb.frame(foreign, 2), tb.frame(local, 1)]
    await tb.drive(frames)
    tb.check(frames, f"pause without dropOnPause {describe_case(SEED, 3)}")


PARAMETER_SWEEP = [
    parameter_case("filter_generated", FILT_EN_G="true"),
    parameter_case("filter_not_generated", FILT_EN_G="false"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_EthMacRxFilterPolicy(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ethmacrxfilterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + [WRAPPER_PATH]},
    )
