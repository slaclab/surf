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
        dut._log.error( f'ERROR - dataIn={hex(dataIn)},dataKIn={hex(dataKIn)}: codeErr={hex(dut.codeErr.value)},dispErr={hex(dut.dispErr.value)}')
        assert False

@cocotb.test()
def dut_tb(dut):

    # Initialize the DUT
    yield dut_init(dut)

    # Sweep through all possible combinations of data codes
    dataKIn = 0
    for dataIn in range(2**10):

        # Load the values
        yield load_value(dut, dataIn, dataKIn)

        # Check the results for errors
        check_result(dut, dataIn, dataKIn)

    # Sweep through the defined Control Code Constants
    dataKIn = 1
    controlCodes = [
        # These symbols are commas, sequences that can be used for word alignment
        0x07C, # 0x07C -> 0x8FC, 0x703
        0x17C, # 0x17C -> 0x2FC, 0xD03
        0x27C, # 0x27C -> 0x4FC, 0xB03
        # These symbols are not commas but can be used for control sequences
        # Technically any K.28.x character is a valid k-char but these are preferred
        0x0BC, # 0x0BC -> 0x683, 0x97C
        0x0DC, # 0x0DC -> 0x643, 0x9BC
        0x13C, # 0x13C -> 0x583, 0xA7C
        0x15C, # 0x15C -> 0xABC, 0x543
        0x19C, # 0x19C -> 0x4C3, 0xB3C
        0x1BC, # 0x1BC -> 0x37C, 0xC83
        0x1DC, # 0x1DC -> 0x3BC, 0xC43
        0x23C, # 0x23C -> 0x383, 0xC7C
        0x25C, # 0x25C -> 0x343, 0xCBC
        0x29C, # 0x29C -> 0x2C3, 0xD3C
        0x2BC, # 0x2BC -> 0x57C, 0xA83
        0x2DC, # 0x2DC -> 0x5BC, 0xA43
        0x33C, # 0x33C -> 0x67C, 0x983
        0x35C, # 0x35C -> 0x6BC, 0x943
    ]
    for dataIn in controlCodes:

        # Load the values
        yield load_value(dut, dataIn, dataKIn)

        # Check the results for errors
        check_result(dut, dataIn, dataKIn)

    dut._log.info("DUT: Passed")

tests_dir = os.path.dirname(__file__)
tests_module = 'LineCode10b12bTb'

@pytest.mark.parametrize(
    "parameters", [
        None
    ])
def test_LineCode10b12bTb(parameters):

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
        sim_build = f'{tests_dir}/sim_build/{tests_module}.',

        # A dictionary of extra environment variables set in simulator process.
        extra_env=parameters,

        # Select a simulator
        simulator="ghdl",

        # use of synopsys package "std_logic_arith" needs the -fsynopsys option
        # When two operators are overloaded, give preference to the explicit declaration (-fexplicit)
        vhdl_compile_args = ['-fsynopsys', '-fexplicit'],

        # Dump waveform to file ($ gtkwave sim_build/LineCode12b14bTb./LineCode12b14bTb.vcd)
        sim_args =[f'--vcd={tests_module}.vcd'],
    )
