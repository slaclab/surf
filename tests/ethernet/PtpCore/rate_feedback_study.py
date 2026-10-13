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
# - Sweep: Two MAC frequencies, +/-100 ppm, cold start, frequency step,
#   independent delay noise, delay step/ramp and a packet gap at 8 Hz Sync.
# - Stimulus: Exact rational free-running clock integration; quantized Q3
#   captures, Q16 master timestamps and seeded integer-ns delay noise.
# - Checks: Compare all candidates on identical intervals admitted by the
#   existing independent RateEstimator. Candidate arithmetic is integer Q48
#   with nearest/ties-away shifts. Check clean convergence and E2E rate error.
# - Timing: Synthetic numerical time, no RTL, PHC servo or compute scheduler.
#   Candidate qualification, clipping and lifecycle logic are not implemented.
#   This is an algorithm study, not a replacement production oracle or test.

"""Run from the SURF root with python -m tests.ethernet.PtpCore.rate_feedback_study.

Optional --csv writes full traces. JSON summaries go to stdout. Dependencies
are the Python standard library and the existing independent reference model.
"""

import argparse
import csv
from fractions import Fraction
import json
import math
from pathlib import Path
import random

from tests.ethernet.PtpCore.ptp_endpoint_reference import Q48, RateEstimator
from tests.ethernet.PtpCore.ptp_reference import NS, Q16, Q32, nearest

EVENT_S = 240
DURATION_S = 720
TAIL_S = 480


def round_shift(value, shift):
    """Integer nearest, ties away; no variable-denominator division."""
    assert shift >= 0
    if shift == 0:
        return value
    magnitude = (abs(value)+(1 << (shift-1))) >> shift
    return -magnitude if value < 0 else magnitude


class Feedback:
    def __init__(self, frequency, kind):
        self.kind = kind
        self.ratio = nearest(Fraction(NS*Q32, frequency)) << 16
        self.updates = 0
        # Predicted master time minus the last observation, scaled by 2**51.
        # A relative residual avoids storing a full epoch in that wider scale.
        self.phase = 0

    def update(self, delta_q16, span_q3):
        power = (span_q3-1).bit_length()  # ceil(log2(span_q3))
        error = (delta_q16 << 35)-self.ratio*span_q3
        if self.kind.startswith('phase_'):
            error -= self.phase
            alpha_shift, beta_shift = (2, 6) if self.kind == 'phase_slow' else (1, 3)
            self.phase = -error+round_shift(error, alpha_shift)
            self.ratio += round_shift(error, power+beta_shift)
        else:
            # 18 fast observations bound clean acquisition from the specified
            # oscillator envelope; this is NOT a validity/lock criterion.
            gain_shift = 0 if self.kind == 'residual_acquire' and self.updates < 18 else 2
            self.ratio += round_shift(error, power+gain_shift)
        self.updates += 1
        return self.ratio


