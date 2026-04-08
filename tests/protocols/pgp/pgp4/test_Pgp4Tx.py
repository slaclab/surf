##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Keep one single-VC direct-transmit wrapper and exercise one steady
#   downstream acceptance sequence.
# - Stimulus: Drive one full-width SSI-style AXI Stream beat into `Pgp4Tx`
#   through a checked-in wrapper with explicit SOF/EOF controls.
# - Checks: The DUT must accept the beat and emit non-zero protocol output on
#   the native 66-bit side.
# - Timing: Reset is released before traffic and the bench waits a bounded
#   window for the transmit output to become valid.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())

    async def cycle(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.rst.setimmediatevalue(1)
        self.dut.txValid.setimmediatevalue(0)
        self.dut.txData.setimmediatevalue(0)
        self.dut.txSof.setimmediatevalue(0)
        self.dut.txEof.setimmediatevalue(0)
        self.dut.txEofe.setimmediatevalue(0)
        self.dut.phyTxReady.setimmediatevalue(1)
        await self.cycle(4)
        self.dut.rst.value = 0
        await self.cycle(4)

    async def send_single_word_frame(self, *, data: int):
        self.dut.txValid.value = 1
        self.dut.txData.value = data
        self.dut.txSof.value = 1
        self.dut.txEof.value = 1
        self.dut.txEofe.value = 0
        for _ in range(64):
            if int(self.dut.txReady.value) == 1:
                break
            await self.cycle(1)
        else:
            raise AssertionError("Timed out waiting for txReady")
        await self.cycle(1)
        self.dut.txValid.value = 0
        self.dut.txSof.value = 0
        self.dut.txEof.value = 0


@cocotb.test()
async def pgp4_tx_direct_wrapper_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.send_single_word_frame(data=0xDEADBEEF12345678)

    seen_valid = False
    for _ in range(1400):
        await tb.cycle(1)
        if int(dut.phyTxValid.value) == 1:
            seen_valid = True
            assert int(dut.phyTxData.value) != 0
            break
    assert seen_valid


PARAMETER_SWEEP = [parameter_case("single_vc_direct_tx")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4Tx(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4txdirectwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4TxDirectWrapper.vhd",
        extra_env=parameters,
    )
