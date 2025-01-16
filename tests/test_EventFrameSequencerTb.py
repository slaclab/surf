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
import cocotb
from cocotb.clock      import Clock
from cocotb.triggers   import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamFrame, AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiLiteBus, AxiLiteMaster

# test_EventFrameSequencerTb
from cocotb_test.simulator import run
import pytest
import glob
import os

# Define a new log level
CUSTOM_LEVEL = 60
logging.addLevelName(CUSTOM_LEVEL, "CUSTOM")

def custom(self, message, *args, **kwargs):
    if self.isEnabledFor(CUSTOM_LEVEL):
        self._log(CUSTOM_LEVEL, message, args, **kwargs)

# Add the custom level to the logging.Logger class
logging.Logger.custom = custom

class TB:
    def __init__(self, dut):

        # Pointer to DUT object
        self.dut = dut

        self.log = logging.getLogger('cocotb.tb')
        self.log.setLevel(logging.DEBUG)

        # Start AXIS_ACLK clock (100 MHz) in a separate thread
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 10.0, units='ns').start())

        # Setup the AXI stream source
        self.sources = [None for _ in range(2)]
        for i in range(2):
            self.sources[i] = AxiStreamSource(
                bus   = AxiStreamBus.from_prefix(dut, f'S_AXIS{i}'),
                clock = dut.AXIS_ACLK,
                reset = dut.AXIS_ARESETN,
                reset_active_level = False,
            )

        # Setup the AXI stream sink
        self.sinks = [None for _ in range(2)]
        for i in range(2):
            self.sinks[i] = AxiStreamSink(
                bus   = AxiStreamBus.from_prefix(dut, f'M_AXIS{i}'),
                clock = dut.AXIS_ACLK,
                reset = dut.AXIS_ARESETN,
                reset_active_level = False,
            )

        # Create the AXI-Lite Master
        self.axil_master = AxiLiteMaster(
            bus   = AxiLiteBus.from_prefix(dut, 'S_AXIL'),
            clock = dut.AXIS_ACLK,
            reset = dut.AXIS_ARESETN,
            reset_active_level=False)

    async def cycle_reset(self):
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        await RisingEdge(self.dut.AXIS_ACLK)
        await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 0
        await RisingEdge(self.dut.AXIS_ACLK)
        await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        await RisingEdge(self.dut.AXIS_ACLK)
        await RisingEdge(self.dut.AXIS_ACLK)

async def run_test(dut):

    tb = TB(dut)
    await tb.cycle_reset()

    # Byte sweeping to check for corner cases
    for x in range(8):

        # Generate the transition data frame
        trans_frame = AxiStreamFrame(bytearray(list(range(0+x, 16))))
        trans_frame.tdest = 0x0
        trans_frame.tuser = x

        # Generate the payload data frames
        test_frames = [None for _ in range(2)]
        for i in range(2):
            test_frames[i] = AxiStreamFrame(bytearray(list(range(1+i+x, 16+1))))
            test_frames[i].tdest = i+1
            test_frames[i].tuser = x

        # Send the transition frame
        await tb.sources[0].send(trans_frame)
        tb.log.custom( f'trans_frame.tdata={trans_frame.tdata}' )
        tb.log.custom( f'trans_frame.tdest={trans_frame.tdest}' )
        tb.log.custom( f'trans_frame.tuser={trans_frame.tuser}' )

        # Received the transition frame
        rx_frame = await tb.sinks[0].recv()
        tb.log.custom( f'rx_frame.tdata={rx_frame.tdata}' )
        tb.log.custom( f'rx_frame.tdest={rx_frame.tdest}' )
        tb.log.custom( f'rx_frame.tuser={rx_frame.tuser}' )
        assert rx_frame.tdata == trans_frame.tdata
        assert rx_frame.tdest == trans_frame.tdest
        assert rx_frame.tuser == trans_frame.tuser
        assert tb.sinks[0].empty()

        # Send the payload data frames
        for i in range(2):
            tb.log.custom( f'test_frames[{i}].tdata={test_frames[i].tdata}' )
            tb.log.custom( f'test_frames[{i}].tdest={test_frames[i].tdest}' )
            tb.log.custom( f'test_frames[{i}].tuser={test_frames[i].tuser}' )
            await tb.sources[i].send(test_frames[i])

        # Received the payload data frame
        for i in range(2):
            rx_frame = await tb.sinks[i].recv()
            tb.log.custom( f'rx_frame.tdata={rx_frame.tdata}' )
            tb.log.custom( f'rx_frame.tdest={rx_frame.tdest}' )
            tb.log.custom( f'rx_frame.tuser={rx_frame.tuser}' )
            assert rx_frame.tdata == test_frames[i].tdata
            assert rx_frame.tdest == test_frames[i].tdest
            assert rx_frame.tuser == test_frames[i].tuser
            assert tb.sinks[i].empty()

if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()

tests_dir = os.path.dirname(__file__)
tests_module = 'EventFrameSequencerTb'

##############################################################################

@pytest.mark.parametrize(
    "parameters", [
        None
    ])
def test_EventFrameSequencerTb(parameters):

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
        sim_args =[f'--wave={tests_module}.ghw'],
    )
