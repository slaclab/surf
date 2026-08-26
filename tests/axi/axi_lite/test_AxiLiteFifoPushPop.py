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
# - Sweep: Keep one stable single-pop, single-loop, single-exposed-push view of
#   the wrapper even though the internal push side is widened to a power-of-two
#   count to avoid the DUT's current elaboration bug.
# - Stimulus: Seed one pop word, access the loop FIFO region, write into the
#   push region, and drain the exported push FIFO word through its handshake.
# - Checks: The pop and loop reads must return the expected data shape, and the
#   push path must emit the expected packed address/data word.
# - Timing: The bench waits on the real loop-valid and push-valid signals so
#   the wrapper is checked through the DUT's actual FIFO retirement behavior.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut

        # Keep all three exposed clocks on true shared edges because this bench
        # is intentionally exercising the synchronous stable subset only.
        start_lockstep_clocks(dut.axiClk, dut.popFifoClk, dut.pushFifoClk, period_ns=5.0)
        dut.axiClkRst.setimmediatevalue(1)
        dut.popFifoRst.setimmediatevalue(1)
        dut.pushFifoRst.setimmediatevalue(1)
        dut.popFifoWrite.setimmediatevalue(0)
        dut.popFifoDin.setimmediatevalue(0)
        dut.pushFifoRead.setimmediatevalue(0)

        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.axiClk, dut.axiClkRst)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Reset all visible domains together before any descriptor-style FIFO
        # traffic is launched into the combined push/pop wrapper.
        self.dut.axiClkRst.value = 1
        self.dut.popFifoRst.value = 1
        self.dut.pushFifoRst.value = 1
        await self.cycle(4)
        self.dut.axiClkRst.value = 0
        self.dut.popFifoRst.value = 0
        self.dut.pushFifoRst.value = 0
        await self.cycle(4)

    async def axil_read(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def axil_write(self, address: int, value: int):
        txn = await self.axil.write(address, value.to_bytes(4, "little"))
        assert txn.resp == AxiResp.OKAY

    async def seed_pop_fifo(self, value: int):
        # Present one word on the exported pop FIFO interface and wait for the
        # DUT to make it visible to the AXI-Lite pop address space.
        self.dut.popFifoDin.value = value
        self.dut.popFifoWrite.value = 1
        await self.cycle(1)
        self.dut.popFifoWrite.value = 0
        await self.cycle(3)

    async def pop_push_fifo(self) -> int:
        # Drain the exposed push FIFO only after the DUT marks the packed word
        # valid, preserving the external consumer handshake behavior.
        for _ in range(20):
            if int(self.dut.pushFifoValid.value):
                value = int(self.dut.pushFifoDout.value)
                self.dut.pushFifoRead.value = 1
                await self.cycle(1)
                self.dut.pushFifoRead.value = 0
                await self.cycle(1)
                return value
            await self.cycle(1)
        raise AssertionError("Timed out waiting for pushed FIFO data")

    async def wait_loop_valid(self):
        # The loop FIFO behaves like a real FIFO-backed storage path, so wait
        # until the DUT reports valid data before reading the mapped word back.
        for _ in range(20):
            if int(self.dut.loopFifoValid.value):
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for loop FIFO data")


@cocotb.test()
async def combined_pop_loop_and_push_spaces_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Exercise the pop path first so the bench proves the wrapper still
    # exposes the dequeue side correctly alongside the loop and push regions.
    await tb.seed_pop_fifo(0x12345678)
    pop_value = await tb.axil_read(0x00)

    # Then fill and read back the loop FIFO region through the mapped address
    # space, waiting for the DUT to advertise valid loop data.
    await tb.axil_write(0x100, 0x89ABCDEF)
    await tb.wait_loop_valid()
    loop_value = await tb.axil_read(0x100)

    # Finally, drive the push address space and confirm the external push FIFO
    # sees the packed address nibble plus payload word.
    await tb.axil_write(0x20C, 0xCAFEBABE)
    pushed = await tb.pop_push_fifo()

    # As with the standalone pop/loop bench, bit 0 is overlaid with the DUT's
    # valid-bit convention on the readable FIFO-backed spaces.
    assert pop_value == (0x12345678 & ~0x1)
    assert loop_value == (0x89ABCDEF & ~0x1)
    assert pushed == ((0x3 << 32) | 0xCAFEBABE)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="single_pop_loop_push")])
def test_AxiLiteFifoPushPop(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitefifopushpopipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
