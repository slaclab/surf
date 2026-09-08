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
# - Sweep: Oscillator error signs, lane phases, signed calibration, PHC rate
#   changes during exchanges, bootstrap packet-delay variation and stale estimates.
# - Stimulus: Exact rational clock/plane coordinates independent of RTL.
# - Checks: Q16 elapsed reconstruction within three rounding units; estimator
#   progresses before path-delay acceptance and never refreshes from bad data.
# - Timing: Ages and spans use unsteered ticks, independent of numerical PHC steps.

from fractions import Fraction
import pytest
from tests.ethernet.PtpCore.ptp_reference import nearest, Q16, Q32, NS
from tests.ethernet.PtpCore.ptp_endpoint_reference import elapsed_master_q16, RateEstimator, Q48

@pytest.mark.parametrize("ppm", [-100, 0, 100])
@pytest.mark.parametrize("phases", [(0, 4), (4, 0), (0, 0)])
def test_elapsed_reference_planes(ppm, phases):
    ratio = Fraction(32, 5)/(1+Fraction(ppm, 1000000))
    ratio_fixed = nearest(ratio*Q48)
    rx_inc = nearest(Fraction(32, 5)*Q32)
    tx_inc = nearest(Fraction(32, 5)*(1+Fraction(77, 1000000))*Q32)
    ingress, egress = nearest(Fraction(29, 4)*Q16), nearest(Fraction(-7, 2)*Q16)
    rx, tx = 8*1000+phases[0], 8*1563500+phases[1]
    exact = Fraction(tx-rx, 8)*ratio
    exact += Fraction(ingress, Q16)*ratio/Fraction(rx_inc, Q32)
    exact += Fraction(egress, Q16)*ratio/Fraction(tx_inc, Q32)
    got = elapsed_master_q16(rx, tx, ratio_fixed, ingress, egress, rx_inc, tx_inc)
    assert abs(Fraction(got, Q16)-exact) <= Fraction(3, Q16)

@pytest.mark.parametrize("ppm", [-100, 100])
def test_bootstrap_and_pdv(ppm):
    frequency = 156250000
    ratio = Fraction(NS, frequency)/(1+Fraction(ppm, 1000000))
    estimator = RateEstimator(frequency, frequency//2, 4*frequency)
    for index in range(20):
        # Bounded +/-100 ns path changes corrupt the observation coordinate,
        # even though all transmitted master timestamps are exact.
        remote = index*NS
        pdv = (-100, 100, 0, 0)[index % 4]
        ticks8 = nearest(Fraction(remote+1000+pdv, ratio)*8)
        estimator.observe(remote*Q16, ticks8, ticks8//8)
    assert estimator.valid(ticks8//8)
    assert abs(Fraction(estimator.ratio, Q48)/ratio-1) < Fraction(500, NS)
    updated = estimator.updated
    estimator.observe(-Q16, ticks8+frequency*8, ticks8//8+frequency)
    assert estimator.updated == updated
    assert not estimator.valid(updated+4*frequency+1)


@pytest.mark.parametrize("period", [Fraction(1, 8), Fraction(1, 4), Fraction(1)])
@pytest.mark.parametrize("oscillator_ppb", [-100000, 100000])
@pytest.mark.parametrize("initial_offset", [-10000, 10000])
def test_pi_operating_envelope(period, oscillator_ppb, initial_offset):
    from tests.ethernet.PtpCore.ptp_endpoint_reference import PiController
    controller = PiController()
    frequency_scale = 1+Fraction(oscillator_ppb, NS)
    bootstrap = nearest(-Fraction(oscillator_ppb, frequency_scale)*Q16)
    offset = Fraction(initial_offset)
    settled = []
    peak = abs(offset)
    for index in range(int(160/period)):
        command = controller.sample(nearest(offset*Q16), period, bootstrap)
        assert abs(command) <= 150000*Q16
        offset += period*(oscillator_ppb + Fraction(command, Q16)*frequency_scale)
        peak = max(peak, abs(offset))
        if index*period >= 120:
            settled.append(abs(offset))
    assert max(settled) < 100
    assert peak < 12000


def test_pi_anti_windup_and_holdover():
    from tests.ethernet.PtpCore.ptp_endpoint_reference import PiController
    controller = PiController(max_frequency=10, max_slew=5, max_rate=12)
    controller.tracking = True
    controller.frequency = -10*Q16
    controller.sample(1000*Q16, Fraction(1), 0)
    assert controller.frequency == -10*Q16
    controller.sample(-Q16, Fraction(1), 0)
    assert controller.frequency > -10*Q16
    assert controller.holdover() == controller.frequency
    assert not controller.tracking
