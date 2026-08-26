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
# - Sweep: Keep one deterministic threshold case that disables pause and one
#   case that blocks traffic for a bounded window.
# - Stimulus: Drive short frames through the wrapper while toggling the
#   threshold input between all-zero and all-one values.
# - Checks: With threshold zero the frame must pass unchanged; with threshold
#   all ones the sink must remain empty for the observed window.
# - Timing: The blocked check is bounded to a few cycles so it proves the
#   pause path without depending on any specific PRBS phase.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = None
        self.sink = None

        cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())
        dut.rst.setimmediatevalue(1)
        dut.threshold.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.clk)

    async def reset(self):
        self.dut.rst.setimmediatevalue(1)
        self.dut.threshold.value = 0
        await self.cycle(3)
        self.dut.rst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.clk, self.dut.rst)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.clk, self.dut.rst)


@cocotb.test()
async def open_and_blocked_threshold_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    frame = AxiStreamFrame(b"\x10\x11\x12\x13")
    await tb.source.send(frame)
    rx_frame = await tb.sink.recv()
    assert rx_frame.tdata == frame.tdata

    tb.dut.threshold.value = 0xFFFFFFFF
    send_task = cocotb.start_soon(tb.source.send(AxiStreamFrame(b"\x20\x21\x22\x23")))
    await tb.cycle(8)
    assert tb.sink.empty()
    send_task.kill()


@pytest.mark.parametrize("parameters", [pytest.param({}, id="threshold_extremes")])
def test_AxiStreamPrbsFlowCtrl(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamprbsflowctrlipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
