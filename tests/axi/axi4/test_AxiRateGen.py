##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the terms
## contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Keep one common-clock 32-bit AXI4 wrapper case so the bench proves
#   the stable control-plane and generated-traffic subset without taking on
#   the asynchronous AXI-Lite crossing variants in this pass.
# - Stimulus: Program the AXI-Lite register map, then let the DUT generate
#   repeated AXI writes into a cocotb RAM model and repeated AXI reads from
#   preloaded RAM contents while both clocks run in lockstep.
# - Checks: Register reads and writes must respond `OKAY`, the AXI config
#   register must expose the wrapper widths, write bursts must zero the
#   programmed byte count with the expected final strobe, and read bursts must
#   emit the programmed address, length, cache, and completion pattern.
# - Timing: The bench records accepted AXI handshakes and checks bounded gaps
#   between successive transactions so the programmed timer fields affect real
#   generated traffic instead of only being read back over AXI-Lite.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiBus, AxiLiteBus, AxiLiteMaster, AxiMaster, AxiRam, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks


def logic_int(value) -> int:
    try:
        return int(value)
    except ValueError:
        return 0


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.cycle_count = 0
        self.aw_handshakes = []
        self.w_handshakes = []
        self.ar_handshakes = []
        self.r_handshakes = []

        start_lockstep_clocks(dut.axiClk, dut.axilClk, period_ns=5.0)

        dut.axiRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)

        self.axil = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXIL"),
            clock=dut.axilClk,
            reset=dut.axilRst,
        )
        self.axi_ram = AxiRam(AxiBus.from_prefix(dut, "M_AXI"), dut.axiClk, dut.axiRst, size=2**16)

        cocotb.start_soon(self._track_cycles())
        cocotb.start_soon(self._monitor_aw())
        cocotb.start_soon(self._monitor_w())
        cocotb.start_soon(self._monitor_ar())
        cocotb.start_soon(self._monitor_r())

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Hold both reset domains active together because this regression keeps
        # the DUT on the stable COMMON_CLK path with truly shared edges.
        self.dut.axiRst.setimmediatevalue(1)
        self.dut.axilRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        self.dut.axilRst.value = 0
        await self.cycle(3)

    async def read_reg(self, address: int) -> int:
        txn = await with_timeout(self.axil.read(address, 4), 2, "us")
        assert txn.resp == AxiResp.OKAY
        return int.from_bytes(txn.data, "little")

    async def write_reg(self, address: int, value: int):
        txn = await with_timeout(self.axil.write(address, value.to_bytes(4, "little")), 2, "us")
        assert txn.resp == AxiResp.OKAY

    async def wait_for_count(self, store, expected: int, *, limit_cycles: int, label: str):
        for _ in range(limit_cycles):
            if len(store) >= expected:
                return
            await self.cycle(1)
        raise AssertionError(f"Timed out waiting for {label}: expected {expected}, saw {len(store)}")

    async def _track_cycles(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            self.cycle_count += 1

    async def _monitor_aw(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if logic_int(self.dut.M_AXI_AWVALID.value) and logic_int(self.dut.M_AXI_AWREADY.value):
                self.aw_handshakes.append(
                    (
                        self.cycle_count,
                        int(self.dut.M_AXI_AWADDR.value),
                        int(self.dut.M_AXI_AWLEN.value),
                        int(self.dut.M_AXI_AWSIZE.value),
                        int(self.dut.M_AXI_AWCACHE.value),
                    )
                )

    async def _monitor_w(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if logic_int(self.dut.M_AXI_WVALID.value) and logic_int(self.dut.M_AXI_WREADY.value):
                self.w_handshakes.append(
                    (
                        self.cycle_count,
                        int(self.dut.M_AXI_WSTRB.value),
                        int(self.dut.M_AXI_WLAST.value),
                    )
                )

    async def _monitor_ar(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if logic_int(self.dut.M_AXI_ARVALID.value) and logic_int(self.dut.M_AXI_ARREADY.value):
                self.ar_handshakes.append(
                    (
                        self.cycle_count,
                        int(self.dut.M_AXI_ARADDR.value),
                        int(self.dut.M_AXI_ARLEN.value),
                        int(self.dut.M_AXI_ARSIZE.value),
                        int(self.dut.M_AXI_ARCACHE.value),
                    )
                )

    async def _monitor_r(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if logic_int(self.dut.M_AXI_RVALID.value) and logic_int(self.dut.M_AXI_RREADY.value):
                self.r_handshakes.append(
                    (
                        self.cycle_count,
                        int(self.dut.M_AXI_RLAST.value),
                    )
                )


@cocotb.test()
async def register_map_and_write_generation_test(dut):
    tb = TB(dut)
    await tb.reset()

    config = await tb.read_reg(0x80)
    assert config == (16 | (4 << 8) | (4 << 16) | (8 << 24))

    for address in (0x1000, 0x2000):
        tb.axi_ram.write(address, b"\xA5" * 16)

    await tb.write_reg(0x10, 9)
    await tb.write_reg(0x20, 4)
    await tb.write_reg(0x40, 0x3)
    await tb.write_reg(0x00, 1)

    assert await tb.read_reg(0x10) == 9
    assert await tb.read_reg(0x20) == 4
    assert await tb.read_reg(0x40) == 0x3
    assert await tb.read_reg(0x00) == 1

    await tb.wait_for_count(tb.aw_handshakes, 2, limit_cycles=80, label="write address handshakes")
    await tb.wait_for_count(tb.w_handshakes, 6, limit_cycles=80, label="write data handshakes")

    first_aw = tb.aw_handshakes[0]
    second_aw = tb.aw_handshakes[1]
    assert first_aw[1:] == (0x1000, 2, 2, 0x3)
    assert second_aw[1:] == (0x2000, 2, 2, 0x3)
    assert second_aw[0] - first_aw[0] >= 4

    assert [entry[1:] for entry in tb.w_handshakes[:6]] == [
        (0xF, 0),
        (0xF, 0),
        (0x3, 1),
        (0xF, 0),
        (0xF, 0),
        (0x3, 1),
    ]
    assert tb.axi_ram.read(0x1000, 16) == (b"\x00" * 10) + (b"\xA5" * 6)
    assert tb.axi_ram.read(0x2000, 16) == (b"\x00" * 10) + (b"\xA5" * 6)


@cocotb.test()
async def read_generation_test(dut):
    tb = TB(dut)
    await tb.reset()

    tb.axi_ram.write(0x1000, bytes(range(8)))
    tb.axi_ram.write(0x2000, bytes(range(0x10, 0x18)))

    await tb.write_reg(0x14, 7)
    await tb.write_reg(0x24, 3)
    await tb.write_reg(0x44, 0x6)
    await tb.write_reg(0x04, 1)

    assert await tb.read_reg(0x14) == 7
    assert await tb.read_reg(0x24) == 3
    assert await tb.read_reg(0x44) == 0x6
    assert await tb.read_reg(0x04) == 1

    await tb.wait_for_count(tb.ar_handshakes, 2, limit_cycles=80, label="read address handshakes")
    await tb.wait_for_count(tb.r_handshakes, 4, limit_cycles=80, label="read data handshakes")

    first_ar = tb.ar_handshakes[0]
    second_ar = tb.ar_handshakes[1]
    assert first_ar[1:] == (0x1000, 1, 2, 0x6)
    assert second_ar[1:] == (0x2000, 1, 2, 0x6)
    assert second_ar[0] - first_ar[0] >= 3
    assert [entry[1] for entry in tb.r_handshakes[:4]] == [0, 1, 0, 1]


@pytest.mark.parametrize("parameters", [pytest.param({}, id="common_clock_32bit")])
def test_AxiRateGen(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axirategenipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiRateGenIpIntegrator.vhd",
            ],
        },
    )
