# Batcher Regression Handoff

## Resume Point
- Start from `docs/plans/batcher-regression/plan.md`.
- The first implementation target, standalone `AxiStreamBatcher` V2 leaf
  behavior at the default 8-byte width, now has a passing cocotb regression.
- A narrow `AxiStreamBatcherAxil` common/async-clock wrapper regression is also
  in place for register readback and control propagation.
- A focused `AxiStreamBatcherEventBuilder` two-source regression is in place for
  INDEXED and ROUTED integration policy.
- Keep any further event-builder work targeted; the current pass is not an
  exhaustive source-count or generic matrix.

## Expected File Areas
- RTL wrappers: `protocols/batcher/wrappers/`
- Tests: `tests/protocols/batcher/`
- Source RTL: `protocols/batcher/rtl/`

## Immediate Next Action
- If continuing Phase 1, add only focused leaf gaps such as a compact V1 case or
  adverse forced-termination timing.
- If deepening Phase 2, keep it wrapper-specific: additional blowoff timing,
  soft-reset timing, or other AXI-Lite control-surface edge cases. Avoid
  duplicating leaf byte grammar tests.
- If deepening Phase 3, add only targeted event-builder integration cases such
  as more source-count/generic breadth, alternate route tables, external-only
  blowoff behavior, or bug-driven transition/bypass timing.

## Current Coverage
- `AxiStreamBatcher`: compacted V2 output, subframe metadata, multi-subframe
  superframes, max-subframe/idle-gap/byte-threshold termination, forced
  termination with terminal `EOFE`, output backpressure, and reset recovery.
- `AxiStreamBatcherAxil`: documented register reset/readback, threshold/count/gap
  control propagation, `softRst`, and `blowoff` drop/recovery in both common and
  independent AXI-Lite clock modes.
- `AxiStreamBatcherEventBuilder`: two-source INDEXED/ROUTED source selection,
  TDEST remap including fixed/passthrough routed bits, null counting without
  forwarding, timeout drop for a missing source followed by a clean later event,
  shared-output backpressure while both inputs contribute to an event, bypass
  skip/recovery, blowoff drop/recovery, routed transition-frame preemption,
  alternate route-table remap, non-default transition TDEST, and visible
  counter/status readback.

## Deferred Scope
- V1 and non-default stream-width leaf coverage.
- Event-builder source-count matrices and exhaustive transition/bypass timing
  permutations.

## Validation Checklist
- Latest completed:
  - `./.venv/bin/vsg -c vsg-linter.yml -f protocols/batcher/wrappers/AxiStreamBatcherWrapper.vhd protocols/batcher/wrappers/AxiStreamBatcherAxilWrapper.vhd protocols/batcher/wrappers/AxiStreamBatcherEventBuilderWrapper.vhd`
  - `PYTHONPYCACHEPREFIX=/private/tmp/surf-pycache ./.venv/bin/python -m py_compile tests/protocols/batcher/batcher_test_utils.py tests/protocols/batcher/test_AxiStreamBatcher.py tests/protocols/batcher/test_AxiStreamBatcherAxil.py tests/protocols/batcher/test_AxiStreamBatcherEventBuilder.py`
  - `./.venv/bin/python -m pytest -n 0 -q tests/protocols/batcher` (`6 passed`)
  - Stale simulator process sweep, no leftover batcher `ghdl`/`pytest`/cocotb
    processes observed
  - `git diff --check`
