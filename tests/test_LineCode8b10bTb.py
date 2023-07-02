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

# test_DspComparator
from cocotb_test.simulator import run
import pytest
import glob
import os

@cocotb.coroutine
def dut_init(dut):

    # Initialize the inputs
    dut.rst.value     = 1
    dut.validIn.value = 0
    dut.dataIn.value  = 0
    dut.dataKIn.value = 0

    # Start clock (200 MHz) in a separate thread
    cocotb.start_soon(Clock(dut.clk, 5.0, units='ns').start())

    # Wait 5 clock cycle
    for i in range(5):
        yield RisingEdge(dut.clk)

    # De-assert the reset
    dut.rst.value = 0

    # Wait 1 clock cycle
    yield RisingEdge(dut.clk)

@cocotb.coroutine
def load_value(dut, dataIn, dataKIn):

    # Load the values
    dut.dataIn.value  = dataIn
    dut.dataKIn.value = dataKIn

    # Assert valid flag
    dut.validIn.value = 1

    # Wait 1 clock cycle
    yield RisingEdge(dut.clk)

    # De-assert valid flag
    dut.validIn.value = 0

    # Wait for the result
    while ( dut.validOut.value != 1 ):
        yield RisingEdge(dut.clk)


def check_result(dut, dataIn, dataKIn):
    # Check (dataIn = dataOut) or (dataKIn = dataKOut) result
    if (dataIn != dut.dataOut.value) or (dataKIn != dut.dataKOut.value):
        dut._log.error( f'dataIn={hex(dataIn)},dataKIn={hex(dataKIn)} but got dataOut={hex(dut.dataOut.value)},dataKOut={hex(dut.dataKOut.value)}')
        assert False

    # Check (codeErr = 0) or (dispErr = 0) result
    if (dut.codeErr.value != 0) or (dut.dispErr.value != 0):
        dut._log.error( f'ERROR: codeErr={hex(dut.codeErr.value)},dispErr={hex(dut.dispErr.value)}')
        assert False

@cocotb.test()
def dut_tb(dut):

    # Initialize the DUT
    yield dut_init(dut)

    # Read the parameters back from the DUT to set up our model
    width = dut.NUM_BYTES_G.value.integer
    dut._log.info( f'Found NUM_BYTES_G={width}' )

    # Sweep through all possible combinations of data codes
    dataKIn = 0
    for dataIn in range(2**(8*width)):

        # Load the values
        yield load_value(dut, dataIn, dataKIn)

        # Check the results for errors
        check_result(dut, dataIn, dataKIn)

    # Sweep through the defined Control Code Constants
    dataKIn = 1
    controlCodes = [
        0x1C, # K28.0, 0x1C
        0x3C, # K28.1, 0x3C (Comma)
        0x5C, # K28.2, 0x5C
        0x7C, # K28.3, 0x7C
        0x9C, # K28.4, 0x9C
        0xBC, # K28.5, 0xBC (Comma)
        0xDC, # K28.6, 0xDC
        0xFC, # K28.7, 0xFC (Comma)
        0xF7, # K23.7, 0xF7
        0xFB, # K27.7, 0xFB
        0xFD, # K29.7, 0xFD
        0xFE, # K30.7, 0xFE
    ]
    for dataIn in controlCodes:

        # Load the values
        yield load_value(dut, dataIn, dataKIn)

        # Check the results for errors
        check_result(dut, dataIn, dataKIn)

    dut._log.info("DUT: Passed")

tests_dir = os.path.dirname(__file__)
tests_module = 'LineCode8b10bTb'

@pytest.mark.parametrize(
    "parameters", [
        {'NUM_BYTES_G': '1'},  # Test 1 byte interface
        {'NUM_BYTES_G': '2'},  # Test 2 byte interface
    ])
def test_LineCode8b10bTb(parameters):

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

        # Dump waveform to file ($ gtkwave sim_build/LineCode8b10bTb.NUM_BYTES_G\=1/LineCode8b10bTb.vcd)
        sim_args =[f'--vcd={tests_module}.vcd'],
    )
