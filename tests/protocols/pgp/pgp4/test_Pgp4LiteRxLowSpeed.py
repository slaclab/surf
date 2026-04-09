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
# - Sweep: Keep one single-lane simulation-mode `Pgp4LiteRxLowSpeed` wrapper
#   with flat AXI-Lite access and an internal `Pgp4TxLite` serializer source.
# - Stimulus: Program the top-level delay register over AXI-Lite, wait for the
#   integrated lane to report locked status, then send a pair of single-word
#   frames through the serialized source.
# - Checks: The configured delay must propagate to `dlyCfg`, the common status
#   register must report a locked lane, and the lane must stay locked with the
#   same delay setting while traffic is present.
# - Timing: The bench uses lockstep clocks for the deserializer and AXI-Lite
#   domains, waits for the RX lane to train, and then checks a bounded
#   post-traffic stability window.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import parameter_case, start_lockstep_clocks
from tests.protocols.pgp.pgp4.pgp4_test_utils import signal_int
from tests.protocols.pgp.pgp_test_utils import run_pgp_wrapper_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        start_lockstep_clocks(dut.clk, dut.S_AXI_ACLK, period_ns=5.0)

    async def cycle(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.rst.setimmediatevalue(1)
        self.dut.S_AXI_ARESETN.setimmediatevalue(0)
        self.dut.txValid.setimmediatevalue(0)
        self.dut.txData.setimmediatevalue(0)
        self.dut.txSof.setimmediatevalue(0)
        self.dut.txEof.setimmediatevalue(0)
        self.dut.txEofe.setimmediatevalue(0)
        await self.cycle(4)
        self.dut.rst.value = 0
        self.dut.S_AXI_ARESETN.value = 1
        await self.cycle(8)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(
                AxiLiteBus.from_prefix(self.dut, "S_AXI"),
                self.dut.S_AXI_ACLK,
                self.dut.S_AXI_ARESETN,
                reset_active_level=False,
            )

    async def send_single_word_frame(self, *, payload: int, eofe: int = 0):
        self.dut.txValid.value = 1
        self.dut.txData.value = payload
        self.dut.txSof.value = 1
        self.dut.txEof.value = 1
        self.dut.txEofe.value = eofe
        for _ in range(64):
            if signal_int(self.dut, "txReady") == 1:
                break
            await self.cycle()
        else:
            raise AssertionError("Timed out waiting for txReady")
        await self.cycle()
        self.dut.txValid.value = 0
        self.dut.txSof.value = 0
        self.dut.txEof.value = 0
        self.dut.txEofe.value = 0

    async def wait_for_locked_status(self, *, cycles: int = 512):
        for _ in range(cycles):
            if (await axil_read_u32(self.axil, 0x400) & 0x1) == 1:
                return
            if (await axil_read_u32(self.axil, 0x000) & 0xFFFF) != 0:
                return
            await self.cycle()
        raise AssertionError("Timed out waiting for top-level low-speed lane lock status")

    async def assert_stable_window(self, *, cycles: int, expected_dly_cfg: int):
        for _ in range(cycles):
            assert signal_int(self.dut, "dlyCfg") == expected_dly_cfg
            await self.cycle()


@cocotb.test()
async def pgp4_lite_rx_low_speed_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    assert ((await axil_read_u32(tb.axil, 0x7FC)) >> 8) == 1
    await axil_write_u32(tb.axil, 0x800, 1)
    await axil_write_u32(tb.axil, 0x500, 0x12)
    await tb.cycle(8)
    assert signal_int(dut, "dlyCfg") == 0x12
    assert (await axil_read_u32(tb.axil, 0x600) & 0x1FF) == 0x12

    await tb.cycle(1400)
    await tb.wait_for_locked_status()
    locked_count_before = await axil_read_u32(tb.axil, 0x000)
    assert locked_count_before != 0
    await tb.assert_stable_window(cycles=16, expected_dly_cfg=0x12)

    await tb.send_single_word_frame(payload=0x8877665544332211)
    await tb.send_single_word_frame(payload=0x0123456789ABCDEF, eofe=1)

    await tb.assert_stable_window(cycles=32, expected_dly_cfg=0x12)
    assert (await axil_read_u32(tb.axil, 0x000)) >= locked_count_before


PARAMETER_SWEEP = [parameter_case("top_level_low_speed_wrapper")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Pgp4LiteRxLowSpeed(parameters):
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp4literxlowspeedwrapper",
        wrapper_source="protocols/pgp/pgp4/core/wrappers/Pgp4LiteRxLowSpeedWrapper.vhd",
        extra_env=parameters,
    )
