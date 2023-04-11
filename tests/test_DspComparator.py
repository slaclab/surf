##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# dut_tb
import sys
import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge

# test_DspComparator
from cocotb_test.simulator import run
import pytest
import glob
import os

@cocotb.coroutine
def dut_init(dut):

    # Initialize the inputs
    dut.rst.value     = 1
    dut.ibValid.value = 0
    dut.ain.value     = 0
    dut.bin.value     = 0
    dut.obReady.value = 1

    # Start clock (200 MHz) in a separate thread
    cocotb.start_soon(Clock(dut.clk, 5.0, units='ns').start())

    # Wait 1 clock cycle
    yield RisingEdge(dut.clk)

    # De-assert the reset
    dut.rst.value = 0

    # Wait 1 clock cycle
    yield RisingEdge(dut.clk)

@cocotb.coroutine
def load_value(dut, ain, bin):

    # Load the values
    dut.ain.value = ain
    dut.bin.value = bin

    # Assert valid flag
    dut.ibValid.value = 1

    # Wait 1 clock cycle
    yield RisingEdge(dut.clk)

    # De-assert valid flag
    dut.ibValid.value = 0

    # Wait 1 clock cycle
    yield RisingEdge(dut.clk)

@cocotb.test()
def dut_tb(dut):

    # Initialize the DUT
    yield dut_init(dut)

    # Read the parameters back from the DUT to set up our model
    width = dut.WIDTH_G.value.integer
    dut._log.info( f'Found WIDTH_G={width}' )

    # Sweep through all possible combinations
    for ain in range(width):
        for bin in range(width):

            # Load the values
            yield load_value(dut, ain, bin)

            # Check (a = b) result
            if ((ain==bin) and (dut.eq.value != 1)) or (not (ain==bin) and (dut.eq.value == 1)):
                sys.exit( f'ERROR: ain={ain},bin={bin} but got dut.eq={dut.eq.value}' )

            # Check (a >  b) result
            if ((ain>bin) and (dut.gt.value != 1)) or (not (ain>bin) and (dut.gt.value == 1)):
                sys.exit( f'ERROR: ain={ain},bin={bin} but got dut.gt={dut.gt.value}')

            # Check (a >=  b) result
            if ((ain>=bin) and (dut.gtEq.value != 1)) or (not (ain>=bin) and (dut.gtEq.value == 1)):
                sys.exit( f'ERROR: ain={ain},bin={bin} but got dut.gtEq={dut.gtEq.value}')

            # Check (a <  b) result
            if ((ain<bin) and (dut.ls.value != 1)) or (not (ain<bin) and (dut.ls.value == 1)):
                sys.exit( f'ERROR: ain={ain},bin={bin} but got dut.ls={dut.ls.value}')

            # Check (a <=  b) result
            if ((ain<=bin) and (dut.lsEq.value != 1)) or (not (ain<=bin) and (dut.lsEq.value == 1)):
                sys.exit( f'ERROR: ain={ain},bin={bin} but got dut.gtEq={dut.lsEq.value}')

    dut._log.info("DUT: Passed")




tests_dir = os.path.dirname(__file__)
tests_module = 'DspComparator'

@pytest.mark.parametrize(
    "parameters", [
        {'WIDTH_G': '4'},
        {'WIDTH_G': '8'}
    ])
def test_DspComparator(parameters):

    # https://github.com/themperek/cocotb-test#arguments-for-simulatorrun
    # https://github.com/themperek/cocotb-test/blob/master/cocotb_test/simulator.py
    run(
        # top level HDL
        toplevel = f'surf.{tests_module}'.lower(),

        # name of the file that contains @cocotb.test() -- this file
        # https://docs.cocotb.org/en/stable/building.html?#envvar-MODULE
        module = f'test_{tests_module}',

        # https://docs.cocotb.org/en/stable/building.html?#var-TOPLEVEL_LANG
        toplevel_lang = 'vhdl',

        # VHDL source files to include.
        # Can be specified as a list or as a dict of lists with the library name as key,
        # if the simulator supports named libraries.
        vhdl_sources = {'surf' : glob.glob(f'{tests_dir}/../build/SRC_VHDL/surf/*'),},

        # A dictionary of top-level parameters/generics.
        parameters = parameters,

        # The directory used to compile the tests. (default: sim_build)
        sim_build = f'{tests_dir}/sim_build/{tests_module}.' + ",".join((f"{key}={value}" for key, value in parameters.items())),

        # A dictionary of extra environment variables set in simulator process.
        extra_env=parameters,

        # Select a simulator
        simulator="ghdl",
    )
