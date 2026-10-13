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
#   Exercise default limits and +/-200000 ppb with sums beyond 35 signed bits.
#   Include signed64 offset extrema, unsigned32 gain extrema and fractional
#   half ties; compare Q16 rate state before the PHC-addend quantization.
#   Check registered valid/cancel/expiry before and after input-changing edges.
#   Median cases cover every ordering, startup count, duplicates, signed64
#   maximum, circular replacement and abort/restart of partially filled history.
#   Cancel each median phase and the shared arithmetic transition windows;
#   check stalled inputs, AXI-only reset, stale work and coherent snapshots.
#   Clock cases cover both MAC nominal increments and a standalone nominal
#   divisor wider than the seconds/ppb constants (47 rather than 46 bits).
# - Stimulus: AXI configuration and independent rational PI oracle; intervals are injected
#   directly so numerical seconds do not require millions of simulator cycles.
# - Checks: Every applied rate addend, full-width offset/filter state, and held
#   command against the oracle; no PHC packet model is embedded in the wrapper.
# - Timing: Each sample must yield a bounded command; commands are acknowledged
#   only after a real ready/valid transfer. Abort precedes holdover work.

from fractions import Fraction
from collections import deque
from itertools import permutations
import cocotb
import pytest
from cocotb.triggers import Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp
from tests.common.regression_utils import env_int, run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_reference import nearest, Q16, Q32, NS
from tests.ethernet.PtpCore.ptp_endpoint_reference import PiController, Q48

