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
# - Sweep: Keep one 64-bit DMA-read case with an aligned multi-beat transfer.
# - Stimulus: Preload AXI RAM, issue one cocotb-driven DMA request, and apply
#   one short ready stall between output beats.
# - Checks: The emitted payload, `tKeep`, `tDest`, `tId`, first-user,
#   last-user, and DMA-ack fields must match the request.
# - Timing: The bench holds `request` high until `done` asserts so the DUT
#   completes through its normal request/ack handshake.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiRamRead, AxiReadBus

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.ram = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.dmaReqRequest.setimmediatevalue(0)
        dut.dmaReqAddress.setimmediatevalue(0)
        dut.dmaReqSize.setimmediatevalue(0)
        dut.dmaReqFirstUser.setimmediatevalue(0)
        dut.dmaReqLastUser.setimmediatevalue(0)
        dut.dmaReqDest.setimmediatevalue(0)
        dut.dmaReqId.setimmediatevalue(0)
        dut.dmaReqProt.setimmediatevalue(0)
        dut.axisCtrlPause.setimmediatevalue(0)
        dut.axisCtrlOverflow.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axiRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        await self.cycle(3)

    def start_ram(self):
        if self.ram is None:
            self.ram = AxiRamRead(
                AxiReadBus.from_prefix(self.dut, "M_AXI"),
                self.dut.axiClk,
                self.dut.axiRst,
                size=2**16,
            )

    async def issue_request(
        self,
        *,
        address: int,
        size: int,
        first_user: int,
        last_user: int,
        dest: int,
        tid: int,
        prot: int = 0,
    ):
        self.dut.dmaReqAddress.value = address
        self.dut.dmaReqSize.value = size
        self.dut.dmaReqFirstUser.value = first_user
        self.dut.dmaReqLastUser.value = last_user
        self.dut.dmaReqDest.value = dest
        self.dut.dmaReqId.value = tid
        self.dut.dmaReqProt.value = prot
        self.dut.dmaReqRequest.value = 1

    async def wait_for_done(self, timeout_cycles=200):
        for _ in range(timeout_cycles):
            if int(self.dut.dmaAckDone.value):
                return
            await self.cycle(1)
        assert False, "DMA read never asserted done"

    async def collect_frame(self, *, stall_cycles_after_first=1, timeout_cycles=200):
        payload = bytearray()
        keep_words = []
        first_user_words = []
        last_user_words = []
        first_dest = None
        first_tid = None
        accepted_beats = 0
        stall_count = 0

        for _ in range(timeout_cycles):
            if accepted_beats == 1 and stall_count < stall_cycles_after_first:
                self.dut.M_AXIS_TREADY.value = 0
                stall_count += 1
            else:
                self.dut.M_AXIS_TREADY.value = 1

            await self.cycle(1)

            if int(self.dut.M_AXIS_TVALID.value) and int(self.dut.M_AXIS_TREADY.value):
                keep_mask = int(self.dut.M_AXIS_TKEEP.value)
                data_word = int(self.dut.M_AXIS_TDATA.value)
                beat_bytes = data_word.to_bytes(len(self.dut.M_AXIS_TKEEP), byteorder="little")

                keep_words.append(keep_mask)
                first_user_words.append(int(self.dut.M_AXIS_FIRST_USER.value))
                last_user_words.append(int(self.dut.M_AXIS_LAST_USER.value))
                if first_dest is None:
                    first_dest = int(self.dut.M_AXIS_TDEST.value)
                    first_tid = int(self.dut.M_AXIS_TID.value)

                for byte_index, byte_value in enumerate(beat_bytes):
                    if keep_mask & (1 << byte_index):
                        payload.append(byte_value)

                accepted_beats += 1
                if int(self.dut.M_AXIS_TLAST.value):
                    self.dut.M_AXIS_TREADY.value = 0
                    return (
                        bytes(payload),
                        keep_words,
                        first_user_words,
                        last_user_words,
                        first_dest,
                        first_tid,
                    )

        assert False, "Timed out waiting for DMA-read frame"


@cocotb.test()
async def aligned_multi_beat_read_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_ram()

    address = 0x20
    size = 10
    first_user = 0x12
    last_user = 0x34
    dest = 0x44
    tid = 0x55
    payload = bytes(range(0x30, 0x30 + 16))
    tb.ram.write(address, payload)

    await tb.issue_request(
        address=address,
        size=size,
        first_user=first_user,
        last_user=last_user,
        dest=dest,
        tid=tid,
    )

    rx_payload, keep_words, first_user_words, last_user_words, rx_dest, rx_tid = await tb.collect_frame(
        stall_cycles_after_first=1
    )
    await tb.wait_for_done()

    assert rx_payload == payload[:size]
    assert keep_words == [0xFF, 0x03]
    assert first_user_words[0] == first_user
    assert last_user_words[-1] == last_user
    assert rx_dest == dest
    assert rx_tid == tid
    assert int(dut.dmaAckReadError.value) == 0
    assert int(dut.dmaAckErrorValue.value) == 0

    dut.dmaReqRequest.value = 0
    await tb.cycle(2)
    assert int(dut.dmaAckDone.value) == 0


@pytest.mark.parametrize("parameters", [pytest.param({}, id="aligned_multi_beat")])
def test_AxiStreamDmaRead(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmareadipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaReadIpIntegrator.vhd",
            ],
        },
    )
