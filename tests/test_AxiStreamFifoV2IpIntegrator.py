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

async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    # Debug messages in case it fails
    dut._log.info( f'Found M_TDATA_NUM_BYTES={dut.M_TDATA_NUM_BYTES.value.integer}' )
    dut._log.info( f'Found S_TDATA_NUM_BYTES={dut.S_TDATA_NUM_BYTES.value.integer}' )

    tb = TB(dut)

    id_count = 2**len(tb.source.bus.tid)

    cur_id = 1

    await tb.s_cycle_reset()
    await tb.m_cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_frames = []

    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id
        await tb.source.send(test_frame)

        test_frames.append(test_frame)

        cur_id = (cur_id + 1) % id_count

    for test_frame in test_frames:
        rx_frame = await tb.sink.recv()

        assert rx_frame.tdata == test_frame.tdata
        assert rx_frame.tid == test_frame.tid
        assert rx_frame.tdest == test_frame.tdest
        assert not rx_frame.tuser

    assert tb.sink.empty()

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

def size_list():
    return list(range(1, 32+1))

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
tests_module = 'AxiStreamFifoV2IpIntegrator'

##############################################################################

paramSweep = []
# Sweep through different master/slave data sizes
for sTdataByte in ['2','5','6']:
    for mTdataByte in ['2','5','6']:
        tmpDict = {
          "M_TDATA_NUM_BYTES": mTdataByte,
          "S_TDATA_NUM_BYTES": sTdataByte,
        }
        paramSweep.append(tmpDict)
# Check for the case where the (VALID_THOLD_G=0) and AXI stream frame is buffer than the FIFO
tmpDict = {
  "VALID_THOLD": '0',
  "FIFO_ADDR_WIDTH": '4',
}
paramSweep.append(tmpDict)

##############################################################################

@pytest.mark.parametrize("parameters", paramSweep)
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
        sim_build = f'{tests_dir}/sim_build/{tests_module}.' + ",".join((f"{key}={value}" for key, value in parameters.items())),

        # A dictionary of extra environment variables set in simulator process.
        extra_env=parameters,

        # Select a simulator
        simulator="ghdl",

        # VHDL compile arguments
        vhdl_compile_args = [
            '-fsynopsys',       # use of synopsys package "std_logic_arith" needs the -fsynopsys option
            '-frelaxed-rules',  # -frelaxed-rules option to allow IP integrator attributes
            '-fexplicit',       # When two operators are overloaded, give preference to the explicit declaration (-fexplicit)
            '-Wno-elaboration', # Hide warnings about functions called before elaborated of its body
            '-Wno-hide',        # Declaration of "axiconfig" hides function in AxiPkg.vhd
            '-Wno-specs',       # Warning related to IP skim layers attributes
            '-O2',              # Optimize the generated simulation code for speed (no change to VHDL semantics)
        ]

        ########################################################################
        # Dump waveform to file ($ gtkwave sim_build/path/To/{tests_module}.ghw)
        ########################################################################
        # sim_args =[f'--wave={tests_module}.ghw'],
    )
