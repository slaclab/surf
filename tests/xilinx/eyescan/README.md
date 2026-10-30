# Eye-scan tests

Tests for the statistical eye-scan support in `surf.xilinx.eyescan`. They run real
Rogue memory transactions against emulated GTHE3 and GTYE4 DRP memories
(`gthe3_eye_model.py`, `gtye4_eye_model.py`) and do not require an FPGA or an HDL
simulator.

- `test_Gthe3Registers.py`: the `Gthe3Channel` variable list compared with the
  frozen pre-change list in `gthe3_variables.json`, bit placement of the added
  variables, the shared-word read-modify-write hazard, and role resolution.
- `test_EyeScanFamilies.py`: the GTHE3 and GTYE4 families side by side: role
  and mask word resolution, the bits that share a DRP word with a scan field,
  the RESET, COUNT, END sequence and status decode, bit counts per run, mask
  word values and order, the width and RXOUT_DIV tables with their refusals,
  abort, back-to-back scans, a refused second run, start-up, `ReadAll`, polling
  and saved YAML with and without the child, both variable lists against their
  golden files, the per-family DRP address and bit-overlap table, the
  descriptor invariants, the `hwVerified` pin of GTYE4 and the `HwVerified`
  variable of its child.
- `gtye4_eye_model.py` and `gtye4_variables.json`: the GTYE4 DRP model (the GTHE3
  sampler over the `Gtye4Channel` field positions, ten mask words per array) and
  the 526 row `Gtye4Channel` variable list captured before the child was added.
  With neither `berFn` nor `eyeFn` the model is a clean link whose data
  transitions show at the two ends of the UI (`CROSSING_BER` at counts `-half`
  and `+half`), and `endSamples` makes a run that reaches END by itself hold a
  short sample count.
- `test_EyeScanDevice.py`: the auto-added `EyeScan` child: read-only state
  decode, reset-hook registration, no bus traffic at start, `ReadAll` or
  polling, exclusion from saved config and state YAML, which drivers carry the
  child, and the scan knobs and summary variables with their defaults, enums and
  groups.
- `test_EyeScanEye.py`: the 2D eye (`runEye`): default and edge-case grids,
  argument validation, signed vertical writes, centre-out rows, the shared DRP
  word, typed CLOSED, ABORTED, UNLOCKED and NOT_ENABLED results, and the npz
  result file.

- `test_EyeScanMargin.py`: the margin summary (`runMargin`): the pure pieces
  (connected open component, area asymmetry, rounding toward zero, BER text,
  result types), then emulated runs of a shifted separable eye: centre offset,
  openings at 1e-12 from one RX reset, step-1 cross geometry, open area,
  asymmetry, clipping and failed fits labelled as measured, a completed cross
  with no position at the bathtub floor labelled `closed` (summary text, npz
  meta, unchanged CSV columns), a closed eye, an abort during the cross, argument validation, and the margin and bathtub npz
  layouts.

- `test_EyeScanOutput.py`: the result files of every kind: the pinned npz key
  lists, the long-form CSV (columns, row order, zero-error points, empty
  results), never overwriting an existing file (a collision moves the save to
  the next serial), atomic npz and CSV writes, the
  save failure policy, the bathtub and eye PNGs (floor and target marks,
  upper-bound markers, plot failure isolation), surf importing and saving data
  without matplotlib, and the `EyeScan.save` mapping to `ResultFile`.

- `test_EyeScanProcess.py`: the Start and Stop path of the `EyeScan` child: the
  scan each `Mode` runs, the always-on save with the PNG policy, a stopped scan
  keeping its partial npz and CSV, status, progress and outcome messages with
  throttled writes, invalid parameters, a failing `OutputDir`, knobs changed
  while running, and a subprocess ZMQ client reading `Progress` during a
  Margin scan. A Start refused by a running synchronous scan only fills its
  `Message` (Status, `ResultFile` and the result of the running scan stay), two
  workers started at once run one scan with `Running` True until it ends, a
  synchronous scan publishes and saves before it releases the scan lock, and a
  Start run keeps the lock until its result is saved, so a synchronous scan is
  refused in between and `ResultFile` names `lastResult`. An
  analysis failure of a Start run ends ERROR with the measured counts saved, and
  a non-finite floor is refused before any bus transaction. Stop is timed at the RX reset handshake, a deep-prescale run
  (`slowFrom` and `slowReads` of the model hold a run in COUNT), the eye raster
  and the margin cross, each within 1.0 s with the registers restored in the
  same order; an abort between points keeps exactly the completed points. The
  scan knob and summary variables are covered in `test_EyeScanDevice.py`.

- `test_EyeScanEta.py`: the scan time model: `pointSeconds`, `scanPointCounts`
  and `estimateScanSeconds` against the cumulative prescale plan and against the
  points an emulated scan measures, the `EtaSeconds` link variable following the
  knobs with no bus traffic and switching to the measured estimate while a scan
  runs, and the progress weighted by modelled seconds.

- `test_EyeScanPhase.py`: the phase-unification bit of `ES_HORZ_OFFSET` on
  emulated GTHE3 and GTYE4 lanes: the `sign` and `rate` rules at 15.46875 and
  6.25 Gb/s on every run of a scan (activation probe, line-rate run and every
  point), the encoding edges and the 10 Gb/s threshold, the descriptor default,
  an unknown rule refused before any bus transaction, and the refusal of a
  `rate` scan without a line rate (keyword, descriptor default and Start path).

