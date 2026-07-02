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
# - Sweep: F-agnostic; NUM_ILAS_MF_G in {4, 8}; both subclasses.
# - Stimulus: Drive nSync_i, sysRef_i, lmfc_i, gtTxReady_i, subClass_i, enable_i
#             per JesdSyncFsmTx port map (JesdSyncFsmTx.vhd:26-63).
# - Checks: code-group-sync: dataValid_o / ila_o / sysref_o transitions; ILA exit
#           exactly at NUM_ILAS_MF_G LMFC pulses after ILA_S entry (E3).
# - Timing: TPD_G=1 ns settle (JesdSyncFsmTx.vhd:209); outputs registered
#           from r (not v). Use bounded waits (wait_for_signal) for output
#           assertions to handle the 1-cycle registered pipeline exactly.
#           lmfc_i is always 0 during wait_for_signal calls so the ILA
#           counter does not advance.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    env_int,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)
from tests.protocols.jesd204b.jesd204b_test_utils import JesdTB


# ---------------------------------------------------------------------------
# Parameter sweep: NUM_ILAS_MF_G in {4, 8} x SUBCLASS in {0, 1}
# SUBCLASS is a Python-only env key; NUM_ILAS_MF_G is the HDL generic.
# ---------------------------------------------------------------------------
PARAMETER_SWEEP = [
    parameter_case("mf4_sc1", NUM_ILAS_MF_G="4", SUBCLASS="1"),
    parameter_case("mf4_sc0", NUM_ILAS_MF_G="4", SUBCLASS="0"),
    parameter_case("mf8_sc1", NUM_ILAS_MF_G="8", SUBCLASS="1"),
    parameter_case("mf8_sc0", NUM_ILAS_MF_G="8", SUBCLASS="0"),
]


# ---------------------------------------------------------------------------
# Bounded-wait helper
# ---------------------------------------------------------------------------

