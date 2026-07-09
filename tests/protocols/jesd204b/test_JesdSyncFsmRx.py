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
# - DUT: JesdSyncFsmRx (flat ports, no wrapper needed).
# - Sweep: Full TI F/K union x NUM_ILAS_MF_G {4, 8} x SUBCLASS {0, 1}.
#   F_G and K_G have no effect on the FSM itself but are swept for completeness.
# - Stimulus: Python LMFC at (K*F)/4 period; dataRx_i/chariskRx_i driven from
#   build_rx_link_timeline() CGS segment; segment-sequenced on nSync_o.
# - Checks: 4-stable K28.5 threshold, nSync_o assertion/
#   deassertion, all CGS exit conditions; ILA_S multiframe count with
#   r.cnt (one clock later than TX v.cnt, registered); DATA_S->IDLE on
#   stable-K (implementation-latitude behavior).
# - Timing: TPD_G=1 ns settle; JesdTB.cycle() for single-clock advance.
#   RX ILA exit: r.cnt -- assert dataValid_o ONE CLOCK AFTER Nth LMFC (registered).
#   nSyncAnyD1_i='0' required for SC1 IDLE exit.
#
# GHDL toplevel: surf.jesdsyncfsmrx
#   Verified by: grep -ri "entity JesdSyncFsmRx" protocols/jesd204b/rtl/
#   Result: protocols/jesd204b/rtl/JesdSyncFsmRx.vhd:entity JesdSyncFsmRx is

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    env_int,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)
from tests.protocols.jesd204b.jesd204b_test_utils import (
    JesdTB,
    K_CHAR,
    inject_stable_k,
)


# ---------------------------------------------------------------------------
# Parameter sweep: full TI F/K union x NUM_ILAS_MF_G {4,8} x SUBCLASS {0,1}
# SUBCLASS is a Python-only env key (stripped by hdl_parameters_from).
# ---------------------------------------------------------------------------
PARAMETER_SWEEP = [
    parameter_case("k32_f2_mf4_sc1", K_G="32", F_G="2", NUM_ILAS_MF_G="4", SUBCLASS="1"),
    parameter_case("k32_f2_mf4_sc0", K_G="32", F_G="2", NUM_ILAS_MF_G="4", SUBCLASS="0"),
    parameter_case("k32_f2_mf8_sc1", K_G="32", F_G="2", NUM_ILAS_MF_G="8", SUBCLASS="1"),
    parameter_case("k32_f2_mf8_sc0", K_G="32", F_G="2", NUM_ILAS_MF_G="8", SUBCLASS="0"),
    # Full TI F/K union:
    parameter_case("k32_f1_mf4_sc1", K_G="32", F_G="1", NUM_ILAS_MF_G="4", SUBCLASS="1"),
    parameter_case("k16_f2_mf4_sc1", K_G="16", F_G="2", NUM_ILAS_MF_G="4", SUBCLASS="1"),
    parameter_case("k32_f4_mf4_sc1", K_G="32", F_G="4", NUM_ILAS_MF_G="4", SUBCLASS="1"),
]


# ---------------------------------------------------------------------------
# Bounded-wait helper (analog: test_JesdSyncFsmTx.py lines 52-61)
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
# LMFC pulse driver (analog: test_JesdSyncFsmTx.py lines 68-71)
# ---------------------------------------------------------------------------

async def drive_lmfc_pulse(dut, tb):
    """Drive one-cycle lmfc_i=1, then deassert."""
    dut.lmfc_i.value = 1
    await tb.cycle()
    dut.lmfc_i.value = 0


# ---------------------------------------------------------------------------
# RX FSM startup helper: IDLE->SYSREF->SYNC->HOLD->ALIGN->ILA
# ---------------------------------------------------------------------------

