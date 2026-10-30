#-----------------------------------------------------------------------------
# Title      : Statistical eye-scan process
#-----------------------------------------------------------------------------
# Description:
# PyRogue Process child added to the transceiver channel drivers. It owns the
# RX reset hook injected by the application, runs the horizontal bathtub, the
# 2D eye and the margin summary from the synchronous API (the scan selected by
# Mode also from the Start and Stop commands), saves results to disk, and
# exposes the eye-scan state.
# Nothing here touches hardware at construction or at start.
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

import contextlib
import dataclasses
import math
import shutil
import threading
import time
from types import SimpleNamespace
from typing import Any, Callable

import click
import pyrogue as pr

from surf.xilinx.eyescan._EyeScanEngine import (
    EyeScanEngine,
    ScanControl,
    _classify,
    _resolveRanges,
    estimateScanSeconds,
)
from surf.xilinx.eyescan._EyeScanFamilies import getFamily
from surf.xilinx.eyescan._EyeScanMath import openRegion
from surf.xilinx.eyescan._EyeScanOutput import SaveOutcome, formatBer, saveResult, surfVersion
from surf.xilinx.eyescan._EyeScanPort import EyeScanPort
from surf.xilinx.eyescan._EyeScanTypes import (
    ActivationResult,
    BathtubResult,
    EyeResult,
    EyeScanError,
    LaneState,
    MarginResult,
    ResetPolicy,
    RxResetHook,
    ScanStatus,
    SoftColdResult,
)

__all__ = [
    'EyeScan',
]

# Progress above which the measured estimate replaces the model
_ETA_MIN_PROGRESS = 0.02

# Seconds added to the reset pulse, fall wait and settle for the sampler probe of an activation
_ACTIVATION_PROBE = 0.1

# Steps of the terminal progress bar of a synchronous scan
_BAR_STEPS = 1000

# Columns of the progress bar line kept for the brackets, percent, ETA and at least ten bar characters
_BAR_RESERVED = 34


_BUSY = 'another eye-scan run is in progress on this transceiver'


class _ScanBusy(EyeScanError):
    """Another scan holds the scan lock: the call is refused and nothing else changes."""


class _Throttle:
    """Pass at most one value per ``period`` seconds to ``setter``; ``flush`` writes the last one."""

    def __init__(self, setter: Callable[[Any], None], period: float = 0.25) -> None:
        self._setter = setter
        self._period = period
        self._sent = -math.inf
        self._last = None
        self._pending = False

    def __call__(self, value: Any) -> None:
        self._last = value
        self._pending = True
        now = time.monotonic()
        if now - self._sent >= self._period:
            self._send(now)

    def flush(self) -> None:
        """Write the most recent value if it has not been written yet."""
        if self._pending:
            self._send(time.monotonic())

    def _send(self, now: float) -> None:
        self._pending = False
        self._sent = now
        self._setter(self._last)


