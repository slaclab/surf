#-----------------------------------------------------------------------------
# Title      : Eye-scan types
#-----------------------------------------------------------------------------
# Description:
# Enums, exceptions, status decode and result containers shared by the
# statistical eye-scan modules. No pyrogue import so every eye-scan module can
# depend on it without an import cycle.
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

import enum
from dataclasses import dataclass
from typing import Any, Callable

import numpy as np

__all__ = [
    'ScanStatus',
    'ResetPolicy',
    'EyeScanError',
    'EyeScanNotActive',
    'EyeScanAborted',
    'EyeScanTimeout',
    'EyeScanUnlocked',
    'STATUS_NAMES',
    'STATUS_END',
    'STATUS_WAIT',
    'STATUS_OFF',
    'decodeControlStatus',
    'RxResetHook',
    'LaneState',
    'ActivationResult',
    'SoftColdResult',
    'PointResult',
    'BathtubResult',
    'EyeCentre',
    'EyeResult',
    'SweepResult',
    'MarginSummary',
    'MarginResult',
]


class ScanStatus(str, enum.Enum):
    """Outcome of an eye-scan point or run."""

    OK = 'OK'
    CLOSED = 'CLOSED'
    UNLOCKED = 'UNLOCKED'
    NOT_ENABLED = 'NOT_ENABLED'
    TIMEOUT = 'TIMEOUT'
    ABORTED = 'ABORTED'
    ERROR = 'ERROR'


class ResetPolicy(str, enum.Enum):
    """Whether the engine calls the RX reset hook while activating the sampler.

    ``Auto`` (default) and ``Always`` reset the RX on every activation and
    refuse to scan when no hook is registered. ``Never`` only sets the enables.
    """

    Auto = 'Auto'
    Always = 'Always'
    Never = 'Never'


class EyeScanError(Exception):
    """Base class for eye-scan failures."""


class EyeScanNotActive(EyeScanError):
    """The eye-scan sampler did not become active."""


class EyeScanAborted(EyeScanError):
    """The run was stopped by the user."""


class EyeScanTimeout(EyeScanError):
    """A bounded wait expired."""


class EyeScanUnlocked(EyeScanError):
    """The link dropped during the run."""


# es_control_status[3:1] is the state, [0] is done. Only the codes below have been read on hardware
# (KCU1500 GTH and Varium C1100 GTY lanes): WAIT, END and READ always report done set, RESET, COUNT and
# ARMED always report it clear, and 0x0 is the lane whose sampler was never enabled. A state with the
# other value of the done bit (0x4 or 0x7, for example) decodes as UNKNOWN and is never waited for.
STATUS_NAMES = {
    0x0: 'OFF',
    0x1: 'WAIT',
    0x2: 'RESET',
    0x6: 'COUNT',
    0x5: 'END',
    0xA: 'ARMED',
    0x9: 'READ',
}
STATUS_END = 0x5
STATUS_WAIT = 0x1
STATUS_OFF = 0x0


def decodeControlStatus(raw: int) -> str:
    """Return the state name of a raw ``es_control_status`` value.

    Parameters
    ----------
    raw : int
        Raw 4-bit status read from DRP address 0x153 (GTHE3).

    Returns
    -------
    str
        State name, or ``UNKNOWN(0xN)`` for a value outside the known table.
    """
    return STATUS_NAMES.get(raw, f'UNKNOWN(0x{raw:X})')


@dataclass(frozen=True)
class RxResetHook:
    """Normalized RX reset hook registered by an application."""

    pulse: Callable[[], None]
    ready: Callable[[], bool]
    settle: float
    timeout: float
    fallWait: float
    hold: float
    description: str


@dataclass
class LaneState:
    """Read-only snapshot of one lane's eye-scan state."""

    family: str
    eyeScanEn: int
    errDetEn: int
    control: int
    prescale: int
    controlStatus: int
    controlStatusName: str
    errorCount: int
    sampleCount: int
    bitsPerSample: int | None
    widthError: str | None
    rxOutDiv: int | None
    horzHalfRange: int | None
    rxResetHook: str


