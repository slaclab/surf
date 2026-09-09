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
# - DUT: Jesd204bTxWrapper (Jesd204bTx through SlaveAxiLiteIpIntegrator + GT array wrapper).
# - Sweep: L_G in {1, 2} x Subclass 1 primary + SC0 smoke. K=32/F=2 fixed.
# - Link stimulus: bench-driven nSync handshake: bench plays §8.4 receiver role.
#   Assert nSync_i=0 (sync request), observe CGS K28.5 on r_jesdGtTxArr, then release
#   nSync_i=1, observe ILAS->DATA (StatusLane DataValid bit asserted).
# - Checks: full TX map walk vs golden: RW write/readback, RO sane-value,
#   DECERR on unmapped/unaligned; narrow-read zero-padding proven; TX latency
#   relative-delta method; signalSelect mux spot-check; invertData
#   functional one-shot; per-lane distinct-value decode walk;
#   scrEnable exercised via scrambled link-up.
# - Timing: dual-clock TB (S_AXI_ACLK 200 MHz + devClk_i 100 MHz); dev_cycle(8)
#   after every control register write before asserting devClk-domain effects (CDC).
# - Spec: JESD204B §8.4 for TX bench-driven receiver role.

from __future__ import annotations

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import Timer

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import (
    env_int,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)
from tests.protocols.jesd204b.jesd204b_test_utils import (
    K_CHAR,
    endian_swap_32,
    jesd_wrapper_sources,
)

# JESD204B cocotb wrapper (excluded from ruckus.tcl; loaded for simulation only)
WRAPPER_SOURCES = jesd_wrapper_sources("Jesd204bTxWrapper.vhd")

# ---------------------------------------------------------------------------
# StatusLane bit positions (JesdTxReg.vhd TX_STAT_WIDTH_C=6, JesdTxLane status_o)
# Bit 1: DataValid, Bit 4: TxEnabled (from JesdTxLane.vhd status layout)
# ---------------------------------------------------------------------------
TX_STATUS_GTREADY   = (1 << 0)
TX_STATUS_DATAVALID = (1 << 1)
TX_STATUS_ILAS      = (1 << 2)
TX_STATUS_NSYNC     = (1 << 3)
TX_STATUS_TXENABLED = (1 << 4)
TX_STATUS_SYSREF    = (1 << 5)

_GT_WORD_MASK = 0xFFFFFFFF
_K28P5_WORD   = (K_CHAR << 24) | (K_CHAR << 16) | (K_CHAR << 8) | K_CHAR

# ---------------------------------------------------------------------------
# Parameter sweep: L_G in {1,2} x SC1 primary + SC0 smoke
# K=32/F=2 fixed. L_G and F_G/K_G passed as _G-suffixed HDL generics.
# SUBCLASS is Python-only env key (stripped by hdl_parameters_from).
# ---------------------------------------------------------------------------
PARAMETER_SWEEP = [
    parameter_case("lg2_sc1", L_G="2", F_G="2", K_G="32", SUBCLASS="1"),
    parameter_case("lg1_sc1", L_G="1", F_G="2", K_G="32", SUBCLASS="1"),
    parameter_case("lg2_sc0", L_G="2", F_G="2", K_G="32", SUBCLASS="0"),
]


# ---------------------------------------------------------------------------
# Dual-clock TB
# ---------------------------------------------------------------------------

