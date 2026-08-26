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
# - Sweep: Cover a stable 32-bit single-frame write and a longer frame that
#   must cross multiple AXI bursts.
# - Stimulus: Send AXI-Stream frames into the write engine, respond to the
#   descriptor request from the bench, and capture the downstream AXI writes in
#   RAM while monitoring accepted write addresses.
# - Checks: The descriptor request and return metadata, written payload bytes,
#   and expected burst-address progression must match the incoming stream.
# - Timing: The descriptor ack is delayed by a cycle so the request handshake
#   and write path both execute through their normal states.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiRamWrite, AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiWriteBus

from tests.common.regression_utils import hdl_parameters_from, run_surf_vhdl_test


def logic_int(value) -> int:
    try:
        return int(value)
    except ValueError:
        return 0


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = None
        self.ram = None
        self.aw_log = []

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.axiWriteCtrlPause.setimmediatevalue(0)
        dut.axiWriteCtrlOver.setimmediatevalue(0)
        dut.dmaWrDescAckValid.setimmediatevalue(0)
        dut.dmaWrDescRetAck.setimmediatevalue(0)
        # Lifetime descriptor peer and handshake monitor owned by the bench.
        self._lifetime_tasks = (
            cocotb.start_soon(self._descriptor_responder()),
            cocotb.start_soon(self._monitor_aw()),
        )

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
        """Lifetime agent: acknowledge DMA descriptors until the test ends."""
        max_size = int(os.environ.get("DESC_MAX_SIZE", "32"), 0)
        timeout = int(os.environ.get("DESC_TIMEOUT", "32"), 0)
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            self.dut.dmaWrDescAckValid.value = 0
            if int(self.dut.dmaWrDescReqValid.value):
                self.dut.dmaWrDescAckAddress.value = int(os.environ.get("WRITE_ADDR", "0x40"), 0)
                self.dut.dmaWrDescAckMetaEnable.value = 0
                self.dut.dmaWrDescAckMetaAddr.value = 0
                self.dut.dmaWrDescAckDropEn.value = 0
                self.dut.dmaWrDescAckMaxSize.value = max_size
                self.dut.dmaWrDescAckContEn.value = 0
                self.dut.dmaWrDescAckBuffId.value = int(os.environ.get("WRITE_BUFF_ID", "0x1234"), 0)
                self.dut.dmaWrDescAckTimeout.value = timeout
                self.dut.dmaWrDescAckValid.value = 1

    async def _monitor_aw(self):
        """Lifetime agent: record DMA write addresses until the test ends."""
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if logic_int(self.dut.M_AXI_AWVALID.value) and logic_int(self.dut.M_AXI_AWREADY.value):
                self.aw_log.append(
                    (
                        int(self.dut.M_AXI_AWADDR.value),
                        int(self.dut.M_AXI_AWLEN.value),
                    )
                )
@cocotb.test()
async def write_descriptor_round_trip_test(dut):
    tb = TB(dut)
    payload = bytes.fromhex(os.environ["PAYLOAD_HEX"])
    frame_dest = int(os.environ["FRAME_DEST"], 0)
    frame_id = int(os.environ["FRAME_ID"], 0)
    write_addr = int(os.environ.get("WRITE_ADDR", "0x40"), 0)
    write_buff_id = int(os.environ.get("WRITE_BUFF_ID", "0x1234"), 0)

    await tb.reset()
    tb.start_agents()

    frame = AxiStreamFrame(payload)
    frame.tdest = frame_dest
    frame.tid = frame_id
    await tb.source.send(frame)

    while not int(dut.dmaWrDescRetValid.value):
        await tb.cycle(1)

    assert int(dut.dmaWrDescReqId.value) == frame_id
    assert int(dut.dmaWrDescReqDest.value) == frame_dest
    assert tb.ram.read(write_addr, len(payload)) == payload
    assert int(dut.dmaWrDescRetBuffId.value) == write_buff_id
    assert int(dut.dmaWrDescRetSize.value) == len(payload)
    assert int(dut.dmaWrDescRetContinue.value) == 0
    assert int(dut.dmaWrDescRetResult.value) == 0
    assert int(dut.dmaWrDescRetDest.value) == frame_dest
    assert int(dut.dmaWrDescRetId.value) == frame_id

    if os.environ.get("EXPECT_MULTI_BURST", "0") == "1":
        assert tb.aw_log[:2] == [(write_addr, 1), (write_addr + 0x8, 1)]

    dut.dmaWrDescRetAck.value = 1
    await tb.cycle(1)
    dut.dmaWrDescRetAck.value = 0
    await tb.cycle(1)
    assert int(dut.dmaWrIdle.value) == 1


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param(
            {
                "PAYLOAD_HEX": "101112132021",
                "FRAME_DEST": 0x44,
                "FRAME_ID": 0x33,
                "WRITE_ADDR": 0x40,
                "WRITE_BUFF_ID": 0x1234,
            },
            id="single_frame_write",
        ),
        pytest.param(
            {
                "BURST_BYTES_G": 8,
                "ACK_WAIT_BVALID_G": True,
                "PAYLOAD_HEX": "303132333435363738393A3B",
                "FRAME_DEST": 0x55,
                "FRAME_ID": 0x21,
                "WRITE_ADDR": 0x80,
                "WRITE_BUFF_ID": 0x4321,
                "DESC_MAX_SIZE": 32,
                "EXPECT_MULTI_BURST": 1,
            },
            id="multi_burst_write",
        ),
    ],
)
def test_AxiStreamDmaV2Write(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2writeipintegrator",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaV2WriteIpIntegrator.vhd",
            ],
        },
    )
