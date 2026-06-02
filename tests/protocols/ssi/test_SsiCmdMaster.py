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
from tests.protocols.ssi.ssi_test_utils import (
    SsiBeat,
    cycle,
    send_contiguous_frame,
    setup_flat_ssi_testbench,
    wait_signal_level,
)


async def wait_cmd_valid(dut, *, timeout_cycles: int = 32):
    # The DUT emits a one-cycle decoded-command pulse, so poll each cycle until
    # the pulse appears and then snapshot the decoded fields immediately.
    for _ in range(timeout_cycles):
        if int(dut.cmdValid.value) == 1:
            return int(dut.cmdCtx.value), int(dut.cmdOpCode.value)
        await cycle(dut.axisClk)
    raise AssertionError("Timed out waiting for decoded command pulse")


async def expect_no_cmd(dut, *, cycles: int = 12):
    # Use a bounded quiet window to prove that malformed traffic does not
    # generate a stray decode pulse later.
    for _ in range(cycles):
        assert int(dut.cmdValid.value) == 0
        await cycle(dut.axisClk)


@cocotb.test()
async def decodes_complete_frame_and_rejects_eofe_frame(dut):
    keep = 0xF

    # Start the SSI clock and drive every input to a known reset-time value
    # before releasing reset.
    bench = await setup_flat_ssi_testbench(dut, source_prefix="sAxis")
    source = bench.source
    assert source is not None

    # A complete four-word command frame should decode into one context/opcode
    # pulse after the module has collected the entire packet.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x123456AC, keep=keep, last=0, sof=1),
            SsiBeat(data=0x0000005A, keep=keep, last=0),
            SsiBeat(data=0x00000000, keep=keep, last=0),
            SsiBeat(data=0x00000000, keep=keep, last=1),
        ],
        clk=bench.clk,
    )

    ctx, opcode = await wait_cmd_valid(dut)
    assert ctx == 0x123456
    assert opcode == 0x5A

    # Repeat the good path with different field values so the bench proves the
    # decoder is not stuck on the first command it saw after reset.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x65432111, keep=keep, last=0, sof=1),
            SsiBeat(data=0x00000033, keep=keep, last=0),
            SsiBeat(data=0x00000000, keep=keep, last=0),
            SsiBeat(data=0x00000000, keep=keep, last=1),
        ],
        clk=bench.clk,
    )
    ctx, opcode = await wait_cmd_valid(dut)
    assert ctx == 0x654321
    assert opcode == 0x33

    # A truncated command frame is malformed, so the DUT should discard it and
    # then return to the idle ready state for the next packet.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0x0BADF011, keep=keep, last=0, sof=1),
            SsiBeat(data=0x00000077, keep=keep, last=1),
        ],
        clk=bench.clk,
    )
    await expect_no_cmd(dut)
    await wait_signal_level(dut.sAxisTReady, clk=bench.clk, expected=1, cycles=8)

    # An otherwise well-formed frame with `EOFE` on the last beat must also be
    # rejected, because the command decoder only accepts clean frames.
    await send_contiguous_frame(
        source,
        [
            SsiBeat(data=0xABCDEF10, keep=keep, last=0, sof=1),
            SsiBeat(data=0x0000007C, keep=keep, last=0),
            SsiBeat(data=0x00000000, keep=keep, last=0),
            SsiBeat(data=0x00000000, keep=keep, last=1, eofe=1),
        ],
        clk=bench.clk,
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
