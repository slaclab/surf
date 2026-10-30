#-----------------------------------------------------------------------------
# Title      : Eye-scan engine
#-----------------------------------------------------------------------------
# Description:
# Eye-scan state machine driver: sampler activation with an RX reset hook, the
# soft return to the cold state, one BER point with adaptive prescale, the
# two-sided horizontal bathtub, the 2D eye raster, the margin run (eye plus a
# step-1 cross through the eye centre in one activation), and the read-only
# state snapshot. Every wait is bounded and checks the abort request at least every
# 50 ms.
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

import dataclasses
import math
import threading
import time
from datetime import datetime
from types import SimpleNamespace
from typing import Any, Callable

import numpy as np

from surf.xilinx.eyescan._EyeScanFamilies import PHASE_RULES
from surf.xilinx.eyescan._EyeScanMath import (
    TailFit,
    areaAsymmetry,
    bitsNeeded,
    bitsPerRun,
    combineCounts,
    extrapolatedOpening,
    fitTail,
    nearestTowardZero,
    openComponent,
    openRegion,
    prescaleForFloor,
)
from surf.xilinx.eyescan._EyeScanOutput import formatBer
from surf.xilinx.eyescan._EyeScanPort import EyeScanPort
from surf.xilinx.eyescan._EyeScanTypes import (
    STATUS_END,
    STATUS_OFF,
    STATUS_WAIT,
    ActivationResult,
    BathtubResult,
    EyeCentre,
    EyeResult,
    EyeScanAborted,
    EyeScanError,
    EyeScanNotActive,
    EyeScanTimeout,
    EyeScanUnlocked,
    LaneState,
    MarginResult,
    MarginSummary,
    PointResult,
    ResetPolicy,
    RxResetHook,
    ScanStatus,
    SoftColdResult,
    SweepResult,
    decodeControlStatus,
)

__all__ = [
    'ScanControl',
    'EyeScanEngine',
]

# Seconds the sampler gets to reach END after RUN when it is being activated
PROBE_WINDOW = 2.0

# Prescale rungs tried before the one that can prove the floor
LADDER = (0, 3, 6, 8)

# A point stops climbing the ladder once its summed errors reach this count
ERROR_STOP = 100

# Longest a single run may take before it is stopped and its partial counts used
MAX_TIME_PER_RUN = 30.0

# Fraction of the line rate the sampler counts bits at: measured on KCU1500 GTH lanes running PGP4 at 6.25 Gb/s
SAMPLER_EFFICIENCY = 0.965

# Seconds a run costs beyond its counting time (RUN to END poll, counter reads, RUN cleared to idle):
# measured on KCU1500 GTH lanes through the PyRogue driver, medians of the 2D eye points
RUN_OVERHEAD = 0.000561

# Prescale of the one run that measures the line rate, long enough to time and short enough to be cheap
_RATE_PRESCALE = 8

# Samples of a run that saturates the sample counter
_RUN_SAMPLES = 65535

# Errors of a run that saturates the error counter
_RUN_ERRORS = 65535

# RX resets one activation may use to bring the sampler in step with the data sampler. On the
# C1100 GTYE4 lanes at 15.46875 Gb/s an out-of-step sampler (error ratio 0.25 at every offset)
# compares the data with samples two bits off. Setting the enables draws that alignment at random;
# an RX reset with the enables held then flips it on some lanes (nearly always) and keeps it on
# others (always). The first retry is a plain reset and every later one clears and sets the
# enables first, so a lane whose resets keep the state is scanned with a warning after ten draws out
# of step, and the scan reports what it measures
SYNC_RESETS = 12

# Seconds both enables stay cleared before they are set again for a retry
REARM_WAIT = 0.1

# Stated once, in the scan warnings and the process message, when the rate was measured
_RATE_WARNING = ('LineRateGbps is not defined; measured {rate:.4g} Gb/s during the scan, '
                 'which is less accurate than setting LineRateGbps')

# Refusal of a 'rate' scan whose line rate is not known: the encoding of bit 11 depends on it
_RATE_RULE_REFUSAL = ("{family}: the phase-unification rule 'rate' needs the line rate, so set LineRateGbps "
                      "or pass a positive lineRateGbps; nothing was written")

# The UT_SIGN comparison needs this many summed errors and stays below this BER
UT_COMPARE_ERRORS = 100
UT_COMPARE_BER_MAX = 1e-2

# Targets at or above the transition density cannot be extrapolated to
_RHO = 0.5

# UT_SIGN values accumulated per equalizer mode (DFE needs both, LPM one)
_UT_SIGNS = {'dfe': (0, 1), 'lpm': (0,)}

# Longest slice of any wait, so an abort request is seen within 50 ms
_SLICE = 0.05

# Poll period of the activation probe and the reset handshake
_POLL = 0.002

# Why openings differ between scans of one lane
_MARGIN_NOTE = ('openings move between RX resets (receiver re-adaptation); '
                'compare settings within one RX reset')

_NO_HOOK = 'no RX reset hook registered: call EyeScan.setRxReset(reset, ready)'

# The two causes a lane that delivers no usable data can have; the scan cannot tell them apart
_TWO_CAUSES = 'the eye-scan sampler is out of step with the data sampler, or the link is closed or unlocked'

# Why a scan checks the sampler again after its last point
_LATE_DROP = ('a link drop shorter than one point passes between two ready reads unseen, so the points measured '
              'after it may read closed by the sampler alone; the scan reports what it measured')


class ScanControl:
    """Abort flag, optional external abort source and progress callback.

    Parameters
    ----------
    isAborted : callable, optional
        Returns True when the run must stop (for example a Stop command).
    onProgress : callable, optional
        Called as ``onProgress(done, total)`` by :meth:`progress`.
    onMessage : callable, optional
        Called as ``onMessage(text)`` by :meth:`message` with the stage the
        scan is in.
    """

    def __init__(
            self,
            isAborted: Callable[[], bool] | None = None,
            onProgress: Callable[[int, int], None] | None = None,
            onMessage: Callable[[str], None] | None = None) -> None:
        self._event = threading.Event()
        self._isAborted = isAborted
        self._onProgress = onProgress
        self._onMessage = onMessage

    def abort(self) -> None:
        """Request that the run stops at its next check."""
        self._event.set()

    @property
    def aborted(self) -> bool:
        """True once an abort was requested."""
        return self._event.is_set() or (self._isAborted is not None and bool(self._isAborted()))

    def check(self) -> None:
        """Raise EyeScanAborted when an abort was requested."""
        if self.aborted:
            raise EyeScanAborted('eye scan aborted')

    def sleep(self, seconds: float) -> None:
        """Sleep for ``seconds`` in slices of at most 50 ms, checking for an abort.

        Parameters
        ----------
        seconds : float
            Time to sleep, in seconds.

        Raises
        ------
        EyeScanAborted
            If an abort was requested before or during the sleep.
        """
        end = time.monotonic() + seconds
        while True:
            self.check()
            remaining = end - time.monotonic()
            if remaining <= 0:
                return
            time.sleep(min(_SLICE, remaining))

    def progress(self, done: int, total: int) -> None:
        """Report progress to the registered callback, if any.

        Parameters
        ----------
        done : int
            Steps finished so far.
        total : int
            Steps in the run.
        """
        if self._onProgress is not None:
            self._onProgress(done, total)

    def message(self, text: str) -> None:
        """Report the stage text to the registered callback, if any.

        Parameters
        ----------
        text : str
            Description of the stage the scan is in.
        """
        if self._onMessage is not None:
            self._onMessage(text)


def _checkBitCount(name: str, floor: float, confidence: float) -> None:
    """Raise ValueError for a floor whose error-free bit count cannot be represented."""
    if not math.isfinite(bitsNeeded(floor, confidence)):
        raise ValueError(f'{name} is too small, got {floor}: the bit count that proves it is not finite')


def _checkPointArgs(floor: float, confidence: float, equalizer: str,
                    fixedPrescale: int | None, maxTimePerRun: float) -> None:
    """Raise ValueError for an argument a point cannot be measured with."""
    if not 0.0 < floor < 1.0:
        raise ValueError(f'floor must be in the open interval (0, 1), got {floor}')
    if not 0.0 < confidence < 1.0:
        raise ValueError(f'confidence must be in the open interval (0, 1), got {confidence}')
    _checkBitCount('floor', floor, confidence)
    if equalizer not in _UT_SIGNS:
        raise ValueError(f'equalizer must be one of {sorted(_UT_SIGNS)}, got {equalizer!r}')
    if fixedPrescale is not None:
        if isinstance(fixedPrescale, bool) or not isinstance(fixedPrescale, (int, np.integer)):
            raise ValueError(f'fixedPrescale must be an integer 0..31, got {fixedPrescale!r}')
        if not 0 <= fixedPrescale <= 31:
            raise ValueError(f'fixedPrescale must be 0..31, got {fixedPrescale}')
    if not maxTimePerRun > 0:
        raise ValueError(f'maxTimePerRun must be positive, got {maxTimePerRun}')


def _analysisFailure(exc: Exception, status: ScanStatus, message: str) -> tuple[ScanStatus, str]:
    """ERROR status and text of a post-scan analysis that raised, keeping the status the scan ended with."""
    text = f'analysis failed after the scan: {type(exc).__name__}: {exc}'
    if status is not ScanStatus.OK:
        text += f' (the scan ended {status.value}' + (f': {message})' if message else ')')
    return ScanStatus.ERROR, text


def _noTransitions(half: int) -> str:
    """Warning of a scan that counted no errors at either end of the UI."""
    return (f'no errors at either end of the UI (counts -{half} and +{half}), '
            f'where a live link shows its data transitions: {_TWO_CAUSES}')


class _EmptyRun(EyeScanTimeout):
    """A run that reached END by itself with no samples: the receiver delivered no data."""


def _failedFit(side: str) -> TailFit:
    """The fit of a tail whose analysis raised."""
    return TailFit(side, ok=False, reason='analysis failed', sigma=None, mu=None, slope=None, intercept=None,
                   r2=None, nPoints=0, decades=0.0)


def _prescalePlan(floor: float, confidence: float, width: int, fixedPrescale: int | None) -> tuple[int, ...]:
    """Return the prescale rungs of one point, in the order they are tried."""
    if fixedPrescale is not None:
        return (int(fixedPrescale),)
    pFloor = prescaleForFloor(floor, width, confidence)
    return tuple(sorted({p for p in LADDER if p < pFloor})) + (pFloor,)


def _checkStep(step: Any) -> int:
    """Return ``step`` as an int, raising ValueError unless it is a positive integer."""
    if isinstance(step, bool) or not isinstance(step, (int, np.integer)) or step < 1:
        raise ValueError(f'step must be a positive integer, got {step!r}')
    return int(step)


def _checkPhase(rule: str | None) -> None:
    """Refuse a phase-unification rule that is neither None nor one of ``PHASE_RULES``."""
    if rule is not None and rule not in PHASE_RULES:
        raise ValueError(f'phaseUnification must be None or one of {PHASE_RULES}, got {rule!r}')


def _checkRange(name: str, value: Any) -> int | None:
    """Return ``value`` as an int, or None, raising ValueError unless it is None or a positive integer."""
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, np.integer)) or value < 1:
        raise ValueError(f'{name} must be None or a positive integer, got {value!r}')
    return int(value)


