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
# - Sweep: Three clock-relationship cases: (a) lockstep 2:1 ratio via
#   start_lockstep_clocks (wrClk 5 ns, rdClk 10 ns), (b) async near-2:1 via
#   independent Clock coroutines (wrClk 5 ns, rdClk 10.3 ns), (c) equal-clock
#   gapped-valid (both 10 ns, validIn duty-cycled keeping pairs contiguous).
# - Stimulus: Drive contiguous pairs of 16-bit words with trigIn=1 on first
#   word and trigIn=0 on second; gapped case keeps each pair back-to-back
#   (a validIn gap resets the write-side accumulator).
# - Checks: 32-bit output word order (dataOut == 0xBBBBAAAA for inputs 0xAAAA
#   then 0xBBBB), trigOut[1:0] bit placement (trigOut[0]=1 for first word,
#   trigOut[1]=0 for second), validOut alignment, overflow='0' and
#   underflow='0' throughout all legal-use cases.
# - Timing: FWFT FIFO auto-reads (rd_en not driven); wait for rdClk-domain
#   validOut; sample after RisingEdge + Timer(1, "ns") to settle past TPD_G=1 ns.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)

# Maximum rdClk cycles to wait for validOut before declaring a timeout
_VALID_TIMEOUT_CYCLES = 64


class TB:
    """Dual-clock TB for Jesd16bTo32b.

    Reads CLOCK_CASE from the environment and starts clocks accordingly:
      - "lockstep" : start_lockstep_clocks for wrClk (5 ns) and rdClk (10 ns)
      - "async"    : independent Clock coroutines at 5 ns / 10.3 ns
      - "gapped"   : equal clocks (both 10 ns), validIn duty-cycled by test
    """

    def __init__(self, dut) -> None:
        self.dut = dut
        self.clock_case = os.environ.get("CLOCK_CASE", "lockstep")

        # Initialise all write-side inputs before clocks start (setimmediatevalue
        # avoids delta-cycle metastability on the very first simulation step).
        dut.validIn.setimmediatevalue(0)
        dut.dataIn.setimmediatevalue(0)
        dut.trigIn.setimmediatevalue(0)
        dut.wrRst.setimmediatevalue(1)
        dut.rdRst.setimmediatevalue(1)

        if self.clock_case == "lockstep":
            # True 2:1 lockstep — wrClk at 5 ns, rdClk at 10 ns.
            start_lockstep_clocks(dut.wrClk, period_ns=5.0)
            start_lockstep_clocks(dut.rdClk, period_ns=10.0)
        elif self.clock_case == "async":
            # Independent oscillators — near-2:1 with slight frequency offset
            # to exercise all FIFO CDC paths.
            cocotb.start_soon(Clock(dut.wrClk, 5.0, unit="ns").start())
            cocotb.start_soon(Clock(dut.rdClk, 10.3, unit="ns").start())
        else:
            # "gapped" — equal clocks; duty cycling is handled in the test
            # coroutine, not the clock infrastructure.
            cocotb.start_soon(Clock(dut.wrClk, 10.0, unit="ns").start())
            cocotb.start_soon(Clock(dut.rdClk, 10.0, unit="ns").start())

    async def reset(self) -> None:
        """Assert both domain resets for several cycles then deassert."""
        self.dut.wrRst.value = 1
        self.dut.rdRst.value = 1
        # Hold reset across several wrClk cycles
        for _ in range(6):
            await RisingEdge(self.dut.wrClk)
            await Timer(1, unit="ns")
        self.dut.wrRst.value = 0
        # Hold rdRst for a couple more rdClk cycles to be safe
        for _ in range(4):
            await RisingEdge(self.dut.rdClk)
            await Timer(1, unit="ns")
        self.dut.rdRst.value = 0
        # Quiet settling time after reset deassertion
        for _ in range(4):
            await RisingEdge(self.dut.wrClk)
            await Timer(1, unit="ns")

    async def write_word(self, data: int, trig: int) -> None:
        """Drive one 16-bit word on the write side on the next wrClk edge."""
        self.dut.validIn.value = 1
        self.dut.dataIn.value = data
        self.dut.trigIn.value = trig
        await RisingEdge(self.dut.wrClk)
        await Timer(1, unit="ns")

    async def write_pair(self, first: int, second: int,
                         trig_first: int = 1, trig_second: int = 0) -> None:
        """Drive a contiguous pair of 16-bit words (back-to-back, no gap).

        Contiguous means both words are driven with validIn='1' in consecutive
        wrClk cycles.  After the second word, validIn is deasserted.
        """
        await self.write_word(first, trig_first)
        await self.write_word(second, trig_second)
        self.dut.validIn.value = 0
        await Timer(1, unit="ns")

    async def wait_valid_out(self) -> None:
        """Block until validOut asserts on the rdClk domain (bounded)."""
        for _ in range(_VALID_TIMEOUT_CYCLES):
            await RisingEdge(self.dut.rdClk)
            await Timer(1, unit="ns")
            if int(self.dut.validOut.value) == 1:
                return
        raise AssertionError(
            f"validOut never asserted within {_VALID_TIMEOUT_CYCLES} rdClk cycles"
        )


