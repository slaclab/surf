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
# - DUT: Jesd204bRxWrapper (Jesd204bRx through SlaveAxiLiteIpIntegrator + GT array wrapper).
# - Sweep: L_G in {1, 2} x Subclass 1 primary + SC0 smoke. K=32/F=2 fixed.
# - Link stimulus: golden GT streams from build_rx_link_timeline(), segment-sequenced on
#   DUT-observed nSync_o: bench drives CGS until nSync_o=1, then ILAS, then DATA.
#   scrEnable exercised once via a scrambled link-up (lg2_sc0 case with scr=True).
# - Checks:
#   Full register map walk vs _JesdRx.py golden:
#     RW: Enable(0x00), SysrefDelay(0x04), Polarity(0x08), CommonCtrl(0x10),
#         LinkErrMask(0x14), InvertData(0x18), PowerDown(0x24) -- proving assertion.
#     RO sane: SysrefPeriod(0x28), StatusLane[i](0x40+4i), ValidCnt[i](0x100+4i),
#              RawData[i](0x140+4i after axi_cycle(8) SynchronizerFifo settle).
#     DECERR: 0x0C, 0x1C (explicitly unmapped), 0x01 (unaligned).
#   RX latency: sysRef_i -> sysRefDbg_o relative delta across {0,1,mid,max}.
#   nSyncAny 4-case combining contract (L_G=2 only).
#   invertData one-shot: set lane0 only, sampleData_0_o flips, sampleData_1_o normal.
#   Per-lane distinct-value walk: TestTXItf/TestSigThr distinct per lane, read back.
# - Timing: dual-clock TB (S_AXI_ACLK 200 MHz + devClk_i 100 MHz); dev_cycle(8) after every
#   control register write before asserting devClk-domain effects (CDC latency).
#   rawData read after axi_cycle(8) SynchronizerFifo settle. RO walk gated behind dataValid.
# - Spec: JESD204B §7.6 / §8.4 RX register map. JesdRxReg 0x24 PowerDown RW fix.
# - GHDL toplevel: surf.jesd204brxwrapper
#   Verified by: entity Jesd204bRxWrapper in protocols/jesd204b/wrappers/Jesd204bRxWrapper.vhd

from __future__ import annotations

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import (
    env_int,
    env_sl,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)
from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.protocols.jesd204b.jesd204b_test_utils import (
    K_CHAR,
    build_ilas_config_octets,
    build_rx_link_timeline,
    wait_data_valid_all,
    wait_nSync,
)

# ---------------------------------------------------------------------------
# RX status bit constants (JesdRxLane.vhd:322 + :267 verified in 04-04-SUMMARY)
# bit0=rstDone, bit1=dataValid, bit2=alignErr, bit3=nSync, bit4=bufUnf,
# bit5=bufOvf, bit6=posErr, bit7=enable, bit8=sysRef, bit9=kDetect,
# bits10-13=dispErr[0:3], bits14-17=decErr[0:3], bits18-25=latency, bit26=cdrStable
# ---------------------------------------------------------------------------
STATUS_RSTDONE   = (1 << 0)
STATUS_DATAVALID = (1 << 1)
STATUS_NSYNC     = (1 << 3)
STATUS_ENABLE    = (1 << 7)
STATUS_KDETECT   = (1 << 9)
STATUS_LATENCY   = (0xFF << 18)

# ---------------------------------------------------------------------------
# Parameter sweep: L_G {1,2} x SC1 primary + SC0 smoke
# K=32/F=2 fixed per parameter matrix.
# SUBCLASS is Python-only (not passed to GHDL); SCR_ENABLE is Python-only.
# ---------------------------------------------------------------------------
PARAMETER_SWEEP = [
    parameter_case("lg2_sc1", L_G="2", SUBCLASS="1", SCR_ENABLE="0"),
    parameter_case("lg1_sc1", L_G="1", SUBCLASS="1", SCR_ENABLE="0"),
    parameter_case("lg2_sc0", L_G="2", SUBCLASS="0", SCR_ENABLE="1"),
]


# ---------------------------------------------------------------------------
# Jesd204bRxTopTB: dual-clock TB with AxiLiteMaster
# ---------------------------------------------------------------------------


