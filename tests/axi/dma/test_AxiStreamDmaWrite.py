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
# - Sweep: Keep one 64-bit direct-request wrapper instance around the v1 DMA
#   write engine so the bench can prove the standalone payload path.
# - Stimulus: Assert one DMA request, send one AXI-Stream frame with `tdest`
#   and `tid`, and capture the downstream AXI write traffic in RAM.
# - Checks: The written bytes and returned DMA-ack metadata must match the
#   requested destination, id, and payload size without write errors.
# - Timing: The test holds the DMA request high until the DUT reports `done`,
#   which exercises the normal request/ack sequencing instead of a one-cycle
#   pulse shortcut.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiRamWrite, AxiWriteBus, AxiStreamBus, AxiStreamFrame, AxiStreamSource

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = None
        self.ram = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.dmaReqRequest.setimmediatevalue(0)
        dut.dmaReqDrop.setimmediatevalue(0)
        dut.dmaReqAddress.setimmediatevalue(0)
        dut.dmaReqMaxSize.setimmediatevalue(0)
        dut.dmaReqProt.setimmediatevalue(0)
        dut.axiCache.setimmediatevalue(0xF)

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
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.axiClk, self.dut.axiRst)
        if self.ram is None:
            self.ram = AxiRamWrite(AxiWriteBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**16)


@cocotb.test()
async def direct_dma_write_request_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    frame = AxiStreamFrame(b"\x10\x11\x12\x13\x20\x21")
    frame.tdest = 0x44
    frame.tid = 0x33

    dut.dmaReqAddress.value = 0x40
    dut.dmaReqMaxSize.value = 16
    dut.dmaReqRequest.value = 1
    await tb.source.send(frame)

    while not int(dut.dmaAckDone.value):
        await tb.cycle(1)

    assert tb.ram.read(0x40, 6) == b"\x10\x11\x12\x13\x20\x21"
    assert int(dut.dmaAckSize.value) == 6
    assert int(dut.dmaAckDest.value) == 0x44
    assert int(dut.dmaAckId.value) == 0x33
    assert int(dut.dmaAckWriteError.value) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="direct_single_frame_write")])
def test_AxiStreamDmaWrite(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmawriteipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaWriteIpIntegrator.vhd",
            ],
        },
    )
