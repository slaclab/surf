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
# - Sweep: Run the direct `Pgp4RxEb` wrapper in three asynchronous clock modes
#   plus one same-clock, skip-disabled passthrough mode.
# - Stimulus: Drive ordered mixes of data words, valid K-words, SKP words, and
#   reset/overflow stress bursts directly into the PHY side of the elastic
#   buffer.  The skip-disabled mode drives a data word with an external link
#   error pulse to cover the no-elastic-buffer passthrough contract.
# - Checks: The DUT must forward non-SKP traffic in order, suppress SKP while
#   still updating `remLinkData`, flush buffered data on reset, and pulse
#   `overflow` when sustained write pressure outruns the read domain.
# - Timing: All output checks are sampled on `pgpRxClk`, while input traffic is
#   launched on `phyRxClk`, so the bench reflects the intended recovered-clock
#   versus local-clock boundary instead of a common-clock approximation.

from __future__ import annotations

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from tests.common.regression_utils import (
    env_flag,
    env_float,
    hdl_parameters_from,
    parameter_case,
    start_lockstep_clocks,
)
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    PGP4_D_HEADER,
    PGP4_K_HEADER,
    initialize_signals,
    pgp4_idle_word,
    pgp4_skip_word,
    signal_int,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


class Pgp4RxEbTB:
    """Dual-clock harness for the elastic-buffer wrapper.

    This stays local because the clock relationship is part of `Pgp4RxEb`
    itself, not a common pattern across the rest of the PGP4 family.
    """

    def __init__(self, dut):
        self.dut = dut
        self.phy_period_ns = env_float("PHY_CLK_PERIOD_NS", default=4.0)
        self.pgp_period_ns = env_float("PGP_CLK_PERIOD_NS", default=4.125)
        if env_flag("COMMON_CLK", default=False):
            start_lockstep_clocks(dut.phyClk, dut.pgpClk, period_ns=self.phy_period_ns)
        else:
            cocotb.start_soon(Clock(dut.phyClk, self.phy_period_ns, unit="ns").start())
            cocotb.start_soon(Clock(dut.pgpClk, self.pgp_period_ns, unit="ns").start())

    async def cycle_phy(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.phyClk)
            await Timer(1, unit="ns")

    async def cycle_pgp(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.pgpClk)
            await Timer(1, unit="ns")

    async def sample_pgp_cycle(self):
        await FallingEdge(self.dut.pgpClk)
        await Timer(1, unit="ps")

    async def reset(self, *, hold_cycles: int = 6, settle_cycles: int = 6):
        max_period_ns = max(self.phy_period_ns, self.pgp_period_ns)
        self.dut.rst.setimmediatevalue(1)
        await Timer(max_period_ns * hold_cycles, unit="ns")
        self.dut.rst.value = 0
        await self.cycle_phy(settle_cycles)
        await self.cycle_pgp(settle_cycles)


class PulseMonitor:
    """Background observer for one-shot outputs used by this async bench."""

    def __init__(self, dut, signal_name: str, *, step):
        self.dut = dut
        self.signal_name = signal_name
        self.step = step
        self.seen = False

    async def run(self):
        while True:
            await self.step()
            if signal_int(self.dut, self.signal_name) == 1:
                self.seen = True


class ValidBeatCollector:
    """Capture one-cycle valid/data beats in the background."""

    def __init__(self, dut, *, step, valid_name: str, field_names: tuple[str, ...]):
        self.dut = dut
        self.step = step
        self.valid_name = valid_name
        self.field_names = field_names
        self.beats: list[tuple[int, ...]] = []

    async def run(self):
        while True:
            await self.step()
            if signal_int(self.dut, self.valid_name) == 1:
                self.beats.append(tuple(signal_int(self.dut, name) for name in self.field_names))


async def wait_for_signal_in_domain(
    tb: Pgp4RxEbTB,
    name: str,
    *,
    value: int = 1,
    cycles: int = 256,
    domain: str = "pgp",
):
    cycle = tb.cycle_pgp if domain == "pgp" else tb.cycle_phy
    for _ in range(cycles):
        if signal_int(tb.dut, name) == value:
            return
        await cycle()
    raise AssertionError(f"Timed out waiting for {name}={value} on {domain} clock")


