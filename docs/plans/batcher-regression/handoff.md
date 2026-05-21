# Batcher Regression Handoff

## Resume Point
- Start from `docs/plans/batcher-regression/plan.md`.
- The first implementation target, standalone `AxiStreamBatcher` V2 leaf
  behavior at the default 8-byte width, now has a passing cocotb regression.
- A narrow `AxiStreamBatcherAxil` common-clock wrapper regression is also in
  place for register readback and control propagation.
- Do not start broad `AxiStreamBatcherEventBuilder` coverage until the leaf and
  AXI-Lite wrapper tests remain green in the current worktree.

## Expected File Areas
- RTL wrappers: `protocols/batcher/wrappers/`
- Tests: `tests/protocols/batcher/`
- Source RTL: `protocols/batcher/rtl/`

## Immediate Next Action
- If continuing Phase 1, add only focused leaf gaps such as a compact V1 case or
  adverse forced-termination timing.
- If deepening Phase 2, keep it wrapper-specific: async AXI-Lite crossing,
  additional blowoff timing, or soft-reset timing. Avoid duplicating leaf byte
  grammar tests.
- If moving to Phase 3, start with small event-builder source-count cases and
  reuse the batcher byte-stream helpers for final output shape.

## Validation Checklist
- Latest completed:
  - `./.venv/bin/vsg -c vsg-linter.yml -f protocols/batcher/wrappers/AxiStreamBatcherWrapper.vhd protocols/batcher/wrappers/AxiStreamBatcherAxilWrapper.vhd`
  - `PYTHONPYCACHEPREFIX=/private/tmp/surf-pycache ./.venv/bin/python -m py_compile tests/protocols/batcher/batcher_test_utils.py tests/protocols/batcher/test_AxiStreamBatcher.py tests/protocols/batcher/test_AxiStreamBatcherAxil.py`
  - `./.venv/bin/python -m pytest -n 0 -q tests/protocols/batcher` (`2 passed`)
  - Stale simulator process sweep, no leftover batcher `ghdl`/`pytest`/cocotb
    processes observed
  - `git diff --check`