@cocotb.test()
async def numerical_control(d):
    frequency = env_int("CLK_FREQ_G", default=125000000)
    nominal = nearest(Fraction(NS*Q32, frequency))

    async def edge(check_registered=False, **values):
        registered = ("commandValid", "cancelCommand", "expireTime")
        before = tuple(int(getattr(d, name).value) for name in registered) if check_registered else None
        d.clk.value = 0
        for name, value in values.items():
            getattr(d, name).value = value
        await Timer(4, unit="ns")
        if check_registered:
            assert tuple(int(getattr(d, name).value) for name in registered) == before
        d.clk.value = 1
        await Timer(4, unit="ns")
    for name in ("clk", "cancel", "ticks", "sampleTicks", "isDelay", "forwardValue", "delayValue", "ratio",
                 "inputValid", "commandReady", "commandAck", "commandError", "prepareConfig", "applyConfig",
                 "regRst", "restart", "generation", "snapshotCapture", "snapshotSequence"):
        getattr(d, name).value = 0
    d.associationTimeout.value = (1 << 62)-1
    d.rst.value = 0
    d.maxPathDelay.value = 1000000*Q16
    axil = AxiLiteMaster(AxiLiteBus.from_prefix(d, "axil"), d.clk, d.rst)

    async def configure(limits, kp=1 << 28, ki=1 << 26):
        # Use the production shadow/candidate/active path. Shared limits are
        # supplied by the fixture's port record; local limits belong to AXI.
        settings = [(0x020, kp, 4), (0x024, ki, 4),
                    (0x028, limits[0], 4), (0x02C, limits[1], 4), (0x030, limits[2], 4),
                    (0x060, (1 << 62)-1, 8), (0x068, 250000000, 8),
                    (0x070, 1, 8), (0x078, (1 << 62)-1, 8)]
        for address, value, size in settings:
            transaction = cocotb.start_soon(axil.write(address, value.to_bytes(size, "little")))
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

    async def wait_command():
        for _ in range(1600):
            if int(d.commandValid.value):
                break
            await edge()
        else:
            assert False, "servo command timeout"

    async def wait_input():
        for _ in range(1600):
            if int(d.inputReady.value):
                return
            await edge(inputValid=0)
        assert False, "servo input remained busy"

    async def collect(expected_ppb):
        await wait_command()
        expected_rate = nearest(Fraction(nominal*expected_ppb, NS*Q16))
        assert int(d.ratePpb.value) == expected_ppb & ((1 << 64)-1)
        assert int(d.commandKind.value) == 2
        assert int(d.commandRate.value) == expected_rate & ((1 << 64)-1)
        for _ in range(3):
            await edge()
            assert int(d.commandValid.value)
            assert int(d.commandRate.value) == expected_rate & ((1 << 64)-1)
        await edge(commandReady=1)
        await edge(commandReady=0, commandAck=1)
        await edge(commandAck=0)
    cases = [(-100, (100000, 50000, 150000)), (100, (100000, 50000, 150000)),
             (-200, (200000, 200000, 200000)), (200, (200000, 200000, 200000)),
             (1, (200000, 200000, 200000)), (0, (200000, 200000, 200000))]
    for ppm, limits in cases:
        await edge(rst=1)
        await edge(rst=0)
        kp, ki = ((1 << 32)-1, (1 << 32)-1) if ppm == 0 else (1 << 28, 1 << 26)
        await configure(limits, kp, ki)
        model = PiController(kp=Fraction(kp, 1 << 30), ki=Fraction(ki, 1 << 30),
                             max_frequency=limits[0], max_slew=limits[1], max_rate=limits[2])
        ratio = nearest(Fraction(NS, frequency)*(1+Fraction(ppm, 1000000))*Q48)
        bootstrap = nearest(Fraction((ratio-(nominal << 16))*NS, nominal))
        now = 100
        for index, delay in enumerate([100, 101, 500, 99, 100]):
            await edge(ticks=now+1, sampleTicks=now, isDelay=1, delayValue=delay*Q16, inputValid=1)
            await edge(inputValid=0)
            await wait_input()
            now += 10
            assert int(d.filterCount.value) == index+1
        assert int(d.filteredDelay.value) == 100*Q16
        last_sample = 0
        for index in range(20):
            interval = (Fraction(1, 8), Fraction(1, 4), Fraction(1))[index % 3]
            if ppm in (0, 1):
                interval = Fraction(1)
            now = last_sample + int(interval*frequency)
            # The controller quantizes elapsed seconds to Q32 before PI work.
            interval = Fraction(nearest(Fraction((now-last_sample)*nominal, NS)), Q32)
            offsets = (1000, -500, 100, -20, 0)
            if abs(ppm) == 200:
                # Bootstrap minus opposite slew can reach +/-400000 ppb.
                # Subsequent same-sign frequency/slew sums exercise the final
                # clamp and anti-windup; preserve low fractional bits as well.
                sign = 1 if ppm > 0 else -1
                offsets = tuple(sign*x for x in (800000, -800000, -1600000, 1600000, 0))
            offset = offsets[index % 5]*Q16+13
            if ppm == 1:
                offsets = (0, 1, 2, 3, -1, -2, -3, 7, 8, 9, -7, -8, -9)
                offset = offsets[index % len(offsets)]
            elif ppm == 0:
                # One-second integration with maximum gain approaches both
                # signed128 product boundaries; the rounded delta exceeds 64 bits.
                offsets = (0, -(1 << 63), (1 << 63)-1, 1, -1, 2, -2)
                offset = offsets[index % len(offsets)]
            expected_ppb = model.sample(offset, interval, bootstrap)
            assert int(d.inputReady.value)
            await edge(ticks=now+100, sampleTicks=now, isDelay=0, forwardValue=(100*Q16+offset) & ((1 << 128)-1),
                       ratio=ratio, inputValid=1)
            await edge(inputValid=0)
            await collect(expected_ppb)
            assert int(d.offsetValue.value) == offset & ((1 << 128)-1)
            last_sample = now
        if ppm == 0:
            # Maximum gain/offset times 1.5 s exceeds signed128 before the
            # rounded integral shift. It must reject rather than clamp a
            # truncated product or update the acknowledged frequency.
            rejected = int(d.rejectedCount.value)
            previous_rate = int(d.ratePpb.value)
            now = last_sample+frequency*3//2
            await edge(ticks=now+100, sampleTicks=now, isDelay=0,
                       forwardValue=(100*Q16-(1 << 63)) & ((1 << 128)-1), inputValid=1)
            await edge(inputValid=0)
            await wait_input()
            assert int(d.rejectedCount.value) == rejected+1
            assert int(d.ratePpb.value) == previous_rate
            assert not int(d.commandValid.value)
        # A held port abort cancels old work once, then permits a new frequency-
        # only holdover command. It must not repeatedly cancel that command.
        await edge(cancel=1)
        await edge()
        await wait_command()
        # A new cancellation coincident with ready may transfer the registered
        # request. The PHC must reject it on its next edge (leaf PHC test).
        # The servo withdraws valid and emits cancellation after this edge.
        await edge(check_registered=True, cancel=0)
        await edge(check_registered=True, cancel=1, commandReady=1)
        assert not int(d.commandValid.value)
        assert int(d.cancelCommand.value)
        await edge(commandReady=0, commandAck=1, commandError=1)
        await edge(commandAck=0, commandError=0)
        await collect(model.holdover())
        assert int(d.servoState.value) == 4
        await edge(check_registered=True, ticks=last_sample+250000000)
        assert not int(d.expireTime.value)
        await edge(check_registered=True, ticks=last_sample+250000001)
        assert int(d.expireTime.value)
        await edge(cancel=0)

    # Sweep the boundaries surrounding bootstrap clamp, proportional rounding/
    # seeding, and integral rounding/anti-windup. These are cancellation timing
    # windows, not a reproduction of the numerical calculation.
    for tracking, cutoffs in ((False, (*range(259, 263), *range(390, 397))),
                              (True, range(912, 919))):
        for cutoff in cutoffs:
            await edge(rst=1, inputValid=0, cancel=0, commandReady=0, commandAck=0)
            await edge(rst=0)
            await configure((100000, 50000, 150000))
            model = PiController()
            ratio = nearest(Fraction(NS, frequency)*(1+Fraction(100, 1000000))*Q48)
            bootstrap = nearest(Fraction((ratio-(nominal << 16))*NS, nominal))
            await edge(ticks=100, sampleTicks=100, isDelay=1, delayValue=100*Q16, inputValid=1)
            await edge(inputValid=0)
            await wait_input()
            now = frequency
            if tracking:
                await edge(ticks=now, sampleTicks=now, isDelay=0, forwardValue=101*Q16,
                           ratio=ratio, inputValid=1)
                await edge(inputValid=0)
                await collect(model.sample(Q16, Fraction(1), bootstrap))
                now += frequency
            await edge(ticks=now, sampleTicks=now, isDelay=0, forwardValue=200*Q16,
                       ratio=ratio, inputValid=1)
            for _ in range(cutoff):
                await edge(inputValid=0)
                assert not int(d.commandValid.value)
            await edge(check_registered=True, cancel=1)
            assert not int(d.commandValid.value)
            assert int(d.filterCount.value) == 0
            await edge(cancel=0)
            if tracking:
                # Canceled integration must leave the acknowledged frequency
                # intact; holdover removes slew and exposes that retained value.
                await collect(model.holdover())
            else:
                for _ in range(700):
                    await edge()
                    assert not int(d.commandValid.value)


