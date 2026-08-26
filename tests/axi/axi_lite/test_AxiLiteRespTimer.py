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
# - Sweep: Keep a two-case control sweep covering synchronous active-high reset
#   and asynchronous active-low reset while exercising the same delayed-write
#   and read-error behavior in both cases.
# - Stimulus: Launch AXI-Lite writes with different timer payloads, count the
#   destination clocks until each write returns, issue an unsupported read, and
#   then reassert reset before a final zero-delay write.
# - Checks: Larger timer payloads must take measurably longer to acknowledge
#   than zero-delay writes, reads must return `DECERR`, and reset must return
#   the endpoint to a state where a new short write completes cleanly.
# - Timing: The bench measures completion in destination clock cycles rather
#   than absolute simulator time so the assertions stay tied to the RTL timer
#   behavior instead of event-loop scheduling noise.

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
        await self.cycle(3)
        self.dut.axilRst.value = self.reset_inactive_value()
        await self.cycle(3)

    async def measure_write_cycles(self, timer_value: int) -> int:
        task = cocotb.start_soon(self.axil.write(0x0, timer_value.to_bytes(4, "little")))
        cycles = 0
        while not task.done():
            await self.cycle(1)
            cycles += 1
            if cycles > 64:
                raise AssertionError("Timed out waiting for delayed AXI-Lite response")
        txn = await task
        assert txn.resp == AxiResp.OKAY
        return cycles


@cocotb.test()
async def delayed_write_response_test(dut):
    tb = TB(dut)
    await tb.reset()

    short_cycles = await tb.measure_write_cycles(0)
    long_cycles = await tb.measure_write_cycles(3)

    assert short_cycles >= 1
    assert long_cycles >= short_cycles + 2


@cocotb.test()
async def read_error_and_reset_recovery_test(dut):
    tb = TB(dut)
    await tb.reset()

    rd_txn = await tb.axil.read(0x0, 4)
    assert rd_txn.resp == AxiResp.DECERR

    await tb.measure_write_cycles(2)

    tb.dut.axilRst.value = tb.reset_active_value()
    await tb.cycle(3)
    tb.dut.axilRst.value = tb.reset_inactive_value()
    await tb.cycle(3)

    recovery_cycles = await tb.measure_write_cycles(0)
    assert recovery_cycles >= 1


PARAMETER_SWEEP = [
    parameter_case("sync_active_high", RST_ASYNC_G="false", RST_POLARITY_G="'1'"),
    parameter_case("async_active_low", RST_ASYNC_G="true", RST_POLARITY_G="'0'"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiLiteRespTimer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiliteresptimeripintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
