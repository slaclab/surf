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
from cocotb.triggers import RisingEdge

# test_HammingEccTb
from cocotb_test.simulator import run
import pytest
import glob
import os

@cocotb.test()
async def dut_tb(dut):
    """Waits for either simulation 'passed' or 'failed' signal"""
    # Wait for reset deassertion
    while dut.rst.value == 1:
        await RisingEdge(dut.clk)

    timeout_us = 1000.0 # 1ms
    clk_period_ns = 4.0 # 4ns
    timeout_ticks = int(timeout_us * 1000.0 / clk_period_ns)

    for _ in range(timeout_ticks):
        await RisingEdge(dut.clk)
        if dut.passed.value == 1:
            dut._log.info("DUT: Passed")
            break
        elif dut.failed.value == 1:
            dut._log.error("DUT: Failed")
            assert False

    if dut.passed.value != 1:
        dut._log.error("DUT: Simulation did not complete in time")
        assert False

tests_dir = os.path.dirname(__file__)
tests_module = 'HammingEccTb'

@pytest.mark.parametrize(
    "parameters", [
        None
    ])
def test_HammingEccTb(parameters):

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

        # Select a simulator
        simulator="ghdl",

        # use of synopsys package "std_logic_arith" needs the -fsynopsys option
        # -frelaxed-rules option to allow IP integrator attributes
        # When two operators are overloaded, give preference to the explicit declaration (-fexplicit)
        vhdl_compile_args = ['-fsynopsys','-frelaxed-rules', '-fexplicit'],

        ########################################################################
        # Dump waveform to file ($ gtkwave sim_build/path/To/{tests_module}.ghw)
        ########################################################################
        # sim_args =[f'--wave={tests_module}.ghw'],
    )
