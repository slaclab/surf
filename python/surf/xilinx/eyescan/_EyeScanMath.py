#-----------------------------------------------------------------------------
# Title      : Eye-scan math
#-----------------------------------------------------------------------------
# Description:
# Pure numeric helpers for the statistical eye scan (numpy and math only).
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

from __future__ import annotations

import math
from dataclasses import dataclass
from functools import lru_cache

import numpy as np
import numpy.typing as npt

__all__ = [
    'internalWidth',
    'zeroErrorBound',
    'poissonUpperBound',
    'bitsNeeded',
    'bitsPerRun',
    'prescaleForFloor',
    'sdataMask',
    'maskWords',
    'combineCounts',
    'qfunc',
    'qinv',
    'TailFit',
    'fitTail',
    'edgeAt',
    'openRegion',
    'extrapolatedOpening',
    'openComponent',
    'areaAsymmetry',
    'nearestTowardZero',
]

# Each sample counts 2**(1 + prescale) windows of `width` bits
_MAX_PRESCALE = 31

# The sample counter is 16 bits wide
_MAX_SAMPLE_COUNT = 65535

# Relative tolerance of the incomplete gamma series and continued fraction
_GAMMA_EPS = 1e-14

# Smallest magnitude kept by the modified Lentz recurrence
_GAMMA_TINY = 1e-300

# Relative step at which the Poisson limit solver stops
_LIMIT_TOL = 1e-12

# Newton iterations before the Poisson limit solver gives up
_LIMIT_MAX_ITER = 200


def internalWidth(dataWidthBits: int, intDataWidthRaw: int) -> int:
    """Return the internal (sampled) data width in bits.

    Parameters
    ----------
    dataWidthBits : int
        Decoded RX_DATA_WIDTH in bits (16, 20, 32, 40, 64, 80, 128 or 160).
    intDataWidthRaw : int
        Raw RX_INT_DATAWIDTH register value.

    Returns
    -------
    int
        ``(20 if dataWidthBits % 20 == 0 else 16) << intDataWidthRaw``.
    """
    return (20 if dataWidthBits % 20 == 0 else 16) << intDataWidthRaw


def _checkConfidence(confidence: float) -> float:
    """Return ``-ln(1 - confidence)`` after validating the open interval (0, 1)."""
    if not 0.0 < confidence < 1.0:
        raise ValueError(f'confidence must be in the open interval (0, 1), got {confidence}')
    return -math.log1p(-confidence)


def _sumAccumulations(errors, bits) -> tuple[np.ndarray, np.ndarray]:
    """Validate counts and sum the UT accumulations of a ``(2, N)`` input.

    Returns int64 errors and float64 bits, both of shape ``(N,)``.
    """
    err = np.asarray(errors)
    nBits = np.asarray(bits)
    if err.shape != nBits.shape:
        raise ValueError(f'errors shape {err.shape} does not match bits shape {nBits.shape}')
    if err.ndim not in (1, 2):
        raise ValueError(f'errors must be 1-D or 2-D, got {err.ndim}-D')
    if err.ndim == 2:
        err = err.sum(axis=0)
        nBits = nBits.sum(axis=0)
    err = err.astype(np.int64)
    nBits = nBits.astype(float)
    if np.any(err < 0) or np.any(nBits < 0):
        raise ValueError('errors and bits must not be negative')
    return err, nBits


def zeroErrorBound(bits: npt.ArrayLike, confidence: float = 0.95) -> float | np.ndarray:
    """Return the upper BER bound for a measurement that saw zero errors.

    For N error-free bits the true BER is below ``-ln(1 - confidence) / N``
    with the stated confidence (about ``2.9957 / N`` at 95 percent). Two
    accumulations are bounded together by passing their summed bit count.

    Parameters
    ----------
    bits : int, float or array_like
        Number of bits observed, strictly positive.
    confidence : float
        One-sided confidence level, strictly between 0 and 1.

    Returns
    -------
    float or numpy.ndarray
        The bound, a float for scalar input and an array otherwise.

    Raises
    ------
    ValueError
        If ``confidence`` is outside (0, 1) or any ``bits`` value is not positive.
    """
    scale = _checkConfidence(confidence)
    arr = np.asarray(bits, dtype=float)
    if not np.all(arr > 0):
        raise ValueError('bits must be strictly positive')
    out = scale / arr
    return float(out) if out.ndim == 0 else out


