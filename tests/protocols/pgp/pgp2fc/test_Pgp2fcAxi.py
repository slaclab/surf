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
# - Sweep: Keep one single-clock writable `Pgp2fcAxi` wrapper instance.
# - Stimulus: Program the writable control registers, then read back both the
#   programmed values and fixed status locations.
# - Checks: The wrapper-exported control outputs and AXI-Lite reads must match
#   the expected register values.
# - Timing: Leave a few cycles after reset and writes for synchronized outputs.

import cocotb
import pytest

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.axil_test_utils import PgpAxiLiteTb
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2fc_axi_register_test(dut):
    tb = PgpAxiLiteTb(dut)
    await tb.reset()
    tb.start_axil_master()
    assert tb.axil is not None

    # Each write here targets one logical control field in the register block.
    await axil_write_u32(tb.axil, 0x04, 0x7)
    await axil_write_u32(tb.axil, 0x08, 0x1)
    await axil_write_u32(tb.axil, 0x0C, 0x3)
    await axil_write_u32(tb.axil, 0x10, 0x15A)
    await axil_write_u32(tb.axil, 0x18, 0x1)
    await tb.cycle(4)

    # Readback checks catch AXI-Lite decode or register-map bugs directly.
    assert await axil_read_u32(tb.axil, 0x04) == 0x7
    assert await axil_read_u32(tb.axil, 0x08) == 0x1
    assert await axil_read_u32(tb.axil, 0x0C) == 0x3
    assert await axil_read_u32(tb.axil, 0x10) == 0x15A
    assert await axil_read_u32(tb.axil, 0x18) == 0x1

    status = await axil_read_u32(tb.axil, 0x20)
    assert (status & 0x1F) == 0x1F
    assert ((status >> 12) & 0xF) == 0b0011
    assert ((status >> 16) & 0xF) == 0b0101
    assert ((status >> 20) & 0xF) == 0b0101
    assert ((status >> 24) & 0xF) == 0b0011
    assert await axil_read_u32(tb.axil, 0x24) == 0x5A

    # Exported wrapper pins should mirror the programmed register fields.
    assert int(dut.resetRxOut.value) == 1
    assert int(dut.resetTxOut.value) == 1
    assert int(dut.resetGtOut.value) == 1
    assert int(dut.flowCntlDisOut.value) == 1
    assert int(dut.loopbackOut.value) == 0b011
    assert int(dut.locDataOut.value) == 0x5A
    assert int(dut.locDataEnOut.value) == 1


PARAMETER_SWEEP = [parameter_case("single_clock_axil")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp2fcAxi(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fcaxiwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcAxiWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
        extra_env=parameters,
    )