@cocotb.test()
async def median_history(d):
    # The wrapper supplies the full shared delay bound; production RTL still
    # validates each sample. AXI reads below check snapshots across publication.
    for name in ("clk", "rst", "cancel", "ticks", "sampleTicks", "isDelay", "forwardValue",
                 "delayValue", "ratio", "inputValid", "commandReady", "commandAck",
                 "commandError", "prepareConfig", "applyConfig", "axil_awaddr", "axil_awvalid",
                 "axil_wdata", "axil_wstrb", "axil_wvalid", "axil_bready", "axil_araddr",
                 "axil_arvalid", "axil_rready", "regRst", "restart", "generation",
                 "snapshotCapture", "snapshotSequence"):
        getattr(d, name).value = 0
    d.associationTimeout.value = (1 << 62)-1
    maximum = (1 << 63)-1
    d.maxPathDelay.value = maximum

    async def edge(**values):
        d.clk.value = 0
        for name, value in values.items():
            getattr(d, name).value = value
        await Timer(4, unit="ns")
        accepted = bool(int(d.inputValid.value) and int(d.inputReady.value))
        d.clk.value = 1
        await Timer(4, unit="ns")
        return accepted

    async def submit(value, tick):
        before = (int(d.filteredDelay.value), int(d.filterCount.value))
        assert await edge(ticks=tick, sampleTicks=tick, inputValid=1, isDelay=1, delayValue=value)
        for _ in range(9):
            assert not int(d.inputReady.value)
            assert (int(d.filteredDelay.value), int(d.filterCount.value)) == before
            assert not await edge(inputValid=0)
        assert int(d.inputReady.value)

    await edge(rst=1)
    await edge(rst=0)
    cases = list(permutations((0, 1, Q16, maximum-1, maximum)))
    cases += [(maximum,)*7, (0,)*7, (5, 5, 1, 1, 5, 0, maximum, 2, 2, 3, 4)]
    now = 0
    for values in cases:
        await edge(cancel=1, inputValid=0)
        assert int(d.filterCount.value) == 0
        await edge(cancel=0)
        history = deque(maxlen=5)
        for value in values:
            now += 1
            await submit(value, now)
            history.append(value)
            expected = sorted(history)[(len(history)-1)//2]
            assert int(d.filterCount.value) == len(history)
            assert int(d.filteredDelay.value) == expected, (values, list(history), expected)
        # A rejected sample must leave both the median and replacement order intact.
        rejected = int(d.rejectedCount.value)
        now += 1
        await edge(ticks=now, sampleTicks=now, delayValue=maximum+1, inputValid=1)
        assert int(d.rejectedCount.value) == rejected+1
        assert int(d.filteredDelay.value) == expected
        now += 1
        await submit(17, now)
        history.append(17)
        assert int(d.filteredDelay.value) == sorted(history)[(len(history)-1)//2]
        await edge(inputValid=0)

    # Present the next sample immediately and hold it through the busy period.
    # Score transfers using pre-edge ready, including consecutive valid high.
    await edge(cancel=1, inputValid=0)
    await edge(cancel=0)
    values = (5, 4, 3, 2, 1, 8, 0)
    history = deque(maxlen=5)
    accepted_count = 0
    pending = None
    published = (int(d.filteredDelay.value), 0)
    for cycle in range(10*len(values)):
        index = min(accepted_count, len(values)-1)
        accepted = await edge(ticks=10000+cycle, sampleTicks=10000+index,
                              inputValid=int(accepted_count < len(values)), delayValue=values[index])
        if accepted:
            assert pending is None
            history.append(values[index])
            pending = (cycle+9, sorted(history)[(len(history)-1)//2], len(history))
            accepted_count += 1
        if pending is not None and cycle == pending[0]:
            published = pending[1:]
            pending = None
        assert (int(d.filteredDelay.value), int(d.filterCount.value)) == published
    assert accepted_count == len(values) and pending is None
    await edge(inputValid=0)

    # Abort/reset/generation/staleness on each comparison edge, including the
    # publication edge. The canceled sample may never reappear in later history.
    for reason in ("cancel", "restart", "generation", "rst", "stale"):
        for phase in range(9):
            await edge(rst=1, cancel=0, restart=0, generation=0, inputValid=0,
                       associationTimeout=(1 << 62)-1)
            await edge(rst=0)
            await submit(11, 100)
            assert await edge(ticks=101, sampleTicks=101, inputValid=1, delayValue=5)
            for _ in range(phase):
                await edge(inputValid=0)
            event = {reason: 1} if reason != "stale" else {"associationTimeout": 2, "ticks": 104}
            await edge(inputValid=0, **event)
            assert int(d.filterCount.value) == 0, (reason, phase)
            assert not int(d.commandValid.value)
            assert int(d.filteredDelay.value) == (0 if reason == "rst" else 11)
            await edge(rst=0, cancel=0, restart=0, associationTimeout=(1 << 62)-1)
            await submit(17, 200)
            assert int(d.filterCount.value) == 1
            assert int(d.filteredDelay.value) == 17

    axil = AxiLiteMaster(AxiLiteBus.from_prefix(d, "axil"), d.clk, d.rst)

    async def read(address, size):
        transaction = cocotb.start_soon(axil.read(address, size))
        for _ in range(100):
            await edge()
            if transaction.done():
                assert transaction.result().resp == AxiResp.OKAY
                return int.from_bytes(transaction.result().data, "little")
        assert False, "servo snapshot read timed out"

    # AXI-only reset cannot discard admitted filter work. A snapshot on the
    # publication edge captures the previous complete value; the next sees new.
    for phase in range(9):
        await edge(rst=1, inputValid=0, generation=0)
        await edge(rst=0)
        await submit(11, 100)
        assert await edge(ticks=101, sampleTicks=101, inputValid=1, delayValue=5)
        for cycle in range(9):
            await edge(inputValid=0, regRst=int(cycle == phase),
                       snapshotCapture=int(cycle == 8), snapshotSequence=phase)
        assert (int(d.filteredDelay.value), int(d.filterCount.value)) == (5, 2)
        await edge(regRst=0, snapshotCapture=0)
        assert await read(0x110, 16) == 11
        assert await read(0x3FC, 4) == phase
        await edge(snapshotCapture=1, snapshotSequence=phase+100)
        await edge(snapshotCapture=0)
        assert await read(0x110, 16) == 5
        assert await read(0x3FC, 4) == phase+100


@pytest.mark.parametrize("frequency", [125000000, 156250000, 31250],
                         ids=["125MHz", "156MHz", "wide-divisor"])
def test_ptp_servo(frequency):
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptpservowrapper",
                      parameters={"CLK_FREQ_G": frequency})