def _gammaQ(a: float, x: float) -> float:
    """Return the regularized upper incomplete gamma function ``Q(a, x)``.

    ``Q(e + 1, lam)`` is the Poisson probability ``P(X <= e; lam)``. Uses the
    power series of ``P(a, x)`` for ``x < a + 1`` and the modified Lentz
    continued fraction of ``Q(a, x)`` otherwise; the prefactor is carried in
    log space so large ``a`` does not overflow.
    """
    if x <= 0.0:
        return 1.0
    logPre = -x + a * math.log(x) - math.lgamma(a)
    maxIter = 10000 + 100 * int(math.sqrt(a))
    if x < a + 1.0:
        term = 1.0 / a
        total = term
        ap = a
        for _ in range(maxIter):
            ap += 1.0
            term *= x / ap
            total += term
            if abs(term) < abs(total) * _GAMMA_EPS:
                return 1.0 - total * math.exp(logPre)
        raise RuntimeError(f'incomplete gamma series did not converge for a={a}, x={x}')
    b = x + 1.0 - a
    c = 1.0 / _GAMMA_TINY
    d = 1.0 / b if abs(b) > _GAMMA_TINY else 1.0 / _GAMMA_TINY
    h = d
    for i in range(1, maxIter):
        an = -i * (i - a)
        b += 2.0
        d = an * d + b
        if abs(d) < _GAMMA_TINY:
            d = _GAMMA_TINY
        c = b + an / c
        if abs(c) < _GAMMA_TINY:
            c = _GAMMA_TINY
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < _GAMMA_EPS:
            return math.exp(logPre) * h
    raise RuntimeError(f'incomplete gamma continued fraction did not converge for a={a}, x={x}')


@lru_cache(maxsize=4096)
def _poissonLimit(errors: int, confidence: float) -> float:
    """Return ``lam`` solving ``P(X <= errors; lam) = 1 - confidence``.

    This is the one-sided upper confidence limit of a Poisson mean that
    produced ``errors`` events. A safeguarded Newton iteration (the derivative
    of the cumulative probability with respect to ``lam`` is minus the Poisson
    pmf) keeps a bisection bracket and falls back to its midpoint whenever a
    step leaves it. The Wilson-Hilferty chi-square quantile only seeds the
    iteration; the returned value is the converged root. Cached so repeated
    counts, such as saturated points, are solved once.
    """
    scale = _checkConfidence(confidence)
    if errors == 0:
        return scale
    a = errors + 1
    target = 1.0 - confidence
    lo = 0.0
    hi = float(max(2, 2 * a))
    for _ in range(64):
        if _gammaQ(a, hi) <= target:
            break
        lo = hi
        hi *= 2.0
    else:
        raise RuntimeError(f'no Poisson limit bracket for errors={errors}, confidence={confidence}')

    k = 2.0 * a
    seed = 0.5 * k * (1.0 - 2.0 / (9.0 * k) + float(qinv(1.0 - confidence)) * math.sqrt(2.0 / (9.0 * k))) ** 3
    x = seed if lo < seed < hi else 0.5 * (lo + hi)
    for _ in range(_LIMIT_MAX_ITER):
        f = _gammaQ(a, x) - target
        if f == 0.0:
            return x
        if f > 0.0:
            lo = x
        else:
            hi = x
        pmf = math.exp(-x + errors * math.log(x) - math.lgamma(a))
        new = x + f / pmf if pmf > 0.0 else 0.5 * (lo + hi)
        if not lo < new < hi:
            new = 0.5 * (lo + hi)
        if abs(new - x) <= _LIMIT_TOL * new:
            return new
        x = new
    raise RuntimeError(f'Poisson limit did not converge for errors={errors}, confidence={confidence}')