def captures(frequency, scenario, ppm, seconds=DURATION_S):
    rng = random.Random(15882019)
    step_ns = EVENT_S*NS
    epoch_ns = (1 << 42)*NS
    for index in range(seconds*8+1):
        emit_ns = index*(NS//8)
        if scenario == 'packet_gap' and step_ns <= emit_ns < step_ns+6*NS:
            continue
        delay_ns = 50000
        if scenario == 'jitter':
            delay_ns += round(rng.gauss(0, 100))
        elif scenario == 'delay_step' and emit_ns >= step_ns:
            delay_ns += 10000
        elif scenario == 'delay_ramp':
            delay_ns += nearest(Fraction(50*emit_ns, NS))
        arrival_ns = emit_ns+delay_ns
        initial_scale = 1+Fraction(ppm, 1000000)
        final_ppm = -50 if scenario in ('frequency_step', 'packet_gap') else ppm
        final_scale = 1+Fraction(final_ppm, 1000000)
        raw_cycles = Fraction(frequency, NS)*(
            min(arrival_ns, step_ns)*initial_scale+max(0, arrival_ns-step_ns)*final_scale)
        scale = initial_scale if arrival_ns < step_ns else final_scale
        truth = Fraction(NS, frequency)/scale
        yield emit_ns/NS, (epoch_ns+emit_ns)*Q16, nearest(raw_cycles*8), truth


def run_case(frequency, scenario, ppm):
    direct = RateEstimator(frequency, frequency//2, 4*frequency)
    feedback = {kind: Feedback(frequency, kind) for kind in
                ('residual_slow', 'residual_acquire', 'phase_slow', 'phase_fast')}
    lower = math.ceil(direct.nominal*Q48*(1-Fraction(direct.maximum_ppb, NS)))
    upper = math.floor(direct.nominal*Q48*(1+Fraction(direct.maximum_ppb, NS)))
    traces = {name: [] for name in ('direct', *feedback)}
    for time_s, remote, raw, truth in captures(frequency, scenario, ppm):
        old_anchor = direct.anchor
        accepted = direct.observe(remote, raw, raw//8)
        if old_anchor is not None and raw-old_anchor[1] >= frequency//2*8 and remote > old_anchor[0]:
            # The same rounded-quotient admission window can be checked by
            # cross products without actually forming that quotient.
            assert accepted == ratio_in_range((remote-old_anchor[0]) << 35,
                                              raw-old_anchor[1], lower, upper)
        if not accepted:
            continue
        delta = remote-old_anchor[0]
        span = raw-old_anchor[1]
        ratios = {'direct': direct.ratio}
        ratios.update({name: candidate.update(delta, span) for name, candidate in feedback.items()})
        for name, ratio in ratios.items():
            error_ppb = float((Fraction(ratio, Q48)/truth-1)*NS)
            traces[name].append((time_s, error_ppb))
    return traces


def settling_time(trace, event_s, threshold_ppb):
    """First post-event observation after which every remaining error is small."""
    relevant = [(t, e) for t, e in trace if t >= event_s]
    failures = [i for i, (_, error) in enumerate(relevant) if abs(error) > threshold_ppb]
    index = failures[-1]+1 if failures else 0
    return None if index == len(relevant) else round(relevant[index][0]-event_s, 3)


def summarize(frequency, scenario, ppm, name, trace):
    tail = [error for time_s, error in trace if time_s >= TAIL_S]
    average = sum(tail)/len(tail)
    event_s = 0 if scenario == 'clean' else EVENT_S
    event_errors = [abs(error) for time_s, error in trace if time_s >= event_s]
    return dict(frequency=frequency, scenario=scenario, ppm=ppm, estimator=name,
                tail_mean_ppb=round(average, 4),
                tail_sigma_ppb=round(math.sqrt(sum((e-average)**2 for e in tail)/len(tail)), 4),
                peak_after_event_ppb=round(max(event_errors), 4),
                settle_10ppb_s=settling_time(trace, event_s, 10),
                observations=len(trace))


def ratio_in_range(numerator, denominator, lower, upper):
    """Equivalent to lower <= round(numerator/denominator) <= upper, positive inputs."""
    return (2*lower-1)*denominator <= 2*numerator < (2*upper+1)*denominator


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--csv', type=Path, help='Optional output file for numerical traces')
    args = parser.parse_args()
    # Independent Fraction rounding verifies negative half ties and all shift
    # counts used by the study. These are analysis checks, not RTL verification.
    for shift in range(68):
        half = (1 << shift)//2
        magnitudes = {0, 1, 2, max(0, half-1), half, half+1, (1 << shift)+1, (1 << 127)-1}
        for value in magnitudes | {-value for value in magnitudes}:
            assert round_shift(value, shift) == nearest(Fraction(value, 1 << shift))
    for denominator in (1, 2, 7, 500000000, 625000000, (1 << 65)-1):
        power = (denominator-1).bit_length()
        assert denominator <= 1 << power < 2*denominator
        lower, upper = (1 << 51)-10000000, (1 << 51)+10000000
        for endpoint in ((2*lower-1)*denominator//2, (2*upper+1)*denominator//2):
            for numerator in range(endpoint-2, endpoint+3):
                expected = lower <= nearest(Fraction(numerator, denominator)) <= upper
                assert ratio_in_range(numerator, denominator, lower, upper) == expected
    summaries, rows = [], []
    for frequency in (125000000, 156250000):
        for scenario in ('clean', 'jitter', 'delay_step', 'delay_ramp', 'frequency_step', 'packet_gap'):
            for ppm in ((-100, 100) if scenario == 'clean' else (100,)):
                for name, trace in run_case(frequency, scenario, ppm).items():
                    result = summarize(frequency, scenario, ppm, name, trace)
                    if scenario == 'clean':
                        assert result['settle_10ppb_s'] is not None, result
                        assert abs(trace[-1][1]) < 0.1, result
                    if scenario == 'delay_ramp':
                        assert abs(result['tail_mean_ppb']+50) < 0.1, result
                    summaries.append(result)
                    rows.extend((frequency, scenario, ppm, name, t, e) for t, e in trace)
    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        with args.csv.open('w', newline='') as output:
            writer = csv.writer(output)
            writer.writerow(('frequency_hz', 'scenario', 'oscillator_ppm', 'estimator',
                             'master_time_s', 'rate_error_ppb'))
            writer.writerows(rows)
    print(json.dumps(summaries, indent=2))


if __name__ == '__main__':
    main()
