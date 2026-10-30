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
# - Sweep: the pure numeric helpers of the eye scan: zero-error bound, Poisson
#   upper bound, bit counts, prescale selection, sdata masks, UT combination,
#   inverse Q, the Q-scale tail fit, the open region and the extrapolated
#   opening.
# - Stimulus: closed-form reference values (UG576 width rows and mask words,
#   pinned inverse-Q values) and a seeded synthetic dual-Dirac bathtub with
#   Poisson counting noise (sigma 0.035 UI, edges at +-0.30 UI, 8.58e9 bits
#   per point), so no hardware, wall clock or unseeded randomness is involved.
# - Checks: a zero-error point is never reported as BER 0 (NaN plus a bound);
#   every measured point carries the exact one-sided Poisson bound (reference
#   limits, monotonic in errors and bits) and the open region uses it;
#   bit counts stay exact Python ints above 2**53; invalid arguments raise
#   ValueError; the fit recovers sigma, the edge and the 1e-12 crossing, and
#   reports ok False with a reason (and no edge) when any quality gate fails.
# - Timing: Pure arithmetic, milliseconds.

import math
import time

import pytest

pytest.importorskip('pyrogue', reason='Importing surf.xilinx requires Rogue/PyRogue')

import numpy as np  # noqa: E402

from surf.xilinx.eyescan._EyeScanFamilies import GTHE3  # noqa: E402
from surf.xilinx.eyescan._EyeScanMath import (  # noqa: E402
    bitsNeeded,
    bitsPerRun,
    combineCounts,
    edgeAt,
    extrapolatedOpening,
    fitTail,
    internalWidth,
    maskWords,
    openRegion,
    poissonUpperBound,
    prescaleForFloor,
    qfunc,
    qinv,
    sdataMask,
    zeroErrorBound,
)


def test_zero_error_bound_is_ln20_over_bits():
    assert zeroErrorBound(1e9) == pytest.approx(math.log(20) / 1e9)
    assert zeroErrorBound(1e9, 0.95) == pytest.approx(2.9957322735539909 / 1e9)
    assert zeroErrorBound(1e9, 0.99) == pytest.approx(-math.log(0.01) / 1e9)


def test_zero_error_bound_accepts_arrays_and_sums_accumulations():
    bits = np.array([1e9, 2e9, 4e9])
    out = zeroErrorBound(bits)
    assert isinstance(out, np.ndarray)
    assert out == pytest.approx(math.log(20) / bits)
    # Two accumulations are bounded over their summed bit count
    assert zeroErrorBound(1e9 + 1e9) == pytest.approx(math.log(20) / 2e9)


@pytest.mark.parametrize('confidence', [0.0, 1.0, -0.1, 1.5])
def test_zero_error_bound_rejects_bad_confidence(confidence):
    with pytest.raises(ValueError):
        zeroErrorBound(1e9, confidence)


@pytest.mark.parametrize('bits', [0, -1, -1e9])
def test_zero_error_bound_rejects_non_positive_bits(bits):
    with pytest.raises(ValueError):
        zeroErrorBound(bits)
    with pytest.raises(ValueError):
        zeroErrorBound(np.array([1e9, bits]))


def test_bits_needed_and_prescale_selector():
    assert bitsNeeded(1e-9, 0.95) == pytest.approx(2.9957e9, rel=1e-4)
    assert prescaleForFloor(1e-9, 32, 0.95) == 10
    assert prescaleForFloor(1e-3, 32) == 0
    assert prescaleForFloor(1e-9, 32, maxPrescale=4) == 4
    assert prescaleForFloor(1e-30, 32) == 31


def test_bits_per_run_is_exact_integer_arithmetic():
    assert bitsPerRun(65535, 10, 32) == 4294901760
    big = bitsPerRun(65535, 31, 32)
    assert isinstance(big, int)
    assert big == 65535 * 2**32 * 32
    wide = bitsPerRun(65535, 31, 40)
    assert wide == 65535 * 2**32 * 40
    assert wide > 2**53
    assert isinstance(wide, int)
    assert bitsPerRun(1, 0, 20) == 40


@pytest.mark.parametrize('prescale', [-1, 32])
def test_bits_per_run_rejects_prescale_out_of_range(prescale):
    with pytest.raises(ValueError):
        bitsPerRun(65535, prescale, 32)