- `test_EyeScanSync.py`: the activation check that the sampler is in step
  with the data on emulated GTHE3 and GTYE4 lanes (`desyncResets`,
  `resetMode` and `enableDraws` of the model): an out-of-step activation is
  reset again and its bathtub is open, alternating resets cost one extra reset
  per bad activation, a reset that keeps the out-of-step state (the C1100 lane
  4 sequence) still ends in step, the reset budget absorbs up to three such
  resets in one activation; a lane whose resets never change the alignment
  (C1100 lanes 5 and 7) is brought in step by clearing and setting the enables
  before the second and later retries, stays in step through later
  activations, and a lane whose reset flips the alignment needs no re-arm. A
  sampler that stays out of step, a dead link whose centre counter is full
  after every reset, and a full counter under `Never` are scanned to `CLOSED`
  with the two-cause warning (sampler out of step, or link closed or
  unlocked) in the message, the meta warnings and
  `ActivationResult.syncWarning`, with every position measured and the
  registers restored; the probe reports `CLOSED` and an in-step activation
  carries no warning. The full error counter is the criterion, a closed eye
  whose samples follow the data stays `CLOSED` with one reset, and a re-arm
  that is aborted or hits a failing DRP write still sets both enables again.

- `test_EyeScanNoLink.py`: a lane that delivers no data, on emulated GTHE3 and
  GTYE4 lanes, in the three forms measured on cards without a link. A static
  input that counts no errors anywhere, including the two ends of the UI where
  a live link shows its data transitions, ends the full-range bathtub, eye and
  margin `CLOSED` with the two-cause warning in the message and the scan
  warnings, keeps and saves every measured point and restores the registers;
  the probe runs the sampler at `+half` and then `-half` after a clean
  activation and reports `CLOSED` with the same text, or `NOT_ENABLED` when an
  edge run counts no samples. A centre run that ends short of 65535 samples is
  treated like a full error counter, under `Auto` (reset again up to
  `SYNC_RESETS` times) and under `Never`. A run that reaches END with no
  samples during a scan, or times out while the ready signal reads False, is a
  link drop and the second one ends the scan `UNLOCKED`; a timeout with ready
  True and a stuck `point` stay `TIMEOUT`. The recovery from a first drop
  repeats the eye-centre run and, when it is clean, the edge runs, so a drop
  that leaves the sampler out of step, or that brings the lane back static,
  ends the bathtub, eye and margin `CLOSED` with the two-cause warning, also on
  a grid that misses the ends of the UI, while a drop that returns a live lane
  adds one run at `+half` and nothing else. A drop that desynchronizes the
  sampler during the horizontal or the vertical cross of a margin keeps its
  warning in the margin meta and the saved `engine.warnings`, although the eye
  was assembled before it. The scans run the two edge runs
  after every clean activation, so a static lane ends `CLOSED` at bathtub step 3
  and 5 and at eye and margin `horzStep` 3 and `horzRange` 32, while healthy
  lanes on those grids stay `OK` at the cost of one extra run at `+half`. An
  edge run without samples during a scan leaves the outcome to the points
  (`UNLOCKED`, `TIMEOUT`). Healthy lanes are unchanged.

- `test_EyeScanBathtub.py`: the two-sided horizontal bathtub (`runBathtub`) and
  its Process front end: sweep construction (every count of the lane range
  once, always containing 0), the per-point adaptive prescale, Q-scale tail
  fits and the measured and extrapolated openings, link-drop handling, typed
  `CLOSED`, `ABORTED` and `UNLOCKED` results, refusal of invalid arguments
  before any bus access, and Stop within 1 s with the registers restored. It
  also holds the `Hook` and `gauss` helpers the other eye-scan tests use.

- `test_EyeScanEngine.py`: the engine below the scans: sampler activation (reset
  policy, reset hook handshake, soft re-cold, probe boundaries, shared-word
  priming, scan lock) and one BER point (exact bit counts, the adaptive
  prescale ladder, DFE and LPM accumulation, zero-error bounds, restore, abort
  in every state), including the dead-sampler `NOT_ENABLED` cases and the
  read-modify-write of the shared DRP words.

- `test_EyeScanMath.py`: the pure numeric helpers (zero-error and Poisson upper
  bounds, bit counts, prescale selection, sdata masks, UT combination, inverse
  Q, the Q-scale tail fit, the open region and the extrapolated opening)
  against closed-form reference values and a seeded synthetic bathtub; no
  hardware model and no wall clock.

With Rogue and the SURF Python package on `PYTHONPATH`, run the CI command:

```sh
PYTHONPATH="$PWD/python" python -m pytest -q -n 0 tests/xilinx/eyescan
```

When cocotb and pytest-xdist are not installed (for example a plain Rogue
environment), skip the shared `tests/conftest.py` and the `-n` option:

```sh
PYTHONPATH="$PWD/python" python -m pytest -q --noconftest tests/xilinx/eyescan
```

See [tests/README.md](../../README.md) for the shared test conventions.
