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
# - Sweep: Keep one single-pop plus single-loop FIFO wrapper configuration on
#   the stable synchronous path so the first pass proves both mapped spaces.
# - Stimulus: Seed the exported pop FIFO with one word, read it through the
#   AXI-Lite pop address space, then exercise the loop FIFO write/read region.
# - Checks: The pop path must consume the queued word, the loop path must store
#   and return the written value, and the visible valid flag must drop after
#   the pop transaction completes.
# - Timing: The bench waits for the exported FIFO-valid state and leaves a few
#   cycles after the pop so the DUT can retire the consumed entry normally.

import cocotb
import pytest

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut

        # Use shared edges across the AXI-Lite and exposed FIFO clocks because
        # this wrapper intentionally stays on the synchronous stable subset.
        start_lockstep_clocks(dut.axiClk, dut.popFifoClk, period_ns=5.0)
        dut.axiClkRst.setimmediatevalue(1)
        dut.popFifoRst.setimmediatevalue(1)
        dut.popFifoWrite.setimmediatevalue(0)
        dut.popFifoDin.setimmediatevalue(0)

        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.axiClk, dut.axiClkRst)

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axiClk)

    async def reset(self):
        # Reset the AXI-Lite side and the exposed FIFO interface together so
        # the first observed valid state belongs to bench-driven stimulus only.
        self.dut.axiClkRst.value = 1
        self.dut.popFifoRst.value = 1
        self.dut.popFifoWrite.value = 0
        await self.cycle(4)
        self.dut.axiClkRst.value = 0
        self.dut.popFifoRst.value = 0
        await self.cycle(4)

    async def push_pop_fifo(self, value: int):
        # Drive one external FIFO write into the DUT and then give the internal
        # bookkeeping a few cycles to present it to the AXI-Lite pop path.
        self.dut.popFifoDin.value = value
        self.dut.popFifoWrite.value = 1
        await self.cycle(1)
        self.dut.popFifoWrite.value = 0
        await self.cycle(3)

    async def axil_read(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def axil_write(self, address: int, value: int):
        txn = await self.axil.write(address, value.to_bytes(4, "little"))
        assert txn.resp == AxiResp.OKAY


@cocotb.test()
async def pop_and_loop_fifo_access_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Seed the exported pop FIFO and confirm the DUT advertises a readable
    # entry before attempting the AXI-Lite-side dequeue.
    await tb.push_pop_fifo(0x13579BDF)
    assert int(dut.popFifoValid.value) == 1

    pop_value = await tb.axil_read(0x00)
    await tb.cycle(3)

    # The loop FIFO address space should behave like a stored write/read path
    # that is separate from the consumed pop FIFO entry above.
    await tb.axil_write(0x100, 0x2468ACE0)
    loop_value = await tb.axil_read(0x100)

    # Bit 0 is overlaid with the valid-status convention in this DUT, so the
    # observed returned payload intentionally differs from the raw seeded word.
    assert pop_value == (0x13579BDF & ~0x1)
    assert int(dut.popFifoValid.value) == 0
    assert loop_value == 0x2468ACE0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="single_pop_and_loop")])
def test_AxiLiteFifoPop(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitefifopopipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
