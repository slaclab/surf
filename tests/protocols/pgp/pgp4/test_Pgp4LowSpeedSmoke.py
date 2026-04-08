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
# - Sweep: Elaborate one single-lane `Pgp4RxLiteLowSpeedLane` wrapper and one
#   single-lane `Pgp4LiteRxLowSpeed` wrapper in simulation mode.
# - Stimulus: Hold the serialized data input at a benign constant pattern while
#   clocks and resets toggle for a short smoke run.
# - Checks: Each wrapper must elaborate, leave reset cleanly, and run several
#   cycles without assertion failures.
# - Timing: The bench drives a shared deserializer/AXI-Lite clock and waits a
#   few cycles after reset release before ending the smoke run.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


@cocotb.test()
async def low_speed_smoke_test(dut):
    cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())
    dut.rst.setimmediatevalue(1)
    dut.deserData.setimmediatevalue(0xBC)

    for _ in range(4):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

    dut.rst.value = 0

    for _ in range(16):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")


PARAMETER_SWEEP = [
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp4rxlitelowspeedlanesmokewrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp4/core/wrappers/Pgp4RxLiteLowSpeedLaneSmokeWrapper.vhd",
        },
        id="lane_smoke",
    ),
    pytest.param(
        {
            "TOPLEVEL": "surf.pgp4literxlowspeedsmokewrapper",
            "WRAPPER_SOURCE": "protocols/pgp/pgp4/core/wrappers/Pgp4LiteRxLowSpeedSmokeWrapper.vhd",
        },
        id="top_smoke",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4LowSpeedSmoke(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel=parameters["TOPLEVEL"],
        wrapper_source=parameters["WRAPPER_SOURCE"],
        extra_env=parameters,
    )
