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
# - Sweep: Keep one 32-bit wrapper instance with a short fixed latency so the
#   bench proves the read-emulation data generator without adding width noise.
# - Stimulus: Issue one aligned multi-beat AXI read by hand through the
#   checked-in AXI4 wrapper so the bench matches the DUT's 2-bit AXI4 lock
#   field instead of relying on an AXI-Lite flavored helper.
# - Checks: The returned byte stream must count upward from zero exactly across
#   beat boundaries and the AXI response must remain `OKAY`.
# - Timing: The test waits on the AXI master completion instead of assuming a
#   specific internal latency for the FIFO plus emulator state machine.

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
        # Keep the unused write channel quiescent while the bench drives reads.
        self.dut.S_AXI_ARID.setimmediatevalue(0)
        self.dut.S_AXI_ARADDR.setimmediatevalue(0)
        self.dut.S_AXI_ARLEN.setimmediatevalue(0)
        self.dut.S_AXI_ARSIZE.setimmediatevalue(0)
        self.dut.S_AXI_ARBURST.setimmediatevalue(0)
        self.dut.S_AXI_ARLOCK.setimmediatevalue(0)
        self.dut.S_AXI_ARCACHE.setimmediatevalue(0)
        self.dut.S_AXI_ARPROT.setimmediatevalue(0)
        self.dut.S_AXI_ARREGION.setimmediatevalue(0)
        self.dut.S_AXI_ARQOS.setimmediatevalue(0)
        self.dut.S_AXI_ARVALID.setimmediatevalue(0)
        self.dut.S_AXI_RREADY.setimmediatevalue(0)

    async def read_burst(self, address, beat_bytes, beats, axi_id):
        data = bytearray()

        self.dut.S_AXI_ARID.value = axi_id
        self.dut.S_AXI_ARADDR.value = address
        self.dut.S_AXI_ARLEN.value = beats - 1
        self.dut.S_AXI_ARSIZE.value = (beat_bytes.bit_length() - 1)
        self.dut.S_AXI_ARBURST.value = 0b01
        self.dut.S_AXI_ARLOCK.value = 0
        self.dut.S_AXI_ARCACHE.value = 0
        self.dut.S_AXI_ARPROT.value = 0
        self.dut.S_AXI_ARREGION.value = 0
        self.dut.S_AXI_ARQOS.value = 0
        self.dut.S_AXI_ARVALID.value = 1

        for _ in range(64):
            await self.cycle()
            if int(self.dut.S_AXI_ARREADY.value):
                break
        else:
            raise AssertionError("Timed out waiting for ARREADY")

        self.dut.S_AXI_ARVALID.value = 0
        self.dut.S_AXI_RREADY.value = 1

        for beat in range(beats):
            for _ in range(128):
                await self.cycle()
                if int(self.dut.S_AXI_RVALID.value):
                    break
            else:
                raise AssertionError(f"Timed out waiting for RVALID on beat {beat}")

            assert int(self.dut.S_AXI_RID.value) == axi_id
            assert int(self.dut.S_AXI_RRESP.value) == 0

            word = int(self.dut.S_AXI_RDATA.value).to_bytes(beat_bytes, byteorder="little")
            data.extend(word)

            if beat == beats - 1:
                assert int(self.dut.S_AXI_RLAST.value) == 1
            else:
                assert int(self.dut.S_AXI_RLAST.value) == 0

        self.dut.S_AXI_RREADY.value = 0
        return bytes(data)


@cocotb.test()
async def counting_payload_read_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Drive a transfer that spans multiple 32-bit beats so the generated count
    # pattern has to stay consistent across beat boundaries.
    payload = await tb.read_burst(address=0x20, beat_bytes=4, beats=3, axi_id=0x12)
    assert payload[:10] == bytes(range(10))


@pytest.mark.parametrize("parameters", [pytest.param({}, id="counting_payload")])
def test_AxiReadEmulate(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axireademulateipintegrator",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd",
                "axi/axi4/ip_integrator/AxiReadEmulateIpIntegrator.vhd",
            ],
        },
    )
