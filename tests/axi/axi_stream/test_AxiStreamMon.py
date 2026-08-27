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
# - Sweep: Keep one common-clock 32-bit monitor wrapper with a deliberately low
#   effective monitor clock frequency that stays well below the real design but
#   still avoids the DUT's `TIMEOUT_C=0` corner at elaboration/runtime.
# - Stimulus: Drive three frames through the monitored input with the wrapper's
#   downstream ready signal held high throughout the transfer.
# - Checks: The total frame count, last-frame size, and min/max frame-size
#   outputs must reflect the accepted traffic after the initial post-reset arm.
# - Timing: The bench samples only the size/count outputs; the one-second rate
#   update path is intentionally left out of this narrow first-pass check.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.axisReady.setimmediatevalue(1)

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axiClk)

    async def reset(self):
        self.dut.axiRst.value = 1
        self.dut.axisReady.value = 1
        await self.cycle(4)
        self.dut.axiRst.value = 0
        await self.cycle(4)

    def start_source(self):
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.axiClk, self.dut.axiRst)


@cocotb.test()
async def frame_count_and_size_tracking_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_source()

    await tb.source.send(AxiStreamFrame(b"\x01\x02"))
    await tb.source.send(AxiStreamFrame(b"\x10\x11\x12\x13\x14"))
    await tb.source.send(AxiStreamFrame(b"\x20\x21\x22"))
    await tb.cycle(30)

    assert int(dut.frameCnt.value) == 3
    assert int(dut.frameSize.value) == 3
    assert int(dut.frameSizeMax.value) == 5
    assert int(dut.frameSizeMin.value) == 3


@pytest.mark.parametrize("parameters", [pytest.param({}, id="common_clk_monitor")])
def test_AxiStreamMon(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreammonipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
