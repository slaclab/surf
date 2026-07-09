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
# - Sweep: Keep one two-buffer ring-read wrapper and exercise only buffer index
#   zero so the first pass stays focused on the AXI-Lite lookup plus readout.
# - Stimulus: Preload AXI-Lite shadow registers for buffer zero, send one status
#   message naming that buffer, and capture the emitted AXI-Stream payload.
# - Checks: The downstream stream must return the bytes from the configured AXI
#   window and propagate the buffer index in `tdest`.
# - Timing: The bench waits on the output frame instead of assuming a fixed
#   number of AXI-Lite register fetches or DMA-read latency cycles.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import (
    AxiLiteBus,
    AxiLiteRam,
    AxiRamRead,
    AxiReadBus,
    AxiStreamBus,
    AxiStreamFrame,
    AxiStreamSink,
    AxiStreamSource,
)

from tests.axi.utils import ring_buffer_axil_addr
from tests.common.regression_utils import parameter_case, run_surf_vhdl_test, start_lockstep_clocks


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil_ram = None
        self.axi_ram = None
        self.status_source = None
        self.data_sink = None

        start_lockstep_clocks(dut.axilClk, dut.statusClk, dut.axiClk, period_ns=5.0)
        dut.axilRst.setimmediatevalue(1)
        dut.statusRst.setimmediatevalue(1)
        dut.axiRst.setimmediatevalue(1)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axilRst.value = 1
        self.dut.statusRst.value = 1
        self.dut.axiRst.value = 1
        await self.cycle(4)
        self.dut.axilRst.value = 0
        self.dut.statusRst.value = 0
        self.dut.axiRst.value = 0
        await self.cycle(6)

    def start_agents(self):
        if self.axil_ram is None:
            self.axil_ram = AxiLiteRam(
                AxiLiteBus.from_prefix(self.dut, "M_AXIL"),
                self.dut.axilClk,
                self.dut.axilRst,
                size=2**12,
            )
        if self.axi_ram is None:
            self.axi_ram = AxiRamRead(
                AxiReadBus.from_prefix(self.dut, "M_AXI"),
                self.dut.axiClk,
                self.dut.axiRst,
                size=2**16,
            )
        if self.status_source is None:
            self.status_source = AxiStreamSource(
                AxiStreamBus.from_prefix(self.dut, "S_STATUS"),
                self.dut.statusClk,
                self.dut.statusRst,
            )
        if self.data_sink is None:
            self.data_sink = AxiStreamSink(
                AxiStreamBus.from_prefix(self.dut, "M_AXIS"),
                self.dut.axiClk,
                self.dut.axiRst,
            )


@cocotb.test()
async def status_driven_ring_read_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    start_addr = 0x20
    end_addr = 0x28
    payload = b"\x10\x11\x12\x13\x20\x21\x22\x23"

    # Populate the register image that the ring-read module fetches over its
    # AXI-Lite master port before it issues the AXI memory read.
    tb.axil_ram.write(ring_buffer_axil_addr(0, 0, 0), start_addr.to_bytes(4, "little"))
    tb.axil_ram.write(ring_buffer_axil_addr(0, 0, 1), (0).to_bytes(4, "little"))
    tb.axil_ram.write(ring_buffer_axil_addr(1, 0, 0), end_addr.to_bytes(4, "little"))
    tb.axil_ram.write(ring_buffer_axil_addr(1, 0, 1), (0).to_bytes(4, "little"))
    tb.axil_ram.write(ring_buffer_axil_addr(4, 0, 0), (0).to_bytes(4, "little"))

    tb.axi_ram.write(start_addr, payload)
    await tb.status_source.send(AxiStreamFrame(b"\x00"))

    frame = await with_timeout(tb.data_sink.recv(), 5, "us")
    assert bytes(frame.tdata) == payload
    assert frame.tdest == 0


# The wide-address case elaborates the DUT with ADDR_WIDTH_C > 32 so CI catches
# generic-dependent slice bounds that only fail for wide AXI address maps.
PARAMETER_SWEEP = [
    parameter_case("buffer0_status_readout"),
    parameter_case("wide_addr_33bit", AXI_ADDR_WIDTH_G="33"),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_AxiStreamDmaRingRead(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmaringreadipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi-lite/ip_integrator/MasterAxiLiteIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/SlaveAxiStreamIpIntegrator.vhd",
                "axi/axi-stream/ip_integrator/MasterAxiStreamIpIntegrator.vhd",
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaRingReadIpIntegrator.vhd",
            ],
        },
    )