async def startup_rx(dut, tb, *, subclass):
    """Drive RX FSM from IDLE to ILA_S entry for Subclass 0 or 1.

    Entry conditions (JesdSyncFsmRx.vhd:188-197):
      SC1 IDLE->SYSREF: sysRef_i='1' AND enable_i='1' AND nSyncAnyD1_i='0'
                        AND gtReady_i='1' AND s_kStable='1'
      SC0 IDLE->SYSREF: enable_i='1' AND gtReady_i='1' AND s_kStable='1'
      s_kStable: 4 consecutive all-K28.5 GT words (JesdSyncFsmRx.vhd:154-156)
      SYSREF->SYNC: s_kDetected='1' AND lmfc_i='1' (line 211)
      SYNC->HOLD:   s_kDetected='0' (first non-K word, line 229)
      HOLD->ALIGN:  lmfc_i='1' (line 249)
      ALIGN->ILA:   unconditional 1-cycle state (line 271)

    nSyncAnyD1_i MUST be '0' for SC1 IDLE exit.
    HOLD_S must receive an LMFC pulse before ILA_S entry.

    Returns when aligned in ILA_S (ila_o=1 confirmed).
    """
    k_word = (K_CHAR << 24) | (K_CHAR << 16) | (K_CHAR << 8) | K_CHAR

    dut.enable_i.value = 1
    dut.gtReady_i.value = 1
    dut.subClass_i.value = subclass
    dut.nSyncAnyD1_i.value = 0   # required for SC1 IDLE exit
    dut.nSyncAny_i.value = 1     # '1' = at least one lane requesting sync (active-low)
    dut.linkErr_i.value = 0

    # Drive K28.5 fill to build s_kStable (4 consecutive all-K words required)
    dut.dataRx_i.value = k_word
    dut.chariskRx_i.value = 0xF

    if subclass == 1:
        # SC1: SYSREF pulse gates the IDLE exit
        dut.sysRef_i.value = 1
        # Hold K28.5 for 4+ cycles to achieve s_kStable while SYSREF is high
        await tb.cycle(5)
        dut.sysRef_i.value = 0
    else:
        # SC0: just need enable + gtReady + s_kStable; hold K28.5 for s_kStable
        await tb.cycle(5)

    # At this point FSM should be in SYSREF_S.
    # SYSREF->SYNC: s_kDetected='1' AND lmfc_i='1' (line 211)
    # K28.5 is still being driven so s_kDetected='1'; fire an LMFC pulse.
    await drive_lmfc_pulse(dut, tb)
    # Allow FSM to register into SYNC_S
    await tb.cycle()

    # Wait for nSync_o to assert (SYNC_S: v.nSync='1', registered as r.nSync)
    await wait_for_signal(dut.nSync_o, value=1, clk=dut.clk, timeout_cycles=8)

    # SYNC->HOLD: drive first non-K word (s_kDetected='0', line 229)
    dut.dataRx_i.value = 0x00000000
    dut.chariskRx_i.value = 0x0
    await tb.cycle()
    await tb.cycle()  # settle into HOLD_S

    # HOLD->ALIGN: fire an LMFC pulse (line 249)
    await drive_lmfc_pulse(dut, tb)

    # ALIGN_S is unconditional 1-cycle -> ILA_S; wait for ila_o to assert
    await wait_for_signal(dut.ila_o, value=1, clk=dut.clk, timeout_cycles=8)


