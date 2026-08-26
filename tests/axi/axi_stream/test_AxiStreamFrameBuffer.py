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
# - Sweep: Test synchronous and asynchronous clocks as well as with and
#   without safe buffers. For the latter case the expected behavior is
#   that the next write overwrites existing data in the buffer.
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

import math

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp, AxiStreamBus, AxiStreamSink

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks, parameter_case


class TB:
    def __init__(self, dut, dataClkPeriod=2.0, axilClkPeriod=5.0, axisClkPeriod=2.5):
        self.dut = dut
        self.axil = None
        self.sink = None

        if dataClkPeriod == axilClkPeriod == axisClkPeriod:
            # Keep the data, AXI-Lite, and stream-export clocks truly aligned.
            start_lockstep_clocks(dut.dataClk, dut.axilClk, dut.axisClk, period_ns=dataClkPeriod)
        else:
            # Generally asynchronous clocks, not locked either
            cocotb.start_soon(Clock(dut.dataClk, dataClkPeriod, unit="ns").start())
            cocotb.start_soon(Clock(dut.axilClk, axilClkPeriod, unit="ns").start())
            cocotb.start_soon(Clock(dut.axisClk, axisClkPeriod, unit="ns").start())

        # Build list of clock signals with the fastest (shortest period) first.
        # If same speed, the order does not matter.
        clocks = [(dut.dataClk, dataClkPeriod), (dut.axilClk, axilClkPeriod), (dut.axisClk, axisClkPeriod)]
        clocks.sort(key=lambda x: x[1])
        self.clkBySpeed = [x[0] for x in clocks]

        dut.dataRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.axisRst.setimmediatevalue(1)
        dut.dataValid.setimmediatevalue(0)
        dut.dataValue.setimmediatevalue(0)
        dut.dataRdTrig.setimmediatevalue(0)
        dut.axilRdTrig.setimmediatevalue(0)

    @classmethod
    def with_sync_clocks(cls, dut):
        # Set some silly clock speeds to test async behaviour
        baseClkPeriod = 5.0  # ns
        tb = cls(
            dut,
            dataClkPeriod=baseClkPeriod,
            axilClkPeriod=baseClkPeriod,
            axisClkPeriod=baseClkPeriod,
        )
        return tb

    @classmethod
    def with_async_clocks(cls, dut):
        # Set some silly clock ratios to test async behaviour
        baseClkPeriod = 5.0  # ns
        tb = cls(
            dut,
            dataClkPeriod=baseClkPeriod,
            axilClkPeriod=round(baseClkPeriod / math.pi, 5),
            axisClkPeriod=round(baseClkPeriod * math.e, 5),
        )
        return tb

    @classmethod
    def from_generics(cls, dut):
        if dut.ASYNC_CLOCKS_G.value:
            return cls.with_async_clocks(dut)
        else:
            return cls.with_sync_clocks(dut)

    async def cycle(self, clk, count=1):
        for _ in range(count):
            await RisingEdge(clk)
            await Timer(1, unit="ns")

    # Wait for one cycle of the slowest clock
    async def cycleSlowest(self, count=1):
        await self.cycle(clk=self.clkBySpeed[-1], count=count)

    async def reset(self):
        self.dut.dataRst.value = 1
        self.dut.axilRst.value = 1
        self.dut.axisRst.value = 1
        self.dut.dataValid.value = 0
        self.dut.dataRdTrig.value = 0
        self.dut.axilRdTrig.value = 0
        await self.cycleSlowest(4)
        self.dut.dataRst.value = 0
        self.dut.axilRst.value = 0
        self.dut.axisRst.value = 0
        await self.cycleSlowest(6)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXI"), self.dut.axilClk, self.dut.axilRst)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)

    async def read_reg(self, address: int) -> int:
        txn = await self.axil.read(address, 4)
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def push_value(self, value: int, last: bool = False):
        self.dut.dataValue.value = value
        self.dut.dataValid.value = 1
        self.dut.dataFrameTxLast.value = int(last)

        await RisingEdge(self.dut.dataClk)

        self.dut.dataValid.value = 0
        self.dut.dataFrameTxLast.value = 0

    async def closeout_frame(self):
        # Last transmission signal asserted after last transmission
        self.dut.dataFrameTxLast.value = 1
        await self.cycle(self.dut.dataClk, 1)
        self.dut.dataFrameTxLast.value = 0
        await self.cycle(self.dut.dataClk, 1)