@pytest.mark.parametrize('width, words', [
    (32, [0x00FF, 0x0000, 0xFF00, 0xFFFF, 0xFFFF]),
    (16, [0xFFFF, 0x00FF, 0xFF00, 0xFFFF, 0xFFFF]),
    (20, [0xFFFF, 0x000F, 0xFF00, 0xFFFF, 0xFFFF]),
    (40, [0x0000, 0x0000, 0xFF00, 0xFFFF, 0xFFFF]),
])
def test_mask_words_for_each_internal_width(width, words):
    assert maskWords(sdataMask(width, 40)) == words


def test_sdata_mask_closed_form():
    assert sdataMask(40, 40) == ((1 << 80) - 1) ^ (((1 << 40) - 1))
    # Width 16 in a 40 bit slot: 40 ones, 16 zeros, 24 ones (from the MSB down)
    assert sdataMask(16, 40) == (((1 << 40) - 1) << 40) | (((1 << 24) - 1))
    # A sampled window of `width` bits is zero (unmasked) inside a 40 bit slot
    mask = sdataMask(32, 40)
    assert (mask >> 8) & ((1 << 32) - 1) == 0
    assert mask & 0xFF == 0xFF
    assert maskWords(0, 2) == [0, 0]


@pytest.mark.parametrize('width', [0, -4, 41, 80])
def test_sdata_mask_rejects_bad_width(width):
    with pytest.raises(ValueError):
        sdataMask(width, 40)


@pytest.mark.parametrize('rxDataWidth, intRaw, expected', [
    (16, 0, 16), (20, 0, 20), (32, 0, 16), (32, 1, 32),
    (40, 0, 20), (40, 1, 40), (64, 1, 32), (64, 2, 64),
    (80, 1, 40), (80, 2, 80), (128, 2, 64), (160, 2, 80),
])
def test_internal_width_reproduces_every_ug_row(rxDataWidth, intRaw, expected):
    assert internalWidth(rxDataWidth, intRaw) == expected


def test_gthe3_width_whitelist_is_exact():
    assert GTHE3.widthCombos == {
        (16, 0), (20, 0), (32, 0), (32, 1), (40, 0), (40, 1), (64, 1), (80, 1),
    }
    assert GTHE3.busWidth == 40


def test_combine_counts_never_reports_ber_zero():
    errors = np.array([[0, 5], [0, 3]])
    bits = np.array([[1e9, 1e9], [1e9, 1e9]])
    ber, berUpper, isBound = combineCounts(errors, bits)
    assert np.isnan(ber[0])
    assert ber[1] == pytest.approx(8 / 2e9)
    assert berUpper[0] == pytest.approx(math.log(20) / 2e9)
    assert berUpper[1] == pytest.approx(14.43465 / 2e9, rel=1e-6)
    assert isBound.tolist() == [True, False]
    assert not np.any(ber == 0.0)


def test_combine_counts_sums_both_ut_accumulations():
    errors = np.array([[1, 0], [3, 0]])
    bits = np.array([[1e9, 2e9], [3e9, 2e9]])
    ber, berUpper, isBound = combineCounts(errors, bits)
    assert ber[0] == pytest.approx((1 + 3) / (1e9 + 3e9))
    assert np.isnan(ber[1])
    assert berUpper[1] == pytest.approx(math.log(20) / 4e9)
    assert berUpper[0] == pytest.approx(9.153519 / 4e9, rel=1e-6)
    assert berUpper[0] > ber[0]


def test_combine_counts_one_dimensional_input_is_one_accumulation():
    ber, berUpper, isBound = combineCounts(np.array([0, 4]), np.array([1e9, 1e9]))
    assert np.isnan(ber[0])
    assert ber[1] == pytest.approx(4e-9)
    assert berUpper[0] == pytest.approx(math.log(20) / 1e9)
    assert berUpper[1] == pytest.approx(9.153519e-9, rel=1e-6)
    assert isBound.tolist() == [True, False]


def test_poisson_upper_bound_reduces_to_the_zero_error_bound():
    assert poissonUpperBound(0, 2e9) == zeroErrorBound(2e9)
    assert poissonUpperBound(0, 1e9, 0.99) == zeroErrorBound(1e9, 0.99)
    assert poissonUpperBound(1, 2e9) == pytest.approx(2.371932e-9, rel=1e-6)
    assert poissonUpperBound(3, 3.5e9) == pytest.approx(2.215330e-9, rel=1e-6)


