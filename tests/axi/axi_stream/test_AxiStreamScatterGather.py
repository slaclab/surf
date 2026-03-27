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
# - Sweep: Reduce the wrapper's frame-length generic to three 16-bit samples so
#   the first pass proves the six-to-one repacking behavior with a tiny stable
#   sequence instead of replaying the full production frame length.
# - Stimulus: Send six SSI-style input frames with explicit SOF/TLAST markers,
#   then drain the repacked output beats and sample the AXI-Lite counters.
# - Checks: Each output beat must contain the corresponding sample index from
#   all six input frames in order, and the bad/long-frame counters must remain
#   clear for the well-formed sequence.
# - Timing: The source and sink coroutines wait on the DUT's real ready/valid
#   handshakes so the test proves the internal RAM/fifo sequencing end-to-end.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.S_AXIS_TVALID.setimmediatevalue(0)
        dut.S_AXIS_TDATA.setimmediatevalue(0)
        dut.S_AXIS_TKEEP.setimmediatevalue(0)
        dut.S_AXIS_TLAST.setimmediatevalue(0)
        dut.S_AXIS_TDEST.setimmediatevalue(0)
        dut.S_AXIS_TID.setimmediatevalue(0)
        dut.S_AXIS_TUSER.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Reset the stream and AXI-Lite paths together so the first sequence of
        # received frames starts from an empty RAM and status FIFO.
        self.dut.axiRst.value = 1
        self.dut.S_AXIS_TVALID.value = 0
        self.dut.M_AXIS_TREADY.value = 0
        await self.cycle(4)
        self.dut.axiRst.value = 0
        await self.cycle(4)

    def start_axil(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axiClk, self.dut.axiRst)

    async def read_reg(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def send_frame(self, words: list[int]):
        # Drive SSI-compatible SOF on the first beat with `TUSER[1]` and TLAST
        # on the final beat so the DUT sees a complete six-frame sequence.
        for index, word in enumerate(words):
            self.dut.S_AXIS_TDATA.value = word
            self.dut.S_AXIS_TKEEP.value = 0x3
            self.dut.S_AXIS_TLAST.value = int(index == len(words) - 1)
            self.dut.S_AXIS_TUSER.value = 0x2 if index == 0 else 0x0
            self.dut.S_AXIS_TVALID.value = 1
            while not int(self.dut.S_AXIS_TREADY.value):
                await self.cycle(1)
            await self.cycle(1)
        self.dut.S_AXIS_TVALID.value = 0
        self.dut.S_AXIS_TLAST.value = 0
        self.dut.S_AXIS_TUSER.value = 0

    async def collect_output(self, expected_beats: int) -> list[tuple[bytes, int]]:
        beats = []
        self.dut.M_AXIS_TREADY.value = 1
        while len(beats) < expected_beats:
            await self.cycle(1)
            if int(self.dut.M_AXIS_TVALID.value):
                beats.append(
                    (
                        int(self.dut.M_AXIS_TDATA.value).to_bytes(12, "little"),
                        int(self.dut.M_AXIS_TLAST.value),
                    )
                )
        self.dut.M_AXIS_TREADY.value = 0
        return beats


@cocotb.test()
async def six_frame_repack_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_axil()

    frames = [[(frame_index << 8) | sample_index for sample_index in range(3)] for frame_index in range(6)]
    for frame in frames:
        await tb.send_frame(frame)

    beats = await tb.collect_output(expected_beats=3)

    expected = []
    for sample_index in range(3):
        packed = bytearray()
        for frame_index in range(6):
            packed.extend(((frame_index << 8) | sample_index).to_bytes(2, "little"))
        expected.append(bytes(packed))

    assert [payload for payload, _ in beats] == expected
    assert [tlast for _, tlast in beats] == [0, 0, 1]
    assert await tb.read_reg(0x20) == 0
    assert await tb.read_reg(0x28) == 0


@pytest.mark.parametrize("parameters", [pytest.param({"AXIS_SLAVE_FRAME_SIZE_G": 3}, id="six_frames_three_words")])
def test_AxiStreamScatterGather(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamscattergatheripintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/SlaveAxiStreamIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/MasterAxiStreamIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/AxiStreamScatterGatherIpIntegrator.vhd",
            ],
        },
    )
