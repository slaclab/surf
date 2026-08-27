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
# - Sweep: Keep a single wrapper-focused case with error responses enabled and
#   a low synthetic `FREQ_HZ` so the uptime path becomes observable in a short
#   simulation.
# - Stimulus: Read the version and git-hash registers, write and read back the
#   scratchpad, toggle the user-reset and FPGA-reload control registers, and
#   wait a few cycles for the accelerated uptime counter to increment.
# - Checks: Mapped reads must return `OKAY`, scratchpad and control writes must
#   update the exported outputs, uptime must advance from zero, and an unmapped
#   read must return `DECERR` when the wrapper error path is enabled.
# - Timing: The bench uses bounded post-write clock waits around the control
#   outputs and the reduced-frequency uptime configuration so no check depends
#   on wall-clock simulation time.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.start_soon(Clock(dut.S_AXI_ACLK, 5.0, unit="ns").start())

        dut.S_AXI_ARESETN.setimmediatevalue(0)
        dut.fpgaEnReload.setimmediatevalue(1)
        dut.slowClk.setimmediatevalue(0)
        dut.userValues.setimmediatevalue(0)

        self.axil = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
            clock=dut.S_AXI_ACLK,
            reset=dut.S_AXI_ARESETN,
            reset_active_level=False,
        )

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.S_AXI_ACLK)

    async def reset(self):
        self.dut.S_AXI_ARESETN.setimmediatevalue(0)
        await self.cycle(3)
        self.dut.S_AXI_ARESETN.value = 1
        await self.cycle(3)


@cocotb.test()
async def register_map_and_controls_test(dut):
    tb = TB(dut)
    await tb.reset()

    fw_txn = await tb.axil.read(0x000, 4)
    assert fw_txn.resp == AxiResp.OKAY

    wr_txn = await tb.axil.write(0x004, b"\x78\x56\x34\x12")
    assert wr_txn.resp == AxiResp.OKAY
    rd_txn = await tb.axil.read(0x004, 4)
    assert rd_txn.resp == AxiResp.OKAY
    assert rd_txn.data == b"\x78\x56\x34\x12"

    await tb.axil.write(0x10C, b"\x01\x00\x00\x00")
    await tb.cycle(2)
    assert int(dut.userReset.value) == 1

    await tb.axil.write(0x108, b"\x44\x33\x22\x11")
    await tb.axil.write(0x104, b"\x01\x00\x00\x00")
    await tb.cycle(2)
    assert int(dut.fpgaReload.value) == 1
    assert int(dut.fpgaReloadAddr.value) == 0x11223344


@cocotb.test()
async def readonly_and_error_response_test(dut):
    tb = TB(dut)
    await tb.reset()

    git_words = []
    for offset in range(0, 16, 4):
        rd_txn = await tb.axil.read(0x600 + offset, 4)
        assert rd_txn.resp == AxiResp.OKAY
        git_words.append(rd_txn.data)
    assert len(git_words) == 4

    build_string_txn = await tb.axil.read(0x800, 32)
    assert build_string_txn.resp == AxiResp.OKAY
    assert any(byte != 0 for byte in build_string_txn.data)

    await tb.cycle(10)
    up_txn = await tb.axil.read(0x008, 4)
    assert up_txn.resp == AxiResp.OKAY
    assert int.from_bytes(up_txn.data, "little") > 0

    err_txn = await tb.axil.read(0x200, 4)
    assert err_txn.resp == AxiResp.DECERR


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param(
            {"EN_ERROR_RESP": "true", "FREQ_HZ": "4"},
            id="error_resp_enabled",
        )
    ],
)
def test_AxiVersion(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiversionipintegrator",
        parameters=parameters,
        extra_env=parameters,
    )
