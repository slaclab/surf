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
# - Sweep: Keep the checked-in wrapper's single-lane direct-transmit shape and
#   run one steady-state handshake sequence.
# - Stimulus: Drive one fixed-width frame word with explicit SOF/EOF markers
#   into the native `Pgp4TxLiteWrapper` pin interface.
# - Checks: The wrapper must accept the input beat and produce protocol output
#   on its native 66-bit side.
# - Timing: Reset is released before traffic, and the bench waits a bounded
#   window for the wrapper to accept the beat and emit output.

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
async def pgp4_tx_lite_direct_wrapper_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.send_single_word_frame(data=0x1122334455667788)

    seen_valid = False
    for _ in range(32):
        await tb.cycle(1)
        if int(dut.phyTxValid.value) == 1:
            seen_valid = True
            assert int(dut.phyTxData.value) != 0
            break
    assert seen_valid


PARAMETER_SWEEP = [parameter_case("direct_wrapper_default")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4TxLite(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4txlitewrapper",
        wrapper_source="protocols/pgp/pgp4/core/rtl/Pgp4TxLiteWrapper.vhd",
        extra_env=parameters,
    )
