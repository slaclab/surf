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
# - Sweep: Keep one 32-bit single-frame case with descriptor ack supplied from
#   the testbench.
# - Stimulus: Send one AXI-Stream frame, respond to the descriptor request with
#   a writable buffer, and capture the downstream AXI write traffic in RAM.
# - Checks: The descriptor request fields, downstream written bytes, and return
#   metadata must match the incoming frame.
# - Timing: The descriptor ack is delayed by a cycle so the request handshake
#   and write path both execute through their normal states.

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
        dut.axiWriteCtrlPause.setimmediatevalue(0)
        dut.axiWriteCtrlOver.setimmediatevalue(0)
        dut.dmaWrDescAckValid.setimmediatevalue(0)
        dut.dmaWrDescRetAck.setimmediatevalue(0)
        cocotb.start_soon(self._descriptor_responder())

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axiRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axiClk, self.dut.axiRst)
        if self.ram is None:
            self.ram = AxiRamWrite(AxiWriteBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**16)

    async def _descriptor_responder(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            self.dut.dmaWrDescAckValid.value = 0
            if int(self.dut.dmaWrDescReqValid.value):
                self.dut.dmaWrDescAckAddress.value = 0x40
                self.dut.dmaWrDescAckMetaEnable.value = 0
                self.dut.dmaWrDescAckMetaAddr.value = 0
                self.dut.dmaWrDescAckDropEn.value = 0
                self.dut.dmaWrDescAckMaxSize.value = 16
                self.dut.dmaWrDescAckContEn.value = 0
                self.dut.dmaWrDescAckBuffId.value = 0x1234
                self.dut.dmaWrDescAckTimeout.value = 0x20
                self.dut.dmaWrDescAckValid.value = 1


@cocotb.test()
async def single_frame_write_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    frame = AxiStreamFrame(b"\x10\x11\x12\x13\x20\x21")
    frame.tdest = 0x44
    frame.tid = 0x33
    await tb.source.send(frame)

    while not int(dut.dmaWrDescRetValid.value):
        await tb.cycle(1)

    assert int(dut.dmaWrDescReqId.value) == 0x33
    assert int(dut.dmaWrDescReqDest.value) == 0x44
    assert tb.ram.read(0x40, 6) == b"\x10\x11\x12\x13\x20\x21"
    assert int(dut.dmaWrDescRetBuffId.value) == 0x1234
    assert int(dut.dmaWrDescRetSize.value) == 6
    assert int(dut.dmaWrDescRetDest.value) == 0x44
    assert int(dut.dmaWrDescRetId.value) == 0x33
    dut.dmaWrDescRetAck.value = 1
    await tb.cycle(1)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="single_frame_write")])
def test_AxiStreamDmaV2Write(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2writeipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaV2WriteIpIntegrator.vhd",
            ],
        },
    )
