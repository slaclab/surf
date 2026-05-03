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
# - Sweep: Cover all four config request-format quadrants plus local timeout
#   and nonzero control-ack response error handling.
# - Stimulus: Drive wide SRPv3 request frames into `cfgIb`, capture the emitted
#   CoaXPress low-speed byte stream on `cfgTx`, and feed the completion side
#   with one config receive acknowledgment.
# - Checks: The DUT must emit the spec-shaped request prefix/suffix, select the
#   correct tagged or untagged packet type, preserve the address and write-data
#   fields, calculate the command CRC, increment the tagged packet counter, and
#   complete the SRPv3 response frame.
# - Timing: Requests are accepted through the real `TREADY` handshake and the
#   test waits on both serialized CoaXPress bytes and the returned SRPv3 frame
#   rather than assuming an ideal one-cycle transfer through the assembly.

import cocotb
from cocotb.triggers import RisingEdge, Timer, with_timeout

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_SOP,
    collect_stream_bytes,
    cxp_crc_word,
    endian_swap32,
    repeat_byte,
    reset_signals,
    set_initial_values,
    start_clock,
    word_to_bytes,
)
from tests.protocols.srp.srp_test_utils import (
    FlatSrpAxis,
    SRP_READ,
    SRP_WRITE,
    SrpV3Request,
    assert_srpv3_response,
    srpv3_frame,
)


CONFIG_READ_ERROR_FOOTER = 0x1
CONFIG_WRITE_ERROR_FOOTER = 0x2


async def _drive_cfg_rx_completion(dut, value: int, *, hold_cycles: int = 8) -> None:
    dut.cfgRxTData.value = value
    dut.cfgRxTValid.value = 1
    for _ in range(hold_cycles):
        await RisingEdge(dut.cfgClk)
        await Timer(1, unit="ns")
    dut.cfgRxTValid.value = 0
    dut.cfgRxTData.value = 0


async def _setup_config_bench(dut, *, config_pkt_tag: int) -> FlatSrpAxis:
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
            "configPktTag": config_pkt_tag,
        },
    )
    await reset_signals(
        dut,
        clk=dut.cfgClk,
        reset_names=("cfgRst",),
        assert_cycles=10,
        release_cycles=5,
    )
    axis = FlatSrpAxis(
        dut,
        clk=dut.cfgClk,
        source_prefix="S_CFG_IB",
        sink_prefix="M_CFG_OB",
        data_bytes=32,
    )
    axis.init_source()
    axis.init_sink()
    return axis


@cocotb.test()
async def coaxpress_config_untagged_read_request_test(dut):
    axis = await _setup_config_bench(dut, config_pkt_tag=0)

    tid = 0x12345678
    addr = 0x00000040
    read_data = 0xDDAA5501
    request = SrpV3Request(SRP_READ, tid, addr, 4)

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
    response_task = cocotb.start_soon(axis.recv_response(timeout_time=20))
    await axis.send_words(srpv3_frame(request))

    tx_bytes = await with_timeout(tx_task, 20, "us")

    expected_prefix = (
        bytes(word_to_bytes(CXP_SOP))
        + bytes([0x02] * 4)
        + bytes(word_to_bytes(0x04000000))
        + bytes(word_to_bytes(endian_swap32(addr)))
    )
    expected_crc = cxp_crc_word([0x04000000, endian_swap32(addr)])
    assert tx_bytes.startswith(expected_prefix)
    assert tx_bytes[16:20] == bytes(word_to_bytes(expected_crc))
    assert tx_bytes[-4:] == bytes(word_to_bytes(CXP_EOP))

    await _drive_cfg_rx_completion(dut, read_data << 32)
    assert_srpv3_response(
        await response_task,
        request,
        [read_data],
    )


@cocotb.test()
async def coaxpress_config_tagged_write_tag_increment_test(dut):
    axis = await _setup_config_bench(dut, config_pkt_tag=1)

    requests = [
        (0x0BADB002, 0x00000020, 0x11223344, 0x00),
        (0x0BADB003, 0x00000024, 0x55667788, 0x01),
    ]

    for tid, addr, write_data, expected_tag in requests:
        request = SrpV3Request(SRP_WRITE, tid, addr, 4)

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
        response_task = cocotb.start_soon(axis.recv_response(timeout_time=20))
        await axis.send_words(srpv3_frame(request, [write_data]))

        tx_bytes = await with_timeout(tx_task, 20, "us")
        assert tx_bytes[:4] == bytes(word_to_bytes(CXP_SOP))
        assert tx_bytes[4:8] == bytes([0x05] * 4)
        assert tx_bytes[8:12] == bytes([expected_tag] * 4)
        assert tx_bytes[12:16] == bytes(word_to_bytes(0x04000001))
        assert tx_bytes[16:20] == bytes(word_to_bytes(endian_swap32(addr)))
        assert tx_bytes[20:24] == bytes(word_to_bytes(write_data))
        expected_crc = cxp_crc_word(
            [repeat_byte(expected_tag), 0x04000001, endian_swap32(addr), write_data]
        )
        assert tx_bytes[24:28] == bytes(word_to_bytes(expected_crc))
        assert tx_bytes[-4:] == bytes(word_to_bytes(CXP_EOP))

        await _drive_cfg_rx_completion(dut, 0)
        assert_srpv3_response(
            await response_task,
            request,
            [write_data],
        )


