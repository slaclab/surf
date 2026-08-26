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
# - Sweep: Keep one single-push-FIFO wrapper configuration with synchronous
#   FIFO crossing so the first pass proves the software-visible address/data
#   packing contract without broad parameter variation.
# - Stimulus: Perform AXI-Lite writes to two mapped addresses and then consume
#   the emitted push FIFO words from the external FIFO interface.
# - Checks: Each emitted 36-bit word must preserve the written payload and
#   encode the AXI-Lite word-address nibble in the upper bits.
# - Timing: The bench waits on the real external FIFO valid/read handshake
#   rather than assuming the push side drains immediately after each write.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut

        # The wrapper is validating the common-clock-style stable path between
        # the AXI-Lite domain and the exposed push FIFO port.
        start_lockstep_clocks(dut.axiClk, dut.pushFifoClk, period_ns=5.0)
        dut.axiClkRst.setimmediatevalue(1)
        dut.pushFifoRst.setimmediatevalue(1)
        dut.pushFifoRead.setimmediatevalue(0)

        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.axiClk, dut.axiClkRst)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Hold both the AXI-Lite and push FIFO sides in reset long enough for
        # the DUT and shim layers to return to the idle state.
        self.dut.axiClkRst.value = 1
        self.dut.pushFifoRst.value = 1
        self.dut.pushFifoRead.value = 0
        await self.cycle(4)
        self.dut.axiClkRst.value = 0
        self.dut.pushFifoRst.value = 0
        await self.cycle(4)

    async def write_word(self, address: int, value: int):
        txn = await self.axil.write(address, value.to_bytes(4, "little"))
        assert txn.resp == AxiResp.OKAY

    async def read_status(self) -> int:
        txn = await self.axil.read(0x00, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def pop_word(self) -> int:
        # Poll the exported FIFO-valid flag and only assert read when the DUT
        # has produced a complete packed word for the external consumer.
        for _ in range(20):
            if int(self.dut.pushFifoValid.value):
                value = int(self.dut.pushFifoDout.value)
                self.dut.pushFifoRead.value = 1
                await self.cycle(1)
                self.dut.pushFifoRead.value = 0
                await self.cycle(1)
                return value
            await self.cycle(1)
        raise AssertionError("Timed out waiting for pushed FIFO word")


@cocotb.test()
async def push_fifo_write_and_pop_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Two writes at different AXI-Lite offsets should appear as two packed FIFO
    # words with the low address nibble preserved in bits [35:32].
    await tb.write_word(0x00, 0x11223344)
    await tb.write_word(0x0C, 0x55667788)

    first = await tb.pop_word()
    second = await tb.pop_word()
    status = await tb.read_status()

    # The status register should report no stuck-full condition after both
    # words have been drained from the exported FIFO lane.
    assert first == ((0x0 << 32) | 0x11223344)
    assert second == ((0x3 << 32) | 0x55667788)
    assert (status & 0x3) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="single_push_fifo")])
def test_AxiLiteFifoPush(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitefifopushipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
