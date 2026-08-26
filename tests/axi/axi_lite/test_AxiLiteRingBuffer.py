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
# - Sweep: Keep one stable lockstep-clock 32-bit capture configuration so the
#   bench proves the externally visible ring-buffer behavior without expanding
#   into the broader generic matrix yet.
# - Stimulus: Enable capture through the external control pins, push a short
#   sample stream past the initial empty state, then clear the buffer again.
# - Checks: The control register must report the configured depth field, the
#   enabled state, the observed buffered length, the readable sample order, and
#   the post-clear empty state.
# - Timing: The bench performs AXI-Lite reads with the DUT's real RAM-read
#   latency in mind instead of assuming an immediate same-cycle sample return.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut

        # Drive the data and AXI-Lite domains from the same coroutine because
        # this wrapper is intentionally proving the true common-clock path.
        start_lockstep_clocks(dut.dataClk, dut.axilClk, period_ns=5.0)

        dut.dataRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.dataValid.setimmediatevalue(0)
        dut.dataValue.setimmediatevalue(0)
        dut.bufferEnable.setimmediatevalue(0)
        dut.bufferClear.setimmediatevalue(0)

        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.axilClk, dut.axilRst)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Return both domains and the external control pins to a known idle
        # state before exercising any capture or readout behavior.
        self.dut.dataRst.value = 1
        self.dut.axilRst.value = 1
        self.dut.dataValid.value = 0
        self.dut.bufferEnable.value = 0
        self.dut.bufferClear.value = 0
        await self.cycle(4)
        self.dut.dataRst.value = 0
        self.dut.axilRst.value = 0
        await self.cycle(6)

    async def read_reg(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def read_sample(self, address: int) -> int:
        # The DUT pipelines RAM-backed sample reads, so the first access arms
        # the returned data and the second access collects the stable word.
        await self.read_reg(address)
        return await self.read_reg(address)

    async def push_value(self, value: int):
        self.dut.dataValue.value = value
        self.dut.dataValid.value = 1
        await self.cycle(1)
        self.dut.dataValid.value = 0
        await self.cycle(1)


@cocotb.test()
async def capture_readout_and_clear_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The empty control register still reports the configured RAM address width
    # in bits [27:20], so the reset value is not all-zero.
    assert await tb.read_reg(0x00) == (4 << 20)

    # Enable capture through the DUT's external control path and confirm the
    # synchronized status bit reflects that the data-side path is running.
    tb.dut.bufferEnable.value = 1
    await tb.cycle(6)

    control = await tb.read_reg(0x00)
    assert ((control >> 29) & 0x1) == 1

    samples = [0x10, 0x21, 0x32, 0x43, 0x54, 0x65]
    for sample in samples:
        await tb.push_value(sample)

    await tb.cycle(6)

    # After several pushes, the length field should expose the currently
    # readable window depth and the sample window should preserve order.
    control = await tb.read_reg(0x00)
    assert (control & 0xF) == 5

    observed = [await tb.read_sample(0x08 + (index * 4)) for index in range(4)]
    assert observed == samples[:4]

    # Clearing through the external control path should flush the visible
    # buffer length back to zero.
    tb.dut.bufferClear.value = 1
    await tb.cycle(2)
    tb.dut.bufferClear.value = 0
    await tb.cycle(6)
    assert (await tb.read_reg(0x00) & 0xF) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="lockstep_32bit")])
def test_AxiLiteRingBuffer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiliteringbufferipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