@dataclass
class ActivationResult:
    """Outcome of bringing the sampler to an active state."""

    status: ScanStatus
    message: str
    policy: ResetPolicy
    hookRegistered: bool
    enablesChanged: bool
    resetCalled: bool
    sawFall: bool
    tFall: float | None
    tReady: float | None
    eyeScanEnReadback: int
    errDetEnReadback: int
    statusBefore: int
    statusAfter: int
    sampleCount: int
    elapsed: float
    # RX reset pulses used, more than one when a reset left the sampler out of step with the data
    resets: int = 0
    # Resets preceded by clearing and setting both enables, which draws the alignment afresh
    rearms: int = 0
    # Warning recorded when the eye-centre run stayed out of step (a full error counter, or fewer samples
    # than a full run) after the reset budget or under policy Never, or when the runs at the two ends of
    # the UI after a clean activation of the probe or of any scan counted no errors; empty when the
    # sampler came in step and showed data transitions
    syncWarning: str = ''


@dataclass
class SoftColdResult:
    """Outcome of the scripted return to the cold (sampler off) state."""

    stopped: bool
    message: str
    eyeScanEn: int
    errDetEn: int
    statusAfter: int
    sampleCount: int
    sawFall: bool
    tFall: float | None
    tReady: float | None
    elapsed: float


@dataclass
class PointResult:
    """One point measured on both UT signs at a horizontal and a vertical offset."""

    horz: int
    errors: tuple[int, int]
    bits: tuple[int, int]
    prescale: int
    rungs: tuple[int, ...]
    ber: float
    berUpper: float
    isBound: bool
    status: ScanStatus
    message: str
    vert: int = 0


@dataclass
class BathtubResult:
    """Horizontal bathtub over the swept counts."""

    horzCounts: np.ndarray
    errors: np.ndarray
    bits: np.ndarray
    prescale: np.ndarray
    ber: np.ndarray
    berUpper: np.ndarray
    isBound: np.ndarray
    uiPerCount: float
    status: ScanStatus
    message: str
    activation: ActivationResult | None
    linkDrops: int
    leftFit: Any
    rightFit: Any
    openingAtFloorUI: float | None
    openingAtTargetUI: float | None
    targetBer: float
    extrapolated: bool
    insufficientData: bool
    utComparison: dict | None
    meta: dict


@dataclass
class EyeCentre:
    """Centre of the open eye and the extents measured from it.

    Horizontal quantities are in counts (``UI`` where named), vertical
    quantities in signed codes. The centre is the midpoint of the open run on
    the vertical-0 row, then the midpoint of the open run on the grid column
    nearest to it, both judged at the eye floor.

    Parameters
    ----------
    horz : float
        Horizontal centre in counts, relative to 0.
    vert : float
        Vertical centre in codes, relative to 0.
    row, column : int
        Grid row and column nearest to the centre (exact halves toward 0).
    horzRun : tuple of int
        First and last column index of the open run on the vertical-0 row.
    vertRun : tuple of int
        First and last row index of the open run on column ``column``.
    horzOpeningUI : float
        Width of the horizontal run at the eye floor in UI.
    vertOpeningCodes : float
        Height of the vertical run at the eye floor in codes.
    clippedH, clippedV : bool
        The run touches the first or last grid position of its axis.
    chordLeft, chordRight : float
        Distance in counts from the centre to the last open point of the
        centre row on each side, 0 when the centre lies outside the chord.
    chordBottom, chordTop : float
        Distance in codes from the centre to the last open point of the
        centre column on each side, 0 when the centre lies outside the chord.
    offsetUI : float
        ``horz`` in UI.
    offsetCodes : float
        ``vert`` in codes.
    """

    horz: float
    vert: float
    row: int
    column: int
    horzRun: tuple[int, int]
    vertRun: tuple[int, int]
    horzOpeningUI: float
    vertOpeningCodes: float
    clippedH: bool
    clippedV: bool
    chordLeft: float
    chordRight: float
    chordBottom: float
    chordTop: float
    offsetUI: float
    offsetCodes: float