def poissonUpperBound(errors: npt.ArrayLike, bits: npt.ArrayLike,
                      confidence: float = 0.95) -> float | np.ndarray:
    """Return the one-sided Poisson upper bound of the BER of every point.

    For ``e`` errors in ``N`` bits the true BER is below ``lam(e, c) / N``
    with confidence ``c``, where ``lam`` solves ``P(X <= e; lam) = 1 - c``
    for a Poisson variable ``X``. For ``e = 0`` this is exactly
    ``-ln(1 - c) / N`` (see :func:`zeroErrorBound`). Input of shape
    ``(2, N)`` holds the UT_SIGN 0 and 1 accumulations and is summed over
    axis 0 first, like :func:`combineCounts`.

    Parameters
    ----------
    errors : int or array_like
        Non-negative error counts, scalar, shape ``(N,)`` or ``(2, N)``.
    bits : int, float or array_like
        Bit counts with the same shape as ``errors``.
    confidence : float
        One-sided confidence level, strictly between 0 and 1.

    Returns
    -------
    float or numpy.ndarray
        The bound, a float for scalar input and a float64 array of shape
        ``(N,)`` otherwise. NaN where the summed bit count is 0.

    Raises
    ------
    ValueError
        If ``confidence`` is outside (0, 1), a count is negative or the
        shapes of ``errors`` and ``bits`` differ.
    """
    _checkConfidence(confidence)
    scalar = np.ndim(errors) == 0 and np.ndim(bits) == 0
    if scalar:
        errors, bits = [errors], [bits]
    err, nBits = _sumAccumulations(errors, bits)
    measured = nBits > 0
    out = np.full(err.shape, np.nan)
    limits = np.array([_poissonLimit(int(e), confidence) for e in err[measured]])
    out[measured] = limits / nBits[measured]
    return float(out[0]) if scalar else out


def bitsNeeded(floor: float, confidence: float = 0.95) -> float:
    """Return the error-free bit count needed to bound the BER below ``floor``.

    Parameters
    ----------
    floor : float
        Target BER floor, strictly positive.
    confidence : float
        One-sided confidence level, strictly between 0 and 1.

    Returns
    -------
    float
        ``-ln(1 - confidence) / floor``.
    """
    scale = _checkConfidence(confidence)
    if not floor > 0:
        raise ValueError(f'floor must be strictly positive, got {floor}')
    return scale / floor


def bitsPerRun(sampleCount: int, prescale: int, width: int) -> int:
    """Return the exact number of bits behind one run of ``sampleCount`` samples.

    Python integer arithmetic keeps the result exact above 2**53.

    Parameters
    ----------
    sampleCount : int
        Value of the sample counter (0 to 65535).
    prescale : int
        Raw PRESCALE field, 0 to 31.
    width : int
        Internal data width in bits.

    Returns
    -------
    int
        ``sampleCount * 2**(1 + prescale) * width``.
    """
    if not 0 <= prescale <= _MAX_PRESCALE:
        raise ValueError(f'prescale must be 0..{_MAX_PRESCALE}, got {prescale}')
    if sampleCount < 0:
        raise ValueError(f'sampleCount must not be negative, got {sampleCount}')
    if width <= 0:
        raise ValueError(f'width must be positive, got {width}')
    return int(sampleCount) * (1 << (1 + int(prescale))) * int(width)


