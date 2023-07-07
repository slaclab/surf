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
from cocotbext.axi     import AxiLiteBus, AxiLiteMaster, AxiResp
from cocotb.regression import TestFactory

# test_AxiVersionIpIntegrator
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

        # Start clock (125 MHz) in a separate thread
        cocotb.start_soon(Clock(dut.S_AXI_ACLK, 8.0, units='ns').start())

        # Create the AXI-Lite Master
        self.axil = AxiLiteMaster(
            bus   = AxiLiteBus.from_prefix(dut, 'S_AXI'),
            clock = dut.S_AXI_ACLK,
            reset = dut.S_AXI_ARESETN,
            reset_active_level=False)

    async def cycle_reset(self):
        self.dut.S_AXI_ARESETN.setimmediatevalue(0)
        await RisingEdge(self.dut.S_AXI_ACLK)
        await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 0
        await RisingEdge(self.dut.S_AXI_ACLK)
        await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 1
        await RisingEdge(self.dut.S_AXI_ACLK)
        await RisingEdge(self.dut.S_AXI_ACLK)

async def dut_tb(dut):

    # Initialize the DUT
    tb = TB(dut)

    # Reset DUT
    await tb.cycle_reset()

    # Get the FpgaVersion register
    rdTxn = await tb.axil.read(address=0x000, length=4)
    assert rdTxn.resp == AxiResp.OKAY
    print( f'FpgaVersion={hex(int.from_bytes(rdTxn.data, byteorder="little"))}' )

    # Test the scratchpad write/read operations
    testWord = int(random.getrandbits(32)).to_bytes(4, "little")
    wrTxn = await tb.axil.write(address=0x004, data=testWord)
    assert wrTxn.resp == AxiResp.OKAY
    rdTxn = await tb.axil.read(address=0x004, length=4)
    assert rdTxn.resp == AxiResp.OKAY
    assert rdTxn.data == testWord

    # Get the BuildStamp string
    rdTxn = await tb.axil.read(address=0x800, length=256)
    assert rdTxn.resp == AxiResp.OKAY
    buildString = rdTxn.data.decode('utf-8')
    print( f'buildString={buildString}' )

if cocotb.SIM_NAME:
    factory = TestFactory(dut_tb)
    factory.generate_tests()

tests_dir = os.path.dirname(__file__)
tests_module = 'AxiVersionIpIntegrator'

@pytest.mark.parametrize(
    "parameters", [
        {'EN_ERROR_RESP': 'true', },  # Enable bus response
    ])
def test_AxiVersionIpIntegrator(parameters):

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
        vhdl_compile_args = ['-fsynopsys','-frelaxed-rules'],

        # Dump waveform to file ($ gtkwave sim_build/AxiVersionIpIntegrator/AxiVersionIpIntegrator.vcd)
        sim_args =[f'--vcd={tests_module}.vcd'],
    )