@dataclass
class EyeResult:
    """Two-dimensional statistical eye over a grid of horizontal and vertical offsets.

    Every array indexed by position has shape ``(nV, nH)`` (vertical rows
    first); ``errors`` and ``bits`` carry the UT_SIGN 0 and 1 accumulations
    on the leading axis, shape ``(2, nV, nH)``. A position that was not
    reached has no bits: ``measured`` is False, ``ber`` and ``berUpper`` are
    NaN.

    Parameters
    ----------
    horzAxis : numpy.ndarray
        Horizontal offsets in counts, ascending, always containing 0.
    vertAxis : numpy.ndarray
        Vertical offsets in signed codes, ascending, always containing 0.
    errors : numpy.ndarray
        int64 error counts per UT_SIGN.
    bits : numpy.ndarray
        int64 bit counts per UT_SIGN.
    prescale : numpy.ndarray
        Prescale of the last rung of each position.
    ber : numpy.ndarray
        Measured BER, NaN where the position has no errors.
    berUpper : numpy.ndarray
        One-sided upper bound of the BER at the stated confidence.
    isBound : numpy.ndarray
        True where the position saw zero errors.
    open : numpy.ndarray
        True where the position is measured and ``berUpper`` is at or below
        the floor.
    measured : numpy.ndarray
        True where the position observed bits.
    uiPerCount : float
        Unit intervals per horizontal count.
    status : ScanStatus
        ``OK`` when the vertical-0 row has an open run at the floor,
        ``CLOSED`` when it has none, otherwise the status the scan ended with.
    message : str
        Human-readable outcome.
    activation : ActivationResult or None
        Outcome of the sampler activation.
    linkDrops : int
        Link drops handled during the scan.
    meta : dict
        Scan parameters and the lane state they were taken in.
    centre : EyeCentre or None
        Centre of the open eye; None when the vertical-0 row has no open run
        or the scan did not complete.
    """

    horzAxis: np.ndarray
    vertAxis: np.ndarray
    errors: np.ndarray
    bits: np.ndarray
    prescale: np.ndarray
    ber: np.ndarray
    berUpper: np.ndarray
    isBound: np.ndarray
    open: np.ndarray
    measured: np.ndarray
    uiPerCount: float
    status: ScanStatus
    message: str
    activation: ActivationResult | None
    linkDrops: int
    meta: dict
    centre: EyeCentre | None = None


@dataclass
class SweepResult:
    """One step-1 bathtub through the eye centre, horizontal or vertical.

    Parameters
    ----------
    axis : str
        ``'horz'`` (counts, fitted in UI) or ``'vert'`` (codes).
    positions : numpy.ndarray
        Measured positions in counts or codes, ascending.
    fixed : int
        Position of the other axis the sweep was taken at.
    errors, bits : numpy.ndarray
        int64 counts per UT_SIGN, shape ``(2, N)``.
    prescale : numpy.ndarray
        Prescale of the last rung of each position.
    ber, berUpper : numpy.ndarray
        Measured BER (NaN without errors) and its one-sided upper bound.
    isBound : numpy.ndarray
        True where the position saw zero errors.
    scale : float
        Axis units per position: UI per count (horz) or 1.0 (vert).
    floor : float
        BER floor the sweep was driven to.
    lowFit, highFit : TailFit or None
        Q-scale fits of the tails below and above the open run; None for an
        incomplete sweep.
    openingAtFloor : float or None
        Width of the open run at ``floor`` in UI (horz) or codes (vert).
    openingAtTarget : float or None
        Extrapolated opening at ``targetBer`` in the same units; set only
        when both fits passed every gate and the run is not clipped.
    targetBer : float
        BER the opening is extrapolated to.
    extrapolated : bool
        ``openingAtTarget`` is set.
    insufficientData : bool
        No extrapolated opening is available.
    clipped : bool
        The open run reaches the first or last position of the sweep, so
        ``openingAtFloor`` is only a lower bound.
    complete : bool
        Every position of the sweep was measured. An incomplete sweep is never
        fitted and has no opening.
    """

    axis: str
    positions: np.ndarray
    fixed: int
    errors: np.ndarray
    bits: np.ndarray
    prescale: np.ndarray
    ber: np.ndarray
    berUpper: np.ndarray
    isBound: np.ndarray
    scale: float
    floor: float
    lowFit: Any
    highFit: Any
    openingAtFloor: float | None
    openingAtTarget: float | None
    targetBer: float
    extrapolated: bool
    insufficientData: bool
    clipped: bool
    complete: bool


