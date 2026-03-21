##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from pathlib import Path

import cocotb
import pytest
from cocotb.triggers import Timer

from tests.common.regression_utils import (
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


class TB:
    def __init__(self, dut):
        self.dut = dut

        # This shim is purely combinational, so initialize the SURF-facing side
        # and then let the test poke values straight through the mapping.
        dut.clk.value = 0
        dut.en.value = 0
        dut.we.value = 0
        dut.rst.value = 0
        dut.addr.value = 0
        dut.din.value = 0
        dut.M_RAM_DOUT.value = 0

    async def settle(self) -> None:
        await Timer(2, unit="ns")


@cocotb.test()
async def surf_to_ipi_mapping_test(dut):
    tb = TB(dut)

    # Drive the SURF-side signals with one recognizable transaction pattern and
    # confirm every IP-integrator-facing output follows it exactly.
    dut.clk.value = 1
    dut.en.value = 1
    dut.we.value = 0b1010
    dut.rst.value = 1
    dut.addr.value = 0x12
    dut.din.value = 0xCAFE_BABE
    await tb.settle()

    assert int(dut.M_RAM_CLK.value) == 1
    assert int(dut.M_RAM_EN.value) == 1
    assert int(dut.M_RAM_WE.value) == 0b1010
    assert int(dut.M_RAM_RST.value) == 1
    assert int(dut.M_RAM_ADDR.value) == 0x12
    assert int(dut.M_RAM_DIN.value) == 0xCAFE_BABE


@cocotb.test()
async def read_data_returns_to_surf_side_test(dut):
    tb = TB(dut)

    # Then drive the BRAM return path and confirm the shim forwards it back to
    # the generic SURF RAM interface without adding state or bit shuffling.
    dut.M_RAM_DOUT.value = 0x1234_5678
    await tb.settle()
    assert int(dut.dout.value) == 0x1234_5678


PARAMETER_SWEEP = [
    parameter_case(
        "baseline_32bit",
        READ_LATENCY="1",
        ADDR_WIDTH="8",
        DATA_WIDTH="32",
    ),
    parameter_case(
        "wider_64bit",
        READ_LATENCY="2",
        ADDR_WIDTH="6",
        DATA_WIDTH="64",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_MasterRamIpIntegrator(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.masterramipintegrator",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": [str(Path("base/general/ip_integrator/MasterRamIpIntegrator.vhd"))]},
    )