async def wait_for_signal(signal, *, value, clk, timeout_cycles=32):
    """Wait up to timeout_cycles for signal to reach value (1ns settle after each edge)."""
    for _ in range(timeout_cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if signal.value == value:
            return
    raise AssertionError(
        f"Signal {signal._name} did not reach {value} within {timeout_cycles} cycles"
    )


# ---------------------------------------------------------------------------
# LMFC pulse driver: one-cycle-wide pulse, lmfc_i returns to 0 after the call
# ---------------------------------------------------------------------------

async def drive_lmfc_pulse(dut, tb):
    """Drive one-cycle lmfc_i=1, then deassert."""
    dut.lmfc_i.value = 1
    await tb.cycle()
    dut.lmfc_i.value = 0


# ---------------------------------------------------------------------------
# FSM startup helpers
# ---------------------------------------------------------------------------

async def startup_sc1(dut, tb):
    """Drive IDLE->SYNC->ILA for Subclass 1.

    Returns when ila_o=1 is confirmed. The ILA counter is 0 on return.

    JesdSyncFsmTx.vhd:120-143: SC1 needs sysRef_i=1 to exit IDLE_S.
    sysref_o asserts 1 cc after IDLE->SYNC transition (registered output).
    SYNC->ILA requires nSync_i=1 AND lmfc_i=1 (line 139).
    """
    dut.enable_i.value = 1
    dut.gtTxReady_i.value = 1
    dut.subClass_i.value = 1

    # SYSREF pulse: exits IDLE_S -> SYNC_S
    dut.sysRef_i.value = 1
    await tb.cycle()
    dut.sysRef_i.value = 0

    # Wait for sysref_o to assert (registered output, 1-2 cycles latency)
    await wait_for_signal(dut.sysref_o, value=1, clk=dut.clk, timeout_cycles=4)

    # nSync=1 + LMFC pulse -> SYNC_S->ILA_S
    dut.nSync_i.value = 1
    await drive_lmfc_pulse(dut, tb)

    # Wait for ila_o to assert (registered output, 1-2 cycles)
    await wait_for_signal(dut.ila_o, value=1, clk=dut.clk, timeout_cycles=4)


async def startup_sc0(dut, tb):
    """Drive IDLE->SYNC->ILA for Subclass 0.

    Returns when ila_o=1 is confirmed. The ILA counter is 0 on return.

    JesdSyncFsmTx.vhd:125-127: SC0 exits IDLE_S on enable+gtTxReady alone.
    """
    dut.enable_i.value = 1
    dut.gtTxReady_i.value = 1
    dut.subClass_i.value = 0

    # SC0: allow 1 cycle for IDLE->SYNC_S transition to latch
    await tb.cycle()

    # nSync=1 + LMFC pulse -> SYNC_S->ILA_S
    dut.nSync_i.value = 1
    await drive_lmfc_pulse(dut, tb)

    # Wait for ila_o to assert (registered output, 1-2 cycles)
    await wait_for_signal(dut.ila_o, value=1, clk=dut.clk, timeout_cycles=4)


# ---------------------------------------------------------------------------
# Test 1 (SC1): Subclass-1 startup and E3 exit
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_cgs01_subclass1(dut):
    """Code-group-sync (SC1): IDLE->SYNC->ILA->DATA for Subclass 1 with SYSREF gate.

    Checks:
    - SYSREF pulse exits IDLE_S; sysref_o asserts (registered output).
    - nSync_i=1 + LMFC -> ILA_S; ila_o asserts.
    - Exactly NUM_ILAS_MF_G LMFC pulses -> DATA_S (E3).
    - NUM_ILAS_MF_G-1 pulses leaves FSM in ILA_S (off-by-one guard).

    Timing note (JesdSyncFsmTx.vhd:192-194): outputs are registered (r.*)
    so they appear 1 clock after the combinatorial state change. All output
    checks use wait_for_signal or are done after bounded settling.
    """
    num_mf = env_int("NUM_ILAS_MF_G", default=4)
    subclass = env_int("SUBCLASS", default=1)

    if subclass != 1:
        return

    dut.enable_i.setimmediatevalue(0)
    dut.nSync_i.setimmediatevalue(0)
    dut.sysRef_i.setimmediatevalue(0)
    dut.lmfc_i.setimmediatevalue(0)
    dut.gtTxReady_i.setimmediatevalue(0)
    dut.subClass_i.setimmediatevalue(1)
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    await startup_sc1(dut, tb)

    # Confirm ILA_S
    assert int(dut.ila_o.value) == 1, (
        f"SC1: ila_o not asserted in ILA_S (got {dut.ila_o.value})"
    )
    assert int(dut.dataValid_o.value) == 0, (
        f"SC1: dataValid_o asserted too early (got {dut.dataValid_o.value})"
    )

    # E3 off-by-one guard: N-1 pulses must keep FSM in ILA_S
    for _ in range(num_mf - 1):
        await drive_lmfc_pulse(dut, tb)
        await tb.cycle()  # settle after lmfc deassert

    assert int(dut.ila_o.value) == 1, (
        f"SC1: ila_o not 1 after {num_mf-1} pulses (off-by-one guard); "
        f"got {dut.ila_o.value}"
    )
    assert int(dut.dataValid_o.value) == 0, (
        f"SC1: dataValid_o asserted prematurely after {num_mf-1} pulses; "
        f"got {dut.dataValid_o.value}"
    )

    # Nth pulse -> DATA_S
    await drive_lmfc_pulse(dut, tb)
    await wait_for_signal(dut.dataValid_o, value=1, clk=dut.clk, timeout_cycles=4)

    assert int(dut.dataValid_o.value) == 1, (
        f"SC1: dataValid_o not 1 after exactly {num_mf} pulses (DATA_S); "
        f"got {dut.dataValid_o.value}"
    )
    assert int(dut.ila_o.value) == 0, (
        f"SC1: ila_o still 1 in DATA_S; got {dut.ila_o.value}"
    )


# ---------------------------------------------------------------------------
# Test 2 (SC0): Subclass-0 startup and E3 exit
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_cgs01_subclass0(dut):
    """Code-group-sync (SC0): IDLE->SYNC->ILA->DATA for Subclass 0 (no SYSREF).

    Checks:
    - enable_i=1 + gtTxReady_i=1 exits IDLE_S.
    - nSync_i=1 + LMFC -> ILA_S; ila_o asserts.
    - Exactly NUM_ILAS_MF_G LMFC pulses -> DATA_S.
    - NUM_ILAS_MF_G-1 pulses leaves FSM in ILA_S (off-by-one guard).
    """
    num_mf = env_int("NUM_ILAS_MF_G", default=4)
    subclass = env_int("SUBCLASS", default=1)

    if subclass != 0:
        return

    dut.enable_i.setimmediatevalue(0)
    dut.nSync_i.setimmediatevalue(0)
    dut.sysRef_i.setimmediatevalue(0)
    dut.lmfc_i.setimmediatevalue(0)
    dut.gtTxReady_i.setimmediatevalue(0)
    dut.subClass_i.setimmediatevalue(0)
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    await startup_sc0(dut, tb)

    assert int(dut.ila_o.value) == 1, (
        f"SC0: ila_o not asserted in ILA_S (got {dut.ila_o.value})"
    )
    assert int(dut.dataValid_o.value) == 0, (
        f"SC0: dataValid_o asserted too early (got {dut.dataValid_o.value})"
    )

    # E3 off-by-one guard: N-1 pulses must keep FSM in ILA_S
    for _ in range(num_mf - 1):
        await drive_lmfc_pulse(dut, tb)
        await tb.cycle()  # settle after lmfc deassert

    assert int(dut.ila_o.value) == 1, (
        f"SC0: ila_o not 1 after {num_mf-1} pulses (off-by-one guard); "
        f"got {dut.ila_o.value}"
    )
    assert int(dut.dataValid_o.value) == 0, (
        f"SC0: dataValid_o asserted prematurely after {num_mf-1} pulses; "
        f"got {dut.dataValid_o.value}"
    )

    # Nth pulse -> DATA_S
    await drive_lmfc_pulse(dut, tb)
    await wait_for_signal(dut.dataValid_o, value=1, clk=dut.clk, timeout_cycles=4)

    assert int(dut.dataValid_o.value) == 1, (
        f"SC0: dataValid_o not 1 after exactly {num_mf} pulses (DATA_S); "
        f"got {dut.dataValid_o.value}"
    )
    assert int(dut.ila_o.value) == 0, (
        f"SC0: ila_o still 1 in DATA_S; got {dut.ila_o.value}"
    )


# ---------------------------------------------------------------------------
# Test 3: E3 exactly-N combined (runs for any subclass in sweep)
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_ilas_e3_exactly_n(dut):
    """E3: ILA_S exits after exactly NUM_ILAS_MF_G LMFC pulses (both subclasses).

    Asserts:
    - N-1 LMFC pulses in ILA_S keep ila_o=1 and dataValid_o=0 after each.
    - The Nth LMFC pulse transitions to DATA_S (dataValid_o=1, ila_o=0).

    JesdSyncFsmTx.vhd:159: v.cnt = NUM_ILAS_MF_G (combinatorial, same cycle
    as the lmfc_i increment). Exact-N semantics.
    """
    num_mf = env_int("NUM_ILAS_MF_G", default=4)
    subclass = env_int("SUBCLASS", default=1)

    dut.enable_i.setimmediatevalue(0)
    dut.nSync_i.setimmediatevalue(0)
    dut.sysRef_i.setimmediatevalue(0)
    dut.lmfc_i.setimmediatevalue(0)
    dut.gtTxReady_i.setimmediatevalue(0)
    dut.subClass_i.setimmediatevalue(subclass)
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    if subclass == 1:
        await startup_sc1(dut, tb)
    else:
        await startup_sc0(dut, tb)

    assert int(dut.ila_o.value) == 1, (
        f"E3: ila_o not 1 at ILA_S entry (SC{subclass}, N={num_mf})"
    )

    # Drive N-1 pulses; assert ILA_S persists after each
    for idx in range(num_mf - 1):
        await drive_lmfc_pulse(dut, tb)
        await tb.cycle()  # settle after lmfc deassert
        assert int(dut.ila_o.value) == 1, (
            f"E3: ila_o not 1 after {idx+1}/{num_mf-1} pulses "
            f"(SC{subclass}, N={num_mf}); got {dut.ila_o.value}"
        )
        assert int(dut.dataValid_o.value) == 0, (
            f"E3: dataValid_o asserted prematurely after {idx+1}/{num_mf-1} pulses "
            f"(SC{subclass}); got {dut.dataValid_o.value}"
        )

    # Nth pulse -> DATA_S
    await drive_lmfc_pulse(dut, tb)
    await wait_for_signal(dut.dataValid_o, value=1, clk=dut.clk, timeout_cycles=4)

    assert int(dut.dataValid_o.value) == 1, (
        f"E3: dataValid_o not 1 after exactly {num_mf} pulses "
        f"(SC{subclass}); got {dut.dataValid_o.value}"
    )
    assert int(dut.ila_o.value) == 0, (
        f"E3: ila_o still 1 in DATA_S (SC{subclass}); got {dut.ila_o.value}"
    )


# ---------------------------------------------------------------------------
# pytest wrapper
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_JesdSyncFsmTx(parameters):
    """Code-group-sync: all coroutines for NUM_ILAS_MF_G x SUBCLASS sweep."""
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesdsyncfsmtx",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
