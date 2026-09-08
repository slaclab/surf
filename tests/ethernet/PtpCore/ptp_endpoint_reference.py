##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Independent numerical contracts for the autonomous endpoint.

Calibration is expressed in local PHC nanoseconds, matching the physical
adapter. Its contribution to elapsed master time must therefore be converted
using the capture-time PHC increment, independently at ingress and egress.
"""

from fractions import Fraction
from tests.ethernet.PtpCore.ptp_reference import nearest, Q16, Q32, NS

Q48 = 1 << 48


def elapsed_master_q16(rx_tick_phase, tx_tick_phase, ratio_q48,
                       ingress_q16=0, egress_q16=0,
                       rx_increment_q32=8*Q32, tx_increment_q32=8*Q32):
    raw = nearest(Fraction((tx_tick_phase-rx_tick_phase)*ratio_q48, 1 << 35))
    ingress = nearest(Fraction(ingress_q16*ratio_q48, rx_increment_q32 << 16))
    egress = nearest(Fraction(egress_q16*ratio_q48, tx_increment_q32 << 16))
    return raw+ingress+egress


class RateEstimator:
    """Bootstrap without requiring PHC validity or an accepted path delay.

    Two qualified intervals establish validity. Each interval must meet minimum
    observation span and absolute oscillator bounds. The filtered estimate is
    updated by one quarter of the error; a rejected interval does not refresh
    its age. Packet delay variation remains observable estimator uncertainty.
    """

    def __init__(self, frequency, minimum_span, maximum_age, maximum_ppb=200000):
        self.nominal = Fraction(NS, frequency)
        self.minimum_span = minimum_span
        self.maximum_age = maximum_age
        self.maximum_ppb = maximum_ppb
        self.anchor = None
        self.ratio = nearest(self.nominal*Q48)
        self.count = 0
        self.updated = None

    def observe(self, remote_q16, raw_phase, now):
        if self.anchor is None:
            self.anchor = (remote_q16, raw_phase)
            return False
        remote_a, raw_a = self.anchor
        span = raw_phase-raw_a
        if span < self.minimum_span*8 or remote_q16 <= remote_a:
            return False
        self.anchor = (remote_q16, raw_phase)
        candidate = nearest(Fraction((remote_q16-remote_a) << 35, span))
        if abs(Fraction(candidate, Q48)-self.nominal) > self.nominal*Fraction(self.maximum_ppb, NS):
            return False
        self.ratio = candidate if self.count == 0 else self.ratio+nearest(Fraction(candidate-self.ratio, 4))
        self.count = min(2, self.count+1)
        self.updated = now
        return True

    def valid(self, now):
        return self.count == 2 and now-self.updated <= self.maximum_age


class PiController:
    """Mathematical PI oracle with the implemented Q16 state quantization.

    Gains are rational values with physical units ppb/ns and ppb/(ns*s).
    The oracle intentionally does not reproduce the RTL operation sequencer.
    """

    def __init__(self, kp=Fraction(1, 4), ki=Fraction(1, 16),
                 max_frequency=100000, max_slew=50000, max_rate=150000):
        self.kp, self.ki = kp, ki
        self.max_frequency, self.max_slew, self.max_rate = max_frequency, max_slew, max_rate
        self.frequency = 0
        self.tracking = False

    @staticmethod
    def clamp(value, maximum):
        limit = maximum*Q16
        return min(limit, max(-limit, value))

    def sample(self, offset_q16, interval, bootstrap_ppb_q16):
        slew = self.clamp(-nearest(offset_q16*self.kp), self.max_slew)
        if not self.tracking:
            base = self.clamp(bootstrap_ppb_q16, self.max_frequency)
            frequency = self.clamp(base-slew, self.max_frequency)
        else:
            delta = -nearest(offset_q16*self.ki*interval)
            proposed = self.frequency+delta
            frequency = self.clamp(proposed, self.max_frequency)
            outside_frequency = proposed != frequency
            outside_rate = frequency+slew != self.clamp(frequency+slew, self.max_rate)
            outward = ((outside_frequency and proposed*delta > 0) or
                       (outside_rate and (frequency+slew)*delta > 0))
            if outward:
                frequency = self.frequency
        self.frequency = frequency
        self.tracking = True
        return self.clamp(frequency+slew, self.max_rate)

    def holdover(self):
        self.tracking = False
        return self.clamp(self.frequency, self.max_rate)
