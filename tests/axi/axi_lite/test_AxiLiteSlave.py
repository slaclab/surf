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
# - Sweep: Keep a two-case handshake sweep covering synchronous active-high and
#   asynchronous active-low reset while holding the req/ack timing otherwise
#   fixed.
# - Stimulus: Drive AXI-Lite writes and reads into the wrapper, observe the
#   flattened req bus directly, and return ack pulses with both `OKAY` and
#   `SLVERR` responses from cocotb.
# - Checks: Writes must produce `rnw=0` plus the write address/data, reads must
#   produce `rnw=1` and forward `ackRdData` back onto AXI-Lite, error acks must
#   map to `SLVERR`, and reset must clear the exported req pulse.
# - Timing: The bench inserts a bounded two-cycle ack delay so the DUT has to
#   hold its req state until the explicit completion pulse arrives.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import env_sl, parameter_case, run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.reset_active = env_sl("RST_POLARITY_G", default=1)

        cocotb.start_soon(Clock(dut.axilClk, 5.0, unit="ns").start())

        dut.axilRst.setimmediatevalue(self.reset_active_value())
        dut.ackDone.setimmediatevalue(0)
        dut.ackResp.setimmediatevalue(0)
        dut.ackRdData.setimmediatevalue(0)

        self.axil = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
            clock=dut.axilClk,
            reset=dut.axilRst,
            reset_active_level=bool(self.reset_active),
        )

    def reset_active_value(self) -> int:
        return self.reset_active

    def reset_inactive_value(self) -> int:
        return 1 - self.reset_active

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axilRst.setimmediatevalue(self.reset_active_value())
        self.dut.ackDone.value = 0
        await self.cycle(3)
        self.dut.axilRst.value = self.reset_inactive_value()
        await self.cycle(3)

    async def ack_request(self, *, resp: int, rd_data: int = 0):
        for _ in range(32):
            if int(self.dut.reqRequest.value):
                break
            await self.cycle(1)
        else:
            raise AssertionError("Timed out waiting for req.request")

        request = {
            "rnw": int(self.dut.reqRnw.value),
            "address": int(self.dut.reqAddress.value),
            "wr_data": int(self.dut.reqWrData.value),
        }

        await self.cycle(2)
        self.dut.ackResp.value = resp
        self.dut.ackRdData.value = rd_data
        self.dut.ackDone.value = 1
        await self.cycle(1)
        self.dut.ackDone.value = 0
        return request


@cocotb.test()
async def write_and_read_translation_test(dut):
    tb = TB(dut)
    await tb.reset()

    write_task = cocotb.start_soon(tb.axil.write(0x24, b"\x44\x33\x22\x11"))
    write_req = await tb.ack_request(resp=0)
    write_txn = await write_task
    assert write_txn.resp == AxiResp.OKAY
    assert write_req == {"rnw": 0, "address": 0x24, "wr_data": 0x11223344}

    read_task = cocotb.start_soon(tb.axil.read(0x28, 4))
    read_req = await tb.ack_request(resp=0, rd_data=0xCAFEBABE)
    read_txn = await read_task
    assert read_txn.resp == AxiResp.OKAY
    assert read_txn.data == b"\xBE\xBA\xFE\xCA"
    assert read_req["rnw"] == 1
    assert read_req["address"] == 0x28


@cocotb.test()
async def error_response_and_reset_test(dut):
    tb = TB(dut)
    await tb.reset()

    write_task = cocotb.start_soon(tb.axil.write(0x30, b"\xAA\x55\x00\x00"))
    await tb.ack_request(resp=1)
    write_txn = await write_task
    assert write_txn.resp == AxiResp.SLVERR

    tb.dut.axilRst.value = tb.reset_active_value()
    await tb.cycle(2)
    assert int(tb.dut.reqRequest.value) == 0
    tb.dut.axilRst.value = tb.reset_inactive_value()
    await tb.cycle(2)


PARAMETER_SWEEP = [
    parameter_case("sync_active_high", RST_ASYNC_G="false", RST_POLARITY_G="'1'"),
    parameter_case("async_active_low", RST_ASYNC_G="true", RST_POLARITY_G="'0'"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiLiteSlave(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiliteslaveipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
