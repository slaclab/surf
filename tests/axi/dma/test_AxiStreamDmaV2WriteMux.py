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
# - Sweep: Cover descriptor-first, simultaneous-launch, and data-first ordering
#   with the same narrow 32-bit wrapper so the bench stays focused on mux
#   arbitration instead of descriptor splitting.
# - Stimulus: Launch one descriptor write and one data write into the shared
#   downstream AXI RAM model under different relative arrival timings.
# - Checks: Both routed responses must return `OKAY`, the shared memory must
#   contain both payloads, and the accepted downstream address order must match
#   the expected arbitration behavior for each launch pattern.
# - Timing: The requests are intentionally separated by a controlled number of
#   clocks, or started in the same cycle, so the mux still steps through real
#   address/data/response states.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiRamWrite, AxiResp, AxiWriteBus

from tests.common.regression_utils import run_surf_vhdl_test


def logic_int(value) -> int:
    try:
        return int(value)
    except ValueError:
        return 0


class SourcePort:
    def __init__(self, dut, prefix):
        self.dut = dut
        self.prefix = prefix

        for suffix, value in {
            "AWID": 0,
            "AWADDR": 0,
            "AWLEN": 0,
            "AWSIZE": 2,
            "AWBURST": 1,
            "AWLOCK": 0,
            "AWCACHE": 0x3,
            "AWPROT": 0,
            "AWREGION": 0,
            "AWQOS": 0,
            "AWVALID": 0,
            "WID": 0,
            "WDATA": 0,
            "WSTRB": 0,
            "WLAST": 0,
            "WVALID": 0,
            "BREADY": 0,
        }.items():
            getattr(dut, f"{prefix}_{suffix}").setimmediatevalue(value)

    async def issue_write(self, address: int, payload: bytes):
        data = int.from_bytes(payload, "little")
        getattr(self.dut, f"{self.prefix}_AWADDR").value = address
        getattr(self.dut, f"{self.prefix}_AWVALID").value = 1
        getattr(self.dut, f"{self.prefix}_WDATA").value = data
        getattr(self.dut, f"{self.prefix}_WSTRB").value = (1 << len(payload)) - 1
        getattr(self.dut, f"{self.prefix}_WLAST").value = 1
        getattr(self.dut, f"{self.prefix}_WVALID").value = 1

        aw_done = False
        w_done = False
        while not (aw_done and w_done):
            await sample_after_tpd(self.dut.axiClk)
            aw_done = aw_done or (
                logic_int(getattr(self.dut, f"{self.prefix}_AWVALID").value)
                and logic_int(getattr(self.dut, f"{self.prefix}_AWREADY").value)
            )
            w_done = w_done or (
                logic_int(getattr(self.dut, f"{self.prefix}_WVALID").value)
                and logic_int(getattr(self.dut, f"{self.prefix}_WREADY").value)
            )
            if aw_done:
                getattr(self.dut, f"{self.prefix}_AWVALID").value = 0
            if w_done:
                getattr(self.dut, f"{self.prefix}_WVALID").value = 0

        getattr(self.dut, f"{self.prefix}_BREADY").value = 1
        while not logic_int(getattr(self.dut, f"{self.prefix}_BVALID").value):
            await sample_after_tpd(self.dut.axiClk)
        resp = int(getattr(self.dut, f"{self.prefix}_BRESP").value)
        await sample_after_tpd(self.dut.axiClk)
        getattr(self.dut, f"{self.prefix}_BREADY").value = 0
        return resp


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.aw_order = []
        self.data = SourcePort(dut, "DATA_AXI")
        self.desc = SourcePort(dut, "DESC_AXI")
        self.ram = None

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        dut.mAxiWriteCtrlPause.setimmediatevalue(0)
        dut.mAxiWriteCtrlOver.setimmediatevalue(0)
        # Lifetime monitor retained by the bench until cocotb ends the test.
        self._monitor_task = cocotb.start_soon(self._monitor_aw())

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.axiClk)

    async def reset(self):
        self.dut.axiRst.setimmediatevalue(1)
        await self.cycle(3)
        self.dut.axiRst.value = 0
        await self.cycle(3)

    def start_agents(self):
        if self.ram is None:
            self.ram = AxiRamWrite(
                AxiWriteBus.from_prefix(self.dut, "M_AXI"),
                self.dut.axiClk,
                self.dut.axiRst,
                size=2**16,
            )

    async def _monitor_aw(self):
        """Lifetime agent: record muxed write addresses until the test ends."""
        while True:
            await sample_after_tpd(self.dut.axiClk)
            if logic_int(self.dut.M_AXI_AWVALID.value) and logic_int(self.dut.M_AXI_AWREADY.value):
                self.aw_order.append(int(self.dut.M_AXI_AWADDR.value))


@cocotb.test()
async def descriptor_then_data_write_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    desc_task = cocotb.start_soon(tb.desc.issue_write(0x0040, b"\xD0\xD1\xD2\xD3"))
    await tb.cycle(2)
    data_resp = await tb.data.issue_write(0x0010, b"\x10\x11\x12\x13")
    desc_resp = await desc_task
    await tb.cycle(2)

    assert data_resp == AxiResp.OKAY
    assert desc_resp == AxiResp.OKAY
    assert tb.ram.read(0x0010, 4) == b"\x10\x11\x12\x13"
    assert tb.ram.read(0x0040, 4) == b"\xD0\xD1\xD2\xD3"
    assert tb.aw_order[:2] == [0x0040, 0x0010]
    assert int(dut.dataWriteCtrlPause.value) == 0


@cocotb.test()
async def simultaneous_launch_dual_accept_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    desc_task = cocotb.start_soon(tb.desc.issue_write(0x0060, b"\xE0\xE1\xE2\xE3"))
    data_task = cocotb.start_soon(tb.data.issue_write(0x0020, b"\x20\x21\x22\x23"))
    desc_resp = await desc_task
    data_resp = await data_task
    await tb.cycle(2)

    assert desc_resp == AxiResp.OKAY
    assert data_resp == AxiResp.OKAY
    assert tb.ram.read(0x0020, 4) == b"\x20\x21\x22\x23"
    assert tb.ram.read(0x0060, 4) == b"\xE0\xE1\xE2\xE3"
    assert set(tb.aw_order[:2]) == {0x0020, 0x0060}


@cocotb.test()
async def in_flight_data_not_preempted_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    data_task = cocotb.start_soon(tb.data.issue_write(0x0030, b"\x30\x31\x32\x33"))
    await tb.cycle(1)
    desc_resp = await tb.desc.issue_write(0x0070, b"\xF0\xF1\xF2\xF3")
    data_resp = await data_task
    await tb.cycle(2)

    assert data_resp == AxiResp.OKAY
    assert desc_resp == AxiResp.OKAY
    assert tb.ram.read(0x0030, 4) == b"\x30\x31\x32\x33"
    assert tb.ram.read(0x0070, 4) == b"\xF0\xF1\xF2\xF3"
    assert tb.aw_order[:2] == [0x0030, 0x0070]


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({}, id="single_beat_32bit"),
        pytest.param({"ACK_WAIT_BVALID_G": True}, id="single_beat_ack_wait"),
    ],
)
def test_AxiStreamDmaV2WriteMux(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axistreamdmav2writemuxipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["axi/dma/ip_integrator/AxiStreamDmaV2WriteMuxIpIntegrator.vhd"],
        },
    )
