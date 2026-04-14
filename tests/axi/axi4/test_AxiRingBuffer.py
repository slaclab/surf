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
# - Sweep: Keep one small common-clock wrapper configuration that matches the
#   legacy ring-buffer testbed's 32-bit capture path.
# - Stimulus: Mirror the checked-in VHDL testbed by driving a continuous ramp,
#   pulsing the external trigger after the capture window is well primed, and
#   then letting the DUT fetch the frame from AXI RAM.
# - Checks: The exported AXI-Stream frame must start with the expected captured
#   ramp values so the wrapper proves the end-to-end write and readback path.
# - Timing: The bench allows tens of microseconds for the trigger-to-stream
#   turnaround because the DUT must drain the buffered window through AXI.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiBus, AxiRam, AxiStreamBus, AxiStreamSink

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.ram = None
        self.sink = None

        # The wrapper intentionally ties the clocks together, so drive them
        # from one coroutine to preserve truly aligned edges.
        start_lockstep_clocks(dut.dataClk, dut.axisClk, dut.axiClk, period_ns=5.0)
        dut.dataRst.setimmediatevalue(1)
        dut.axisRst.setimmediatevalue(1)
        dut.axiRst.setimmediatevalue(1)
        dut.dataValid.setimmediatevalue(0)
        dut.dataValue.setimmediatevalue(0)
        dut.extTrig.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.dataRst.value = 1
        self.dut.axisRst.value = 1
        self.dut.axiRst.value = 1
        await self.cycle(4)
        self.dut.dataRst.value = 0
        self.dut.axisRst.value = 0
        self.dut.axiRst.value = 0
        await self.cycle(6)

    def start_agents(self):
        if self.ram is None:
            self.ram = AxiRam(AxiBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**16)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)

    async def drive_ramp_until_trigger(self, trigger_index: int):
        # Keep dataValid asserted continuously, matching the native VHDL testbed
        # that exercises the ring buffer with a free-running sample stream.
        self.dut.dataValid.value = 1

        for sample in range(trigger_index + 8):
            self.dut.dataValue.value = sample
            self.dut.extTrig.value = int(sample == trigger_index)
            await self.cycle(1)

        self.dut.extTrig.value = 0


@cocotb.test()
async def trigger_exports_captured_window_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    trigger_index = 2100
    await tb.drive_ramp_until_trigger(trigger_index)

    frame = await with_timeout(tb.sink.recv(), 50, "us")
    payload = bytes(frame.tdata)

    # The checked-in HDL testbench's first captured word lands 960 samples
    # before the trigger point for this wrapper configuration.
    expected_start = trigger_index - 960
    expected_prefix = b"".join((expected_start + i).to_bytes(4, "little") for i in range(8))

    assert payload.startswith(expected_prefix)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="triggered_capture_window")])
def test_AxiRingBuffer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiringbufferipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-stream/ip_integrator/MasterAxiStreamIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiRingBufferIpIntegrator.vhd",
            ],
        },
    )
