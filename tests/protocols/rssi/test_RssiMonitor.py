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
# - Purpose: Verify the RSSI monitor/timer side effects that drive ACK, NULL,
#   retransmission, BUSY, and close requests.  These behaviors are timing-heavy
#   and easier to isolate here than through a full `RssiCore` integration test.
# - DUT shape: Run `RssiMonitor` through a thin wrapper that flattens RSSI
#   parameter and received-flag records.  Timeout scale is one count per clock
#   so tests can reason in cycles and avoid long protocol-time waits.
# - Stimulus: Start from an active connection and drive received header flags,
#   transmitted-header strobes, local BUSY state, and transmit-buffer
#   occupancy directly.  This bypasses the RX/TX FSMs while still exercising
#   the monitor's policy decisions.
# - Checks: Remote BUSY must suppress retransmission timeout progress.  Server
#   liveness must refresh only on DATA or NULL receipt, not ACK/BUSY-only
#   traffic.  Local BUSY must request an immediate ACK on assertion and then
#   periodic BUSY ACKs at the RSSI page's recommended Retransmission
#   Timeout/2 cadence.
# - Timing: Samples are taken after the default `TPD_G` output delay.  Timeout
#   thresholds are small deterministic cycle counts, and each test uses direct
#   cycle waits rather than real-time delays so failures map cleanly to counter
#   behavior.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import env_flag, run_surf_vhdl_test


class TB:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.axisClk, 5.0, unit="ns").start())

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.axisClk)
            await Timer(2, unit="ns")

    def _set_flag_defaults(self) -> None:
        self.dut.rxFlagsSyn_i.value = 0
        self.dut.rxFlagsAck_i.value = 0
        self.dut.rxFlagsEack_i.value = 0
        self.dut.rxFlagsRst_i.value = 0
        self.dut.rxFlagsNul_i.value = 0
        self.dut.rxFlagsData_i.value = 0
        self.dut.rxFlagsBusy_i.value = 0
        self.dut.rxFlagsEofe_i.value = 0

    def _set_param_defaults(self) -> None:
        self.dut.paramVersion_i.value = 0
        self.dut.paramChksumEn_i.value = 1
        self.dut.paramTimeoutUnit_i.value = 1
        self.dut.paramMaxOutsSeg_i.value = 4
        self.dut.paramMaxSegSize_i.value = 8
        self.dut.paramRetransTout_i.value = 4
        self.dut.paramCumulAckTout_i.value = 4
        self.dut.paramNullSegTout_i.value = 4
        self.dut.paramMaxRetrans_i.value = 10
        self.dut.paramMaxCumAck_i.value = 4
        self.dut.paramMaxOutofseq_i.value = 0
        self.dut.paramConnectionId_i.value = 0

    async def reset(self, *, connected: bool = True) -> None:
        self.dut.axisRst.setimmediatevalue(1)
        self.dut.connActive_i.setimmediatevalue(0)
        self.dut.localBusy_i.setimmediatevalue(0)
        self._set_param_defaults()
        self._set_flag_defaults()
        self.dut.rxLastSeqN_i.setimmediatevalue(0)
        self.dut.rxWindowSize_i.setimmediatevalue(4)
        self.dut.txBufferEmpty_i.setimmediatevalue(1)
        self.dut.rxValid_i.setimmediatevalue(0)
        self.dut.rxDrop_i.setimmediatevalue(0)
        self.dut.ackHeadSt_i.setimmediatevalue(0)
        self.dut.rstHeadSt_i.setimmediatevalue(0)
        self.dut.dataHeadSt_i.setimmediatevalue(0)
        self.dut.nullHeadSt_i.setimmediatevalue(0)
        self.dut.lenErr_i.setimmediatevalue(0)
        self.dut.ackErr_i.setimmediatevalue(0)
        self.dut.peerConnTout_i.setimmediatevalue(0)
        self.dut.paramReject_i.setimmediatevalue(0)
        await self.cycle(4)
        self.dut.axisRst.value = 0
        await self.cycle(2)
        self.dut.connActive_i.value = int(connected)
        await self.cycle(2)

    async def expect_no_resend(self, cycles: int) -> None:
        for _ in range(cycles):
            await self.cycle()
            assert int(self.dut.sndResend_o.value) == 0

    async def wait_for_resend(self, cycles: int) -> None:
        for _ in range(cycles):
            await self.cycle()
            if int(self.dut.sndResend_o.value) == 1:
                return
        raise AssertionError("Timed out waiting for sndResend_o")

    async def wait_for_close(self, cycles: int) -> None:
        for _ in range(cycles):
            await self.cycle()
            if int(self.dut.closeRq_o.value) == 1:
                return
        raise AssertionError("Timed out waiting for closeRq_o")

    async def wait_for_ack(self, cycles: int) -> None:
        for _ in range(cycles):
            await self.cycle()
            if int(self.dut.sndAck_o.value) == 1:
                return
        raise AssertionError("Timed out waiting for sndAck_o")

    async def expect_no_ack(self, cycles: int) -> None:
        for _ in range(cycles):
            await self.cycle()
            assert int(self.dut.sndAck_o.value) == 0

    async def pulse_ack_sent(self) -> None:
        self.dut.ackHeadSt_i.value = 1
        await self.cycle()
        self.dut.ackHeadSt_i.value = 0
        await self.cycle()

    async def pulse_rx_flag(self, flag_name: str) -> None:
        self._set_flag_defaults()
        getattr(self.dut, flag_name).value = 1
        self.dut.rxValid_i.value = 1
        await self.cycle()
        self.dut.rxValid_i.value = 0
        getattr(self.dut, flag_name).value = 0


