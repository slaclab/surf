# SURF RTL Regression Plan

## Objective
- Build a repo-wide regression system for synthesizable SURF RTL.
- Standardize on a single executable test framework so new work stays consistent.
- Make progress resumable across many context windows without re-discovery.

## Chosen Methodology
- Python-only executable test logic.
- Primary stack: `pytest + cocotb + GHDL + ruckus`.
- VHDL is allowed only for thin wrappers, shims, or required simulation models.
- Existing VHDL testbenches are reference material, not execution constraints.

## Scope
- Whole repo target.
- Phase 1 focuses on simulator-friendly modules.
- Vendor-heavy modules are deferred in phase 1 unless they become practical under the open-source flow.

## Coverage Model
- `functional_python`
  - Module has a Python-authored cocotb regression.
- `smoke_python`
  - Module has compile/elaborate coverage only.
- `wrapper_required`
  - Module needs a retained or added VHDL wrapper to expose a cocotb-friendly interface.
- `deferred_vendor_heavy`
  - Module is intentionally excluded from phase 1 executable regression.

## Generic And Configuration Policy
- Generic-heavy modules are Python-first by default.
- Build curated configuration matrices in Python.
- Do not use naive full Cartesian products for broad generic spaces.
- Compute expected behavior dynamically in Python from the active generics.

## CI And Runtime Policy
- Tier-first split.
- Separate `smoke` and `functional` regression tiers.
- Shard by subsystem only if runtime requires it.
- Keep room for PR-vs-nightly expansion later if runtime and coverage needs justify it.

## Reuse Policy
- Legacy VHDL testbenches are reference material only.
- Rewrite executable test logic in Python when migrating a module into the new regression system.
- Keep VHDL wrappers only when they make Python stimulus materially cleaner.
- Do not preserve old benches purely for historical reasons.

## Phase Breakdown
### Phase 1
- Create the regression inventory and artifact scaffolding.
- Establish shared Python regression helpers.
- Add smoke coverage for simulator-friendly modules.
- Add functional Python tests for the highest-value pilot modules and reusable blocks.
- Define the migration pattern for wrappers and generic-heavy modules.

### Phase 2
- Deepen randomized and adversarial coverage.
- Expand curated configuration sweeps for generic-heavy modules.
- Add stronger reusable scoreboards and protocol-specific helpers.
- Revisit deferred vendor-heavy modules after phase 1 baseline stability.

## Acceptance Criteria For Phase 1
- The repo has a checked-in inventory and handoff system.
- New windows can recover project state by reading the handoff artifacts only.
- The Python-only regression direction is documented and stable.
- The first pilot modules are selected and ready for implementation.
- The smoke/functional tier split is established in the plan and progress tracking.

## Open Questions And Deferred Decisions
- Whether PR-vs-nightly split is needed immediately or only after runtime data.
- Exact criteria for moving a vendor-heavy module out of `deferred_vendor_heavy`.
- Which subsystem should be the first large-scale migration after the pilot modules.