# ---------------------------------------------------------------------------
# Test 1: K-detection threshold
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_cgs02_k_detection_threshold(dut):
    """Exactly 4 consecutive K28.5 GT words -> s_kStable -> nSync_o deasserts.

    Spec: JESD204B §7.1 -- four successive /K/ required before de-asserting SYNC~.
    RTL:  JesdSyncFsmRx.vhd:154-156 -- 4-sample AND on kDetectReg pipeline.
    Exact threshold is RTL contract; bench pins it (implementation-latitude).

    Positive case: exactly 4 all-K GT-words asserted with charisk=0xF -> s_kStable
    asserts -> FSM exits IDLE_S.
    Negative case: 3 all-K GT-words then a non-K word -> s_kStable does NOT assert
    -> FSM stays in IDLE_S.
    """
    subclass = env_int("SUBCLASS", default=1)

    # --- Setup ---
    dut.enable_i.setimmediatevalue(0)
    dut.gtReady_i.setimmediatevalue(0)
    dut.subClass_i.setimmediatevalue(subclass)
    dut.sysRef_i.setimmediatevalue(0)
    dut.dataRx_i.setimmediatevalue(0)
    dut.chariskRx_i.setimmediatevalue(0)
    dut.lmfc_i.setimmediatevalue(0)
    dut.nSyncAny_i.setimmediatevalue(1)
    dut.nSyncAnyD1_i.setimmediatevalue(0)
    dut.linkErr_i.setimmediatevalue(0)
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    k_word = (K_CHAR << 24) | (K_CHAR << 16) | (K_CHAR << 8) | K_CHAR

    # --- Positive case: 4 consecutive K28.5 words + SYSREF (SC1) / just 4 K (SC0) ---
    # Enable and set gtReady so IDLE exit conditions can be met
    dut.enable_i.value = 1
    dut.gtReady_i.value = 1
    dut.dataRx_i.value = k_word
    dut.chariskRx_i.value = 0xF

    if subclass == 1:
        # SC1 also needs sysRef_i='1' at transition moment
        dut.sysRef_i.value = 1

    # Drive 4 cycles of all-K to achieve s_kStable (4-sample AND)
    await tb.cycle(4)

    if subclass == 1:
        dut.sysRef_i.value = 0

    # FSM should now be in SYSREF_S (IDLE exit fired with s_kStable='1')
    # Fire LMFC with K still asserted to advance SYSREF->SYNC
    await drive_lmfc_pulse(dut, tb)
    await tb.cycle()

    # nSync_o should assert (SYNC_S output v.nSync='1')
    await wait_for_signal(dut.nSync_o, value=1, clk=dut.clk, timeout_cycles=8)
    assert int(dut.nSync_o.value) == 1, (
        f"positive: nSync_o did not assert after 4 K-words "
        f"(SC{subclass}); got {dut.nSync_o.value}"
    )

    # --- Reset and run the negative case: 3 K-words then a non-K ---
    await tb.reset()

    dut.enable_i.value = 1
    dut.gtReady_i.value = 1
    dut.dataRx_i.value = k_word
    dut.chariskRx_i.value = 0xF

    if subclass == 1:
        dut.sysRef_i.value = 1

    # Drive only 3 K-words
    await tb.cycle(3)

    # Then break the sequence with a non-K word (s_kStable cannot assert)
    dut.dataRx_i.value = 0x00000000
    dut.chariskRx_i.value = 0x0
    await tb.cycle()

    if subclass == 1:
        dut.sysRef_i.value = 0

    # Fire an LMFC -- FSM should NOT have exited IDLE_S (s_kStable never asserted)
    await drive_lmfc_pulse(dut, tb)
    await tb.cycle(2)

    assert int(dut.nSync_o.value) == 0, (
        f"negative: nSync_o asserted after only 3 K-words + break "
        f"(SC{subclass}); 3-then-break must NOT deassert SYNC~; "
        f"got {dut.nSync_o.value}"
    )


