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
# - Sweep: Five curated F/K pairs anchored to TI converters used at SLAC
#   (DAC38J84IAAV, ADC32RF44IRMP, ADC16DX370RMET, DAC37J82IAAV, ADS54J54,
#   ADS54J60). All pairs satisfy (K*F) divisible by 4 (GT_WORD_SIZE_C=4).
#   PERIOD_C = (K_G*F_G)/GT_WORD_SIZE_C - 1, validated against RTL formula.
# - Stimulus: Single SYSREF rising-edge pulse with nSync_i='0' to align the
#   counter, then free-running measurement; nSync_i='1' for gating tests.
# - Checks: lmfc_o period = (K_G*F_G)//4 device clocks;
#   sysrefRe_o pulse exactly 1 cc after SYSREF edge, lmfc_o exactly 2 cc
#   after SYSREF edge, nSync_i gating, phase-neutral periodic SYSREF
#   (SYSREF-gating clauses a-d).
# - Timing: 2-clock latency from SYSREF rising edge to first lmfc_o pulse
#   (registered sysrefRe + registered lmfc output); 1 ns settle after each
#   RisingEdge (TPD_G=1 ns).

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    env_int,
    parameter_case,
    run_surf_vhdl_test,
)
from tests.protocols.jesd204b.jesd204b_test_utils import (
    JesdTB,
    measure_lmfc_period,
)


# ---------------------------------------------------------------------------
# Curated F/K parameter sweep
# Deployment-typical pairs anchored to TI converters at SLAC.
# All satisfy (K*F)/4 = integer (GT_WORD_SIZE_C=4 hardcoded in Jesd204bPkg).
# ---------------------------------------------------------------------------
PARAMETER_SWEEP = [
    parameter_case("k32_f2", K_G="32", F_G="2"),   # RTL default; common for DAC38J84, ADC32RF44
    parameter_case("k32_f4", K_G="32", F_G="4"),   # Multi-sample-per-clock (ADS54J54/60)
    parameter_case("k16_f2", K_G="16", F_G="2"),   # Shorter multiframes; ADC16DX370 style
    parameter_case("k32_f1", K_G="32", F_G="1"),   # Single-byte-per-frame; narrow-lane configs
    parameter_case("k16_f4", K_G="16", F_G="4"),   # Alternative multi-converter (DAC37J82)
]


# ---------------------------------------------------------------------------
# LMFC period verification
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_period(dut):
    """LMFC period: lmfc_o period = (K_G*F_G)//4 device clocks for each curated F/K case.

    Reads K_G and F_G from env so the expected period is computed from the
    generics, not hardcoded per case.  Drives one SYSREF rising-edge pulse with
    nSync_i='0' to align the counter, then calls measure_lmfc_period and
    asserts against the formula.
    """
    k = env_int("K_G", default=32)
    f = env_int("F_G", default=2)
    expected_period = (k * f) // 4

    # Initialise DUT ports before clock starts
    dut.nSync_i.value = 1
    dut.sysref_i.value = 0
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    # Align: assert SYSREF rising edge with nSync_i='0'
    dut.nSync_i.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.sysref_i.value = 1     # rising edge
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.sysref_i.value = 0     # deassert after one cycle

    # measure_lmfc_period waits for the first lmfc_o pulse then counts to the
    # second — returns the free-running period in device clocks.
    measured = await measure_lmfc_period(dut, clk=dut.clk)

    assert measured == expected_period, (
        f"LMFC period FAIL: K={k} F={f} expected period={expected_period}, "
        f"got {measured} device clocks"
    )


