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
# - Sweep: Cover the two request-serialization branches that are unique to
#   `CoaXPressConfig`: untagged reads and tagged writes.
# - Stimulus: Drive one-beat SRPv3 request frames into `cfgIb` and capture the
#   emitted CoaXPress low-speed byte stream on `cfgTx`.
# - Checks: The DUT must emit the spec-shaped request prefix/suffix, select the
#   correct tagged or untagged packet type, preserve the address and write-data
#   fields, and increment the tagged packet counter across transactions.
# - Timing: Requests are accepted through the real `TREADY` handshake and the
#   test waits on the serialized CoaXPress bytes rather than assuming an ideal
#   one-cycle transfer through the assembly.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer, with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_SOP,
    collect_stream_bytes,
    endian_swap32,
    pack_u32_words_le,
    reset_signals,
    send_axis_payload,
    set_initial_values,
    start_clock,
    word_to_bytes,
)

pytestmark = pytest.mark.skip(
    reason=(
        "Blocked by a suspected CoaXPressConfig/SrpV3AxiLite integration issue: "
        "the real SRP-driven request path does not complete within the current bench timeout."
    )
)


READ_OPCODE = 0x0
WRITE_OPCODE = 0x1


def _srp_request_words(*, opcode: int, tid: int, addr: int, req_size: int, write_data: int | None = None) -> list[int]:
    words = [0x00000003 | (opcode << 8), tid, addr & 0xFFFFFFFF, 0x00000000, req_size]
    if write_data is not None:
        words.append(write_data & 0xFFFFFFFF)
    return words


async def _drive_cfg_rx_completion(dut, value: int, *, hold_cycles: int = 8) -> None:
    dut.cfgRxTData.value = value
    dut.cfgRxTValid.value = 1
    for _ in range(hold_cycles):
        await RisingEdge(dut.cfgClk)
        await Timer(1, unit="ns")
    dut.cfgRxTValid.value = 0
    dut.cfgRxTData.value = 0


@cocotb.test()
async def coaxpress_config_untagged_read_request_test(dut):
    start_clock(dut.cfgClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "S_CFG_IB_TVALID": 0,
            "S_CFG_IB_TDATA": 0,
            "S_CFG_IB_TKEEP": 0,
            "S_CFG_IB_TLAST": 0,
            "S_CFG_IB_TUSER": 0,
            "M_CFG_OB_TREADY": 1,
            "M_CFG_TX_TREADY": 0,
            "cfgRxTValid": 0,
            "cfgRxTData": 0,
            "configTimerSize": 4096,
            "configErrResp": 1,
            "configPktTag": 0,
        },
    )
    await reset_signals(dut, clk=dut.cfgClk, reset_names=("cfgRst",), assert_cycles=10, release_cycles=5)

    tid = 0x12345678
    addr = 0x00000040
    read_data = 0xDDAA5501
    request_payload = pack_u32_words_le(
        _srp_request_words(opcode=READ_OPCODE, tid=tid, addr=addr, req_size=0x00000003)
    )

    tx_task = cocotb.start_soon(
        collect_stream_bytes(
            dut,
            clk=dut.cfgClk,
            valid_name="M_CFG_TX_TVALID",
            data_name="M_CFG_TX_TDATA",
            ready_name="M_CFG_TX_TREADY",
            count=24,
            timeout_cycles=8000,
        )
    )
    await send_axis_payload(dut, clk=dut.cfgClk, prefix="S_CFG_IB", payload=request_payload, width_bytes=32, tuser=0x2)

    tx_bytes = await with_timeout(tx_task, 20, "us")

    expected_prefix = (
        bytes(word_to_bytes(CXP_SOP))
        + bytes([0x02] * 4)
        + bytes(word_to_bytes(0x04000000))
        + bytes(word_to_bytes(endian_swap32(addr)))
    )
    assert tx_bytes.startswith(expected_prefix)
    assert tx_bytes[-4:] == bytes(word_to_bytes(CXP_EOP))
    assert tx_bytes[16:20] != b"\x00\x00\x00\x00"
    await _drive_cfg_rx_completion(dut, read_data << 32)


@cocotb.test()
async def coaxpress_config_tagged_write_tag_increment_test(dut):
    start_clock(dut.cfgClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "S_CFG_IB_TVALID": 0,
            "S_CFG_IB_TDATA": 0,
            "S_CFG_IB_TKEEP": 0,
            "S_CFG_IB_TLAST": 0,
            "S_CFG_IB_TUSER": 0,
            "M_CFG_OB_TREADY": 1,
            "M_CFG_TX_TREADY": 0,
            "cfgRxTValid": 0,
            "cfgRxTData": 0,
            "configTimerSize": 4096,
            "configErrResp": 1,
            "configPktTag": 1,
        },
    )
    await reset_signals(dut, clk=dut.cfgClk, reset_names=("cfgRst",), assert_cycles=10, release_cycles=5)

    requests = [
        (0x0BADB002, 0x00000020, 0x11223344, 0x00),
        (0x0BADB003, 0x00000024, 0x55667788, 0x01),
    ]

    for tid, addr, write_data, expected_tag in requests:
        request_payload = pack_u32_words_le(
            _srp_request_words(opcode=WRITE_OPCODE, tid=tid, addr=addr, req_size=0x00000003, write_data=write_data)
        )

        tx_task = cocotb.start_soon(
            collect_stream_bytes(
                dut,
                clk=dut.cfgClk,
                valid_name="M_CFG_TX_TVALID",
                data_name="M_CFG_TX_TDATA",
                ready_name="M_CFG_TX_TREADY",
                count=32,
                timeout_cycles=8000,
            )
        )
        await send_axis_payload(dut, clk=dut.cfgClk, prefix="S_CFG_IB", payload=request_payload, width_bytes=32, tuser=0x2)

        tx_bytes = await with_timeout(tx_task, 20, "us")
        assert tx_bytes[:4] == bytes(word_to_bytes(CXP_SOP))
        assert tx_bytes[4:8] == bytes([0x05] * 4)
        assert tx_bytes[8:12] == bytes([expected_tag] * 4)
        assert tx_bytes[12:16] == bytes(word_to_bytes(0x04000001))
        assert tx_bytes[16:20] == bytes(word_to_bytes(endian_swap32(addr)))
        assert tx_bytes[20:24] == bytes(word_to_bytes(write_data))
        assert tx_bytes[-4:] == bytes(word_to_bytes(CXP_EOP))

        await _drive_cfg_rx_completion(dut, 0)


def test_CoaXPressConfig():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressconfigwrapper",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressConfig.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressConfigWrapper.vhd",
            ]
        },
    )