@dataclass
class MarginSummary:
    """Numbers a user acts on, taken from one margin run.

    Horizontal values are in counts or UI, vertical values in codes. An
    opening is ``'extrapolated'`` when it comes from the Q-scale fits at
    ``targetBer``, ``'measured'`` when it is the open run at ``bathtubFloor``
    (a fit failed its gates, or the run is clipped and the value is a lower
    bound) and None when there is no opening. Every field of an axis that
    could not be measured is None and its ``insufficientData`` flag is True.

    Parameters
    ----------
    status : ScanStatus
        Outcome of the run.
    eyeFloor, bathtubFloor, targetBer, confidence : float
        BER floors of the eye and the cross, the extrapolation target and the
        confidence of every bound.
    centreHorzCounts, centreVertCodes : float or None
        Eye centre relative to (0, 0).
    offsetUI, offsetCodes : float or None
        The centre offset in UI and codes.
    horzOpeningUI, vertOpeningCodes : float or None
        Reported opening of each axis.
    horzOpeningSource, vertOpeningSource : str or None
        ``'extrapolated'``, ``'measured'``, ``'closed'`` (a completed cross with
        no position at or below ``bathtubFloor``; the opening is None and the
        insufficient-data flag False) or None.
    horzOpeningAtFloorUI, vertOpeningAtFloorCodes : float or None
        Open run of each cross sweep at ``bathtubFloor``.
    horzOpeningAtTargetUI, vertOpeningAtTargetCodes : float or None
        Extrapolated opening of each axis at ``targetBer``.
    openPoints : int or None
        Points of the 4-connected open component that contains the centre.
    openAreaUiCodes : float or None
        ``openPoints`` times the grid spacing, in UI x codes.
    asymmetryLR, asymmetryTB : float or None
        Open-area asymmetry about the centre, signed in [-1, 1].
    chordLeftCounts, chordRightCounts : float or None
        Chord extents from the centre in counts.
    chordBottomCodes, chordTopCodes : float or None
        Chord extents from the centre in codes.
    clippedH, clippedV : bool
        The open run of that axis reaches the scan range limit, so its
        opening is a lower bound.
    extrapolatedH, extrapolatedV : bool
        The reported opening of that axis is extrapolated.
    insufficientDataH, insufficientDataV : bool
        No extrapolated opening is available for that axis.
    berAtCenter, berUpperAtCenter : float or None
        BER and upper bound at the centre point.
    isBoundAtCenter : bool or None
        The centre point saw zero errors.
    berAtCenterText : str
        The centre BER as text, a bound for a zero-error point.
    text : str
        One-line summary of the run.
    """

    status: ScanStatus
    eyeFloor: float
    bathtubFloor: float
    targetBer: float
    confidence: float
    centreHorzCounts: float | None
    centreVertCodes: float | None
    offsetUI: float | None
    offsetCodes: float | None
    horzOpeningUI: float | None
    horzOpeningSource: str | None
    vertOpeningCodes: float | None
    vertOpeningSource: str | None
    horzOpeningAtFloorUI: float | None
    horzOpeningAtTargetUI: float | None
    vertOpeningAtFloorCodes: float | None
    vertOpeningAtTargetCodes: float | None
    openPoints: int | None
    openAreaUiCodes: float | None
    asymmetryLR: float | None
    asymmetryTB: float | None
    chordLeftCounts: float | None
    chordRightCounts: float | None
    chordBottomCodes: float | None
    chordTopCodes: float | None
    clippedH: bool
    clippedV: bool
    extrapolatedH: bool
    extrapolatedV: bool
    insufficientDataH: bool
    insufficientDataV: bool
    berAtCenter: float | None
    berUpperAtCenter: float | None
    isBoundAtCenter: bool | None
    berAtCenterText: str
    text: str


@dataclass
class MarginResult:
    """2D eye, the two cross bathtubs and the margin summary of one run.

    Parameters
    ----------
    eye : EyeResult
        The eye at the eye floor, with its centre.
    horz, vert : SweepResult or None
        Step-1 bathtubs along the centre row and the centre column; None when
        the cross was not reached.
    summary : MarginSummary
        The numbers a user acts on.
    status : ScanStatus
        ``OK`` when the eye is open, ``CLOSED`` when its vertical-0 row has no
        open run, otherwise the status the run ended with.
    message : str
        Human-readable outcome.
    activation : ActivationResult or None
        Outcome of the single sampler activation of the run.
    linkDrops : int
        Link drops handled during the run.
    meta : dict
        Scan parameters, timing and the lane state they were taken in.
    """

    eye: EyeResult
    horz: SweepResult | None
    vert: SweepResult | None
    summary: MarginSummary
    status: ScanStatus
    message: str
    activation: ActivationResult | None
    linkDrops: int
    meta: dict
