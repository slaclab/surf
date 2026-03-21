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

        # Like the master-facing shim, this module is just wiring plus IP
        # integrator attributes, so no clocked driver is needed here.
        dut.S_RAM_CLK.value = 0
        dut.S_RAM_EN.value = 0
        dut.S_RAM_WE.value = 0
        dut.S_RAM_RST.value = 0
        dut.S_RAM_ADDR.value = 0
        dut.S_RAM_DIN.value = 0
        dut.dout.value = 0

    async def settle(self) -> None:
        await Timer(2, unit="ns")


@cocotb.test()
async def ipi_to_surf_mapping_test(dut):
    tb = TB(dut)

    # Present one BRAM transaction on the IP-integrator-facing side and make
    # sure the generic SURF RAM outputs mirror it exactly.
    dut.S_RAM_CLK.value = 1
    dut.S_RAM_EN.value = 1
    dut.S_RAM_WE.value = 0b0011
    dut.S_RAM_RST.value = 1
    dut.S_RAM_ADDR.value = 0x15
    dut.S_RAM_DIN.value = 0x89AB_CDEF
    await tb.settle()

    assert int(dut.clk.value) == 1
    assert int(dut.en.value) == 1
    assert int(dut.we.value) == 0b0011
    assert int(dut.rst.value) == 1
    assert int(dut.addr.value) == 0x15
    assert int(dut.din.value) == 0x89AB_CDEF


@cocotb.test()
async def surf_read_data_returns_to_ipi_test(dut):
    tb = TB(dut)

    # The only reverse-direction payload path is `dout`, so verify that one
    # path explicitly instead of assuming the pass-through is symmetric.
    dut.dout.value = 0x0BAD_F00D
    await tb.settle()
    assert int(dut.S_RAM_DOUT.value) == 0x0BAD_F00D


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
def test_SlaveRamIpIntegrator(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.slaveramipintegrator",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": [str(Path("base/general/ip_integrator/SlaveRamIpIntegrator.vhd"))]},
    )
