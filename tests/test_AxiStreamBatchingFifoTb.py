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
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamFrame, AxiLiteBus, AxiLiteMaster
from cocotb.clock import Clock, Timer

# test_AxiStreamBatchingFifoTb
from cocotb_test.simulator import run
import pytest
import glob
import os

@cocotb.test()
async def dut_tb(dut):
    timeout_us = 3.0
    clk_period_ns = 4.0 # 4ns
    number_of_frames = 7


    source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)
    program = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)

    cocotb.start_soon(Clock(dut.clk, clk_period_ns, "ns").start())

    for i in range(3):
        master_timer = Timer(timeout_us, "us")

        # Assert reset
        dut.rst.value = 1
        await Timer(40, "ns")
        dut.rst.value = 0
        await Timer(40, "ns")

        # Write frame number
        await program.write(0x0, (number_of_frames+i*2).to_bytes(4, "little"))
        await Timer(40, "ns")

        # Read data back
        data = await program.read(0x000, 4)
        dut._log.info(f"Read addr 0x0: {data}")

        # Send 40 frames
        payload = bytearray(list(range(0,64)))
        frame = AxiStreamFrame(payload)
        for i in range(40):
            await source.send(frame)

        await master_timer


tests_dir = os.path.dirname(__file__)
tests_module = 'AxiStreamBatchingFifoTb'

@pytest.mark.parametrize(
    "parameters", [
        None
    ])
def test_AxiStreamBatchingFifoTb(parameters):

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
        sim_args =[f'--wave={tests_module}.ghw'],
    )
