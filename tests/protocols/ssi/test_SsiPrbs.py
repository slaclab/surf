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
# - Sweep: Exercise the default internal PRBS loopback configuration from the
#   legacy bench.
# - Stimulus: Run the TX and RX blocks with free-running trigger generation.
# - Checks: A fixed number of result updates must complete with no packet,
#   length, data, EOFE, or word-count errors.
# - Timing: The test waits on RX result updates with a bounded timeout.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout

from tests.common.regression_utils import run_surf_vhdl_test


EXPECTED_UPDATES = 33


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.fastClk, 3333, unit="ps").start())
        cocotb.start_soon(Clock(dut.slowClk, 10.0, unit="ns").start())

    async def reset(self):
        self.dut.fastRst.setimmediatevalue(1)
        self.dut.slowRst.setimmediatevalue(1)
        for _ in range(120):
            await RisingEdge(self.dut.slowClk)
        self.dut.fastRst.value = 0
        self.dut.slowRst.value = 0
        for _ in range(4):
            await RisingEdge(self.dut.slowClk)


@cocotb.test()
async def ssi_prbs_loopback_test(dut):
    tb = TB(dut)
    await tb.reset()

    completed = 0
    while completed < EXPECTED_UPDATES:
        await with_timeout(RisingEdge(dut.updated), 2, "ms")
        assert int(dut.errMissedPacket.value) == 0
        assert int(dut.errLength.value) == 0
        assert int(dut.errDataBus.value) == 0
        assert int(dut.errEofe.value) == 0
        assert int(dut.errWordCnt.value) == 0
        completed += 1


PARAMETER_SWEEP = [pytest.param({}, id="default_loopback")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiPrbs(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiprbswrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiPrbsWrapper.vhd"]},
    )