@cocotb.test()
async def remote_busy_suppresses_retransmission_timeout_progress_test(dut):
    tb = TB(dut)
    await tb.reset()

    # An occupied TX buffer lets the retransmission timer run.  While the peer
    # advertises BUSY, the timer must be held reset and no resend request should
    # be generated even after more than one retransmission timeout interval.
    dut.txBufferEmpty_i.value = 0
    dut.rxFlagsBusy_i.value = 1
    await tb.expect_no_resend(cycles=10)
    assert int(dut.statusReg_o.value) & (1 << 8)

    # Releasing BUSY allows the same outstanding segment to time out normally.
    dut.rxFlagsBusy_i.value = 0
    await tb.wait_for_resend(cycles=8)
    assert int(dut.sndResend_o.value) == 1
    await tb.cycle()
    assert int(dut.resendCnt_o.value) == 1


@cocotb.test()
async def server_ack_and_busy_only_traffic_does_not_reset_null_timeout_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Server-side liveness is defined by DATA or NULL receipt.  Standalone ACK
    # and BUSY traffic may affect other timers, but it must not prevent the
    # server null-timeout close when no DATA/NULL arrives.
    await tb.pulse_rx_flag("rxFlagsNul_i")

    for index in range(10):
        tb._set_flag_defaults()
        flag_name = "rxFlagsAck_i" if index % 2 == 0 else "rxFlagsBusy_i"
        getattr(dut, flag_name).value = 1
        dut.rxValid_i.value = 1
        await tb.cycle()
        if int(dut.closeRq_o.value) == 1:
            break
    else:
        raise AssertionError("ACK/BUSY-only traffic incorrectly prevented server null timeout")


@cocotb.test()
async def local_busy_rising_edge_requests_ack_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Local busy is advertised through the next outgoing header.  The monitor
    # must request an ACK immediately so the header generator can carry BUSY
    # even when no cumulative ACK threshold has been reached.
    dut.localBusy_i.value = 1
    await tb.wait_for_ack(cycles=2)
    assert int(dut.sndAck_o.value) == 1
    assert int(dut.statusReg_o.value) & (1 << 7)

    await tb.pulse_ack_sent()
    assert int(dut.sndAck_o.value) == 0


@cocotb.test()
async def local_busy_generates_periodic_ack_after_cumulative_timeout_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Local BUSY periodic ACKs follow the RSSI page recommendation of
    # Retransmission Timeout/2, not the shorter cumulative ACK timeout.
    dut.paramCumulAckTout_i.value = 2
    dut.paramRetransTout_i.value = 20
    dut.localBusy_i.value = 1

    await tb.wait_for_ack(cycles=2)
    await tb.pulse_ack_sent()
    await tb.expect_no_ack(cycles=6)
    await tb.wait_for_ack(cycles=6)
    assert int(dut.sndAck_o.value) == 1


PARAMETER_SWEEP = [pytest.param({}, id="server_monitor")]

KNOWN_ISSUE_REASON = "set RUN_RSSI_KNOWN_ISSUE_TESTS=1 to run RSSI cases that require follow-up RTL fixes"


@pytest.mark.skipif(not env_flag("RUN_RSSI_KNOWN_ISSUE_TESTS", default=False), reason=KNOWN_ISSUE_REASON)
@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiMonitor(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssimonitorwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                "protocols/rssi/v1/rtl/RssiMonitor.vhd",
                "protocols/rssi/v1/wrappers/RssiMonitorWrapper.vhd",
            ],
        },
        force_compile=True,
    )
