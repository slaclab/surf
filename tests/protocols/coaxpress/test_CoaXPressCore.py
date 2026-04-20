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
# - Sweep: Keep the first `CoaXPressCore` pass on the one-lane top-level path
#   and focus on the unique cross-block integration that only the full core can
#   exercise: AXI-Lite control of `configPktTag`/`txLsRate` into the config/TX
#   assembly.
# - Stimulus: Program `configPktTag` and the fast low-speed rate over AXI-Lite,
#   then send one SRPv3 read request through the core config ingress.
# - Checks: The top level must expose the programmed AXI-Lite register values
#   back to software and serialize the corresponding tagged CoaXPress config
#   request on the TX low-speed byte stream.
# - Timing: AXI-Lite writes, config ingress, and TX byte observation all run on
#   the real module interfaces, so the bench checks the actual sequencing across
#   `CoaXPressAxiL`, `CoaXPressConfig`, and `CoaXPressTx`.

import cocotb
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks
from tests.protocols.coaxpress.coaxpress_test_utils import CXP_SOP, endian_swap32, pack_bytes, word_to_bytes


def _words_to_payload(words: list[int]) -> bytes:
    return b"".join((word & 0xFFFFFFFF).to_bytes(4, "little") for word in words)


async def _reset_all(dut) -> None:
    dut.dataRst.value = 1
    dut.cfgRst.value = 1
    dut.txRst.value = 1
    dut.rxRst.value = 1
    dut.axilRst.value = 1
    await Timer(40, unit="ns")
    dut.dataRst.value = 0
    dut.cfgRst.value = 0
    dut.txRst.value = 0
    dut.rxRst.value = 0
    dut.axilRst.value = 0
    await Timer(20, unit="ns")


async def _send_cfg_ib_frame(dut, payload: bytes) -> None:
    dut.S_CFG_IB_TVALID.value = 1
    dut.S_CFG_IB_TDATA.value = pack_bytes(payload, width_bytes=32)
    dut.S_CFG_IB_TKEEP.value = (1 << len(payload)) - 1
    dut.S_CFG_IB_TLAST.value = 1
    dut.S_CFG_IB_TUSER.value = 0x2
    while True:
        await RisingEdge(dut.cfgClk)
        await Timer(1, unit="ns")
        if int(dut.S_CFG_IB_TREADY.value) == 1:
            break
    dut.S_CFG_IB_TVALID.value = 0
    dut.S_CFG_IB_TDATA.value = 0
    dut.S_CFG_IB_TKEEP.value = 0
    dut.S_CFG_IB_TLAST.value = 0
    dut.S_CFG_IB_TUSER.value = 0


async def _collect_tx_bytes(dut, *, count: int, timeout_cycles: int = 12000) -> list[tuple[int, int]]:
    observed: list[tuple[int, int]] = []
    for _ in range(timeout_cycles):
        await RisingEdge(dut.txClk)
        await Timer(1, unit="ns")
        if int(dut.txLsValid.value) == 1:
            observed.append((int(dut.txLsData.value), int(dut.txLsDataK.value)))
            if len(observed) >= count:
                return observed
    raise AssertionError("Timed out waiting for CoaXPressCore TX bytes")


def _find_subsequence(payload: bytes, expected: bytes) -> int | None:
    for start in range(len(payload) - len(expected) + 1):
        if payload[start : start + len(expected)] == expected:
            return start
    return None


@cocotb.test()
async def coaxpress_core_tagged_config_tx_path_test(dut):
    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, dut.axilClk, period_ns=4.0)
    dut.txTrig.setimmediatevalue(0)
    dut.txLinkUp.setimmediatevalue(1)
    dut.rxData.setimmediatevalue(0xB53C3CBC)
    dut.rxDataK.setimmediatevalue(0x7)
    dut.rxDispErr.setimmediatevalue(0)
    dut.rxDecErr.setimmediatevalue(0)
    dut.rxLinkUp.setimmediatevalue(1)
    dut.S_CFG_IB_TVALID.setimmediatevalue(0)
    dut.S_CFG_IB_TDATA.setimmediatevalue(0)
    dut.S_CFG_IB_TKEEP.setimmediatevalue(0)
    dut.S_CFG_IB_TLAST.setimmediatevalue(0)
    dut.S_CFG_IB_TUSER.setimmediatevalue(0)
    dut.M_CFG_OB_TREADY.setimmediatevalue(0)
    dut.M_DATA_TREADY.setimmediatevalue(1)
    dut.M_HDR_TREADY.setimmediatevalue(1)
    await _reset_all(dut)

    axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.axilClk, dut.axilRst)

    reg_ff8 = await axil.read_dword(0xFF8)
    await axil.write_dword(0xFF8, reg_ff8 | (1 << 26) | (1 << 27))
    updated_ff8 = await axil.read_dword(0xFF8)
    assert (updated_ff8 >> 26) & 0x1 == 1
    assert (updated_ff8 >> 27) & 0x1 == 1

    tid = 0x13579BDF
    addr = 0x00000040
    request_payload = _words_to_payload([0x00000003, tid, addr, 0x00000000, 0x00000003])

    tx_task = cocotb.start_soon(_collect_tx_bytes(dut, count=32))
    await _send_cfg_ib_frame(dut, request_payload)

    tx_bytes = await with_timeout(tx_task, 20, "us")
    tx_payload = bytes(data for data, _ in tx_bytes)
    expected_request = (
        bytes(word_to_bytes(CXP_SOP))
        + bytes([0x05] * 4)
        + b"\x00\x00\x00\x00"
        + bytes(word_to_bytes(0x04000000))
        + bytes(word_to_bytes(endian_swap32(addr)))
    )
    request_start = _find_subsequence(tx_payload, expected_request)
    assert request_start is not None, tx_payload


def test_CoaXPressCore():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpresscorewrapper",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressEventAckMsg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressTxLsFsm.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressTx.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxWordPacker.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxLaneMux.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxLane.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxHsFsm.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRx.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressConfig.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressAxiL.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressCore.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressCoreWrapper.vhd",
            ]
        },
    )