# Generate a frame shorter than the buffer and terminate using the
# last dataFrameTxLast signal.
@cocotb.test()
async def trigger_exports_captured_frame_single_short_test(dut):
    tb = TB.from_generics(dut)
    await tb.reset()
    tb.start_agents()

    samples = [0x0010, 0x0021, 0x0132, 0x0243, 0x0354, 0x0465]
    for i in range(len(samples)):
        sample = samples[i]
        last = i == len(samples) - 1
        await tb.push_value(sample, last)
    await tb.cycle(tb.dut.dataClk, 1)

    tb.dut.dataRdTrig.value = 1
    await tb.cycle(tb.dut.dataClk, 1)
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
    tb = TB.from_generics(dut)
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
        await tb.push_value(sample, last=False)  # Do not assert last for this test

        if i == 15 + 2:
            # Check correct timing of frame done signal in the cycle from which
            # onwards a new frame is available for readout.
            assert tb.dut.dataFrameRxDone.value == 1
    await tb.cycle(tb.dut.dataClk, 2)

    tb.dut.dataRdTrig.value = 1
    await tb.cycle(tb.dut.dataClk, 1)
    tb.dut.dataRdTrig.value = 0

    # Frame readout can start immediately but may wait a few cycles until first
    # valid data (tvalid = 1) data available.
    frame_0 = await with_timeout(tb.sink.recv(), 3, "us")
    if dut.SAFE_BUFFS_G.value:
        # Second frame mid-receive so the read out frame should be the first one,
        # i.e. the first 16 words from the samples list.
        expected_0 = b"".join(sample.to_bytes(2, "little") for sample in samples[:16])
    else:
        # Second frame mid receive overwrites data in buffer in unsafe mode.
        # First 8 words overwritten at this point.
        expected_0 = b"".join(sample.to_bytes(2, "little") for sample in samples[16 : 16 + 8] + samples[8 : 8 + 8])

    # Might as well complete the second frame. The frame done signal can be
    # asserted during the last transaction but can also be asserted later,
    # without transmitting any data (dataValid = 0) to close out the frame.
    await tb.closeout_frame()

    tb.dut.dataRdTrig.value = 1
    await tb.cycle(tb.dut.dataClk, 1)
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


@cocotb.test()
async def soft_trigger_exports_captured_frame_single_short_test(dut):
    tb = TB.from_generics(dut)
    await tb.reset()
    tb.start_agents()

    samples = [0x0210, 0x0F23, 0x1131, 0x014E, 0x0C5A, 0x01AA]
    for i in range(len(samples)):
        sample = samples[i]
        last = i == len(samples) - 1
        await tb.push_value(sample, last)
    await tb.cycle(tb.dut.dataClk, 1)

    # Issue software trigger
    txn = await tb.axil.write(0x8, 0x1.to_bytes(4, "little"))
    assert txn.resp == AxiResp.OKAY

    # Read register and check that its automatically reset to zero
    txn = await tb.axil.read(0x8, 4)
    assert txn.resp == AxiResp.OKAY
    assert int.from_bytes(txn.data, "little") == 0

    # Frame readout can start immediately but may wait a few cycles until first
    # valid data (tvalid = 1) data available.
    frame = await with_timeout(tb.sink.recv(), 3, "us")
    expected = b"".join(sample.to_bytes(2, "little") for sample in samples)

    assert bytes(frame.tdata) == expected


PARAMETER_SWEEP = [
    parameter_case(
        "async_clk_capture_safebuf",
        ASYNC_CLOCKS_G=True,
        SAFE_BUFFS_G=True,
    ),
    parameter_case(
        "async_clk_capture_unsafebuf",
        ASYNC_CLOCKS_G=True,
        SAFE_BUFFS_G=False,
    ),
    parameter_case(
        "sync_clk_capture_safebuf",
        ASYNC_CLOCKS_G=False,
        SAFE_BUFFS_G=True,
    ),
    parameter_case(
        "sync_clk_capture_unsafebuf",
        ASYNC_CLOCKS_G=False,
        SAFE_BUFFS_G=False,
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiStreamFrameBuffer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamframebufferipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