def prescaleForFloor(floor: float, width: int, confidence: float = 0.95,
                     maxPrescale: int = _MAX_PRESCALE) -> int:
    """Return the smallest prescale whose saturated run can prove ``floor``.

    A run that saturates the sample counter observes
    ``65535 * 2**(1 + prescale) * width`` bits; the prescale is chosen so that
    this count first reaches ``bitsNeeded(floor, confidence)`` (at least 0 and
    at most ``maxPrescale``).

    Parameters
    ----------
    floor : float
        Target BER floor, strictly positive.
    width : int
        Internal data width in bits.
    confidence : float
        One-sided confidence level, strictly between 0 and 1.
    maxPrescale : int
        Upper cap on the returned prescale, 0 to 31.

    Returns
    -------
    int
        ``max(0, ceil(log2(bitsNeeded / (65535 * width))) - 1)``, capped.
    """
    if width <= 0:
        raise ValueError(f'width must be positive, got {width}')
    if not 0 <= maxPrescale <= _MAX_PRESCALE:
        raise ValueError(f'maxPrescale must be 0..{_MAX_PRESCALE}, got {maxPrescale}')
    ratio = bitsNeeded(floor, confidence) / (_MAX_SAMPLE_COUNT * width)
    prescale = max(0, math.ceil(math.log2(ratio)) - 1)
    return min(prescale, maxPrescale)


def sdataMask(width: int, busWidth: int) -> int:
    """Return the ``2 * busWidth`` bit sdata mask that leaves only ``width`` bits unmasked.

    The unmasked window sits at the top of the lower half of the mask (bits
    ``busWidth - width`` up to ``busWidth - 1``, so UG576 Table 4-20 reads
    ``[39:8]`` clear for a 32-bit GTHE3 lane); a set bit masks the sample out.

    Parameters
    ----------
    width : int
        Internal data width in bits, 1 to ``busWidth``.
    busWidth : int
        Width of the sdata bus (40 for GTHE3).

    Returns
    -------
    int
        ``((1 << 2 * busWidth) - 1) ^ (((1 << width) - 1) << (busWidth - width))``.
    """
    if not 1 <= width <= busWidth:
        raise ValueError(f'width must be 1..{busWidth}, got {width}')
    return ((1 << (2 * busWidth)) - 1) ^ (((1 << width) - 1) << (busWidth - width))


def maskWords(mask: int, nWords: int = 5) -> list[int]:
    """Split ``mask`` into 16-bit DRP words, word 0 holding bits [15:0].

    Parameters
    ----------
    mask : int
        Non-negative mask value.
    nWords : int
        Number of 16-bit words to return.

    Returns
    -------
    list of int
        ``nWords`` values in the range 0 to 0xFFFF.
    """
    if mask < 0:
        raise ValueError(f'mask must not be negative, got {mask}')
    if nWords <= 0:
        raise ValueError(f'nWords must be positive, got {nWords}')
    return [(mask >> (16 * i)) & 0xFFFF for i in range(nWords)]