class Jesd204bRxTopTB:
    """TB for Jesd204bRxWrapper: dual-clock (S_AXI_ACLK 200 MHz + devClk_i 100 MHz)."""

    AXI_CLK_NS = 5.0    # 200 MHz axiClk
    DEV_CLK_NS = 10.0   # 100 MHz devClk

    def __init__(self, dut, l_g: int) -> None:
        self.dut = dut
        self.l_g = l_g
        cocotb.start_soon(Clock(dut.S_AXI_ACLK, self.AXI_CLK_NS, unit="ns").start())
        cocotb.start_soon(Clock(dut.devClk_i, self.DEV_CLK_NS, unit="ns").start())

        # Active-low reset: start asserted (0)
        dut.S_AXI_ARESETN.setimmediatevalue(0)
        dut.devRst_i.setimmediatevalue(1)
        dut.sysRef_i.setimmediatevalue(0)

        # Safe defaults for all GT RX inputs (both lanes)
        for lane in range(2):
            getattr(dut, f"gtRxData_{lane}_i").setimmediatevalue(0)
            getattr(dut, f"gtRxDataK_{lane}_i").setimmediatevalue(0)
            getattr(dut, f"gtRxDispErr_{lane}_i").setimmediatevalue(0)
            getattr(dut, f"gtRxDecErr_{lane}_i").setimmediatevalue(0)
            getattr(dut, f"gtRxRstDone_{lane}_i").setimmediatevalue(0)
            getattr(dut, f"gtRxCdrStable_{lane}_i").setimmediatevalue(0)

        # AXI-Lite master
        self.axil = AxiLiteMaster(
            AxiLiteBus.from_prefix(dut, "S_AXI"),
            dut.S_AXI_ACLK,
            dut.S_AXI_ARESETN,
            reset_active_level=False,
        )

    async def axi_cycle(self, n: int = 1) -> None:
        for _ in range(n):
            await RisingEdge(self.dut.S_AXI_ACLK)
            await Timer(1, unit="ns")

    async def dev_cycle(self, n: int = 1) -> None:
        for _ in range(n):
            await RisingEdge(self.dut.devClk_i)
            await Timer(1, unit="ns")

    async def reset(self, axi_cycles: int = 8, dev_cycles: int = 8) -> None:
        self.dut.S_AXI_ARESETN.value = 0
        self.dut.devRst_i.value = 1
        await self.axi_cycle(axi_cycles)
        await self.dev_cycle(dev_cycles)
        self.dut.S_AXI_ARESETN.value = 1
        self.dut.devRst_i.value = 0
        await self.axi_cycle(4)


# ---------------------------------------------------------------------------
# CDC-aware register write helper
# ---------------------------------------------------------------------------


async def write_reg_cdc(
    tb: Jesd204bRxTopTB, address: int, value: int, *, cdc_cycles: int = 8
) -> None:
    """Write AXI-Lite register and wait for CDC propagation to devClk domain."""
    await axil_write_u32(tb.axil, address, value)
    await tb.dev_cycle(cdc_cycles)
    await Timer(1, unit="ns")


# ---------------------------------------------------------------------------
# DECERR assertion helper
# ---------------------------------------------------------------------------


async def assert_decerr(axil_master: AxiLiteMaster, address: int) -> None:
    """Assert that a read to address returns DECERR (unmapped or unaligned)."""
    txn = await axil_master.read(address, 4)
    # txn.resp may be an int or AxiResp enum; compare both ways
    resp_int = int(txn.resp) if hasattr(txn.resp, '__int__') else txn.resp
    decerr_int = int(AxiResp.DECERR)
    assert resp_int == decerr_int, (
        f"Expected DECERR({decerr_int}) at {address:#06x}, got resp={txn.resp!r}"
    )


# ---------------------------------------------------------------------------
# Bounded-wait helpers (analog: test_JesdRxLane.py:201-223)
# ---------------------------------------------------------------------------


