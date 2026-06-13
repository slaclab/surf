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
# - Drive a continued ("multi-buffer") frame: a single AXI-Stream frame longer
#   than the descriptor maxSize, with contEn=1, so the write engine fills one
#   buffer, returns it with continue=1, requests a SECOND descriptor at a
#   DIFFERENT memory address, and finishes the frame there.
# - This mirrors the main PCIe DMA (AxiStreamDmaV2Desc) path on hardware, where
#   each continued buffer is a separately-mapped host page. A stray write burst
#   to the wrong / boundary address is exactly what triggers an IOMMU
#   IO_PAGE_FAULT on real hardware once a frame crosses a buffer boundary.
# - Checks:
#     * The two returned descriptors carry continue=1 then continue=0.
#     * Each buffer's bytes land at its own address.
#     * EVERY M_AXI write burst targets one of the two declared buffer windows
#       -- no stray burst to an unmapped address.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiRamWrite, AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiWriteBus

from tests.common.regression_utils import hdl_parameters_from, run_surf_vhdl_test


def logic_int(value) -> int:
    try:
        return int(value)
    except ValueError:
        return 0


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.source = None
        self.ram = None
        self.aw_log = []
        # Distinct, page-like buffers handed out on successive descriptor
        # requests, widely spaced so any boundary-overrun write lands in a gap
        # (outside every buffer window) and is detectable.
        # 4 kB-aligned, widely-spaced buffers: a boundary-overrun write lands in
        # the gap between buffers (outside every window) so it is detectable.
        self.base = int(os.environ.get("ADDR_BASE", "0x1000"), 0)
        self.stride = int(os.environ.get("ADDR_STRIDE", "0x1000"), 0)
        self.max_size = int(os.environ.get("DESC_MAX_SIZE", "32"), 0)
        self.req_count = 0

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.axiWriteCtrlPause.setimmediatevalue(0)
        dut.axiWriteCtrlOver.setimmediatevalue(0)
        dut.dmaWrDescAckValid.setimmediatevalue(0)
        dut.dmaWrDescRetAck.setimmediatevalue(0)
        cocotb.start_soon(self._descriptor_responder())
        cocotb.start_soon(self._monitor_aw())

    def buf_addr(self, i):
        return self.base + i * self.stride

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axiRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axiClk, self.dut.axiRst)
        if self.ram is None:
            self.ram = AxiRamWrite(AxiWriteBus.from_prefix(self.dut, "M_AXI"), self.dut.axiClk, self.dut.axiRst, size=2 ** 16)

    async def _descriptor_responder(self):
        acked = False
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            self.dut.dmaWrDescAckValid.value = 0
            req = int(self.dut.dmaWrDescReqValid.value)
            if not req:
                acked = False
            if req and not acked:
                acked = True
                addr = self.buf_addr(self.req_count)
                self.req_count += 1
                self.dut.dmaWrDescAckAddress.value = addr
                self.dut.dmaWrDescAckMetaEnable.value = 0
                self.dut.dmaWrDescAckMetaAddr.value = 0
                self.dut.dmaWrDescAckDropEn.value = 0
                self.dut.dmaWrDescAckMaxSize.value = self.max_size
                self.dut.dmaWrDescAckContEn.value = 1          # allow multi-buffer continue
                self.dut.dmaWrDescAckBuffId.value = 0x1000 + self.req_count
                self.dut.dmaWrDescAckTimeout.value = 0x1000
                self.dut.dmaWrDescAckValid.value = 1

    async def _monitor_aw(self):
        while True:
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")
            if logic_int(self.dut.M_AXI_AWVALID.value) and logic_int(self.dut.M_AXI_AWREADY.value):
                self.aw_log.append((int(self.dut.M_AXI_AWADDR.value), int(self.dut.M_AXI_AWLEN.value)))


@cocotb.test(timeout_time=200, timeout_unit="us")
async def continue_multibuffer_write_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    # Frame spans ceil(total/max_size) buffers: each full buffer returns
    # continue=1, the final (partial) buffer returns continue=0.
    total = int(os.environ.get("FRAME_SIZE", "48"), 0)
    payload = bytes((i & 0xFF) for i in range(total))
    await tb.source.send(AxiStreamFrame(payload, tdest=0, tid=0))

    n_bufs = (total + tb.max_size - 1) // tb.max_size
    sizes = [tb.max_size] * (n_bufs - 1) + [total - tb.max_size * (n_bufs - 1)]

    # Collect every continued descriptor return.
    returns = []
    deadline = 40000
    while len(returns) < n_bufs and deadline > 0:
        await tb.cycle(1)
        deadline -= 1
        if int(dut.dmaWrDescRetValid.value):
            returns.append(
                (int(dut.dmaWrDescRetContinue.value), int(dut.dmaWrDescRetSize.value))
            )
            dut.dmaWrDescRetAck.value = 1
            await tb.cycle(1)
            dut.dmaWrDescRetAck.value = 0

    assert len(returns) == n_bufs, f"expected {n_bufs} descriptor returns, got {returns}"
    for i, (cont, size) in enumerate(returns):
        exp_cont = 0 if i == n_bufs - 1 else 1
        assert cont == exp_cont, f"buffer {i} continue={cont}, expected {exp_cont}; returns={returns}"
        assert size == sizes[i], f"buffer {i} size={size}, expected {sizes[i]}; returns={returns}"

    # Data integrity: each buffer holds its own slice at its own address.
    off = 0
    for i, sz in enumerate(sizes):
        assert tb.ram.read(tb.buf_addr(i), sz) == payload[off:off + sz], f"buffer {i} payload mismatch"
        off += sz

    # No stray write: every AW burst must fall inside one of the buffer windows.
    # A burst in the gap between buffers is the IOMMU IO_PAGE_FAULT signature.
    windows = [(tb.buf_addr(i), tb.buf_addr(i) + sizes[i]) for i in range(n_bufs)]
    for addr, length in tb.aw_log:
        in_window = any(lo <= addr < hi for lo, hi in windows)
        assert in_window, (
            f"stray write burst at addr=0x{addr:x} len={length} outside buffer windows "
            f"{[hex(w[0]) for w in windows]} -- this is the IOMMU IO_PAGE_FAULT signature"
        )


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({"DESC_MAX_SIZE": 32, "FRAME_SIZE": 48}, id="continue_48B_over_32B"),
        pytest.param({"DESC_MAX_SIZE": 32, "FRAME_SIZE": 64}, id="continue_64B_two_full"),
        pytest.param({"DESC_MAX_SIZE": 16, "FRAME_SIZE": 48, "BURST_BYTES_G": 8}, id="continue_48B_over_16B"),
    ],
)
def test_AxiStreamDmaV2WriteContinue(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2writeipintegrator",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd",
                "axi/dma/ip_integrator/AxiStreamDmaV2WriteIpIntegrator.vhd",
            ],
        },
    )