@cocotb.test()
async def word_order_and_trig_test(dut):
    """Verify 16->32 word ordering, trigOut placement, validOut alignment.

    Drives the canonical pair (0xAAAA with trigIn=1, 0xBBBB with trigIn=0)
    and asserts:
      - dataOut == 0xBBBBAAAA (second-word high half, first-word low half)
      - trigOut == 0b01  (trig[0]=1 from first word, trig[1]=0 from second)
      - overflow == '0' and underflow == '0' throughout
    """
    tb = TB(dut)
    await tb.reset()

    overflow_seen = 0
    underflow_seen = 0

    # Drive several pairs and verify each output
    for _ in range(4):
        await tb.write_pair(0xAAAA, 0xBBBB, trig_first=1, trig_second=0)
        await tb.wait_valid_out()

        data_out = int(dut.dataOut.value)
        trig_out = int(dut.trigOut.value)
        overflow_seen |= int(dut.overflow.value)
        underflow_seen |= int(dut.underflow.value)

        assert data_out == 0xBBBBAAAA, (
            f"word ordering: expected 0xBBBBAAAA, got {data_out:#010x}"
        )
        assert trig_out == 0b01, (
            f"trigOut placement: expected 0b01, got {trig_out:#04b}"
        )

        # Wait for validOut to deassert before next pair
        for _ in range(8):
            await RisingEdge(dut.rdClk)
            await Timer(1, unit="ns")
            if int(dut.validOut.value) == 0:
                break

    assert overflow_seen == 0, "overflow asserted during legal-use test"
    assert underflow_seen == 0, "underflow asserted during legal-use test"


@cocotb.test()
async def trig_second_word_test(dut):
    """Verify trig[1] tracks the second 16-bit word.

    Drives a pair with trigIn=0 on first, trigIn=1 on second.
    Expects trigOut == 0b10.
    """
    tb = TB(dut)
    await tb.reset()

    await tb.write_pair(0x1234, 0x5678, trig_first=0, trig_second=1)
    await tb.wait_valid_out()

    data_out = int(dut.dataOut.value)
    trig_out = int(dut.trigOut.value)

    assert data_out == 0x56781234, (
        f"word ordering: expected 0x56781234, got {data_out:#010x}"
    )
    assert trig_out == 0b10, (
        f"trigOut placement: expected 0b10, got {trig_out:#04b}"
    )
    assert int(dut.overflow.value) == 0, "overflow asserted"
    assert int(dut.underflow.value) == 0, "underflow asserted"


@cocotb.test()
async def overflow_underflow_quiet_test(dut):
    """Assert overflow and underflow stay deasserted across a longer run."""
    tb = TB(dut)
    await tb.reset()

    overflow_seen = 0
    underflow_seen = 0

    clock_case = os.environ.get("CLOCK_CASE", "lockstep")

    if clock_case == "gapped":
        # Gapped case: duty-cycle validIn in groups of 2 (full pair), with
        # a gap of 2 cycles between pairs.  The gap resets the
        # write-side accumulator so only complete back-to-back pairs produce
        # 32-bit output words.
        for pair_idx in range(6):
            # Contiguous pair
            dut.validIn.value = 1
            dut.dataIn.value = 0xA000 + pair_idx
            dut.trigIn.value = 1
            await RisingEdge(dut.wrClk)
            await Timer(1, unit="ns")

            dut.dataIn.value = 0xB000 + pair_idx
            dut.trigIn.value = 0
            await RisingEdge(dut.wrClk)
            await Timer(1, unit="ns")

            # Gap — deassert validIn for 2 wrClk cycles (accumulator resets)
            dut.validIn.value = 0
            for _ in range(2):
                await RisingEdge(dut.wrClk)
                await Timer(1, unit="ns")
                overflow_seen |= int(dut.overflow.value)

            # Read side sampling
            await tb.wait_valid_out()
            underflow_seen |= int(dut.underflow.value)
            overflow_seen |= int(dut.overflow.value)

            # Wait for validOut to deassert
            for _ in range(8):
                await RisingEdge(dut.rdClk)
                await Timer(1, unit="ns")
                if int(dut.validOut.value) == 0:
                    break

    else:
        # lockstep / async: 8 consecutive pairs
        for pair_idx in range(8):
            await tb.write_pair(
                0xA000 + pair_idx, 0xB000 + pair_idx,
                trig_first=pair_idx % 2, trig_second=(pair_idx + 1) % 2,
            )
            overflow_seen |= int(dut.overflow.value)
            await tb.wait_valid_out()
            underflow_seen |= int(dut.underflow.value)
            overflow_seen |= int(dut.overflow.value)
            # Wait for validOut to deassert before next pair
            for _ in range(8):
                await RisingEdge(dut.rdClk)
                await Timer(1, unit="ns")
                if int(dut.validOut.value) == 0:
                    break

    assert overflow_seen == 0, "overflow asserted during legal-use run"
    assert underflow_seen == 0, "underflow asserted during legal-use run"


PARAMETER_SWEEP = [
    parameter_case("lockstep_2to1", CLOCK_CASE="lockstep"),
    parameter_case("async_near_2to1", CLOCK_CASE="async"),
    parameter_case("equal_gapped_valid", CLOCK_CASE="gapped"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Jesd16bTo32b(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesd16bto32b",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        sim_build_key=(
            "tests/sim_build/protocols/jesd204b/test_Jesd16bTo32b."
            + ".".join(f"{k}={v}" for k, v in parameters.items())
        ),
    )
