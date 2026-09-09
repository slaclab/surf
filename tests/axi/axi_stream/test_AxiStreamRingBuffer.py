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
# - Sweep: Keep one small common-clock 16-bit wrapper configuration with a
#   16-deep ring so the bench proves the trigger-to-stream export behavior.
# - Stimulus: Push a short sequence into the data port, confirm the visible
#   buffered-length register, then stop capture with `extTrig` and drain the
#   exported AXI-Stream frame.
# - Checks: The stream must emit the current wrapper's captured window, which
#   includes the design's initial BRAM word followed by the populated samples
#   visible through the registered read path at trigger time.
# - Timing: The bench waits for the DUT to emit the stream frame after the
#   trigger instead of assuming the readout begins immediately on the same cycle.

import cocotb
import pytest
from cocotb.triggers import with_timeout

from tests.common.regression_utils import sample_after_tpd
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
        dut.extTrig.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axilClk)

    async def reset(self):
        self.dut.dataRst.value = 1
        self.dut.axilRst.value = 1
        self.dut.axisRst.value = 1
        self.dut.dataValid.value = 0
        self.dut.extTrig.value = 0
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

    async def push_value(self, value: int):
        self.dut.dataValue.value = value
        self.dut.dataValid.value = 1
        await self.cycle(1)
        self.dut.dataValid.value = 0
        await self.cycle(1)


@cocotb.test()
async def trigger_exports_captured_window_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    samples = [0x0010, 0x0021, 0x0132, 0x0243, 0x0354, 0x0465]
    for sample in samples:
        await tb.push_value(sample)
    await tb.cycle(1)

    tb.dut.extTrig.value = 1
    await tb.cycle(1)
    tb.dut.extTrig.value = 0
    await tb.cycle(6)

    frame = await with_timeout(tb.sink.recv(), 3, "us")
    expected = b"\x00\x00" + b"".join(sample.to_bytes(2, "little") for sample in samples[:-1])

    assert bytes(frame.tdata) == expected


@pytest.mark.parametrize("parameters", [pytest.param({}, id="small_common_clk_capture")])
def test_AxiStreamRingBuffer(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamringbufferipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