class EyeScan(pr.Process):
    """Eye-scan child of a transceiver channel driver.

    Parameters
    ----------
    family : str
        Transceiver family name, for example ``GTHE3``.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Process``. The device is
        always placed in the ``NoConfig`` and ``NoState`` groups.
    """

    def __init__(self, *, family: str, **kwargs: Any) -> None:
        groups = list(kwargs.pop('groups', None) or [])
        for group in ('NoConfig', 'NoState'):
            if group not in groups:
                groups.append(group)
        kwargs['groups'] = groups
        kwargs.setdefault('description', 'Statistical eye scan of this transceiver channel')
        super().__init__(function=self._runProcess, **kwargs)

        self._family = family
        self._hook = None
        self._hookObjs = None
        # Re-entrant: a Start run holds it across the scan and the save, and the scan itself takes it again
        self._scanLock = threading.RLock()
        self._runGate = threading.Lock()
        self._lastProgress = 0.0
        self._scanStart = None
        self._laneInfo = None
        self._measuredLineRate = 0.0
        self.lastResult = None

        self.add(pr.LocalVariable(
            name        = 'Family',
            description = 'Transceiver family of the eye-scan descriptor',
            value       = family,
            mode        = 'RO',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'Status',
            description = 'Outcome of the most recent eye-scan run',
            value       = 'Idle',
            mode        = 'RO',
            groups      = ['NoConfig'],
        ))

        # Evaluated at read time: variable paths are only final once the root is attached
        self.add(pr.LocalVariable(
            name        = 'OutputDir',
            description = 'Folder the result files are saved to; a relative path is resolved to an absolute path when the result is saved',
            value       = '.',
            mode        = 'RW',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'ResultFile',
            description = 'Absolute path of the npz written by the most recent save, empty when the last run was not saved',
            value       = '',
            mode        = 'RO',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'RxResetHook',
            description = 'RX reset and ready objects registered by the application',
            value       = 'none',
            mode        = 'RO',
            localGet    = self._hookText,
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'ResetPolicy',
            description = 'RX reset on activation: Auto and Always reset on every activation (no hook refuses the scan), Never only sets the enables',
            value       = 0,
            mode        = 'RW',
            enum        = {0: 'Auto', 1: 'Always', 2: 'Never'},
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'Mode',
            description = 'Scan the Start command runs: Bathtub (horizontal sweep), Eye (2D eye) or Margin (2D eye plus the step-1 cross and the extrapolated openings)',
            value       = 2,
            mode        = 'RW',
            enum        = {0: 'Bathtub', 1: 'Eye', 2: 'Margin'},
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'EyeBerFloor',
            description = 'BER floor every eye position must prove in Eye and Margin mode, in (0, 1)',
            value       = 1e-6,
            mode        = 'RW',
            disp        = '{:g}',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'BathtubBerFloor',
            description = 'BER floor every bathtub position must prove in Bathtub mode and in the Margin cross, in (0, 1)',
            value       = 1e-9,
            mode        = 'RW',
            disp        = '{:g}',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'TargetBer',
            description = 'BER the bathtub and margin openings are extrapolated to, in (0, 1)',
            value       = 1e-12,
            mode        = 'RW',
            disp        = '{:g}',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'HorzStep',
            description = 'Spacing in counts of the horizontal positions of the eye and of the Bathtub mode sweep; the default of 2 gives a 65 count Bathtub run, 1 gives every count',
            value       = 2,
            mode        = 'RW',
            minimum     = 1,
            maximum     = 512,
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'VertStep',
            description = 'Spacing in codes of the vertical positions of the eye',
            value       = 4,
            mode        = 'RW',
            minimum     = 1,
            maximum     = 127,
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'Equalizer',
            description = 'Receiver equalizer the lane runs with: dfe or lpm',
            value       = 0,
            mode        = 'RW',
            enum        = {0: 'dfe', 1: 'lpm'},
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'Confidence',
            description = 'One-sided confidence of the zero-error BER bound, in (0, 1)',
            value       = 0.95,
            mode        = 'RW',
            disp        = '{:g}',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'LineRateGbps',
            description = 'Line rate of the lane in Gb/s; 0 means not defined: the scan then measures the rate with one extra run, records it as measured and warns that the value is less accurate than setting this variable, which is left at 0',
            value       = 0.0,
            mode        = 'RW',
            units       = 'Gb/s',
            minimum     = 0.0,
            disp        = '{:g}',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'SavePng',
            description = 'Render the PNG plots next to the npz and CSV of a Start run; a stopped scan never renders them',
            value       = True,
            mode        = 'RW',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'HorzRange',
            description = 'Largest horizontal offset in counts of the eye and the cross, 0 for the full range of the lane',
            value       = 0,
            mode        = 'RW',
            minimum     = 0,
            hidden      = True,
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'VertRange',
            description = 'Largest vertical offset in codes of the eye and the cross, 0 for the full range of the lane',
            value       = 0,
            mode        = 'RW',
            minimum     = 0,
            hidden      = True,
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'MaxTimePerRun',
            description = 'Seconds a sampler run may count before it is stopped and its partial counts are used; '
                          'the scan ends in TIMEOUT only when a stopped run counted no samples or the sampler '
                          'does not return to idle',
            value       = 30.0,
            mode        = 'RW',
            disp        = '{:g}',
            hidden      = True,
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'HorzOpeningUI',
            description = 'Horizontal eye opening of the last run in UI (extrapolated to TargetBer when available), NaN until a result exists',
            value       = math.nan,
            mode        = 'RO',
            disp        = '{:.4f}',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'VertOpeningCodes',
            description = 'Vertical eye opening of the last run in codes (extrapolated to TargetBer when available), NaN until a result exists or in Bathtub mode',
            value       = math.nan,
            mode        = 'RO',
            disp        = '{:.1f}',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'BerAtCenter',
            description = 'BER at the centre of the last run as text; a point without errors reads BER < X at the confidence level, never BER 0',
            value       = '',
            mode        = 'RO',
            groups      = ['NoConfig'],
        ))

        self.add(pr.LocalVariable(
            name        = 'HwVerified',
            description = 'True when the eye scan of this transceiver family was verified on hardware',
            value       = False,
            mode        = 'RO',
            localGet    = self._hwVerified,
            groups      = ['NoConfig'],
        ))

        # Reads LocalVariable values and cached attributes only, never the bus
        self.add(pr.LinkVariable(
            name         = 'EtaSeconds',
            description  = self._etaDescription(),
            mode         = 'RO',
            units        = 's',
            disp         = '{:.0f}',
            groups       = ['NoConfig'],
            dependencies = [self.Mode, self.EyeBerFloor, self.BathtubBerFloor, self.HorzStep, self.VertStep,
                            self.HorzRange, self.VertRange, self.Equalizer, self.Confidence,
                            self.LineRateGbps, self.MaxTimePerRun, self.ResetPolicy, self.Progress,
                            self.Running],
            linkedGet    = self._eta,
        ))

    def setRxReset(
            self,
            reset: Any,
            ready: Any,
            settle: float = 0.5,
            timeout: float = 6.0,
            *,
            hold: float = 0.05,
            fallWait: float = 0.5) -> None:
        """Register the RX reset hook used to activate the sampler.

        Registration only stores the hook, it never accesses hardware.

        Parameters
        ----------
        reset : pyrogue variable or callable
            A writable variable is pulsed True then False (always deasserted);
            a callable performs the whole pulse itself and should return within
            0.1 s, because the pulse is the one step of a scan that Stop cannot
            interrupt.
        ready : pyrogue variable or callable
            A variable is polled with ``get()``; a callable returns a bool.
        settle : float, optional
            Seconds to wait after ready returns True.
        timeout : float, optional
            Seconds to wait for ready to return True after the pulse. The
            default is about ten times the longest relock measured on KCU1500
            GTH lanes (0.55 s).
        hold : float, optional
            Seconds the reset variable is held True; keep it below 0.1 s so
            Stop stays within 1 s.
        fallWait : float, optional
            Seconds to wait for ready to drop after the pulse.

        Raises
        ------
        TypeError
            If ``reset`` or ``ready`` is neither a variable nor a callable.
        ValueError
            If ``reset`` is a read-only variable.
        """
        pulse = self._asPulse(reset, hold)
        isReady = self._asReady(ready)
        self._hook = RxResetHook(
            pulse       = pulse,
            ready       = isReady,
            settle      = settle,
            timeout     = timeout,
            fallWait    = fallWait,
            hold        = hold,
            description = f'{self._describe(reset)} / {self._describe(ready)}',
        )
        self._hookObjs = (reset, ready)

    def clearRxReset(self) -> None:
        """Drop the registered RX reset hook."""
        self._hook = None
        self._hookObjs = None

    def readState(self) -> LaneState:
        """Read the eye-scan state of the parent channel (hardware reads only).

        Returns
        -------
        LaneState
            Snapshot of the enables, control, counters and decoded widths.
        """
        return self._engine().readState()

    def probe(
            self,
            *,
            resetPolicy: ResetPolicy | str | None = None,
            probeWindow: float = 2.0,
            control: ScanControl | None = None) -> ActivationResult:
        """Activate the sampler and report whether it came alive.

        The registers a scan changes are restored afterwards; both enables stay
        set. The call never raises for a scan failure, the result carries a
        typed status.

        Parameters
        ----------
        resetPolicy : ResetPolicy or str, optional
            Overrides the ``ResetPolicy`` variable for this call.
        probeWindow : float, optional
            Seconds the probe run has to reach END.
        control : ScanControl, optional
            Abort flag and progress callback.

        Returns
        -------
        ActivationResult
            Status OK when the sampler reached END with samples and showed
            data transitions at the ends of the UI, CLOSED with the two-cause
            warning (sampler out of step, or link closed or unlocked) when it
            did not, NOT_ENABLED when a run did not reach END with samples.

        Raises
        ------
        EyeScanError
            If another scan holds the scan lock.
        """
        policy = ResetPolicy(resetPolicy if resetPolicy is not None else self.ResetPolicy.valueDisp())
        with self._scanning(control) as engine:
            result = engine.probe(policy, probeWindow)
        self.Status.set(result.status.value)
        return result

    def softCold(
            self,
            *,
            probeWindow: float = 2.0,
            control: ScanControl | None = None) -> SoftColdResult:
        """Return the sampler to the cold state (enables 0) and prove it stopped.

        Needs a registered RX reset hook.

        Parameters
        ----------
        probeWindow : float, optional
            Seconds the probe run is observed.
        control : ScanControl, optional
            Abort flag and progress callback.

        Returns
        -------
        SoftColdResult
            ``stopped`` is True when the sampler no longer reaches END with samples.

        Raises
        ------
        EyeScanError
            If no hook is registered or another scan holds the scan lock.
        """
        with self._scanning(control) as engine:
            try:
                result = engine.softCold(probeWindow)
            except Exception as exc:
                self.Status.set(_classify(exc)[0].value)
                raise
        self.Status.set(ScanStatus.OK.value if result.stopped else ScanStatus.ERROR.value)
        return result

    def runBathtub(
            self,
            *,
            floor: float = 1e-9,
            confidence: float = 0.95,
            step: int = 1,
            equalizer: str = 'dfe',
            resetPolicy: ResetPolicy | str | None = None,
            targetBer: float = 1e-12,
            fixedPrescale: int | None = None,
            maxTimePerRun: float = 30.0,
            probeWindow: float = 2.0,
            lineRateGbps: float | None = None,
            phaseUnification: str | None = None,
            control: ScanControl | None = None,
            outDir: str | None = None,
            progressBar: bool = False) -> BathtubResult:
        """Measure the two-sided horizontal bathtub and restore the registers.

        The sweep covers every count of the lane's +-0.5 UI range (spaced by
        ``step``); each point is driven to ``floor`` with an adaptive prescale.
        A scan failure or stop is returned as a typed status with the
        completed points. The result is also kept in ``lastResult``.

        Parameters
        ----------
        floor : float, optional
            BER floor every point must prove, in (0, 1).
        confidence : float, optional
            One-sided confidence of the zero-error bound, in (0, 1).
        step : int, optional
            Spacing of the swept counts.
        equalizer : str, optional
            ``dfe`` or ``lpm``.
        resetPolicy : ResetPolicy or str, optional
            Overrides the ``ResetPolicy`` variable for this call.
        targetBer : float, optional
            BER the opening is extrapolated to, in (0, 1).
        fixedPrescale : int, optional
            Run exactly this one prescale at every point.
        maxTimePerRun : float, optional
            Seconds one run may take.
        probeWindow : float, optional
            Seconds the activation probe has to reach END.
        lineRateGbps : float, optional
            Line rate in Gb/s; the ``LineRateGbps`` variable when omitted. A
            value of 0 or below is not defined: the scan measures the rate with
            one extra run, records the source ``measured`` and a warning.
        phaseUnification : str, optional
            Expert override of the phase-unification rule, ``sign`` or ``rate``
            (see ``EyeScanFamily``); the family's rule when omitted. There is no
            variable for it. The rule ``rate`` needs a positive line rate: with
            ``LineRateGbps`` 0 and no positive ``lineRateGbps`` the scan ends
            ``ERROR`` naming ``LineRateGbps``, with nothing written.
        control : ScanControl, optional
            Abort flag and progress callback.
        outDir : str, optional
            Folder to save the result to; nothing is saved when omitted.
        progressBar : bool, optional
            Show a click progress bar with the ETA and the scan stage on the
            terminal; ``control`` still receives the abort, progress and stage.

        Returns
        -------
        BathtubResult
            The extrapolated opening is only set when both tail fits passed
            their quality gates.

        Raises
        ------
        ValueError
            If an argument is invalid; nothing is written in that case.
        EyeScanError
            If another scan holds the scan lock.
        """
        policy = ResetPolicy(resetPolicy if resetPolicy is not None else self.ResetPolicy.valueDisp())
        return self._scan(control, outDir, progressBar, 'Bathtub', lambda engine: engine.bathtub(
            policy=policy, floor=floor, confidence=confidence, step=step, equalizer=equalizer,
            targetBer=targetBer, fixedPrescale=fixedPrescale, maxTimePerRun=maxTimePerRun,
            probeWindow=probeWindow, phaseUnification=phaseUnification, **self._rateArgs(lineRateGbps)))

    def runEye(
            self,
            *,
            floor: float = 1e-6,
            confidence: float = 0.95,
            horzStep: int = 2,
            vertStep: int = 4,
            horzRange: int | None = None,
            vertRange: int | None = None,
            equalizer: str = 'dfe',
            resetPolicy: ResetPolicy | str | None = None,
            fixedPrescale: int | None = None,
            maxTimePerRun: float = 30.0,
            probeWindow: float = 2.0,
            lineRateGbps: float | None = None,
            phaseUnification: str | None = None,
            control: ScanControl | None = None,
            outDir: str | None = None,
            progressBar: bool = False) -> EyeResult:
        """Measure the 2D statistical eye and restore the registers.

        The grid is symmetric about the eye centre and always contains 0 on
        both axes; the default covers the full range of the lane at the
        default steps (RXOUT_DIV 2 gives 65 columns by 63 rows). Rows are
        measured centre-out and the sampler is activated once. A scan failure
        or stop is returned as a typed status with the completed positions.
        The result is also kept in ``lastResult``.

        Parameters
        ----------
        floor : float, optional
            BER floor every position must prove, in (0, 1).
        confidence : float, optional
            One-sided confidence of the zero-error bound, in (0, 1).
        horzStep : int, optional
            Spacing of the horizontal counts.
        vertStep : int, optional
            Spacing of the vertical codes.
        horzRange : int, optional
            Largest horizontal offset in counts; the full range when omitted.
        vertRange : int, optional
            Largest vertical offset in codes; the full range when omitted.
        equalizer : str, optional
            ``dfe`` or ``lpm``.
        resetPolicy : ResetPolicy or str, optional
            Overrides the ``ResetPolicy`` variable for this call.
        fixedPrescale : int, optional
            Run exactly this one prescale at every position.
        maxTimePerRun : float, optional
            Seconds one run may take.
        probeWindow : float, optional
            Seconds the activation probe has to reach END.
        lineRateGbps : float, optional
            Line rate in Gb/s; the ``LineRateGbps`` variable when omitted. A
            value of 0 or below is not defined: the scan measures the rate with
            one extra run, records the source ``measured`` and a warning.
        phaseUnification : str, optional
            Expert override of the phase-unification rule, ``sign`` or ``rate``
            (see ``EyeScanFamily``); the family's rule when omitted. There is no
            variable for it. The rule ``rate`` needs a positive line rate: with
            ``LineRateGbps`` 0 and no positive ``lineRateGbps`` the scan ends
            ``ERROR`` naming ``LineRateGbps``, with nothing written.
        control : ScanControl, optional
            Abort flag and progress callback.
        outDir : str, optional
            Folder to save the result to; nothing is saved when omitted.
        progressBar : bool, optional
            Show a click progress bar with the ETA and the scan stage on the
            terminal; ``control`` still receives the abort, progress and stage.

        Returns
        -------
        EyeResult
            ``OK`` or ``CLOSED`` from the vertical-0 row, else the status the
            scan ended with.

        Raises
        ------
        ValueError
            If an argument is invalid; nothing is written in that case.
        EyeScanError
            If another scan holds the scan lock.
        """
        policy = ResetPolicy(resetPolicy if resetPolicy is not None else self.ResetPolicy.valueDisp())
        return self._scan(control, outDir, progressBar, 'Eye', lambda engine: engine.eye(
            policy=policy, floor=floor, confidence=confidence, horzStep=horzStep, vertStep=vertStep,
            horzRange=horzRange, vertRange=vertRange, equalizer=equalizer, fixedPrescale=fixedPrescale,
            maxTimePerRun=maxTimePerRun, probeWindow=probeWindow, phaseUnification=phaseUnification,
            **self._rateArgs(lineRateGbps)))

    def runMargin(
            self,
            *,
            floor: float = 1e-6,
            bathtubFloor: float = 1e-9,
            targetBer: float = 1e-12,
            confidence: float = 0.95,
            horzStep: int = 2,
            vertStep: int = 4,
            horzRange: int | None = None,
            vertRange: int | None = None,
            equalizer: str = 'dfe',
            resetPolicy: ResetPolicy | str | None = None,
            fixedPrescale: int | None = None,
            maxTimePerRun: float = 30.0,
            probeWindow: float = 2.0,
            lineRateGbps: float | None = None,
            phaseUnification: str | None = None,
            control: ScanControl | None = None,
            outDir: str | None = None,
            progressBar: bool = False) -> MarginResult:
        """Measure the 2D eye and the margin cross in one sampler activation.

        The eye is measured at ``floor``, then a horizontal bathtub along the
        eye-centre row and a vertical bathtub along the eye-centre column, both
        at step 1 and driven to ``bathtubFloor``, and the openings are
        extrapolated to ``targetBer``. Everything shares one RX reset because
        the opening moves between resets. A scan failure or stop is returned as
        a typed status with the completed measurements. The result is also
        kept in ``lastResult``.

        Parameters
        ----------
        floor : float, optional
            BER floor of the eye, in (0, 1).
        bathtubFloor : float, optional
            BER floor of the cross bathtubs, in (0, 1).
        targetBer : float, optional
            BER the openings are extrapolated to, in (0, 1).
        confidence : float, optional
            One-sided confidence of the zero-error bound, in (0, 1).
        horzStep : int, optional
            Spacing of the eye's horizontal counts.
        vertStep : int, optional
            Spacing of the eye's vertical codes.
        horzRange : int, optional
            Largest horizontal offset in counts; the full range when omitted.
        vertRange : int, optional
            Largest vertical offset in codes; the full range when omitted.
        equalizer : str, optional
            ``dfe`` or ``lpm``.
        resetPolicy : ResetPolicy or str, optional
            Overrides the ``ResetPolicy`` variable for this call.
        fixedPrescale : int, optional
            Run exactly this one prescale at every position.
        maxTimePerRun : float, optional
            Seconds one run may take.
        probeWindow : float, optional
            Seconds the activation probe has to reach END.
        lineRateGbps : float, optional
            Line rate in Gb/s; the ``LineRateGbps`` variable when omitted. A
            value of 0 or below is not defined: the scan measures the rate with
            one extra run, records the source ``measured`` and a warning.
        phaseUnification : str, optional
            Expert override of the phase-unification rule, ``sign`` or ``rate``
            (see ``EyeScanFamily``); the family's rule when omitted. There is no
            variable for it. The rule ``rate`` needs a positive line rate: with
            ``LineRateGbps`` 0 and no positive ``lineRateGbps`` the scan ends
            ``ERROR`` naming ``LineRateGbps``, with nothing written.
        control : ScanControl, optional
            Abort flag and progress callback.
        outDir : str, optional
            Folder to save the result to; nothing is saved when omitted.
        progressBar : bool, optional
            Show a click progress bar with the ETA and the scan stage on the
            terminal; ``control`` still receives the abort, progress and stage.

        Returns
        -------
        MarginResult
            ``OK`` or ``CLOSED`` from the eye, else the status the scan ended
            with. Openings are labelled extrapolated or measured in the
            summary.

        Raises
        ------
        ValueError
            If an argument is invalid; nothing is written in that case.
        EyeScanError
            If another scan holds the scan lock.
        """
        policy = ResetPolicy(resetPolicy if resetPolicy is not None else self.ResetPolicy.valueDisp())
        return self._scan(control, outDir, progressBar, 'Margin', lambda engine: engine.margin(
            policy=policy, floor=floor, bathtubFloor=bathtubFloor, targetBer=targetBer,
            confidence=confidence, horzStep=horzStep, vertStep=vertStep, horzRange=horzRange,
            vertRange=vertRange, equalizer=equalizer, fixedPrescale=fixedPrescale,
            maxTimePerRun=maxTimePerRun, probeWindow=probeWindow, phaseUnification=phaseUnification,
            **self._rateArgs(lineRateGbps)))

    def save(
            self,
            result: EyeResult | BathtubResult | MarginResult | None = None,
            outDir: str | None = None,
            *,
            png: bool = True,
            extraMeta: dict | None = None,
            surfVersion: str | None = None) -> SaveOutcome:
        """Save a result as an npz, a CSV and PNG plots and record the npz path in ``ResultFile``.

        Parameters
        ----------
        result : EyeResult, BathtubResult or MarginResult, optional
            Result to save; the most recent one (``lastResult``) when omitted.
        outDir : str, optional
            Target folder; the ``OutputDir`` value when omitted.
        png : bool
            Render the PNG plots; False never imports matplotlib.
        extraMeta : dict, optional
            Caller context stored in the file under ``application``.
        surfVersion : str, optional
            Version text stored in the file; resolved when omitted.

        Returns
        -------
        SaveOutcome
            Paths of the written files and the error texts. ``ResultFile``
            holds the npz path when the npz and the CSV were written and is
            empty otherwise; a plotting failure is only reported in
            ``pngErrors`` and keeps ``ResultFile`` on the npz. A save never
            clears ``lastResult``.

        Raises
        ------
        EyeScanError
            If there is no result to save or the device is not attached.
        """
        result = result if result is not None else self.lastResult
        if result is None:
            raise EyeScanError('no eye-scan result to save')
        if self.parent is None:
            raise EyeScanError('EyeScan is not attached to a transceiver device')
        outDir = outDir if outDir is not None else self.OutputDir.get()
        outcome = saveResult(result, outDir, devicePath=self.parent.path, png=png, extraMeta=extraMeta,
                             surfVersion=surfVersion)
        self.ResultFile.set(outcome.npzPath if not outcome.errors else '')
        return outcome

    def _scan(self, control: ScanControl | None, outDir: str | None, progressBar: bool, kind: str,
              measure: Callable[[EyeScanEngine], Any]) -> Any:
        # Resolved before the scan so the save after a Stop never runs git describe
        version = surfVersion()
        with contextlib.ExitStack() as stack:
            if progressBar:
                control = stack.enter_context(self._progressBar(control, kind))
            return self._scanLocked(control, outDir, version, measure)

    def _scanLocked(self, control: ScanControl | None, outDir: str | None, version: str,
                    measure: Callable[[EyeScanEngine], Any]) -> Any:
        # Status reads Running while the scan lock is held; a refused call leaves everything as it was
        with self._scanning(control) as engine:
            self.ResultFile.set('')
            previous = self.Status.value()
            self.Status.set('Running')
            try:
                result = measure(engine)
            except BaseException:
                self.Status.set(previous)
                raise
            # Published and saved before the lock is released, so a caller refused meanwhile sees a whole scan
            self.lastResult = result
            self._publish(result)
            if outDir is not None:
                self.save(result, outDir, surfVersion=version)
        return result

    @contextlib.contextmanager
    def _progressBar(self, control: ScanControl | None, kind: str):
        # A terminal bar fed by a ScanControl that forwards the abort, the progress and the stage to control.
        # The engine's progress is weighted by the modelled point times, so the bar ETA follows the scan time
        name = self.parent.name if self.parent is not None else self.name
        label = f'{name} {kind}:'

        def stage(text: str | None) -> str | None:
            # Trimmed so the line never wraps, a wrapped line would leave a copy behind on every redraw
            if text is None:
                return None
            return text[:max(0, shutil.get_terminal_size().columns - len(label) - _BAR_RESERVED)]

        with click.progressbar(
                length           = _BAR_STEPS,
                label            = click.style(label, fg='green'),
                width            = 0,
                show_eta         = True,
                show_percent     = True,
                update_min_steps = 0,
                item_show_func   = stage) as bar:

            def onProgress(done: int, total: int) -> None:
                if control is not None:
                    control.progress(done, total)
                target = min(_BAR_STEPS, _BAR_STEPS * done // total) if total > 0 else 0
                if target > bar.pos:
                    bar.update(target - bar.pos)

            def onMessage(text: str) -> None:
                if control is not None:
                    control.message(text)
                bar.update(0, text)

            yield ScanControl(
                isAborted  = None if control is None else (lambda: control.aborted),
                onProgress = onProgress,
                onMessage  = onMessage)

    def _rateArgs(self, lineRateGbps: float | None) -> dict:
        # None takes the variable; a rate of 0 or below is not defined, so the scan measures it
        rate = self.LineRateGbps.value() if lineRateGbps is None else lineRateGbps
        return dict(lineRateGbps=max(0.0, float(rate)), measureLineRate=not rate > 0)

    def _publish(self, result: EyeResult | BathtubResult | MarginResult) -> None:
        # Status and the summary scalars of the result just measured
        if result.meta.get('lineRateSource') == 'measured':
            self._measuredLineRate = float(result.meta['lineRateGbps'])
        width, divider = result.meta.get('bitsPerSample'), result.meta.get('rxOutDiv')
        if width is not None and divider is not None:
            self._laneInfo = dict(width=int(width), divider=int(divider))
        horzUI, vertCodes, berText = self._scalars(result)
        self.Status.set(result.status.value)
        self.HorzOpeningUI.set(horzUI)
        self.VertOpeningCodes.set(vertCodes)
        self.BerAtCenter.set(berText)

    @staticmethod
    def _scalars(result: EyeResult | BathtubResult | MarginResult) -> tuple[float, float, str]:
        def number(value: float | None) -> float:
            return math.nan if value is None else float(value)

        confidence = result.meta['confidence']
        if isinstance(result, MarginResult):
            summary = result.summary
            return number(summary.horzOpeningUI), number(summary.vertOpeningCodes), summary.berAtCenterText
        if isinstance(result, EyeResult):
            centre = result.centre
            if centre is None:
                return math.nan, math.nan, formatBer(math.nan, math.nan, False, confidence)
            at = (centre.row, centre.column)
            text = formatBer(float(result.ber[at]), float(result.berUpper[at]), bool(result.isBound[at]), confidence)
            return number(centre.horzOpeningUI), number(centre.vertOpeningCodes), text
        opening = result.openingAtTargetUI if result.extrapolated and result.openingAtTargetUI is not None \
            else result.openingAtFloorUI
        counts = [int(c) for c in result.horzCounts]
        if not counts:
            return number(opening), math.nan, formatBer(math.nan, math.nan, False, confidence)
        # The bathtub centre is the middle of its open run, else the count nearest 0
        region = openRegion(result.horzCounts, result.errors, result.bits, result.meta['floor'], confidence)
        centre = 0.0 if region is None else (counts[region[0]] + counts[region[1]]) / 2.0
        index = min(range(len(counts)), key=lambda i: (abs(counts[i] - centre), abs(counts[i])))
        text = formatBer(float(result.ber[index]), float(result.berUpper[index]), bool(result.isBound[index]),
                         confidence)
        return number(opening), math.nan, text

    def _eta(self) -> float:
        # Only LocalVariable values and cached attributes are read: no bus transaction, safe at any time
        progress = self.Progress.value()
        start = self._scanStart
        if self.Running.value() and start is not None and progress > _ETA_MIN_PROGRESS:
            return max(0.0, (time.monotonic() - start) / progress * (1.0 - progress))
        try:
            return self._modelEta()
        except (ValueError, EyeScanError):
            return math.nan

    def _lineRate(self) -> tuple[float, bool]:
        # The rate the estimate prices bits at, and whether the scan will spend a run measuring it
        rate = self.LineRateGbps.value()
        if rate > 0:
            return rate, False
        return self._measuredLineRate, True

    def _etaDescription(self) -> str:
        # The pre-scan lane comes from the family descriptor, an unsupported or unknown family has none
        try:
            family = getFamily(self._family)
            lane = f'W {family.defaultWidth} and RXOUT_DIV {family.defaultDivider}'
        except EyeScanError:
            lane = "the family's lane values"
        return ('Worst-case scan time before Start (every point runs to its floor, from the knobs and the line rate), '
                'the measured estimate while scanning; NaN until LineRateGbps is set or a scan has measured the line '
                f'rate; the data width and RXOUT_DIV used before the first scan are {lane}')

    def _modelEta(self) -> float:
        family = getFamily(self._family)
        rate, measure = self._lineRate()
        if rate <= 0:
            # No line rate set and none measured yet: the overhead-only estimate would be about 100x too low
            return math.nan
        lane = self._laneInfo or dict(width=family.defaultWidth, divider=family.defaultDivider)
        half = family.countsPerHalfUiPerDiv * lane['divider']
        mode = self.Mode.valueDisp()
        horzStep = int(self.HorzStep.value())
        vertStep = int(self.VertStep.value())
        if mode == 'Bathtub':
            horzRange, vertRange = _resolveRanges(half, family.vsCodeMax, horzStep, 1, None, None)
        else:
            horzRange, vertRange = _resolveRanges(half, family.vsCodeMax, horzStep, vertStep,
                                                  int(self.HorzRange.value()) or None,
                                                  int(self.VertRange.value()) or None)
        hook = self._hook
        activation = 0.0
        if hook is not None and self.ResetPolicy.valueDisp() != 'Never':
            activation = hook.hold + hook.fallWait + hook.settle + _ACTIVATION_PROBE
        return estimateScanSeconds(
            mode, floor=self.EyeBerFloor.value(), bathtubFloor=self.BathtubBerFloor.value(),
            confidence=self.Confidence.value(), horzStep=horzStep, vertStep=vertStep, horzRange=horzRange,
            vertRange=vertRange, equalizer=self.Equalizer.valueDisp(), fixedPrescale=None,
            lineRateGbps=rate, width=lane['width'], maxTimePerRun=self.MaxTimePerRun.value(),
            activationSeconds=activation, measureLineRate=measure)

    def _hwVerified(self) -> bool:
        # Read from the descriptor each time, an unsupported or unknown family is never verified
        try:
            return bool(getFamily(self._family).hwVerified)
        except EyeScanError:
            return False

    @contextlib.contextmanager
    def _scanning(self, control: ScanControl | None):
        # One scan at a time: a second caller is refused instead of queued
        if not self._scanLock.acquire(blocking=False):
            raise _ScanBusy(_BUSY)
        try:
            yield self._engine(control or ScanControl())
        finally:
            self._scanLock.release()

    def _hookText(self) -> str:
        if self._hookObjs is None:
            return 'none'
        return f'{self._describe(self._hookObjs[0])} / {self._describe(self._hookObjs[1])}'

    @staticmethod
    def _describe(obj: Any) -> str:
        return obj.path if isinstance(obj, pr.BaseVariable) else 'callable'

    @staticmethod
    def _asPulse(reset: Any, hold: float) -> Callable[[], None]:
        if isinstance(reset, pr.BaseVariable):
            if reset.mode == 'RO':
                raise ValueError(f'reset variable {reset.name} is read-only')

            def pulse() -> None:
                # Read first so the shared register word shadow holds the live neighbours
                reset.get()
                try:
                    reset.set(True)
                    time.sleep(hold)
                finally:
                    reset.set(False)
            return pulse
        if callable(reset):
            return reset
        raise TypeError('reset must be a pyrogue variable or a callable')

    @staticmethod
    def _asReady(ready: Any) -> Callable[[], bool]:
        if isinstance(ready, pr.BaseVariable):
            return lambda: bool(ready.get())
        if callable(ready):
            return lambda: bool(ready())
        raise TypeError('ready must be a pyrogue variable or a callable')

    def _engine(self, control: ScanControl | None = None) -> EyeScanEngine:
        # The parent is resolved at call time, it is None until the device is attached
        if self.parent is None:
            raise EyeScanError('EyeScan is not attached to a transceiver device')
        hook = self._hook
        if hook is not None:
            hook = dataclasses.replace(hook, description=self._hookText())
        return EyeScanEngine(EyeScanPort(self.parent, getFamily(self._family)), hook, control)

    def _processParams(self) -> dict:
        # Every knob is read once, at Start: a change while Running applies to the next Start
        return dict(
            mode          = self.Mode.valueDisp(),
            eyeFloor      = self.EyeBerFloor.value(),
            bathtubFloor  = self.BathtubBerFloor.value(),
            targetBer     = self.TargetBer.value(),
            horzStep      = int(self.HorzStep.value()),
            vertStep      = int(self.VertStep.value()),
            equalizer     = self.Equalizer.valueDisp(),
            confidence    = self.Confidence.value(),
            horzRange     = int(self.HorzRange.value()) or None,
            vertRange     = int(self.VertRange.value()) or None,
            maxTimePerRun = self.MaxTimePerRun.value(),
            lineRateGbps  = self.LineRateGbps.value(),
            resetPolicy   = self.ResetPolicy.valueDisp(),
            outDir        = self.OutputDir.value(),
            savePng       = bool(self.SavePng.value()))

    def _setProgressValue(self, value: float) -> None:
        self._lastProgress = value
        self.setProgress(value)

    def _run(self) -> None:
        # A worker that starts while another is live ends at once and touches nothing but Message, so Running
        # and Status stay as the live run left them; the live run overwrites Message with its own progress
        if not self._runGate.acquire(blocking=False):
            self.Message.set('Start refused: another eye-scan run of this transceiver is still running or ending')
            return
        try:
            super()._run()
        finally:
            self._runGate.release()

    def _runProcess(self) -> SimpleNamespace:
        # The scan selected by Mode on the worker thread; Stop clears _runEn, which aborts the scan.
        # Everything one Start measures stays in the returned record, so a refused Start cannot alter another run
        run = SimpleNamespace(result=None, error=None, outcome=None, refused=False)
        # The scan lock is held from here through the save: a synchronous caller that completed a scan between
        # the publication of this result and its save would leave ResultFile naming a result that is not
        # lastResult. The scan that holds the lock owns Status and the result files; only the Message tells of
        # the refusal
        if not self._scanLock.acquire(blocking=False):
            run.error = _BUSY
            run.refused = True
            return run
        try:
            return self._runOwned(run)
        finally:
            self._scanLock.release()

    def _runOwned(self, run: SimpleNamespace) -> SimpleNamespace:
        # The scan selected by Mode and its save, with the scan lock held by the worker thread
        self._scanStart = time.monotonic()
        progress = _Throttle(self._setProgressValue)
        message = _Throttle(self.Message.set)
        control = ScanControl(
            isAborted  = lambda: not self._runEn,
            onProgress = lambda done, total: progress(done / total),
            onMessage  = message)
        try:
            params = self._processParams()
            run.result = self._runMode(params, control)
        except EyeScanError as exc:
            self.Status.set(ScanStatus.ERROR.value)
            run.error = str(exc)
        except ValueError as exc:
            self.Status.set(ScanStatus.ERROR.value)
            run.error = f'invalid parameter: {exc}'
        except Exception as exc:
            self.Status.set(ScanStatus.ERROR.value)
            run.error = f'{type(exc).__name__}: {exc}'
        finally:
            progress.flush()
            message.flush()
        result = run.result
        if result is not None:
            # A stopped scan skips the PNGs so Stop returns promptly
            png = params['savePng'] and result.status is not ScanStatus.ABORTED and self._runEn
            run.outcome = self.save(result, params['outDir'], png=png, surfVersion=surfVersion())
        return run

    def _runMode(self, params: dict, control: ScanControl) -> BathtubResult | EyeResult | MarginResult:
        common = dict(confidence=params['confidence'], equalizer=params['equalizer'],
                      resetPolicy=params['resetPolicy'], maxTimePerRun=params['maxTimePerRun'],
                      lineRateGbps=params['lineRateGbps'], control=control)
        if params['mode'] == 'Bathtub':
            return self.runBathtub(floor=params['bathtubFloor'], step=params['horzStep'],
                                   targetBer=params['targetBer'], **common)
        grid = dict(horzStep=params['horzStep'], vertStep=params['vertStep'], horzRange=params['horzRange'],
                    vertRange=params['vertRange'])
        if params['mode'] == 'Eye':
            return self.runEye(floor=params['eyeFloor'], **grid, **common)
        return self.runMargin(floor=params['eyeFloor'], bathtubFloor=params['bathtubFloor'],
                              targetBer=params['targetBer'], **grid, **common)

    def _process(self) -> None:
        # The generic process steps, with the Done message replaced by the outcome of the scan
        self.Message.setDisp('Running')
        self.setStep(0)
        self.setProgress(0.0)
        run = self._runProcess()
        self.Message.setDisp('Done')
        self.setProgress(1.0)
        result = run.result
        outcome = run.outcome
        warnings = '' if result is None else ''.join(f' | {text}' for text in result.meta.get('warnings', []))
        if run.error is not None:
            self.Message.set(f'Error: {run.error}')
        elif result is None:
            return
        elif result.status is ScanStatus.ABORTED:
            # The generic Done step reset Progress to 1.0
            self.setProgress(self._lastProgress)
            if outcome.errors:
                self.Message.set(f'Scan stopped; Save failed: {"; ".join(outcome.errors)}{warnings}')
            else:
                self.Message.set(f'Scan stopped: partial results saved to {outcome.npzPath} (PNG skipped){warnings}')
        elif result.status in (ScanStatus.NOT_ENABLED, ScanStatus.TIMEOUT, ScanStatus.UNLOCKED, ScanStatus.ERROR):
            self.Message.set(f'Error: {result.status.value} {result.message}{self._saveText(outcome)}{warnings}')
        else:
            self.Message.set(f'{self._summaryText(result)}{self._saveText(outcome)}{warnings}')

    @staticmethod
    def _saveText(outcome: SaveOutcome) -> str:
        if outcome.errors:
            return f' | Save failed: {"; ".join(outcome.errors)}'
        text = f' | saved {outcome.npzPath}'
        if outcome.pngErrors:
            text += f' | PNG failed: {"; ".join(outcome.pngErrors)}'
        return text

    def _summaryText(self, result: BathtubResult | EyeResult | MarginResult) -> str:
        if isinstance(result, MarginResult):
            return result.summary.text
        if isinstance(result, EyeResult):
            return self._eyeSummary(result)
        return self._summary(result)

    def _eyeSummary(self, result: EyeResult) -> str:
        floor = result.meta['floor']
        centre = result.centre
        if centre is None:
            return f'{result.status.value}: no position meets BER {floor:g}'
        return (f'{result.status.value}: opening {centre.horzOpeningUI:.3f} UI by {centre.vertOpeningCodes:.1f} codes '
                f'at BER {floor:g} (measured), centre {self.BerAtCenter.value()}')

    @staticmethod
    def _summary(result: BathtubResult) -> str:
        if result.openingAtFloorUI is None:
            return f'{result.status.value}: no position meets BER {result.meta["floor"]:g}'
        text = f'{result.status.value}: opening {result.openingAtFloorUI:.3f} UI at BER {result.meta["floor"]:g} (measured)'
        if result.extrapolated:
            return f'{text}, {result.openingAtTargetUI:.3f} UI at BER {result.targetBer:g} (extrapolated)'
        return f'{text}, extrapolation insufficient_data'
