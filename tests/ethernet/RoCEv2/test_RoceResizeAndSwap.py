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
# - Sweep: Keep a narrow three-case wrapper sweep covering equal-width
#   pass-through, `16 -> 32` upsize with byte swapping, and `32 -> 16`
#   downsize with the same byte-swapped big-lane ordering used by the RoCE
#   engine wrapper.
# - Stimulus: Drive AXI Stream frames with distinct `tid`, `tdest`, and
#   sideband values through a checked-in scalar-generic wrapper and stall the
#   sink briefly so buffered resized output becomes visible.
# - Checks: The output byte stream must match the expected resize-and-swap
#   transformation, metadata must survive unchanged, and the sideband value
#   must stay aligned with each accepted output beat.
# - Timing: Equal-width traffic is treated as pass-through, while resized
#   cases wait on visible output handshakes rather than assuming a fixed
#   internal latency.

from __future__ import annotations

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test
from tests.ethernet.RoCEv2.roce_test_utils import expected_resize_and_swap_bytes, roce_rtl_sources


WRAPPER_PATH = "ethernet/RoCEv2/wrappers/RoceResizeAndSwapIpIntegrator.vhd"
RTL_SOURCES = roce_rtl_sources("RoceResizeAndSwap.vhd")


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.slave_bytes = int(os.environ["SLAVE_DATA_BYTES_G"])
        self.master_bytes = int(os.environ["MASTER_DATA_BYTES_G"])
        self.side_band_width = int(os.environ["SIDE_BAND_WIDTH_G"])
        self.swap_endian = env_flag("SWAP_ENDIAN_G", default=False)
        self.little_endian = env_flag("LITTLE_ENDIAN_G", default=True)
        self.source = None
        self.sink = None
        self.rx_sidebands: list[int] = []

        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())

        dut.axisRst.setimmediatevalue(1)
        dut.S_AXIS_TVALID.setimmediatevalue(0)
        dut.S_AXIS_TDATA.setimmediatevalue(0)
        dut.S_AXIS_TKEEP.setimmediatevalue(0)
        dut.S_AXIS_TLAST.setimmediatevalue(0)
        dut.S_AXIS_TDEST.setimmediatevalue(0)
        dut.S_AXIS_TID.setimmediatevalue(0)
        dut.S_SIDE_BAND.setimmediatevalue(0)
        dut.M_AXIS_TREADY.setimmediatevalue(0)

        # Lifetime sideband monitor retained by the bench.
        self._monitor_task = cocotb.start_soon(self._monitor_sideband())

    async def cycle(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")

    async def _monitor_sideband(self):
        """Lifetime agent: collect RoCE sidebands until the test ends."""
        while True:
            await RisingEdge(self.dut.axisClk)
            await Timer(1, unit="ns")
            if int(self.dut.M_AXIS_TVALID.value) == 1 and int(self.dut.M_AXIS_TREADY.value) == 1:
                self.rx_sidebands.append(int(self.dut.M_SIDE_BAND.value))

    async def reset(self):
        self.dut.axisRst.value = 1
        self.dut.M_AXIS_TREADY.value = 0
        await self.cycle(4)
        self.dut.axisRst.value = 0
        await self.cycle(2)

    def start_agents(self):
        if self.source is None:
            self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "S_AXIS"), self.dut.axisClk, self.dut.axisRst)
        if self.sink is None:
            self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "M_AXIS"), self.dut.axisClk, self.dut.axisRst)


@cocotb.test()
async def roce_resize_and_swap_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()
    assert tb.source is not None
    assert tb.sink is not None

    payload = bytes(range(2 * max(tb.slave_bytes, tb.master_bytes)))
    frame = AxiStreamFrame(payload)
    frame.tid = 0x35
    frame.tdest = 0x71
    sideband = (1 << tb.side_band_width) - 1

    tb.dut.S_SIDE_BAND.value = sideband
    tb.dut.M_AXIS_TREADY.value = 0
    send_task = cocotb.start_soon(tb.source.send(frame))
    await tb.cycle(3)
    tb.dut.M_AXIS_TREADY.value = 1
    rx_frame = await tb.sink.recv()
    await send_task

    assert rx_frame.tdata == expected_resize_and_swap_bytes(
        payload,
        slave_bytes=tb.slave_bytes,
        master_bytes=tb.master_bytes,
        swap_endian=tb.swap_endian,
        little_endian=tb.little_endian,
    )
    assert rx_frame.tid == frame.tid
    assert rx_frame.tdest == frame.tdest

    assert tb.rx_sidebands
    assert all(observed == sideband for observed in tb.rx_sidebands)


PARAMETER_SWEEP = [
    parameter_case(
        "equal_width_passthrough",
        SLAVE_DATA_BYTES_G="16",
        MASTER_DATA_BYTES_G="16",
        SIDE_BAND_WIDTH_G="2",
        SWAP_ENDIAN_G="false",
        LITTLE_ENDIAN_G="true",
    ),
    parameter_case(
        "upsize_swap_big_lane",
        SLAVE_DATA_BYTES_G="16",
        MASTER_DATA_BYTES_G="32",
        SIDE_BAND_WIDTH_G="3",
        SWAP_ENDIAN_G="true",
        LITTLE_ENDIAN_G="false",
    ),
    parameter_case(
        "downsize_swap_big_lane",
        SLAVE_DATA_BYTES_G="32",
        MASTER_DATA_BYTES_G="16",
        SIDE_BAND_WIDTH_G="3",
        SWAP_ENDIAN_G="true",
        LITTLE_ENDIAN_G="false",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RoceResizeAndSwap(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.roceresizeandswapipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": RTL_SOURCES + [WRAPPER_PATH]},
    )
