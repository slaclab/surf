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
# - Sweep: Keep one common-clock 32-bit in/32-bit out configuration so the
#   bench isolates the batching behavior from width-conversion side effects.
# - Stimulus: Program the batch threshold over AXI-Lite, send one frame and
#   confirm it stays buffered, then send a second frame and drain the output.
# - Checks: The AXI-Lite register must retain the configured threshold and the
#   two output frames must emerge in order only after the threshold is reached.
# - Timing: The bench waits on the real AXI-Stream sink activity instead of
#   assuming a fixed number of cycles between the second input and first output.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        self.source = None
        self.sink = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axiRst.value = 1
        await self.cycle(4)
        self.dut.axiRst.value = 0
        await self.cycle(4)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axiClk, self.dut.axiRst)
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.axiClk, self.dut.axiRst)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axiClk, self.dut.axiRst)

    async def read_reg(self, address: int) -> int:
        return await axil_read_u32(self.axil, address)

    async def write_reg(self, address: int, value: int):
        await axil_write_u32(self.axil, address, value)


@cocotb.test()
async def threshold_controls_release_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await tb.write_reg(0x0, 2)
    assert await tb.read_reg(0x0) == 2

    await tb.source.send(AxiStreamFrame(b"\x10\x11\x12\x13"))
    await tb.cycle(8)
    assert tb.sink.empty()

    await tb.source.send(AxiStreamFrame(b"\x20\x21\x22\x23"))
    first = await with_timeout(tb.sink.recv(), 2, "us")
    second = await with_timeout(tb.sink.recv(), 2, "us")

    assert bytes(first.tdata) == b"\x10\x11\x12\x13"
    assert bytes(second.tdata) == b"\x20\x21\x22\x23"


@pytest.mark.parametrize("parameters", [pytest.param({}, id="two_frame_threshold")])
def test_AxiStreamBatchingFifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreambatchingfifoipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/SlaveAxiStreamIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/MasterAxiStreamIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/AxiStreamBatchingFifoIpIntegrator.vhd",
            ],
        },
    )
