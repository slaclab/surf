# Eye-scan command-line runner

## Goal and scope

Move the generic part of the pgp-pcie-apps `software/scripts/PgpEyeScan.py`
(Status, Probe, Bathtub, Eye and Margin runs, the checks, the summaries, the
result files and the Ctrl-C handling) into surf, so that every application
repository (pgp-pcie-apps, lcls2-pgp-pcie-apps and later ones) keeps only a
short script that builds its root and names its lanes. Usage is in
[python/surf/xilinx/README.md](../../../python/surf/xilinx/README.md), section
"Command-line runner".

## Current status

- `surf.xilinx.eyescan._EyeScanRunner` (`addEyeScanArguments`,
  `prepareEyeScan`, `runEyeScan`, `EyeScanLane`, `EyeScanLink`,
  `RawWordReader`) and `surf.protocols.pgp.Pgp4EyeScanLink` exist and are
  exported.
- 28 of the script's functions moved unchanged (compared by AST); the 14 that
  changed are the points where the script reached into the pgp-pcie-apps device
  tree. The argument set is the script's minus `--dev`, `--boardType` and
  `--numLane`; the `--lanes` default is every lane and the `--lineRate` default
  is 0, which an application restores with `parser.set_defaults`.
- The PGP application scripts are not converted yet. The first hardware run
  through the new entry point was a JESD lane (below).
- `surf.protocols.jesd204b.JesdRxEyeScanLink` is the second adapter: one lane
  of a `JesdRx` core, hook on the shared `ResetGTs` with the lane's `DataValid`
  bit as ready, tested over emulated GTHE3 and GTHE4 JESD lanes. The shared
  reset brought `EyeScanLink.resetGroup()` to the runner: two selected lanes
  with the same key are refused `--parallel true` in `checkLanes`. Status, Probe,
  Bathtub and Eye ran `OK` on the four GTHE3 lanes of an AMC carrier (8B10B,
  7.02 Gb/s) from an application script on `runEyeScan`.

## Decisions

- surf, not axi-pcie-core: the runner only uses surf devices (the `EyeScan`
  child, `Pgp4AxiL`, `AxiVersion`), boards without axi-pcie-core need eye scans
  too, and the emulated GT models that test it are already here. The
  board-type to GT channel class map is PCIe card knowledge and belongs in
  axi-pcie-core instead.
- The application hands lanes, not a root: `EyeScanLane(lane, gt, link)`.
  The runner never looks up a device path.
- No memory map argument: raw evidence words are read by a read-only
  `RawWordReader` connected to the GT device (and by the link adapter to its
  own device), so the addresses are offsets within the device and lanes behind
  different memory trees run in one call.
- Link evidence goes through an adapter (`EyeScanLink`) so a non-PGP4 lane
  still scans; `--loopback` is refused on a lane whose adapter has no
  loopback control.
- Checks stay ahead of the hardware: `prepareEyeScan` refuses invalid
  arguments and lane lists before the root is built, and `runEyeScan` refuses
  missing or unfit lanes with reads only and removes the empty run folder.
- The SIGINT handler is installed only from the main thread and the previous
  handler is restored when the run ends. The handler only sets the stop flag
  of the run: it takes no lock (it runs on the main thread between two of its
  bytecodes, so a lock held by that thread would never be released) and keeps
  no registry of live controls. Every lane control reads the flag through
  `ScanControl(isAborted=...)`, so a lane that starts after the Ctrl-C ends
  `ABORTED` before its soft re-cold, loopback or scan writes anything, and a
  stop request always returns 2 (review of PR #1519).

## Files

- `python/surf/xilinx/eyescan/_EyeScanRunner.py`, `python/surf/xilinx/eyescan/__init__.py`
- `python/surf/protocols/pgp/_Pgp4EyeScanLink.py`, `python/surf/protocols/pgp/__init__.py`
- `python/surf/protocols/jesd204b/_JesdRxEyeScanLink.py`, `python/surf/protocols/jesd204b/__init__.py`
- `tests/xilinx/eyescan/test_EyeScanRunner.py`, `tests/xilinx/eyescan/test_JesdRxEyeScanLink.py`
  (with `makeJesdLaneRoot` in `gt_new_eye_model.py` and `LaneMemory.attachBits` in `gthe3_eye_model.py`)
- `python/surf/xilinx/README.md`, `tests/xilinx/eyescan/README.md`

## Validation

- `PYTHONPATH="$PWD/python" python -m pytest -q -n 0 tests/xilinx/eyescan`:
  1292 passed (1257 before, 35 new; Rogue v6.16.0); 1307 with the JESD
  adapter tests.
- `flake8 --count python/ scripts/ tests/`: 0.

## Next steps

- axi-pcie-core: a public board-type to GT channel class map, replacing the
  copies in pgp-pcie-apps `_PgpRoot.py` and lcls2-pgp-fw-lib `_Hsio.py`.
- lcls2-pgp-fw-lib: `Hsio` registers the PGP4 RX reset hook with
  `Pgp4EyeScanLink.connectRxReset`.
- pgp-pcie-apps and lcls2-pgp-pcie-apps: thin scripts on `runEyeScan`, then a
  hardware Status and Margin run on one lane of each.
- Remove this directory once the application scripts are converted and the
  hardware runs are recorded.