def _gridAxis(rangeMax: int, step: int) -> np.ndarray:
    """Return the symmetric scan axis ``k * step`` for ``|k * step| <= rangeMax``.

    The axis is ascending, int64 and always contains 0; a range that is not a
    multiple of the step is truncated to the last multiple inside it.
    """
    ks = np.arange(0, rangeMax // step + 1, dtype=np.int64) * step
    return np.unique(np.concatenate([ks, -ks]))


def _resolveRanges(half: int, vertMax: int, horzStep: int, vertStep: int,
                   horzRange: int | None, vertRange: int | None) -> tuple[int, int]:
    """Return the effective ranges, raising ValueError for one the lane or the step cannot honour."""
    horzRange = half if horzRange is None else horzRange
    vertRange = vertMax if vertRange is None else vertRange
    if horzRange > half:
        raise ValueError(f'horzRange {horzRange} is larger than half a UI of {half} counts')
    if vertRange > vertMax:
        raise ValueError(f'vertRange {vertRange} is larger than the largest code {vertMax}')
    if horzStep > horzRange:
        raise ValueError(f'horzStep {horzStep} is larger than the range of {horzRange} counts')
    if vertStep > vertRange:
        raise ValueError(f'vertStep {vertStep} is larger than the range of {vertRange} codes')
    return horzRange, vertRange


def pointSeconds(floor: float, confidence: float, width: int, lineRateGbps: float, *,
                 fixedPrescale: int | None = None, nUt: int = 2,
                 maxTimePerRun: float = MAX_TIME_PER_RUN) -> float:
    """Return the seconds one point costs when it runs its whole prescale plan.

    The cumulative plan of :func:`_prescalePlan` is simulated: every rung runs
    once per UT_SIGN and the point stops after the first rung where the summed
    bits reach ``bitsNeeded(floor, confidence)``, as the engine does when no
    errors appear. A run costs ``min(maxTimePerRun, bits / rate)`` plus
    ``RUN_OVERHEAD``, where ``rate`` is the line rate times
    ``SAMPLER_EFFICIENCY``.

    Parameters
    ----------
    floor : float
        BER floor the point must prove, in (0, 1).
    confidence : float
        One-sided confidence of the zero-error bound, in (0, 1).
    width : int
        Internal data width in bits.
    lineRateGbps : float
        Line rate in Gb/s; 0 or less leaves only the overhead terms.
    fixedPrescale : int, optional
        Run exactly this one prescale.
    nUt : int
        UT_SIGN values accumulated per rung, 2 for DFE and 1 for LPM.
    maxTimePerRun : float
        Seconds one run may take.

    Returns
    -------
    float
        Modelled seconds of the point.

    Raises
    ------
    ValueError
        If an argument cannot be modelled.
    """
    if not maxTimePerRun > 0:
        raise ValueError(f'maxTimePerRun must be positive, got {maxTimePerRun}')
    rate = max(0.0, lineRateGbps) * 1e9 * SAMPLER_EFFICIENCY
    needed = bitsNeeded(floor, confidence)
    bits = 0.0
    seconds = 0.0
    for prescale in _prescalePlan(floor, confidence, width, fixedPrescale):
        runBits = float(bitsPerRun(_RUN_SAMPLES, prescale, width))
        runSeconds = 0.0
        if rate > 0:
            runBits = min(runBits, rate * maxTimePerRun)
            runSeconds = runBits / rate
        seconds += nUt * (runSeconds + RUN_OVERHEAD)
        bits += nUt * runBits
        if bits >= needed:
            break
    return seconds


def scanPointCounts(mode: str, *, horzStep: int, vertStep: int, horzRange: int, vertRange: int) -> dict:
    """Return the number of points each stage of a scan measures.

    Every axis comes from :func:`_gridAxis`, the same builder the scans use, so
    the counts are exactly the points measured.

    Parameters
    ----------
    mode : str
        ``Bathtub``, ``Eye`` or ``Margin``.
    horzStep, vertStep : int
        Grid spacing of the eye (``horzStep`` also spaces the bathtub).
    horzRange, vertRange : int
        Largest offset of the grid; the horizontal range of a bathtub is the
        full half range of the lane.

    Returns
    -------
    dict
        ``horz`` for ``Bathtub``, ``eye`` for ``Eye``, and ``eye``, ``horz``
        and ``vert`` (the step-1 cross) for ``Margin``.

    Raises
    ------
    ValueError
        If ``mode`` is unknown or a step is not a positive integer.
    """
    horzStep = _checkStep(horzStep)
    vertStep = _checkStep(vertStep)
    if mode == 'Bathtub':
        return dict(horz=int(_gridAxis(horzRange, horzStep).size))
    eye = int(_gridAxis(horzRange, horzStep).size) * int(_gridAxis(vertRange, vertStep).size)
    if mode == 'Eye':
        return dict(eye=eye)
    if mode == 'Margin':
        return dict(eye=eye, horz=int(_gridAxis(horzRange, 1).size), vert=int(_gridAxis(vertRange, 1).size))
    raise ValueError(f'mode must be Bathtub, Eye or Margin, got {mode!r}')


def estimateScanSeconds(mode: str, *, floor: float, bathtubFloor: float, confidence: float, horzStep: int,
                        vertStep: int, horzRange: int, vertRange: int, equalizer: str,
                        fixedPrescale: int | None, lineRateGbps: float, width: int, maxTimePerRun: float,
                        activationSeconds: float = 0.0, measureLineRate: bool = False) -> float:
    """Return the worst-case seconds of a scan, with every point running its whole prescale plan.

    The stages are priced with :func:`pointSeconds`: a ``Bathtub`` at
    ``bathtubFloor``, an ``Eye`` at ``floor``, a ``Margin`` as the eye at
    ``floor`` plus the step-1 cross at ``bathtubFloor``.

    Parameters
    ----------
    mode : str
        ``Bathtub``, ``Eye`` or ``Margin``.
    floor, bathtubFloor : float
        BER floors of the eye and of the bathtub or cross, in (0, 1).
    confidence : float
        One-sided confidence of the zero-error bound, in (0, 1).
    horzStep, vertStep : int
        Grid spacing of the eye (``horzStep`` also spaces the bathtub).
    horzRange, vertRange : int
        Largest offset of the grid in counts and codes.
    equalizer : str
        ``dfe`` or ``lpm``.
    fixedPrescale : int, optional
        Run exactly this one prescale at every point.
    lineRateGbps : float
        Line rate in Gb/s; 0 or less leaves only the overhead terms.
    width : int
        Internal data width in bits.
    maxTimePerRun : float
        Seconds one run may take.
    activationSeconds : float
        Seconds of the RX reset and probe before the first point.
    measureLineRate : bool
        Add the one prescale 8 run that measures the line rate.

    Returns
    -------
    float
        Modelled seconds of the scan.

    Raises
    ------
    ValueError
        If an argument cannot be modelled.
    """
    _checkPointArgs(floor, confidence, equalizer, fixedPrescale, maxTimePerRun)
    if not 0.0 < bathtubFloor < 1.0:
        raise ValueError(f'bathtubFloor must be in the open interval (0, 1), got {bathtubFloor}')
    counts = scanPointCounts(mode, horzStep=horzStep, vertStep=vertStep, horzRange=horzRange, vertRange=vertRange)
    nUt = len(_UT_SIGNS[equalizer])

    def stage(points: int, stageFloor: float) -> float:
        return points * pointSeconds(stageFloor, confidence, width, lineRateGbps, fixedPrescale=fixedPrescale,
                                     nUt=nUt, maxTimePerRun=maxTimePerRun)

    seconds = activationSeconds
    if mode == 'Bathtub':
        seconds += stage(counts['horz'], bathtubFloor)
    else:
        seconds += stage(counts['eye'], floor)
        if mode == 'Margin':
            seconds += stage(counts['horz'] + counts['vert'], bathtubFloor)
    if measureLineRate:
        seconds += pointSeconds(floor, confidence, width, lineRateGbps, fixedPrescale=_RATE_PRESCALE, nUt=1,
                                maxTimePerRun=maxTimePerRun)
    return seconds


class _Progress:
    """Progress in integer microseconds of modelled point seconds done over the modelled total."""

    def __init__(self, control: ScanControl) -> None:
        self._control = control
        self.total = 0
        self.done = 0

    @staticmethod
    def micro(seconds: float) -> int:
        """Return ``seconds`` as whole microseconds, at least 1 so every point advances."""
        return max(1, round(seconds * 1e6))

    def plan(self, *stages: tuple[int, float]) -> None:
        """Set the total from ``(points, modelled seconds per point)`` stages and restart the count."""
        self.total = sum(points * self.micro(seconds) for points, seconds in stages)
        self.done = 0

    def advance(self, seconds: float) -> None:
        """Count one finished point of ``seconds`` modelled seconds and report it."""
        self.done += self.micro(seconds)
        self._control.progress(self.done, self.total)


def _classify(exc: Exception) -> tuple[ScanStatus, str]:
    """Map an exception to a scan status and a message."""
    if isinstance(exc, EyeScanAborted):
        status = ScanStatus.ABORTED
    elif isinstance(exc, EyeScanNotActive):
        status = ScanStatus.NOT_ENABLED
    elif isinstance(exc, EyeScanTimeout):
        status = ScanStatus.TIMEOUT
    elif isinstance(exc, EyeScanUnlocked):
        status = ScanStatus.UNLOCKED
    else:
        status = ScanStatus.ERROR
    text = str(exc) if isinstance(exc, EyeScanError) else f'{type(exc).__name__}: {exc}'
    return status, text


def _settle(status: ScanStatus, message: str, error: Exception | None, restoreError: Exception | None):
    """Final status and message once the restore outcome is known.

    A scan that ended for any reason and then failed to restore the registers
    is an ERROR; the message keeps the name of the status it ended with.
    """
    if error is not None:
        status, message = _classify(error)
    if restoreError is not None:
        _, text = _classify(restoreError)
        message = f'restore failed: {text}; scan ended {status.value}' + (f': {message}' if message else '')
        status = ScanStatus.ERROR
    return status, message


class EyeScanEngine:
    """Eye-scan engine for one lane.

    Parameters
    ----------
    port : EyeScanPort
        Register port of the lane's driver device.
    hook : RxResetHook, optional
        RX reset hook registered by the application.
    control : ScanControl, optional
        Abort flag and progress callback of the run.
    """

    def __init__(self, port: EyeScanPort, hook: RxResetHook | None = None,
                 control: ScanControl | None = None) -> None:
        self.port = port
        self.hook = hook
        self.control = control if control is not None else ScanControl()
        self._snapshot = None
        self._result = None
        self._rungProgress = True
        # (rule, line rate in Gb/s) of the scan in progress; None writes the sign encoding
        self._phase = None

    def readState(self) -> LaneState:
        """Read the eye-scan state of the lane (hardware reads only, no writes).

        Returns
        -------
        LaneState
            Snapshot of the enables, control, counters and decoded widths.
        """
        port = self.port
        controlStatus = port.read('controlStatus')

        bits = None
        widthError = None
        try:
            bits = port.bitsPerSample()
        except EyeScanError as e:
            widthError = str(e)

        rxOutDiv = None
        horzHalfRange = None
        try:
            rxOutDiv = port.rxOutDiv()
            horzHalfRange = port.family.countsPerHalfUiPerDiv * rxOutDiv
        except EyeScanError:
            pass

        return LaneState(
            family            = port.family.name,
            eyeScanEn         = port.read('eyeScanEn'),
            errDetEn          = port.read('errDetEn'),
            control           = port.read('control'),
            prescale          = port.read('prescale'),
            controlStatus     = controlStatus,
            controlStatusName = decodeControlStatus(controlStatus),
            errorCount        = port.read('errorCount'),
            sampleCount       = port.read('sampleCount'),
            bitsPerSample     = bits,
            widthError        = widthError,
            rxOutDiv          = rxOutDiv,
            horzHalfRange     = horzHalfRange,
            rxResetHook       = self.hook.description if self.hook is not None else 'none',
        )

    def _waitIdle(self) -> None:
        self.port.waitIdle(sleep=self.control.sleep)

    def _handshake(self, hook: RxResetHook, out: Any) -> None:
        """Pulse the hook, wait for ready to fall, then to rise, then settle.

        ``out`` receives ``sawFall``, ``tFall`` and ``tReady`` (seconds from the
        start of the pulse). A ready that never falls is recorded, not an error;
        a ready that never rises raises EyeScanNotActive.
        """
        ctl = self.control
        t0 = time.monotonic()
        hook.pulse()
        fallDeadline = time.monotonic() + hook.fallWait
        while True:
            ctl.check()
            if not hook.ready():
                out.sawFall = True
                out.tFall = time.monotonic() - t0
                break
            if time.monotonic() >= fallDeadline:
                break
            ctl.sleep(_POLL)
        readyDeadline = time.monotonic() + hook.timeout
        while True:
            ctl.check()
            if hook.ready():
                out.tReady = time.monotonic() - t0
                break
            if time.monotonic() >= readyDeadline:
                raise EyeScanNotActive(
                    f'RX reset ready ({hook.description}) did not return True within '
                    f'{hook.timeout:g} s after the reset pulse')
            ctl.sleep(_POLL)
        ctl.sleep(hook.settle)

    def _runProbe(self, probeWindow: float) -> tuple[int, int, int]:
        """Set RUN and wait up to ``probeWindow`` for END; return (status, samples, errors)."""
        port, ctl = self.port, self.control
        port.write('control', 1, verify=False)
        deadline = time.monotonic() + probeWindow
        while True:
            ctl.check()
            status = port.read('controlStatus')
            if status == STATUS_END or time.monotonic() >= deadline:
                break
            ctl.sleep(_POLL)
        ctl.check()
        samples = port.read('sampleCount') if status == STATUS_END else 0
        errors = port.read('errorCount') if status == STATUS_END else 0
        port.write('control', 0, verify=False)
        self._waitIdle()
        return status, samples, errors

    def _prepareProbe(self, width: int) -> None:
        """Write the masks and park the scan position at the eye centre."""
        port = self.port
        port.writeMasks(width)
        port.write('prescale', 0)
        port.write('horzOffset', self._horzWord(0))
        for role in ('vsCode', 'vsNegDir', 'vsUtSign'):
            port.write(role, 0)

    def _resolvePhase(self, rule: str | None, params: dict) -> None:
        """Fix the phase-unification rule of the scan about to start.

        ``None`` takes the family rule. The rule ``rate`` needs a positive line
        rate: without one the scan is refused here, before anything is written.
        The rule is recorded in ``params`` either way.

        Raises
        ------
        EyeScanError
            If the rule is ``rate`` and the line rate is not positive.
        """
        self._phase = None
        family = self.port.family
        rule = family.phaseUnification if rule is None else rule
        params['phaseUnification'] = rule
        rate = params['lineRateGbps']
        if rule == 'rate' and not rate > 0:
            raise EyeScanError(_RATE_RULE_REFUSAL.format(family=family.name))
        self._phase = (rule, rate)

    def _horzWord(self, horz: int) -> int:
        """Raw horizontal offset word of a signed count under the rule of the scan.

        ``sign`` (also when no scan fixed a rule): bit 11 is 1 only for a
        negative count. ``rate``: bit 11 is 1 for every count when the line rate
        is above the family threshold and 0 at or below it. Bits [10:0] are
        always the two's complement count.
        """
        family = self.port.family
        mask = (1 << family.horzBits) - 1
        if self._phase is None or self._phase[0] == 'sign':
            return horz & mask
        top = 1 << (family.horzBits - 1)
        return (horz & (top - 1)) | (top if self._phase[1] > family.rateThresholdGbps else 0)

    def _begin(self) -> dict:
        """Prime the shared words and snapshot the registers a scan changes."""
        self.port.prime()
        self._snapshot = self.port.snapshot()
        return self._snapshot

    def _guarded(self, body: Callable[[], Any]):
        """Run ``body`` between prime and restore.

        Returns ``(value, error, restoreError)``; the restore runs whenever the
        snapshot was taken, whatever ended the body.
        """
        snapshot = None
        value = error = restoreError = None
        try:
            snapshot = self._begin()
            value = body()
        except Exception as exc:
            error = exc
        finally:
            self._snapshot = None
            if snapshot is not None:
                try:
                    self.port.restore(snapshot)
                except Exception as exc:
                    restoreError = exc
        return value, error, restoreError

    @staticmethod
    def _noteSync(params: dict, activation: ActivationResult | None) -> None:
        """Add the sync warning of an activation to the scan warnings."""
        if activation is not None and activation.syncWarning and activation.syncWarning not in params['warnings']:
            params['warnings'].append(activation.syncWarning)

    @staticmethod
    def _withSyncWarning(message: str, activation: ActivationResult | None) -> str:
        """Append the sync warning of an activation to a result message, once."""
        warning = '' if activation is None else activation.syncWarning
        if not warning or warning in message:
            return message
        return f'{message}; {warning}' if message else warning

    def ensureActive(self, policy: ResetPolicy = ResetPolicy.Auto,
                     probeWindow: float = PROBE_WINDOW, width: int | None = None) -> ActivationResult:
        """Bring the sampler to an active state.

        Sets both enables, calls the RX reset hook unless the policy is
        ``Never``, and proves the sampler alive: a RUN must reach END with a non-zero
        sample count inside ``probeWindow``. The probe at the eye centre must also
        leave its error counter short of full and end with a full sample counter;
        a full error counter, or a run that ended with fewer samples, means the
        sampler is out of step with the data (or the receiver delivers none), and
        the hook is called again, up to ``SYNC_RESETS`` resets in all. The first such retry is a plain reset; the
        later ones clear both enables for ``REARM_WAIT`` and set them again before
        the reset, because on some lanes a reset never changes the alignment. A
        centre run that is still not in step after ``SYNC_RESETS`` resets, or
        under ``Never``, is recorded in ``ActivationResult.syncWarning`` (sampler
        out of step, or link closed or unlocked) and the activation still
        returns.

        Parameters
        ----------
        policy : ResetPolicy
            ``Auto`` and ``Always`` reset the RX on every activation through
            the registered hook and refuse (``NOT_ENABLED``) when no hook is
            registered; ``Never`` only sets the enables and never resets.
        probeWindow : float
            Seconds the probe run has to reach END.
        width : int, optional
            Internal data width in bits; decoded from the registers when omitted.

        Returns
        -------
        ActivationResult
            Status OK with the handshake timing and the probe counters;
            ``syncWarning`` is empty unless the centre run stayed out of step.

        Raises
        ------
        EyeScanNotActive
            If no hook is registered under ``Auto`` or ``Always``, the enables
            do not read back set, the sampler never reached END or counted no
            samples, or the ready signal did not return; the partial
            :class:`ActivationResult` is attached as ``exc.result``.

        Notes
        -----
        This changes ES_CONTROL, both enables, the masks and the scan position
        and restores none of them. Setting the enables on a running GTYE4 lane
        drops the link once, so a retry with re-armed enables costs a link drop
        beyond its reset. Call it inside a guarded scan (``probe``,
        ``point``, ``bathtub`` and ``softCold`` run it under ``_guarded``), or
        follow it with :meth:`EyeScanPort.restore`.
        """
        policy = ResetPolicy(policy)
        port, ctl, hook = self.port, self.control, self.hook
        start = time.monotonic()
        res = ActivationResult(
            status=ScanStatus.ERROR, message='', policy=policy, hookRegistered=hook is not None,
            enablesChanged=False, resetCalled=False, sawFall=False, tFall=None, tReady=None,
            eyeScanEnReadback=0, errDetEnReadback=0, statusBefore=0, statusAfter=0,
            sampleCount=0, elapsed=0.0)
        self._result = res

        def fail(text: str) -> None:
            res.status = ScanStatus.NOT_ENABLED
            res.message = text
            res.elapsed = time.monotonic() - start
            exc = EyeScanNotActive(text)
            exc.result = res
            raise exc

        # The width is decoded before the first write so an unsupported setting changes nothing
        if width is None:
            width = port.bitsPerSample()
        ctl.check()
        if self._snapshot is None:
            port.prime()
        port.write('control', 0)
        res.statusBefore = port.read('controlStatus')
        res.enablesChanged = not (port.read('eyeScanEn') == 1 and port.read('errDetEn') == 1)
        if policy is not ResetPolicy.Never and hook is None:
            fail(f'cannot reset the RX before the scan with policy {policy.value}: {_NO_HOOK}')
        port.write('errDetEn', 1)
        port.write('eyeScanEn', 1)

        def reset() -> None:
            # The timing fields describe the last reset
            res.resetCalled = True
            res.resets += 1
            res.sawFall, res.tFall, res.tReady = False, None, None
            try:
                self._handshake(hook, res)
            except EyeScanNotActive as exc:
                fail(str(exc))

        def rearm() -> None:
            # Clearing and setting both enables draws the alignment afresh, which a reset may never do
            res.rearms += 1
            try:
                port.write('eyeScanEn', 0)
                port.write('errDetEn', 0)
                ctl.sleep(REARM_WAIT)
            finally:
                port.write('errDetEn', 1)
                port.write('eyeScanEn', 1)

        if policy is ResetPolicy.Never:
            note = 'RX reset not requested (policy Never)'
        else:
            note = f'RX reset hook called ({hook.description})'
            reset()

        res.eyeScanEnReadback = port.read('eyeScanEn')
        res.errDetEnReadback = port.read('errDetEn')
        if not (res.eyeScanEnReadback and res.errDetEnReadback):
            fail(f'ES_EYE_SCAN_EN reads {res.eyeScanEnReadback} and ES_ERRDET_EN reads '
                 f'{res.errDetEnReadback} after being set; {note}')

        while True:
            self._prepareProbe(width)
            status, samples, errors = self._runProbe(probeWindow)
            res.statusAfter = status
            res.sampleCount = samples
            if status != STATUS_END or samples == 0:
                seen = ('END with es_sample_count 0' if status == STATUS_END
                        else f'es_control_status stayed {decodeControlStatus(status)} (0x{status:X})')
                fail(f'eye-scan sampler not active: {seen} for {probeWindow:g} s with RUN set; '
                     f'ES_EYE_SCAN_EN={res.eyeScanEnReadback} ES_ERRDET_EN={res.errDetEnReadback}; {note}')
            # The eye centre of a working link is clean and its run ends with a full sample counter. A full
            # error counter there means the offset samples do not follow the data samples (the sampler is
            # out of step), which a retry can realign; a run that ended short of a full sample counter
            # was cut short by something else and is treated the same way
            if errors < _RUN_ERRORS and samples >= _RUN_SAMPLES:
                break
            if errors >= _RUN_ERRORS:
                seen = f'the eye-centre error counter is full ({errors} errors in {samples} samples): {_TWO_CAUSES}'
            else:
                seen = (f'the eye-centre run ended at {samples} of {_RUN_SAMPLES} samples ({errors} errors): '
                        f'{_TWO_CAUSES}')
            if policy is ResetPolicy.Never:
                res.syncWarning = (f'{seen}; policy Never does not reset the RX to realign it, so the scan '
                                   f'continues and reports what it measures')
                break
            if res.resets >= SYNC_RESETS:
                res.syncWarning = (f'{seen}, after each of {res.resets} RX resets ({hook.description}); '
                                   f'the enables were cleared and set again before {res.rearms} of them, '
                                   f'so the scan continues and reports what it measures')
                break
            ctl.check()
            # A plain reset flips the alignment on most lanes; once one has not, re-arm before each reset
            if res.resets >= 2:
                rearm()
            reset()
        ctl.check()
        res.status = ScanStatus.OK
        res.message = f'sampler active: END with {samples} samples'
        if res.resets > 1:
            res.message += f' after {res.resets} RX resets'
        if res.rearms:
            res.message += f', {res.rearms} of them after clearing and setting the enables'
        res.elapsed = time.monotonic() - start
        return res

    def probe(self, policy: ResetPolicy = ResetPolicy.Auto,
              probeWindow: float = PROBE_WINDOW) -> ActivationResult:
        """Activate the sampler only, then restore the registers.

        Never raises for a scan failure: the result carries a typed status. A
        sync warning (the eye-centre run stayed out of step) makes the status
        ``CLOSED`` and is part of the message. After a clean activation the
        probe also runs the sampler at the two ends of the UI, ``+half`` and
        then ``-half`` (the second only when the first counted no errors): a
        live link shows its data transitions there, so no errors at both ends
        is a sync warning too, and an edge run that does not reach END with
        samples ends the probe ``NOT_ENABLED``.

        Parameters
        ----------
        policy : ResetPolicy
            Whether the RX reset hook is called before the sampler is armed.
        probeWindow : float
            Seconds the sampler gets to reach END.

        Returns
        -------
        ActivationResult
            Typed status, message, reset and enable bookkeeping, sample count
            and elapsed time in seconds.
        """
        start = time.monotonic()
        self._result = None
        self._phase = None
        def body() -> ActivationResult:
            activation = self.ensureActive(policy, probeWindow)
            if not activation.syncWarning:
                self._edgeCheck(activation, probeWindow)
            return activation

        value, error, restoreError = self._guarded(body)
        res = value or getattr(error, 'result', None) or self._result
        if res is None:
            res = ActivationResult(
                status=ScanStatus.ERROR, message='', policy=ResetPolicy(policy),
                hookRegistered=self.hook is not None, enablesChanged=False, resetCalled=False,
                sawFall=False, tFall=None, tReady=None, eyeScanEnReadback=0, errDetEnReadback=0,
                statusBefore=0, statusAfter=0, sampleCount=0, elapsed=0.0)
        if value is not None and error is None and res.syncWarning:
            res.status = ScanStatus.CLOSED
            res.message = self._withSyncWarning(res.message, res)
        res.status, res.message = _settle(res.status, res.message, error, restoreError)
        res.elapsed = time.monotonic() - start
        return res

    def _edgeCheck(self, res: ActivationResult, probeWindow: float, *, strict: bool = True) -> None:
        """Run the sampler at the two ends of the UI of an activated lane and look for data transitions.

        A live link counts errors at ``+half`` and ``-half``, where the offset
        sampler sits on the data transitions. The run at ``+half`` comes first
        and the one at ``-half`` only when it counted no errors; zero errors at
        both sets ``res.syncWarning``.

        Parameters
        ----------
        res : ActivationResult
            Result of a clean activation; its ``syncWarning`` is set when no
            transitions are seen.
        probeWindow : float
            Seconds each run has to reach END.
        strict : bool, optional
            True (the probe) ends the check on an edge run that does not reach
            END or counts no samples. False (the scans) returns at once
            without a warning and without touching the status, so the scan
            leaves such a run to its own points, where it is a link drop or a
            timeout.

        Raises
        ------
        EyeScanNotActive
            If ``strict`` and an edge run does not reach END or counts no
            samples; ``res`` carries the status and message and is attached as
            ``exc.result``. The non-strict form never raises it.
        """
        try:
            half = self.port.horzHalfRange()
        except EyeScanError:
            return
        samplesSeen = []
        for horz in (half, -half):
            self.port.write('horzOffset', self._horzWord(horz))
            status, samples, errors = self._runProbe(probeWindow)
            if status != STATUS_END or samples == 0:
                if not strict:
                    return
                seen = ('END with es_sample_count 0' if status == STATUS_END
                        else f'es_control_status stayed {decodeControlStatus(status)} (0x{status:X})')
                text = (f'eye-scan sampler not active at count {horz} (eye edge): {seen} for {probeWindow:g} s '
                        f'with RUN set; ES_EYE_SCAN_EN={res.eyeScanEnReadback} ES_ERRDET_EN={res.errDetEnReadback}')
                res.status = ScanStatus.NOT_ENABLED
                res.message = text
                exc = EyeScanNotActive(text)
                exc.result = res
                raise exc
            if errors > 0:
                return
            samplesSeen.append(samples)
        res.syncWarning = f'{_noTransitions(half)} ({samplesSeen[0]} and {samplesSeen[1]} samples)'

    def softCold(self, probeWindow: float = PROBE_WINDOW) -> SoftColdResult:
        """Return the sampler to the cold state and prove it stopped.

        Clears both enables, pulses the RX reset hook, and runs a probe that
        must not reach END with samples. The registers a scan changes are
        restored; the enables stay 0.

        Parameters
        ----------
        probeWindow : float
            Seconds the proving probe may wait for END.

        Returns
        -------
        SoftColdResult
            Whether the sampler stopped, its message, enable readbacks, final
            status, sample count and elapsed time in seconds.

        Raises
        ------
        EyeScanError
            If no hook is registered (nothing is written) or a bounded wait
            failed.
        """
        hook = self.hook
        if hook is None:
            raise EyeScanError(f'soft re-cold needs the RX reset: {_NO_HOOK}')
        port = self.port
        start = time.monotonic()
        self._phase = None
        width = port.bitsPerSample()
        out = SimpleNamespace(sawFall=False, tFall=None, tReady=None)

        def body() -> SoftColdResult:
            port.write('control', 0)
            port.write('eyeScanEn', 0)
            port.write('errDetEn', 0)
            try:
                self._handshake(hook, out)
            except EyeScanNotActive as exc:
                raise EyeScanError(f'soft re-cold could not confirm the RX reset: {exc}') from exc
            self._prepareProbe(width)
            status, samples, _ = self._runProbe(probeWindow)
            stopped = not (status == STATUS_END and samples > 0)
            en, det = port.read('eyeScanEn'), port.read('errDetEn')
            seen = f'{decodeControlStatus(status)} (0x{status:X}) with {samples} samples'
            return SoftColdResult(
                stopped=stopped,
                message=('sampler stopped: ' if stopped else 'sampler still active: ') + seen,
                eyeScanEn=en, errDetEn=det, statusAfter=status, sampleCount=samples,
                sawFall=out.sawFall, tFall=out.tFall, tReady=out.tReady,
                elapsed=0.0)

        value, error, restoreError = self._guarded(body)
        if error is not None and restoreError is not None:
            _, text = _classify(restoreError)
            raise EyeScanError(f'restore failed: {text}; soft re-cold ended: {error}') from error
        if error is not None:
            raise error
        if restoreError is not None:
            raise restoreError
        value.elapsed = time.monotonic() - start
        return value

    def runOnce(self, prescale: int, deadline: float, width: int) -> tuple[int, int]:
        """Run the sampler once and return ``(errors, bits)``.

        The run ends at END or, when ``deadline`` (a ``time.monotonic`` value)
        passes first, by clearing RUN: the counters stay valid and the bit
        count is taken from the samples actually counted.

        Parameters
        ----------
        prescale : int
            Raw prescale value written before the run.
        deadline : float
            ``time.monotonic`` time in seconds at which the run is stopped.
        width : int
            Internal data width in bits.

        Returns
        -------
        tuple of int
            ``(errors, bits)``: the error count and the number of bits
            actually observed.

        Raises
        ------
        EyeScanTimeout
            If the run produced no samples or the sampler did not return to idle.
            A run that reached END by itself with no samples raises a private
            subclass, which the scans count as a link drop.
        """
        port, ctl = self.port, self.control
        port.write('prescale', prescale, verify=False)
        port.write('control', 1, verify=False)
        started = time.monotonic()
        ended = False
        while True:
            ctl.check()
            status = port.read('controlStatus')
            if status == STATUS_END:
                ended = True
                break
            now = time.monotonic()
            if now >= deadline:
                # RUN=0 takes COUNT to END and then WAIT with the counters intact
                port.write('control', 0, verify=False)
                status = port.waitStatus((STATUS_END, STATUS_WAIT, STATUS_OFF), sleep=ctl.sleep)
                break
            ctl.sleep(min(_SLICE, max(0.0005, (now - started) / 20)))
        errors = port.read('errorCount')
        samples = port.read('sampleCount')
        port.write('control', 0, verify=False)
        self._waitIdle()
        ctl.check()
        if samples == 0 and ended:
            raise _EmptyRun(
                f'the sampler reached END with no samples at prescale {prescale}: the receiver delivered no data, '
                f'so the link is closed or unlocked')
        if samples == 0:
            raise EyeScanTimeout(
                f'no samples counted in {time.monotonic() - started:.1f} s at prescale {prescale}: '
                f'es_control_status {decodeControlStatus(status)} (0x{status:X})')
        return errors, bitsPerRun(samples, prescale, width)

    def measurePoint(self, horz: int, *, vert: int = 0, floor: float = 1e-9, confidence: float = 0.95,
                     equalizer: str = 'dfe', fixedPrescale: int | None = None,
                     maxTimePerRun: float = MAX_TIME_PER_RUN, width: int) -> PointResult:
        """Measure one position on an already active sampler.

        Climbs the prescale ladder ``LADDER`` then the prescale that can prove
        ``floor`` and stops after the first rung where the summed errors reach
        ``ERROR_STOP`` or the summed bits reach ``bitsNeeded(floor, confidence)``.
        DFE sums UT_SIGN 0 and 1, LPM uses UT_SIGN 0 only. A point with no errors
        is an upper bound and carries NaN as its BER.

        Parameters
        ----------
        horz : int
            Horizontal offset in counts, negative to the left.
        vert : int
            Vertical offset in signed codes; the code written is ``abs(vert)``
            and the negative direction is set only for ``vert < 0``, so a
            vertical offset of 0 is always written positive.
        floor : float
            BER floor to prove.
        confidence : float
            One-sided confidence of the zero-error bound.
        equalizer : str
            ``dfe`` or ``lpm``.
        fixedPrescale : int, optional
            Run exactly this one prescale instead of the ladder.
        maxTimePerRun : float
            Seconds one run may take.
        width : int
            Internal data width in bits.

        Returns
        -------
        PointResult
            Errors and bits per UT_SIGN, the prescale rungs used, the BER (NaN
            for a point without errors), its upper bound and the status.

        Raises
        ------
        ValueError
            If an argument is invalid (raised before any hardware access).
        """
        _checkPointArgs(floor, confidence, equalizer, fixedPrescale, maxTimePerRun)
        vert = int(vert)
        if abs(vert) > self.port.family.vsCodeMax:
            raise ValueError(f'vert {vert} is outside +-{self.port.family.vsCodeMax} codes')
        port, ctl = self.port, self.control
        uts = _UT_SIGNS[equalizer]
        plan = _prescalePlan(floor, confidence, width, fixedPrescale)

        # Phase unification: bit 11 follows the rule fixed at the scan start (see _horzWord)
        port.write('horzOffset', self._horzWord(horz))
        port.write('vsCode', abs(vert))
        port.write('vsNegDir', 1 if vert < 0 else 0)

        errors = [0, 0]
        bits = [0, 0]
        done = []
        needed = bitsNeeded(floor, confidence)
        for prescale in plan:
            ctl.check()
            for ut in uts:
                port.write('vsUtSign', ut)
                e, b = self.runOnce(prescale, time.monotonic() + maxTimePerRun, width)
                errors[ut] += e
                bits[ut] += b
            done.append(prescale)
            if self._rungProgress:
                ctl.progress(len(done), len(plan))
            if sum(errors) >= ERROR_STOP or sum(bits) >= needed:
                break

        berArr, upperArr, boundArr = combineCounts(
            np.array(errors, dtype=np.int64).reshape(2, 1), np.array(bits, dtype=np.int64).reshape(2, 1), confidence)
        return PointResult(
            horz=horz, errors=(errors[0], errors[1]), bits=(bits[0], bits[1]), prescale=done[-1],
            rungs=tuple(done), ber=float(berArr[0]), berUpper=float(upperArr[0]), isBound=bool(boundArr[0]),
            status=ScanStatus.OK,
            message=f'{len(done)} prescale rung(s) {tuple(done)}, {sum(errors)} errors in {sum(bits)} bits',
            vert=vert)

    def point(self, horz: int = 0, *, policy: ResetPolicy = ResetPolicy.Auto, floor: float = 1e-9,
              confidence: float = 0.95, equalizer: str = 'dfe', fixedPrescale: int | None = None,
              maxTimePerRun: float = MAX_TIME_PER_RUN, probeWindow: float = PROBE_WINDOW,
              lineRateGbps: float = 0.0, measureLineRate: bool = False,
              phaseUnification: str | None = None) -> PointResult:
        """Measure one horizontal offset from a cold start to a restored lane.

        Activates the sampler, measures the point and restores every register
        the scan changed, whatever ended the scan. A scan failure is reported in
        the result status, never raised.

        Parameters
        ----------
        lineRateGbps : float
            Line rate in Gb/s; the phase-unification rule ``rate`` needs it.
        measureLineRate : bool
            Accepted for symmetry with the scans; a point has no metadata to
            record a measured rate in, so it never measures one.
        phaseUnification : str, optional
            ``sign`` or ``rate``: how bit 11 of the horizontal offset is chosen
            (see ``EyeScanFamily``); the family's rule when omitted.

        Returns
        -------
        PointResult
            ``ERROR`` when the rule in effect is ``rate`` and ``lineRateGbps``
            is not positive; nothing is written in that case.

        Raises
        ------
        ValueError
            If an argument is invalid or ``horz`` is outside half a UI; nothing
            is written in that case.
        """
        _checkPointArgs(floor, confidence, equalizer, fixedPrescale, maxTimePerRun)
        _checkPhase(phaseUnification)
        policy = ResetPolicy(policy)
        horz = int(horz)
        port = self.port
        params = self._rateParams(lineRateGbps, measureLineRate)
        try:
            # Decoded now, at every scan start, before anything is written
            width = port.bitsPerSample()
            half = port.horzHalfRange()
            self._resolvePhase(phaseUnification, params)
        except Exception as exc:
            return self._failedPoint(horz, *_settle(ScanStatus.OK, '', exc, None))
        if abs(horz) > half:
            raise ValueError(f'horz {horz} is outside +-{half} counts (half a UI)')

        def body() -> PointResult:
            activation = self.ensureActive(policy, probeWindow, width=width)
            result = self.measurePoint(
                horz, floor=floor, confidence=confidence, equalizer=equalizer,
                fixedPrescale=fixedPrescale, maxTimePerRun=maxTimePerRun, width=width)
            self.control.check()
            result.message = self._withSyncWarning(result.message, activation)
            return result

        value, error, restoreError = self._guarded(body)
        status, message = _settle(ScanStatus.OK if value is None else value.status,
                                  '' if value is None else value.message, error, restoreError)
        if value is None or error is not None:
            return self._failedPoint(horz, status, message)
        value.status, value.message = status, message
        return value

    @staticmethod
    def _failedPoint(horz: int, status: ScanStatus, message: str) -> PointResult:
        return PointResult(
            horz=horz, errors=(0, 0), bits=(0, 0), prescale=0, rungs=(), ber=math.nan,
            berUpper=math.nan, isBound=False, status=status, message=message)

    def _recoverLink(self, hook: RxResetHook, width: int, state: Any) -> None:
        """Count a link drop, wait for ready, rewrite the masks and recheck the eye centre and the UI ends.

        The link comes back through a PHY re-init, which draws the alignment of
        the eye-scan sampler afresh (see ``SYNC_RESETS``). The eye-centre run of
        the activation is therefore repeated: a full error counter, or a run
        short of a full sample counter, sets the sync warning of the activation
        so the scan ends ``CLOSED`` with the warning instead of reporting a
        closed eye without one. A clean centre run is followed by the edge runs
        of the activation (see :meth:`_edgeCheck`), because a lane that came
        back static counts no errors anywhere, and the grid may never land on
        the ends of the UI: no transitions at both ends sets the same warning.
        A centre or edge run that does not reach END with samples is left to
        the scan point that follows, where it is the second drop.

        Raises
        ------
        EyeScanUnlocked
            If this is the second drop of the scan or ready did not return
            True within ``hook.timeout``.
        """
        ctl = self.control
        state.drops += 1
        if state.drops >= 2:
            raise EyeScanUnlocked(f'link dropped {state.drops} times during the scan')
        deadline = time.monotonic() + hook.timeout
        while not hook.ready():
            if time.monotonic() >= deadline:
                raise EyeScanUnlocked(
                    f'link did not return within {hook.timeout:g} s after a drop at the scan position')
            ctl.sleep(_POLL)
        ctl.sleep(hook.settle)
        self._prepareProbe(width)
        status, samples, errors = self._runProbe(state.probeWindow)
        if status != STATUS_END or samples == 0:
            return
        activation = state.activation
        if activation is None or activation.syncWarning:
            return
        if errors < _RUN_ERRORS and samples >= _RUN_SAMPLES:
            # A clean centre, as after the activation: a live lane must also show its transitions at the ends
            self._edgeCheck(activation, state.probeWindow, strict=False)
            if activation.syncWarning:
                activation.syncWarning += (' after the link returned from a drop during the scan; '
                                           'the scan continues and reports what it measures')
                self._noteSync(state.params, activation)
            return
        if errors >= _RUN_ERRORS:
            seen = f'the eye-centre error counter is full ({errors} errors in {samples} samples)'
        else:
            seen = f'the eye-centre run ended at {samples} of {_RUN_SAMPLES} samples ({errors} errors)'
        activation.syncWarning = (f'{seen} after the link returned from a drop during the scan: {_TWO_CAUSES}; '
                                  f'the scan continues and reports what it measures')
        self._noteSync(state.params, activation)

    def _finalCheck(self, width: int, state: Any) -> None:
        """Repeat the eye-centre run, and after a clean one the edge runs, once the last point is measured.

        The ready reads around a point catch a drop that outlasts the point,
        not one that falls between two reads: the receiver can lose and regain
        lock inside one point, and the PHY re-init behind that leaves the
        eye-scan sampler out of step for the rest of the scan, so every later
        point counts a full error counter and the scan would end with a closed
        eye and no warning. The centre run of the activation is therefore
        repeated after the last point, under the same criterion as
        :meth:`ensureActive` and :meth:`_recoverLink`, and a clean centre is
        followed by the edge runs. A warning found here sets the sync warning
        of the activation, so the scan ends ``CLOSED`` with every point kept. A
        run that does not reach END with samples adds nothing. Nothing is
        checked when the activation already carries a warning.
        """
        activation = state.activation
        if activation is None or activation.syncWarning:
            return
        self._prepareProbe(width)
        status, samples, errors = self._runProbe(state.probeWindow)
        if status != STATUS_END or samples == 0:
            return
        if errors < _RUN_ERRORS and samples >= _RUN_SAMPLES:
            self._edgeCheck(activation, state.probeWindow, strict=False)
            if not activation.syncWarning:
                return
            seen = f'{activation.syncWarning} after the last point of the scan'
        elif errors >= _RUN_ERRORS:
            seen = (f'the eye-centre error counter is full ({errors} errors in {samples} samples) after the last '
                    f'point of the scan: {_TWO_CAUSES}')
        else:
            seen = (f'the eye-centre run ended at {samples} of {_RUN_SAMPLES} samples ({errors} errors) after the '
                    f'last point of the scan: {_TWO_CAUSES}')
        activation.syncWarning = f'{seen}; {_LATE_DROP}'
        self._noteSync(state.params, activation)

    def _checkedPoint(self, horz: int, width: int, state: Any, *, vert: int = 0, **kw: Any) -> PointResult:
        """Measure one position, discarding and repeating it once after a link drop.

        A ready check before and after the measurement catches a drop, and so
        does a run that reached END with no samples, or timed out while the
        ready signal reads False. The discarded measurement is never kept; the
        drops of the whole scan are counted in ``state`` and the second one
        ends the scan. The recovery repeats the eye-centre run of the
        activation (see :meth:`_recoverLink`). A timeout with ready True is a stuck sampler and ends
        the scan ``TIMEOUT``; without a hook an empty run ends it ``UNLOCKED``.
        """
        hook = self.hook
        if hook is None:
            try:
                return self.measurePoint(horz, vert=vert, width=width, **kw)
            except _EmptyRun as exc:
                raise EyeScanUnlocked(str(exc)) from exc
        stable = hook.ready()
        while True:
            if not stable:
                self._recoverLink(hook, width, state)
            try:
                result = self.measurePoint(horz, vert=vert, width=width, **kw)
            except EyeScanTimeout as exc:
                if not isinstance(exc, _EmptyRun) and hook.ready():
                    raise
                stable = False
                continue
            if hook.ready():
                return result
            stable = False

    @staticmethod
    def _rateParams(lineRateGbps: float, measureLineRate: bool) -> dict:
        """Line-rate entries of the scan parameters: the value, where it came from and the warnings."""
        if lineRateGbps > 0:
            return dict(lineRateGbps=float(lineRateGbps), lineRateSource='set', warnings=[],
                        measureLineRate=False)
        return dict(lineRateGbps=0.0, lineRateSource='undefined', warnings=[],
                    measureLineRate=bool(measureLineRate))

    def _measureRate(self, params: dict, width: int, maxTimePerRun: float) -> None:
        """Measure the line rate with one prescale 8 run at the eye centre when the scan asked for it.

        The rate and its ``measured`` source replace the undefined entries of
        ``params`` and the warning is recorded; nothing is written back to the
        caller's line rate.
        """
        if not params['measureLineRate']:
            return
        port = self.port
        port.write('horzOffset', self._horzWord(0))
        for role in ('vsCode', 'vsNegDir', 'vsUtSign'):
            port.write(role, 0)
        started = time.monotonic()
        try:
            _, bits = self.runOnce(_RATE_PRESCALE, started + maxTimePerRun, width)
        except _EmptyRun as exc:
            raise EyeScanUnlocked(str(exc)) from exc
        elapsed = max(time.monotonic() - started, 1e-9)
        rate = bits / elapsed / 1e9 / SAMPLER_EFFICIENCY
        params.update(lineRateGbps=rate, lineRateSource='measured')
        params['warnings'].append(_RATE_WARNING.format(rate=rate))

    def bathtub(self, *, policy: ResetPolicy = ResetPolicy.Auto, floor: float = 1e-9,
                confidence: float = 0.95, step: int = 1, equalizer: str = 'dfe',
                targetBer: float = 1e-12, fixedPrescale: int | None = None,
                maxTimePerRun: float = MAX_TIME_PER_RUN, probeWindow: float = PROBE_WINDOW,
                lineRateGbps: float = 0.0, measureLineRate: bool = False,
                phaseUnification: str | None = None) -> BathtubResult:
        """Measure the two-sided horizontal bathtub of the lane.

        Activates the sampler, then measures every integer count from
        ``-32 * D`` to ``+32 * D`` (``D`` is the RXOUT_DIV divider) in steps
        of ``step`` and restores every register the scan changed. Each point
        climbs the prescale ladder (see :meth:`measurePoint`). A scan failure
        or stop is reported in the result status and keeps the completed
        points; only invalid arguments raise.

        Parameters
        ----------
        policy : ResetPolicy
            ``Auto`` and ``Always`` reset the RX through the hook on every
            activation (no hook gives ``NOT_ENABLED``); ``Never`` only sets
            the enables.
        floor : float
            BER floor every point must prove, in (0, 1).
        confidence : float
            One-sided confidence of the zero-error bound, in (0, 1).
        step : int
            Spacing of the swept counts, 1 to ``32 * D``; the sweep is
            symmetric about 0 and always contains 0.
        equalizer : str
            ``dfe`` or ``lpm``.
        targetBer : float
            BER the opening is extrapolated to, in (0, 1).
        fixedPrescale : int, optional
            Run exactly this one prescale at every point.
        maxTimePerRun : float
            Seconds one run may take.
        probeWindow : float
            Seconds the activation probe has to reach END.
        lineRateGbps : float
            Line rate in Gb/s, recorded in the metadata with the source ``set``
            and used to weight the progress; 0 means not defined.
        measureLineRate : bool
            With ``lineRateGbps`` 0, measure the rate with one prescale 8 run
            at the eye centre right after the activation; the metadata then
            records the source ``measured`` and a warning that it is less
            accurate than a defined rate.
        phaseUnification : str, optional
            ``sign`` or ``rate``: how bit 11 of the horizontal offset is
            chosen (see ``EyeScanFamily``); the family's rule when omitted.
            The rule ``rate`` needs a positive ``lineRateGbps``.

        Returns
        -------
        BathtubResult
            ``OK`` when at least one position meets ``floor``, ``CLOSED`` when
            none does or when the activation found the lane silent (the
            eye-centre run stayed out of step, or the runs at the two ends of
            the UI, counts ``-half`` and ``+half``, counted no errors, whatever
            the step; a lane that delivers no data; the message and the scan
            warnings name both causes, and the points are kept), otherwise the
            status the scan ended with. The centre and edge runs repeated
            after the last point catch a sampler that a drop shorter than one
            point left out of step unseen, and end the scan ``CLOSED`` with the
            same warning.
            A run that reaches END with no samples is a link drop,
            so the second one ends the scan ``UNLOCKED``. The
            extrapolated opening is only set when both tail fits passed every
            quality gate.
            The status is ``ERROR``, with nothing written, when the rule in
            effect is ``rate`` and ``lineRateGbps`` is not positive.

        Raises
        ------
        ValueError
            If an argument is invalid; nothing is written in that case.
        """
        _checkPointArgs(floor, confidence, equalizer, fixedPrescale, maxTimePerRun)
        _checkPhase(phaseUnification)
        if not 0.0 < targetBer < 1.0:
            raise ValueError(f'targetBer must be in the open interval (0, 1), got {targetBer}')
        step = _checkStep(step)
        policy = ResetPolicy(policy)
        port, ctl, hook = self.port, self.control, self.hook
        wall = datetime.now().astimezone()
        start = time.monotonic()
        params = dict(equalizer=equalizer, floor=floor, confidence=confidence, targetBer=targetBer,
                      step=step, fixedPrescale=fixedPrescale, resetPolicy=policy.value, wall=wall,
                      **self._rateParams(lineRateGbps, measureLineRate))

        try:
            # Decoded now, at every scan start, before anything is written
            width = port.bitsPerSample()
            divider = port.rxOutDiv()
            vsRange = port.read('vsRange')
            self._resolvePhase(phaseUnification, params)
        except Exception as exc:
            status, message = _settle(ScanStatus.OK, '', exc, None)
            return self._assemble([], None, params, None, 0, status, message, start, None, None)
        half = port.family.countsPerHalfUiPerDiv * divider
        if step > half:
            raise ValueError(f'step {step} is larger than half the range of {half} counts')

        info = dict(width=width, divider=divider, half=half, vsRange=vsRange,
                    ladder=list(_prescalePlan(floor, confidence, width, fixedPrescale)))
        counts = [int(c) for c in _gridAxis(half, step)]
        state = SimpleNamespace(drops=0, activation=None, probeWindow=probeWindow, params=params)
        points: list[PointResult] = []
        kw = dict(floor=floor, confidence=confidence, equalizer=equalizer,
                  fixedPrescale=fixedPrescale, maxTimePerRun=maxTimePerRun)

        progress = _Progress(ctl)

        def body() -> None:
            ctl.message('Activating the sampler')
            state.activation = self.ensureActive(policy, probeWindow, width=width)
            if not state.activation.syncWarning:
                self._edgeCheck(state.activation, probeWindow, strict=False)
            self._noteSync(params, state.activation)
            self._measureRate(params, width, maxTimePerRun)
            seconds = pointSeconds(floor, confidence, width, params['lineRateGbps'], fixedPrescale=fixedPrescale,
                                   nUt=len(_UT_SIGNS[equalizer]), maxTimePerRun=maxTimePerRun)
            progress.plan((len(counts), seconds))
            self._rungProgress = False
            try:
                for index, count in enumerate(counts):
                    ctl.check()
                    ctl.message(f'Bathtub position {index + 1} of {len(counts)}, count {count}')
                    points.append(self._checkedPoint(count, width, state, **kw))
                    progress.advance(seconds)
                self._finalCheck(width, state)
            finally:
                self._rungProgress = True

        _, error, restoreError = self._guarded(body)
        activation = state.activation or getattr(error, 'result', None)
        status, message = _settle(ScanStatus.OK, '', error, restoreError)
        return self._assemble(points, 1.0 / (2 * half), params, activation, state.drops,
                              status, message, start, info, hook)

    def _assemble(self, points: list[PointResult], uiPerCount: float | None, params: dict,
                  activation: ActivationResult | None, drops: int, status: ScanStatus,
                  message: str, start: float, info: dict | None, hook: RxResetHook | None) -> BathtubResult:
        """Build the BathtubResult from the completed points."""
        floor, confidence, targetBer = params['floor'], params['confidence'], params['targetBer']
        ui = math.nan if uiPerCount is None else uiPerCount
        n = len(points)
        counts = np.array([p.horz for p in points], dtype=np.int64)
        errors = np.ascontiguousarray(np.array([p.errors for p in points], dtype=np.int64).reshape(n, 2).T)
        bits = np.ascontiguousarray(np.array([p.bits for p in points], dtype=np.int64).reshape(n, 2).T)
        prescale = np.array([p.prescale for p in points], dtype=np.int64)
        try:
            ber, berUpper, isBound = combineCounts(errors, bits, confidence)

            region = openRegion(counts, errors, bits, floor, confidence)
            if region is not None:
                first, last = region
                openingAtFloor = float((counts[last] - counts[first]) * ui)
                centre = (int(counts[first]) + int(counts[last])) / 2.0
            else:
                openingAtFloor = None
                worst = np.where(np.isnan(ber), np.where(np.isnan(berUpper), np.inf, berUpper), ber)
                centre = float(counts[int(np.argmin(worst))]) if n else 0.0

            x = counts * ui
            left, right = counts < centre, counts > centre
            leftFit = fitTail(x[left], errors[:, left], bits[:, left], 'left')
            rightFit = fitTail(x[right], errors[:, right], bits[:, right], 'right')
            opening = None
            if leftFit.ok and rightFit.ok and targetBer < _RHO:
                opening = extrapolatedOpening(leftFit, rightFit, targetBer)
            extrapolated = opening is not None

            half = (info or {}).get('half')
            if status is ScanStatus.OK and region is None:
                status = ScanStatus.CLOSED
                message = 'no position meets the BER floor'
            elif status is ScanStatus.OK and activation is not None and activation.syncWarning:
                status = ScanStatus.CLOSED
                message = f'{n} points measured'
            elif status is ScanStatus.OK and self._silentEnds(counts, errors, bits, half):
                status = ScanStatus.CLOSED
                message = _noTransitions(half)
                params['warnings'].append(message)
            elif status is ScanStatus.OK:
                message = f'{n} points measured'
        except Exception as exc:
            status, message = _analysisFailure(exc, status, message)
            ber = berUpper = np.full(n, np.nan)
            isBound = np.zeros(n, dtype=bool)
            leftFit, rightFit = _failedFit('left'), _failedFit('right')
            openingAtFloor = opening = None
            extrapolated = False
        message = self._withSyncWarning(message, activation)

        info = info or {}
        wall = params.get('wall') or datetime.now().astimezone()
        elapsed = time.monotonic() - start
        meta = dict(
            family=self.port.family.name, hwVerified=self.port.family.hwVerified,
            bitsPerSample=info.get('width'), rxOutDiv=info.get('divider'), horzHalfRange=info.get('half'),
            uiPerCount=uiPerCount, equalizer=params['equalizer'], resetPolicy=params['resetPolicy'],
            floor=floor, confidence=confidence, targetBer=targetBer, step=params['step'],
            fixedPrescale=params['fixedPrescale'], ladder=info.get('ladder'), linkDrops=drops,
            readyAvailable=hook is not None, rxResetHook=hook.description if hook is not None else 'none',
            elapsed=elapsed, vsRange=info.get('vsRange'), timestamp=wall.isoformat(timespec='seconds'),
            stamp=wall.strftime('%Y%m%d_%H%M%S'), lineRateGbps=params['lineRateGbps'],
            lineRateSource=params['lineRateSource'], warnings=list(params['warnings']),
            phaseUnification=params.get('phaseUnification', self.port.family.phaseUnification))

        return BathtubResult(
            horzCounts=counts, errors=errors, bits=bits, prescale=prescale, ber=ber, berUpper=berUpper,
            isBound=isBound, uiPerCount=ui, status=status, message=message, activation=activation,
            linkDrops=drops, leftFit=leftFit, rightFit=rightFit, openingAtFloorUI=openingAtFloor,
            openingAtTargetUI=opening, targetBer=targetBer, extrapolated=extrapolated,
            insufficientData=not extrapolated,
            utComparison=self._utComparison(counts, errors, bits, prescale, params['equalizer']), meta=meta)

    @staticmethod
    def _silentEnds(axis: np.ndarray, errors: np.ndarray, bits: np.ndarray, half: int | None) -> bool:
        """True when both ends of the UI were measured and counted no errors.

        A live link shows its data transitions at counts ``-half`` and ``+half``,
        so an axis that holds both ends, each with bits counted and no error
        on either UT sign, belongs to a lane that delivers no data.

        Parameters
        ----------
        axis : numpy.ndarray
            Signed horizontal counts of the measured positions.
        errors, bits : numpy.ndarray
            Counts of the positions, shape ``(2, n)`` (one row per UT sign).
        half : int, optional
            Counts of half a UI; None when it is not known.

        Returns
        -------
        bool
            Whether the rule fires.
        """
        if half is None or len(axis) < 2 or int(axis[0]) != -half or int(axis[-1]) != half:
            return False
        for i in (0, -1):
            if int(bits[:, i].sum()) <= 0 or int(errors[:, i].sum()) != 0:
                return False
        return True

    @staticmethod
    def _utComparison(counts: np.ndarray, errors: np.ndarray, bits: np.ndarray, prescale: np.ndarray,
                      equalizer: str) -> dict | None:
        """UT_SIGN 0 against 1 at the first position inward from the right edge with errors on both."""
        if equalizer != 'dfe':
            return None
        for i in range(counts.size - 1, -1, -1):
            e0, e1 = int(errors[0, i]), int(errors[1, i])
            b0, b1 = int(bits[0, i]), int(bits[1, i])
            total = e0 + e1
            if e0 > 0 and e1 > 0 and total >= UT_COMPARE_ERRORS and total < UT_COMPARE_BER_MAX * (b0 + b1):
                return dict(horz=int(counts[i]), errors0=e0, bits0=b0, errors1=e1, bits1=b1,
                            ber0=e0 / b0, ber1=e1 / b1, prescale=int(prescale[i]))
        return None

    def eye(self, *, policy: ResetPolicy = ResetPolicy.Auto, floor: float = 1e-6, confidence: float = 0.95,
            horzStep: int = 2, vertStep: int = 4, horzRange: int | None = None, vertRange: int | None = None,
            equalizer: str = 'dfe', fixedPrescale: int | None = None,
            maxTimePerRun: float = MAX_TIME_PER_RUN, probeWindow: float = PROBE_WINDOW,
            lineRateGbps: float = 0.0, measureLineRate: bool = False,
            phaseUnification: str | None = None) -> EyeResult:
        """Measure the two-dimensional statistical eye of the lane.

        Activates the sampler once, then measures every position of the grid
        and restores every register the scan changed. Rows are measured
        centre-out (vertical 0 first, then -s, +s, -2s, +2s and so on) and
        columns ascending within a row, so a stopped scan leaves a contiguous
        band of complete rows around vertical 0. Each position climbs the
        prescale ladder (see :meth:`measurePoint`). A scan failure or stop is
        reported in the result status and keeps the completed positions; only
        invalid arguments raise.

        Parameters
        ----------
        policy : ResetPolicy
            ``Auto`` and ``Always`` reset the RX through the hook on every
            activation (no hook gives ``NOT_ENABLED``); ``Never`` only sets
            the enables.
        floor : float
            BER floor every position must prove, in (0, 1).
        confidence : float
            One-sided confidence of the zero-error bound, in (0, 1).
        horzStep : int
            Spacing of the horizontal counts, 1 to ``horzRange``.
        vertStep : int
            Spacing of the vertical codes, 1 to ``vertRange``.
        horzRange : int, optional
            Largest horizontal offset in counts, at most ``32 * D`` for the
            RXOUT_DIV divider ``D``; the full range when omitted.
        vertRange : int, optional
            Largest vertical offset in codes, at most the family's largest
            code; the full range when omitted.
        equalizer : str
            ``dfe`` or ``lpm``.
        fixedPrescale : int, optional
            Run exactly this one prescale at every position.
        maxTimePerRun : float
            Seconds one run may take.
        probeWindow : float
            Seconds the activation probe has to reach END.
        lineRateGbps : float
            Line rate in Gb/s, recorded in the metadata with the source ``set``
            and used to weight the progress; 0 means not defined.
        measureLineRate : bool
            With ``lineRateGbps`` 0, measure the rate with one prescale 8 run
            at the eye centre right after the activation; the metadata then
            records the source ``measured`` and a warning that it is less
            accurate than a defined rate.
        phaseUnification : str, optional
            ``sign`` or ``rate``: how bit 11 of the horizontal offset is
            chosen (see ``EyeScanFamily``); the family's rule when omitted.
            The rule ``rate`` needs a positive ``lineRateGbps``.

        Returns
        -------
        EyeResult
            ``OK`` when the vertical-0 row has an open run at ``floor``,
            ``CLOSED`` when it has none or when the activation found the lane
            silent (the eye-centre run stayed out of step, or the runs at the
            two ends of the UI, counts ``-half`` and ``+half``, counted no
            errors, whatever the steps and ranges; the message and the scan
            warnings name both causes and the measured points are kept),
            otherwise the status the scan ended with. The centre and edge runs repeated
            after the last point catch a sampler that a drop shorter than one
            point left out of step unseen, and end the scan ``CLOSED`` with the
            same warning.
            The status is ``ERROR``, with nothing written, when the rule in
            effect is ``rate`` and ``lineRateGbps`` is not positive.

        Raises
        ------
        ValueError
            If an argument is invalid; nothing is written in that case.
        """
        _checkPointArgs(floor, confidence, equalizer, fixedPrescale, maxTimePerRun)
        _checkPhase(phaseUnification)
        horzStep = _checkStep(horzStep)
        vertStep = _checkStep(vertStep)
        horzRange = _checkRange('horzRange', horzRange)
        vertRange = _checkRange('vertRange', vertRange)
        policy = ResetPolicy(policy)
        port, hook = self.port, self.hook
        wall = datetime.now().astimezone()
        start = time.monotonic()
        params = dict(equalizer=equalizer, floor=floor, confidence=confidence, horzStep=horzStep,
                      vertStep=vertStep, horzRange=horzRange, vertRange=vertRange,
                      fixedPrescale=fixedPrescale, resetPolicy=policy.value,
                      **self._rateParams(lineRateGbps, measureLineRate))
        empty = np.zeros(0, dtype=np.int64)

        try:
            # Decoded now, at every scan start, before anything is written
            width = port.bitsPerSample()
            divider = port.rxOutDiv()
            vsRange = port.read('vsRange')
            self._resolvePhase(phaseUnification, params)
        except Exception as exc:
            status, message = _settle(ScanStatus.OK, '', exc, None)
            return self._assembleEye(empty, empty, np.zeros((2, 0, 0), dtype=np.int64),
                                     np.zeros((2, 0, 0), dtype=np.int64), np.zeros((0, 0), dtype=np.int64),
                                     params, None, 0, status, message, start, wall, None, hook)
        half = port.family.countsPerHalfUiPerDiv * divider
        horzRange, vertRange = _resolveRanges(half, port.family.vsCodeMax, horzStep, vertStep,
                                              horzRange, vertRange)
        params['horzRange'], params['vertRange'] = horzRange, vertRange
        info = dict(width=width, divider=divider, half=half, vsRange=vsRange,
                    ladder=list(_prescalePlan(floor, confidence, width, fixedPrescale)))

        horzAxis = _gridAxis(horzRange, horzStep)
        vertAxis = _gridAxis(vertRange, vertStep)
        order = np.argsort(np.abs(vertAxis), kind='stable')
        shape = (vertAxis.size, horzAxis.size)
        errors = np.zeros((2,) + shape, dtype=np.int64)
        bits = np.zeros((2,) + shape, dtype=np.int64)
        prescale = np.zeros(shape, dtype=np.int64)
        state = SimpleNamespace(drops=0, activation=None, probeWindow=probeWindow, params=params)
        kw = dict(floor=floor, confidence=confidence, equalizer=equalizer,
                  fixedPrescale=fixedPrescale, maxTimePerRun=maxTimePerRun)
        progress = _Progress(self.control)

        def body() -> None:
            self.control.message('Activating the sampler')
            state.activation = self.ensureActive(policy, probeWindow, width=width)
            if not state.activation.syncWarning:
                self._edgeCheck(state.activation, probeWindow, strict=False)
            self._noteSync(params, state.activation)
            self._measureRate(params, width, maxTimePerRun)
            seconds = pointSeconds(floor, confidence, width, params['lineRateGbps'], fixedPrescale=fixedPrescale,
                                   nUt=len(_UT_SIGNS[equalizer]), maxTimePerRun=maxTimePerRun)
            progress.plan((shape[0] * shape[1], seconds))
            self._rungProgress = False
            try:
                self._raster(width, state, horzAxis, vertAxis, order, kw, errors, bits, prescale, progress, seconds)
                self._finalCheck(width, state)
            finally:
                self._rungProgress = True

        _, error, restoreError = self._guarded(body)
        activation = state.activation or getattr(error, 'result', None)
        status, message = _settle(ScanStatus.OK, '', error, restoreError)
        return self._assembleEye(horzAxis, vertAxis, errors, bits, prescale, params, activation,
                                 state.drops, status, message, start, wall, info, hook)

    def _raster(self, width: int, state: Any, horzAxis: np.ndarray, vertAxis: np.ndarray, order: np.ndarray,
                kw: dict, errors: np.ndarray, bits: np.ndarray, prescale: np.ndarray,
                progress: _Progress, seconds: float) -> None:
        """Measure every grid position, rows in ``order`` and columns ascending, into the arrays."""
        ctl = self.control
        for rowNumber, row in enumerate(order):
            ctl.message(f'Eye row {rowNumber + 1} of {order.size}, vertical code {int(vertAxis[row])}')
            for col, count in enumerate(horzAxis):
                ctl.check()
                point = self._checkedPoint(int(count), width, state, vert=int(vertAxis[row]), **kw)
                errors[:, row, col] = point.errors
                bits[:, row, col] = point.bits
                prescale[row, col] = point.prescale
                progress.advance(seconds)

    def _assembleEye(self, horzAxis: np.ndarray, vertAxis: np.ndarray, errors: np.ndarray, bits: np.ndarray,
                     prescale: np.ndarray, params: dict, activation: ActivationResult | None, drops: int,
                     status: ScanStatus, message: str, start: float, wall: datetime, info: dict | None,
                     hook: RxResetHook | None) -> EyeResult:
        """Build the EyeResult from the counts of the completed positions."""
        floor, confidence = params['floor'], params['confidence']
        shape = prescale.shape
        info = info or {}
        half = info.get('half')
        ui = math.nan if half is None else 1.0 / (2 * half)
        measured = bits.sum(axis=0) > 0
        centre = None
        try:
            flatBer, flatUpper, flatBound = combineCounts(
                errors.reshape(2, -1), bits.reshape(2, -1), confidence)
            ber, berUpper, isBound = flatBer.reshape(shape), flatUpper.reshape(shape), flatBound.reshape(shape)
            isOpen = measured & (berUpper <= floor)
            if status is ScanStatus.OK:
                row = int(np.flatnonzero(vertAxis == 0)[0])
                region = openRegion(horzAxis, errors[:, row, :], bits[:, row, :], floor, confidence)
                if region is None:
                    status = ScanStatus.CLOSED
                    message = 'no position on the vertical-0 row meets the BER floor'
                else:
                    message = f'{int(measured.sum())} points measured'
                    centre = self._eyeCentre(horzAxis, vertAxis, errors, bits, isOpen, region, floor, confidence,
                                             ui)
                    if activation is not None and activation.syncWarning:
                        status = ScanStatus.CLOSED
                    elif self._silentEnds(horzAxis, errors[:, row, :], bits[:, row, :], half):
                        status = ScanStatus.CLOSED
                        message = _noTransitions(half)
                        params['warnings'].append(message)
        except Exception as exc:
            status, message = _analysisFailure(exc, status, message)
            ber = berUpper = np.full(shape, np.nan)
            isBound = np.zeros(shape, dtype=bool)
            isOpen = np.zeros(shape, dtype=bool)
            centre = None
        message = self._withSyncWarning(message, activation)
        elapsed = time.monotonic() - start
        meta = dict(
            family=self.port.family.name, hwVerified=self.port.family.hwVerified,
            bitsPerSample=info.get('width'), rxOutDiv=info.get('divider'), horzHalfRange=half,
            uiPerCount=None if half is None else ui, vsRange=info.get('vsRange'),
            vsCodeMax=self.port.family.vsCodeMax, equalizer=params['equalizer'],
            resetPolicy=params['resetPolicy'], floor=floor, confidence=confidence,
            horzStep=params['horzStep'], vertStep=params['vertStep'], horzRange=params['horzRange'],
            vertRange=params['vertRange'], fixedPrescale=params['fixedPrescale'], ladder=info.get('ladder'),
            linkDrops=drops, readyAvailable=hook is not None,
            rxResetHook=hook.description if hook is not None else 'none',
            pointsTotal=int(prescale.size), pointsMeasured=int(measured.sum()), elapsed=elapsed,
            timestamp=wall.isoformat(timespec='seconds'), stamp=wall.strftime('%Y%m%d_%H%M%S'),
            lineRateGbps=params['lineRateGbps'], lineRateSource=params['lineRateSource'],
            warnings=list(params['warnings']),
            phaseUnification=params.get('phaseUnification', self.port.family.phaseUnification))

        return EyeResult(
            horzAxis=horzAxis, vertAxis=vertAxis, errors=errors, bits=bits, prescale=prescale, ber=ber,
            berUpper=berUpper, isBound=isBound, open=isOpen, measured=measured, uiPerCount=ui,
            status=status, message=message, activation=activation, linkDrops=drops, meta=meta,
            centre=centre)

    @staticmethod
    def _eyeCentre(horzAxis: np.ndarray, vertAxis: np.ndarray, errors: np.ndarray, bits: np.ndarray,
                   isOpen: np.ndarray, region: tuple[int, int], floor: float, confidence: float,
                   ui: float) -> EyeCentre | None:
        """Locate the eye centre from the open run of the vertical-0 row.

        The horizontal centre is the midpoint of ``region``; the column is the
        grid column nearest to it and the vertical centre is the midpoint of
        the open run of that column. Ties between grid positions go toward 0.
        """
        def nearest(axis: np.ndarray, value: float) -> int:
            distance = np.abs(axis - value)
            candidates = np.flatnonzero(distance == distance.min())
            return int(candidates[np.argmin(np.abs(axis[candidates]))])

        first, last = region
        horz = (int(horzAxis[first]) + int(horzAxis[last])) / 2.0
        column = nearest(horzAxis, horz)
        vertRegion = openRegion(vertAxis, errors[:, :, column], bits[:, :, column], floor, confidence)
        if vertRegion is None:
            return None
        low, high = vertRegion
        vert = (int(vertAxis[low]) + int(vertAxis[high])) / 2.0
        row = nearest(vertAxis, vert)

        left = right = column
        while left > 0 and isOpen[row, left - 1]:
            left -= 1
        while right < horzAxis.size - 1 and isOpen[row, right + 1]:
            right += 1
        bottom = top = row
        while bottom > 0 and isOpen[bottom - 1, column]:
            bottom -= 1
        while top < vertAxis.size - 1 and isOpen[top + 1, column]:
            top += 1
        return EyeCentre(
            horz=horz, vert=vert, row=row, column=column, horzRun=(int(first), int(last)),
            vertRun=(int(low), int(high)),
            horzOpeningUI=float((horzAxis[last] - horzAxis[first]) * ui),
            vertOpeningCodes=float(vertAxis[high] - vertAxis[low]),
            clippedH=bool(first == 0 or last == horzAxis.size - 1),
            clippedV=bool(low == 0 or high == vertAxis.size - 1),
            chordLeft=max(0.0, float(horz - horzAxis[left])), chordRight=max(0.0, float(horzAxis[right] - horz)),
            chordBottom=max(0.0, float(vert - vertAxis[bottom])), chordTop=max(0.0, float(vertAxis[top] - vert)),
            offsetUI=float(horz * ui), offsetCodes=vert)

    def margin(self, *, policy: ResetPolicy = ResetPolicy.Auto, floor: float = 1e-6,
               bathtubFloor: float = 1e-9, targetBer: float = 1e-12, confidence: float = 0.95,
               horzStep: int = 2, vertStep: int = 4, horzRange: int | None = None,
               vertRange: int | None = None, equalizer: str = 'dfe', fixedPrescale: int | None = None,
               maxTimePerRun: float = MAX_TIME_PER_RUN, probeWindow: float = PROBE_WINDOW,
               lineRateGbps: float = 0.0, measureLineRate: bool = False,
               phaseUnification: str | None = None) -> MarginResult:
        """Measure the 2D eye and the margin cross of the lane in one sampler activation.

        The sampler is activated once. It measures the eye at ``floor``,
        locates the eye centre, then a horizontal bathtub along the centre row
        and a vertical bathtub along the centre column, both at step 1 and
        driven to ``bathtubFloor``. The cross is taken in the same activation
        as the eye because the opening moves by several counts between RX
        resets. The cross positions are the centre rounded to the nearest
        count and code, exact halves toward 0. Each tail is fitted on the Q
        scale and extrapolated to ``targetBer``. A scan failure or stop is
        reported in the result status and keeps the completed measurements;
        only invalid arguments raise.

        Parameters
        ----------
        policy : ResetPolicy
            ``Auto`` and ``Always`` reset the RX through the hook on the
            activation (no hook gives ``NOT_ENABLED``); ``Never`` only sets
            the enables.
        floor : float
            BER floor of the eye, in (0, 1).
        bathtubFloor : float
            BER floor of the cross bathtubs, in (0, 1).
        targetBer : float
            BER the openings are extrapolated to, in (0, 1).
        confidence : float
            One-sided confidence of the zero-error bound, in (0, 1).
        horzStep, vertStep : int
            Grid spacing of the eye in counts and codes.
        horzRange, vertRange : int, optional
            Largest offset of the eye and of the cross; the full range of the
            lane when omitted.
        equalizer : str
            ``dfe`` or ``lpm``.
        fixedPrescale : int, optional
            Run exactly this one prescale at every position.
        maxTimePerRun : float
            Seconds one run may take.
        probeWindow : float
            Seconds the activation probe has to reach END.
        lineRateGbps : float
            Line rate in Gb/s, recorded in the metadata with the source ``set``
            and used to weight the progress; 0 means not defined.
        measureLineRate : bool
            With ``lineRateGbps`` 0, measure the rate with one prescale 8 run
            at the eye centre right after the activation; the metadata then
            records the source ``measured`` and a warning that it is less
            accurate than a defined rate.
        phaseUnification : str, optional
            ``sign`` or ``rate``: how bit 11 of the horizontal offset is
            chosen (see ``EyeScanFamily``); the family's rule when omitted.
            The rule ``rate`` needs a positive ``lineRateGbps``.

        Returns
        -------
        MarginResult
            ``OK`` when the vertical-0 row of the eye has an open run,
            ``CLOSED`` when it has none (the cross is not measured) or when
            the activation found the lane silent (the eye-centre run stayed
            out of step, or the runs at the two ends of the UI, counts
            ``-half`` and ``+half``, counted no errors, whatever the steps and
            ranges; the cross is still measured and the points are kept),
            otherwise the status the scan ended with. The centre and edge runs repeated
            after the last point catch a sampler that a drop shorter than one
            point left out of step unseen, and end the scan ``CLOSED`` with the
            same warning. An opening is extrapolated only
            when both tail fits of its axis passed every gate and the open run
            does not reach the range limit.
            The status is ``ERROR``, with nothing written, when the rule in
            effect is ``rate`` and ``lineRateGbps`` is not positive.

        Raises
        ------
        ValueError
            If an argument is invalid; nothing is written in that case.
        """
        _checkPointArgs(floor, confidence, equalizer, fixedPrescale, maxTimePerRun)
        _checkPhase(phaseUnification)
        for name, value in (('bathtubFloor', bathtubFloor), ('targetBer', targetBer)):
            if not 0.0 < value < 1.0:
                raise ValueError(f'{name} must be in the open interval (0, 1), got {value}')
        _checkBitCount('bathtubFloor', bathtubFloor, confidence)
        horzStep = _checkStep(horzStep)
        vertStep = _checkStep(vertStep)
        horzRange = _checkRange('horzRange', horzRange)
        vertRange = _checkRange('vertRange', vertRange)
        policy = ResetPolicy(policy)
        port, ctl, hook = self.port, self.control, self.hook
        wall = datetime.now().astimezone()
        start = time.monotonic()
        params = dict(equalizer=equalizer, floor=floor, confidence=confidence, horzStep=horzStep,
                      vertStep=vertStep, horzRange=horzRange, vertRange=vertRange,
                      fixedPrescale=fixedPrescale, resetPolicy=policy.value,
                      bathtubFloor=bathtubFloor, targetBer=targetBer,
                      **self._rateParams(lineRateGbps, measureLineRate))

        try:
            # Decoded now, at every scan start, before anything is written
            width = port.bitsPerSample()
            divider = port.rxOutDiv()
            vsRange = port.read('vsRange')
            self._resolvePhase(phaseUnification, params)
        except Exception as exc:
            status, message = _settle(ScanStatus.OK, '', exc, None)
            empty = np.zeros(0, dtype=np.int64)
            eye = self._assembleEye(empty, empty, np.zeros((2, 0, 0), dtype=np.int64),
                                    np.zeros((2, 0, 0), dtype=np.int64), np.zeros((0, 0), dtype=np.int64),
                                    params, None, 0, status, message, start, wall, None, hook)
            return self._assembleMargin(eye, None, params, None, 0, status, message, start, None)
        half = port.family.countsPerHalfUiPerDiv * divider
        horzRange, vertRange = _resolveRanges(half, port.family.vsCodeMax, horzStep, vertStep,
                                              horzRange, vertRange)
        params['horzRange'], params['vertRange'] = horzRange, vertRange

        horzAxis = _gridAxis(horzRange, horzStep)
        vertAxis = _gridAxis(vertRange, vertStep)
        horzCross = _gridAxis(horzRange, 1)
        vertCross = _gridAxis(vertRange, 1)
        order = np.argsort(np.abs(vertAxis), kind='stable')
        shape = (vertAxis.size, horzAxis.size)
        errors = np.zeros((2,) + shape, dtype=np.int64)
        bits = np.zeros((2,) + shape, dtype=np.int64)
        prescale = np.zeros(shape, dtype=np.int64)
        state = SimpleNamespace(
            drops=0, activation=None, probeWindow=probeWindow, params=params, eye=None, eyeEnd=None, rowVert=None,
            colHorz=None, horzPoints=None, vertPoints=None, horzDone=False, vertDone=False)
        progress = _Progress(ctl)
        kw = dict(floor=floor, confidence=confidence, equalizer=equalizer,
                  fixedPrescale=fixedPrescale, maxTimePerRun=maxTimePerRun)
        kwCross = dict(kw, floor=bathtubFloor)
        info = dict(width=width, divider=divider, half=half, vsRange=vsRange,
                    ladder=list(_prescalePlan(floor, confidence, width, fixedPrescale)),
                    crossLadder=list(_prescalePlan(bathtubFloor, confidence, width, fixedPrescale)))

        def sweep(positions: np.ndarray, points: list, measure: Callable[[int], PointResult], stage: str,
                  seconds: float) -> None:
            for index, position in enumerate(positions):
                ctl.check()
                ctl.message(f'{stage}, position {index + 1} of {positions.size}')
                points.append(measure(int(position)))
                progress.advance(seconds)

        def body() -> None:
            self.control.message('Activating the sampler')
            state.activation = self.ensureActive(policy, probeWindow, width=width)
            if not state.activation.syncWarning:
                self._edgeCheck(state.activation, probeWindow, strict=False)
            self._noteSync(params, state.activation)
            self._measureRate(params, width, maxTimePerRun)
            nUt = len(_UT_SIGNS[equalizer])
            eyeSeconds = pointSeconds(floor, confidence, width, params['lineRateGbps'], fixedPrescale=fixedPrescale,
                                      nUt=nUt, maxTimePerRun=maxTimePerRun)
            crossSeconds = pointSeconds(bathtubFloor, confidence, width, params['lineRateGbps'],
                                        fixedPrescale=fixedPrescale, nUt=nUt, maxTimePerRun=maxTimePerRun)
            progress.plan((shape[0] * shape[1], eyeSeconds), (horzCross.size + vertCross.size, crossSeconds))
            self._rungProgress = False
            try:
                self._raster(width, state, horzAxis, vertAxis, order, kw, errors, bits, prescale, progress,
                             eyeSeconds)
                state.eyeEnd = time.monotonic()
                state.eye = self._assembleEye(horzAxis, vertAxis, errors, bits, prescale, params,
                                              state.activation, state.drops, ScanStatus.OK, '', start,
                                              wall, info, hook)
                centre = state.eye.centre
                if centre is None:
                    self._finalCheck(width, state)
                    return
                state.rowVert = nearestTowardZero(centre.vert)
                state.colHorz = nearestTowardZero(centre.horz)
                state.horzPoints = []
                sweep(horzCross, state.horzPoints,
                      lambda pos: self._checkedPoint(pos, width, state, vert=state.rowVert, **kwCross),
                      f'Horizontal cross at vertical code {state.rowVert}', crossSeconds)
                state.horzDone = True
                state.vertPoints = []
                sweep(vertCross, state.vertPoints,
                      lambda pos: self._checkedPoint(state.colHorz, width, state, vert=pos, **kwCross),
                      f'Vertical cross at horizontal count {state.colHorz}', crossSeconds)
                state.vertDone = True
                self._finalCheck(width, state)
            finally:
                self._rungProgress = True

        _, error, restoreError = self._guarded(body)
        activation = state.activation or getattr(error, 'result', None)
        status, message = _settle(ScanStatus.OK, '', error, restoreError)
        eye = state.eye
        if eye is None:
            eye = self._assembleEye(horzAxis, vertAxis, errors, bits, prescale, params, activation,
                                    state.drops, status, message, start, wall, info, hook)
        return self._assembleMargin(eye, state, params, activation, state.drops, status, message, start, info)

    @staticmethod
    def _assembleSweep(axis: str, points: list[PointResult], fixed: int, scale: float, floor: float,
                       confidence: float, targetBer: float, complete: bool) -> SweepResult:
        """Build a SweepResult from the measured points of one cross sweep.

        An incomplete sweep keeps its counts but is never fitted and has no
        opening. An opening is extrapolated only when both tails passed the fit
        gates, the open run does not reach either end of the sweep and the
        sweep is open at ``floor``.
        """
        n = len(points)
        positions = np.array([p.horz if axis == 'horz' else p.vert for p in points], dtype=np.int64)
        errors = np.ascontiguousarray(np.array([p.errors for p in points], dtype=np.int64).reshape(n, 2).T)
        bits = np.ascontiguousarray(np.array([p.bits for p in points], dtype=np.int64).reshape(n, 2).T)
        prescale = np.array([p.prescale for p in points], dtype=np.int64)
        ber, berUpper, isBound = combineCounts(errors, bits, confidence)

        lowFit = highFit = None
        openingAtFloor = opening = None
        clipped = False
        if complete and n:
            region = openRegion(positions, errors, bits, floor, confidence)
            if region is not None:
                first, last = region
                openingAtFloor = float((positions[last] - positions[first]) * scale)
                centre = (int(positions[first]) + int(positions[last])) / 2.0
                clipped = bool(first == 0 or last == n - 1)
            else:
                worst = np.where(np.isnan(ber), np.where(np.isnan(berUpper), np.inf, berUpper), ber)
                centre = float(positions[int(np.argmin(worst))])
            x = positions * scale
            low, high = positions < centre, positions > centre
            lowFit = fitTail(x[low], errors[:, low], bits[:, low], 'left')
            highFit = fitTail(x[high], errors[:, high], bits[:, high], 'right')
            if lowFit.ok and highFit.ok and region is not None and not clipped and targetBer < _RHO:
                opening = extrapolatedOpening(lowFit, highFit, targetBer)
        extrapolated = opening is not None
        return SweepResult(
            axis=axis, positions=positions, fixed=int(fixed), errors=errors, bits=bits, prescale=prescale,
            ber=ber, berUpper=berUpper, isBound=isBound, scale=scale, floor=floor, lowFit=lowFit,
            highFit=highFit, openingAtFloor=openingAtFloor, openingAtTarget=opening, targetBer=targetBer,
            extrapolated=extrapolated, insufficientData=not extrapolated, clipped=clipped, complete=complete)

    @staticmethod
    def _failedSweep(axis: str, points: list[PointResult], fixed: int, scale: float, floor: float,
                     targetBer: float) -> SweepResult:
        """The counts of one cross sweep whose analysis raised, without any analysis."""
        n = len(points)
        positions = np.array([p.horz if axis == 'horz' else p.vert for p in points], dtype=np.int64)
        errors = np.ascontiguousarray(np.array([p.errors for p in points], dtype=np.int64).reshape(n, 2).T)
        bits = np.ascontiguousarray(np.array([p.bits for p in points], dtype=np.int64).reshape(n, 2).T)
        prescale = np.array([p.prescale for p in points], dtype=np.int64)
        return SweepResult(
            axis=axis, positions=positions, fixed=int(fixed), errors=errors, bits=bits, prescale=prescale,
            ber=np.full(n, np.nan), berUpper=np.full(n, np.nan), isBound=np.zeros(n, dtype=bool), scale=scale,
            floor=floor, lowFit=_failedFit('left'), highFit=_failedFit('right'), openingAtFloor=None,
            openingAtTarget=None, targetBer=targetBer, extrapolated=False, insufficientData=True,
            clipped=False, complete=False)

    def _assembleMargin(self, eye: EyeResult, state: Any, params: dict, activation: ActivationResult | None,
                        drops: int, status: ScanStatus, message: str, start: float,
                        info: dict | None) -> MarginResult:
        """Build the MarginResult from the eye and the cross points measured so far."""
        floor, confidence = params['bathtubFloor'], params['confidence']
        horz = vert = None
        scanStatus, scanMessage = status, message
        try:
            if state is not None and state.horzPoints is not None:
                horz = self._assembleSweep('horz', state.horzPoints, state.rowVert, eye.uiPerCount, floor,
                                           confidence, params['targetBer'], state.horzDone)
            if state is not None and state.vertPoints is not None:
                vert = self._assembleSweep('vert', state.vertPoints, state.colHorz, 1.0, floor,
                                           confidence, params['targetBer'], state.vertDone)
            if status is ScanStatus.OK:
                status = eye.status
                message = eye.message
                if status is ScanStatus.OK and activation is not None and activation.syncWarning:
                    status = ScanStatus.CLOSED
                if status is ScanStatus.OK and horz is not None and vert is not None:
                    message = (f'{int(eye.measured.sum())} eye points, {horz.positions.size} horizontal and '
                               f'{vert.positions.size} vertical cross points measured')
            message = self._withSyncWarning(message, activation)
            summary = self._marginSummary(eye, horz, vert, params, status, message)
        except Exception as exc:
            status, message = _analysisFailure(exc, scanStatus, scanMessage)
            message = self._withSyncWarning(message, activation)
            horz = vert = None
            if state is not None and state.horzPoints is not None:
                horz = self._failedSweep('horz', state.horzPoints, state.rowVert, eye.uiPerCount, floor,
                                         params['targetBer'])
            if state is not None and state.vertPoints is not None:
                vert = self._failedSweep('vert', state.vertPoints, state.colHorz, 1.0, floor, params['targetBer'])
            summary = self._marginSummary(dataclasses.replace(eye, centre=None), None, None, params, status,
                                          message)

        end = time.monotonic()
        eyeEnd = None if state is None else state.eyeEnd
        meta = dict(eye.meta)
        # The eye copied the warnings when the raster ended; a drop during the cross can have added one since
        meta.update(
            warnings=list(params['warnings']),
            bathtubFloor=floor, targetBer=params['targetBer'], crossStep=1,
            rowVert=None if state is None else state.rowVert,
            columnHorz=None if state is None else state.colHorz,
            crossLadder=(info or {}).get('crossLadder'), linkDrops=drops,
            eyeSeconds=None if eyeEnd is None else eyeEnd - start,
            crossSeconds=None if eyeEnd is None else end - eyeEnd,
            elapsed=end - start, note=_MARGIN_NOTE)
        return MarginResult(eye=eye, horz=horz, vert=vert, summary=summary, status=status, message=message,
                            activation=activation, linkDrops=drops, meta=meta)

    @staticmethod
    def _axisOpening(sweep: SweepResult | None, centreClipped: bool) -> dict:
        """Opening, source and flags of one axis from its sweep (None when it was not completed)."""
        if sweep is None or not sweep.complete:
            return dict(opening=None, source=None, atFloor=None, atTarget=None, clipped=centreClipped,
                        extrapolated=False, insufficient=True)
        if sweep.extrapolated:
            opening, source = sweep.openingAtTarget, 'extrapolated'
        elif sweep.openingAtFloor is not None:
            opening, source = sweep.openingAtFloor, 'measured'
        else:
            opening, source = None, 'closed'
        return dict(opening=opening, source=source, atFloor=sweep.openingAtFloor, atTarget=sweep.openingAtTarget,
                    clipped=sweep.clipped, extrapolated=sweep.extrapolated,
                    insufficient=not sweep.extrapolated and source != 'closed')

    @staticmethod
    def _openingText(label: str, axis: dict, unit: str, digits: int, params: dict) -> str:
        """One clause of the summary line for the opening of one axis."""
        value, source = axis['opening'], axis['source']
        if source == 'closed':
            return f'{label} opening none (no position meets BER {params["bathtubFloor"]:g})'
        if value is None:
            return f'{label} opening not available (insufficient data)'
        if source == 'extrapolated':
            return f'{label} opening {value:.{digits}f} {unit} at BER {params["targetBer"]:g} (extrapolated)'
        where = f'at BER {params["bathtubFloor"]:g}'
        if axis['clipped']:
            return f'{label} opening >= {value:.{digits}f} {unit} {where} (measured, clipped, lower bound)'
        return f'{label} opening {value:.{digits}f} {unit} {where} (measured, insufficient data)'

    def _marginSummary(self, eye: EyeResult, horz: SweepResult | None, vert: SweepResult | None,
                       params: dict, status: ScanStatus, message: str) -> MarginSummary:
        """Fill the MarginSummary: centre, openings with their labels, open area, asymmetry and centre BER."""
        centre = eye.centre
        confidence = params['confidence']
        h = self._axisOpening(horz, False if centre is None else centre.clippedH)
        v = self._axisOpening(vert, False if centre is None else centre.clippedV)

        openPoints = area = asymLR = asymTB = None
        berAtCenter = berUpperAtCenter = isBound = None
        berText = formatBer(math.nan, math.nan, False, confidence)
        if centre is not None:
            component = openComponent(eye.open, centre.row, centre.column)
            openPoints = int(component.sum())
            area = float(openPoints * params['horzStep'] * params['vertStep'] * eye.uiPerCount)
            asymLR, asymTB = areaAsymmetry(component, eye.horzAxis, eye.vertAxis, centre.horz, centre.vert)
            at = (centre.row, centre.column)
            ber, upper, bound = eye.ber[at], eye.berUpper[at], eye.isBound[at]
            if horz is not None:
                measured = horz.bits.sum(axis=0) > 0
                index = np.flatnonzero((horz.positions == nearestTowardZero(centre.horz)) & measured)
                if index.size:
                    ber, upper, bound = horz.ber[index[0]], horz.berUpper[index[0]], horz.isBound[index[0]]
            berAtCenter = None if math.isnan(ber) else float(ber)
            berUpperAtCenter = None if math.isnan(upper) else float(upper)
            isBound = bool(bound)
            berText = formatBer(float(ber), float(upper), isBound, confidence)

        if centre is None:
            text = f'{status.value}: {message}'
        else:
            asym = ', '.join(f'{name} {value:+.2f}' if value is not None else f'{name} n/a'
                             for name, value in (('LR', asymLR), ('TB', asymTB)))
            text = (f'{status.value}: {self._openingText("horizontal", h, "UI", 3, params)}; '
                    f'{self._openingText("vertical", v, "codes", 1, params)}; '
                    f'open area {area:.4g} UI x codes ({openPoints} points); '
                    f'centre offset {centre.offsetUI:+.3f} UI, {centre.offsetCodes:+.1f} codes; '
                    f'asymmetry {asym}; centre {berText}')

        return MarginSummary(
            status=status, eyeFloor=params['floor'], bathtubFloor=params['bathtubFloor'],
            targetBer=params['targetBer'], confidence=confidence,
            centreHorzCounts=None if centre is None else centre.horz,
            centreVertCodes=None if centre is None else centre.vert,
            offsetUI=None if centre is None else centre.offsetUI,
            offsetCodes=None if centre is None else centre.offsetCodes,
            horzOpeningUI=h['opening'], horzOpeningSource=h['source'],
            vertOpeningCodes=v['opening'], vertOpeningSource=v['source'],
            horzOpeningAtFloorUI=h['atFloor'], horzOpeningAtTargetUI=h['atTarget'],
            vertOpeningAtFloorCodes=v['atFloor'], vertOpeningAtTargetCodes=v['atTarget'],
            openPoints=openPoints, openAreaUiCodes=area, asymmetryLR=asymLR, asymmetryTB=asymTB,
            chordLeftCounts=None if centre is None else centre.chordLeft,
            chordRightCounts=None if centre is None else centre.chordRight,
            chordBottomCodes=None if centre is None else centre.chordBottom,
            chordTopCodes=None if centre is None else centre.chordTop,
            clippedH=h['clipped'], clippedV=v['clipped'],
            extrapolatedH=h['extrapolated'], extrapolatedV=v['extrapolated'],
            insufficientDataH=h['insufficient'], insufficientDataV=v['insufficient'],
            berAtCenter=berAtCenter, berUpperAtCenter=berUpperAtCenter, isBoundAtCenter=isBound,
            berAtCenterText=berText, text=text)
