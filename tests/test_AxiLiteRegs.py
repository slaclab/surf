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
import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge

# test_AxiLiteRegs
from cocotb_test.simulator import run
import pytest
import glob
import os

@cocotb.coroutine
def dut_init(dut):

    # Initialize the inputs
    dut.axiClkRst.value     = 1

    # Start clock (200 MHz) in a separate thread
    cocotb.start_soon(Clock(dut.axiClk, 5.0, units='ns').start())

    # Wait 1 clock cycle
    yield RisingEdge(dut.axiClk)

    # De-assert the reset
    dut.axiClkRst.value = 0

    # Wait 1 clock cycle
    yield RisingEdge(dut.axiClk)

@cocotb.coroutine
def load_value(dut, ain, bin):

    # Wait 1 clock cycle
    yield RisingEdge(dut.axiClk)

@cocotb.test()
def dut_tb(dut):

    # Initialize the DUT
    yield dut_init(dut)

    ###################################################
    # Waiting for record type support for CocoTB + GHDL
    ###################################################
    # https://github.com/ghdl/ghdl/issues/2324
    ###################################################

    dut._log.info("DUT: Passed")

tests_dir = os.path.dirname(__file__)
tests_module = 'AxiLiteRegs'

@pytest.mark.parametrize(
    "parameters", [None]
    )
def test_AxiLiteRegs(parameters):

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
        vhdl_sources = {
            'surf'   : glob.glob(f'{tests_dir}/../build/SRC_VHDL/surf/*'),
            'ruckus' : glob.glob(f'{tests_dir}/../build/SRC_VHDL/ruckus/*'),
        },

        # A dictionary of top-level parameters/generics.
        parameters = parameters,

        # The directory used to compile the tests. (default: sim_build)
        sim_build = f'{tests_dir}/sim_build/{tests_module}',

        # A dictionary of extra environment variables set in simulator process.
        extra_env=parameters,

        # Select VHDL-2008 standard
        # use of synopsys package "std_logic_arith" needs the -fsynopsys option
        vhdl_compile_args = ['--std=08', '-fsynopsys'],

        # Select a simulator
        simulator="ghdl",

        # Dump waveform to file ($ gtkwave sim_build/AxiLiteRegs/AxiLiteRegs.vcd)
        sim_args =[f'--vcd={tests_module}.vcd'],
    )