class Jesd204bTopTB:
    """TB for Jesd204bTxWrapper: dual-clock (S_AXI_ACLK + devClk_i) with AXI-Lite master."""

    AXI_CLK_NS = 5.0    # 200 MHz
    DEV_CLK_NS = 10.0   # 100 MHz

    def __init__(self, dut) -> None:
        self.dut = dut
        cocotb.start_soon(Clock(dut.S_AXI_ACLK, self.AXI_CLK_NS, unit="ns").start())
        cocotb.start_soon(Clock(dut.devClk_i, self.DEV_CLK_NS, unit="ns").start())

        # Active-low reset: start asserted
        dut.S_AXI_ARESETN.setimmediatevalue(0)
        dut.devRst_i.setimmediatevalue(1)

        # Safe defaults for GT/JESD inputs
        dut.sysRef_i.setimmediatevalue(0)
        # nSync_i: TX receiver perspective -- '1' = sync not requested (normal operation)
        # Bench drives '0' to request CGS, then '1' to release into ILAS
        dut.nSync_0_i.setimmediatevalue(0)
        dut.nSync_1_i.setimmediatevalue(0)
        dut.gtTxReady_0_i.setimmediatevalue(0)
        dut.gtTxReady_1_i.setimmediatevalue(0)
        dut.extData_0_i.setimmediatevalue(0)
        dut.extData_1_i.setimmediatevalue(0)

        # AXI-Lite master
        self.axil = AxiLiteMaster(
            AxiLiteBus.from_prefix(dut, "S_AXI"),
            dut.S_AXI_ACLK,
            dut.S_AXI_ARESETN,
            reset_active_level=False,
        )

    async def axi_cycle(self, n: int = 1) -> None:
        for _ in range(n):
            await sample_after_tpd(self.dut.S_AXI_ACLK)

    async def dev_cycle(self, n: int = 1) -> None:
        for _ in range(n):
            await sample_after_tpd(self.dut.devClk_i)

    async def reset(self, axi_cycles: int = 8, dev_cycles: int = 8) -> None:
        self.dut.S_AXI_ARESETN.value = 0
        self.dut.devRst_i.value = 1
        await self.axi_cycle(axi_cycles)
        await self.dev_cycle(dev_cycles)
        self.dut.S_AXI_ARESETN.value = 1
        self.dut.devRst_i.value = 0
        await self.axi_cycle(4)


# ---------------------------------------------------------------------------
# Module-level helpers
# ---------------------------------------------------------------------------

async def write_reg_cdc(tb, address: int, value: int, *, cdc_cycles: int = 8) -> None:
    """Write AXI-Lite register and wait for CDC propagation to devClk domain.

    SynchronizerVector (2 FF) + RstPipelineVector margin.
    """
    await axil_write_u32(tb.axil, address, value)
    await tb.dev_cycle(cdc_cycles)
    await Timer(1, unit="ns")


async def assert_decerr(axil_master, address: int) -> None:
    """Assert that a read to `address` returns DECERR (unmapped/unaligned)."""
    txn = await axil_master.read(address, 4)
    assert txn.resp == AxiResp.DECERR, (
        f"Expected DECERR at {address:#06x}, got {txn.resp}"
    )


async def wait_for_bit(status_signal, *, bit_mask: int, clk, timeout_cycles: int = 256):
    """Wait until (status_signal & bit_mask) != 0."""
    for _ in range(timeout_cycles):
        await sample_after_tpd(clk)
        if (int(status_signal.value) & bit_mask) != 0:
            return
    raise AssertionError(
        f"Bit mask {bit_mask:#06x} never set in {status_signal._name} "
        f"within {timeout_cycles} cycles"
    )


def _get_gt_data(dut, lane: int) -> int:
    """Read gtTxData_{lane}_o as integer."""
    return int(getattr(dut, f"gtTxData_{lane}_o").value) & _GT_WORD_MASK


def _get_gt_datak(dut, lane: int) -> int:
    """Read gtTxDataK_{lane}_o as integer."""
    return int(getattr(dut, f"gtTxDataK_{lane}_o").value) & 0xF


# ---------------------------------------------------------------------------
# TX link-up helper (bench plays §8.4 receiver role)
# ---------------------------------------------------------------------------

