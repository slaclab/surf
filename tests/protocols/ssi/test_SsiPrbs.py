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
# - Sweep: Keep the default internal PRBS loopback datapath, but drive the TX
#   control inputs directly so the bench can force both clean and malformed
#   packets through the real TX/RX pair.
# - Stimulus: Trigger one clean packet, one minimum-length packet via
#   `packetLength=0`, one forced-EOFE packet, and then a TX-only reset before
#   the next trigger so the RX sees a restarted seed sequence.
# - Checks: Clean traffic must update with no errors, the short-length request
#   must clamp to the minimum visible packet length, forced EOFE must set only
#   the EOFE error flag, and the TX-only reset must raise the missed-packet
#   flag without spurious length or data-bus errors.
# - Timing: The bench pulses `trig` in the fast clock domain, waits on
#   `updated`, and samples the exported RX status signals directly instead of
#   relying on a fixed free-running packet cadence.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout

from tests.common.regression_utils import run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        # The PRBS wrapper uses separate fast TX and slow status clocks, so the
        # test starts both domains explicitly.
        cocotb.start_soon(Clock(dut.fastClk, 3333, unit="ps").start())
        cocotb.start_soon(Clock(dut.slowClk, 10.0, unit="ns").start())

    async def fast_cycle(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.fastClk)
            await Timer(1, unit="ns")

    async def slow_cycle(self, count: int = 1):
        for _ in range(count):
            await RisingEdge(self.dut.slowClk)
            await Timer(1, unit="ns")

    async def reset(self):
        # Hold both domains in reset long enough for the internal loopback path
        # to settle before any trigger pulses are issued.
        self.dut.fastRst.setimmediatevalue(1)
        self.dut.slowRst.setimmediatevalue(1)
        self.dut.trig.setimmediatevalue(0)
        self.dut.packetLength.setimmediatevalue(64)
        self.dut.forceEofe.setimmediatevalue(0)
        for _ in range(120):
            await RisingEdge(self.dut.slowClk)
        self.dut.fastRst.value = 0
        self.dut.slowRst.value = 0
        await self.slow_cycle(4)

    async def trigger_packet(self, *, packet_length: int, force_eofe: bool = False):
        # `trig` is sampled in the fast clock domain, so pulse it for one fast
        # cycle after programming the requested packet shape.
        self.dut.packetLength.value = packet_length
        self.dut.forceEofe.value = int(force_eofe)
        self.dut.trig.value = 1
        await self.fast_cycle(1)
        self.dut.trig.value = 0

    async def wait_update(self):
        # The RX status block raises `updated` when one packet result is ready.
        await with_timeout(RisingEdge(self.dut.updated), 2, "ms")
        return {
            "errMissedPacket": int(self.dut.errMissedPacket.value),
            "errLength": int(self.dut.errLength.value),
            "errDataBus": int(self.dut.errDataBus.value),
            "errEofe": int(self.dut.errEofe.value),
            "errWordCnt": int(self.dut.errWordCnt.value),
            "rxPacketLength": int(self.dut.rxPacketLength.value),
        }

    async def pulse_fast_reset(self):
        # Reset only the TX side so the RX side sees a discontinuity in the PRBS
        # sequence and can flag the missed-packet condition.
        self.dut.fastRst.value = 1
        await self.fast_cycle(3)
        self.dut.fastRst.value = 0
        await self.fast_cycle(2)


@cocotb.test()
async def ssi_prbs_directed_loopback_test(dut):
    tb = TB(dut)
    await tb.reset()

    # First prove a normal clean packet updates status with no error flags set.
    await tb.trigger_packet(packet_length=5)
    status = await tb.wait_update()
    assert status == {
        "errMissedPacket": 0,
        "errLength": 0,
        "errDataBus": 0,
        "errEofe": 0,
        "errWordCnt": 0,
        "rxPacketLength": 5,
    }

    # A zero request should clamp to the module's minimum visible packet
    # length, not to an empty frame.
    await tb.trigger_packet(packet_length=0)
    status = await tb.wait_update()
    assert status == {
        "errMissedPacket": 0,
        "errLength": 0,
        "errDataBus": 0,
        "errEofe": 0,
        "errWordCnt": 0,
        "rxPacketLength": 2,
    }

    # Forcing `EOFE` should only raise the EOFE error bit, while the rest of
    # the packet accounting stays correct.
    await tb.trigger_packet(packet_length=4, force_eofe=True)
    status = await tb.wait_update()
    assert status == {
        "errMissedPacket": 0,
        "errLength": 0,
        "errDataBus": 0,
        "errEofe": 1,
        "errWordCnt": 0,
        "rxPacketLength": 4,
    }
    dut.forceEofe.value = 0

    # Send one more clean packet before the TX-only reset to show the link is
    # healthy immediately beforehand.
    await tb.trigger_packet(packet_length=5)
    status = await tb.wait_update()
    assert status["errMissedPacket"] == 0

    # Resetting only the transmitter restarts the PRBS seed sequence, so the
    # receiver should report a missed packet on the next update.
    await tb.pulse_fast_reset()
    await tb.trigger_packet(packet_length=5)
    status = await tb.wait_update()
    assert status == {
        "errMissedPacket": 1,
        "errLength": 0,
        "errDataBus": 0,
        "errEofe": 0,
        "errWordCnt": 0,
        "rxPacketLength": 5,
    }


PARAMETER_SWEEP = [pytest.param({}, id="directed_loopback")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiPrbs(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiprbswrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiPrbsWrapper.vhd"]},
    )