# ---------------------------------------------------------------------------
# Test 2: CGS/IDLE exit conditions (enable/gtReady/nSyncAnyD1_i permutations)
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_cgs02_exit_conditions(dut):
    """CGS/IDLE exit permutations from the FSM state table.

    Spec: JESD204B §7.1 -- receiver asserts SYNC~ after detecting four successive /K/.
    RTL:  JesdSyncFsmRx.vhd:188-197 -- IDLE exit conditions.
    Implementation-latitude on threshold; bench covers what RTL exposes.

    Asserts:
    - enable_i='0' keeps FSM in IDLE_S (no SYSREF_S entry) for both subclasses.
    - gtReady_i='0' keeps FSM in IDLE_S even with s_kStable and enable_i='1'.
    - SC1 only: nSyncAnyD1_i='1' blocks IDLE exit.
    """
    subclass = env_int("SUBCLASS", default=1)

    tb = JesdTB(dut)
    k_word = (K_CHAR << 24) | (K_CHAR << 16) | (K_CHAR << 8) | K_CHAR

    # Helper: reset and set K28.5 fill baseline
    async def _reset_and_set_k():
        dut.enable_i.setimmediatevalue(0)
        dut.gtReady_i.setimmediatevalue(0)
        dut.subClass_i.setimmediatevalue(subclass)
        dut.sysRef_i.setimmediatevalue(0)
        dut.dataRx_i.setimmediatevalue(k_word)
        dut.chariskRx_i.setimmediatevalue(0xF)
        dut.lmfc_i.setimmediatevalue(0)
        dut.nSyncAny_i.setimmediatevalue(1)
        dut.nSyncAnyD1_i.setimmediatevalue(0)
        dut.linkErr_i.setimmediatevalue(0)
        dut.rst.setimmediatevalue(1)
        await tb.reset()

    # --- Case A: enable_i='0' keeps FSM in IDLE_S ---
    await _reset_and_set_k()
    dut.gtReady_i.value = 1
    # enable_i stays 0
    if subclass == 1:
        dut.sysRef_i.value = 1
    await tb.cycle(6)  # 4+ K-words with s_kStable, plus SYSREF if SC1
    if subclass == 1:
        dut.sysRef_i.value = 0
    await drive_lmfc_pulse(dut, tb)
    await tb.cycle(2)

    # nSync_o must stay 0 (FSM must not have entered SYSREF_S -> SYNC_S)
    assert int(dut.nSync_o.value) == 0, (
        f"exit cond A: nSync_o asserted with enable_i='0' "
        f"(SC{subclass}); FSM must stay in IDLE_S; got {dut.nSync_o.value}"
    )

    # --- Case B: gtReady_i='0' keeps FSM in IDLE_S ---
    await _reset_and_set_k()
    dut.enable_i.value = 1
    # gtReady_i stays 0
    if subclass == 1:
        dut.sysRef_i.value = 1
    await tb.cycle(6)
    if subclass == 1:
        dut.sysRef_i.value = 0
    await drive_lmfc_pulse(dut, tb)
    await tb.cycle(2)

    assert int(dut.nSync_o.value) == 0, (
        f"exit cond B: nSync_o asserted with gtReady_i='0' "
        f"(SC{subclass}); FSM must stay in IDLE_S; got {dut.nSync_o.value}"
    )

    # --- Case C (SC1 only): nSyncAnyD1_i='1' blocks IDLE exit ---
    if subclass == 1:
        await _reset_and_set_k()
        dut.enable_i.value = 1
        dut.gtReady_i.value = 1
        dut.nSyncAnyD1_i.value = 1   # blocks SC1 IDLE exit (line 190)
        dut.sysRef_i.value = 1
        await tb.cycle(6)
        dut.sysRef_i.value = 0
        await drive_lmfc_pulse(dut, tb)
        await tb.cycle(2)

        assert int(dut.nSync_o.value) == 0, (
            "exit cond C (SC1): nSync_o asserted with nSyncAnyD1_i='1'; "
            "SC1 IDLE exit requires nSyncAnyD1_i='0'; "
            f"got {dut.nSync_o.value}"
        )


