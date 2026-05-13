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
# - Sweep: Keep one small common-clock 2-byte frame-buffer wrapper
#   configuration with a 16-word frame depth so the bench validates the
#   frame-capture and AXI-Stream export behavior without introducing
#   cross-clock timing complexity (although it should manage async clocks).
# - Stimulus: Drive framed sample sequences into the data interface using
#   `dataValid` and `dataFrameTxLast`, including both an explicitly
#   terminated short frame and a frame that overruns the configured buffer
#   depth to verify automatic frame rollover.
# - Checks: A read trigger must export only the completed frame currently
#   stored in the buffer. Explicitly closed frames must stream exactly the
#   transmitted samples, while oversized writes must split into sequential
#   frame-sized captures with the remaining samples exported only after the
#   follow-on frame is closed.
# - Timing: The bench allows AXI-Stream readout to begin immediately after
#   `dataRdTrig` assertion but tolerates a small startup latency before the
#   first valid stream beat is presented (`tValid = 1`). Further, 
#   dataFrameRxDone timing is checked.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp, AxiStreamBus, AxiStreamSink

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        self.sink = None

        # Keep the data, AXI-Lite, and stream-export clocks truly aligned for
        # the common-clock wrapper subset this bench is validating.
        start_lockstep_clocks(dut.dataClk, dut.axilClk, dut.axisClk, period_ns=5.0)
        dut.dataRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.axisRst.setimmediatevalue(1)
        dut.dataValid.setimmediatevalue(0)
        dut.dataValue.setimmediatevalue(0)
        dut.dataRdTrig.setimmediatevalue(0)
        dut.axilRdTrig.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.dataRst.value = 1
        self.dut.axilRst.value = 1
        self.dut.axisRst.value = 1
        self.dut.dataValid.value = 0
        self.dut.dataRdTrig.value = 0
        self.dut.axilRdTrig.value = 0
        await self.cycle(4)
        self.dut.dataRst.value = 0
        self.dut.axilRst.value = 0
        self.dut.axisRst.value = 0
        await self.cycle(6)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axilClk, self.dut.axilRst)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)

    async def read_reg(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def push_value(self, value: int, last: bool=False):
        # Last transmission signal asserted during last transmission
        self.dut.dataValue.value = value
        self.dut.dataValid.value = 1
        if last:
            self.dut.dataFrameTxLast.value = 1
        await self.cycle(1)
        self.dut.dataValid.value = 0
        if last:
            self.dut.dataFrameTxLast.value = 0
        frame_done = self.dut.dataFrameRxDone.value 
        await self.cycle(1)
        return frame_done

    async def closeout_frame(self):
        # Last transmission signal asserted after last transmission
        self.dut.dataFrameTxLast.value = 1
        await self.cycle(1)
        self.dut.dataFrameTxLast.value = 0
        await self.cycle(1)


# Generate a frame shorter than the buffer and terminate using the
# last dataFrameTxLast signal.
@cocotb.test()
async def trigger_exports_captured_frame_single_short_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    samples = [0x0010, 0x0021, 0x0132, 0x0243, 0x0354, 0x0465]
    for i in range(len(samples)):
        sample = samples[i]
        last = (i == len(samples) - 1)
        await tb.push_value(sample, last)
    await tb.cycle(1)

    tb.dut.dataRdTrig.value = 1
    await tb.cycle(1)
    tb.dut.dataRdTrig.value = 0
    # Frame readout can start immediately but may wait a few cycles until first
    # valid data (tvalid = 1) data available.
    frame = await with_timeout(tb.sink.recv(), 3, "us")
    expected = b"".join(sample.to_bytes(2, "little") for sample in samples)

    assert bytes(frame.tdata) == expected

# Generate a frame longer than the buffer to verify automatic frame
# stop/switching to next frame.
@cocotb.test()
async def trigger_exports_captured_frame_multi_longshort_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    # RAM_ADDR_WIDTH_G = 4 so 2**4 * 2 bytes or 2**4 words per frame
    samples = [
        0x0010, 0x0021, 0x0132, 0x0243, 0x0354, 0x0465, 0xB00B, 0x144F,
        0x1Af2, 0xFFAF, 0x0F12, 0xDC1F, 0x0000, 0xFFFF, 0xBAAB, 0x0010, # First frame until here
        0x13FA, 0x13FF, 0xF12A, 0xFA1F, 0x1113, 0x12B2, 0xD1DD, 0x0123, # Second frame (half full)
        ]

    for i in range(len(samples)):
        sample = samples[i]
        frame_done = await tb.push_value(sample, last=False)  # Do not assert last for this test
        if i == 15 + 1:
            # Check correct timing of frame done signal in the cycle from which
            # onwards a new frame is available for readout.
            assert frame_done == 1
    await tb.cycle(2)

    tb.dut.dataRdTrig.value = 1
    await tb.cycle(1)
    tb.dut.dataRdTrig.value = 0

    # Frame readout can start immediately but may wait a few cycles until first
    # valid data (tvalid = 1) data available.
    frame_0 = await with_timeout(tb.sink.recv(), 3, "us")
    # Second frame mid-receive so the read out frame should be the first one,
    # i.e. the first 16 words from the samples list.
    expected_0 = b"".join(sample.to_bytes(2, "little") for sample in samples[:16])

    # Might as well complete the second frame. The frame done signal can be
    # asserted during the last transaction but can also be asserted later, 
    # without transmitting any data (dataValid = 0) to close out the frame.
    await tb.closeout_frame()

    tb.dut.dataRdTrig.value = 1
    await tb.cycle(1)
    # Check correct timing of frame done signal in the cycle from which
    # onwards a new frame is available for readout.
    assert tb.dut.dataFrameRxDone.value == 1
    tb.dut.dataRdTrig.value = 0

    # Frame readout can start immediately but may wait a few cycles until first
    # valid data (tvalid = 1) data available.
    frame_1 = await with_timeout(tb.sink.recv(), 3, "us")
    # Second frame done so now the remaining 8 bytes will be read.
    expected_1 = b"".join(sample.to_bytes(2, "little") for sample in samples[16:])

    assert bytes(frame_0.tdata) == expected_0
    assert bytes(frame_1.tdata) == expected_1


@pytest.mark.parametrize("parameters", [pytest.param({}, id="small_common_clk_capture")])
def test_AxiStreamFrameBuffer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamframebufferipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/MasterAxiStreamIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/AxiStreamFrameBufferIpIntegrator.vhd",
            ],
        },
    )
