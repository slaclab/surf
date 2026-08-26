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
# - Sweep: Keep a two-case control-plane sweep covering synchronous active-high
#   reset and asynchronous active-low reset while holding the AXI-Lite slave
#   model behavior otherwise fixed.
# - Stimulus: Drive request/ack transactions directly into the flattened
#   `AxiLiteReqType` interface, respond from a small cocotb AXI-Lite slave
#   model with staggered ready/valid handshakes, and then return explicit
#   error responses from that model.
# - Checks: Writes must update the slave model memory with full strobes,
#   reads must return the stored word, `SLVERR` responses must propagate into
#   the ack record, and reset must return the DUT outputs to the idle state.
# - Timing: The bench forces separate address/data/response delays on the AXI
#   side so the DUT state machine has to step through its write and read
#   phases instead of seeing zero-latency handshakes.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import cancel_and_join_tasks, sample_after_tpd
from cocotbext.axi import AxiResp

from tests.common.regression_utils import env_sl, parameter_case, run_surf_vhdl_test


class SimpleAxiLiteSlave:
    def __init__(self, dut, reset_active):
        self.dut = dut
        self.reset_active = reset_active
        self.mem = {}
        self.read_resp = AxiResp.OKAY
        self.write_resp = AxiResp.OKAY
        self.last_write = None
        self.last_read = None

        dut.M_AXI_AWREADY.setimmediatevalue(0)
        dut.M_AXI_WREADY.setimmediatevalue(0)
        dut.M_AXI_BVALID.setimmediatevalue(0)
        dut.M_AXI_BRESP.setimmediatevalue(0)
        dut.M_AXI_ARREADY.setimmediatevalue(0)
        dut.M_AXI_RVALID.setimmediatevalue(0)
        dut.M_AXI_RRESP.setimmediatevalue(0)
        dut.M_AXI_RDATA.setimmediatevalue(0)

        # The read/write responders are lifetime protocol peers owned by TB.
        self._responder_tasks = (
            cocotb.start_soon(self._run_write()),
            cocotb.start_soon(self._run_read()),
        )

    async def close(self) -> None:
        await cancel_and_join_tasks(self._responder_tasks)

    def in_reset(self) -> bool:
        try:
            return int(self.dut.axilRst.value) == self.reset_active
        except ValueError:
            return True

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axilClk)

    async def _wait_while_reset(self):
        while self.in_reset():
            self.dut.M_AXI_AWREADY.value = 0
            self.dut.M_AXI_WREADY.value = 0
            self.dut.M_AXI_BVALID.value = 0
            self.dut.M_AXI_ARREADY.value = 0
            self.dut.M_AXI_RVALID.value = 0
            await self.cycle(1)

    async def _run_write(self):
        """Lifetime agent: respond to AXI-Lite writes until the test ends."""
        while True:
            await self._wait_while_reset()

            while not int(self.dut.M_AXI_AWVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            await self.cycle(1)
            awaddr = int(self.dut.M_AXI_AWADDR.value)
            awprot = int(self.dut.M_AXI_AWPROT.value)
            self.dut.M_AXI_AWREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_AWREADY.value = 0

            while not int(self.dut.M_AXI_WVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            await self.cycle(2)
            wdata = int(self.dut.M_AXI_WDATA.value)
            wstrb = int(self.dut.M_AXI_WSTRB.value)
            self.last_write = (awaddr, wdata, wstrb, awprot)

            if self.write_resp == AxiResp.OKAY:
                prior = self.mem.get(awaddr, 0).to_bytes(4, "little")
                next_bytes = bytearray(prior)
                write_bytes = wdata.to_bytes(4, "little")
                for index in range(4):
                    if wstrb & (1 << index):
                        next_bytes[index] = write_bytes[index]
                self.mem[awaddr] = int.from_bytes(next_bytes, "little")

            self.dut.M_AXI_WREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_WREADY.value = 0

            await self.cycle(1)
            self.dut.M_AXI_BRESP.value = int(self.write_resp)
            self.dut.M_AXI_BVALID.value = 1
            while not int(self.dut.M_AXI_BREADY.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)
            await self.cycle(1)
            self.dut.M_AXI_BVALID.value = 0

    async def _run_read(self):
        """Lifetime agent: respond to AXI-Lite reads until the test ends."""
        while True:
            await self._wait_while_reset()

            while not int(self.dut.M_AXI_ARVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            await self.cycle(2)
            araddr = int(self.dut.M_AXI_ARADDR.value)
            arprot = int(self.dut.M_AXI_ARPROT.value)
            self.last_read = (araddr, arprot)
            self.dut.M_AXI_ARREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_ARREADY.value = 0

            await self.cycle(1)
            self.dut.M_AXI_RDATA.value = self.mem.get(araddr, 0)
            self.dut.M_AXI_RRESP.value = int(self.read_resp)
            self.dut.M_AXI_RVALID.value = 1
            while not int(self.dut.M_AXI_RREADY.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)
            await self.cycle(1)
            self.dut.M_AXI_RVALID.value = 0


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.reset_active = env_sl("RST_POLARITY_G", default=1)

        cocotb.start_soon(Clock(dut.axilClk, 5.0, unit="ns").start())

        dut.axilRst.setimmediatevalue(self.reset_active_value())
        dut.reqRequest.setimmediatevalue(0)
        dut.reqRnw.setimmediatevalue(1)
        dut.reqAddress.setimmediatevalue(0)
        dut.reqWrData.setimmediatevalue(0)

        self.slave = SimpleAxiLiteSlave(dut, self.reset_active)

    async def close(self) -> None:
        await self.slave.close()

    def reset_active_value(self) -> int:
        return self.reset_active

    def reset_inactive_value(self) -> int:
        return 1 - self.reset_active

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axilClk)

    async def reset(self):
        # Drive reset and hold the request inputs idle so the state machine
        # restarts from its initial request/ack handshake contract.
        self.dut.axilRst.setimmediatevalue(self.reset_active_value())
        self.dut.reqRequest.value = 0
        await self.cycle(3)
        self.dut.axilRst.value = self.reset_inactive_value()
        await self.cycle(3)

    async def issue_request(self, *, rnw: bool, address: int, wr_data: int = 0):
        # Present one request until the DUT raises `ack.done`, then drop the
        # request so the DUT clears the sticky ack before the next command.
        self.dut.reqRnw.value = int(rnw)
        self.dut.reqAddress.value = address
        self.dut.reqWrData.value = wr_data
        self.dut.reqRequest.value = 1

        for _ in range(40):
            await self.cycle(1)
            if int(self.dut.ackDone.value):
                break
        else:
            raise AssertionError("Timed out waiting for AxiLiteMaster ack")

        ack_resp = int(self.dut.ackResp.value)
        ack_data = int(self.dut.ackRdData.value)

        self.dut.reqRequest.value = 0
        await self.cycle(2)
        assert int(self.dut.ackDone.value) == 0
        return ack_resp, ack_data


@cocotb.test()
async def write_read_round_trip_test(dut):
    tb = TB(dut)
    try:
        await tb.reset()

        ack_resp, _ = await tb.issue_request(rnw=False, address=0x24, wr_data=0x11223344)
        assert ack_resp == int(AxiResp.OKAY)
        assert tb.slave.mem[0x24] == 0x11223344
        assert tb.slave.last_write == (0x24, 0x11223344, 0xF, 0)

        ack_resp, ack_data = await tb.issue_request(rnw=True, address=0x24)
        assert ack_resp == int(AxiResp.OKAY)
        assert ack_data == 0x11223344
        assert tb.slave.last_read == (0x24, 0)
    finally:
        await tb.close()


@cocotb.test()
async def error_and_idle_reset_test(dut):
    tb = TB(dut)
    try:
        await tb.reset()

        tb.slave.mem[0x40] = 0xCAFEBABE
        tb.slave.write_resp = AxiResp.SLVERR
        tb.slave.read_resp = AxiResp.SLVERR

        ack_resp, _ = await tb.issue_request(
            rnw=False,
            address=0x40,
            wr_data=0xDEADBEEF,
        )
        assert ack_resp == int(AxiResp.SLVERR)
        assert tb.slave.mem[0x40] == 0xCAFEBABE

        ack_resp, ack_data = await tb.issue_request(rnw=True, address=0x40)
        assert ack_resp == int(AxiResp.SLVERR)
        assert ack_data == 0xCAFEBABE

        # Reassert reset after the error path so the test proves the DUT
        # returns its request and ack outputs to the idle state cleanly.
        tb.dut.axilRst.value = tb.reset_active_value()
        await tb.cycle(2)
        assert int(tb.dut.ackDone.value) == 0
        assert int(tb.dut.M_AXI_AWVALID.value) == 0
        assert int(tb.dut.M_AXI_WVALID.value) == 0
        assert int(tb.dut.M_AXI_ARVALID.value) == 0
        assert int(tb.dut.M_AXI_BREADY.value) == 1
        assert int(tb.dut.M_AXI_RREADY.value) == 1
    finally:
        await tb.close()


PARAMETER_SWEEP = [
    parameter_case(
        "sync_active_high",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
    ),
    parameter_case(
        "async_active_low",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiLiteMaster(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitemasteripintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
