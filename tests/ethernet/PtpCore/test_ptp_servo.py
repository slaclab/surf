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
# - Sweep: Both oscillator correction signs, variable sample intervals, offset
#   signs, command backpressure, median startup and holdover cancellation.
# - Stimulus: AXI configuration and independent rational PI oracle; intervals are injected
#   directly so numerical seconds do not require millions of simulator cycles.
# - Checks: Every applied rate addend, full-width offset/filter state, and held
#   command against the oracle; no PHC packet model is embedded in the wrapper.
# - Timing: Each sample must yield a bounded command; commands are acknowledged
#   only after a real ready/valid transfer. Abort precedes holdover work.

from fractions import Fraction
import cocotb
from cocotb.triggers import Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_reference import nearest, Q16, Q32, NS
from tests.ethernet.PtpCore.ptp_endpoint_reference import PiController, Q48

@cocotb.test()
async def numerical_control(d):
    async def edge(**values):
        d.clk.value = 0
        for name, value in values.items():
            getattr(d, name).value = value
        await Timer(4, unit="ns")
        d.clk.value = 1
        await Timer(4, unit="ns")
    for name in ("clk", "cancel", "ticks", "sampleTicks", "isDelay", "forwardValue", "delayValue", "ratio",
                 "inputValid", "commandReady", "commandAck", "commandError", "prepareConfig", "applyConfig"):
        getattr(d, name).value = 0
    d.rst.value = 0
    axil = AxiLiteMaster(AxiLiteBus.from_prefix(d, "axil"), d.clk, d.rst)

    async def configure():
        # Use the production shadow/candidate/active path. Shared limits are
        # supplied by the fixture's port record; local limits belong to AXI.
        for address, value in ((0x060, (1 << 62)-1), (0x068, 250000000),
                               (0x070, 1), (0x078, (1 << 62)-1)):
            transaction = cocotb.start_soon(axil.write(address, value.to_bytes(8, "little")))
            for _ in range(100):
                await edge()
                if transaction.done():
                    assert transaction.result().resp == AxiResp.OKAY
                    break
            else:
                assert False, "servo AXI write timeout"
        await edge(prepareConfig=1)
        assert int(d.configValid.value)
        await edge(prepareConfig=0, applyConfig=1)
        await edge(applyConfig=0)

    async def collect(expected_ppb):
        for _ in range(1600):
            if int(d.commandValid.value):
                break
            await edge()
        else:
            assert False, "servo command timeout"
        expected_rate = nearest(Fraction(8*Q32*expected_ppb, NS*Q16))
        assert int(d.commandKind.value) == 2
        assert int(d.commandRate.value) == expected_rate & ((1 << 64)-1)
        for _ in range(3):
            await edge()
            assert int(d.commandValid.value)
            assert int(d.commandRate.value) == expected_rate & ((1 << 64)-1)
        await edge(commandReady=1)
        await edge(commandReady=0, commandAck=1)
        await edge(commandAck=0)
    for ppm in (-100, 100):
        await edge(rst=1)
        await edge(rst=0)
        await configure()
        model = PiController()
        ratio = nearest(8*(1+Fraction(ppm, 1000000))*Q48)
        bootstrap = nearest(Fraction((ratio-8*Q48)*NS, 8*Q32))
        now = 100
        for index, delay in enumerate([100, 101, 500, 99, 100]):
            await edge(ticks=now+1, sampleTicks=now, isDelay=1, delayValue=delay*Q16, inputValid=1)
            await edge(inputValid=0)
            now += 10
            assert int(d.filterCount.value) == index+1
        assert int(d.filteredDelay.value) == 100*Q16
        last_sample = 0
        for index in range(20):
            interval = (Fraction(1, 8), Fraction(1, 4), Fraction(1))[index % 3]
            now = last_sample + int(interval*125000000)
            offset = (1000, -500, 100, -20, 0)[index % 5]*Q16+13
            expected_ppb = model.sample(offset, interval, bootstrap)
            assert int(d.inputReady.value)
            await edge(ticks=now+100, sampleTicks=now, isDelay=0, forwardValue=(100*Q16+offset) & ((1 << 128)-1),
                       ratio=ratio, inputValid=1)
            await edge(inputValid=0)
            await collect(expected_ppb)
            assert int(d.offsetValue.value) == offset & ((1 << 128)-1)
            last_sample = now
        # A held port abort cancels old work once, then permits a new frequency-
        # only holdover command. It must not repeatedly cancel that command.
        await edge(cancel=1)
        await edge()
        await collect(model.holdover())
        assert int(d.servoState.value) == 4
        await edge(ticks=now+250000001)
        assert int(d.expireTime.value)
        await edge(cancel=0)


def test_ptp_servo():
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptpservowrapper")
