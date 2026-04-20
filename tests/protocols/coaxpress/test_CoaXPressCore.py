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
from cocotb.triggers import with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_SOP,
    collect_stream_bytes,
    endian_swap32,
    find_subsequence,
    pack_u32_words_le,
    reset_signals,
    send_axis_payload,
    set_initial_values,
    word_to_bytes,
)


@cocotb.test()
async def coaxpress_core_tagged_config_tx_path_test(dut):
    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, dut.axilClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "txTrig": 0,
            "txLinkUp": 1,
            "rxData": 0xB53C3CBC,
            "rxDataK": 0x7,
            "rxDispErr": 0,
            "rxDecErr": 0,
            "rxLinkUp": 1,
            "S_CFG_IB_TVALID": 0,
            "S_CFG_IB_TDATA": 0,
            "S_CFG_IB_TKEEP": 0,
            "S_CFG_IB_TLAST": 0,
            "S_CFG_IB_TUSER": 0,
            "M_CFG_OB_TREADY": 0,
            "M_DATA_TREADY": 1,
            "M_HDR_TREADY": 1,
        },
    )
    await reset_signals(
        dut,
        clk=dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst", "axilRst"),
        assert_cycles=10,
        release_cycles=5,
    )

    axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.axilClk, dut.axilRst)

    reg_ff8 = await axil.read_dword(0xFF8)
    await axil.write_dword(0xFF8, reg_ff8 | (1 << 26) | (1 << 27))
    updated_ff8 = await axil.read_dword(0xFF8)
    assert (updated_ff8 >> 26) & 0x1 == 1
    assert (updated_ff8 >> 27) & 0x1 == 1

    tid = 0x13579BDF
    addr = 0x00000040
    request_payload = pack_u32_words_le([0x00000003, tid, addr, 0x00000000, 0x00000003])

    tx_task = cocotb.start_soon(
        collect_stream_bytes(
            dut,
            clk=dut.txClk,
            valid_name="txLsValid",
            data_name="txLsData",
            count=32,
            timeout_cycles=12000,
        )
    )
    await send_axis_payload(dut, clk=dut.cfgClk, prefix="S_CFG_IB", payload=request_payload, width_bytes=32, tuser=0x2)

    tx_bytes = await with_timeout(tx_task, 20, "us")
    expected_request = (
        bytes(word_to_bytes(CXP_SOP))
        + bytes([0x05] * 4)
        + b"\x00\x00\x00\x00"
        + bytes(word_to_bytes(0x04000000))
        + bytes(word_to_bytes(endian_swap32(addr)))
    )
    request_start = find_subsequence(tx_bytes, expected_request)
    assert request_start is not None, tx_bytes


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
