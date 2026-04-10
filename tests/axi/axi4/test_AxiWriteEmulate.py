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
# - Sweep: Keep one 32-bit wrapper instance with a short fixed response latency.
# - Stimulus: Send one multi-beat AXI write burst by hand through the flat
#   wrapper interface so the bench can drive the AXI4 lock field directly.
# - Checks: The write response must complete with `OKAY`, proving the DUT
#   accepts address/data beats and returns the completion response.
# - Timing: The test waits for the AXI master write transaction to finish so it
#   exercises the DUT's full address/data/response sequencing.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.start_soon(Clock(dut.axiClk, 5.0, unit="ns").start())
        dut.axiRst.setimmediatevalue(1)
        self._drive_defaults()

    async def cycle(self, count=1):
        for _ in range(count):
            await RisingEdge(self.dut.axiClk)
            await Timer(1, unit="ns")

    async def reset(self):
        self.dut.axiRst.value = 1
        await self.cycle(4)
        self.dut.axiRst.value = 0
        await self.cycle(4)

    def _drive_defaults(self):
        self.dut.S_AXI_AWID.setimmediatevalue(0)
        self.dut.S_AXI_AWADDR.setimmediatevalue(0)
        self.dut.S_AXI_AWLEN.setimmediatevalue(0)
        self.dut.S_AXI_AWSIZE.setimmediatevalue(0)
        self.dut.S_AXI_AWBURST.setimmediatevalue(0)
        self.dut.S_AXI_AWLOCK.setimmediatevalue(0)
        self.dut.S_AXI_AWCACHE.setimmediatevalue(0)
        self.dut.S_AXI_AWPROT.setimmediatevalue(0)
        self.dut.S_AXI_AWREGION.setimmediatevalue(0)
        self.dut.S_AXI_AWQOS.setimmediatevalue(0)
        self.dut.S_AXI_AWVALID.setimmediatevalue(0)
        self.dut.S_AXI_WID.setimmediatevalue(0)
        self.dut.S_AXI_WDATA.setimmediatevalue(0)
        self.dut.S_AXI_WSTRB.setimmediatevalue(0)
        self.dut.S_AXI_WLAST.setimmediatevalue(0)
        self.dut.S_AXI_WVALID.setimmediatevalue(0)
        self.dut.S_AXI_BREADY.setimmediatevalue(0)

    async def write_burst(self, address, payload, beat_bytes, axi_id):
        assert len(payload) % beat_bytes == 0
        beats = len(payload) // beat_bytes

        self.dut.S_AXI_AWID.value = axi_id
        self.dut.S_AXI_AWADDR.value = address
        self.dut.S_AXI_AWLEN.value = beats - 1
        self.dut.S_AXI_AWSIZE.value = (beat_bytes.bit_length() - 1)
        self.dut.S_AXI_AWBURST.value = 0b01
        self.dut.S_AXI_AWLOCK.value = 0
        self.dut.S_AXI_AWCACHE.value = 0
        self.dut.S_AXI_AWPROT.value = 0
        self.dut.S_AXI_AWREGION.value = 0
        self.dut.S_AXI_AWQOS.value = 0
        self.dut.S_AXI_AWVALID.value = 1

        for _ in range(64):
            await self.cycle()
            if int(self.dut.S_AXI_AWREADY.value):
                break
        else:
            raise AssertionError("Timed out waiting for AWREADY")

        self.dut.S_AXI_AWVALID.value = 0

        for beat in range(beats):
            word = payload[beat * beat_bytes:(beat + 1) * beat_bytes]
            self.dut.S_AXI_WID.value = axi_id
            self.dut.S_AXI_WDATA.value = int.from_bytes(word, byteorder="little")
            self.dut.S_AXI_WSTRB.value = (1 << beat_bytes) - 1
            self.dut.S_AXI_WLAST.value = int(beat == beats - 1)
            self.dut.S_AXI_WVALID.value = 1

            for _ in range(64):
                await self.cycle()
                if int(self.dut.S_AXI_WREADY.value):
                    break
            else:
                raise AssertionError(f"Timed out waiting for WREADY on beat {beat}")

            self.dut.S_AXI_WVALID.value = 0
            self.dut.S_AXI_WLAST.value = 0

        self.dut.S_AXI_BREADY.value = 1

        for _ in range(128):
            await self.cycle()
            if int(self.dut.S_AXI_BVALID.value):
                break
        else:
            raise AssertionError("Timed out waiting for BVALID")

        resp = int(self.dut.S_AXI_BRESP.value)
        bid = int(self.dut.S_AXI_BID.value)

        self.dut.S_AXI_BREADY.value = 0

        return resp, bid


@cocotb.test()
async def burst_write_response_test(dut):
    tb = TB(dut)
    await tb.reset()

    payload = bytes(range(0x10, 0x10 + 12))
    resp, bid = await tb.write_burst(address=0x40, payload=payload, beat_bytes=4, axi_id=0x3)

    assert resp == 0
    assert bid == 0x3


@pytest.mark.parametrize("parameters", [pytest.param({}, id="burst_write_response")])
def test_AxiWriteEmulate(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axiwriteemulateipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiWriteEmulateIpIntegrator.vhd",
            ],
        },
    )
