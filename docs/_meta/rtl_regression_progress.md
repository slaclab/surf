# SURF RTL Regression Progress

## Summary
- Current phase: Planning complete, implementation scaffolding started
- Current subsystem: cross-cutting infrastructure
- Current focus module: `AxiStreamFifoV2`
- Last updated: 2026-03-20

## Status
| Subsystem | Inventory | Smoke | Functional | Notes |
| --- | --- | --- | --- | --- |
| Cross-cutting infrastructure | started | not started | started | Shared helper structure now lives in `tests/common/regression_utils.py`; new regressions should be package-organized |
| `base` | started | not started | started | Initial validated pilot regression exists at `tests/base/fifo/test_FifoAsync.py` |
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
- Added `scripts/setup_regression_env.sh` to bootstrap the local regression environment.
- Added `.vscode/tasks.json` with setup, import, and regression tasks.
- Installed local `ghdl` via Homebrew.
- Created `.venv`, installed Python regression dependencies, linked `~/ruckus`, and completed `make MODULES="$PWD" import`.
- Added shared regression helpers in `tests/regression_utils.py`.
- Implemented the first Python pilot regression in `tests/base/fifo/test_FifoAsync.py`.
- Validated `tests/base/fifo/test_FifoAsync.py` locally with `python -m pytest -v tests/base/fifo/test_FifoAsync.py`.
- Reorganized new regressions into subsystem packages under `tests/` and moved shared helpers to `tests/common/`.
- Added `tests/README.md` to document the regression layout policy.
- Ran a quick HDL coverage spike against the local Homebrew `ghdl` build and confirmed it does not expose `--coverage` or a `coverage` subcommand.

## Current In-Progress Item
- Expand the organized shared-helper pattern and move to the next pilot module.

## Next 3 Concrete Tasks
- Create the `tests/axi/axi_stream/` package and migrate `AxiStreamFifoV2` onto the shared helper structure there.
- Decide whether `AxiLiteAsync` should get a new thin wrapper instead of reusing the legacy tb file directly, and place that regression under `tests/axi/axi_lite/`.
- Expand `FifoAsync` coverage to include additional configurations or edge-case pulses after the next pilot is stable.

## Blockers And Risks
- Runtime may grow quickly once configuration-heavy modules are added without careful tiering.
- Wrapper policy must stay narrow or VHDL cruft will accumulate again.
- HDL source coverage is not immediately available with the current local `ghdl` LLVM build; it needs a separate tooling decision if we want it later.

## Findings Worth Preserving
- Existing Python regressions are generally the best reusable verification assets.
- Existing VHDL TBs contain useful behavioral intent but are inconsistent as a scalable execution framework.
- Generic-heavy modules strongly favor Python-authored tests.
- Broad repo coverage will require tiering and likely later sharding.
- The initial inventory file should remain small and explicit rather than auto-generated until the schema stabilizes.
- `AxiStreamFifoV2` already has a useful wrapper-plus-Python pattern; `AxiLiteAsync` likely needs wrapper cleanup before it fits the new model.
- The local machine needs a reproducible one-command bootstrap path before test implementation work can move efficiently.
- The bootstrap path is now working locally with `~/ruckus` linked into the repo.
- The first shared-helper-based pilot is working; start simple and grow coverage incrementally rather than front-loading every edge case.
- New regressions need to live in subsystem packages from the start; do not add more flat `tests/test_*.py` files.
- The current Homebrew `ghdl` install is sufficient for cocotb regressions but not for a simple built-in HDL coverage flow.

## Log
- 2026-03-20: Agreed on Python-only executable regression logic and wrapper-only VHDL retention.
- 2026-03-20: Agreed on whole-repo scope with simulator-friendly phase 1 and vendor-heavy deferral.
- 2026-03-20: Agreed to add stable handoff artifacts under `docs/_meta/` before deeper implementation work.
- 2026-03-20: Added `docs/_meta/rtl_regression_inventory.yaml` and seeded it with the first three pilot modules.
- 2026-03-20: Added local bootstrap helpers in `scripts/setup_regression_env.sh` and `.vscode/tasks.json`.
- 2026-03-20: Installed local toolchain and completed the first successful `make MODULES="$PWD" import`.
- 2026-03-20: Added `tests/regression_utils.py` and landed the first passing pilot regression for `FifoAsync`.
- 2026-03-20: Moved new regression infrastructure to `tests/common/`, relocated `FifoAsync` to `tests/base/fifo/`, and documented the subsystem-organized test layout.
- 2026-03-20: Checked local HDL coverage viability; the installed LLVM-backed `ghdl` rejects `--coverage`, so HDL coverage is deferred pending a different simulator/backend decision.