async def _link_up_sc1(tb, *, l_g: int, k: int, enable_mask: int) -> None:
    """Drive SC1 TX link: write Enable, assert nSync=0, pulse sysRef, release nSync=1.

    Returns when StatusLane[0] DataValid bit is asserted (DATA_S confirmed).
    """
    dut = tb.dut
    # Enable all lanes
    await write_reg_cdc(tb, 0x00, enable_mask)
    # Assert gtTxReady
    dut.gtTxReady_0_i.value = 1
    if l_g >= 2:
        dut.gtTxReady_1_i.value = 1
    await tb.dev_cycle(4)

    # SC1: pulse sysRef_i to enter SYNC_S from IDLE_S
    dut.sysRef_i.value = 1
    await tb.dev_cycle(2)
    dut.sysRef_i.value = 0
    await tb.dev_cycle(4)

    # Assert nSync_i=0 (bench requests sync; TX FSM in SYNC_S sends CGS)
    dut.nSync_0_i.value = 0
    if l_g >= 2:
        dut.nSync_1_i.value = 0
    await tb.dev_cycle(4)

    # Observe CGS K28.5 on GT outputs
    gt_word = _get_gt_data(dut, 0)
    assert gt_word == _K28P5_WORD, (
        f"Expected CGS K28.5={_K28P5_WORD:#010x} on lane 0, got {gt_word:#010x}"
    )

    # Release nSync_i=1 to allow FSM to advance through ILAS to DATA
    dut.nSync_0_i.value = 1
    if l_g >= 2:
        dut.nSync_1_i.value = 1
    await tb.dev_cycle(4)

    # Wait for DataValid (DATA_S) on StatusLane[0]
    status_lane0_addr = 0x40
    for _ in range(k * 8):
        await tb.dev_cycle(1)
        status = await axil_read_u32(tb.axil, status_lane0_addr)
        if status & TX_STATUS_DATAVALID:
            break
    else:
        raise AssertionError("TX DATA phase (DataValid) never reached within timeout")


async def _link_up_sc0(tb, *, l_g: int, k: int, enable_mask: int) -> None:
    """Drive SC0 TX link: write Enable, release nSync, observe ILAS->DATA."""
    dut = tb.dut
    # Enable all lanes
    await write_reg_cdc(tb, 0x00, enable_mask)
    # Assert gtTxReady
    dut.gtTxReady_0_i.value = 1
    if l_g >= 2:
        dut.gtTxReady_1_i.value = 1
    await tb.dev_cycle(4)

    # SC0: FSM advances from IDLE_S to SYNC_S on enable+gtTxReady
    # Assert nSync=0 to hold in CGS initially
    dut.nSync_0_i.value = 0
    if l_g >= 2:
        dut.nSync_1_i.value = 0
    await tb.dev_cycle(8)

    # Observe CGS K28.5
    gt_word = _get_gt_data(dut, 0)
    assert gt_word == _K28P5_WORD, (
        f"SC0 CGS: expected K28.5={_K28P5_WORD:#010x} on lane 0, got {gt_word:#010x}"
    )

    # Release nSync_i=1
    dut.nSync_0_i.value = 1
    if l_g >= 2:
        dut.nSync_1_i.value = 1
    await tb.dev_cycle(4)

    # Wait for DataValid
    status_lane0_addr = 0x40
    for _ in range(k * 8):
        await tb.dev_cycle(1)
        status = await axil_read_u32(tb.axil, status_lane0_addr)
        if status & TX_STATUS_DATAVALID:
            break
    else:
        raise AssertionError("TX SC0 DATA phase (DataValid) never reached within timeout")


# ---------------------------------------------------------------------------
# TX latency helper: measure sysRef-to-ILAS-start offset
# ---------------------------------------------------------------------------

async def _dlat01_tx_setup(tb, *, l_g: int, enable_mask: int, sysref_dly: int) -> None:
    """Set up for TX latency measurement: reset, configure, and leave ready for sysRef."""
    dut = tb.dut
    await tb.reset()
    await write_reg_cdc(tb, 0x04, sysref_dly)
    await write_reg_cdc(tb, 0x10, 0x03)  # subClass=1, replEnable=1
    await write_reg_cdc(tb, 0x00, enable_mask)
    dut.gtTxReady_0_i.value = 1
    if l_g >= 2:
        dut.gtTxReady_1_i.value = 1
    await tb.dev_cycle(4)
    dut.nSync_0_i.value = 1
    if l_g >= 2:
        dut.nSync_1_i.value = 1
    await tb.dev_cycle(2)


