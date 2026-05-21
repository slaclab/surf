# Batcher Regression Progress

## Status
- Current phase: planning.
- Current implementation gate: do not expand batcher tests until this plan is
  reviewed.
- Current target: `AxiStreamBatcher` leaf regression first, then
  `AxiStreamBatcherAxil`, then `AxiStreamBatcherEventBuilder` if needed.

## Decisions
- Use a standalone leaf-first strategy.
- Use Python/cocotb for executable stimulus and scoreboards.
- Use a thin checked-in wrapper only when the native record interface is too
  awkward for direct cocotb stimulus.
- Keep high-level wrapper tests focused on register/control/integration policy
  instead of re-proving the full leaf packet grammar.

## Draft Work In This Session
- A local draft wrapper/helper/test may exist in the working tree from initial
  exploration. Treat it as implementation draft material, not as accepted final
  scope, until this plan is approved and any remaining planned coverage is
  reviewed against it.

## Validation
- No validation is required for the plan-only checkpoint.

## Next Steps
1. Review and approve or adjust `plan.md`.
2. If approved, finish Phase 1 leaf-batcher coverage.
3. Run focused lint, syntax, pytest, stale-process sweep, and diff checks.
4. Update this progress file with actual validated results.
