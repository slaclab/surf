#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: Both oscillator signs and Sync modes with 8 Hz timestamps.
# - Stimulus: Independent piecewise oscillator drift, signed packet-delay
#   variation, a path step, an outlier and a four-packet loss burst.
# - Checks: Production association/rate results against a rational rate oracle,
#   exact forward samples despite independent PHC steering, rejected-estimate
#   freshness, held results and inclusive ratio expiry without port restart.
# - Timing: Raw time skips idle periods; all production pipelines run normally.
#   This tests rate dynamics, not a continuous PHC/servo accuracy trajectory.

from fractions import Fraction
import os

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_endpoint_reference import RateEstimator, Q48
from tests.ethernet.PtpCore.ptp_reference import nearest
from tests.ethernet.PtpCore.test_ptp_port_samples import Bench, NS, Q16

HZ = 125000000


@cocotb.test(timeout_time=5, timeout_unit='ms')
async def disturbed_source(d):
    b = Bench(d)
    await b.start()
    try:
        await b.write(0x088, 4*HZ)
        await b.write(0x0A0, HZ//16)
        await b.write(0x0A8, 2*HZ)
        d.prepare.value = 1
        await b.wait()
        d.prepare.value = 0
        await b.wait_config()
        assert int(d.configValid.value)
        await b.pulse('applyConfig')
        model = RateEstimator(HZ, HZ//16, 2*HZ)
        sign = int(os.environ['OSCILLATOR_SIGN'])
        two_step = bool(int(os.environ['TWO_STEP']))
        raw = Fraction(0)
        qualified = rejected = delivered = 0
        for index in range(64):
            # Integrate a free-running oscillator; never derive master time
            # from the DUT PHC or from the estimator output being checked.
            ppb = sign*(100000+min(max(index-20, 0), 20)*1000)
            period = Fraction(NS, HZ)/(1+Fraction(ppb, NS))
            raw += Fraction(NS, 8)/period*8
            if index in (32, 33, 34, 35):
                continue
            path = 1000+(800 if index >= 20 else 0)
            pdv = (-100, 100, 0, 50, -50)[index % 5]
            if index == 16:
                pdv += 100000  # Out-of-envelope estimate must not refresh age.
            capture = nearest(raw+Fraction(path+pdv, period)*8)
            tick, phase = divmod(capture, 8)
            remote = (index+1)*NS//8
            # Deliberate numerical-PHC phase changes cannot change raw rate.
            forward = (path+pdv+17+(200 if index % 2 else -200))*Q16+7
            d.capturePhase.value = phase
            old_updated = model.updated
            accepted = model.observe(remote*Q16, capture, tick)
            if old_updated is not None and not accepted:
                rejected += 1
                assert model.updated == old_updated
            await b.send(0, index, remote, ticks=tick, local=remote*Q16+forward,
                         two_step=two_step)
            if two_step:
                await b.send(8, index, remote)
            result = await b.result(index, forward, tick)
            assert result[4] == model.ratio, (index, result[4], model.ratio)
            assert result[5] == model.valid(b.now), (index, result, model.updated)
            held = b.payload()
            await b.wait(5)
            assert int(d.measurementValid.value) and b.payload() == held
            await b.drain()
            qualified += bool(result[5])
            delivered += 1
        assert delivered == 60 and qualified > 50 and rejected >= 2
        true_ratio = Fraction(NS, HZ)/(1+Fraction(sign*120000, NS))
        assert abs(Fraction(model.ratio, Q48)/true_ratio-1) < Fraction(1000, NS)
        assert model.updated is not None
        # Finish with a rejected estimate and no later good sample. Expiry
        # must still use the last accepted estimate's age; checking only the
        # held ratio would miss a rejection that incorrectly refreshes age.
        raw += Fraction(NS, 8)/period*8
        capture = nearest(raw+Fraction(101800, period)*8)
        tick, phase = divmod(capture, 8)
        remote = 65*NS//8
        forward = 101817*Q16+7
        d.capturePhase.value = phase
        updated = model.updated
        assert not model.observe(remote*Q16, capture, tick)
        assert model.updated == updated
        await b.send(0, 64, remote, ticks=tick, local=remote*Q16+forward, two_step=two_step)
        if two_step:
            await b.send(8, 64, remote)
        result = await b.result(64, forward, tick)
        assert result[4] == model.ratio and result[5]
        await b.drain()
        # Sync timeout is longer than ratio age: this isolates stale ratio
        # invalidation from port cancellation and leaves the source active.
        async def status():
            value = await b.axil.read(0x044, 4)
            return int.from_bytes(value.data, 'little')
        for extra, valid in ((0, True), (1, False)):
            d.ticks.value = model.updated+2*HZ+extra
            await b.wait(4)
            flags = await status()
            assert flags & 1, 'ratio age test unexpectedly restarted the port'
            assert bool(flags & 4) == valid
    finally:
        b.stop()


@pytest.mark.parametrize('sign', [-1, 1], ids=['slow', 'fast'])
@pytest.mark.parametrize('two_step', [False, True], ids=['one-step', 'two-step'])
def test_ptp_disturbance(sign, two_step):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpprotocolenginewrapper',
                      extra_env={'OSCILLATOR_SIGN': sign, 'TWO_STEP': int(two_step)},
                      extra_vhdl_sources={'surf': ['ethernet/PtpCore/wrappers/PtpProtocolEngineWrapper.vhd']})
