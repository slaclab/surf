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
    for dataIn in range(2**12):

        # Load the values
        yield load_value(dut, dataIn, dataKIn)

        # Check the results for errors
        check_result(dut, dataIn, dataKIn)

    # Sweep through the defined Control Code Constants
    dataKIn = 1
    controlCodes = [
        # -------------------------------------------------------------------------------------------------
        # -- Constants for K codes
        # -- These are intended for public use
        # -------------------------------------------------------------------------------------------------
        0x078, # constant K_120_0_C  : slv(11 downto 0) := "000001111000";
        0x0F8, # constant K_120_1_C  : slv(11 downto 0) := "000011111000";
        0x178, # constant K_120_2_C  : slv(11 downto 0) := "000101111000";
        0x1F8, # constant K_120_3_C  : slv(11 downto 0) := "000111111000";
        0x278, # constant K_120_4_C  : slv(11 downto 0) := "001001111000";
        0x3F8, # constant K_120_7_C  : slv(11 downto 0) := "001111111000";
        0x478, # constant K_120_8_C  : slv(11 downto 0) := "010001111000";
        0x5F8, # constant K_120_11_C : slv(11 downto 0) := "010111111000";
        # --   constant K_120_15_C : slv(11 downto 0) := "011111111000";
        0x878, # constant K_120_16_C : slv(11 downto 0) := "100001111000";
        0x9F8, # constant K_120_19_C : slv(11 downto 0) := "100111111000";
        0xBF8, # constant K_120_23_C : slv(11 downto 0) := "101111111000";
        0xC78, # constant K_120_24_C : slv(11 downto 0) := "110001111000";
        0xDF8, # constant K_120_27_C : slv(11 downto 0) := "110111111000";
        0xEF8, # constant K_120_29_C : slv(11 downto 0) := "111011111000";
        0xF78, # constant K_120_30_C : slv(11 downto 0) := "111101111000";
        0xFF8, # constant K_120_31_C : slv(11 downto 0) := "111111111000";
        # --    constant K_55_15_C  : slv(11 downto 0) := "011110110111";
        # --    constant K_57_15_C  : slv(11 downto 0) := "011110111001";
        # --    constant K_87_15_C  : slv(11 downto 0) := "011111010111";
        # --    constant K_93_15_C  : slv(11 downto 0) := "011111011101";
        # --    constant K_117_15_C : slv(11 downto 0) := "011111110101";
    ]
    for dataIn in controlCodes:

        # Load the values
        yield load_value(dut, dataIn, dataKIn)

        # Check the results for errors
        check_result(dut, dataIn, dataKIn)

    testPattern = [
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x078,1],
       [0x5F8,1],
       [0xEAD,0],
       [0x0BD,0],
       [0xEAD,0],
       [0x1BD,0],
       [0xEAD,0],
       [0x2BD,0],
       [0xEAD,0],
       [0x3BD,0],
       [0xEAD,0],
       [0x4BD,0],
       [0xEAD,0],
       [0x5BD,0],
       [0xEAD,0],
       [0x6BD,0],
       [0xEAD,0],
       [0x7BD,0],
       [0xEAD,0],
       [0x8BD,0],
       [0xEAD,0],
       [0x9BD,0],
       [0xEAD,0],
       [0xABD,0],
       [0xEAD,0],
       [0xBBD,0],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
       [0x5F8,1],
    ]
    for dataIn,dataKIn in testPattern:

        # Load the values
        yield load_value(dut, dataIn, dataKIn)

        # Check the results for errors
        check_result(dut, dataIn, dataKIn)

    dut._log.info("DUT: Passed")

tests_dir = os.path.dirname(__file__)
tests_module = 'LineCode12b14bTb'

@pytest.mark.parametrize(
    "parameters", [
        None
    ])
def test_LineCode12b14bTb(parameters):

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
        # When two operators are overloaded, give preference to the explicit declaration (-fexplicit)
        vhdl_compile_args = ['-fsynopsys', '-fexplicit'],

        ########################################################################
        # Dump waveform to file ($ gtkwave sim_build/path/To/{tests_module}.ghw)
        ########################################################################
        # sim_args =[f'--wave={tests_module}.ghw'],
    )
