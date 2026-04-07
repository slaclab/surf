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
# - Sweep: Keep one common-clock compact command path to prove the decoder
#   contract before expanding the FIFO configuration matrix.
# - Stimulus: Send one valid four-word command frame and one EOFE-tagged frame
#   through the flattened SSI source interface.
# - Checks: The valid frame must emit the decoded context/opcode pulse, while
#   the EOFE frame must not assert `cmdValid`.
# - Timing: The bench waits for the exported command pulse rather than assuming
#   a fixed FIFO-to-command latency.

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.ssi.ssi_test_utils import FlatSsiEndpoint, SsiBeat, cycle, reset_dut, send_contiguous_frame, start_clock


async def wait_cmd_valid(dut, *, timeout_cycles: int = 32):
    for _ in range(timeout_cycles):
        if int(dut.cmdValid.value) == 1:
            return int(dut.cmdCtx.value), int(dut.cmdOpCode.value)
        await cycle(dut.axisClk)
    raise AssertionError("Timed out waiting for decoded command pulse")


async def expect_no_cmd(dut, *, cycles: int = 12):
    for _ in range(cycles):
        assert int(dut.cmdValid.value) == 0
        await cycle(dut.axisClk)


@cocotb.test()
async def decodes_complete_frame_and_rejects_eofe_frame(dut):
    keep = 0xF

    start_clock(dut.axisClk)
    source = FlatSsiEndpoint(dut, prefix="sAxis")
    dut.axisRst.setimmediatevalue(1)
    source.set_idle()
    await reset_dut(dut)

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x123456AC, keep=keep, last=0, sof=1),
            SsiBeat(data=0x0000005A, keep=keep, last=0),
            SsiBeat(data=0x00000000, keep=keep, last=0),
            SsiBeat(data=0x00000000, keep=keep, last=1),
        ],
        clk=dut.axisClk,
    )

    ctx, opcode = await wait_cmd_valid(dut)
    assert ctx == 0x123456
    assert opcode == 0x5A

    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0xABCDEF10, keep=keep, last=0, sof=1),
            SsiBeat(data=0x0000007C, keep=keep, last=0),
            SsiBeat(data=0x00000000, keep=keep, last=0),
            SsiBeat(data=0x00000000, keep=keep, last=1, eofe=1),
        ],
        clk=dut.axisClk,
    )

    await expect_no_cmd(dut)


@pytest.mark.parametrize("parameters", [pytest.param({}, id="common_clk_default")])
def test_SsiCmdMaster(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssicmdmasterwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiCmdMasterWrapper.vhd"]},
    )
