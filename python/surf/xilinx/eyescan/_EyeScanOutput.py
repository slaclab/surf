#-----------------------------------------------------------------------------
# Title      : Eye-scan result files
#-----------------------------------------------------------------------------
# Description:
# Writes eye-scan results to disk and reads them back: the npz holding the
# prefixed result arrays and one JSON meta string (eye, bathtub and margin
# layouts), the long-form CSV, the PNG plots, the file stem builder, and the
# surf version resolver. numpy and the standard library only at import time:
# matplotlib is imported inside the plot functions, so a result can be saved
# and loaded, and surf imported, without it.
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

import csv
import dataclasses
import enum
import importlib.metadata
import json
import math
import os
import re
import subprocess
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Callable

import numpy as np

from surf.xilinx.eyescan._EyeScanMath import qfunc, qinv
from surf.xilinx.eyescan._EyeScanTypes import BathtubResult, EyeResult, MarginResult

__all__ = [
    'CSV_COLUMNS',
    'NPZ_KEYS',
    'SaveOutcome',
    'metaJson',
    'resultStem',
    'resultArrays',
    'resultMeta',
    'saveResult',
    'loadResult',
    'surfVersion',
    'formatBer',
]

# Columns of the long-form CSV, one row per measured point
CSV_COLUMNS = ('kind', 'horz_count', 'horz_ui', 'vert_code', 'errors_ut0', 'errors_ut1', 'bits_ut0', 'bits_ut1',
               'prescale', 'ber', 'ber_upper', 'is_bound', 'open')

_EYE_SUFFIXES = ('horzAxis', 'vertAxis', 'errors', 'bits', 'prescale', 'ber', 'berUpper', 'isBound', 'open',
                 'measured')
_SWEEP_SUFFIXES = ('axis', 'errors', 'bits', 'prescale', 'ber', 'berUpper', 'isBound')

# Keys of the npz of each result kind
NPZ_KEYS = dict(
    bathtub=('meta',) + tuple(f'horz_{s}' for s in _SWEEP_SUFFIXES),
    eye=('meta',) + tuple(f'eye_{s}' for s in _EYE_SUFFIXES),
    margin=('meta',) + tuple(f'eye_{s}' for s in _EYE_SUFFIXES)
    + tuple(f'{p}_{s}' for p in ('horz', 'vert') for s in _SWEEP_SUFFIXES),
)

# Row order of the CSV kinds
_CSV_KIND_ORDER = {'eye': 0, 'horz': 1, 'vert': 2}

# Seconds the version lookup may spend in git
_GIT_TIMEOUT = 5.0

_STAMP_FORMAT = '%Y%m%d_%H%M%S'

# The resolved surf version, looked up once per process
_version: str | None = None


@dataclass
class SaveOutcome:
    """Outcome of saving a result.

    Parameters
    ----------
    npzPath : str
        Absolute path of the npz, empty when it was not written.
    csvPath : str
        Absolute path of the CSV, empty when it was not written.
    pngPaths : list of str
        Absolute paths of the PNG files that were written.
    errors : list of str
        Directory, npz and CSV failures, one entry each; empty when the data
        files were written.
    pngErrors : list of str
        Plotting failures, one entry each; they never affect the data files.
    """

    npzPath: str = ''
    csvPath: str = ''
    pngPaths: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    pngErrors: list[str] = field(default_factory=list)