# ---------------------------------------------------------------------------
# Test 3: ILAS multiframe counting and DATA_S transition timing
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_ilas03_multiframe_count(dut):
    """ILA_S multiframe counting and DATA_S entry timing.

    Spec: JESD204B §5.3.3.5 / §8.2 -- receiver counts NUM_ILAS_MF_G LMFC pulses
          in ILA sequence before declaring data valid.
    RTL:  JesdSyncFsmRx ILA_S state -- r.cnt (registered) exits at NUM_ILAS_MF_G.
    RX uses r.cnt (registered, exits ONE CLOCK AFTER Nth LMFC pulse);
    TX uses v.cnt (combinatorial, exits ON Nth LMFC pulse).
    Assert dataValid_o ONE CLOCK AFTER the Nth LMFC, not on the Nth.

    Asserts:
    - N-1 LMFC pulses keep ila_o=1 and dataValid_o=0 (off-by-one guard).
    - After Nth LMFC AND one additional clock, dataValid_o=1 / ila_o=0 (r.cnt timing).
    """
    num_mf = env_int("NUM_ILAS_MF_G", default=4)
    subclass = env_int("SUBCLASS", default=1)

    dut.enable_i.setimmediatevalue(0)
    dut.gtReady_i.setimmediatevalue(0)
    dut.subClass_i.setimmediatevalue(subclass)
    dut.sysRef_i.setimmediatevalue(0)
    dut.dataRx_i.setimmediatevalue(0)
    dut.chariskRx_i.setimmediatevalue(0)
    dut.lmfc_i.setimmediatevalue(0)
    dut.nSyncAny_i.setimmediatevalue(1)
    dut.nSyncAnyD1_i.setimmediatevalue(0)
    dut.linkErr_i.setimmediatevalue(0)
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    # Walk the FSM to ILA_S
    await startup_rx(dut, tb, subclass=subclass)

    assert int(dut.ila_o.value) == 1, (
        f"ila_o not asserted at ILA_S entry (SC{subclass}, N={num_mf}); "
        f"got {dut.ila_o.value}"
    )
    assert int(dut.dataValid_o.value) == 0, (
        f"dataValid_o asserted too early at ILA_S entry (SC{subclass}); "
        f"got {dut.dataValid_o.value}"
    )

    # N-1 LMFC pulses -- must stay in ILA_S after each
    for idx in range(num_mf - 1):
        await drive_lmfc_pulse(dut, tb)
        await tb.cycle()   # settle after lmfc deassert

        assert int(dut.ila_o.value) == 1, (
            f"ila_o not 1 after {idx + 1}/{num_mf - 1} pulses "
            f"(SC{subclass}, N={num_mf}); got {dut.ila_o.value}"
        )
        assert int(dut.dataValid_o.value) == 0, (
            f"dataValid_o asserted prematurely after {idx + 1}/{num_mf - 1} pulses "
            f"(SC{subclass}); got {dut.dataValid_o.value}"
        )

    # Nth LMFC pulse -- r.cnt becomes NUM_ILAS_MF_G on the NEXT clock edge (registered)
    await drive_lmfc_pulse(dut, tb)

    # On the Nth LMFC, v.cnt = NUM_ILAS_MF_G is combinatorial, but v.state is
    # DATA_S only as rin; the registered r.state transitions ONE CLOCK LATER.
    # Advance one additional clock before asserting dataValid_o (registered, line 291).
    await tb.cycle()   # extra clock for r.cnt -> DATA_S registration

    await wait_for_signal(dut.dataValid_o, value=1, clk=dut.clk, timeout_cycles=4)

    assert int(dut.dataValid_o.value) == 1, (
        f"dataValid_o not 1 one clock after Nth LMFC "
        f"(SC{subclass}, N={num_mf}); r.cnt timing -- NOT v.cnt (registered, line 291); "
        f"got {dut.dataValid_o.value}"
    )
    assert int(dut.ila_o.value) == 0, (
        f"ila_o still 1 in DATA_S (SC{subclass}, N={num_mf}); "
        f"got {dut.ila_o.value}"
    )


