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
# - Sweep: Isolate `AxiLiteSrpV0` from the SRPv0 loopback wrapper and exercise
#   write/read requests plus malformed response handling.
# - Stimulus: Drive AXI-Lite transactions from cocotb, capture the generated
#   128-bit SRPv0 stream word, and inject matching or intentionally bad stream
#   responses.
# - Checks: The emitted SRPv0 fields must contain the transaction count,
#   address/opcode, data, and terminal zero word expected by the legacy bridge,
#   while bad responses must translate into AXI-Lite `SLVERR` responses.
# - Timing: AXI-Lite requests run concurrently with stream capture/response
#   coroutines so the DUT is checked through real ready/valid handshakes.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.axi.utils import wait_sampled_ready
from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.srp.srp_test_utils import FlatSrpAxis


SRPV0_READ = 0
SRPV0_WRITE = 1


def srpv0_addr_word(opcode: int, address: int) -> int:
    return ((opcode & 0x3) << 30) | ((address >> 2) & 0x3FFF_FFFF)


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 8.0, unit="ns").start())
        self.axil = AxiLiteMaster(
            AxiLiteBus.from_prefix(dut, "S_AXI"),
            dut.AXIS_ACLK,
            dut.AXIS_ARESETN,
            reset_active_level=False,
        )
        self.axis = FlatSrpAxis(dut, clk=dut.AXIS_ACLK, data_bytes=16)

    async def reset(self):
        # Initialize both stream directions before releasing reset so the
        # bridge cannot observe unknown ready/valid inputs.
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        self.axis.init_source()
        self.axis.init_sink()
        for _ in range(12):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(12):
            await RisingEdge(self.dut.AXIS_ACLK)

    async def send_response(self, words: list[int], *, last: int = 1, tkeep: int = 0xFFFF, sof: int = 0x2):
        # The direct wrapper uses a 16-byte stream so one SRPv0 response beat
        # carries the complete four-word legacy frame.
        data = 0
        for index, word in enumerate(words):
            data |= (word & 0xFFFF_FFFF) << (32 * index)

        self.dut.S_AXIS_TVALID.value = 1
        self.dut.S_AXIS_TDATA.value = data
        self.dut.S_AXIS_TKEEP.value = tkeep
        self.dut.S_AXIS_TLAST.value = last
        self.dut.S_AXIS_TUSER.value = sof
        await wait_sampled_ready(self.dut.S_AXIS_TREADY, clk=self.dut.AXIS_ACLK)
        self.dut.S_AXIS_TVALID.value = 0
        self.dut.S_AXIS_TLAST.value = 0
        self.dut.S_AXIS_TUSER.value = 0


async def recv_request(tb: TB) -> list[int]:
    response = await tb.axis.recv_response()
    assert response.tkeep == [0xF, 0xF, 0xF, 0xF]
    assert response.tuser[0] & 0x2 == 0x2
    return response.words


@cocotb.test()
async def axilite_srpv0_write_read_translation_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A write must become one SRPv0 request word bundle and complete only after
    # the matching echoed response returns.
    write_address = 0x014
    write_data = 0x1234_ABCD
    write_task = cocotb.start_soon(tb.axil.write(write_address, write_data.to_bytes(4, "little")))
    write_request = await recv_request(tb)
    assert write_request == [
        0,
        srpv0_addr_word(SRPV0_WRITE, write_address),
        write_data,
        0,
    ]
    await tb.send_response(write_request)
    write_txn = await write_task
    assert write_txn.resp == AxiResp.OKAY

    # The next transaction count is visible in the stream frame, and read data
    # is taken from the third response word.
    read_address = 0x028
    read_data = 0xDEAD_BEEF
    read_task = cocotb.start_soon(tb.axil.read(read_address, 4))
    read_request = await recv_request(tb)
    assert read_request == [
        1,
        srpv0_addr_word(SRPV0_READ, read_address),
        0,
        0,
    ]
    await tb.send_response([read_request[0], read_request[1], read_data, 0])
    read_txn = await read_task
    assert read_txn.resp == AxiResp.OKAY
    assert read_txn.data == read_data.to_bytes(4, "little")


@cocotb.test()
async def axilite_srpv0_bad_response_recovery_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A response whose echoed data does not match the outstanding write must be
    # rejected as an AXI-Lite error.
    bad_task = cocotb.start_soon(tb.axil.write(0x030, (0xA5A5_5A5A).to_bytes(4, "little")))
    bad_request = await recv_request(tb)
    await tb.send_response([bad_request[0], bad_request[1], 0xFFFF_0000, 0])
    bad_txn = await bad_task
    assert bad_txn.resp == AxiResp.SLVERR

    # A non-terminal response beat forces the DUT through its bleed state. The
    # trailing beat drains that bad frame, then a normal read proves recovery.
    bleed_task = cocotb.start_soon(tb.axil.read(0x034, 4))
    bleed_request = await recv_request(tb)
    await tb.send_response([bleed_request[0], bleed_request[1], 0x1111_2222, 0], last=0)
    await tb.send_response([0, 0, 0, 0])
    bleed_txn = await bleed_task
    assert bleed_txn.resp == AxiResp.SLVERR

    recovery_task = cocotb.start_soon(tb.axil.read(0x038, 4))
    recovery_request = await recv_request(tb)
    await tb.send_response([recovery_request[0], recovery_request[1], 0xCAFE_BABE, 0])
    recovery_txn = await recovery_task
    assert recovery_txn.resp == AxiResp.OKAY
    assert recovery_txn.data == (0xCAFE_BABE).to_bytes(4, "little")


@pytest.mark.parametrize("parameters", [pytest.param({}, id="direct")])
def test_AxiLiteSrpV0(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitesrpv0wrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/srp/wrappers/AxiLiteSrpV0Wrapper.vhd"]},
    )
