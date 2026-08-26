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
# - Sweep: Cover both an aligned 4-byte read and a short 3-byte terminal beat.
# - Stimulus: Preload downstream AXI RAM, issue one V2 read descriptor, and
#   collect the emitted AXI-Stream frame without compacting away invalid bytes.
# - Checks: The compacted payload, raw `tKeep`, `tDest`, `tId`, observable
#   `tUser`, descriptor ack, and descriptor return fields must match the
#   requested transfer.
# - Timing: The bench uses the real read-address and stream handshakes, not a
#   forced internal state advance.

import os

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
    read_addr = int(os.environ["READ_ADDR"], 0)
    read_size = int(os.environ["READ_SIZE"], 0)
    read_dest = int(os.environ["READ_DEST"], 0)
    read_tid = int(os.environ["READ_TID"], 0)
    read_buff_id = int(os.environ["READ_BUFF_ID"], 0)
    payload = bytes.fromhex(os.environ["READ_PAYLOAD_HEX"])
    raw_bytes = payload + bytes([0xEE] * (4 - len(payload)))

    assert len(payload) == read_size

    await tb.reset()
    tb.start_agents()

    tb.ram.write(read_addr, raw_bytes)
    await tb.issue_desc(
        address=read_addr,
        size=read_size,
        buff_id=read_buff_id,
        dest=read_dest,
        tid=read_tid,
    )

    rx_frame = await tb.sink.recv(compact=False)
    assert bytes(rx_frame.tdata) == raw_bytes
    assert list(rx_frame.tkeep) == ([1] * read_size) + ([0] * (len(raw_bytes) - read_size))
    assert bytes(byte for byte, keep in zip(rx_frame.tdata, rx_frame.tkeep) if keep) == payload
    assert all(dest == read_dest for dest in rx_frame.tdest[:read_size])
    assert all(tid == read_tid for tid in rx_frame.tid[:read_size])
    assert all(user == 0x12 for user in rx_frame.tuser[:read_size])

    while not int(dut.dmaRdDescRetValid.value):
        await tb.cycle(1)
    assert int(dut.dmaRdDescRetBuffId.value) == read_buff_id
    assert int(dut.dmaRdDescRetResult.value) == 0
    dut.dmaRdDescRetAck.value = 1
    await tb.cycle(1)


@pytest.mark.parametrize(
    "case_env",
    [
        pytest.param(
            {
                "READ_ADDR": 0x20,
                "READ_SIZE": 4,
                "READ_DEST": 0x44,
                "READ_TID": 0x33,
                "READ_BUFF_ID": 0x55AA,
                "READ_PAYLOAD_HEX": "10111213",
            },
            id="aligned_4byte_frame",
        ),
        pytest.param(
            {
                "READ_ADDR": 0x40,
                "READ_SIZE": 3,
                "READ_DEST": 0x24,
                "READ_TID": 0x11,
                "READ_BUFF_ID": 0xA5A5,
                "READ_PAYLOAD_HEX": "202122",
            },
            id="short_3byte_terminal_frame",
        ),
    ],
)
def test_AxiStreamDmaV2Read(case_env):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2readipintegrator",
        extra_env=case_env,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaV2ReadIpIntegrator.vhd",
            ],
        },
    )
