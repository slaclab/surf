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
# - Sweep: Keep one common-clock direct wrapper around `Pgp4RxEb`.
# - Stimulus: Drive one valid SKP k-code and one bad CRC-marked k-code into
#   the elastic-buffer input.
# - Checks: SKP must update `remLinkData` without triggering an error, and the
#   bad k-code must pulse `linkError`.
# - Timing: Each stimulus is separated by a few wrapper clock cycles so the
#   FIFO and synchronizer paths can settle.

import cocotb
import pytest

from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import parameter_case, start_lockstep_clocks
from tests.protocols.pgp.pgp4.pgp4_test_utils import (
    PGP4_K_HEADER,
    pgp4_idle_word,
    pgp4_skip_word,
    signal_int,
)
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        start_lockstep_clocks(dut.phyClk, dut.pgpClk, period_ns=5.0)

    async def cycle(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.phyClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.rst.setimmediatevalue(1)
        await self.cycle(4)
        self.dut.rst.value = 0
        await self.cycle(4)


async def wait_for_signal(tb: TB, name: str, value: int = 1, cycles: int = 256):
    for _ in range(cycles):
        if signal_int(tb.dut, name) == value:
            return
        await tb.cycle()
    raise AssertionError(f"Timed out waiting for {name}={value}")


async def send_phy_word(tb: TB, *, header: int, data: int):
    tb.dut.phyRxHeader.value = header
    tb.dut.phyRxData.value = data
    tb.dut.phyRxValid.value = 1
    await tb.cycle()
    tb.dut.phyRxValid.value = 0


@cocotb.test()
async def pgp4_rx_eb_filters_special_words(dut):
    tb = TB(dut)
    dut.phyRxValid.setimmediatevalue(0)
    dut.phyRxData.setimmediatevalue(0)
    dut.phyRxHeader.setimmediatevalue(0)
    await tb.reset()

    skip_data = 0x123456789ABC
    await send_phy_word(tb, header=PGP4_K_HEADER, data=pgp4_skip_word(skip_data))
    await tb.cycle(32)
    assert signal_int(dut, "remLinkData") == skip_data
    assert signal_int(dut, "linkError") == 0

    bad_idle = pgp4_idle_word(rem_link_ready=1) ^ (1 << 48)
    await send_phy_word(tb, header=PGP4_K_HEADER, data=bad_idle)
    await wait_for_signal(tb, "linkError")


PARAMETER_SWEEP = [parameter_case("common_clock_direct_wrapper")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4RxEb(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4rxebwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4RxEbWrapper.vhd",
        extra_env=parameters,
    )