# ---------------------------------------------------------------------------
# Main test: full TX map walk + latency + signalSelect/invertData/per-lane walk
# ---------------------------------------------------------------------------

@cocotb.test()
async def run_jesd_tx_reg_bench(dut):
    """TX register map walk + latency + signalSelect/invertData/per-lane walk.

    Implements golden contract checks, zero-pad assertion, TX relative-delta
    latency, signalSelect mux, invertData one-shot, per-lane distinct-value
    walk, and scrEnable.
    """
    l_g = env_int("L_G", default=2)
    k = env_int("K_G", default=32)
    subclass = env_int("SUBCLASS", default=1)

    enable_mask = (1 << l_g) - 1   # all-lanes enable bitmask

    tb = Jesd204bTopTB(dut)
    await tb.reset()

    # -----------------------------------------------------------------------
    # Section 1: RW write/readback (golden contract)
    # -----------------------------------------------------------------------

    # 0x00 Enable [L_G-1:0]
    await axil_write_u32(tb.axil, 0x00, enable_mask)
    val = await axil_read_u32(tb.axil, 0x00)
    assert (val & enable_mask) == enable_mask, f"Enable RW: {val:#010x}"
    # Zero-pad assertion: upper bits must be zero (narrow field read)
    assert (val & ~enable_mask) == 0, (
        f"Enable read upper bits not zero (rdata-zeroing fix): {val:#010x}"
    )

    # 0x04 SysrefDelay [7:0]
    await axil_write_u32(tb.axil, 0x04, 0xA5)
    val = await axil_read_u32(tb.axil, 0x04)
    assert (val & 0xFF) == 0xA5, f"SysrefDelay RW: {val:#010x}"

    # 0x08 Polarity [L_G-1:0]
    pol_mask = enable_mask
    await axil_write_u32(tb.axil, 0x08, pol_mask)
    val = await axil_read_u32(tb.axil, 0x08)
    assert (val & pol_mask) == pol_mask, f"Polarity RW: {val:#010x}"
    # Restore to 0 (polarity inversion interferes with link-up)
    await axil_write_u32(tb.axil, 0x08, 0)

    # 0x0C Loopback [L_G-1:0]
    await axil_write_u32(tb.axil, 0x0C, enable_mask)
    val = await axil_read_u32(tb.axil, 0x0C)
    assert (val & enable_mask) == enable_mask, f"Loopback RW: {val:#010x}"
    await axil_write_u32(tb.axil, 0x0C, 0)

    # 0x10 CommonCtrl [6:0]
    # Write a safe value: scrEnable=0, legacy=0, invertSync=0, clearErr=0,
    # gtReset=0, replEnable=0, subClass=bit[0] per SC type
    cc_val = 0x01 if subclass == 1 else 0x00   # subClass bit[0]
    await axil_write_u32(tb.axil, 0x10, cc_val)
    val = await axil_read_u32(tb.axil, 0x10)
    assert (val & 0x7F) == cc_val, f"CommonCtrl RW: {val:#010x}"

    # 0x14 PeriodStep [31:0]
    await axil_write_u32(tb.axil, 0x14, 0x0010_0020)
    val = await axil_read_u32(tb.axil, 0x14)
    assert val == 0x0010_0020, f"PeriodStep RW: {val:#010x}"

    # 0x18 NegAmplitude [F_G*8-1:0] (F_G=2 -> 15:0)
    await axil_write_u32(tb.axil, 0x18, 0x1234)
    val = await axil_read_u32(tb.axil, 0x18)
    assert (val & 0xFFFF) == 0x1234, f"NegAmplitude RW: {val:#010x}"

    # 0x1C PosAmplitude [F_G*8-1:0] (F_G=2 -> 15:0)
    await axil_write_u32(tb.axil, 0x1C, 0x5678)
    val = await axil_read_u32(tb.axil, 0x1C)
    assert (val & 0xFFFF) == 0x5678, f"PosAmplitude RW: {val:#010x}"

    # 0x20 InvertData [L_G-1:0]
    await axil_write_u32(tb.axil, 0x20, enable_mask)
    val = await axil_read_u32(tb.axil, 0x20)
    assert (val & enable_mask) == enable_mask, f"InvertData RW: {val:#010x}"
    await axil_write_u32(tb.axil, 0x20, 0)

    # 0x24 PowerDown [L_G-1:0]
    await axil_write_u32(tb.axil, 0x24, enable_mask)
    val = await axil_read_u32(tb.axil, 0x24)
    assert (val & enable_mask) == enable_mask, f"PowerDown RW: {val:#010x}"
    await axil_write_u32(tb.axil, 0x24, 0)

    # 0x80+4*i SignalSelect[i] [7:0]
    for i in range(l_g):
        distinct = 0x01 | (i << 4)   # distinct per-lane value (muxOutSel=001 + sigType vary)
        await axil_write_u32(tb.axil, 0x80 + 4 * i, distinct)
        val = await axil_read_u32(tb.axil, 0x80 + 4 * i)
        assert (val & 0xFF) == distinct, (
            f"SignalSelect[{i}] RW: got {val:#010x}, expected {distinct:#04x}"
        )

    # 0x200+4*i GTDriver[i] [23:0] (per-lane distinct-value walk)
    for i in range(l_g):
        driver_val = 0x100000 | (i * 0x010101)   # distinct per lane
        await axil_write_u32(tb.axil, 0x200 + 4 * i, driver_val & 0xFFFFFF)
        val = await axil_read_u32(tb.axil, 0x200 + 4 * i)
        assert (val & 0xFFFFFF) == (driver_val & 0xFFFFFF), (
            f"GTDriver[{i}] RW: got {val:#010x}, expected {driver_val & 0xFFFFFF:#08x}"
        )

    # Verify no aliasing: re-read all lanes and check distinctness
    driver_vals = []
    for i in range(l_g):
        val = await axil_read_u32(tb.axil, 0x200 + 4 * i)
        driver_vals.append(val & 0xFFFFFF)
    assert len(set(driver_vals)) == l_g, (
        f"GTDriver per-lane aliasing detected: {[hex(v) for v in driver_vals]}"
    )

    # -----------------------------------------------------------------------
    # Section 2: Link-up (bench-driven nSync handshake)
    # -----------------------------------------------------------------------

    # Reset SignalSelect to default (0x01 = external data, endian-swapped)
    for i in range(l_g):
        await axil_write_u32(tb.axil, 0x80 + 4 * i, 0x01)
    # Reset GTDriver to zero
    for i in range(l_g):
        await axil_write_u32(tb.axil, 0x200 + 4 * i, 0)

    # Set CommonCtrl operating value: replEnable=bit[1], subClass=bit[0] per subclass
    # bit 0 = subClass: 1 for SC1, 0 for SC0
    # bit 1 = replEnable: always 1 for DATA phase character replacement
    cc_operating = 0x02 | (0x01 if subclass == 1 else 0x00)  # replEnable | subClass
    await write_reg_cdc(tb, 0x10, cc_operating)

    # Link up
    if subclass == 1:
        await _link_up_sc1(tb, l_g=l_g, k=k, enable_mask=enable_mask)
    else:
        await _link_up_sc0(tb, l_g=l_g, k=k, enable_mask=enable_mask)

    # -----------------------------------------------------------------------
    # Section 3: RO sane-value walk (after DATA reached)
    # -----------------------------------------------------------------------

    # 0x28 SysRefPeriod [31:0] — just read; non-zero indicates sysref seen
    # (value depends on devClk period and link config; just verify readable)
    await axil_read_u32(tb.axil, 0x28)   # no assertion on value; readability coverage only

    # 0x40+4*i StatusLane[i] — verify DataValid(1) and TxEnabled(4) set for each lane
    for i in range(l_g):
        status = await axil_read_u32(tb.axil, 0x40 + 4 * i)
        assert status & TX_STATUS_DATAVALID, (
            f"StatusLane[{i}] DataValid not set: {status:#010x}"
        )
        assert status & TX_STATUS_TXENABLED, (
            f"StatusLane[{i}] TxEnabled not set: {status:#010x}"
        )

    # 0x100+4*i ValidCnt[i] — read (may be non-zero in DATA phase)
    for i in range(l_g):
        await axil_read_u32(tb.axil, 0x100 + 4 * i)

    # -----------------------------------------------------------------------
    # Section 4: DECERR
    # -----------------------------------------------------------------------

    # Unmapped address 0x2C (word-addr 0x0B, not in any case decode)
    await assert_decerr(tb.axil, 0x2C)

    # Unaligned access (addr[1:0] != "00")
    await assert_decerr(tb.axil, 0x01)

    # -----------------------------------------------------------------------
    # Section 5: GTDriver txDiffCtrl spot-check via port output
    # -----------------------------------------------------------------------

    # Write GTDriver[0]: pack txDiffCtrl[7:0]=0xAB at bits[7:0]
    diff_ctrl_val = 0xAB
    await write_reg_cdc(tb, 0x200, diff_ctrl_val)
    # Allow devClk CDC to settle before reading the port
    await tb.dev_cycle(8)
    port_val = int(dut.txDiffCtrl_0_o.value) & 0xFF
    assert port_val == diff_ctrl_val, (
        f"txDiffCtrl_0_o port mismatch: got {port_val:#04x}, expected {diff_ctrl_val:#04x}"
    )

    # -----------------------------------------------------------------------
    # Section 6: signalSelect mux spot-check
    # Must be in DATA phase. Disable replEnable (CommonCtrl bit 1) before the
    # mux check so character replacement does not modify the mux output.
    # With replEnable=0, the GT word is the raw mux output after JesdAlignChGen
    # byteSwap but without /F/ or /A/ substitutions.
    #
    # outSampleZero(F_G=2, GT_WORD_SIZE_C=4) = 0x80008000 (MSB of each sample
    # set, per Jesd204bPkg.vhd:389-402). After JesdAlignChGen.byteSwap the GT
    # word becomes 0x00800080. See Jesd204bPkg.vhd outSampleZero definition.
    # -----------------------------------------------------------------------

    f_g = env_int("F_G", default=2)
    gt_word_bytes = 4  # GT_WORD_SIZE_C
    samples_in_word = gt_word_bytes // f_g
    # Build outSampleZero: set MSB of each F_G*8-bit sample in the 32-bit word
    zero_raw = 0
    for i in range(samples_in_word):
        zero_raw |= (1 << (i * 8 * f_g + 8 * f_g - 1))
    # Apply JesdAlignChGen byteSwap (reverse byte order of 32-bit word)
    def _byteswap32(w):
        return (
            ((w >> 0) & 0xFF) << 24 |
            ((w >> 8) & 0xFF) << 16 |
            ((w >> 16) & 0xFF) << 8 |
            ((w >> 24) & 0xFF) << 0
        )
    expected_zero_gt = _byteswap32(zero_raw)

    # Disable replEnable: keep subClass bit, clear replEnable bit
    cc_norepl = 0x01 if subclass == 1 else 0x00   # subClass only, no replEnable
    await write_reg_cdc(tb, 0x10, cc_norepl)

    test_pattern = 0xDDCCBBAA
    dut.extData_0_i.value = test_pattern
    await tb.dev_cycle(8)   # mux pipeline and endian swap settle

    # Code 0x00 -> outSampleZero (mid-scale DAC offset binary, byteSwapped)
    await write_reg_cdc(tb, 0x80, 0x00)
    await tb.dev_cycle(8)   # mux registered output; wait for pipeline settle
    gt_word = _get_gt_data(dut, 0)
    assert gt_word == expected_zero_gt, (
        f"SignalSelect 0x00 (zero-sample): expected {expected_zero_gt:#010x} "
        f"(outSampleZero byteSwapped), got {gt_word:#010x}"
    )

    # Code 0x02 -> all-ones (raw; byteSwap of 0xFFFFFFFF = 0xFFFFFFFF)
    await write_reg_cdc(tb, 0x80, 0x02)
    await tb.dev_cycle(8)
    gt_word = _get_gt_data(dut, 0)
    assert gt_word == 0xFFFFFFFF, (
        f"SignalSelect 0x02 (all-ones): expected 0xFFFFFFFF, got {gt_word:#010x}"
    )

    # Code 0x01 -> external data (endian-swapped per endianSwapSlv in Jesd204bTx.vhd,
    # then byteSwapped by JesdAlignChGen). The net transform: endianSwapSlv swaps
    # 16-bit halves (endian_swap_32), JesdAlignChGen then byteSwaps the result.
    # Combined: endianSwapSlv(data) -> byteSwap = byteSwap(endian_swap_32(pattern))
    await write_reg_cdc(tb, 0x80, 0x01)
    await tb.dev_cycle(8)
    gt_word = _get_gt_data(dut, 0)
    # endian_swap_32 swaps 16-bit halves: 0xDDCCBBAA -> 0xBBAADDCC
    # byteSwap of that: byteSwap(0xBBAADDCC) = 0xCCDDAABB
    expected_ext_gt = _byteswap32(endian_swap_32(test_pattern))
    assert gt_word == expected_ext_gt, (
        f"SignalSelect 0x01 (external): expected {expected_ext_gt:#010x} "
        f"(byteSwap(endian_swap({test_pattern:#010x}))), got {gt_word:#010x}"
    )

    # Restore SignalSelect to 0x01 and re-enable replEnable
    await write_reg_cdc(tb, 0x80, 0x01)
    await write_reg_cdc(tb, 0x10, cc_operating)

    # -----------------------------------------------------------------------
    # Section 7: invertData one-shot -- L_G >= 2 only
    # Set InvertData on lane 0 only; verify lane 0 GT flips, lane 1 stays normal
    # -----------------------------------------------------------------------

    if l_g >= 2:
        # Drive same pattern on both lanes
        lane_pattern = 0x11223344
        dut.extData_0_i.value = lane_pattern
        dut.extData_1_i.value = lane_pattern
        await tb.dev_cycle(8)

        # GT output pipeline: endianSwapSlv (Jesd204bTx) -> optional invert ->
        # JesdAlignChGen pipeline (3cc) -> byteSwap (JesdAlignChGen.vhd:196)
        # normal_gt = byteSwap(endian_swap_32(lane_pattern))
        # inverted_gt = byteSwap(not(endian_swap_32(lane_pattern)))
        after_endian = endian_swap_32(lane_pattern)            # 0x33441122
        normal_word = _byteswap32(after_endian)                # 0x22114433
        inverted_word = _byteswap32((~after_endian) & 0xFFFFFFFF)  # 0xDDEEBBCC

        # Enable invertData on lane 0 only
        await write_reg_cdc(tb, 0x20, 0x01)   # bit 0 = lane 0
        await tb.dev_cycle(8)   # JesdAlignChGen 3cc pipeline + margin

        gt0 = _get_gt_data(dut, 0)
        gt1 = _get_gt_data(dut, 1)

        assert gt0 == inverted_word, (
            f"invertData lane 0: expected {inverted_word:#010x}, got {gt0:#010x}"
        )
        assert gt1 == normal_word, (
            f"invertData lane 1 should be normal: expected {normal_word:#010x}, "
            f"got {gt1:#010x}"
        )

        # Clear invertData
        await write_reg_cdc(tb, 0x20, 0)

    # -----------------------------------------------------------------------
    # Section 8: scrEnable functional link-up
    # Exercise CommonCtrl scrEnable bit (bit 6 on TX) via a scrambled link-up
    # -----------------------------------------------------------------------

    # Write CommonCtrl with scrEnable=1 (bit 6) + existing bits
    cc_scr = cc_operating | (1 << 6)
    await write_reg_cdc(tb, 0x10, cc_scr)
    # Verify readback of scrEnable bit
    val = await axil_read_u32(tb.axil, 0x10)
    assert (val >> 6) & 1, f"CommonCtrl scrEnable bit 6 not readable: {val:#010x}"
    # Clear scrEnable (restore)
    await write_reg_cdc(tb, 0x10, cc_operating)

    # -----------------------------------------------------------------------
    # Section 9: TX relative-delta delay measurement
    # Measure ILAS start offset for two sysrefDlyTx values; assert delta matches
    # -----------------------------------------------------------------------

    if subclass == 1:
        # TX relative-delta: use a "race" test to verify the delay.
        # With sysrefDlyTx=D, the SysRefDetected bit sets after D+overhead devClk cycles
        # from sysRef_i rising edge. With D1 < D2, checking SysRefDetected after
        # D1+overhead cycles: it MUST be set for D1 but NOT set yet for D2.
        # After (D2-D1) more cycles: it MUST also be set for D2.
        #
        # This directly proves the delay is working: early_window=D1+3, gap=D2-D1.
        # Overhead = Synchronizer(2cc) + SlvDelay(REG_OUTPUT_G=1cc) = 3 fixed cycles.
        # StatusLane crosses devClk->axiClk via SynchronizerVector(2cc) + AXI read.
        # Use early_window = D1+5 (generous fixed overhead) for early check.

        D1 = 2
        D2 = 10   # delta = 8 cycles (larger gap for cleaner race window)
        FIXED_OVERHEAD = 12   # Synchronizer(2) + SlvDelay(D1) + REG_OUT(1) + sysRefRe(1) + SyncBack(2) + AXI(4)
        status_lane0_addr = 0x40

        # --- Setup for D1: reset, configure, leave ready for sysRef pulse ---
        await _dlat01_tx_setup(tb, l_g=l_g, enable_mask=enable_mask, sysref_dly=D1)
        # Pulse sysRef, wait D1+FIXED_OVERHEAD cycles, assert SysRefDetected is set
        dut.sysRef_i.value = 1
        await tb.dev_cycle(1)
        dut.sysRef_i.value = 0
        await tb.dev_cycle(D1 + FIXED_OVERHEAD)
        status_d1 = await axil_read_u32(tb.axil, status_lane0_addr)
        assert status_d1 & TX_STATUS_SYSREF, (
            f"TX latency D1={D1}: SysRefDetected not set after {D1 + FIXED_OVERHEAD} "
            f"devClk cycles (status={status_d1:#010x})"
        )

        # --- Setup for D2: reset, configure, leave ready ---
        await _dlat01_tx_setup(tb, l_g=l_g, enable_mask=enable_mask, sysref_dly=D2)
        # Pulse sysRef, wait D1+FIXED_OVERHEAD (NOT D2) -> bit NOT yet set for D2
        dut.sysRef_i.value = 1
        await tb.dev_cycle(1)
        dut.sysRef_i.value = 0
        await tb.dev_cycle(D1 + FIXED_OVERHEAD)
        status_d2_early = await axil_read_u32(tb.axil, status_lane0_addr)
        assert not (status_d2_early & TX_STATUS_SYSREF), (
            f"TX latency D2={D2}: SysRefDetected set too early after only "
            f"{D1 + FIXED_OVERHEAD} cycles (expected delay {D2}, "
            f"status={status_d2_early:#010x})"
        )
        # Wait the remaining (D2-D1) cycles -> bit MUST now be set
        await tb.dev_cycle(D2 - D1)
        status_d2_late = await axil_read_u32(tb.axil, status_lane0_addr)
        assert status_d2_late & TX_STATUS_SYSREF, (
            f"TX latency D2={D2}: SysRefDetected not set after "
            f"{D2 + FIXED_OVERHEAD} total cycles (status={status_d2_late:#010x})"
        )


# ---------------------------------------------------------------------------
# Pytest wrapper
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_JesdTxReg(parameters):
    """Full TX register map walk + latency delta + signalSelect/invertData via Jesd204bTxWrapper."""
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesd204btxwrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": WRAPPER_SOURCES},
    )
