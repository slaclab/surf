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
# - Sweep: Keep one single-VC common-clock register wrapper with the default
#   writable monitor surface enabled.
# - Stimulus: Read the capability register, then write the control register
#   fields that drive TX disable, flow-control disable, loopback, and resets.
# - Checks: Readback must match the written values and the wrapper-exported
#   control outputs must reflect the programmed register state.
# - Timing: The bench leaves several AXI-Lite clock cycles after reset and each
#   transaction so the synchronized register outputs settle cleanly.

import cocotb
import pytest

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import parameter_case
from tests.protocols.pgp.axil_test_utils import PgpAxiLiteTb
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


@cocotb.test()
async def pgp4_axil_register_test(dut):
    tb = PgpAxiLiteTb(dut)
    await tb.reset()
    tb.start_axil_master()
    assert tb.axil is not None

    # Capability registers are read-only metadata.  Check those first so we
    # know the wrapper started in its expected configuration.
    capabilities = await axil_read_u32(tb.axil, 0x004)
    assert (capabilities & 0x1) == 0x1
    assert ((capabilities >> 8) & 0xFF) == 1

    # The scratch register is useful as a very simple write/read sanity check.
    await axil_write_u32(tb.axil, 0x008, 0x13579BDF)
    assert await axil_read_u32(tb.axil, 0x008) == 0x13579BDF

    # This control word drives several independent output fields.
    await axil_write_u32(tb.axil, 0x00C, 0x7D)
    await tb.cycle(4)

    assert int(dut.txDisableOut.value) == 1
    assert int(dut.flowCntlDisOut.value) == 1
    assert int(dut.resetTxOut.value) == 1
    assert int(dut.resetRxOut.value) == 1
    assert int(dut.loopbackOut.value) == 0b101


PARAMETER_SWEEP = [parameter_case("single_vc_common_clock_axil")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4AxiL(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4axildirectwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4AxiLDirectWrapper.vhd",
        extra_env=parameters,
    )