# Exact one-sided Poisson limits lambda(e, c): P(X <= e; lambda) = 1 - c
POISSON_LIMITS = [
    (1, 0.95, 4.743865), (2, 0.95, 6.295794), (3, 0.95, 7.753657),
    (8, 0.95, 14.43465), (10, 0.95, 16.962219), (100, 0.95, 118.079273),
    (0, 0.99, 4.605170), (1, 0.99, 6.638352), (3, 0.99, 10.045118),
]


@pytest.mark.parametrize('errors, confidence, limit', POISSON_LIMITS)
def test_poisson_upper_bound_matches_the_reference_limits(errors, confidence, limit):
    assert poissonUpperBound(errors, 1e9, confidence) * 1e9 == pytest.approx(limit, rel=1e-6)


@pytest.mark.parametrize('bits', [1e8, 2e9, 3e9, 8.6e9])
def test_poisson_upper_bound_is_monotonic_in_errors_and_bits(bits):
    errors = np.arange(201)
    bound = poissonUpperBound(errors, np.full(errors.shape, bits))
    assert np.all(np.diff(bound) > 0)
    assert poissonUpperBound(7, bits) > poissonUpperBound(7, bits * 2)


@pytest.mark.parametrize('floor', [1e-9, 1e-6])
@pytest.mark.parametrize('bits', [1e8, 2e9, 3e9, 8.6e9])
def test_poisson_upper_bound_never_opens_a_point_for_more_errors(bits, floor):
    isOpen = [openRegion(np.array([0]), np.array([e]), np.array([bits]), floor) is not None
              for e in range(201)]
    assert all(later <= earlier for earlier, later in zip(isOpen, isOpen[1:]))


@pytest.mark.parametrize('errors', [0, 1, 3, 10])
def test_poisson_upper_bound_grows_with_confidence(errors):
    low = poissonUpperBound(errors, 1e9, 0.6827)
    mid = poissonUpperBound(errors, 1e9, 0.95)
    high = poissonUpperBound(errors, 1e9, 0.99)
    assert high > mid > low


def test_poisson_upper_bound_sits_exactly_on_the_floor_boundary():
    bits = 7.753657 / (1e-9 * 0.999)
    counts = np.array([0])
    assert openRegion(counts, np.array([3]), np.array([bits]), 1e-9) == (0, 0)
    assert openRegion(counts, np.array([4]), np.array([bits]), 1e-9) is None


def test_poisson_upper_bound_sums_accumulations_and_flags_unmeasured_points():
    errors = np.array([[1, 0, 2], [2, 0, 0]])
    bits = np.array([[1e9, 0.0, 1e9], [2e9, 0.0, 1e9]])
    out = poissonUpperBound(errors, bits)
    assert out.shape == (3,)
    assert out[0] == pytest.approx(poissonUpperBound(3, 3e9))
    assert np.isnan(out[1])
    assert out[2] == pytest.approx(poissonUpperBound(2, 2e9))
    assert isinstance(poissonUpperBound(2, 1e9), float)
    assert np.isnan(poissonUpperBound(5, 0))


@pytest.mark.parametrize('confidence', [0.0, 1.0, -0.1, 1.5, float('nan')])
def test_poisson_upper_bound_rejects_bad_confidence(confidence):
    with pytest.raises(ValueError):
        poissonUpperBound(1, 1e9, confidence)
    with pytest.raises(ValueError):
        openRegion(np.array([0]), np.array([1]), np.array([1e9]), 1e-9, confidence)


def test_poisson_upper_bound_rejects_bad_counts():
    with pytest.raises(ValueError):
        poissonUpperBound(-1, 1e9)
    with pytest.raises(ValueError):
        poissonUpperBound(1, -1e9)
    with pytest.raises(ValueError):
        poissonUpperBound(np.array([1, 2]), np.array([1e9, 1e9, 1e9]))


def test_poisson_upper_bound_is_exact_for_saturated_counts():
    # Both UT accumulations saturated at prescale 10 with a 32 bit window
    errors, bits = 131070, 8589803520
    bound = poissonUpperBound(errors, bits)
    assert math.isfinite(bound)
    assert bound > errors / bits
    start = time.monotonic()
    out = poissonUpperBound(np.full((2, 129), 65535), np.full((2, 129), 4294901760))
    assert time.monotonic() - start < 1.0
    assert np.all(np.isfinite(out))
    assert out[0] == pytest.approx(bound)


# ---------------------------------------------------------------------------
# Inverse Q
# ---------------------------------------------------------------------------

