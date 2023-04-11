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
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge

@cocotb.coroutine
def dut_init(dut):

    # Initialize the inputs
    dut.rst.value     = 1
    dut.ibValid.value = 0
    dut.ain.value     = 0
    dut.bin.value     = 0
    dut.obReady.value = 1

    # Initialize the clock (200 MHz)
    cocotb.start_soon(Clock(dut.clk, 5.0, units='ns').start())

    # Wait 1 clock cycle
    yield RisingEdge(dut.clk)

    # De-assert the reset
    dut.rst.value = 0

    # Wait 1 clock cycle
    yield RisingEdge(dut.clk)

@cocotb.coroutine
def load_value(dut, ain, bin):

    # Load the values
    dut.ain.value = ain
    dut.bin.value = bin

    # Assert valid flag
    dut.ibValid.value = 1

    # Wait 1 clock cycle
    yield RisingEdge(dut.clk)

    # De-assert valid flag
    dut.ibValid.value = 0

    # Wait 1 clock cycle
    yield RisingEdge(dut.clk)

@cocotb.test()
def test_DspComparator(dut):

    # Initialize the DUT
    yield dut_init(dut)

    # Read the parameters back from the DUT to set up our model
    width = dut.WIDTH_G.value.integer
    dut._log.info( f'Found WIDTH_G={width}' )

    # Sweep through all possible combinations
    for ain in range(width):
        for bin in range(width):

            # Load the values
            yield load_value(dut, ain, bin)

            # Check (a = b) result
            if ((ain==bin) and (dut.eq.value != 1)) or (not (ain==bin) and (dut.eq.value == 1)):
                dut._log.error( f'ain={ain},bin={bin} but got dut.eq={dut.eq.value}')
                assert False

            # Check (a >  b) result
            if ((ain>bin) and (dut.gt.value != 1)) or (not (ain>bin) and (dut.gt.value == 1)):
                dut._log.error( f'ain={ain},bin={bin} but got dut.gt={dut.gt.value}')
                assert False

            # Check (a >=  b) result
            if ((ain>=bin) and (dut.gtEq.value != 1)) or (not (ain>=bin) and (dut.gtEq.value == 1)):
                dut._log.error( f'ain={ain},bin={bin} but got dut.gtEq={dut.gtEq.value}')
                assert False

            # Check (a <  b) result
            if ((ain<bin) and (dut.ls.value != 1)) or (not (ain<bin) and (dut.ls.value == 1)):
                dut._log.error( f'ain={ain},bin={bin} but got dut.ls={dut.ls.value}')
                assert False

            # Check (a <=  b) result
            if ((ain<=bin) and (dut.lsEq.value != 1)) or (not (ain<=bin) and (dut.lsEq.value == 1)):
                dut._log.error( f'ain={ain},bin={bin} but got dut.gtEq={dut.lsEq.value}')
                assert False

    dut._log.info("DUT: Passed")
