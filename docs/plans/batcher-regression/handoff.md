# Batcher Regression Handoff

## Resume Point
- Start from `docs/plans/batcher-regression/plan.md`.
- The first implementation target is `AxiStreamBatcher` leaf behavior.
- Do not start with `AxiStreamBatcherAxil` or `AxiStreamBatcherEventBuilder`
  until the leaf contract is pinned down.

## Expected File Areas
- RTL wrappers: `protocols/batcher/wrappers/`
- Tests: `tests/protocols/batcher/`
- Source RTL: `protocols/batcher/rtl/`

## Immediate Next Action
- Confirm the plan scope with the user.
- Then continue or revise the Phase 1 standalone `AxiStreamBatcher` tests.

## Validation Checklist
- `./.venv/bin/vsg -c vsg-linter.yml -f <edited wrapper files>`
- `PYTHONPYCACHEPREFIX=/private/tmp/surf-pycache ./.venv/bin/python -m py_compile <edited python files>`
- `./.venv/bin/python -m pytest -n 0 -q tests/protocols/batcher`
- Stale simulator process sweep
- `git diff --check`
