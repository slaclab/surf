# surf.xilinx (Python)

PyRogue models and helpers for Xilinx devices: the GT channel and common register maps (`Gthe3Channel`, `Gthe4Channel`, `Gtye3Channel`, `Gtye4Channel`, `Gtxe2Channel`, `Gtpe2Channel` and their `*Common` devices), the AXI PCIe PHY, the system monitors, clock manager, GPIO and SPI PS blocks, the triple modular redundancy and SEM helpers, and the statistical eye scan of the GT receivers described below. Register names, offsets and bit fields mirror the RTL and the vendor user guides; see [python/README.md](../../README.md) for the package layout and the PyRogue API style.

## Module map of the eye scan

- `eyescan/_EyeScan.py`: the `EyeScan` PyRogue process that the GT channel drivers add as a child. It owns the RX reset hook, the PyDM variables, the synchronous scan API and the Start and Stop path.
- `eyescan/_EyeScanEngine.py`: sampler activation, probe, point measurement, bathtub, eye, margin, abort and restore, plus `ScanControl` and the scan time model.
- `eyescan/_EyeScanPort.py`: role-based register access to the GT DRP words with primed read-modify-write and the snapshot and restore of everything a scan changes.
- `eyescan/_EyeScanMath.py`: bit counts, the prescale ladder, mask words, Poisson bounds and the Q-scale tail fits.
- `eyescan/_EyeScanFamilies.py`: the `GTHE3`, `GTHE4`, `GTYE3` and `GTYE4` descriptors (register roles, mask arrays, width and divider tables, phase rule, `hwVerified`) and `getFamily`.
- `eyescan/_EyeScanTypes.py`: the typed results, `ScanStatus`, `ResetPolicy` and the eye-scan exceptions.
- `eyescan/_EyeScanOutput.py`: the result files (npz, CSV, PNG), `loadResult`, the file stem and the surf version lookup.

## GT eye scan

Every `Gthe3Channel` (UltraScale GTH), `Gthe4Channel` (UltraScale+ GTH), `Gtye3Channel` (UltraScale GTY) and `Gtye4Channel` (UltraScale+ GTY) carries an `EyeScan` child. It measures a two-sided horizontal bathtub, a 2D statistical eye or a margin summary on the live link, with one Python call or with the Start and Stop commands of the PyDM GUI.

### Quick start

Register the RX reset of the lane once, after the device tree is built. The scan resets the receiver to bring its sampler alive, so it needs a way to pulse the reset and to see the receiver come back. For a PGP4 lane the reset is `Ctrl.ResetRx` and the ready signal is `RxStatus.PhyRxActive`:

```python
gt.EyeScan.setRxReset(reset=laneDev.Ctrl.ResetRx, ready=laneDev.RxStatus.PhyRxActive)
```

Run a bathtub and save it:

```python
res = gt.EyeScan.runBathtub()
print(res.status.value, res.openingAtFloorUI)
gt.EyeScan.save(res, '/path/to/outDir')
```

From PyDM, set `LineRateGbps`, `Mode` and `OutputDir` on the `EyeScan` node and press `Start`; `Stop` ends the scan and keeps the partial result.

### The EyeScan child