async def wait_for_collected_beats(collector: ValidBeatCollector, *, count: int, step, cycles: int = 256) -> list[tuple[int, ...]]:
    for _ in range(cycles):
        if len(collector.beats) >= count:
            return collector.beats[:count]
        await step()
    raise AssertionError(f"Timed out waiting for collected beats, saw {collector.beats!r}")


def initialize_phy_inputs(dut):
    """Drive the direct PHY-side wrapper inputs to a known idle state."""

    initialize_signals(dut, phyRxValid=0, phyRxData=0, phyRxHeader=0, phyRxLinkError=0)


async def send_phy_word(tb: Pgp4RxEbTB, *, header: int, data: int, link_error: int = 0):
    """Launch one PHY-side word for exactly one recovered-clock cycle."""

    tb.dut.phyRxHeader.value = header
    tb.dut.phyRxData.value = data
    tb.dut.phyRxLinkError.value = link_error
    tb.dut.phyRxValid.value = 1
    await tb.cycle_phy()
    tb.dut.phyRxValid.value = 0
    tb.dut.phyRxLinkError.value = 0


async def send_phy_words(tb: Pgp4RxEbTB, words: list[tuple[int, int]]):
    for header, data in words:
        await send_phy_word(tb, header=header, data=data)


def env_parameters_from(parameters: dict[str, object]) -> dict[str, object]:
    return {
        key: value
        for key, value in parameters.items()
        if not key.endswith("_G")
    }


async def collect_output_words(tb: Pgp4RxEbTB, *, count: int, cycles: int = 256) -> list[tuple[int, int]]:
    """Capture visible FIFO output words on the `pgpRxClk` side.

    The elastic buffer auto-reads whenever `valid` is asserted, so output words
    can appear for only one local clock cycle.  Sampling on the read-domain
    clock keeps the test aligned with the real consumer-facing contract.
    """

    words = []
    for _ in range(cycles):
        await tb.sample_pgp_cycle()
        if signal_int(tb.dut, "pgpRxValid") == 1:
            words.append(
                (
                    signal_int(tb.dut, "pgpRxHeader"),
                    signal_int(tb.dut, "pgpRxData"),
                )
            )
            if len(words) >= count:
                return words
    raise AssertionError("Timed out collecting elastic-buffer output words")


async def assert_no_output_words(tb: Pgp4RxEbTB, *, cycles: int):
    for _ in range(cycles):
        await tb.sample_pgp_cycle()
        assert signal_int(tb.dut, "pgpRxValid") == 0


@cocotb.test(
    skip=(
        env_flag("EXPECT_SKIP_DISABLED", default=False)
        or env_flag("EXPECT_OVERFLOW", default=False)
    ),
)
async def pgp4_rx_eb_filters_skip_and_preserves_stream_order(dut):
    tb = Pgp4RxEbTB(dut)
    initialize_phy_inputs(dut)
    await tb.reset()

    # The elastic buffer should pass ordinary data and ordinary K-words through
    # in order, but it should strip SKP words from the stream while still
    # exporting the remote link data field derived from the SKP payload.
    collector = ValidBeatCollector(
        dut,
        step=tb.sample_pgp_cycle,
        valid_name="pgpRxValid",
        field_names=("pgpRxHeader", "pgpRxData"),
    )
    cocotb.start_soon(collector.run())

    data_word_a = 0x0123456789ABCDEF
    idle_word = pgp4_idle_word(rem_link_ready=1, pause_mask=0x1234, overflow_mask=0x00A5)
    data_word_b = 0xFEDCBA9876543210
    skip_data = 0x123456789ABC

    await send_phy_words(
        tb,
        [
            (PGP4_D_HEADER, data_word_a),
            (PGP4_K_HEADER, pgp4_skip_word(skip_data)),
            (PGP4_K_HEADER, idle_word),
            (PGP4_D_HEADER, data_word_b),
        ],
    )

    words = await wait_for_collected_beats(collector, count=3, step=tb.cycle_pgp, cycles=256)
    assert words == [
        (PGP4_D_HEADER, data_word_a),
        (PGP4_K_HEADER, idle_word),
        (PGP4_D_HEADER, data_word_b),
    ]
    await wait_for_signal_in_domain(tb, "remLinkData", value=skip_data, cycles=64)

