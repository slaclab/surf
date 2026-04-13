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
# - Sweep: Keep one small tap configuration and exercise both coefficient-init
#   use and runtime coefficient updates rather than building a width matrix.
# - Stimulus: Drive signed samples and cascade values into the tap, first using
#   the generic coefficient and then loading a new coefficient through the
#   `coeffce` path.
# - Checks: The registered cascade output must equal `cascin + datain*coeff`
#   with signed arithmetic, and a disabled cycle must hold the previous
#   accumulator value.
# - Timing: The bench samples the output one cycle after each enabled update,
#   which is the tap's only visible state transition.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import run_surf_vhdl_test
from tests.dsp.generic.dsp_test_utils import tick, to_unsigned, truncate_signed


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.data_width = len(dut.datain)
        self.coeff_width = len(dut.coeffin)
        self.casc_width = len(dut.cascin)

        cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())
        dut.en.setimmediatevalue(0)
        dut.datain.setimmediatevalue(0)
        dut.coeffin.setimmediatevalue(0)
        dut.coeffce.setimmediatevalue(0)
        dut.cascin.setimmediatevalue(0)

    async def cycle(self, count=1):
        await tick(self.dut.clk, count=count)

    def observed(self) -> int:
        return truncate_signed(int(self.dut.cascout.value), self.casc_width)


@cocotb.test()
async def coefficient_init_and_hold_test(dut):
    tb = TB(dut)
    await tb.cycle(2)

    # Use the generic coefficient first so the bench proves the tap does not
    # require an explicit runtime load before it can accumulate data.
    dut.en.value = 1
    dut.datain.value = to_unsigned(3, tb.data_width)
    dut.cascin.value = to_unsigned(5, tb.casc_width)
    await tb.cycle(1)
    assert tb.observed() == 11

    # Hold the tap disabled with changing inputs so the accumulator output
    # remains parked instead of re-evaluating combinatorially.
    dut.en.value = 0
    dut.datain.value = to_unsigned(-2, tb.data_width)
    dut.cascin.value = to_unsigned(7, tb.casc_width)
    await tb.cycle(1)
    assert tb.observed() == 11


@cocotb.test()
async def coefficient_update_test(dut):
    tb = TB(dut)
    await tb.cycle(1)

    # Load a new runtime coefficient, then use it on the next enabled sample.
    dut.coeffin.value = to_unsigned(-3, tb.coeff_width)
    dut.coeffce.value = 1
    await tb.cycle(1)
    dut.coeffce.value = 0

    dut.en.value = 1
    dut.datain.value = to_unsigned(-4, tb.data_width)
    dut.cascin.value = to_unsigned(6, tb.casc_width)
    await tb.cycle(1)
    assert tb.observed() == 18


@cocotb.test()
async def simultaneous_coeff_load_applies_next_cycle_test(dut):
    tb = TB(dut)
    await tb.cycle(1)

    # This primitive has no reset, and cocotb runs the tap tests in one
    # simulator process. Preload a known old coefficient first so this test
    # does not depend on whatever the previous test left in the tap register.
    dut.coeffin.value = to_unsigned(2, tb.coeff_width)
    dut.coeffce.value = 1
    dut.en.value = 0
    await tb.cycle(1)

    # The tap registers the new coefficient through `coeffce`, but the enabled
    # multiply-accumulate for that cycle still uses the previously registered
    # coefficient. The new coefficient applies on the next enabled sample.
    dut.coeffin.value = to_unsigned(-3, tb.coeff_width)
    dut.coeffce.value = 1
    dut.en.value = 1
    dut.datain.value = to_unsigned(4, tb.data_width)
    dut.cascin.value = to_unsigned(1, tb.casc_width)
    await tb.cycle(1)
    assert tb.observed() == 9

    dut.coeffce.value = 0
    dut.datain.value = to_unsigned(4, tb.data_width)
    dut.cascin.value = to_unsigned(1, tb.casc_width)
    await tb.cycle(1)
    assert tb.observed() == -11


@pytest.mark.parametrize("parameters", [pytest.param({}, id="tap_core")])
def test_FirFilterTap(parameters):
    wrapper_name = "FirFilterTapTestWrapper"
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel=f"surf.{wrapper_name.lower()}",
        parameters=None,
        extra_env={
            "DATA_WIDTH_G": "6",
            "COEFF_WIDTH_G": "5",
            "CASC_WIDTH_G": "12",
        },
        extra_vhdl_sources={
            "surf": [
                "dsp/generic/fixed/FirFilterTap.vhd",
                "dsp/generic/wrappers/FirFilterTapTestWrapper.vhd",
            ]
        },
    )
