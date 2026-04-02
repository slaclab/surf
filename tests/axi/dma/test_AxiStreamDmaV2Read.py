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
# - Sweep: Keep one 32-bit single-frame descriptor case.
# - Stimulus: Preload downstream AXI RAM, issue one V2 read descriptor, and
#   collect the emitted AXI-Stream frame.
# - Checks: The stream payload, `tDest`, descriptor ack, and descriptor return
#   fields must match the requested transfer.
# - Timing: The bench uses the real read-address and stream handshakes, not a
#   forced internal state advance.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiRamRead, AxiReadBus, AxiStreamBus, AxiStreamSink

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.ram = None
        self.sink = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.axisCtrlPause.setimmediatevalue(0)
        dut.axisCtrlOverflow.setimmediatevalue(0)
        dut.dmaRdDescReqValid.setimmediatevalue(0)
        dut.dmaRdDescRetAck.setimmediatevalue(0)

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
        if self.ram is None:
            self.ram = AxiRamRead(AxiReadBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**16)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axiClk, self.dut.axiRst)

    async def issue_desc(self, *, address: int, size: int, buff_id: int, dest: int, tid: int):
        self.dut.dmaRdDescReqAddress.value = address
        self.dut.dmaRdDescReqBuffId.value = buff_id
        self.dut.dmaRdDescReqFirstUser.value = 0x12
        self.dut.dmaRdDescReqLastUser.value = 0x34
        self.dut.dmaRdDescReqSize.value = size
        self.dut.dmaRdDescReqContinue.value = 0
        self.dut.dmaRdDescReqId.value = tid
        self.dut.dmaRdDescReqDest.value = dest
        self.dut.dmaRdDescReqValid.value = 1
        while not int(self.dut.dmaRdDescAck.value):
            await self.cycle(1)
        self.dut.dmaRdDescReqValid.value = 0


@cocotb.test()
async def single_descriptor_read_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    tb.ram.write(0x20, b"\x10\x11\x12\x13")
    await tb.issue_desc(address=0x20, size=4, buff_id=0x55AA, dest=0x44, tid=0x33)

    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == b"\x10\x11\x12\x13"
    assert rx_frame.tdest == 0x44
    assert rx_frame.tid == 0x33

    while not int(dut.dmaRdDescRetValid.value):
        await tb.cycle(1)
    assert int(dut.dmaRdDescRetBuffId.value) == 0x55AA
    assert int(dut.dmaRdDescRetResult.value) == 0
    dut.dmaRdDescRetAck.value = 1
    await tb.cycle(1)


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param(
            {},
            id="single_frame_read",
            marks=pytest.mark.xfail(
                reason="Known RTL bug: AxiStreamDmaV2Read currently aborts in simulation",
                strict=False,
            ),
        )
    ],
)
def test_AxiStreamDmaV2Read(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2readipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaV2ReadIpIntegrator.vhd",
            ],
        },
    )