@cocotb.test(skip=env_flag("EXPECT_SKIP_DISABLED", default=False))
async def pgp4_rx_eb_reset_flushes_buffered_words(dut):
    tb = Pgp4RxEbTB(dut)
    initialize_phy_inputs(dut)
    await tb.reset()

    # Push a short burst into the write domain, reset both domains, and then
    # prove no stale FIFO words reappear afterward.  This is the practical
    # flush/reset corner case for an elastic buffer sitting between recovered
    # and local clocks.
    for index in range(16):
        await send_phy_word(tb, header=PGP4_D_HEADER, data=0xABC0000000000000 | index)

    await tb.reset()
    await assert_no_output_words(tb, cycles=24)

    marker_word = 0x55AA55AA55AA55AA
    await send_phy_word(tb, header=PGP4_D_HEADER, data=marker_word)
    words = await collect_output_words(tb, count=1, cycles=128)
    assert words == [(PGP4_D_HEADER, marker_word)]


@cocotb.test(
    skip=(
        env_flag("EXPECT_SKIP_DISABLED", default=False)
        or not env_flag("EXPECT_OVERFLOW", default=False)
    ),
)
async def pgp4_rx_eb_overflow_pulses_when_phy_outpaces_local_clock(dut):
    tb = Pgp4RxEbTB(dut)
    initialize_phy_inputs(dut)
    await tb.reset()

    # Overflow is not expected under the slight-drift case, so keep the normal
    # regression realistic and only execute the deep fill test when the pytest
    # parameter sweep requests the explicit overflow-stress clock ratio.
    overflow_monitor = PulseMonitor(dut, "overflow", step=tb.cycle_pgp)
    cocotb.start_soon(overflow_monitor.run())

    # The DUT uses a 512-entry async FIFO.  With the write clock much faster
    # than the read clock, a sustained burst should eventually overrun that
    # depth and produce a synchronized one-shot `overflow` indication.
    for index in range(768):
        await send_phy_word(tb, header=PGP4_D_HEADER, data=index)

    await tb.cycle_pgp(64)
    assert overflow_monitor.seen


@cocotb.test(skip=not env_flag("EXPECT_SKIP_DISABLED", default=False))
async def pgp4_rx_eb_skip_disabled_passes_stream_and_link_error(dut):
    tb = Pgp4RxEbTB(dut)
    initialize_phy_inputs(dut)
    await tb.reset()

    collector = ValidBeatCollector(
        dut,
        step=tb.sample_pgp_cycle,
        valid_name="pgpRxValid",
        field_names=("pgpRxHeader", "pgpRxData"),
    )
    link_error_monitor = PulseMonitor(dut, "linkError", step=tb.sample_pgp_cycle)
    cocotb.start_soon(collector.run())
    cocotb.start_soon(link_error_monitor.run())

    data_word = 0x123456789ABCDEF0
    await send_phy_word(tb, header=PGP4_D_HEADER, data=data_word, link_error=1)

    words = await wait_for_collected_beats(collector, count=1, step=tb.cycle_pgp, cycles=64)
    assert words == [(PGP4_D_HEADER, data_word)]
    assert link_error_monitor.seen


PARAMETER_SWEEP = [
    parameter_case(
        "async_drift_direct_wrapper",
        PHY_CLK_PERIOD_NS="4.000",
        PGP_CLK_PERIOD_NS="4.125",
        EXPECT_OVERFLOW="0",
    ),
    parameter_case(
        "async_near_empty_direct_wrapper",
        PHY_CLK_PERIOD_NS="4.500",
        PGP_CLK_PERIOD_NS="3.500",
        EXPECT_OVERFLOW="0",
    ),
    parameter_case(
        "async_overflow_stress_direct_wrapper",
        PHY_CLK_PERIOD_NS="2.000",
        PGP_CLK_PERIOD_NS="12.000",
        EXPECT_OVERFLOW="1",
    ),
    parameter_case(
        "same_clock_skip_disabled",
        SKIP_EN_G=False,
        PHY_CLK_PERIOD_NS="4.000",
        PGP_CLK_PERIOD_NS="4.000",
        COMMON_CLK="1",
        EXPECT_SKIP_DISABLED="1",
        EXPECT_OVERFLOW="0",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4RxEb(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4rxebwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4RxEbWrapper.vhd",
        parameters=hdl_parameters_from(parameters),
        extra_env=env_parameters_from(parameters),
    )