- Added to every `Gthe3Channel`, `Gthe4Channel`, `Gtye3Channel` and `Gtye4Channel`; `eyeScan=False` on any of them leaves it out. The GTHE4 and GTYE3 drivers and descriptors were written from UG576 Table C-2 and UG578 Table B-2 and have not been run on hardware (`HwVerified` reads False); see [GT drivers from the user guides](#gt-drivers-from-the-user-guides).
- Constructing it, starting the root and `ReadAll` do not access the hardware, nothing polls, and none of its variables is in the saved configuration or state YAML (the device is in the `NoConfig` and `NoState` groups and every variable is a `NoConfig` local).
- `Gtxe2Channel` and `Gtpe2Channel` have no child. `getFamily('GTXE2')` and `getFamily('GTPE2')` raise `EyeScanError` ("eye scan is not supported for this family yet").
- One scan runs at a time per channel. A synchronous call or a Start that finds another scan running is refused and changes nothing of the running scan.

### RX reset hook

The sampler of a GT receiver only comes up reliably after an RX reset, so the application registers one with `setRxReset`:

```python
EyeScan.setRxReset(reset, ready, settle=0.5, timeout=6.0, *, hold=0.05, fallWait=0.5)
```

- `reset`: a writable PyRogue variable, or a callable. A variable is read once, set True, held for `hold` seconds and set False again (always, even after an error). A callable performs the whole pulse itself and should return within 0.1 s, because the pulse is the one step of a scan that Stop cannot interrupt. A read-only variable raises `ValueError`, anything else that is not callable raises `TypeError`.
- `ready`: a PyRogue variable (read with `get()`) or a callable returning a bool. It reads True when the receiver is usable again.
- Handshake: the reset pulse, then up to `fallWait` seconds for `ready` to read False (not seeing it fall is recorded and is not an error), then up to `timeout` seconds for it to read True, then `settle` seconds. A `ready` that never returns ends the activation `NOT_ENABLED`. The default `timeout` is about ten times the longest relock measured on KCU1500 GTH lanes (0.55 s).
- Registering only stores the hook. `clearRxReset()` drops it, and the `RxResetHook` variable shows the registered objects or `none`.
- During a scan the engine also reads `ready` around every point to catch a link drop: the point is discarded and measured again once, and a second drop ends the scan `UNLOCKED`. The recovery repeats the eye-centre run of the activation, because the PHY re-init behind the drop can leave the sampler out of step: a full error counter there adds the sync warning below and the scan ends `CLOSED` with every point kept.

The pgp-pcie-apps `PgpRoot` wires the hook of every PGP4 lane this way:

```python
gt.EyeScan.setRxReset(reset=laneDev.Ctrl.ResetRx, ready=laneDev.RxStatus.PhyRxActive)
```

### Reset policy

`ResetPolicy` (the `ResetPolicy` variable, or the `resetPolicy` argument of a call) is `Auto` (default), `Always` or `Never`.

- `Auto` and `Always` reset the RX on every activation and refuse the scan with `NOT_ENABLED` when no hook is registered. Nothing is scanned and no enable is written in that case.
- `Never` sets the enables without a reset; use it to look at the lane as it is.
- `ES_EYE_SCAN_EN` and `ES_ERRDET_EN` stay set after a scan. Every other register a scan touches is restored, also after an abort or an error.

### Scan modes and PyDM variables

`Mode` selects what Start runs: `Bathtub` (horizontal sweep), `Eye` (2D eye) or `Margin` (default: the 2D eye, then a step-1 horizontal and vertical bathtub through the eye centre, with the openings extrapolated to `TargetBer`). The knobs below are read once at Start; a change while a scan runs applies to the next Start.

| Variable | Default | Meaning |
|----------|---------|---------|
| `Mode` | Margin | `Bathtub`, `Eye` or `Margin` |
| `ResetPolicy` | Auto | `Auto`, `Always` or `Never` |
| `Equalizer` | dfe | `dfe` sums the UT_SIGN 0 and 1 counts, `lpm` uses UT_SIGN 0 |
| `EyeBerFloor` | 1e-6 | BER every eye position must prove in Eye and Margin mode |
| `BathtubBerFloor` | 1e-9 | BER every bathtub position must prove in Bathtub mode and in the Margin cross |
| `TargetBer` | 1e-12 | BER the openings are extrapolated to |
| `Confidence` | 0.95 | one-sided confidence of every bound |
| `HorzStep` | 2 | counts between horizontal positions of the eye and of the Bathtub mode sweep |
| `VertStep` | 4 | codes between vertical positions of the eye |
| `LineRateGbps` | 0 | lane line rate; 0 makes the scan measure it with one extra run and warn |
| `SavePng` | True | render the PNGs of a Start run (a stopped scan never renders them) |
| `OutputDir` | `.` | folder of the result files, resolved to an absolute path when saved |
| `HorzRange`, `VertRange` | 0 | hidden; largest offset of the eye and cross, 0 for the full range |
| `MaxTimePerRun` | 30 s | hidden; seconds a sampler run may count before it is stopped and its partial counts are used (see `TIMEOUT`) |

State and results (read only): `Family`, `Status` (`Idle` before the first run, `Running` during a scan, else the status of the last run from the table below), `ResultFile` (npz path of the last save, empty when the last run was not saved), `RxResetHook`, `HorzOpeningUI`, `VertOpeningCodes`, `BerAtCenter` (a point without errors reads `BER < X at 95%`, never BER 0), `HwVerified` and `EtaSeconds`. `EtaSeconds` is the worst-case scan time before Start (the measured estimate while scanning); it is NaN until `LineRateGbps` is set or a scan has measured the rate, and it reads no hardware. The process members `Start`, `Stop`, `Progress`, `Message` and `Running` come from `pyrogue.Process`.

Stop returns within 1 s: the scan ends `ABORTED`, the registers are restored and the partial npz and CSV are saved without PNGs. A client in another process can read `Progress` during a scan.

At the default grid of RXOUT_DIV 2 (6.25 Gb/s) the eye is 65 columns by 63 rows (horizontal step 2 over +-64 counts, vertical step 4 over +-124 codes).

### Statuses

Every scan returns a typed status and keeps the points it measured.

| Status | Meaning |
|--------|---------|
| `OK` | the scan completed and, for Eye and Margin, the eye centre is open |
| `CLOSED` | the scan completed and found no opening, or the lane delivers no usable data (the eye-centre run stayed out of step, or the runs at the two ends of the UI counted no errors, whatever the step and range; see below) |
| `UNLOCKED` | the link dropped twice during the scan, did not return within the hook `timeout` after a drop, or a run without a hook ended with no samples |
| `NOT_ENABLED` | the sampler could not be activated: no hook under `Auto` or `Always`, a `ready` that never returns, enables that do not read back set, or a sampler run that reached no END or counted no samples |
| `TIMEOUT` | a stopped run counted no samples, or the sampler did not return to idle, while `ready` read True (a stuck sampler); a run that reaches `MaxTimePerRun` after counting samples is stopped and its partial counts are used |
| `ABORTED` | Stop or `ScanControl.abort()` |
| `ERROR` | an invalid parameter on the Start path, a failed register restore, or an analysis that failed after the scan (the measured counts are kept and saved) |

Sync check. After the RX reset the activation probes the eye centre of a working link, which is clean and ends with a full sample counter. A full error counter there means the sampler is out of step with the data sampler, or the receiver delivers no data. Under `Auto` and `Always` the hook is called again, up to 12 resets in all, and from the third reset on the enables are cleared and set again before the reset. If the centre stays full (or under `Never`), the scan continues and reports what it measures: it ends `CLOSED` with a warning in the message, in the scan warnings (`meta['warnings']`) and in `ActivationResult.syncWarning` that names both causes, "the eye-scan sampler is out of step with the data sampler, or the link is closed or unlocked". After a clean activation the probe and every Bathtub, Eye and Margin run the sampler at both ends of the UI: at `+half` and, when that run counted no errors, at `-half`, whatever the step and range of the scan. A live link shows its data transitions there, so no errors at both ends is the same warning, and the result is `CLOSED` with every measured point kept. An edge run that counts no samples ends the probe `NOT_ENABLED` and, in a scan, leaves the lane to the scan points (a run without samples is a link drop). The check costs one fast run on a live lane and at most two runs of `probeWindow` plus the 1 s idle wait, 6 s at the defaults, per activation. Earlier versions refused such a lane with `NOT_ENABLED`; a missing hook or a `ready` that never returns still ends `NOT_ENABLED`.

Measured on QSFP[0] lanes 0 to 3 of two cards, with the QSFP module present and no fiber (link status read before the runs; the module and the missing fiber were not confirmed by hand), 6.25 Gb/s images, `Auto` policy except where noted, default floors and grid:

| Card (family) | Probe | Bathtub | Margin | Probe with `Never` |
|---------------|-------|---------|--------|--------------------|
| KCU1500 (GTHE3) | `CLOSED`, 1.06 s | `CLOSED`, 255.7 to 256.4 s | `CLOSED`, 537.2 to 620.7 s | `CLOSED`, 0.01 s |
| Varium C1100 (GTYE4) | `NOT_ENABLED`, 0.56 to 3.15 s | `NOT_ENABLED`, 0.58 to 2.56 s | `NOT_ENABLED`, 0.56 to 2.57 s | lane 0 `CLOSED` 0.01 s, lanes 1 to 3 `NOT_ENABLED`, 0.02 to 2.01 s |

Every KCU1500 `CLOSED` carried the two-cause warning (no errors at either end of the UI, 65535 samples). On the C1100 the sampler of those lanes did not run (END with no samples, or `es_control_status` stayed OFF), so they ended `NOT_ENABLED`. On the KCU1500 lanes `PhyRxActive` read True and the sampler reached a full 65535-sample END while `LinkReady` was False, so a signal source on those lanes is not excluded. Every lane finished inside the bounds fixed before the run (probe 132.6 s, probe with `Never` 14.0 s, bathtub 504.32 s on GTHE3 and 317.06 s on GTYE4, margin 1241.69 s and 692.8 s) and every register was identical before and after apart from the two enables. Those bounds leave out the two runs at the ends of the UI, up to 6 s per activation, so the worst case of the current code is 6 s higher in every mode: probe 138.6 s, probe with `Never` 20.0 s, bathtub 510.32 s on GTHE3 and 323.06 s on GTYE4, margin 1247.69 s and 698.8 s.

### Synchronous API

All methods are on the `EyeScan` child. A scan failure is returned as a typed status; `ValueError` (invalid argument, nothing written) and `EyeScanError` (another scan holds the lock) are raised.

| Method | Returns | Notes |
|--------|---------|-------|
| `readState()` | `LaneState` | reads the enables, control, counters and the decoded width and RXOUT_DIV; no write |
| `probe(*, resetPolicy=None, probeWindow=2.0, control=None)` | `ActivationResult` | activates the sampler, reports status, sample count and timing, restores the registers |
| `softCold(*, probeWindow=2.0, control=None)` | `SoftColdResult` | clears the enables and proves the sampler stopped; needs a hook |
| `runBathtub(*, floor=1e-9, confidence=0.95, step=1, equalizer='dfe', resetPolicy=None, targetBer=1e-12, ..., outDir=None)` | `BathtubResult` | every count of the lane range spaced by `step` (129 counts at RXOUT_DIV 2), each driven to `floor` |
| `runEye(*, floor=1e-6, horzStep=2, vertStep=4, horzRange=None, vertRange=None, ...)` | `EyeResult` | 2D eye, rows measured centre-out on one activation |
| `runMargin(*, floor=1e-6, bathtubFloor=1e-9, targetBer=1e-12, ...)` | `MarginResult` | eye plus the cross, one RX reset for all of it, with a `summary` (`MarginSummary`) |
| `save(result=None, outDir=None, *, png=True, extraMeta=None, surfVersion=None)` | `SaveOutcome` | saves `lastResult` when `result` is omitted and sets `ResultFile` |
| `surf.xilinx.eyescan.loadResult(path)` | `(arrays, meta)` | reads an npz back without pickle |

The scan methods share `lineRateGbps`, `fixedPrescale`, `maxTimePerRun`, `probeWindow`, `control` and `outDir` (save the result there when given); `lineRateGbps` defaults to the `LineRateGbps` variable. `runBathtub`, `runEye` and `runMargin` also take `progressBar=True`, which shows a click progress bar on the terminal with the percent done, the ETA and the scan stage; the progress is weighted by the modelled time of each point, and a `control` passed alongside still receives the abort, progress and stage. `ScanControl(isAborted=None, onProgress=None, onMessage=None)` carries an abort flag (`abort()`) and the progress and stage callbacks; pass it as `control`. The last result of any scan is kept in `lastResult`. The Bathtub mode of Start uses `HorzStep` (default 2, 65 counts), the `runBathtub` call defaults to step 1.

### Result files

`save` (and `outDir=` on a scan call) writes, in this order, an npz, a CSV and the PNGs of the kind, each through a `.part` file that is renamed when complete. A save never overwrites: when a file of the stem exists the whole save moves to the next serial. Failures are reported in `SaveOutcome.errors` and `pngErrors`; a plotting failure never removes the data files.

File stem: `eyescan_{stamp}_{device}_{kind}`, with `stamp` the scan start as `yyyymmdd_hhmmss`, `device` the device path with every run of characters outside `A-Za-z0-9` replaced by one `_` (for example `PgpRoot_PgpGtDrp_4`) and `kind` `bathtub`, `eye` or `margin`. From the second save in the same second the serial goes after the stamp: `eyescan_{stamp}_{serial}_{device}_{kind}`. The extensions are `.npz`, `.csv`, `_bathtub.png` (bathtub and margin) and `_eye.png` (eye and margin).

npz keys per kind (counts are int64; error and bit arrays have one row per UT_SIGN):

| Kind | Keys |
|------|------|
| bathtub | `meta`, `horz_axis`, `horz_errors`, `horz_bits`, `horz_prescale`, `horz_ber`, `horz_berUpper`, `horz_isBound` |
| eye | `meta`, `eye_horzAxis`, `eye_vertAxis`, `eye_errors`, `eye_bits`, `eye_prescale`, `eye_ber`, `eye_berUpper`, `eye_isBound`, `eye_open`, `eye_measured` |
| margin | the `meta` and `eye_` keys of the eye, the seven `horz_` keys of the bathtub (as above) and the seven `vert_` keys `vert_axis`, `vert_errors`, `vert_bits`, `vert_prescale`, `vert_ber`, `vert_berUpper`, `vert_isBound` (a cross sweep the run did not reach is saved empty) |

`meta` is one JSON string: `kind`, `devicePath`, `status`, `message`, `linkDrops`, `activation`, `surfVersion`, `application` (the `extraMeta` given to `save`), and the blocks of the kind: `engine` (family, `hwVerified`, `bitsPerSample`, `rxOutDiv`, floors, `confidence`, `lineRateGbps` with its `lineRateSource`, `warnings`, `stamp`, `elapsed`, `phaseUnification`), `centre` (eye and margin), `fits` (bathtub and margin), `bathtub` (openings and flags) or `summary` (margin). NaN and infinity are stored as null.

The CSV has one row per measured point, ordered `eye`, `horz`, `vert`, with the columns

```text
kind,horz_count,horz_ui,vert_code,errors_ut0,errors_ut1,bits_ut0,bits_ut1,prescale,ber,ber_upper,is_bound,open
```

`kind` is `eye`, `horz` or `vert`, `ber` is `nan` for a point with no errors (`ber_upper` holds its bound) and `is_bound` and `open` are 0 or 1. A bathtub CSV has `kind` `horz` and `vert_code` 0.

PNG plotting imports matplotlib inside the plotting functions only; surf imports, saves and loads data without it, and `png=False` never imports it.

### Opening labels

An opening of the margin summary carries one label, in `MarginSummary.horzOpeningSource` and `vertOpeningSource` and in the summary text:

- `extrapolated`: from the Q-scale tail fits at `TargetBer`, only when both tail fits pass their quality gates and the open run does not reach the range limit.
- `measured`: the open run at the bathtub floor, because a fit failed a gate or the open run reaches the range limit. When the run reaches the scan range limit the value is a lower bound and is marked clipped. A measured axis without an extrapolation is flagged insufficient data (`insufficient_data`).
- `closed`: the cross completed and no position meets the bathtub floor. The opening is none and the text reads "none (no position meets BER <floor>)".
- `insufficient data`: the axis was not completed, or no opening is available.

The `closed` label is in the `MarginSummary`, the npz `meta` summary, the summary text and the per-lane opening lines that the pgp-pcie-apps `EyeScan.py` prints. The per-point CSV is unchanged by it: it carries no summary.

### Hardware verification

`hwVerified` of each family descriptor is the `HwVerified` variable of the child.

| Family | Driver | hwVerified | Basis |
|--------|--------|------------|-------|
| GTHE3 | `Gthe3Channel` | True | KCU1500 lanes 4 to 7 at 6.25 Gb/s. The first one-reset battery failed two repeatability checks on lane 6 and was indeterminate on lane 4; one repeat battery, fixed before the card was touched, passed every check, and the flag rests on it with the failure kept on record |
| GTYE4 | `Gtye4Channel` | True | Varium C1100 lanes 4 to 7, 6.25 Gb/s battery that passed on its first run: one card, one image, the QSFP CDR most likely disabled, phase rule `sign` kept after an undecided comparison with `rate` at 6.25, 10.3125, 15.46875 and 25 Gb/s |
| GTHE4 | `Gthe4Channel` | False | written from UG576 v1.7.1 Table C-2; no UltraScale+ GTH card was available, so the descriptor rests on the user guide and the emulated tests only |
| GTYE3 | `Gtye3Channel` | False | written from UG578 v1.4 Table B-2; no UltraScale GTY card was available, so the descriptor rests on the user guide and the emulated tests only |
| GTXE2 | `Gtxe2Channel` | not supported | no `EyeScan` child |
| GTPE2 | `Gtpe2Channel` | not supported | no `EyeScan` child |

A later re-check of lanes 4 to 7 after the activation changes: the GTHE3 openings (105, 94, 104 and 101 counts at 1e-9) stayed inside the recorded range. The GTYE4 openings (104, 104, 104 and 103 counts) were above the range of the battery on lanes 4, 5 and 7 (battery maxima 101, 101 and 100 counts) and inside the allowed band, the battery range widened by 2 counts per side, on lane 6 only. That is reported as wider, not as a pass: the QSFP module was re-seated after the battery, so the CDR is back at its power-on state while the battery most likely ran with it disabled. There is no battery with the CDR restored on record, no CDR-enabled C1100 evidence and no second card per family. The detail is in the [design record](../../../docs/plans/eyescan/README.md).

### Measured examples

Margin summary of the four GTH lanes 4 to 7 of a KCU1500 (image `XilinxKcu1500Pgp4_6Gbps`, 6.25 Gb/s), as printed by the pgp-pcie-apps `EyeScan.py --mode Margin`:

```text
Summary (E extrapolated, C clipped so a lower bound, I insufficient_data):
Lane  Mode    Status  Horz UI    Vert codes  Open area  Offset UI/codes  LR asym  TB asym  BER at centre         File
4     Margin  OK      0.766 [E]  172.0 [I]   152.250    -0.016/-10.0     -0.021   +0.038   BER < 2.6e-10 at 95%  eyescan_20261026_113918_PgpRoot_PgpGtDrp_4_margin.npz
5     Margin  OK      0.752 [E]  136.0 [I]   113.375    +0.000/+2.0      -0.024   -0.013   BER < 2.6e-10 at 95%  eyescan_20261026_114843_PgpRoot_PgpGtDrp_5_margin.npz
6     Margin  OK      0.719 [E]  80.0 [I]    70.438     -0.008/-2.0      -0.054   +0.013   BER < 2.6e-10 at 95%  eyescan_20261026_115647_PgpRoot_PgpGtDrp_6_margin.npz
7     Margin  OK      0.717 [E]  81.0 [I]    65.562     +0.000/-4.0      -0.019   +0.006   BER < 2.6e-10 at 95%  eyescan_20261026_120250_PgpRoot_PgpGtDrp_7_margin.npz
```

The same on the four GTY lanes 4 to 7 of a Varium C1100 (image `XilinxVariumC1100Pgp4_6Gbps`, 6.25 Gb/s):

```text
Summary (E extrapolated, C clipped so a lower bound, I insufficient_data):
Lane  Mode    Status  Horz UI    Vert codes  Open area  Offset UI/codes  LR asym  TB asym  BER at centre         File
4     Margin  OK      0.744 [E]  91.0 [I]    79.375     +0.000/-2.0      -0.058   +0.000   BER < 5.4e-10 at 95%  eyescan_20261027_082622_PgpRoot_PgpGtDrp_4_margin.npz
5     Margin  OK      0.744 [E]  97.0 [I]    86.188     +0.000/+0.0      -0.027   +0.050   BER < 5.4e-10 at 95%  eyescan_20261027_083013_PgpRoot_PgpGtDrp_5_margin.npz
6     Margin  OK      0.727 [E]  91.0 [I]    80.688     +0.000/-4.0      -0.060   +0.031   BER < 5.4e-10 at 95%  eyescan_20261027_083357_PgpRoot_PgpGtDrp_6_margin.npz
7     Margin  OK      0.702 [E]  97.0 [I]    82.000     +0.000/+2.0      -0.028   -0.003   BER < 5.4e-10 at 95%  eyescan_20261027_083717_PgpRoot_PgpGtDrp_7_margin.npz
```

`[E]` marks an extrapolated opening (horizontal at 1e-12), `[I]` a vertical opening that is the measured open run at 1e-9 because the Q-scale fit gate failed, and `[C]` would mark a clipped lower bound. The horizontal opening is in UI, the vertical opening in codes, the open area in UI times codes.

### Known limitations

Stated as measured on the lanes above:

- The vertical Q-scale fit gate (r2 of at least 0.95) fails at step 1 on every GTH and every GTY lane that was measured, on at least one tail. The vertical margin is therefore a measured opening at 1e-9 (`[I]`), not a 1e-12 value. Whether another fit window or gate would pass was not tried.
- The vertical opening moves with the receiver adaptation state: between RX resets of one lane it differed by up to a factor of 2.6 (GTH lane 7, 228 and 88 codes at the 1e-6 floor), and the horizontal opening moved by 7 to 15 counts over 10 resets on the GTH lanes. The cause is not separated. Compare settings within one RX reset.
- The GTYE4 descriptor `defaultDivider` is 2, which is right only at 6.25 Gb/s: RXOUT_DIV decodes 1 at 10.3125, 15.46875 and 25 Gb/s. It only affects the lane that `EtaSeconds` prices before the first scan.
- On the 25 Gb/s RS-FEC image `PhyRxInitCnt` rose by 22, 22, 7 and 26 more than the engine's resets, re-arms and enable changes account for on lanes 4 to 7 (the accounting held exactly at 6.25 and 10.3125 Gb/s). The cause is open.
- The QSFP[0] no-fiber result was taken with the default floors and grid on the code from before every scan ran the check at both ends of the UI (the scans then checked both ends only when their axis reached them). That a lane without data now ends `CLOSED` on any step or range is shown by the emulated tests, not on a card.
- Hardware evidence is one card per family, 6.25 Gb/s for the battery, the eye and the margin; the QSFP CDR state of the C1100 was never read back.

The design record lists the open risks in full: [docs/plans/eyescan/README.md](../../../docs/plans/eyescan/README.md).

### GT drivers from the user guides

`Gthe4Channel`, `Gthe4Common` (UltraScale+ GTH, UG576 v1.7.1 Tables C-2 and C-1) and `Gtye3Channel`, `Gtye3Common` (UltraScale GTY, UG578 v1.4 Tables B-2 and B-1) were generated row by row from the DRP address maps of the user guides, in the `Gtye4Channel` style: one `RemoteVariable` per table row named after the attribute, 16-bit DRP words behind a 32-bit window (`offset = address << 2`), `RO` for the read-only rows, the two-word `RX_PRBS_ERR_CNT` as one list variable, and the symbolic encodings of the tables as enums. Every field was compared with its table row before the golden lists under `tests/xilinx/eyescan` were captured. Neither family has been run on hardware.

Decisions taken where the user guides leave room:

- GTHE4 eye-scan mask arrays. UG576 Table C-2 lists `ES_SDATA_MASK0` to `ES_SDATA_MASK9` (and the qualifier words) at the GTYE4 addresses, but Table 4-20 note 1 keeps words 5 to 9 for GTY transceivers and the GTH internal datapath stays 40 bits wide (Table 4-46). The `GTHE4` descriptor therefore writes the five low words of each array with the GTHE3 40-bit masks and leaves words 5 to 9 as plain driver registers; the emulated tests check that a scan never writes them. The read-only capture words `es_rdata_byte` and `es_sdata_byte` have five words each (Table 4-21).
- GTHE4 width pairs and dividers. The GTH tables of UG576 (Tables 4-20 and 4-46) give the GTHE3 width pairs (no `RX_INT_DATAWIDTH` 2) and the dividers 1 to 16, so the `GTHE4` descriptor reuses the GTHE3 tables, and the `RXOUT_DIV` and `TXOUT_DIV` enums stop at 16. The 128 and 160 codes of `RX_DATA_WIDTH` are in the DRP table and stay in the enum, and the eye scan refuses them with the raw values.
- GTYE3 is the GTYE4 layout: ten mask words per array, 80-bit sdata bus, `RX_INT_DATAWIDTH` up to 2, dividers up to 32 (the /32 divider is refused by the scan like on GTYE4 because the half UI would not fit the offset field).
- Phase-unification bit 11 of `ES_HORZ_OFFSET`. UG578 Table 4-20 reads UltraScale GTY as 0 at or below 10 Gb/s and 1 above (the `rate` rule). Both hardware-verified families use `sign`, and on the C1100 GTYE4 lanes the two rules did not separate, so `GTYE3` and `GTHE4` keep `sign`; `phaseUnification='rate'` stays available on every scan call.
- `Gtye3Channel` declares `TX_FIFO_BYP_EN` and `TX_PI_DIV2_MODE_B` with `overlapEn`, because UG578 v1.4 Table B-2 lists both on bit 0 of DRP word 0xFB (a revision 1.4 change of that word).
- The GTHE4 `RX_PROGDIV_CFG` and `TX_PROGDIV_CFG` enums decode the binary pairs of Table C-2 to the same words as `Gtye4Channel`; the GTYE3 ones follow the UltraScale encodings of Table B-2, which differ for the 5, 16.5, 33 and 66 dividers.

When one of these families reaches hardware, run the eye-scan battery of the [design record](../../../docs/plans/eyescan/README.md) before setting `hwVerified`.

### Tests

The tests run real Rogue memory transactions against emulated GTHE3, GTHE4, GTYE3 and GTYE4 DRP memories and need no FPGA. See [tests/xilinx/eyescan/README.md](../../../tests/xilinx/eyescan/README.md) for what each file covers. From the surf root, with Rogue and the surf Python package on `PYTHONPATH`, the CI command is

```sh
PYTHONPATH="$PWD/python" python -m pytest -q -n 0 tests/xilinx/eyescan
```

and in a plain Rogue environment without cocotb and pytest-xdist

```sh
PYTHONPATH="$PWD/python" python -m pytest -q --noconftest tests/xilinx/eyescan
```

The lint command of CI is `flake8 --count python/ scripts/ tests/`.

Hardware runs use `software/scripts/EyeScan.py` of pgp-pcie-apps, which runs the `Status`, `Probe`, `Bathtub`, `Eye` and `Margin` modes on selected lanes and writes one run folder per invocation with the per-lane npz, CSV and PNG files:

```sh
python software/scripts/EyeScan.py --lanes 4-7 --mode Eye --outDir <dir>
python software/scripts/EyeScan.py --lanes 4-7 --mode Margin --outDir <dir>
```