PINNED_QINV = [
    (1e-3, 3.09023), (1e-6, 4.75342), (1e-9, 5.99781),
    (1e-12, 7.03448), (1e-15, 7.94135), (1e-18, 8.75729),
]


@pytest.mark.parametrize('p, expected', PINNED_QINV)
def test_qinv_pinned_values(p, expected):
    assert round(float(qinv(p)), 5) == expected


def test_qinv_vector_input_returns_array():
    out = qinv(np.array([1e-3, 1e-6]))
    assert isinstance(out, np.ndarray)
    assert out.shape == (2,)
    assert round(float(out[1]), 5) == 4.75342
    assert qinv(0.5) == pytest.approx(0.0, abs=1e-9)


@pytest.mark.parametrize('p', [0.0, 1.0, -1.0, 2.0, float('nan')])
def test_qinv_rejects_values_outside_open_interval(p):
    with pytest.raises(ValueError):
        qinv(p)
    with pytest.raises(ValueError):
        qinv(np.array([1e-3, p]))


def test_qfunc_round_trips_qinv_over_eighteen_decades():
    p = np.logspace(-18, -3, 61)
    assert np.abs(qfunc(qinv(p)) / p - 1.0).max() < 1e-6


def test_qfunc_known_values():
    assert qfunc(0.0) == pytest.approx(0.5)
    assert qfunc(np.array([0.0, 1.0]))[1] == pytest.approx(0.15865525393145707)


def test_qinv_is_continuous_across_the_branch_point():
    below = float(qinv(0.02425 * (1 - 1e-9)))
    above = float(qinv(0.02425 * (1 + 1e-9)))
    assert abs(below - above) / abs(below) < 1e-6
    below = float(qinv(1 - 0.02425 * (1 + 1e-9)))
    above = float(qinv(1 - 0.02425 * (1 - 1e-9)))
    assert abs(below - above) / max(abs(below), 1e-12) < 1e-4


# ---------------------------------------------------------------------------
# Q-scale tail fit
# ---------------------------------------------------------------------------

SIGMA = 0.035
EDGE = 0.30
BITS = 8.58e9


def bathtubBer(x):
    return 0.5 * (qfunc((EDGE - x) / SIGMA) + qfunc((x + EDGE) / SIGMA))


@pytest.fixture(scope='module')
def bathtub():
    x = np.arange(-64, 65) / 128.0
    bits = np.full(x.shape, BITS)
    errors = np.random.default_rng(1234).poisson(bathtubBer(x) * bits)
    return x, errors, bits


def tailFromQ(q, bits=BITS, side='right'):
    """Noise free tail points at Q-scale positions q (BER = 0.5 * Q(q))."""
    q = np.asarray(q, dtype=float)
    ber = 0.5 * qfunc(q)
    x = EDGE - SIGMA * q if side == 'right' else SIGMA * q - EDGE
    errors = np.round(ber * bits).astype(np.int64)
    return x, errors, np.full(q.shape, bits)


def test_fit_tail_recovers_right_tail(bathtub):
    x, errors, bits = bathtub
    sel = x > 0
    fit = fitTail(x[sel], errors[sel], bits[sel], 'right')
    assert fit.ok, fit.reason
    assert fit.side == 'right'
    assert fit.sigma == pytest.approx(SIGMA, rel=0.02)
    assert fit.mu == pytest.approx(EDGE, abs=0.002)
    assert fit.slope < 0
    assert fit.r2 >= 0.95
    assert fit.nPoints >= 5
    assert fit.decades >= 1.5
    expected = EDGE - SIGMA * float(qinv(2e-12))
    assert edgeAt(fit, 1e-12) == pytest.approx(expected, abs=0.002)


def test_fit_tail_recovers_left_tail_symmetrically(bathtub):
    x, errors, bits = bathtub
    sel = x < 0
    fit = fitTail(x[sel], errors[sel], bits[sel], 'left')
    assert fit.ok, fit.reason
    assert fit.sigma == pytest.approx(SIGMA, rel=0.02)
    assert fit.mu == pytest.approx(-EDGE, abs=0.002)
    assert fit.slope > 0
    expected = -EDGE + SIGMA * float(qinv(2e-12))
    assert edgeAt(fit, 1e-12) == pytest.approx(expected, abs=0.002)


