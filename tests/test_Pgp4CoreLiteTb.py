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
import itertools
import logging
import cocotb
from cocotb.clock      import Clock
from cocotb.triggers   import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamFrame, AxiStreamBus, AxiStreamSource, AxiStreamSink

# test_Pgp4CoreLiteTb
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

        # Start AXIS_ACLK clock (200 MHz) in a separate thread
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 5.0, units='ns').start())

        # Setup the AXI stream source
        self.source = AxiStreamSource(
            bus   = AxiStreamBus.from_prefix(dut, "S_AXIS"),
            clock = dut.AXIS_ACLK,
            reset = dut.AXIS_ARESETN,
            reset_active_level = False,
        )

        # Setup the AXI stream sink
        self.sink = AxiStreamSink(
            bus   = AxiStreamBus.from_prefix(dut, "M_AXIS"),
            clock = dut.AXIS_ACLK,
            reset = dut.AXIS_ARESETN,
            reset_active_level = False,
        )

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

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

        # Wait for the PGP link to come up before sending data
        while( self.dut.LINK_READY.value != 1):
            await RisingEdge(self.dut.AXIS_ACLK)


async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_frames = []

    #############################################################
    # Build and send frames
    #############################################################
    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_frame = AxiStreamFrame(test_data)
        await tb.source.send(test_frame)
        test_frames.append(test_frame)

    #############################################################
    # Receive and check frames
    #############################################################
    for test_frame in test_frames:
        rx_frame = await tb.sink.recv()

        # Check data
        assert rx_frame.tdata == test_frame.tdata, \
            f"TDATA mismatch: expected {test_frame.tdata}, got {rx_frame.tdata}"

        # Check data payload size
        assert len(rx_frame.tdata) == len(test_frame.tdata), \
            f"len(TDATA) mismatch: expected {len(test_frame.tdata)}, got {len(rx_frame.tdata)}"

    # Must be empty at the end
    assert tb.sink.empty()

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

def size_list():
    # Sweep AXI-Stream frame sizes from 1 to 256 bytes
    # return list(range(1, 256+1))
    return list(range(1, 4+1))

def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))

if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()

tests_dir = os.path.dirname(__file__)
tests_module = 'Pgp4CoreLiteTb'

##############################################################################

@pytest.mark.parametrize(
    "parameters", [
        None
    ])
def test_Pgp4CoreLiteTb(parameters):

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
