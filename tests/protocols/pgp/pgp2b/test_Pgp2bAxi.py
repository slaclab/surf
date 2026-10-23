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
# - Sweep: Keep one single-clock writable `Pgp2bAxi` wrapper instance.
# - Stimulus: Program the writable control registers, then read back both the
#   programmed values and a couple of fixed status locations.
# - Checks: The exported wrapper outputs and AXI-Lite readbacks must match the
#   register values driven through the AXI-Lite slave.
# - Timing: Leave a few cycles after reset and writes for synchronized outputs.

import cocotb
import pytest

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.axil_test_utils import PgpAxiLiteTb
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


@cocotb.test()
async def pgp2b_axi_register_test(dut):
    # `Pgp2bAxi` is a plain AXI-Lite register block.  The helper below owns the
    # clock, reset, and cocotbext AXI-Lite master so this test can read like a
    # short register-programming script instead of simulator setup code.
    tb = PgpAxiLiteTb(dut)
    await tb.reset()
    tb.start_axil_master()
    assert tb.axil is not None

    # Program the writable control surface exactly the way software would.
    await axil_write_u32(tb.axil, 0x04, 0x7)
    await axil_write_u32(tb.axil, 0x0C, 0x5)
    await axil_write_u32(tb.axil, 0x10, 0x1A5)
    await axil_write_u32(tb.axil, 0x18, 0x1)
    await axil_write_u32(tb.axil, 0x1C, 0x4A3F)
    await tb.cycle(4)

    # Read the same locations back first.  This proves the AXI-Lite slave
    # itself is functioning before we inspect the wrapper-exported outputs.
    assert await axil_read_u32(tb.axil, 0x04) == 0x7
    assert await axil_read_u32(tb.axil, 0x0C) == 0x5
    assert await axil_read_u32(tb.axil, 0x10) == 0x1A5
    assert await axil_read_u32(tb.axil, 0x18) == 0x1
    assert await axil_read_u32(tb.axil, 0x1C) == 0x4A3F

    # Then check the fixed status words that the wrapper ties to known inputs.
    status = await axil_read_u32(tb.axil, 0x20)
    assert (status & 0x1F) == 0x1F
    assert ((status >> 8) & 0x3) == 0b10
    assert ((status >> 12) & 0xF) == 0b0101
    assert ((status >> 16) & 0xF) == 0b0011
    assert ((status >> 20) & 0xF) == 0b0011
    assert ((status >> 24) & 0xF) == 0b0101
    assert await axil_read_u32(tb.axil, 0x24) == 0xA5

    # Finally, confirm that the internal register fields actually drive the
    # wrapper outputs that a larger integration would consume.
    assert int(dut.resetRxOut.value) == 1
    assert int(dut.resetTxOut.value) == 1
    assert int(dut.resetGtOut.value) == 1
    assert int(dut.flowCntlDisOut.value) == 1
    assert int(dut.loopbackOut.value) == 0b101
    assert int(dut.locDataOut.value) == 0xA5
    assert int(dut.locDataEnOut.value) == 1
    assert int(dut.txDiffCtrlOut.value) == 0b11111
    assert int(dut.txPreCursorOut.value) == 0b10001
    assert int(dut.txPostCursorOut.value) == 0b10010


PARAMETER_SWEEP = [parameter_case("single_clock_axil")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp2bAxi(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2baxiwrapper",
        wrapper_source="protocols/pgp/pgp2b/core/wrappers/Pgp2bAxiWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2b"),
        extra_env=parameters,
    )
