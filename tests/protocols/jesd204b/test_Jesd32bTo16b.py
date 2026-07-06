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
#   gapped-valid (both 10 ns, validIn duty-cycled).
# - Stimulus: Drive one 32-bit word per write cycle; observe two 16-bit output
#   words in sequence on the rdClk domain.
# - Checks: 32-bit input 0xBBBBAAAA emits 0xAAAA (low half, first) then 0xBBBB
#   (high half, second) with trigOut tracking the per-half trig bit; validOut
#   alignment accounting for 1-cc registered delay; overflow='0' and
#   underflow='0' throughout all legal-use cases.
# - Timing: RTL toggles its own rdEn on alternate cycles (do NOT drive rdEn
#   from the test); validOut is r.valid (1-cc pipeline delay from FIFO valid);
#   sample after RisingEdge + Timer(1, "ns") to settle past TPD_G=1 ns.

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
    """Dual-clock TB for Jesd32bTo16b.

    Reads CLOCK_CASE from the environment and starts clocks accordingly:
      - "lockstep" : start_lockstep_clocks for wrClk (5 ns) and rdClk (10 ns)
      - "async"    : independent Clock coroutines at 5 ns / 10.3 ns
      - "gapped"   : equal clocks (both 10 ns), validIn duty-cycled by test
    """

    def __init__(self, dut) -> None:
        self.dut = dut
        self.clock_case = os.environ.get("CLOCK_CASE", "lockstep")

        # Initialise all write-side inputs before clocks start.
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
            # Independent oscillators — near-2:1 with slight frequency offset.
            cocotb.start_soon(Clock(dut.wrClk, 5.0, unit="ns").start())
            cocotb.start_soon(Clock(dut.rdClk, 10.3, unit="ns").start())
        else:
            # "gapped" — equal clocks; duty cycling handled in test coroutine.
            cocotb.start_soon(Clock(dut.wrClk, 10.0, unit="ns").start())
            cocotb.start_soon(Clock(dut.rdClk, 10.0, unit="ns").start())

    async def reset(self) -> None:
        """Assert both domain resets for several cycles then deassert."""
        self.dut.wrRst.value = 1
        self.dut.rdRst.value = 1
        for _ in range(6):
            await RisingEdge(self.dut.wrClk)
            await Timer(1, unit="ns")
        self.dut.wrRst.value = 0
        for _ in range(4):
            await RisingEdge(self.dut.rdClk)
            await Timer(1, unit="ns")
        self.dut.rdRst.value = 0
        # Quiet settling time after reset deassertion
        for _ in range(4):
            await RisingEdge(self.dut.wrClk)
            await Timer(1, unit="ns")

    async def write_word(self, data: int, trig: int) -> None:
        """Drive one 32-bit word with the given trig[1:0] value on the write side."""
        self.dut.validIn.value = 1
        self.dut.dataIn.value = data
        self.dut.trigIn.value = trig
        await RisingEdge(self.dut.wrClk)
        await Timer(1, unit="ns")
        self.dut.validIn.value = 0
        await Timer(1, unit="ns")

    async def wait_valid_out(self) -> None:
        """Block until validOut asserts on the rdClk domain (bounded).

        validOut is r.valid — it has a 1-cc pipeline delay from the FIFO
        valid signal — so we poll rdClk rising edges after Timer(1, "ns").
        """
        for _ in range(_VALID_TIMEOUT_CYCLES):
            await RisingEdge(self.dut.rdClk)
            await Timer(1, unit="ns")
            if int(self.dut.validOut.value) == 1:
                return
        raise AssertionError(
            f"validOut never asserted within {_VALID_TIMEOUT_CYCLES} rdClk cycles"
        )

    async def wait_valid_deassert(self, max_cycles: int = 16) -> None:
        """Wait until validOut deasserts (bounded)."""
        for _ in range(max_cycles):
            await RisingEdge(self.dut.rdClk)
            await Timer(1, unit="ns")
            if int(self.dut.validOut.value) == 0:
                return


