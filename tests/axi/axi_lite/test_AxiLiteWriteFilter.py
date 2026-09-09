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
# - Sweep: Keep a narrow two-case wrapper sweep covering the filtered path and
#   the unfiltered pass-through path while holding the allowed-address list to
#   a single entry.
# - Stimulus: Issue AXI-Lite writes into the flattened slave-side port, toggle
#   `blockAll` and `enFilter`, and service any forwarded master-side write with
#   a small cocotb responder.
# - Checks: `blockAll` must return `SLVERR` without forwarding traffic,
#   disallowed filtered writes must return `DECERR`, allowed writes must reach
#   the master side with the original address/data/strobes, and pass-through
#   mode must propagate downstream `BRESP` values unchanged.
# - Timing: The master-side responder inserts one-cycle address/data/response
#   handshakes so the DUT has to traverse its filter state machine rather than
#   seeing zero-latency completion.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import env_sl, parameter_case, run_surf_vhdl_test


class ForwardedWriteTarget:
    def __init__(self, dut, reset_active):
        self.dut = dut
        self.reset_active = reset_active
        self.next_resp = AxiResp.OKAY
        self.last_write = None
        self.write_count = 0

        dut.M_AXI_AWREADY.setimmediatevalue(0)
        dut.M_AXI_WREADY.setimmediatevalue(0)
        dut.M_AXI_BVALID.setimmediatevalue(0)
        dut.M_AXI_BRESP.setimmediatevalue(0)

        # Lifetime AXI-Lite responder retained by the bus model.
        self._responder_task = cocotb.start_soon(self._run())

    def in_reset(self) -> bool:
        try:
            return int(self.dut.axilRst.value) == self.reset_active
        except ValueError:
            return True

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axilClk)

    async def _wait_while_reset(self):
        while self.in_reset():
            self.dut.M_AXI_AWREADY.value = 0
            self.dut.M_AXI_WREADY.value = 0
            self.dut.M_AXI_BVALID.value = 0
            await self.cycle(1)

    async def _run(self):
        """Lifetime agent: respond to downstream writes until the test ends."""
        while True:
            await self._wait_while_reset()

            while not int(self.dut.M_AXI_AWVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            awaddr = int(self.dut.M_AXI_AWADDR.value)
            awprot = int(self.dut.M_AXI_AWPROT.value)
            self.dut.M_AXI_AWREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_AWREADY.value = 0

            while not int(self.dut.M_AXI_WVALID.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)

            wdata = int(self.dut.M_AXI_WDATA.value)
            wstrb = int(self.dut.M_AXI_WSTRB.value)
            self.last_write = (awaddr, wdata, wstrb, awprot)
            self.write_count += 1
            self.dut.M_AXI_WREADY.value = 1
            await self.cycle(1)
            self.dut.M_AXI_WREADY.value = 0

            self.dut.M_AXI_BRESP.value = int(self.next_resp)
            self.dut.M_AXI_BVALID.value = 1
            while not int(self.dut.M_AXI_BREADY.value):
                await self._wait_while_reset()
                if not self.in_reset():
                    await self.cycle(1)
            await self.cycle(1)
            self.dut.M_AXI_BVALID.value = 0


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.reset_active = env_sl("RST_POLARITY_G", default=1)

        cocotb.start_soon(Clock(dut.axilClk, 5.0, unit="ns").start())

        dut.axilRst.setimmediatevalue(self.reset_active_value())
        dut.enFilter.setimmediatevalue(1)
        dut.blockAll.setimmediatevalue(1)

        self.axil = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
            clock=dut.axilClk,
            reset=dut.axilRst,
            reset_active_level=bool(self.reset_active),
        )
        self.target = ForwardedWriteTarget(dut, self.reset_active)

    def reset_active_value(self) -> int:
        return self.reset_active

    def reset_inactive_value(self) -> int:
        return 1 - self.reset_active

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axilClk)

    async def reset(self):
        self.dut.axilRst.setimmediatevalue(self.reset_active_value())
        self.dut.enFilter.value = 1
        self.dut.blockAll.value = 1
        await self.cycle(3)
        self.dut.axilRst.value = self.reset_inactive_value()
        await self.cycle(3)


@cocotb.test()
async def block_and_filtered_pass_test(dut):
    tb = TB(dut)
    await tb.reset()

    block_txn = await tb.axil.write(0x1A0, b"\x11\x22\x33\x44")
    assert block_txn.resp == AxiResp.SLVERR
    assert tb.target.write_count == 0

    tb.dut.blockAll.value = 0
    allowed_txn = await tb.axil.write(0x1A0, b"\xAA\xBB\xCC\xDD")
    assert allowed_txn.resp == AxiResp.OKAY
    assert tb.target.last_write[:3] == (0x1A0, 0xDDCCBBAA, 0xF)
    assert tb.target.write_count == 1

    denied_txn = await tb.axil.write(0x0FF0, b"\x55\x66\x77\x88")
    assert denied_txn.resp == AxiResp.DECERR
    assert tb.target.write_count == 1


@cocotb.test()
async def unfiltered_passthrough_test(dut):
    tb = TB(dut)
    await tb.reset()

    tb.dut.blockAll.value = 0
    tb.dut.enFilter.value = 0
    tb.target.next_resp = AxiResp.SLVERR

    txn = await tb.axil.write(0x0FF0, b"\xDE\xAD\xBE\xEF")
    assert txn.resp == AxiResp.SLVERR
    assert tb.target.last_write[:3] == (0x0FF0, 0xEFBEADDE, 0xF)
    assert tb.target.write_count == 1


PARAMETER_SWEEP = [
    parameter_case("sync_active_high", FILTER_SIZE_G="1", RST_ASYNC_G="false", RST_POLARITY_G="'1'"),
    parameter_case("async_active_low", FILTER_SIZE_G="1", RST_ASYNC_G="true", RST_POLARITY_G="'0'"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiLiteWriteFilter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitewritefilteripintegrator",
        parameters={
            **parameters,
            "FILTER_ADDR_0_G": "416",
        },
        extra_env=parameters,
    )
