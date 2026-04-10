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
# - Sweep: Keep a narrow two-case sweep covering normal pass-through and
#   mid-frame flush on the SSI-enabled path.
# - Stimulus: Send short and long AXI Stream frames through the wrapper,
#   toggle the flush input after the first output beat of a long frame, and
#   hold the pause input high for a few cycles so the output state is visible.
# - Checks: With flush disabled the output frame must match the input frame,
#   and with flush asserted mid-frame the emitted frame must terminate early
#   while the remainder of the original input frame is discarded.
# - Timing: Flush is asserted only after the first output beat is visible so
#   the bench proves the state transition out of MOVE rather than a trivial
#   pre-frame drop case.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())

        dut.axisRst.setimmediatevalue(1)
        dut.flushEn.setimmediatevalue(0)
        dut.M_AXIS_PAUSE.setimmediatevalue(0)

        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "S_AXIS"), dut.axisClk, dut.axisRst)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "M_AXIS"), dut.axisClk, dut.axisRst)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(1)
        self.dut.flushEn.value = 0
        self.dut.M_AXIS_PAUSE.value = 0
        await self.cycle(3)
        self.dut.axisRst.value = 0
        await self.cycle(3)


@cocotb.test()
async def pass_through_test(dut):
    tb = TB(dut)
    await tb.reset()

    frame = AxiStreamFrame(b"\x10\x11\x12\x13\x14\x15")
    frame.tdest = 0x44
    frame.tid = 0x12
    await tb.source.send(frame)

    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == frame.tdata
    assert rx_frame.tdest == frame.tdest
    assert rx_frame.tid == frame.tid


@cocotb.test()
async def flush_midframe_test(dut):
    tb = TB(dut)
    await tb.reset()

    frame = AxiStreamFrame(bytes(range(24)))
    send_task = cocotb.start_soon(tb.source.send(frame))

    for _ in range(16):
        await tb.cycle(1)
        if int(tb.dut.M_AXIS_TVALID.value):
            break
    else:
        raise AssertionError("Timed out waiting for first flush output beat")

    tb.dut.M_AXIS_PAUSE.value = 1
    tb.dut.flushEn.value = 1
    await tb.cycle(1)
    tb.dut.M_AXIS_PAUSE.value = 0
    tb.dut.flushEn.value = 0
    await send_task

    rx_frame = await tb.sink.recv()
    assert len(rx_frame.tdata) < len(frame.tdata)
    assert rx_frame.tdata == frame.tdata[: len(rx_frame.tdata)]
    assert tb.sink.empty()


@pytest.mark.parametrize("parameters", [pytest.param({"SSI_EN_G": "true"}, id="ssi_enabled")])
def test_AxiStreamFlush(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamflushipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/axi-stream/ip_integrator/AxiStreamFlushIpIntegrator.vhd"],
        },
    )
