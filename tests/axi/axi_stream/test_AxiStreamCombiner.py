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
# - Sweep: Keep a single two-lane wrapper-focused case so the bench proves the
#   stable combine path and header-discard recovery without expanding into the
#   broader legacy stream matrix.
# - Stimulus: Drive one valid pair of lane frames with matching alignment
#   headers, then a mismatched-header pair followed by another valid pair.
# - Checks: The valid pair must combine into one wide output beat with lane
#   bytes interleaved in little-endian order, the bad header pair must produce
#   no output, and the next good pair must recover cleanly.
# - Timing: Both lanes are driven concurrently and the bench waits a bounded
#   number of clocks for output so recovery is checked as finite state-machine
#   progress rather than an unbounded drain.

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

        self.source0 = AxiStreamSource(AxiStreamBus.from_prefix(dut, "S0_AXIS"), dut.axisClk, dut.axisRst)
        self.source1 = AxiStreamSource(AxiStreamBus.from_prefix(dut, "S1_AXIS"), dut.axisClk, dut.axisRst)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "M_AXIS"), dut.axisClk, dut.axisRst)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axisRst.value = 0
        await self.cycle(3)


@cocotb.test()
async def combine_valid_pair_test(dut):
    tb = TB(dut)
    await tb.reset()

    lane0 = AxiStreamFrame(b"\x22\x55\x10\x11")
    lane1 = AxiStreamFrame(b"\x22\x55\x20\x21")
    lane0.tdest = lane1.tdest = 0x34
    lane0.tid = lane1.tid = 0x12

    send0 = cocotb.start_soon(tb.source0.send(lane0))
    await tb.source1.send(lane1)
    await send0

    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == b"\x10\x20\x11\x21"
    assert rx_frame.tdest == 0x34
    assert rx_frame.tid == 0x12


@cocotb.test()
async def bad_header_recovery_test(dut):
    tb = TB(dut)
    await tb.reset()

    bad0 = AxiStreamFrame(b"\x31\x55\xAA\xAB")
    bad1 = AxiStreamFrame(b"\x32\x55\xBA\xBB")
    send_bad0 = cocotb.start_soon(tb.source0.send(bad0))
    await tb.source1.send(bad1)
    await send_bad0

    await tb.cycle(10)
    assert tb.sink.empty()

    good0 = AxiStreamFrame(b"\x33\x55\x44\x45")
    good1 = AxiStreamFrame(b"\x33\x55\x54\x55")
    send_good0 = cocotb.start_soon(tb.source0.send(good0))
    await tb.source1.send(good1)
    await send_good0

    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == b"\x44\x54\x45\x55"


@pytest.mark.parametrize("parameters", [pytest.param({}, id="two_lane_default")])
def test_AxiStreamCombiner(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamcombineripintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/axi-stream/ip_integrator/AxiStreamCombinerIpIntegrator.vhd"],
        },
    )
