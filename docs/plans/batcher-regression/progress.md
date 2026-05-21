# Batcher Regression Progress

## Status
- Current phase: Phase 2 AXI-Lite wrapper implementation started.
- Current implementation gate: `AxiStreamBatcher` V2 8-byte leaf coverage and
  `AxiStreamBatcherAxil` common-clock register/control coverage are validated
  locally.
- Current target: keep any further `AxiStreamBatcherAxil` work register/control
  specific, then move to `AxiStreamBatcherEventBuilder` if needed.

## Decisions
- Use a standalone leaf-first strategy.
- Use Python/cocotb for executable stimulus and scoreboards.
- Use a thin checked-in wrapper only when the native record interface is too
  awkward for direct cocotb stimulus.
- Keep high-level wrapper tests focused on register/control/integration policy
  instead of re-proving the full leaf packet grammar.

## Draft Work In This Session
- Added a thin cocotb-facing wrapper at
  `protocols/batcher/wrappers/AxiStreamBatcherWrapper.vhd`.
- Added a common-clock AXI-Lite wrapper at
  `protocols/batcher/wrappers/AxiStreamBatcherAxilWrapper.vhd`.
- Added shared batcher helpers in
  `tests/protocols/batcher/batcher_test_utils.py`.
- Added a standalone leaf regression in
  `tests/protocols/batcher/test_AxiStreamBatcher.py`.
- Added an AXI-Lite wrapper regression in
  `tests/protocols/batcher/test_AxiStreamBatcherAxil.py`.
- Covered V2 compacted output for the default 8-byte width: superframe header
  bytes, subframe payload/tail bytes, multiple subframes per superframe,
  termination by max-subframe count, idle gap, byte threshold, forced
  termination with terminal `EOFE`, output backpressure stability, and reset
  recovery after a partial superframe.
- Covered `AxiStreamBatcherAxil` reset/readback for the documented register map,
  control propagation for max-subframe count, byte threshold, and clock gap,
  `softRst` recovery from a partial superframe, and `blowoff` accept/drop
  behavior followed by normal recovery traffic.

## Validation
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/batcher/wrappers/AxiStreamBatcherWrapper.vhd protocols/batcher/wrappers/AxiStreamBatcherAxilWrapper.vhd`
  passed with zero violations.
- `PYTHONPYCACHEPREFIX=/private/tmp/surf-pycache ./.venv/bin/python -m py_compile tests/protocols/batcher/batcher_test_utils.py tests/protocols/batcher/test_AxiStreamBatcher.py tests/protocols/batcher/test_AxiStreamBatcherAxil.py`
  passed.
- `./.venv/bin/python -m pytest -n 0 -q tests/protocols/batcher` passed with
  `2 passed`.
- Stale simulator process sweep did not show leftover `ghdl`, `pytest`, or
  cocotb batcher processes.
- `git diff --check` passed for tracked changes. The new batcher files are
  still untracked, so whitespace on those files was also covered by `vsg` and
  `py_compile`.

## Next Steps
1. Keep Phase 1 intentionally narrow unless a change touches the batcher leaf:
   possible next leaf additions are a small V1/power-of-two-width case or more
   adverse `forceTerm` timing.
2. If Phase 2 deepens, stay focused on wrapper-specific behavior such as async
   AXI-Lite crossing or additional malformed/blowoff timing; do not duplicate
   the full leaf byte grammar.
3. Start Phase 3 event-builder coverage with small `NUM_SLAVES_G` cases and
   reuse the leaf byte-stream helpers for final output shape.