# ---------------------------------------------------------------------------
# Test 4: stable-K resync (implementation-latitude behavior)
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_err03_stable_k_resync(dut):
    """4 consecutive genuine K28.5 GT-words in DATA_S -> FSM returns to IDLE_S.

    Spec: JESD204B §7.6.3 -- re-initialization conditions are implementer-configurable.
    RTL:  JesdSyncFsmRx DATA_S state -- s_kStable='1' exits to IDLE_S.
    Implementation-latitude behavior: the trigger requires genuine K28.5
    GT-words with charisk=0xF (charisk-gated).
    detKcharFunc() is charisk-gated -- payload-value aliasing cannot trigger.

    Positive case: inject 4 genuine K28.5 words (data=0xBCBCBCBC, charisk=0xF)
                   in DATA_S -> FSM returns to IDLE_S (nSync_o deasserts).
    Negative case: inject 0xBC data with charisk=0 (non-K flagged) -> FSM stays
                   in DATA_S (charisk-gated, E1 -- payload aliasing cannot trigger).
    """
    num_mf = env_int("NUM_ILAS_MF_G", default=4)
    subclass = env_int("SUBCLASS", default=1)

    dut.enable_i.setimmediatevalue(0)
    dut.gtReady_i.setimmediatevalue(0)
    dut.subClass_i.setimmediatevalue(subclass)
    dut.sysRef_i.setimmediatevalue(0)
    dut.dataRx_i.setimmediatevalue(0)
    dut.chariskRx_i.setimmediatevalue(0)
    dut.lmfc_i.setimmediatevalue(0)
    dut.nSyncAny_i.setimmediatevalue(1)
    dut.nSyncAnyD1_i.setimmediatevalue(0)
    dut.linkErr_i.setimmediatevalue(0)
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    # Walk FSM to DATA_S (reuse startup_rx then drive ILAS counting)
    await startup_rx(dut, tb, subclass=subclass)

    # Drive NUM_ILAS_MF_G LMFC pulses to exit ILA_S -> DATA_S
    for _ in range(num_mf):
        await drive_lmfc_pulse(dut, tb)
    # One extra clock for r.cnt timing (registered, line 291)
    await tb.cycle()
    await wait_for_signal(dut.dataValid_o, value=1, clk=dut.clk, timeout_cycles=4)

    assert int(dut.dataValid_o.value) == 1, (
        f"setup: did not reach DATA_S (SC{subclass}, N={num_mf})"
    )

    # --- Negative case first: 0xBC payload with charisk=0 -- must NOT trigger ---
    k_word = (K_CHAR << 24) | (K_CHAR << 16) | (K_CHAR << 8) | K_CHAR
    dut.dataRx_i.value = k_word
    dut.chariskRx_i.value = 0x0   # charisk=0: detKcharFunc() does not detect K-chars
    await tb.cycle(6)              # 4+ cycles of 0xBC data without K flags

    assert int(dut.dataValid_o.value) == 1, (
        "negative: FSM left DATA_S on 0xBC payload with charisk=0 "
        "(charisk-gated -- payload aliasing must NOT trigger stable-K); "
        f"got dataValid_o={dut.dataValid_o.value}"
    )

    # Reset to clean DATA_S state before positive injection
    dut.dataRx_i.value = 0x00000000
    dut.chariskRx_i.value = 0x0
    await tb.cycle(2)

    assert int(dut.dataValid_o.value) == 1, (
        "lost DATA_S after driving plain data (unexpected resync)"
    )

    # --- Positive case: 4 genuine K28.5 words with charisk=0xF -> IDLE_S ---
    # Use inject_stable_k to build the 4-word sequence
    plain_data = [(0x00000000, 0x0)] * 8
    stable_k_seq = inject_stable_k(plain_data, start_idx=0, count=4)

    for data_word, datak in stable_k_seq[:4]:
        dut.dataRx_i.value = data_word
        dut.chariskRx_i.value = datak
        await tb.cycle()

    # After 4 genuine K28.5 words, s_kStable='1' -> v.state=IDLE_S (line 308)
    # Allow 1-2 cycles for registered transition
    await wait_for_signal(dut.dataValid_o, value=0, clk=dut.clk, timeout_cycles=8)

    assert int(dut.dataValid_o.value) == 0, (
        "positive: dataValid_o still asserted after 4 genuine K28.5 words "
        "in DATA_S (expected IDLE_S reversion); "
        f"got {dut.dataValid_o.value}"
    )
    assert int(dut.nSync_o.value) == 0, (
        "positive: nSync_o still asserted after IDLE_S reversion "
        "(expected IDLE_S: v.nSync='0'); "
        f"got {dut.nSync_o.value}"
    )


# ---------------------------------------------------------------------------
# pytest wrapper (analog: test_JesdSyncFsmTx.py lines 337-345)
# Flat-port DUT: no extra_vhdl_sources needed.
# GHDL toplevel: surf.jesdsyncfsmrx (entity JesdSyncFsmRx, VHDL-2008 lowercase)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_JesdSyncFsmRx(parameters):
    """K-detection / multiframe-count / stable-K: all coroutines for full K/F/MF/subclass sweep."""
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesdsyncfsmrx",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
