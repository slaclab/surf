##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

# test_Saci2ToAxiLiteTb
from cocotb_test.simulator import run
from tests.regression_utils import COMMON_VHDL_COMPILE_ARGS
import pytest
import glob
import os
import itertools
import logging

class TB:
    def __init__(self, dut):

        # Pointer to DUT object
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # Start clock (125 MHz) in a separate thread
        cocotb.start_soon(Clock(dut.S_AXI_ACLK, 8.0, units='ns').start())

        # Create the AXI-Lite Master
        self.axil_master = AxiLiteMaster(
            bus   = AxiLiteBus.from_prefix(dut, 'S_AXI'),
            clock = dut.S_AXI_ACLK,
            reset = dut.S_AXI_ARESETN,
            reset_active_level=False)

    def set_idle_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.aw_channel.set_pause_generator(generator())
            self.axil_master.write_if.w_channel.set_pause_generator(generator())
            self.axil_master.read_if.ar_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.b_channel.set_pause_generator(generator())
            self.axil_master.read_if.r_channel.set_pause_generator(generator())

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


async def run_test_words(dut):

    tb = TB(dut)

    await tb.cycle_reset()

    # Wait for internal reset to fall
    await Timer(10, 'us')

    ########################################################################
    # Positive test coverage:
    # Iterate over all valid high address offsets (0–16) and low word offsets
    # to verify correct AXI-Lite read/write behavior across the full mapped
    # SACI-to-AXI-Lite address space.
    ########################################################################
    for offsetHigh in range(17):
        for offsetLow in range(0, 0xF, 4):
            high = 0
            if offsetHigh != 0:
                high = (1 << (offsetHigh+3))
            addr = high | offsetLow
            test_data = addr.to_bytes(length=4, byteorder='little')

            rsp = await tb.axil_master.write(addr, test_data)
            assert rsp.resp == AxiResp.OKAY

    for offsetHigh in range(17):
        for offsetLow in range(0, 0xF, 4):
            high = 0
            if offsetHigh != 0:
                high = (1 << (offsetHigh+3))
            addr = high | offsetLow
            test_data = addr.to_bytes(length=4, byteorder='little')

            rsp = await tb.axil_master.read(addr, 4)
            assert rsp.resp == AxiResp.OKAY
            assert rsp.data == test_data

    ########################################################################
    # Negative test: access an unmapped/invalid AXI-Lite address and confirm
    # that BOTH the write and read return a non-zero AXI response (error).
    ########################################################################
    bad_addr = 0x0010_0000
    bad_data = (0xFFFFFFFF).to_bytes(length=4, byteorder='little')

    rsp = await tb.axil_master.write(bad_addr, bad_data)
    assert rsp.resp != AxiResp.OKAY

    rsp = await tb.axil_master.read(bad_addr, 4)
    assert rsp.resp != AxiResp.OKAY

    await RisingEdge(dut.S_AXI_ACLK)
    await RisingEdge(dut.S_AXI_ACLK)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


# Prevent pytest from trying to collect cocotb's TestFactory class
TestFactory.__test__ = False

# Safe SIM_NAME access for pytest collection and cocotb 2.x
SIM_NAME = getattr(cocotb, "SIM_NAME", None)
if SIM_NAME:

    #################
    # run_test_words
    #################
    factory = TestFactory(run_test_words)
    factory.generate_tests()

tests_dir = os.path.dirname(__file__)
tests_module = 'Saci2ToAxiLiteTb'

##############################################################################

@pytest.mark.parametrize(
    "parameters", [
        None
    ])
def test_Saci2ToAxiLiteTb(parameters):

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

        # VHDL compile arguments
        vhdl_compile_args=COMMON_VHDL_COMPILE_ARGS,

        ########################################################################
        # Dump waveform to file ($ gtkwave sim_build/path/To/{tests_module}.ghw)
        ########################################################################
        # sim_args =[f'--wave={tests_module}.ghw'],
    )
