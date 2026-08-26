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
# - Datapath: Drive a single AXI-Stream frame into the integrated store-and-forward
#   FIFO (sAxis), let it buffer through the AXI4 memory model (M_AXI -> AxiRam), and
#   capture the forwarded frame on the output (mAxis).
# - Boundary: The IP-integrator wrapper bakes BUFF_FRAME_WIDTH_G = 8, i.e. a 256-byte
#   per-buffer frame. A frame larger than 256 B is split across multiple buffers with
#   the "continue" bit set on every buffer except the last, then re-merged on readback
#   (AxiStreamDmaV2Read drives tLast := not continue). This is the same mechanism that,
#   on the XilinxVariumC1100 HBM buffer (BUFF_FRAME_WIDTH_G = 19), splits frames at
#   512 KiB. Testing at the 256-byte sim boundary exercises identical logic.
# - Check: The forwarded frame must be byte-for-byte identical to the injected frame
#   and arrive as ONE frame (single tLast). A truncated/fragmented output frame means
#   the continue re-merge is broken.

import os

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import (
    AxiBus,
    AxiRam,
    AxiStreamBus,
    AxiStreamFrame,
    AxiStreamSink,
    AxiStreamSource,
)

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks

# Per-buffer frame size baked into AxiStreamDmaV2FifoIpIntegrator (BUFF_FRAME_WIDTH_G=8).
BUFFER_FRAME_BYTES = 256


class TB:
    def __init__(self, dut):
        self.dut = dut

        start_lockstep_clocks(dut.axiClk, dut.axilClk, period_ns=5.0)
        dut.axiRst.setimmediatevalue(1)
        dut.axilRst.setimmediatevalue(1)
        dut.axiReady.setimmediatevalue(1)

        # Source drives sAxis, sink captures mAxis, AxiRam backs the M_AXI store.
        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "S_AXIS"), dut.axiClk, dut.axiRst)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "M_AXIS"), dut.axiClk, dut.axiRst)
        self.ram = AxiRam(AxiBus.from_prefix(dut, "M_AXI"), dut.axiClk, dut.axiRst, size=2 ** 16)

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axiRst.value = 1
        self.dut.axilRst.value = 1
        await self.cycle(8)
        self.dut.axiRst.value = 0
        self.dut.axilRst.value = 0
        # The FIFO self-loads its internal free list (INIT_S) after reset; give it
        # time to populate before injecting traffic.
        await self.cycle(64)


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def fifo_loopback_frame_test(dut):
    tb = TB(dut)
    await tb.reset()

    size = int(os.environ.get("FRAME_SIZE", "260"))
    payload = bytes((i & 0xFF) for i in range(size))

    await tb.source.send(AxiStreamFrame(payload, tdest=0, tid=0))
    rx = await tb.sink.recv()
    got = bytes(rx.tdata)

    crosses = size > BUFFER_FRAME_BYTES
    assert len(got) == size, (
        f"output frame size {len(got)} != injected {size} "
        f"(buffer frame = {BUFFER_FRAME_BYTES} B; "
        f"{'continue re-merge produced a fragmented frame' if crosses else 'single-buffer frame corrupted'})"
    )
    assert got == payload, (
        f"payload mismatch through store-and-forward buffer (size={size}, "
        f"crosses 256 B boundary={crosses})"
    )


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({"FRAME_SIZE": 256}, id="one_buffer_256B"),
        pytest.param({"FRAME_SIZE": 260}, id="continue_boundary_260B"),
        pytest.param({"FRAME_SIZE": 1024}, id="multi_buffer_1024B"),
    ],
)
def test_AxiStreamDmaV2FifoLoopback(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2fifoipintegrator",
        # FRAME_SIZE is consumed by the bench via the environment, not a VHDL generic.
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaV2FifoIpIntegrator.vhd",
            ],
        },
    )