@cocotb.test()
async def word_order_and_trig_test(dut):
    """Verify 32->16 word ordering, trigOut placement, validOut alignment.

    Drives 0xBBBBAAAA with trigIn=0b01 and asserts:
      - First output: dataOut == 0xAAAA (low half) with trigOut == 1 (trig[0])
      - Second output: dataOut == 0xBBBB (high half) with trigOut == 0 (trig[1])
      - overflow == '0' and underflow == '0' throughout
    """
    tb = TB(dut)
    await tb.reset()

    overflow_seen = 0
    underflow_seen = 0

    for _ in range(4):
        # Write the 32-bit word with trigIn[0]=1, trigIn[1]=0 (i.e. trigIn=0b01)
        await tb.write_word(0xBBBBAAAA, trig=0b01)

        # First 16-bit output: low half 0xAAAA, trig[0]=1
        await tb.wait_valid_out()
        first_data = int(dut.dataOut.value)
        first_trig = int(dut.trigOut.value)
        overflow_seen |= int(dut.overflow.value)
        underflow_seen |= int(dut.underflow.value)

        assert first_data == 0xAAAA, (
            f"first half: expected 0xAAAA, got {first_data:#06x}"
        )
        assert first_trig == 1, (
            f"first trig: expected 1 (trig[0]=1), got {first_trig}"
        )

        # Second 16-bit output: high half 0xBBBB, trig[1]=0
        await tb.wait_valid_out()
        second_data = int(dut.dataOut.value)
        second_trig = int(dut.trigOut.value)
        overflow_seen |= int(dut.overflow.value)
        underflow_seen |= int(dut.underflow.value)

        assert second_data == 0xBBBB, (
            f"second half: expected 0xBBBB, got {second_data:#06x}"
        )
        assert second_trig == 0, (
            f"second trig: expected 0 (trig[1]=0), got {second_trig}"
        )

        # Wait for validOut to deassert before next word
        await tb.wait_valid_deassert()

    assert overflow_seen == 0, "overflow asserted during legal-use test"
    assert underflow_seen == 0, "underflow asserted during legal-use test"


@cocotb.test()
async def trig_high_half_test(dut):
    """Verify trigOut tracks the high-half trig bit (trig[1]).

    Drives 0x56781234 with trigIn=0b10 and asserts:
      - First output: dataOut == 0x1234, trigOut == 0 (trig[0]=0)
      - Second output: dataOut == 0x5678, trigOut == 1 (trig[1]=1)
    """
    tb = TB(dut)
    await tb.reset()

    await tb.write_word(0x56781234, trig=0b10)

    # First half: low word, trig[0]=0
    await tb.wait_valid_out()
    first_data = int(dut.dataOut.value)
    first_trig = int(dut.trigOut.value)
    assert first_data == 0x1234, f"first half: expected 0x1234, got {first_data:#06x}"
    assert first_trig == 0, f"first trig: expected 0, got {first_trig}"

    # Second half: high word, trig[1]=1
    await tb.wait_valid_out()
    second_data = int(dut.dataOut.value)
    second_trig = int(dut.trigOut.value)
    assert second_data == 0x5678, f"second half: expected 0x5678, got {second_data:#06x}"
    assert second_trig == 1, f"second trig: expected 1, got {second_trig}"

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
        # Gapped case: duty-cycle validIn with a gap between words.
        for word_idx in range(6):
            # Write one 32-bit word
            dut.validIn.value = 1
            dut.dataIn.value = 0xA000_0000 + word_idx
            dut.trigIn.value = 0b01
            await RisingEdge(dut.wrClk)
            await Timer(1, unit="ns")
            # Gap: deassert validIn for 2 cycles
            dut.validIn.value = 0
            for _ in range(2):
                await RisingEdge(dut.wrClk)
                await Timer(1, unit="ns")
                overflow_seen |= int(dut.overflow.value)

            # Collect the two output halves
            await tb.wait_valid_out()
            underflow_seen |= int(dut.underflow.value)
            overflow_seen |= int(dut.overflow.value)
            await tb.wait_valid_out()
            underflow_seen |= int(dut.underflow.value)
            overflow_seen |= int(dut.overflow.value)
            await tb.wait_valid_deassert()

    else:
        # lockstep / async: 8 consecutive 32-bit words
        for word_idx in range(8):
            await tb.write_word(
                0xA000_0000 + word_idx,
                trig=(word_idx % 3),
            )
            overflow_seen |= int(dut.overflow.value)

            # Collect the two output halves
            await tb.wait_valid_out()
            underflow_seen |= int(dut.underflow.value)
            overflow_seen |= int(dut.overflow.value)
            await tb.wait_valid_out()
            underflow_seen |= int(dut.underflow.value)
            overflow_seen |= int(dut.overflow.value)
            await tb.wait_valid_deassert()

    assert overflow_seen == 0, "overflow asserted during legal-use run"
    assert underflow_seen == 0, "underflow asserted during legal-use run"


PARAMETER_SWEEP = [
    parameter_case("lockstep_2to1", CLOCK_CASE="lockstep"),
    parameter_case("async_near_2to1", CLOCK_CASE="async"),
    parameter_case("equal_gapped_valid", CLOCK_CASE="gapped"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Jesd32bTo16b(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesd32bto16b",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
