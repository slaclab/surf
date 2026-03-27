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
# - Sweep: Keep one two-buffer ring-write wrapper and configure only buffer
#   zero, which is enough to prove the write-side pointer/state machine path.
# - Stimulus: Program buffer-zero AXI-Lite registers, send one frame on the
#   data stream, and capture the emitted completion status frame.
# - Checks: The AXI memory write must land at the configured start address, the
#   status frame must report buffer zero, and the exported buffer flags must
#   mark the buffer as done and triggered.
# - Timing: The bench waits for the downstream status stream instead of
#   assuming a fixed number of internal pointer, RAM, and DMA cycles.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp, AxiRamWrite, AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource, AxiWriteBus

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


def get_buffer_addr(bus_index: int, buf: int = 0, high: int = 0) -> int:
    if bus_index in (4, 5):
        return (bus_index << 9) | (buf << 2)
    return (bus_index << 9) | (buf << 3) | (high << 2)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        self.source = None
        self.status_sink = None
        self.ram = None

        start_lockstep_clocks(dut.axilClk, dut.axisStatusClk, dut.axiClk, period_ns=5.0)
        dut.axilRst.setimmediatevalue(1)
        dut.axisStatusRst.setimmediatevalue(1)
        dut.axiRst.setimmediatevalue(1)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axilRst.value = 1
        self.dut.axisStatusRst.value = 1
        self.dut.axiRst.value = 1
        await self.cycle(4)
        self.dut.axilRst.value = 0
        self.dut.axisStatusRst.value = 0
        self.dut.axiRst.value = 0
        await self.cycle(6)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axilClk, self.dut.axilRst)
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.axiClk, self.dut.axiRst)
        if self.status_sink is None:
            self.status_sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_STATUS"), self.dut.axisStatusClk, self.dut.axisStatusRst)
        if self.ram is None:
            self.ram = AxiRamWrite(AxiWriteBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**16)

    async def write_reg(self, address: int, value: int):
        txn = await self.axil.write(address, value.to_bytes(4, "little"))
        assert txn.resp == AxiResp.OKAY

    async def wait_until(self, predicate, cycles: int = 64):
        for _ in range(cycles):
            if predicate():
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for DUT state to settle")


@cocotb.test()
async def configured_buffer_capture_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    await tb.write_reg(get_buffer_addr(0, 0, 0), 0x20)
    await tb.write_reg(get_buffer_addr(0, 0, 1), 0x00)
    await tb.write_reg(get_buffer_addr(1, 0, 0), 0x40)
    await tb.write_reg(get_buffer_addr(1, 0, 1), 0x00)
    # Initialize the active write pointer from the programmed start address and
    # arm a software trigger so the first stored frame completes the buffer.
    await tb.write_reg(get_buffer_addr(4, 0, 0), 0x0C)
    await tb.wait_until(lambda: (int(dut.bufferDone.value) & 0x1) == 0)

    frame = AxiStreamFrame(bytes(range(0x10, 0x20)))
    frame.tdest = 0
    frame.tuser = [0x0] * len(frame.tdata)
    await tb.source.send(frame)

    status = await with_timeout(tb.status_sink.recv(), 5, "us")

    assert tb.ram.read(0x20, 16) == bytes(range(0x10, 0x20))
    assert bytes(status.tdata) == b"\x00"
    assert int(dut.bufferDone.value) & 0x1
    assert int(dut.bufferTriggered.value) & 0x1


@pytest.mark.parametrize("parameters", [pytest.param({}, id="buffer0_capture_done")])
def test_AxiStreamDmaRingWrite(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmaringwriteipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/SlaveAxiStreamIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/MasterAxiStreamIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaRingWriteIpIntegrator.vhd",
            ],
        },
    )