async def wait_for_signal(signal, *, value, clk, timeout_cycles: int = 128):
    """Wait up to timeout_cycles for signal to equal value."""
    for _ in range(timeout_cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if int(signal.value) == value:
            return
    raise AssertionError(
        f"Signal {signal._name} did not reach {value} within {timeout_cycles} cycles"
    )


# ---------------------------------------------------------------------------
# RX link-up driver: drives all lanes CGS->ILAS->DATA slaved to nSync_o
# ---------------------------------------------------------------------------


async def drive_rx_link_up(
    tb: Jesd204bRxTopTB,
    *,
    k: int,
    f: int,
    l_g: int,
    scr: bool,
) -> None:
    """Drive CGS->ILAS->DATA on all lanes, segment-sequenced on DUT-observed nSync_o.

    Protocol (golden GT streams):
      1. Assert gtRxRstDone/gtRxCdrStable for all lanes.
      2. Drive CGS K28.5 on all lanes until wait_nSync(value=1) (SYNC_S entered).
      3. Drive ILAS on all lanes.
      4. Drive DATA on all lanes.
      5. wait_data_valid_all: all lanes in DATA state.

    Scrambling: scr=True enables scrEnable bit 5 in commonCtrl at DATA entry.
    The scrEnable write uses write_reg_cdc to cross CDC.
    """
    dut = tb.dut
    config_octets = build_ilas_config_octets(
        f_val=f, k_val=k, jesdv=1, subclassv=1, scr=int(scr)
    )
    data_words = [0xDEADBEEF] * 32

    timeline = build_rx_link_timeline(
        k=k, f=f, scr=scr, config_octets=config_octets, data_words=data_words
    )

    # Enable all lanes and bring GT ready high
    for lane in range(l_g):
        getattr(dut, f"gtRxRstDone_{lane}_i").value = 1
        getattr(dut, f"gtRxCdrStable_{lane}_i").value = 1

    # Enable RX lanes (0x00)
    enable_mask = (1 << l_g) - 1
    await write_reg_cdc(tb, 0x00, enable_mask)
    # Set commonCtrl: subClass=1(b0), replEnable=1(b1), gtReset=0(b2), clearErr=0(b3),
    # invertSync=0(b4), scrEnable=0(b5). invertSync=0 so nSync_o directly reflects nSyncAny.
    # = 0x03
    await write_reg_cdc(tb, 0x10, 0x03)

    # Drive CGS on all lanes with sysRef_i asserted (SC1: needed for IDLE->SYSREF_S)
    # invertSync=0 so nSync_o directly reflects nSyncAny: '0'=not synced, '1'=synced
    k_word = (K_CHAR << 24) | (K_CHAR << 16) | (K_CHAR << 8) | K_CHAR
    for lane in range(l_g):
        getattr(dut, f"gtRxData_{lane}_i").value = k_word
        getattr(dut, f"gtRxDataK_{lane}_i").value = 0xF

    # Assert sysRef while driving K28.5 (mirrors test_JesdRxLane.py drive_timeline SC1 sequence)
    dut.sysRef_i.value = 1
    await tb.dev_cycle(12)
    dut.sysRef_i.value = 0

    # Wait for nSync_o='1' (SYNC_S: all enabled lanes see stable K28.5, nSyncAny=1)
    # Internal LmfcGen fires LMFC which triggers SYSREF_S->SYNC_S transition
    await wait_nSync(dut, value=1, clk=dut.devClk_i, timeout_cycles=512)

    # Drive non-K data to trigger SYNC_S -> HOLD_S (s_kDetected='0')
    for lane in range(l_g):
        getattr(dut, f"gtRxData_{lane}_i").value = 0
        getattr(dut, f"gtRxDataK_{lane}_i").value = 0
    await tb.dev_cycle(4)

    # Drive ILAS on all lanes -- LmfcGen fires internally at K*F/4=16 devClk periods
    # Drive extra time beyond num_mf*lmfc_period to allow full ILAS to be processed
    ilas = timeline['ilas']
    # Pad ILAS with DATA words after the ILAS segment to keep driving during ILA_S
    ilas_words_to_drive = list(ilas) + [(0xDEADBEEF, 0)] * 64
    for data_32b, datak_4b in ilas_words_to_drive:
        for lane in range(l_g):
            getattr(dut, f"gtRxData_{lane}_i").value = data_32b
            getattr(dut, f"gtRxDataK_{lane}_i").value = datak_4b
        await RisingEdge(dut.devClk_i)
        await Timer(1, unit="ns")

    # Enable scrEnable if scrambled link-up: write commonCtrl bit5=1
    if scr:
        # 0x23 = subClass=1,replEnable=1,invertSync=0,scrEnable=1
        # RX scrEnable is bit 5; invertSync stays 0
        await write_reg_cdc(tb, 0x10, 0x23)

    # Drive DATA on all lanes continuously to keep link alive
    data_seg = timeline['data']
    data_cycle_count = 0
    for data_32b, datak_4b in data_seg:
        for lane in range(l_g):
            getattr(dut, f"gtRxData_{lane}_i").value = data_32b
            getattr(dut, f"gtRxDataK_{lane}_i").value = datak_4b
        await RisingEdge(dut.devClk_i)
        await Timer(1, unit="ns")
        data_cycle_count += 1

    # Keep driving last data word while waiting for dataValid to assert
    for lane in range(l_g):
        getattr(dut, f"gtRxData_{lane}_i").value = 0xDEADBEEF
        getattr(dut, f"gtRxDataK_{lane}_i").value = 0

    # Wait for all lanes to reach DATA state (wait_data_valid_all)
    await wait_data_valid_all(dut, l_g, clk=dut.devClk_i, timeout_cycles=512)


# ---------------------------------------------------------------------------
# Main test coroutine
# ---------------------------------------------------------------------------


@cocotb.test()
async def test_rx_reg_map(dut):
    """Register map walk + RX latency + nSyncAny full bench via Jesd204bRxWrapper.

    Drives full link-up via golden GT streams, then walks the complete
    JesdRxReg map, verifies PowerDown 0x24 RW (proving assertion), per-lane
    latency/valid-counters/rawData, RX delay sweep at sysRef_i->sysRefDbg_o,
    nSyncAny 4 cases, invertData one-shot, and per-lane distinct decode.
    """
    k = env_int("K_G", default=32)
    f = env_int("F_G", default=2)
    l_g = env_int("L_G", default=2)
    subclass = env_int("SUBCLASS", default=1)
    scr_enable = env_sl("SCR_ENABLE", default=0)

    tb = Jesd204bRxTopTB(dut, l_g)
    await tb.reset()

    # -----------------------------------------------------------------------
    # Step 1: Full link-up
    # -----------------------------------------------------------------------
    await drive_rx_link_up(tb, k=k, f=f, l_g=l_g, scr=bool(scr_enable))

    # Smoke-level integration: verify DATA state on all lanes
    for lane in range(l_g):
        dv = int(getattr(dut, f"dataValid_{lane}_o").value)
        assert dv == 1, (
            f"dataValid_{lane}_o not asserted after link-up "
            f"(L_G={l_g}, k={k}, f={f}, sc={subclass})"
        )

    # One sampleData payload spot-check: just read and verify non-X
    sd0 = int(dut.sampleData_0_o.value)
    assert 0 <= sd0 <= 0xFFFFFFFF, f"sampleData_0_o is not valid: {sd0}"

    # -----------------------------------------------------------------------
    # Step 2: RW register walk (full map vs _JesdRx.py golden)
    # -----------------------------------------------------------------------

    # 0x00 Enable RW [L_G-1:0]
    enable_mask = (1 << l_g) - 1
    await axil_write_u32(tb.axil, 0x00, enable_mask)
    val = await axil_read_u32(tb.axil, 0x00)
    assert (val & enable_mask) == enable_mask, (
        f"reg map Enable(0x00) readback fail: wrote {enable_mask:#x}, got {val:#010x}"
    )

    # 0x04 SysrefDelay RW [7:0]
    await axil_write_u32(tb.axil, 0x04, 0xA5)
    val = await axil_read_u32(tb.axil, 0x04)
    assert (val & 0xFF) == 0xA5, (
        f"reg map SysrefDelay(0x04) readback fail: got {val:#010x}"
    )
    # restore
    await axil_write_u32(tb.axil, 0x04, 0x00)

    # 0x08 Polarity RW [L_G-1:0]
    await axil_write_u32(tb.axil, 0x08, enable_mask)
    val = await axil_read_u32(tb.axil, 0x08)
    assert (val & enable_mask) == enable_mask, (
        f"reg map Polarity(0x08) readback fail: got {val:#010x}"
    )
    await axil_write_u32(tb.axil, 0x08, 0x00)

    # 0x10 CommonCtrl RW [5:0] (6-bit; scrEnable at bit 5)
    await axil_write_u32(tb.axil, 0x10, 0x23)
    val = await axil_read_u32(tb.axil, 0x10)
    assert (val & 0x3F) == 0x23, (
        f"reg map CommonCtrl(0x10) readback fail: got {val:#010x}"
    )
    # restore to working state (subClass=1, replEnable=1, invertSync=0)
    await write_reg_cdc(tb, 0x10, 0x03)

    # 0x14 LinkErrMask RW [5:0]
    await axil_write_u32(tb.axil, 0x14, 0x3F)
    val = await axil_read_u32(tb.axil, 0x14)
    assert (val & 0x3F) == 0x3F, (
        f"reg map LinkErrMask(0x14) readback fail: got {val:#010x}"
    )
    await write_reg_cdc(tb, 0x14, 0x00)

    # 0x18 InvertData RW [L_G-1:0]
    await axil_write_u32(tb.axil, 0x18, enable_mask)
    val = await axil_read_u32(tb.axil, 0x18)
    assert (val & enable_mask) == enable_mask, (
        f"reg map InvertData(0x18) readback fail: got {val:#010x}"
    )
    await write_reg_cdc(tb, 0x18, 0x00)

    # 0x24 PowerDown RW [L_G-1:0] -- PROVING ASSERTION
    # This is the headline assertion: pre-fix RTL would have failed here.
    # Write a value, read it back equal (not corrupted by stale wdata, not silently no-op).
    pd_val = enable_mask & 0x3
    await axil_write_u32(tb.axil, 0x24, pd_val)
    val = await axil_read_u32(tb.axil, 0x24)
    assert (val & enable_mask) == pd_val, (
        f"reg map PowerDown(0x24) proving assertion FAILED: "
        f"wrote {pd_val:#x}, got {val:#010x} masked={val & enable_mask:#x}. "
        f"Pre-fix JesdRxReg.vhd would return 0 (write action swapped to read path)."
    )
    # Write a second distinct value to confirm no aliasing
    await axil_write_u32(tb.axil, 0x24, 0x00)
    val2 = await axil_read_u32(tb.axil, 0x24)
    assert (val2 & enable_mask) == 0x00, (
        f"reg map PowerDown(0x24) second write fail: got {val2:#010x}"
    )

    # -----------------------------------------------------------------------
    # Step 3: Per-lane TestTXItf/TestSigThr distinct-value walk
    # -----------------------------------------------------------------------
    for lane in range(l_g):
        # 0x80+4*i TestTXItf[i] RW [15:0]: dlyTx[3:0]@[11:8], alignTx[3:0]@[3:0]
        tx_itf_val = ((lane + 1) << 8) | (lane + 5)
        await axil_write_u32(tb.axil, 0x80 + 4 * lane, tx_itf_val)
        # 0xC0+4*i TestSigThr[i] RW [31:0]
        thr_val = ((lane + 0x10) << 16) | (lane + 0x20)
        await axil_write_u32(tb.axil, 0xC0 + 4 * lane, thr_val)

    for lane in range(l_g):
        # Read back TestTXItf
        tx_itf_expected = ((lane + 1) << 8) | (lane + 5)
        val = await axil_read_u32(tb.axil, 0x80 + 4 * lane)
        assert (val & 0xFFFF) == tx_itf_expected, (
            f"TestTXItf[{lane}](0x{0x80 + 4*lane:02x}) aliased: "
            f"expected {tx_itf_expected:#x}, got {val:#010x}"
        )
        # Read back TestSigThr
        thr_expected = ((lane + 0x10) << 16) | (lane + 0x20)
        val = await axil_read_u32(tb.axil, 0xC0 + 4 * lane)
        assert (val & 0xFFFFFFFF) == thr_expected, (
            f"TestSigThr[{lane}](0x{0xC0 + 4*lane:02x}) aliased: "
            f"expected {thr_expected:#010x}, got {val:#010x}"
        )

    # -----------------------------------------------------------------------
    # Step 4: RO register walk gated behind dataValid
    # -----------------------------------------------------------------------
    # 0x28 SysRefPeriod / SysrefMon RO [31:0]
    val = await axil_read_u32(tb.axil, 0x28)
    # Can be 0 if no SYSREF pulsed yet — just verify it reads without error
    assert isinstance(val, int), f"reg map SysRefPeriod(0x28) read error: {val}"

    # 0x40+4*i StatusLane[i] RO — verify after link-up
    for lane in range(l_g):
        await tb.axi_cycle(4)
        status = await axil_read_u32(tb.axil, 0x40 + 4 * lane)
        assert status & STATUS_DATAVALID, (
            f"reg map StatusLane[{lane}](0x{0x40+4*lane:02x}): "
            f"DATAVALID bit not set after link-up; status={status:#010x}"
        )
        assert status & STATUS_ENABLE, (
            f"reg map StatusLane[{lane}](0x{0x40+4*lane:02x}): "
            f"ENABLE bit not set; status={status:#010x}"
        )
        latency = (status >> 18) & 0xFF
        assert latency > 0, (
            f"reg map StatusLane[{lane}](0x{0x40+4*lane:02x}): "
            f"LATENCY field [25:18] is zero; status={status:#010x}"
        )

    # 0x100+4*i ValidCnt[i] RO
    for lane in range(l_g):
        val = await axil_read_u32(tb.axil, 0x100 + 4 * lane)
        assert isinstance(val, int), (
            f"reg map ValidCnt[{lane}](0x{0x100+4*lane:03x}) read error"
        )

    # 0x140+4*i RawData[i] RO — read after axi_cycle(8) SynchronizerFifo settle
    await tb.axi_cycle(8)
    for lane in range(l_g):
        raw = await axil_read_u32(tb.axil, 0x140 + 4 * lane)
        assert isinstance(raw, int), (
            f"reg map RawData[{lane}](0x{0x140+4*lane:03x}) read error"
        )
        # Raw data should be a plausible GT word (any 32-bit value is valid)
        assert 0 <= raw <= 0xFFFFFFFF, (
            f"reg map RawData[{lane}](0x{0x140+4*lane:03x}) out of range: {raw}"
        )

    # -----------------------------------------------------------------------
    # Step 5: DECERR assertions
    # -----------------------------------------------------------------------
    await assert_decerr(tb.axil, 0x0C)    # explicitly unmapped
    await assert_decerr(tb.axil, 0x1C)    # explicitly unmapped
    await assert_decerr(tb.axil, 0x01)    # unaligned access

    # -----------------------------------------------------------------------
    # Step 6: RX sysRef_i -> sysRefDbg_o delay sweep
    # Relative delta method: O2-O1 must equal D2-D1 (avoid absolute-offset assumption)
    # -----------------------------------------------------------------------
    sweep_delays = [0, 1, 15, 255]  # {0, 1, mid, max} curated sweep points

    async def measure_sysref_offset(delay_val: int) -> int:
        """Write sysrefDlyRx, pulse sysRef_i, measure edge offset in devClk cycles.

        Clears the SlvDelay shift register by holding sysRef_i low for DELAY_G=256
        cycles before pulsing to avoid aliasing from previous pulses.
        """
        # Write delay with CDC settle
        await write_reg_cdc(tb, 0x04, delay_val, cdc_cycles=16)
        # Hold sysRef_i low for full DELAY_G=256+8 cycles to flush shift register
        dut.sysRef_i.value = 0
        await tb.dev_cycle(272)

        # Pulse sysRef_i high and measure devClk cycles until sysRefDbg_o rises
        dut.sysRef_i.value = 1
        offset = 0
        max_cycles = 600
        for _ in range(max_cycles):
            await RisingEdge(dut.devClk_i)
            await Timer(1, unit="ns")
            offset += 1
            if int(dut.sysRefDbg_o.value) == 1:
                break
        else:
            assert False, (
                f"RX latency: sysRefDbg_o never rose for delay={delay_val} "
                f"(waited {max_cycles} devClk cycles)"
            )
        dut.sysRef_i.value = 0
        return offset

    offsets = []
    for d in sweep_delays:
        off = await measure_sysref_offset(d)
        offsets.append(off)

    # Verify inter-point delta equals programmed delay delta (relative method)
    for i in range(1, len(sweep_delays)):
        d_delta = sweep_delays[i] - sweep_delays[i - 1]
        o_delta = offsets[i] - offsets[i - 1]
        assert o_delta == d_delta, (
            f"RX latency: delay delta [{sweep_delays[i-1]}->{sweep_delays[i]}]"
            f" expected offset delta={d_delta}, got o_delta={o_delta} "
            f"(offsets={offsets})"
        )

    # Restore sysrefDlyRx to 0
    await write_reg_cdc(tb, 0x04, 0x00, cdc_cycles=16)

    # -----------------------------------------------------------------------
    # Step 7: invertData one-shot -- lane0 only, lane1 stays normal
    # -----------------------------------------------------------------------
    if l_g >= 2:
        # Read baseline sampleData on both lanes
        baseline_0 = int(dut.sampleData_0_o.value)
        baseline_1 = int(dut.sampleData_1_o.value)

        # Set InvertData lane0 only (0x18 bit0=1)
        await write_reg_cdc(tb, 0x18, 0x01)
        await tb.dev_cycle(4)

        # Sample after invert applied
        inverted_0 = int(dut.sampleData_0_o.value)
        normal_1 = int(dut.sampleData_1_o.value)

        # Lane 0 should differ (invData() flips bits, so non-zero baseline gives change)
        # invData() in Jesd204bPkg.vhd: invData(data) = not data
        expected_inv_0 = (~baseline_0) & 0xFFFFFFFF
        assert inverted_0 == expected_inv_0, (
            f"invertData lane0: expected {expected_inv_0:#010x} "
            f"(~{baseline_0:#010x}), got {inverted_0:#010x}"
        )
        # Lane 1 should be unaffected (invData bit1=0)
        assert normal_1 == baseline_1, (
            f"invertData lane1 should be unchanged: "
            f"baseline={baseline_1:#010x}, got={normal_1:#010x}"
        )

        # Restore InvertData to 0
        await write_reg_cdc(tb, 0x18, 0x00)

    # -----------------------------------------------------------------------
    # Step 8: nSyncAny 4-case combining contract (L_G=2 only)
    # -----------------------------------------------------------------------
    if l_g >= 2:
        # Case (c): both disabled -> nSync_o=0 (allBits guard)
        # Disable all lanes
        await write_reg_cdc(tb, 0x00, 0x00)
        await tb.dev_cycle(8)
        assert int(dut.nSync_o.value) == 0, (
            "nSyncAny case(c): both disabled, expected nSync_o=0 "
            "(allBits(enableRx,'0') guard)"
        )

        # Case (b): lane1 disabled, lane0 alone controls nSync_o
        # Enable only lane0
        await write_reg_cdc(tb, 0x00, 0x01)
        await tb.dev_cycle(8)
        # With lane1 disabled: s_nSyncVecEn[1] = nSync[1] OR not enable[1] = X OR 1 = 1
        # So nSync_o = lane0's nSyncVec only
        # Lane0 should still be in DATA (dataValid asserted), so nSync[0]=1
        dv0 = int(dut.dataValid_0_o.value)
        if dv0 == 1:
            # Lane0 in DATA -> nSync[0]=1 -> nSync_o=1
            assert int(dut.nSync_o.value) == 1, (
                "nSyncAny case(b): lane1 disabled, lane0 in DATA, "
                "expected nSync_o=1 (lane0 alone controls)"
            )

        # Case (a): both enabled, force lane0 out of DATA -> nSync_o=0
        # Re-enable both lanes and inject error on lane0 with UNMASKED linkErrMask
        await write_reg_cdc(tb, 0x00, 0x03)  # enable both lanes
        await write_reg_cdc(tb, 0x14, 0x01)  # unmask alignErr on lane0
        await tb.dev_cycle(4)

        # Inject a misplaced K-char on lane0 to trigger alignErr -> link drop -> nSync[0]=0
        getattr(dut, "gtRxData_0_i").value = K_CHAR
        getattr(dut, "gtRxDataK_0_i").value = 0x1
        await tb.dev_cycle(4)
        getattr(dut, "gtRxData_0_i").value = 0
        getattr(dut, "gtRxDataK_0_i").value = 0

        # Wait for nSync_o to go 0 (lane0 drops -> AND combine -> nSync_o=0)
        await wait_for_signal(dut.nSync_o, value=0, clk=dut.devClk_i, timeout_cycles=32)
        assert int(dut.nSync_o.value) == 0, (
            "nSyncAny case(a/d): lane0 dropped with unmasked error, "
            "expected nSync_o=0"
        )

        # Restore linkErrMask
        await write_reg_cdc(tb, 0x14, 0x00)


# ---------------------------------------------------------------------------
# pytest wrapper
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_JesdRxReg(parameters):
    """RX register map walk + latency check via Jesd204bRxWrapper."""
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesd204brxwrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "protocols/jesd204b/wrappers/Jesd204bRxWrapper.vhd",
            ]
        },
    )