def combineCounts(errors: npt.ArrayLike, bits: npt.ArrayLike,
                  confidence: float = 0.95) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Combine error and bit counts into BER values with Poisson upper bounds.

    Input of shape ``(2, N)`` holds the UT_SIGN 0 and 1 accumulations and is
    summed over axis 0 (``BER = (e0 + e1) / (b0 + b1)``); a 1-D input is one
    accumulation. A point with zero errors is never reported as BER 0: its
    ``ber`` is NaN and ``isBound`` is True. Every measured point carries
    ``berUpper``, the one-sided upper bound of the BER at ``confidence``
    (:func:`poissonUpperBound`; ``-ln(1 - confidence) / bits`` for a point
    with zero errors). A point that observed no bits carries no information
    and is NaN in both arrays with ``isBound`` False.

    Parameters
    ----------
    errors : array_like
        Non-negative error counts, shape ``(N,)`` or ``(2, N)``.
    bits : array_like
        Bit counts with the same shape as ``errors``.
    confidence : float
        One-sided confidence level of the upper bound.

    Returns
    -------
    ber : numpy.ndarray
        Measured BER ``errors / bits``, NaN where the point has zero errors or
        no bits.
    berUpper : numpy.ndarray
        Upper bound at ``confidence``, NaN where the point has no bits. It is
        never below ``ber`` for a confidence of 0.5 or more; a lower confidence
        gives a bound below the measured BER.
    isBound : numpy.ndarray
        True where the point saw zero errors (its ``ber`` is NaN).
    """
    err, nBits = _sumAccumulations(errors, bits)
    berUpper = poissonUpperBound(err, nBits, confidence)

    measured = nBits > 0
    zero = measured & (err == 0)
    seen = measured & (err > 0)
    ber = np.full(err.shape, np.nan)
    ber[seen] = err[seen] / nBits[seen]
    return ber, berUpper, zero


# Acklam rational approximation of the inverse normal CDF (relative error ~1e-9)
_ACK_A = (-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
          1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00)
_ACK_B = (-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
          6.680131188771972e+01, -1.328068155288572e+01)
_ACK_C = (-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
          -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00)
_ACK_D = (7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
          3.754408661907416e+00)
_ACK_BREAK = 0.02425


def _polyval(coeffs, x):
    """Horner evaluation, highest order coefficient first."""
    out = np.zeros_like(x) + coeffs[0]
    for c in coeffs[1:]:
        out = out * x + c
    return out


def qfunc(x: npt.ArrayLike) -> float | np.ndarray:
    """Return the Gaussian tail probability ``Q(x) = 0.5 * erfc(x / sqrt(2))``.

    Parameters
    ----------
    x : float or array_like
        Position in standard deviations.

    Returns
    -------
    float or numpy.ndarray
        ``Q(x)``, a float for scalar input and an array otherwise.
    """
    arr = np.asarray(x, dtype=float)
    out = np.array([0.5 * math.erfc(v / math.sqrt(2.0)) for v in arr.ravel()]).reshape(arr.shape)
    return float(out) if out.ndim == 0 else out


def qinv(p: npt.ArrayLike) -> float | np.ndarray:
    """Return the inverse of :func:`qfunc`, ``-ndtri(p)``.

    Uses the Acklam rational approximation with branch points at 0.02425 and
    ``1 - 0.02425``; ``qfunc(qinv(p)) / p`` stays within 1e-6 of 1 for p from
    1e-18 to 1e-3.

    Parameters
    ----------
    p : float or array_like
        Tail probability strictly inside (0, 1).

    Returns
    -------
    float or numpy.ndarray
        The Q-scale position of ``p``.

    Raises
    ------
    ValueError
        If any ``p`` is not strictly between 0 and 1 (including NaN).
    """
    arr = np.asarray(p, dtype=float)
    if not np.all((arr > 0.0) & (arr < 1.0)):
        raise ValueError('p must be strictly inside (0, 1)')
    flat = arr.ravel()
    ndtri = np.empty_like(flat)

    lo = flat < _ACK_BREAK
    hi = flat > 1.0 - _ACK_BREAK
    mid = ~(lo | hi)

    if np.any(lo):
        q = np.sqrt(-2.0 * np.log(flat[lo]))
        ndtri[lo] = _polyval(_ACK_C, q) / (_polyval(_ACK_D, q) * q + 1.0)
    if np.any(hi):
        q = np.sqrt(-2.0 * np.log1p(-flat[hi]))
        ndtri[hi] = -_polyval(_ACK_C, q) / (_polyval(_ACK_D, q) * q + 1.0)
    if np.any(mid):
        q = flat[mid] - 0.5
        r = q * q
        ndtri[mid] = _polyval(_ACK_A, r) * q / (_polyval(_ACK_B, r) * r + 1.0)

    out = (-ndtri).reshape(arr.shape)
    return float(out) if out.ndim == 0 else out


@dataclass
class TailFit:
    """Result of a Q-scale fit of one bathtub tail.

    Attributes
    ----------
    side : str
        ``'left'`` or ``'right'``.
    ok : bool
        True only when every quality gate passed; an edge may be extrapolated
        from the fit only then.
    reason : str
        Empty when ``ok``, otherwise every failed gate (words: points,
        decades, slope, r2).
    sigma : float or None
        Random-jitter sigma in the units of ``xUi`` (``1 / abs(slope)``).
    mu : float or None
        Edge position at ``BER = rho / 2`` (``-intercept / slope``).
    slope, intercept : float or None
        Weighted least-squares line of ``qinv(ber / rho)`` against ``xUi``.
    r2 : float or None
        Coefficient of determination of the weighted fit.
    nPoints : int
        Number of points that passed the usable-window selection.
    decades : float
        ``log10(max ber / min ber)`` over those points.
    """

    side: str
    ok: bool
    reason: str
    sigma: float | None
    mu: float | None
    slope: float | None
    intercept: float | None
    r2: float | None
    nPoints: int
    decades: float


def fitTail(xUi: npt.ArrayLike, errors: npt.ArrayLike, bits: npt.ArrayLike, side: str, *,
            rho: float = 0.5, minErrors: int = 10,
            berLow: float = 1e-9, berHigh: float = 1e-2, minPoints: int = 5,
            minDecades: float = 1.5, minR2: float = 0.95) -> TailFit:
    """Fit one bathtub tail on the Q scale (dual-Dirac random-jitter model).

    The caller passes only the points on one side of the eye centre. Points
    with at least ``minErrors`` errors and ``berLow < ber < berHigh`` are
    used; ``y = qinv(ber / rho)`` is fitted against ``xUi`` by weighted
    least squares (weight ``sqrt(errors)``). The fit is ``ok`` only when
    there are at least ``minPoints`` points spanning ``minDecades`` decades,
    the slope sign matches the side (negative for ``'right'``, positive for
    ``'left'``) and the weighted ``r2`` reaches ``minR2``. A failed fit never
    yields an edge.

    Parameters
    ----------
    xUi : array_like
        Sample positions of the tail points, shape ``(N,)``.
    errors : array_like
        Error counts, shape ``(N,)`` or ``(2, N)`` for two accumulations.
    bits : array_like
        Bit counts with the same shape as ``errors``.
    side : str
        ``'left'`` or ``'right'``.
    rho : float
        Transition density, in (0, 1].
    minErrors : int
        Minimum errors for a point to be usable.
    berLow, berHigh : float
        Open BER window of usable points.
    minPoints : int
        Gate: minimum number of usable points.
    minDecades : float
        Gate: minimum BER span of the usable points.
    minR2 : float
        Gate: minimum weighted coefficient of determination.

    Returns
    -------
    TailFit
        The fit with its gate verdict.
    """
    if side not in ('left', 'right'):
        raise ValueError(f"side must be 'left' or 'right', got {side!r}")
    if not 0.0 < rho <= 1.0:
        raise ValueError(f'rho must be in (0, 1], got {rho}')
    x = np.asarray(xUi, dtype=float)
    err, nBits = _sumAccumulations(errors, bits)
    if x.shape != err.shape:
        raise ValueError(f'xUi shape {x.shape} does not match counts shape {err.shape}')

    with np.errstate(divide='ignore', invalid='ignore'):
        ber = np.where(nBits > 0, err / nBits, np.nan)
    use = (nBits > 0) & (err >= minErrors) & (ber > berLow) & (ber < berHigh)
    xs, es, bs = x[use], err[use].astype(float), ber[use]
    nPoints = int(xs.size)
    decades = float(np.log10(bs.max() / bs.min())) if nPoints else 0.0

    if nPoints < 2:
        return TailFit(side, False, f'{nPoints} usable points, need at least {minPoints}',
                       None, None, None, None, None, nPoints, decades)

    ys = qinv(bs / rho)
    slope, intercept = np.polyfit(xs, ys, 1, w=np.sqrt(es))
    resid = ys - (slope * xs + intercept)
    ssRes = float(np.sum(es * resid ** 2))
    ssTot = float(np.sum(es * (ys - np.sum(es * ys) / np.sum(es)) ** 2))
    r2 = 1.0 - ssRes / ssTot if ssTot > 0 else 0.0

    failed = []
    if nPoints < minPoints:
        failed.append(f'{nPoints} usable points, need at least {minPoints}')
    if decades < minDecades:
        failed.append(f'{decades:.2f} decades spanned, need at least {minDecades}')
    if (side == 'right' and not slope < 0) or (side == 'left' and not slope > 0):
        failed.append(f'slope {slope:.4g} has the wrong sign for the {side} tail')
    if r2 < minR2:
        failed.append(f'r2 {r2:.3f} below {minR2}')

    slope, intercept = float(slope), float(intercept)
    sigma = 1.0 / abs(slope) if slope != 0 else None
    mu = -intercept / slope if slope != 0 else None
    return TailFit(side, not failed, '; '.join(failed), sigma, mu, slope, intercept,
                   float(r2), nPoints, decades)


def edgeAt(fit: TailFit, ber: float, rho: float = 0.5) -> float | None:
    """Return the tail position where the fitted BER equals ``ber``.

    Parameters
    ----------
    fit : TailFit
        A tail fit.
    ber : float
        Target BER, below ``rho``.
    rho : float
        Transition density used for the fit.

    Returns
    -------
    float or None
        ``(qinv(ber / rho) - intercept) / slope`` in the units of the fit's
        ``xUi``, or None when the fit failed any quality gate.

    Raises
    ------
    ValueError
        If ``ber / rho`` is not strictly inside (0, 1) for an ok fit.
    """
    if not fit.ok:
        return None
    return float((qinv(ber / rho) - fit.intercept) / fit.slope)


def openRegion(horzCounts: npt.ArrayLike, errors: npt.ArrayLike, bits: npt.ArrayLike, floor: float,
               confidence: float = 0.95) -> tuple[int, int] | None:
    """Return the longest contiguous run of points proven to meet ``floor``.

    A point is open when it observed bits and its one-sided Poisson upper
    bound at ``confidence`` (:func:`poissonUpperBound`, which equals the
    zero-error bound for a point without errors) is at or below ``floor``.
    Accumulations of a ``(2, N)`` input are summed first. When two runs are
    equally long the one containing, or nearest to, count 0 wins (then the
    leftmost).

    Parameters
    ----------
    horzCounts : array_like
        Strictly increasing sample positions in counts.
    errors : array_like
        Error counts, shape ``(N,)`` or ``(2, N)``.
    bits : array_like
        Bit counts with the same shape as ``errors``.
    floor : float
        BER floor, strictly positive.
    confidence : float
        Confidence of the upper bound.

    Returns
    -------
    tuple of int or None
        Inclusive ``(first, last)`` indices of the run, or None when no point
        is open.
    """
    counts = np.asarray(horzCounts)
    err, nBits = _sumAccumulations(errors, bits)
    if counts.shape != err.shape:
        raise ValueError(f'horzCounts shape {counts.shape} does not match counts shape {err.shape}')
    if counts.size > 1 and not np.all(np.diff(counts) > 0):
        raise ValueError('horzCounts must be strictly increasing')
    if not floor > 0:
        raise ValueError(f'floor must be strictly positive, got {floor}')
    open_ = poissonUpperBound(err, nBits, confidence) <= floor

    best = None
    bestKey = None
    start = None
    for i in range(open_.size + 1):
        if i < open_.size and open_[i]:
            if start is None:
                start = i
            continue
        if start is not None:
            run = counts[start:i]
            key = (i - start, -int(np.abs(run).min()))
            if bestKey is None or key > bestKey:
                best, bestKey = (start, i - 1), key
            start = None
    return best


def extrapolatedOpening(leftFit: TailFit, rightFit: TailFit, targetBer: float,
                        rho: float = 0.5) -> float | None:
    """Return the extrapolated eye opening at ``targetBer``.

    Parameters
    ----------
    leftFit, rightFit : TailFit
        Fits of the left and right tails.
    targetBer : float
        Target BER, below ``rho``.
    rho : float
        Transition density used for the fits.

    Returns
    -------
    float or None
        ``edgeAt(rightFit) - edgeAt(leftFit)`` (signed, negative when the
        extrapolated edges cross), or None unless both fits are ok.
    """
    right = edgeAt(rightFit, targetBer, rho)
    left = edgeAt(leftFit, targetBer, rho)
    if right is None or left is None:
        return None
    return right - left


def openComponent(openMask: npt.ArrayLike, seedRow: int, seedCol: int) -> np.ndarray:
    """Return the 4-connected open component that contains a seed point.

    Only points that share an edge are connected; a diagonal neighbour or an
    isolated open point elsewhere in the grid is not part of the component.

    Parameters
    ----------
    openMask : array_like
        Boolean grid of shape ``(nV, nH)``, True where a position is open.
    seedRow, seedCol : int
        Position of the seed in ``openMask``.

    Returns
    -------
    numpy.ndarray
        Boolean mask of the same shape. It is all False when the seed is
        outside the grid or not open, and never contains a point that is not
        open.
    """
    grid = np.asarray(openMask, dtype=bool)
    out = np.zeros(grid.shape, dtype=bool)
    nRows, nCols = grid.shape
    if not (0 <= seedRow < nRows and 0 <= seedCol < nCols) or not grid[seedRow, seedCol]:
        return out
    out[seedRow, seedCol] = True
    stack = [(int(seedRow), int(seedCol))]
    while stack:
        row, col = stack.pop()
        for r, c in ((row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1)):
            if 0 <= r < nRows and 0 <= c < nCols and grid[r, c] and not out[r, c]:
                out[r, c] = True
                stack.append((r, c))
    return out


def areaAsymmetry(component: npt.ArrayLike, horzAxis: npt.ArrayLike, vertAxis: npt.ArrayLike,
                  centreHorz: float, centreVert: float) -> tuple[float | None, float | None]:
    """Return the left-right and top-bottom asymmetry of an open area.

    Points of the component strictly right, left, above and below the centre
    are counted; a point on the centre column or row counts to neither side
    of that axis.

    Parameters
    ----------
    component : array_like
        Boolean mask of shape ``(nV, nH)``.
    horzAxis : array_like
        Horizontal position of every column.
    vertAxis : array_like
        Vertical position of every row.
    centreHorz, centreVert : float
        Centre in the units of the axes.

    Returns
    -------
    tuple of float or None
        ``((right - left) / (right + left), (top - bottom) / (top + bottom))``,
        each signed in [-1, 1] and None when no component point lies off the
        centre line of that axis.
    """
    comp = np.asarray(component, dtype=bool)
    horz = np.asarray(horzAxis, dtype=float)
    vert = np.asarray(vertAxis, dtype=float)
    if comp.shape != (vert.size, horz.size):
        raise ValueError(f'component shape {comp.shape} does not match the axes ({vert.size}, {horz.size})')
    perColumn = comp.sum(axis=0)
    perRow = comp.sum(axis=1)
    right, left = int(perColumn[horz > centreHorz].sum()), int(perColumn[horz < centreHorz].sum())
    top, bottom = int(perRow[vert > centreVert].sum()), int(perRow[vert < centreVert].sum())
    asymLR = (right - left) / (right + left) if right + left else None
    asymTB = (top - bottom) / (top + bottom) if top + bottom else None
    return asymLR, asymTB


def nearestTowardZero(x: float) -> int:
    """Return the integer nearest to ``x``, with exact halves rounded toward 0.

    Parameters
    ----------
    x : float
        Value to round.

    Returns
    -------
    int
        ``2.5`` gives 2, ``-2.5`` gives -2, ``2.6`` gives 3 and ``-0.4`` gives 0.
    """
    magnitude = abs(float(x))
    whole = math.floor(magnitude)
    rounded = whole + 1 if magnitude - whole > 0.5 else whole
    return -rounded if x < 0 else rounded
