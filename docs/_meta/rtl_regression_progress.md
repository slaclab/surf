# SURF RTL Regression Progress

## Summary
- Current phase: Planning complete, implementation scaffolding started
- Current subsystem: axi
- Current focus module: `AxiLiteAsync`
- Last updated: 2026-03-20

## Status
| Subsystem | Inventory | Smoke | Functional | Notes |
| --- | --- | --- | --- | --- |
| Cross-cutting infrastructure | started | not started | started | Shared helper structure now lives in `tests/common/regression_utils.py`; pytest now defaults to `xdist` parallel execution via `pytest.ini` |
| `base` | started | not started | started | Expanded validated `FifoAsync` matrix exists at `tests/base/fifo/test_FifoAsync.py` |
| `axi` | started | not started | started | `AxiStreamFifoV2` is now validated in `tests/axi/axi_stream/`; `AxiLiteAsync` is next |
| `protocols` | not started | not started | not started | Large simulator-friendly surface area |
| `ethernet` | not started | not started | not started | Likely phase 1 later stage |
| `devices` | not started | not started | not started | Many vendor-heavy cases |
| `xilinx` | not started | not started | not started | Many vendor-heavy cases |

## Completed Decisions
- Use Python-only executable test logic.
- Use `pytest + cocotb + GHDL + ruckus` as the primary stack.
- Keep VHDL only for wrappers, shims, and required simulation models.
- Comment new Python regression code so non-obvious test intent and framework behavior are documented in-place.
- Whole repo is the long-term target.
- Phase 1 focuses on simulator-friendly modules.
- Vendor-heavy modules are deferred in phase 1.
- Generic-heavy modules are Python-first.
- Use curated configuration matrices instead of full Cartesian products.
- Keep a tier-first CI model: `smoke` and `functional`.
- Rewrite legacy VHDL TB logic in Python rather than preserving it by default.
- Keep wrappers only when they make Python interaction cleaner.
- Treat VHDL packages as transitively covered unless a behavioral function/procedure needs a dedicated wrapper.

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
- Migrated `AxiStreamFifoV2` into `tests/axi/axi_stream/test_AxiStreamFifoV2IpIntegrator.py` and validated the current 10-case sweep locally.
- Expanded `FifoAsync` into a curated 12-case matrix and validated it locally under parallel pytest execution.
- Added `pytest.ini` to default to `-n auto --dist=worksteal`, and aligned CI to rely on that default xdist configuration.

## Current In-Progress Item
- Start the `AxiLiteAsync` pilot with a purpose-built thin wrapper under the AXI-Lite test package.

## Next 3 Concrete Tasks
- Add a thin cocotb-friendly wrapper for `AxiLiteAsync` because the existing VHDL tb contains verification logic, not just interface exposure.
- Implement `tests/axi/axi_lite/test_AxiLiteAsync.py` using the shared helper structure and the new wrapper.
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
- The existing `AxiLiteAsyncTb.vhd` is useful as intent/reference, but it is not an appropriate long-term wrapper because it embeds clocks, memories, and transaction logic.
- Future Python regression code should continue the current comment style: explain non-obvious intent and framework mechanics, but avoid line-by-line narration.
- `FifoAsync` needed a curated matrix rather than a naive Cartesian sweep: standard FIFO mode, FWFT mode, and pipelined FWFT do not share identical read/full semantics.
- VHDL packages should not become top-level test targets by default; only high-value behavioral helpers warrant dedicated wrapper tests.

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
- 2026-03-20: Migrated `AxiStreamFifoV2` into `tests/axi/axi_stream/` and validated the full current 10-case sweep in 146s.
- 2026-03-20: Added an explicit project rule to comment new Python regression code where intent or runner behavior is not self-evident.
- 2026-03-20: Expanded `FifoAsync` to a validated 12-case parameter matrix and enabled default pytest xdist parallelization with `pytest.ini`.
- 2026-03-20: Added package-coverage policy: packages are covered transitively unless a behavioral helper warrants a dedicated wrapper test.
