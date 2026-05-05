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
# - Sweep: Exercise the software-visible CXPoF bridge RX status register file
#   through the AXI-Lite clock crossing.
# - Stimulus: Pulse representative receive-domain status events for `/Q/`
#   sequence tracking, sequence mismatch, HKP classification, and `/E/` abort.
# - Checks: AXI-Lite reads must report sticky status, last-observed status
#   fields, event counters, and write-one counter/sticky reset behavior.
# - Timing: AXI-Lite and RX clocks run asynchronously so the bench covers the
#   intended `AxiLiteAsync` path, not only a common-clock register file.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_ALL_CTRL_K,
    CXP_EOP,
    CXPOF_HKP_TYPE_EOP,
    CXPOF_HKP_TYPE_K_CODE,
    CXPOF_RX_ERR_PAYLOAD_ABORT,
    CXPOF_RX_ERR_SEQ_MISMATCH,
)


STATUS_RX_ERROR = 1 << 0
STATUS_RX_ABORT = 1 << 1
STATUS_SEQ_VALID = 1 << 2
STATUS_SEQ_ERROR = 1 << 3
STATUS_HKP_VALID = 1 << 4
STATUS_HKP_ERROR = 1 << 5


async def _rx_cycle(dut, count: int = 1) -> None:
    for _ in range(count):
        await RisingEdge(dut.rxClk)
        await Timer(1, unit="ns")


async def _axil_read(axil, address: int) -> int:
    return await with_timeout(axil_read_u32(axil, address), 2, "us")


async def _axil_write(axil, address: int, value: int) -> None:
    await with_timeout(axil_write_u32(axil, address, value), 2, "us")


def _clear_status_inputs(dut) -> None:
    for name in (
        "rxError",
        "rxAbort",
        "rxErrorCode",
        "seqValid",
        "seqData",
        "seqError",
        "seqExpected",
        "seqErrorExpected",
        "hkpValid",
        "hkpData",
        "hkpEop",
        "hkpSof",
        "hkpError",
        "hkpWordCount",
        "hkpKCodeMask",
        "hkpKCodeValid",
        "hkpType",
    ):
        getattr(dut, name).value = 0


async def _pulse_status(dut, **values: int) -> None:
    _clear_status_inputs(dut)
    for name, value in values.items():
        getattr(dut, name).value = value
    await _rx_cycle(dut)
    _clear_status_inputs(dut)


async def _read_until(axil, address: int, expected: int, *, mask: int = 0xFFFFFFFF) -> int:
    for _ in range(64):
        value = await _axil_read(axil, address)
        if (value & mask) == expected:
            return value
    raise AssertionError(f"AXI-Lite 0x{address:03X} did not reach 0x{expected:X}")


@cocotb.test()
async def coaxpress_over_fiber_bridge_axil_status_registers_test(dut):
    cocotb.start_soon(Clock(dut.rxClk, 4.0, unit="ns").start())
    cocotb.start_soon(Clock(dut.S_AXI_ACLK, 7.0, unit="ns").start())

    dut.rxRst.setimmediatevalue(1)
    dut.S_AXI_ARESETN.setimmediatevalue(0)
    _clear_status_inputs(dut)

    axil = AxiLiteMaster(
        AxiLiteBus.from_prefix(dut, "S_AXI"),
        dut.S_AXI_ACLK,
        dut.S_AXI_ARESETN,
        reset_active_level=False,
    )

    await _rx_cycle(dut, 8)
    dut.S_AXI_ARESETN.value = 1
    dut.rxRst.value = 0
    await _rx_cycle(dut, 8)

    assert await _axil_read(axil, 0x000) == 0
    assert await _axil_read(axil, 0x020) == 0

    await _pulse_status(
        dut,
        seqValid=1,
        seqData=0x341200,
        seqExpected=0x341201,
    )

    await _pulse_status(
        dut,
        rxError=1,
        rxErrorCode=CXPOF_RX_ERR_SEQ_MISMATCH,
        seqValid=1,
        seqData=0x341203,
        seqExpected=0x341204,
        seqError=1,
        seqErrorExpected=0x341202,
    )

    await _pulse_status(
        dut,
        hkpValid=1,
        hkpData=CXP_EOP,
        hkpEop=1,
        hkpSof=1,
        hkpWordCount=1,
        hkpKCodeMask=CXP_ALL_CTRL_K,
        hkpKCodeValid=1,
        hkpType=CXPOF_HKP_TYPE_EOP,
    )

    await _pulse_status(
        dut,
        rxError=1,
        rxAbort=1,
        rxErrorCode=CXPOF_RX_ERR_PAYLOAD_ABORT,
    )

    expected_sticky = (
        STATUS_RX_ERROR
        | STATUS_RX_ABORT
        | STATUS_SEQ_VALID
        | STATUS_SEQ_ERROR
        | STATUS_HKP_VALID
    )
    assert (await _read_until(axil, 0x000, expected_sticky, mask=0x3F)) & 0x3F == expected_sticky

    assert (await _read_until(axil, 0x004, CXPOF_RX_ERR_PAYLOAD_ABORT, mask=0xF)) & 0xF == CXPOF_RX_ERR_PAYLOAD_ABORT
    assert (await _read_until(axil, 0x008, 0x341203, mask=0xFFFFFF)) & 0xFFFFFF == 0x341203
    assert (await _read_until(axil, 0x00C, 0x341204, mask=0xFFFFFF)) & 0xFFFFFF == 0x341204
    assert (await _read_until(axil, 0x010, 0x341202, mask=0xFFFFFF)) & 0xFFFFFF == 0x341202
    assert await _read_until(axil, 0x014, CXP_EOP) == CXP_EOP

    hkp_status = await _read_until(axil, 0x018, 1, mask=0xFF)
    assert (hkp_status >> 0) & 0xFF == 1
    assert (hkp_status >> 8) & 0xF == CXP_ALL_CTRL_K
    assert (hkp_status >> 12) & 0x1 == 1
    assert (hkp_status >> 16) & 0xF == CXPOF_HKP_TYPE_EOP

    assert await _read_until(axil, 0x020, 2) == 2
    assert await _read_until(axil, 0x024, 1) == 1
    assert await _read_until(axil, 0x028, 2) == 2
    assert await _read_until(axil, 0x02C, 1) == 1
    assert await _read_until(axil, 0x030, 1) == 1
    assert await _read_until(axil, 0x034, 0) == 0

    await _axil_write(axil, 0x03C, 1)
    assert (await _read_until(axil, 0x000, 0, mask=0x3F)) & 0x3F == 0
    assert await _read_until(axil, 0x020, 0) == 0

    await _pulse_status(
        dut,
        rxError=1,
        rxErrorCode=0x7,
        hkpValid=1,
        hkpError=1,
        hkpData=0x11223344,
        hkpWordCount=1,
        hkpKCodeMask=0,
        hkpKCodeValid=0,
        hkpType=CXPOF_HKP_TYPE_K_CODE,
    )

    expected_hkp_error = STATUS_RX_ERROR | STATUS_HKP_VALID | STATUS_HKP_ERROR
    assert (await _read_until(axil, 0x000, expected_hkp_error, mask=0x3F)) & 0x3F == expected_hkp_error
    assert await _read_until(axil, 0x030, 1) == 1
    assert await _read_until(axil, 0x034, 1) == 1


def test_CoaXPressOverFiberBridgeAxiL():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressoverfiberbridgeaxilwrapper",
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressOverFiberBridgeAxiL.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressOverFiberBridgeAxiLWrapper.vhd",
            ]
        },
    )