def test_fit_tail_sums_two_accumulations(bathtub):
    x, errors, bits = bathtub
    sel = x > 0
    half = np.stack([errors[sel] // 2, errors[sel] - errors[sel] // 2])
    halfBits = np.stack([bits[sel] / 2, bits[sel] / 2])
    fit = fitTail(x[sel], half, halfBits, 'right')
    plain = fitTail(x[sel], errors[sel], bits[sel], 'right')
    assert fit.ok
    assert fit.sigma == pytest.approx(plain.sigma)


def test_fit_tail_clean_synthetic_is_exact():
    x, errors, bits = tailFromQ(np.linspace(5.5, 3.2, 12))
    fit = fitTail(x, errors, bits, 'right')
    assert fit.ok, fit.reason
    assert fit.reason == ''
    assert fit.sigma == pytest.approx(SIGMA, rel=1e-3)
    assert fit.mu == pytest.approx(EDGE, abs=1e-3)


def test_gate_too_few_points():
    x, errors, bits = tailFromQ([5.6, 4.7, 3.7, 3.1])
    fit = fitTail(x, errors, bits, 'right')
    assert not fit.ok
    assert 'points' in fit.reason
    assert fit.nPoints == 4
    assert edgeAt(fit, 1e-12) is None


def test_gate_too_few_decades():
    x, errors, bits = tailFromQ(np.linspace(2.9, 3.5, 6))
    fit = fitTail(x, errors, bits, 'right')
    assert not fit.ok
    assert 'decades' in fit.reason
    assert 'points' not in fit.reason
    assert fit.decades < 1.5
    assert edgeAt(fit, 1e-12) is None


def test_gate_wrong_slope_sign():
    x, errors, bits = tailFromQ(np.linspace(5.5, 3.2, 12), side='left')
    fit = fitTail(x, errors, bits, 'right')
    assert not fit.ok
    assert 'slope' in fit.reason
    assert edgeAt(fit, 1e-12) is None
    # the same points are a good left tail
    assert fitTail(x, errors, bits, 'left').ok


def test_gate_low_r2():
    q = np.linspace(5.5, 3.2, 12)
    x, errors, bits = tailFromQ(q)
    # Alternate each count a decade up or down so the Q-scale line is lost
    factor = np.where(np.arange(q.size) % 2 == 0, 10.0, 0.1)
    errors = np.round(errors * factor).astype(np.int64)
    fit = fitTail(x, errors, bits, 'right')
    assert not fit.ok
    assert 'r2' in fit.reason
    assert fit.r2 < 0.95
    assert edgeAt(fit, 1e-12) is None


def test_fit_tail_ignores_points_outside_the_usable_window():
    x, errors, bits = tailFromQ(np.linspace(5.5, 3.2, 12))
    # An error-poor point and a saturated point must not be selected
    x = np.append(x, [0.0, 0.5])
    errors = np.append(errors, [3, 5000000000])
    bits = np.append(bits, [BITS, BITS])
    fit = fitTail(x, errors, bits, 'right')
    assert fit.ok, fit.reason
    assert fit.nPoints == 12


def test_fit_tail_with_fewer_than_two_points_has_no_numbers():
    fit = fitTail(np.array([0.1]), np.array([0]), np.array([BITS]), 'right')
    assert not fit.ok
    assert fit.nPoints == 0
    for name in ('sigma', 'mu', 'slope', 'intercept', 'r2'):
        assert getattr(fit, name) is None
    assert 'points' in fit.reason
    assert edgeAt(fit, 1e-12) is None


def test_fit_tail_rejects_bad_arguments():
    x, errors, bits = tailFromQ(np.linspace(5.5, 3.2, 12))
    with pytest.raises(ValueError):
        fitTail(x, errors, bits, 'middle')
    with pytest.raises(ValueError):
        fitTail(x, errors[:-1], bits, 'right')
    with pytest.raises(ValueError):
        fitTail(x, errors, bits, 'right', rho=0.0)


def test_edge_at_rejects_ber_outside_the_fit_domain():
    x, errors, bits = tailFromQ(np.linspace(5.5, 3.2, 12))
    fit = fitTail(x, errors, bits, 'right')
    with pytest.raises(ValueError):
        edgeAt(fit, 0.6)


# ---------------------------------------------------------------------------
# Open region and extrapolated opening
# ---------------------------------------------------------------------------

def test_open_region_longest_contiguous_run():
    counts = np.arange(-4, 5)
    bits = np.full(counts.shape, 4e9)
    errors = np.array([500, 80, 0, 0, 0, 0, 0, 200, 900])
    assert openRegion(counts, errors, bits, 1e-9) == (2, 6)


def test_open_region_needs_the_upper_bound_below_the_floor():
    counts = np.arange(5)
    errors = np.array([100, 1, 0, 1, 100])
    # 1 error in 5e9 bits has a 95 percent bound of 9.49e-10 and meets the
    # floor, as does the error-free point (7.49e-10)
    bits = np.array([1e9, 5e9, 4e9, 5e9, 1e9])
    assert openRegion(counts, errors, bits, 1e-9) == (1, 3)
    # 1 error in 1e9 bits has a bound of 4.74e-9: only the error-free point is open
    bits = np.array([1e9, 1e9, 4e9, 1e9, 1e9])
    assert openRegion(counts, errors, bits, 1e-9) == (2, 2)


@pytest.mark.parametrize('errors, bits, expected', [
    (0, 2.0e9, None),
    (1, 2.0e9, None),
    (3, 3.5e9, None),
    (1, 5.0e9, (0, 0)),
    (0, 3.0e9, (0, 0)),
])
def test_open_region_applies_the_bound_to_points_with_errors(errors, bits, expected):
    # Bounds at 95 percent: 1.498e-9, 2.372e-9, 2.215e-9, 9.49e-10 and 9.99e-10
    got = openRegion(np.array([0]), np.array([errors]), np.array([bits]), 1e-9)
    assert got == expected


def test_open_region_requires_the_bound_to_meet_the_floor():
    counts = np.arange(3)
    bits = np.array([1e9, 4e9, 1e9])
    errors = np.zeros(3, dtype=int)
    # ln(20) / 1e9 = 3.0e-9 misses a 1e-9 floor; ln(20) / 4e9 = 7.5e-10 meets it
    assert openRegion(counts, errors, bits, 1e-9) == (1, 1)


def test_open_region_closed_eye_is_none():
    counts = np.arange(-2, 3)
    assert openRegion(counts, np.array([9, 9, 9, 9, 9]), np.full(5, 1e9), 1e-9) is None
    assert openRegion(counts, np.zeros(5, dtype=int), np.full(5, 1e8), 1e-9) is None


def test_open_region_sums_both_accumulations():
    counts = np.arange(3)
    errors = np.array([[0, 0, 5], [0, 0, 5]])
    bits = np.full((2, 3), 2e9)
    assert openRegion(counts, errors, bits, 1e-9) == (0, 1)


def test_open_region_tie_goes_to_the_run_containing_count_zero():
    counts = np.arange(-4, 5)
    bits = np.full(counts.shape, 4e9)
    errors = np.array([0, 0, 9, 9, 0, 0, 9, 9, 9])
    assert openRegion(counts, errors, bits, 1e-9) == (4, 5)


def test_open_region_tie_goes_to_the_run_nearest_count_zero():
    counts = np.arange(-6, 7)
    bits = np.full(counts.shape, 4e9)
    errors = np.full(counts.shape, 9)
    errors[0:2] = 0      # counts -6, -5
    errors[8:10] = 0     # counts 2, 3
    assert openRegion(counts, errors, bits, 1e-9) == (8, 9)


def test_open_region_unmeasured_points_are_closed():
    counts = np.arange(3)
    assert openRegion(counts, np.zeros(3, dtype=int), np.zeros(3), 1e-9) is None


def test_open_region_rejects_unsorted_counts():
    with pytest.raises(ValueError):
        openRegion(np.array([0, 2, 1]), np.zeros(3, dtype=int), np.full(3, 4e9), 1e-9)


def test_extrapolated_opening_is_right_edge_minus_left_edge(bathtub):
    x, errors, bits = bathtub
    left = fitTail(x[x < 0], errors[x < 0], bits[x < 0], 'left')
    right = fitTail(x[x > 0], errors[x > 0], bits[x > 0], 'right')
    opening = extrapolatedOpening(left, right, 1e-12)
    assert opening == pytest.approx(edgeAt(right, 1e-12) - edgeAt(left, 1e-12))
    truth = 2 * (EDGE - SIGMA * float(qinv(2e-12)))
    assert opening == pytest.approx(truth, abs=0.004)


def test_extrapolated_opening_is_none_unless_both_fits_are_ok(bathtub):
    x, errors, bits = bathtub
    right = fitTail(x[x > 0], errors[x > 0], bits[x > 0], 'right')
    bad = fitTail(x[:3], errors[:3], bits[:3], 'left')
    assert not bad.ok
    assert extrapolatedOpening(bad, right, 1e-12) is None
    assert extrapolatedOpening(right, bad, 1e-12) is None