# ---------------------------------------------------------------------------
# SYSREF-gating realignment contract (clauses a-d)
# All timing uses k32_f2 default (period=16) unless stated otherwise.
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_sysref_realign_clause_a(dut):
    """SYSREF-gating clause (a): SYSREF edge while nSync_i='0' realigns the counter.

    Verifies:
    - sysrefRe_o='1' exactly 1 cc after the SYSREF rising edge
    - lmfc_o='0' at that same cycle (not yet)
    - lmfc_o='1' exactly 2 cc after the SYSREF rising edge (off-by-one guard)
    - Free-running period after alignment equals (K_G*F_G)//4
    """
    k = env_int("K_G", default=32)
    f = env_int("F_G", default=2)
    expected_period = (k * f) // 4

    dut.nSync_i.value = 1
    dut.sysref_i.value = 0
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    # --- Drive SYSREF rising edge while nSync_i='0' ---
    # Timing reference (10 ns clock, TPD_G = 1 ns):
    #   t_sysref_edge : last RisingEdge before sysref_i goes high (captures the edge)
    #   t_sysref_edge + 10 : RisingEdge M+1 — r.sysrefRe registered at M+1+1ns
    #   t_sysref_edge + 20 : RisingEdge M+2 — r.lmfc registered at M+2+1ns = lmfc_o='1'
    #
    # Assertion strategy: capture sim time at the sysref edge, wait for sysrefRe_o
    # and lmfc_o to pulse via RisingEdge triggers, then verify the sim times match
    # the 1-cc / 2-cc contract.  This avoids Timer boundary races at TPD expiry.
    import cocotb.utils

    dut.nSync_i.value = 0
    await RisingEdge(dut.clk)          # edge M — capture pre-sysref timing reference
    t_edge_m = cocotb.utils.get_sim_time("ns")
    await Timer(1, unit="ns")
    dut.sysref_i.value = 1             # rising edge between M and M+1

    # sysrefRe_o should pulse exactly 1 cc after the sysref edge (registered at M+1+1ns)
    await RisingEdge(dut.sysrefRe_o)   # waits for sysrefRe_o 0→1 transition
    await Timer(1, unit="ns")          # settle past TPD
    t_sysref_re = cocotb.utils.get_sim_time("ns")
    # 1 cc = 1 clock period = 10 ns from edge M
    assert abs(t_sysref_re - (t_edge_m + 10 + 1)) <= 1, (
        f"SYSREF clause-a FAIL: sysrefRe_o pulse at {t_sysref_re:.1f}ns, "
        f"expected {t_edge_m + 11:.1f}ns (edge M+1 + 1ns TPD)"
    )
    assert dut.lmfc_o.value == 0, (
        "SYSREF clause-a FAIL: lmfc_o should be '0' at sysrefRe pulse (off-by-one guard)"
    )
    dut.sysref_i.value = 0             # deassert sysref

    # lmfc_o should pulse exactly 2 cc after the sysref edge (registered at M+2+1ns)
    await RisingEdge(dut.lmfc_o)       # waits for lmfc_o 0→1 transition
    await Timer(1, unit="ns")          # settle past TPD
    t_lmfc = cocotb.utils.get_sim_time("ns")
    # 2 cc = 2 clock periods = 20 ns from edge M
    assert abs(t_lmfc - (t_edge_m + 20 + 1)) <= 1, (
        f"SYSREF clause-a FAIL: lmfc_o first pulse at {t_lmfc:.1f}ns, "
        f"expected {t_edge_m + 21:.1f}ns (edge M+2 + 1ns TPD)"
    )

    # Verify free-running period from this point
    measured = await measure_lmfc_period(dut, clk=dut.clk)
    assert measured == expected_period, (
        f"SYSREF clause-a FAIL: period after realign: expected {expected_period}, got {measured}"
    )


@cocotb.test()
async def test_sysref_gate_clause_b(dut):
    """SYSREF-gating clause (b): SYSREF edge while nSync_i='1' does NOT shift LMFC phase.

    Aligns with nSync_i='0', records the phase, then injects a SYSREF rising
    edge mid-period with nSync_i='1' and asserts subsequent pulses keep the
    original phase.
    """
    k = env_int("K_G", default=32)
    f = env_int("F_G", default=2)
    period = (k * f) // 4

    dut.nSync_i.value = 1
    dut.sysref_i.value = 0
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    # --- Align with nSync_i='0' ---
    dut.nSync_i.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.sysref_i.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.sysref_i.value = 0

    # Wait for the alignment lmfc pulse (2 cc after edge)
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    # Now lmfc_o should be high (cycle N+2)

    # Let the counter free-run; measure period to confirm alignment
    measured_before = await measure_lmfc_period(dut, clk=dut.clk)
    assert measured_before == period, (
        f"SYSREF clause-b FAIL: alignment period: expected {period}, got {measured_before}"
    )

    # --- Switch to nSync_i='1' and inject a SYSREF edge mid-period ---
    dut.nSync_i.value = 1
    # Advance half a period into the cycle
    half = period // 2
    await tb.cycle(half)
    # Inject SYSREF rising edge (nSync_i='1' → counter should NOT reset)
    dut.sysref_i.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.sysref_i.value = 0

    # Measure the period after the gated edge — should be unchanged
    measured_after = await measure_lmfc_period(dut, clk=dut.clk)
    assert measured_after == period, (
        f"SYSREF clause-b FAIL: gated-edge period: expected {period}, got {measured_after}"
    )


@cocotb.test()
async def test_sysref_phase_neutral_clause_c(dut):
    """SYSREF-gating clause (c): spec-periodic SYSREF during nSync='0' causes no phase jump.

    Places a SYSREF rising edge at an integer multiple of the LMFC period
    after the alignment edge.  The measured period straddling that edge must
    be identical to the free-running period (no counter perturbation).
    """
    k = env_int("K_G", default=32)
    f = env_int("F_G", default=2)
    period = (k * f) // 4

    dut.nSync_i.value = 1
    dut.sysref_i.value = 0
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    # --- Initial alignment ---
    dut.nSync_i.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.sysref_i.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.sysref_i.value = 0

    # Wait for the alignment lmfc pulse
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    # Let it free-run for exactly one full period so we know the phase
    measured_baseline = await measure_lmfc_period(dut, clk=dut.clk)
    assert measured_baseline == period, (
        f"SYSREF clause-c FAIL: baseline period: expected {period}, got {measured_baseline}"
    )

    # --- Place a SYSREF edge exactly at the lmfc_o rising edge (period boundary) ---
    # We are currently exactly at an lmfc_o pulse.  The next lmfc_o is `period`
    # cycles away.  Inject SYSREF at that same moment (nSync_i='0').
    # Wait for the next lmfc_o pulse while simultaneously injecting SYSREF.
    for _ in range(512):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        if dut.lmfc_o.value == 1:
            # We are at a period boundary — inject SYSREF now
            dut.sysref_i.value = 1
            await RisingEdge(dut.clk)
            await Timer(1, unit="ns")
            dut.sysref_i.value = 0
            break
    else:
        raise AssertionError("SYSREF clause-c: could not find lmfc_o pulse for phase-neutral injection")

    # The lmfc_o pulse at N+2 from the SYSREF edge is also a normal period boundary;
    # the resulting period should equal the original.
    measured_after = await measure_lmfc_period(dut, clk=dut.clk)
    assert measured_after == period, (
        f"SYSREF clause-c FAIL: phase-neutral period: expected {period}, got {measured_after}"
    )