def _plain(value: Any) -> Any:
    """Return ``value`` as JSON-ready Python objects.

    Numpy scalars keep their kind (integers stay integers), arrays become
    lists, dataclasses become dicts, enums become their value and NaN or
    infinity become None.
    """
    if dataclasses.is_dataclass(value) and not isinstance(value, type):
        return _plain(dataclasses.asdict(value))
    if isinstance(value, enum.Enum):
        return _plain(value.value)
    if isinstance(value, dict):
        return {str(key): _plain(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_plain(item) for item in value]
    if isinstance(value, np.ndarray):
        return _plain(value.tolist())
    if isinstance(value, np.generic):
        return _plain(value.item())
    if isinstance(value, float):
        return value if math.isfinite(value) else None
    if value is None or isinstance(value, (bool, int, str)):
        return value
    return str(value)


def metaJson(meta: Any) -> str:
    """Return ``meta`` as a JSON string.

    Parameters
    ----------
    meta : Any
        Nested dicts, lists, dataclasses, numpy scalars and arrays.

    Returns
    -------
    str
        JSON with sorted keys. Integers stay integers, floats use the shortest
        round-trip representation and NaN or infinity are written as ``null``.
    """
    return json.dumps(_plain(meta), sort_keys=True, allow_nan=False)


def resultStem(devicePath: str, kind: str, timestamp: datetime | str, serial: int | None = None) -> str:
    """Return the file stem ``eyescan_{stamp}_{device}_{kind}``.

    From the second serial on, the serial is inserted right after the stamp:
    ``eyescan_{stamp}_{serial}_{device}_{kind}``.

    Parameters
    ----------
    devicePath : str
        Path of the transceiver device; every run of characters outside
        ``[A-Za-z0-9]`` becomes one ``_`` and leading and trailing ``_`` are
        dropped.
    kind : str
        Result kind, for example ``eye``.
    timestamp : datetime or str
        Scan start, or its ``yyyymmdd_hhmmss`` stamp.
    serial : int, optional
        Serial of a save that shares its stamp with an earlier one. ``None``
        and 1 give the plain stem, 2 and above insert the serial.

    Returns
    -------
    str
        The stem, without extension.

    Raises
    ------
    ValueError
        If ``serial`` is below 1.
    """
    if serial is not None and serial < 1:
        raise ValueError(f'serial must be at least 1, got {serial}')
    stamp = timestamp.strftime(_STAMP_FORMAT) if isinstance(timestamp, datetime) else str(timestamp)
    device = re.sub(r'[^A-Za-z0-9]+', '_', devicePath).strip('_') or 'device'
    position = f'{serial}_' if serial is not None and serial > 1 else ''
    return f'eyescan_{stamp}_{position}{device}_{kind}'


def _kind(result: Any) -> str:
    if isinstance(result, EyeResult):
        return 'eye'
    if isinstance(result, BathtubResult):
        return 'bathtub'
    if isinstance(result, MarginResult):
        return 'margin'
    raise TypeError(f'cannot save a result of type {type(result).__name__}')


def _eyeArrays(result: EyeResult) -> dict[str, np.ndarray]:
    return {
        'eye_horzAxis': result.horzAxis,
        'eye_vertAxis': result.vertAxis,
        'eye_errors':   result.errors,
        'eye_bits':     result.bits,
        'eye_prescale': result.prescale,
        'eye_ber':      result.ber,
        'eye_berUpper': result.berUpper,
        'eye_isBound':  result.isBound,
        'eye_open':     result.open,
        'eye_measured': result.measured,
    }


def _sweepArrays(prefix: str, positions, errors, bits, prescale, ber, berUpper, isBound) -> dict[str, np.ndarray]:
    return {
        f'{prefix}_axis':     positions,
        f'{prefix}_errors':   errors,
        f'{prefix}_bits':     bits,
        f'{prefix}_prescale': prescale,
        f'{prefix}_ber':      ber,
        f'{prefix}_berUpper': berUpper,
        f'{prefix}_isBound':  isBound,
    }


def _fromSweep(prefix: str, sweep: Any) -> dict[str, np.ndarray]:
    return _sweepArrays(prefix, sweep.positions, sweep.errors, sweep.bits, sweep.prescale, sweep.ber,
                        sweep.berUpper, sweep.isBound)


def _emptySweep(prefix: str) -> dict[str, np.ndarray]:
    flat = np.zeros(0, dtype=np.int64)
    counts = np.zeros((2, 0), dtype=np.int64)
    return _sweepArrays(prefix, flat, counts, counts, flat, np.zeros(0), np.zeros(0), np.zeros(0, dtype=bool))


def resultArrays(result: Any) -> dict[str, np.ndarray]:
    """Return the npz arrays of ``result`` under their prefixed keys.

    Parameters
    ----------
    result : EyeResult, BathtubResult or MarginResult
        Result to save.

    Returns
    -------
    dict
        Key to array. An eye gives the ten ``eye_`` keys, a bathtub the seven
        ``horz_`` keys and a margin the ``eye_`` keys plus the seven ``horz_``
        and ``vert_`` keys; a sweep the run did not reach is saved empty. Every
        key list is pinned in ``NPZ_KEYS``. Counts keep their int64 dtype.
    """
    kind = _kind(result)
    if kind == 'eye':
        return _eyeArrays(result)
    if kind == 'bathtub':
        return _sweepArrays('horz', result.horzCounts, result.errors, result.bits, result.prescale,
                            result.ber, result.berUpper, result.isBound)
    arrays = _eyeArrays(result.eye)
    for prefix, sweep in (('horz', result.horz), ('vert', result.vert)):
        arrays.update(_emptySweep(prefix) if sweep is None else _fromSweep(prefix, sweep))
    return arrays


def _fitPair(low: Any, high: Any) -> dict | None:
    return None if low is None and high is None else dict(left=low, right=high)


def _kindMeta(result: Any) -> dict:
    """Return the meta blocks that depend on the kind of result."""
    if isinstance(result, EyeResult):
        return dict(engine=result.meta, centre=result.centre)
    if isinstance(result, BathtubResult):
        return dict(
            engine=result.meta,
            fits=dict(horz=_fitPair(result.leftFit, result.rightFit)),
            bathtub=dict(
                openingAtFloorUI=result.openingAtFloorUI, openingAtTargetUI=result.openingAtTargetUI,
                targetBer=result.targetBer, extrapolated=result.extrapolated,
                insufficientData=result.insufficientData, utComparison=result.utComparison))
    return dict(
        engine=result.meta,
        summary=result.summary,
        fits=dict(horz=None if result.horz is None else _fitPair(result.horz.lowFit, result.horz.highFit),
                  vert=None if result.vert is None else _fitPair(result.vert.lowFit, result.vert.highFit)),
        centre=result.eye.centre)


def resultMeta(result: Any, *, devicePath: str, extraMeta: dict | None = None,
               surfVersion: str | None = None) -> dict:
    """Return the meta dict saved next to the arrays of ``result``.

    Parameters
    ----------
    result : EyeResult, BathtubResult or MarginResult
        Result to describe.
    devicePath : str
        Path of the transceiver device.
    extraMeta : dict, optional
        Caller context stored under ``application``.
    surfVersion : str, optional
        Version text; resolved from the installation when omitted.

    Returns
    -------
    dict
        Kind, device path, status, message, link drops, activation, the
        engine meta, the surf version and the application meta. An eye adds
        its ``centre``, a bathtub its ``fits`` and a ``bathtub`` block of
        openings and flags, a margin its ``summary``, ``fits`` of both axes
        and the eye ``centre``.
    """
    return dict(
        kind=_kind(result),
        devicePath=devicePath,
        status=result.status,
        message=result.message,
        linkDrops=result.linkDrops,
        activation=result.activation,
        surfVersion=surfVersion if surfVersion is not None else _currentVersion(),
        application=dict(extraMeta) if extraMeta else {},
        **_kindMeta(result),
    )


def _atomicWrite(finalPath: str, writer: Callable[[Any], None], binary: bool) -> None:
    """Write ``finalPath`` through an exclusively created ``.part`` file.

    The final name only ever appears complete: ``writer`` fills the part
    file, which is renamed with ``os.replace`` after ``writer`` returned. A
    failure removes the part file this call created and is re-raised; an
    existing final file is refused, never replaced.

    Parameters
    ----------
    finalPath : str
        Name of the finished file.
    writer : callable
        Called with the open part file handle.
    binary : bool
        Open the part file as binary (``xb``) or as text with ``newline=''``
        (``x``).
    """
    part = finalPath + '.part'
    created = False
    try:
        if binary:
            handle = open(part, 'xb')
        else:
            handle = open(part, 'x', newline='', encoding='utf-8')
        created = True
        with handle:
            writer(handle)
        if os.path.lexists(finalPath):
            raise FileExistsError(f'{finalPath} already exists')
        os.replace(part, finalPath)
    except BaseException:
        if created:
            try:
                os.remove(part)
            except OSError:
                pass
        raise


def _num(value: Any) -> str:
    """Return a CSV cell for a number: ``nan`` for NaN, shortest round-trip repr otherwise."""
    if isinstance(value, (bool, np.bool_)):
        return '1' if value else '0'
    if isinstance(value, (int, np.integer)):
        return str(int(value))
    return repr(float(value))


def _pointRow(kind: str, horz: int, vert: int, ui: float, errors, bits, prescale, ber, berUpper, isBound,
              isOpen) -> tuple:
    """Return ``(kind order, vert, horz, cells)`` of one measured point."""
    # A zero-error point is a bound, never a measured BER of 0
    value = math.nan if isBound or ber == 0 else float(ber)
    cells = (kind, _num(horz), _num(horz * ui), _num(vert), _num(errors[0]), _num(errors[1]), _num(bits[0]),
             _num(bits[1]), _num(prescale), _num(value), _num(berUpper), _num(bool(isBound)), _num(bool(isOpen)))
    return _CSV_KIND_ORDER[kind], vert, horz, cells


def _csvRows(result: Any) -> list[tuple]:
    """Return the CSV rows of ``result`` as ``(kind order, vert, horz, cells)``, unsorted."""
    kind = _kind(result)
    rows: list[tuple] = []
    if kind == 'bathtub':
        floor = result.meta['floor']
        for k in range(len(result.horzCounts)):
            rows.append(_pointRow('horz', int(result.horzCounts[k]), 0, result.uiPerCount, result.errors[:, k],
                                  result.bits[:, k], result.prescale[k], result.ber[k], result.berUpper[k],
                                  result.isBound[k], result.berUpper[k] <= floor))
        return rows
    eye = result if kind == 'eye' else result.eye
    for i in range(len(eye.vertAxis)):
        for j in range(len(eye.horzAxis)):
            if eye.measured[i, j]:
                rows.append(_pointRow('eye', int(eye.horzAxis[j]), int(eye.vertAxis[i]), eye.uiPerCount,
                                      eye.errors[:, i, j], eye.bits[:, i, j], eye.prescale[i, j], eye.ber[i, j],
                                      eye.berUpper[i, j], eye.isBound[i, j], eye.open[i, j]))
    if kind == 'margin':
        for sweep in (result.horz, result.vert):
            if sweep is None:
                continue
            for k in range(len(sweep.positions)):
                position = int(sweep.positions[k])
                horz, vert = (position, sweep.fixed) if sweep.axis == 'horz' else (sweep.fixed, position)
                rows.append(_pointRow(sweep.axis, horz, vert, eye.uiPerCount, sweep.errors[:, k], sweep.bits[:, k],
                                      sweep.prescale[k], sweep.ber[k], sweep.berUpper[k], sweep.isBound[k],
                                      sweep.berUpper[k] <= sweep.floor))
    return rows


def _writeCsv(result: Any, path: str) -> None:
    """Write the long-form CSV of ``result`` to ``path``, atomically.

    One row per measured point, ordered by kind (``eye``, ``horz``,
    ``vert``), then ascending vertical code, then ascending horizontal count.
    Every cell is a number except the kind word, so no device path or other
    free text reaches the file.
    """
    rows = sorted(_csvRows(result), key=lambda row: row[:3])

    def write(handle: Any) -> None:
        writer = csv.writer(handle, lineterminator='\n')
        writer.writerow(CSV_COLUMNS)
        for row in rows:
            writer.writerow(row[3])

    _atomicWrite(path, write, False)


def _confidenceText(confidence: float) -> str:
    return f'{round(confidence * 100, 6):g}%'


def _eyeOf(result: Any) -> EyeResult:
    return result if isinstance(result, EyeResult) else result.eye


def _eyeFigure(result: Any, devicePath: str) -> Any:
    """Return the figure of the 2D eye of an eye or margin result.

    The map is ``log10`` of the BER upper bound (defined at every measured
    point); unmeasured positions are masked. A contour marks the measurement
    floor when the data crosses it, and a text mark states the floor and its
    confidence. A margin result adds the eye centre and the two cross lines.
    """
    from matplotlib.figure import Figure

    eye = _eyeOf(result)
    floor, confidence = eye.meta['floor'], eye.meta['confidence']
    ui = eye.uiPerCount
    cols, rows = np.argsort(eye.horzAxis, kind='stable'), np.argsort(eye.vertAxis, kind='stable')
    x = np.asarray(eye.horzAxis, dtype=float)[cols] * ui
    y = np.asarray(eye.vertAxis, dtype=float)[rows]
    with np.errstate(divide='ignore', invalid='ignore'):
        z = np.ma.masked_invalid(np.log10(np.where(eye.measured, eye.berUpper, np.nan))[np.ix_(rows, cols)])
    fig = Figure(figsize=(8.0, 6.0), layout='constrained')
    ax = fig.add_subplot()
    if x.size and y.size:
        mesh = ax.pcolormesh(x, y, z, shading='nearest', cmap='viridis')
        fig.colorbar(mesh, ax=ax, label=f'log10 BER upper bound ({_confidenceText(confidence)} confidence)')
    level = math.log10(floor)
    if x.size > 1 and y.size > 1 and z.count() and z.min() < level < z.max():
        ax.contour(x, y, z, levels=[level], colors='white', linewidths=1.5)
    ax.text(0.02, 0.98, f'measurement floor BER {floor:g} at {_confidenceText(confidence)}',
            transform=ax.transAxes, va='top', ha='left', color='white', fontsize=9,
            bbox=dict(facecolor='black', alpha=0.6, edgecolor='none'))
    if isinstance(result, MarginResult) and eye.centre is not None:
        centre = eye.centre
        ax.plot([centre.horz * ui], [centre.vert], marker='+', markersize=14, markeredgewidth=2, color='red',
                linestyle='none', label='eye centre')
        if result.horz is not None:
            ax.axhline(result.horz.fixed, color='red', linestyle=':', linewidth=1, label='cross')
        if result.vert is not None:
            ax.axvline(result.vert.fixed * ui, color='red', linestyle=':', linewidth=1, label='cross')
        handles, labels = ax.get_legend_handles_labels()
        ax.legend(dict(zip(labels, handles)).values(), dict(zip(labels, handles)).keys(), loc='lower right',
                  fontsize=8)
    ax.set_xlabel('horizontal offset (UI)')
    ax.set_ylabel('vertical offset (codes)')
    ax.set_title(f"{devicePath}  {eye.meta.get('family', '')}  eye, floor {floor:g}")
    return fig


def _plotEye(result: Any, path: str, *, devicePath: str) -> None:
    """Write the eye figure of ``result`` to ``path`` as a PNG, atomically."""
    fig = _eyeFigure(result, devicePath)
    _atomicWrite(path, lambda handle: fig.savefig(handle, format='png'), True)


def _tailLine(fit: Any, positions: np.ndarray, targetBer: float) -> tuple[np.ndarray, np.ndarray] | None:
    """Return the fitted tail from the sweep edge down to ``targetBer``, or None.

    ``positions`` are in the unit the fit was made in (UI or codes).
    """
    if fit is None or not fit.ok or not fit.slope or positions.size == 0:
        return None
    xTarget = (qinv(targetBer / 0.5) - fit.intercept) / fit.slope
    edge = positions[0] if fit.side == 'left' else positions[-1]
    xs = np.linspace(edge, xTarget, 100)
    return xs, 0.5 * np.array([qfunc(fit.slope * v + fit.intercept) for v in xs])


def _drawSweep(ax: Any, positions, errors, ber, berUpper, isBound, unit: float, floor: float, targetBer: float,
               fits: tuple, xlabel: str, title: str) -> None:
    """Draw one swept axis of a bathtub on ``ax``."""
    positions = np.asarray(positions, dtype=float) * unit
    ber = np.asarray(ber, dtype=float)
    berUpper = np.asarray(berUpper, dtype=float)
    seen = np.asarray(errors).sum(axis=0) > 0 if np.asarray(errors).size else np.zeros(0, dtype=bool)
    seen = seen & np.isfinite(ber) & (ber > 0)
    bound = np.asarray(isBound, dtype=bool) & np.isfinite(berUpper) & (berUpper > 0)
    if seen.any():
        ax.plot(positions[seen], ber[seen], linestyle='none', marker='o', markersize=4, color='tab:blue',
                label='measured BER')
    if bound.any():
        ax.plot(positions[bound], berUpper[bound], linestyle='none', marker='v', markersize=5, color='tab:gray',
                label='upper bound (zero errors)')
    ax.axhline(floor, color='tab:orange', linestyle='--', linewidth=1, label=f'measurement floor {floor:g}')
    ax.axhline(targetBer, color='tab:red', linestyle='--', linewidth=1, label=f'target BER {targetBer:g}')
    labelled = False
    for fit in fits:
        line = _tailLine(fit, positions, targetBer)
        if line is not None:
            ax.plot(line[0], line[1], color='tab:green', linewidth=1.2,
                    label='fitted tail (extrapolated)' if not labelled else '_nolegend_')
            labelled = True
    shown = np.concatenate([ber[seen], berUpper[bound]])
    ax.set_yscale('log')
    ax.set_ylim(min(targetBer, floor, shown.min() if shown.size else 1.0) / 10.0, 1.0)
    ax.set_xlabel(xlabel)
    ax.set_ylabel('BER')
    ax.set_title(title)
    ax.grid(True, which='major', alpha=0.3)
    ax.legend(fontsize=8, loc='upper center')


def _bathtubFigure(result: Any, devicePath: str) -> Any:
    """Return the bathtub figure of a bathtub or margin result.

    One axes per swept axis (horizontal in UI for a bathtub; horizontal in UI
    and vertical in codes for a margin) on a log BER axis. Measured BER
    (errors seen) are markers; a zero-error point is a downward triangle at
    its upper bound, never a measured value. The measurement floor and the
    target BER are labelled lines, and each passing tail fit is drawn down to
    the target BER and labelled extrapolated.
    """
    from matplotlib.figure import Figure

    if isinstance(result, BathtubResult):
        panels = [dict(positions=result.horzCounts, errors=result.errors, ber=result.ber,
                       berUpper=result.berUpper, isBound=result.isBound, unit=result.uiPerCount,
                       floor=result.meta['floor'], target=result.targetBer, fits=(result.leftFit, result.rightFit),
                       xlabel='horizontal offset (UI)', title=f'{devicePath}  horizontal bathtub')]
    else:
        eye = result.eye
        panels = []
        for sweep, xlabel, name in ((result.horz, 'horizontal offset (UI)', 'horizontal'),
                                    (result.vert, 'vertical offset (codes)', 'vertical')):
            if sweep is not None:
                panels.append(dict(positions=sweep.positions, errors=sweep.errors, ber=sweep.ber,
                                   berUpper=sweep.berUpper, isBound=sweep.isBound,
                                   unit=eye.uiPerCount if sweep.axis == 'horz' else 1.0, floor=sweep.floor,
                                   target=sweep.targetBer, fits=(sweep.lowFit, sweep.highFit), xlabel=xlabel,
                                   title=f'{devicePath}  {name} bathtub'))
    fig = Figure(figsize=(6.0 * max(1, len(panels)), 4.5), layout='constrained')
    if not panels:
        ax = fig.add_subplot()
        ax.text(0.5, 0.5, 'no bathtub measured', transform=ax.transAxes, ha='center', va='center')
        ax.set_title(f'{devicePath}  bathtub')
        return fig
    for ax, panel in zip(fig.subplots(1, len(panels), squeeze=False)[0], panels):
        _drawSweep(ax, panel['positions'], panel['errors'], panel['ber'], panel['berUpper'], panel['isBound'],
                   panel['unit'], panel['floor'], panel['target'], panel['fits'], panel['xlabel'], panel['title'])
    return fig


def _plotBathtub(result: Any, path: str, *, devicePath: str) -> None:
    """Write the bathtub figure of ``result`` to ``path`` as a PNG, atomically."""
    fig = _bathtubFigure(result, devicePath)
    _atomicWrite(path, lambda handle: fig.savefig(handle, format='png'), True)


def _writeNpz(result: Any, path: str, devicePath: str, extraMeta: dict | None, surfVersion: str | None) -> None:
    meta = resultMeta(result, devicePath=devicePath, extraMeta=extraMeta, surfVersion=surfVersion)
    arrays = resultArrays(result)
    _atomicWrite(path, lambda handle: np.savez(handle, meta=np.array(metaJson(meta)), **arrays), True)


def saveResult(result: Any, outDir: str | os.PathLike, *, devicePath: str, png: bool = True,
               extraMeta: dict | None = None, surfVersion: str | None = None) -> SaveOutcome:
    """Write ``result`` to ``outDir`` as an npz, a long-form CSV and PNG plots.

    The folder is created when missing. Every file is written under a
    ``.part`` name and renamed once complete, so a file only ever appears
    under its final name complete. Nothing is overwritten: when a file of the
    stem exists, the whole save moves to the next free serial (the serial is
    inserted after the stamp, see :func:`resultStem`). The order is npz, CSV,
    then the PNGs, each plot in its own step: a failure is reported and never
    removes a file an earlier step wrote. Failures are returned, not raised.

    Parameters
    ----------
    result : EyeResult, BathtubResult or MarginResult
        Result to save.
    outDir : str or path-like
        Target folder, resolved to an absolute path.
    devicePath : str
        Path of the transceiver device, used in the file name and the meta.
    png : bool
        Render the PNGs of the kind (``_bathtub.png`` for a bathtub or margin,
        ``_eye.png`` for an eye or margin). False never imports matplotlib.
    extraMeta : dict, optional
        Caller context stored under ``application``.
    surfVersion : str, optional
        Version text; resolved from the installation when omitted.

    Returns
    -------
    SaveOutcome
        Absolute paths of the written files (empty when not written), the
        data file error texts and the plotting error texts.
    """
    outcome = SaveOutcome()
    try:
        folder = os.path.abspath(os.fspath(outDir))
        kind = _kind(result)
        serial = 1
        while True:
            stem = os.path.join(folder, resultStem(devicePath, kind, result.meta['stamp'], serial))
            npz, csvPath = stem + '.npz', stem + '.csv'
            plots = []
            if png:
                if kind in ('bathtub', 'margin'):
                    plots.append(('bathtub', _plotBathtub, stem + '_bathtub.png'))
                if kind in ('eye', 'margin'):
                    plots.append(('eye', _plotEye, stem + '_eye.png'))
            if not any(os.path.lexists(path) for path in (npz, csvPath, *(plot[2] for plot in plots))):
                break
            serial += 1
    except Exception as exc:
        outcome.errors.append(f'{type(exc).__name__}: {exc}')
        return outcome
    try:
        os.makedirs(folder, exist_ok=True)
    except Exception as exc:
        outcome.errors.append(f'outDir: {type(exc).__name__}: {exc}')
        return outcome
    try:
        _writeNpz(result, npz, devicePath, extraMeta, surfVersion)
        outcome.npzPath = npz
    except Exception as exc:
        outcome.errors.append(f'npz: {type(exc).__name__}: {exc}')
    try:
        _writeCsv(result, csvPath)
        outcome.csvPath = csvPath
    except Exception as exc:
        outcome.errors.append(f'csv: {type(exc).__name__}: {exc}')
    for name, plot, path in plots:
        try:
            plot(result, path, devicePath=devicePath)
            outcome.pngPaths.append(path)
        except Exception as exc:
            outcome.pngErrors.append(f'png: {name} plot: {type(exc).__name__}: {exc}')
    return outcome


def loadResult(path: str | os.PathLike) -> tuple[dict[str, np.ndarray], dict]:
    """Load an npz written by :func:`saveResult`.

    Parameters
    ----------
    path : str or path-like
        The npz file; it is opened without pickle support.

    Returns
    -------
    arrays : dict
        Key to array, every array except ``meta``.
    meta : dict
        The decoded JSON meta.
    """
    with np.load(os.fspath(path), allow_pickle=False) as data:
        arrays = {key: data[key] for key in data.files if key != 'meta'}
        meta = json.loads(str(data['meta']))
    return arrays, meta


def _currentVersion() -> str:
    global _version
    if _version is None:
        _version = _gitDescribe() or _installedVersion() or 'unknown'
    return _version


def _gitDescribe() -> str | None:
    # --dirty refreshes the index; GIT_OPTIONAL_LOCKS=0 keeps that read-only so a scan thread never
    # writes .git/index of the checkout it runs from
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0')
    try:
        out = subprocess.run(
            ['git', 'describe', '--tags', '--always', '--dirty'],
            cwd=os.path.dirname(os.path.abspath(__file__)), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            timeout=_GIT_TIMEOUT, check=False, text=True, env=env)
    except (OSError, subprocess.SubprocessError):
        return None
    text = out.stdout.strip()
    return text if out.returncode == 0 and text else None


def _installedVersion() -> str | None:
    try:
        return importlib.metadata.version('surf')
    except importlib.metadata.PackageNotFoundError:
        return None


def surfVersion() -> str:
    """Return the surf version.

    Returns
    -------
    str
        ``git describe --tags --always --dirty`` of the checkout the package
        was loaded from, else the installed package version, else
        ``unknown``; looked up once per process.
    """
    return _currentVersion()


def formatBer(ber: float, berUpper: float, isBound: bool, confidence: float) -> str:
    """Return the text of one BER observation.

    A point without errors is stated as an upper bound, never as BER 0.

    Parameters
    ----------
    ber : float
        Measured BER, NaN when the point saw no errors.
    berUpper : float
        One-sided upper bound of the BER at ``confidence``.
    isBound : bool
        True when the point saw zero errors.
    confidence : float
        Confidence of the bound, in (0, 1).

    Returns
    -------
    str
        ``BER < X at 95%`` for a bound, ``BER = Y`` for a measured value and
        ``BER not measured`` when the point has no data.
    """
    if (isBound or ber == 0) and math.isfinite(berUpper):
        return f'BER < {berUpper:.2g} at {round(confidence * 100, 6):g}%'
    if math.isfinite(ber) and ber > 0:
        return f'BER = {ber:.2e}'
    return 'BER not measured'