@cocotb.test()
async def coaxpress_config_tagged_read_and_untagged_write_request_test(dut):
    # Cover the two request-format quadrants not hit by the original directed
    # cases: tagged read and untagged write.
    axis = await _setup_config_bench(dut, config_pkt_tag=1)

    read_request = SrpV3Request(SRP_READ, 0x12340001, 0x00000120, 4)
    read_data = 0x13579BDF
    read_tx_task = cocotb.start_soon(
        collect_stream_bytes(
            dut,
            clk=dut.cfgClk,
            valid_name="M_CFG_TX_TVALID",
            data_name="M_CFG_TX_TDATA",
            ready_name="M_CFG_TX_TREADY",
            count=28,
            timeout_cycles=8000,
        )
    )
    read_response_task = cocotb.start_soon(axis.recv_response(timeout_time=20))
    await axis.send_words(srpv3_frame(read_request))

    read_tx_bytes = await with_timeout(read_tx_task, 20, "us")
    assert read_tx_bytes[:4] == bytes(word_to_bytes(CXP_SOP))
    assert read_tx_bytes[4:8] == bytes([0x05] * 4)
    assert read_tx_bytes[8:12] == bytes([0x00] * 4)
    assert read_tx_bytes[12:16] == bytes(word_to_bytes(0x04000000))
    assert read_tx_bytes[16:20] == bytes(word_to_bytes(endian_swap32(read_request.address)))
    expected_read_crc = cxp_crc_word(
        [0x00000000, 0x04000000, endian_swap32(read_request.address)]
    )
    assert read_tx_bytes[20:24] == bytes(word_to_bytes(expected_read_crc))
    assert read_tx_bytes[-4:] == bytes(word_to_bytes(CXP_EOP))

    await _drive_cfg_rx_completion(dut, read_data << 32)
    assert_srpv3_response(await read_response_task, read_request, [read_data])

    dut.configPktTag.value = 0
    await RisingEdge(dut.cfgClk)
    await Timer(1, unit="ns")

    write_request = SrpV3Request(SRP_WRITE, 0x12340002, 0x00000124, 4)
    write_data = 0x2468ACE0
    write_tx_task = cocotb.start_soon(
        collect_stream_bytes(
            dut,
            clk=dut.cfgClk,
            valid_name="M_CFG_TX_TVALID",
            data_name="M_CFG_TX_TDATA",
            ready_name="M_CFG_TX_TREADY",
            count=28,
            timeout_cycles=8000,
        )
    )
    write_response_task = cocotb.start_soon(axis.recv_response(timeout_time=20))
    await axis.send_words(srpv3_frame(write_request, [write_data]))

    write_tx_bytes = await with_timeout(write_tx_task, 20, "us")
    assert write_tx_bytes[:4] == bytes(word_to_bytes(CXP_SOP))
    assert write_tx_bytes[4:8] == bytes([0x02] * 4)
    assert write_tx_bytes[8:12] == bytes(word_to_bytes(0x04000001))
    assert write_tx_bytes[12:16] == bytes(word_to_bytes(endian_swap32(write_request.address)))
    assert write_tx_bytes[16:20] == bytes(word_to_bytes(write_data))
    expected_write_crc = cxp_crc_word(
        [0x04000001, endian_swap32(write_request.address), write_data]
    )
    assert write_tx_bytes[20:24] == bytes(word_to_bytes(expected_write_crc))
    assert write_tx_bytes[-4:] == bytes(word_to_bytes(CXP_EOP))

    await _drive_cfg_rx_completion(dut, 0)
    assert_srpv3_response(await write_response_task, write_request, [write_data])


@cocotb.test()
async def coaxpress_config_response_error_paths_test(dut):
    # The current RTL maps either a local config-response timeout or a nonzero
    # control-ack status word into the local SRPv3 AXI-Lite error footer when
    # `configErrResp` is asserted.
    axis = await _setup_config_bench(dut, config_pkt_tag=0)
    dut.configTimerSize.value = 8

    timeout_request = SrpV3Request(SRP_READ, 0xABC00001, 0x00000200, 4)
    timeout_tx_task = cocotb.start_soon(
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
    timeout_response_task = cocotb.start_soon(axis.recv_response(timeout_time=20))
    await axis.send_words(srpv3_frame(timeout_request))
    await with_timeout(timeout_tx_task, 20, "us")
    assert_srpv3_response(
        await timeout_response_task,
        timeout_request,
        [],
        footer_mask=CONFIG_READ_ERROR_FOOTER,
        footer_value=CONFIG_READ_ERROR_FOOTER,
    )

    dut.configTimerSize.value = 4096
    status_request = SrpV3Request(SRP_WRITE, 0xABC00002, 0x00000204, 4)
    status_write_data = 0xA5A55A5A
    status_tx_task = cocotb.start_soon(
        collect_stream_bytes(
            dut,
            clk=dut.cfgClk,
            valid_name="M_CFG_TX_TVALID",
            data_name="M_CFG_TX_TDATA",
            ready_name="M_CFG_TX_TREADY",
            count=28,
            timeout_cycles=8000,
        )
    )
    status_response_task = cocotb.start_soon(axis.recv_response(timeout_time=20))
    await axis.send_words(srpv3_frame(status_request, [status_write_data]))
    await with_timeout(status_tx_task, 20, "us")

    await _drive_cfg_rx_completion(dut, 0x00000001)
    assert_srpv3_response(
        await status_response_task,
        status_request,
        [status_write_data],
        footer_mask=CONFIG_WRITE_ERROR_FOOTER,
        footer_value=CONFIG_WRITE_ERROR_FOOTER,
    )


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
