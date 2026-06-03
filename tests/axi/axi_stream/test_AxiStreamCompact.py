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
# - Sweep: Keep one stable same-width wrapper case.
# - Stimulus: Drive one contiguous full-keep beat directly into the flat slave
#   port and hold the master ready high.
# - Checks: A full-keep beat passes straight through, so the output beat must
#   preserve the payload data and full-byte keep mask and terminate with
#   `tLast`.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.rx_beats = []

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())
        dut.axisRst.setimmediatevalue(1)
        dut.S_AXIS_TVALID.setimmediatevalue(0)
        dut.S_AXIS_TDATA.setimmediatevalue(0)
        dut.S_AXIS_TKEEP.setimmediatevalue(0)
        dut.S_AXIS_TLAST.setimmediatevalue(0)
        dut.S_AXIS_TDEST.setimmediatevalue(0)
        dut.S_AXIS_TID.setimmediatevalue(0)
        dut.S_AXIS_TUSER.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(1)
        cocotb.start_soon(self._monitor())

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axisRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axisRst.value = 0
        await self.cycle(3)

    async def _monitor(self):
        while True:
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")
            if int(self.dut.M_AXIS_TVALID.value) and int(self.dut.M_AXIS_TREADY.value):
                self.rx_beats.append(
                    (
                        int(self.dut.M_AXIS_TDATA.value),
                        int(self.dut.M_AXIS_TKEEP.value),
                        int(self.dut.M_AXIS_TLAST.value),
                    )
                )

    async def drive_beat(self, *, data: int, keep: int, last: int):
        self.dut.S_AXIS_TDATA.value = data
        self.dut.S_AXIS_TKEEP.value = keep
        self.dut.S_AXIS_TLAST.value = last
        self.dut.S_AXIS_TVALID.value = 1
        while True:
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")
            if int(self.dut.S_AXIS_TREADY.value):
                break
        self.dut.S_AXIS_TVALID.value = 0


@cocotb.test()
async def contiguous_full_keep_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.drive_beat(data=0x44332211, keep=0xF, last=1)
    await tb.cycle(2)
    assert tb.rx_beats == [(0x44332211, 0xF, 1)]


@pytest.mark.parametrize("parameters", [pytest.param({}, id="contiguous_same_width")])
def test_AxiStreamCompact(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamcompactipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/axi-stream/ip_integrator/AxiStreamCompactIpIntegrator.vhd"],
        },
    )
