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
# - Sweep: Use a curated three-case matrix covering equal-width bypass,
#   32-bit-to-64-bit upsize, and 64-bit-to-32-bit downsize.
# - Stimulus: Drive one aligned AXI write burst and one aligned AXI read burst
#   through the slave port while a downstream AXI RAM model services the
#   master side of the wrapper.
# - Checks: Payload bytes must round-trip exactly, the downstream memory image
#   must match the write payload, and the accepted downstream `AWLEN`/`ARLEN`
#   values must match the resized beat count for the active widths.
# - Timing: The bench checks accepted downstream transactions after the slave
#   side bursts complete so the resize logic is measured on actual handshakes,
#   not only on source intent.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiBus, AxiMaster, AxiRam

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test


def logic_int(value) -> int:
    try:
        return int(value)
    except ValueError:
        return 0


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.slave_bytes = int(os.environ["SLAVE_DATA_BYTES_G"])
        self.master_bytes = int(os.environ["MASTER_DATA_BYTES_G"])
        self.aw_meta = []
        self.ar_meta = []

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())

        dut.axiRst.setimmediatevalue(1)
        self.master = None
        self.ram = None

        cocotb.start_soon(self._monitor_aw())
        cocotb.start_soon(self._monitor_ar())

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Reset the wrapper shims and the resize state so each parameter case
        # starts from an empty partial-beat accumulator.
        self.dut.axiRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.master is None:
            self.master = AxiMaster(AxiBus.from_prefix(self.dut, "S_AXI"), self.dut.axiClk, self.dut.axiRst)
        if self.ram is None:
            self.ram = AxiRam(AxiBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2**16)

    async def _monitor_aw(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if logic_int(self.dut.M_AXI_AWVALID.value) and logic_int(self.dut.M_AXI_AWREADY.value):
                self.aw_meta.append(
                    (
                        int(self.dut.M_AXI_AWADDR.value),
                        int(self.dut.M_AXI_AWLEN.value),
                        int(self.dut.M_AXI_AWSIZE.value),
                    )
                )

    async def _monitor_ar(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if logic_int(self.dut.M_AXI_ARVALID.value) and logic_int(self.dut.M_AXI_ARREADY.value):
                self.ar_meta.append(
                    (
                        int(self.dut.M_AXI_ARADDR.value),
                        int(self.dut.M_AXI_ARLEN.value),
                        int(self.dut.M_AXI_ARSIZE.value),
                    )
                )


@cocotb.test()
async def write_read_round_trip_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    payload_len = 2 * max(tb.slave_bytes, tb.master_bytes)
    payload = bytes((0x40 + i) & 0xFF for i in range(payload_len))
    address = 0x0020

    write_resp = await with_timeout(tb.master.write(address, payload, awid=3), 2, "us")
    read_resp = await with_timeout(tb.master.read(address, payload_len, arid=2), 2, "us")

    expected_beats = (payload_len + tb.master_bytes - 1) // tb.master_bytes
    expected_size = tb.master_bytes.bit_length() - 1

    assert write_resp.resp == 0
    assert bytes(read_resp) == payload
    assert read_resp.resp == 0
    assert tb.ram.read(address, payload_len) == payload
    assert tb.aw_meta[-1] == (address, expected_beats - 1, expected_size)
    assert tb.ar_meta[-1] == (address, expected_beats - 1, expected_size)


PARAMETER_SWEEP = [
    parameter_case("equal_width", SLAVE_DATA_BYTES_G="4", MASTER_DATA_BYTES_G="4"),
    parameter_case("upsize", SLAVE_DATA_BYTES_G="4", MASTER_DATA_BYTES_G="8"),
    parameter_case("downsize", SLAVE_DATA_BYTES_G="8", MASTER_DATA_BYTES_G="4"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiResize(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiresizeipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiResizeIpIntegrator.vhd",
            ],
        },
    )
