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
import logging
import random
import cocotb
from cocotb.clock      import Clock
from cocotb.triggers   import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamFrame, AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor

# test_AxiStreamFifoV2IpIntegrator
from cocotb_test.simulator import run
import pytest
import glob
import os

class TB:
    def __init__(self, dut):

        # Pointer to DUT object
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # Start S_AXIS_ACLK clock (200 MHz) in a separate thread
        cocotb.start_soon(Clock(dut.S_AXIS_ACLK, 5.0, units='ns').start())
        
        # Start M_AXIS_ACLK clock (200 MHz) in a separate thread
        cocotb.start_soon(Clock(dut.M_AXIS_ACLK, 5.0, units='ns').start())        

        # Setup the AXI stream source
        self.source = AxiStreamSource(
            bus   = AxiStreamBus.from_prefix(dut, "S_AXIS"), 
            clock = dut.S_AXIS_ACLK, 
            reset = dut.S_AXIS_ARESETN,
            reset_active_level = False,
        )
        
        # Setup the AXI stream sink
        self.sink = AxiStreamSink(
            bus   = AxiStreamBus.from_prefix(dut, "M_AXIS"), 
            clock = dut.M_AXIS_ACLK, 
            reset = dut.M_AXIS_ARESETN,
            reset_active_level = False,
        )        

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

    async def s_cycle_reset(self):
        self.dut.S_AXIS_ARESETN.setimmediatevalue(0)
        await RisingEdge(self.dut.S_AXIS_ACLK)
        await RisingEdge(self.dut.S_AXIS_ACLK)
        self.dut.S_AXIS_ARESETN.value = 0
        await RisingEdge(self.dut.S_AXIS_ACLK)
        await RisingEdge(self.dut.S_AXIS_ACLK)
        self.dut.S_AXIS_ARESETN.value = 1
        await RisingEdge(self.dut.S_AXIS_ACLK)
        await RisingEdge(self.dut.S_AXIS_ACLK)
        
    async def m_cycle_reset(self):
        self.dut.M_AXIS_ARESETN.setimmediatevalue(0)
        await RisingEdge(self.dut.M_AXIS_ACLK)
        await RisingEdge(self.dut.M_AXIS_ACLK)
        self.dut.M_AXIS_ARESETN.value = 0
        await RisingEdge(self.dut.M_AXIS_ACLK)
        await RisingEdge(self.dut.M_AXIS_ACLK)
        self.dut.M_AXIS_ARESETN.value = 1
        await RisingEdge(self.dut.M_AXIS_ACLK)
        await RisingEdge(self.dut.M_AXIS_ACLK)        

async def dut_tb(dut):

    # Initialize the DUT
    tb = TB(dut)

    # Reset DUT
    await tb.s_cycle_reset()
    await tb.m_cycle_reset()

if cocotb.SIM_NAME:
    factory = TestFactory(dut_tb)
    factory.generate_tests()

tests_dir = os.path.dirname(__file__)
tests_module = 'AxiStreamFifoV2IpIntegrator'

@pytest.mark.parametrize(
    "parameters", [
        {'S_TDATA_NUM_BYTES': '1', },
    ])
def test_AxiStreamFifoV2IpIntegrator(parameters):

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

        # use of synopsys package "std_logic_arith" needs the -fsynopsys option
        # -frelaxed-rules option to allow IP integrator attributes
        # When two operators are overloaded, give preference to the explicit declaration (-fexplicit)
        vhdl_compile_args = ['-fsynopsys','-frelaxed-rules', '-fexplicit'],

        # Select a simulator
        simulator="ghdl",

        # # Dump waveform to file ($ gtkwave sim_build/AxiStreamFifoV2IpIntegrator/AxiStreamFifoV2IpIntegrator.vcd)
        # sim_args =[f'--vcd={tests_module}.vcd'],
    )