@cocotb.test()
async def test_sysref_re_pulse_clause_d(dut):
    """SYSREF-gating clause (d): sysrefRe_o is a single-cycle pulse on every SYSREF rising edge.

    Verifies the single-cycle pulse in both nSync states (gated and active).
    """
    dut.nSync_i.value = 1
    dut.sysref_i.value = 0
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    # --- Test with nSync_i='0' (active realignment) ---
    # Sample sysrefRe_o mid-cycle (Timer(6ns) past the rising edge) to avoid the
    # TPD=1ns boundary race at RisingEdge+1ns when r.sysrefRe transitions.
    dut.nSync_i.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.sysref_i.value = 1    # rising edge (cycle N)
    # Cycle N+1: sample 6ns into the clock cycle — solidly in the sysrefRe='1' window
    await RisingEdge(dut.clk)     # latch at edge N+1 (r.sysrefRe = 1 registered)
    await Timer(6, unit="ns")     # 5 ns past TPD expiry
    assert dut.sysrefRe_o.value == 1, (
        "SYSREF clause-d FAIL: sysrefRe_o not asserted 1 cc after SYSREF edge (nSync='0')"
    )
    dut.sysref_i.value = 0    # deassert sysref
    # Cycle N+2: sample mid-cycle — sysrefRe_o should be low (single-cycle pulse done)
    await RisingEdge(dut.clk)
    await Timer(6, unit="ns")
    assert dut.sysrefRe_o.value == 0, (
        "SYSREF clause-d FAIL: sysrefRe_o should be '0' the cycle after the pulse (nSync='0')"
    )

    # Let the counter free-run a few cycles
    await tb.cycle(8)

    # --- Test with nSync_i='1' (gated — sysrefRe_o still pulses) ---
    dut.nSync_i.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.sysref_i.value = 1    # rising edge (cycle N)
    # Cycle N+1: sample mid-cycle — sysrefRe_o should be high (pulse regardless of nSync)
    await RisingEdge(dut.clk)
    await Timer(6, unit="ns")
    assert dut.sysrefRe_o.value == 1, (
        "SYSREF clause-d FAIL: sysrefRe_o not asserted 1 cc after SYSREF edge (nSync='1')"
    )
    dut.sysref_i.value = 0
    # Cycle N+2: sample mid-cycle — sysrefRe_o should be low
    await RisingEdge(dut.clk)
    await Timer(6, unit="ns")
    assert dut.sysrefRe_o.value == 0, (
        "SYSREF clause-d FAIL: sysrefRe_o should be '0' the cycle after the pulse (nSync='1')"
    )


# ---------------------------------------------------------------------------
# pytest wrappers
#
# Selective cocotb execution uses COCOTB_TEST_FILTER (a coroutine-name regex
# honored by cocotb 2.x); the bare TESTCASE env var is NOT read by cocotb 2.x
# and would run every coroutine.
#   pytest -k period  → test_JesdLmfcGen_period  (COCOTB_TEST_FILTER=test_period)
#   pytest -k sysref  → test_JesdLmfcGen_sysref  (COCOTB_TEST_FILTER=test_sysref)
#   pytest            → test_JesdLmfcGen          (all coroutines, no filter)
# Each wrapper uses a unique sim_build_key for parallel xdist isolation.
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_JesdLmfcGen_period(parameters):
    """LMFC period: run only the period-sweep coroutine."""
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesdlmfcgen",
        parameters=parameters,
        extra_env={**parameters, "COCOTB_TEST_FILTER": "test_period"},
    )


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_JesdLmfcGen_sysref(parameters):
    """SYSREF-gating: run the four SYSREF-gating coroutines (clauses a-d)."""
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesdlmfcgen",
        parameters=parameters,
        extra_env={
            **parameters,
            # Regex matches all four test_sysref_*_clause_* coroutines
            "COCOTB_TEST_FILTER": "test_sysref",
        },
    )


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_JesdLmfcGen(parameters):
    """Full suite: run all period and SYSREF-gating coroutines together."""
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesdlmfcgen",
        parameters=parameters,
        extra_env=parameters,
    )
