# SURF RTL Regression Progress

## Summary
- Current phase: Planning complete, implementation scaffolding started
- Current subsystem: Cross-cutting infrastructure
- Current focus module: Inventory scaffold and pilot selection
- Last updated: 2026-03-20

## Status
| Subsystem | Inventory | Smoke | Functional | Notes |
| --- | --- | --- | --- | --- |
| Cross-cutting infrastructure | started | not started | not started | Handoff artifacts and inventory scaffold are checked in under `docs/_meta/` |
| `base` | started | not started | not started | Pilot selected: `FifoAsync` |
| `axi` | started | not started | not started | Pilots selected: `AxiStreamFifoV2` and `AxiLiteAsync` |
| `protocols` | not started | not started | not started | Large simulator-friendly surface area |
| `ethernet` | not started | not started | not started | Likely phase 1 later stage |
| `devices` | not started | not started | not started | Many vendor-heavy cases |
| `xilinx` | not started | not started | not started | Many vendor-heavy cases |

## Completed Decisions
- Use Python-only executable test logic.
- Use `pytest + cocotb + GHDL + ruckus` as the primary stack.
- Keep VHDL only for wrappers, shims, and required simulation models.
- Whole repo is the long-term target.
- Phase 1 focuses on simulator-friendly modules.
- Vendor-heavy modules are deferred in phase 1.
- Generic-heavy modules are Python-first.
- Use curated configuration matrices instead of full Cartesian products.
- Keep a tier-first CI model: `smoke` and `functional`.
- Rewrite legacy VHDL TB logic in Python rather than preserving it by default.
- Keep wrappers only when they make Python interaction cleaner.

## Completed Work Items
- Surveyed repo structure and existing verification flow.
- Reviewed existing Python regressions and representative VHDL testbenches.
- Compared `cocotb + pytest`, `VUnit`, and `OSVVM` for SURF.
- Chose Python-only executable regression logic.
- Defined the context-handoff artifact set.
- Created the checked-in handoff artifacts under `docs/_meta/`.
- Created the initial regression inventory scaffold in `docs/_meta/rtl_regression_inventory.yaml`.
- Selected and documented the first pilot modules: `FifoAsync`, `AxiStreamFifoV2`, and `AxiLiteAsync`.

## Current In-Progress Item
- Define the shared Python regression helper structure and migrate the first pilot into it.

## Next 3 Concrete Tasks
- Define the shared Python regression helper structure for simulator invocation, compile flags, and generic sweeps.
- Decide whether `AxiLiteAsync` should get a new thin wrapper instead of reusing the legacy tb file directly.
- Implement the first pilot regression, with `FifoAsync` as the cleanest starting point.

## Blockers And Risks
- `ruckus` is not present in the current local checkout, so local import/build flow is not immediately runnable.
- Runtime may grow quickly once configuration-heavy modules are added without careful tiering.
- Wrapper policy must stay narrow or VHDL cruft will accumulate again.

## Findings Worth Preserving
- Existing Python regressions are generally the best reusable verification assets.
- Existing VHDL TBs contain useful behavioral intent but are inconsistent as a scalable execution framework.
- Generic-heavy modules strongly favor Python-authored tests.
- Broad repo coverage will require tiering and likely later sharding.
- The initial inventory file should remain small and explicit rather than auto-generated until the schema stabilizes.
- `AxiStreamFifoV2` already has a useful wrapper-plus-Python pattern; `AxiLiteAsync` likely needs wrapper cleanup before it fits the new model.

## Log
- 2026-03-20: Agreed on Python-only executable regression logic and wrapper-only VHDL retention.
- 2026-03-20: Agreed on whole-repo scope with simulator-friendly phase 1 and vendor-heavy deferral.
- 2026-03-20: Agreed to add stable handoff artifacts under `docs/_meta/` before deeper implementation work.
- 2026-03-20: Added `docs/_meta/rtl_regression_inventory.yaml` and seeded it with the first three pilot modules.
