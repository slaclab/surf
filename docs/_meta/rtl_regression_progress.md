# SURF RTL Regression Progress

## Summary
- Current phase: Planning complete, implementation scaffolding started
- Current subsystem: base
- Current focus module: post-batch planning after the 15-module `base` general/delay/sync rollout
- Last updated: 2026-03-20

## Status
| Subsystem | Inventory | Smoke | Functional | Notes |
| --- | --- | --- | --- | --- |
| Cross-cutting infrastructure | started | not started | started | Shared helper structure now lives in `tests/common/regression_utils.py`; pytest now defaults to `xdist` parallel execution via `pytest.ini` |
| `base` | started | not started | started | Validated low-level regressions now exist for `FifoAsync`, `FifoSync`, `FifoOutputPipeline`, `FifoWrFsm`, `FifoRdFsm`, `Synchronizer`, `SynchronizerVector`, `SynchronizerEdge`, `SynchronizerOneShot`, `SynchronizerFifo`, `SynchronizerOneShotCnt`, `RstSync`, `RstPipeline`, `RstPipelineVector`, `PwrUpRst`, `Arbiter`, `ClockDivider`, `Debouncer`, `Gearbox`, `Heartbeat`, `Mux`, `OneShot`, `RegisterVector`, `WatchDogRst`, `Scrambler`, `SimpleDualPortRam`, `TrueDualPortRam`, `LutRam`, `SlvDelay`, `SlvFixedDelay`, `Crc32Parallel`, `Crc32`, and `CRC32Rtl` under subsystem-organized `tests/base/` packages |
| `axi` | started | not started | started | `AxiStreamFifoV2` is now validated in `tests/axi/axi_stream/`; `AxiLiteAsync` is deferred while bottom-up base coverage expands |
| `protocols` | not started | not started | not started | Large simulator-friendly surface area |
| `ethernet` | not started | not started | not started | Likely phase 1 later stage |
| `devices` | not started | not started | not started | Many vendor-heavy cases |
| `xilinx` | not started | not started | not started | Many vendor-heavy cases |

## Completed Decisions
- Use Python-only executable test logic.
- Use `pytest + cocotb + GHDL + ruckus` as the primary stack.
- Keep VHDL only for wrappers, shims, and required simulation models.
- Comment new Python regression code at a tutorial level so readers who are new to cocotb can follow the flow in-place.
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
- Validated `tests/base/fifo/test_FifoAsync.py` locally with `./.venv/bin/python -m pytest -v tests/base/fifo/test_FifoAsync.py`.
- Reorganized new regressions into subsystem packages under `tests/` and moved shared helpers to `tests/common/`.
- Added `tests/README.md` to document the regression layout policy.
- Ran a quick HDL coverage spike against the local Homebrew `ghdl` build and confirmed it does not expose `--coverage` or a `coverage` subcommand.
- Migrated `AxiStreamFifoV2` into `tests/axi/axi_stream/test_AxiStreamFifoV2IpIntegrator.py` and validated the current 10-case sweep locally.
- Expanded `FifoAsync` into a curated 12-case matrix and validated it locally under parallel pytest execution.
- Added `pytest.ini` to default to `-n auto --dist=worksteal`, and aligned CI to rely on that default xdist configuration.
- Implemented `tests/base/fifo/test_FifoSync.py` and validated its 11-case matrix locally under parallel pytest execution.
- Added `scripts/build_rtl_instantiation_graph.py` and generated checked-in graph artifacts in `docs/_meta/rtl_instantiation_graph.{md,json}`.
- Implemented `tests/base/sync/test_Synchronizer.py` and validated its 6-case matrix locally under parallel pytest execution.
- Implemented `tests/base/sync/test_SynchronizerVector.py` and validated its 6-case matrix locally under parallel pytest execution.
- Implemented `tests/base/general/test_RstPipeline.py` and validated its 4-case matrix locally under parallel pytest execution.
- Implemented `tests/base/ram/test_SimpleDualPortRam.py` and validated its 5-case matrix locally under parallel pytest execution.
- Implemented `tests/base/fifo/test_FifoOutputPipeline.py` and validated its 5-case matrix locally under parallel pytest execution.
- Implemented `tests/base/fifo/test_FifoWrFsm.py` and validated its 4-case matrix locally under parallel pytest execution.
- Extended `tests/common/regression_utils.py` so regressions can add test-local VHDL wrapper sources when simulator limitations make a thin shim cleaner than direct generic overrides.
- Implemented `tests/base/crc/test_Crc32Parallel.py`, `tests/base/crc/test_Crc32.py`, and `tests/base/crc/test_CRC32Rtl.py` and validated their combined 9-case CRC batch locally under parallel pytest execution.
- Implemented `tests/base/sync/test_RstSync.py`, `tests/base/sync/test_SynchronizerEdge.py`, and `tests/base/sync/test_SynchronizerOneShot.py` and validated their combined 11-case sync/reset batch locally under parallel pytest execution.
- Implemented `tests/base/general/test_PwrUpRst.py` and validated its 3-case matrix locally under parallel pytest execution.
- Implemented `tests/base/ram/test_TrueDualPortRam.py` and `tests/base/ram/test_LutRam.py` and validated their combined 9-case RAM batch locally under parallel pytest execution.
- Implemented `tests/base/fifo/test_FifoRdFsm.py` and validated its 4-case matrix locally under parallel pytest execution.
- Validated the full 10-module follow-on subset in one run with `./.venv/bin/python -m pytest -v tests/base/crc/test_Crc32Parallel.py tests/base/crc/test_Crc32.py tests/base/crc/test_CRC32Rtl.py tests/base/sync/test_RstSync.py tests/base/general/test_PwrUpRst.py tests/base/sync/test_SynchronizerEdge.py tests/base/sync/test_SynchronizerOneShot.py tests/base/ram/test_TrueDualPortRam.py tests/base/ram/test_LutRam.py tests/base/fifo/test_FifoRdFsm.py` (`38 passed`).
- Implemented `tests/base/general/test_Arbiter.py`, `tests/base/general/test_ClockDivider.py`, `tests/base/general/test_Debouncer.py`, `tests/base/general/test_Gearbox.py`, `tests/base/general/test_Heartbeat.py`, `tests/base/general/test_Mux.py`, `tests/base/general/test_OneShot.py`, `tests/base/general/test_RegisterVector.py`, `tests/base/general/test_RstPipelineVector.py`, `tests/base/general/test_Scrambler.py`, `tests/base/general/test_WatchDogRst.py`, `tests/base/delay/test_SlvDelay.py`, `tests/base/delay/test_SlvFixedDelay.py`, `tests/base/sync/test_SynchronizerFifo.py`, and `tests/base/sync/test_SynchronizerOneShotCnt.py`.
- Validated the full 15-module follow-on subset in one run with `./.venv/bin/python -m pytest -n 0 -q tests/base/general/test_Arbiter.py tests/base/general/test_ClockDivider.py tests/base/general/test_Debouncer.py tests/base/general/test_Gearbox.py tests/base/general/test_Heartbeat.py tests/base/general/test_Mux.py tests/base/general/test_OneShot.py tests/base/general/test_RegisterVector.py tests/base/general/test_RstPipelineVector.py tests/base/general/test_Scrambler.py tests/base/general/test_WatchDogRst.py tests/base/delay/test_SlvDelay.py tests/base/delay/test_SlvFixedDelay.py tests/base/sync/test_SynchronizerFifo.py tests/base/sync/test_SynchronizerOneShotCnt.py` (`41 passed`).
- Added a shared generated-wrapper path in `tests/common/regression_utils.py` and migrated the `Heartbeat` and `Debouncer` regressions away from checked-in one-off VHDL wrappers.
- Revalidated the generated-wrapper migration locally with `./.venv/bin/python -m pytest -n 0 -q tests/base/general/test_Heartbeat.py tests/base/general/test_Debouncer.py` (`6 passed`) and then revalidated the full 15-module batch (`41 passed`).

## Current In-Progress Item
- Choose and scope the next graph-guided `base/` follow-on after the now-validated 15-module general/delay/sync batch and the generated-wrapper helper cleanup.

## Next 3 Concrete Tasks
- Update the inventory and handoff artifacts to record the expanded covered primitive layer and the validated generated-wrapper helper path.
- Choose the next graph-guided `base/` follow-on, likely from the remaining high-reuse wrappers such as `SyncStatusVector` and adjacent vectorized helper blocks.
- Reuse the generated-wrapper helper the next time a real- or vector-generic leaf needs a cycle-friendly shim, instead of checking in another one-off HDL wrapper.

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
- Bare `python` should not be assumed to exist on `PATH` in this repo's shell environment; use `./.venv/bin/python` for local pytest and helper-script invocations unless the virtualenv is already activated.
- The first shared-helper-based pilot is working; start simple and grow coverage incrementally rather than front-loading every edge case.
- New regressions need to live in subsystem packages from the start; do not add more flat `tests/test_*.py` files.
- The current Homebrew `ghdl` install is sufficient for cocotb regressions but not for a simple built-in HDL coverage flow.
- The existing `AxiLiteAsyncTb.vhd` is useful as intent/reference, but it is not an appropriate long-term wrapper because it embeds clocks, memories, and transaction logic.
- Future Python regression code should follow the user's preferred comment style: assume limited cocotb familiarity and explain the purpose of most major coroutine steps, waits, stimulus phases, and checks in-place without turning the file into pure prose.
- `FifoAsync` needed a curated matrix rather than a naive Cartesian sweep: standard FIFO mode, FWFT mode, and pipelined FWFT do not share identical read/full semantics.
- VHDL packages should not become top-level test targets by default; only high-value behavioral helpers warrant dedicated wrapper tests.
- `FifoSync` benefits from the same curated-matrix approach as `FifoAsync`, but its threshold checks needed event-driven flag handling because `prog_full`/`prog_empty` timing did not line up with fixed write-count assumptions.
- The instantiation graph is useful for rollout planning because it exposes both high-reuse leaves and likely duplicated coverage paths; it should guide prioritization, not dictate exact test depth.
- The first graph pass surfaced `Synchronizer`, `SynchronizerVector`, `SimpleDualPortRam`, `FifoOutputPipeline`, `FifoRdFsm`, and `FifoWrFsm` as concrete `base/` bottom-up candidates after the FIFO pilots.
- Duplicate entity names are common in SURF due to dummy/vendor variants, so graph consumers need to read path context rather than rely on entity names alone.
- Direct cocotb tests for simple SURF leaf modules still need to account for `TPD_G` when sampling outputs after clock or reset events; sampling exactly at the nominal edge can create false negatives.
- Simple RAM tests benefit from a small startup warm-up and conservative read sampling so direct and registered output configurations share one stable helper.
- For leaf modules with combinational outputs derived from current request inputs, pulse-based tests should drop the request before sampling post-edge state or they may observe the next pending transaction instead of the one just accepted.
- The local GHDL flow rejects direct command-line overrides of a 32-bit `slv` generic in `Crc32`; when a parameterized leaf still needs expanded coverage, prefer a thin test-only wrapper over simulator-specific literal hacks.
- For repeated real-generic shim cases, generated test-local wrappers are a better default than checking in one VHDL file per module; they keep the workaround explicit without growing permanent HDL debris.

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
- 2026-03-20: Switched from pilot-only work to the bottom-up rollout and selected `FifoSync` as the next low-level target.
- 2026-03-20: Implemented and validated an 11-case `FifoSync` matrix under `tests/base/fifo/test_FifoSync.py`.
- 2026-03-20: Added and generated the first-pass RTL instantiation graph to guide bottom-up rollout decisions and reduce repeated test effort across the hierarchy.
- 2026-03-20: Implemented and validated a 6-case `Synchronizer` matrix under `tests/base/sync/test_Synchronizer.py` as the next graph-guided `base` leaf.
- 2026-03-20: Documented that local Python commands should use `./.venv/bin/python` unless the virtualenv is already activated, after a bare `python` invocation failed due to a missing shell shim.
- 2026-03-20: Implemented and validated the next five graph-guided `base` regressions: `SynchronizerVector`, `RstPipeline`, `SimpleDualPortRam`, `FifoOutputPipeline`, and `FifoWrFsm`.
- 2026-03-20: Updated the planning and handoff docs to preserve the user's tutorial-style cocotb comment preference for future regressions.
- 2026-03-20: Implemented and validated the next 10 graph-guided `base` regressions: `Crc32Parallel`, `Crc32`, `CRC32Rtl`, `RstSync`, `PwrUpRst`, `SynchronizerEdge`, `SynchronizerOneShot`, `TrueDualPortRam`, `LutRam`, and `FifoRdFsm`.
- 2026-03-20: Expanded `Crc32` coverage beyond the default IEEE polynomial to include Castagnoli and Koopman-style cases, using a thin test-only VHDL wrapper because local GHDL rejected direct runtime overrides of the 32-bit `CRC_POLY_G` vector generic.
- 2026-03-20: Implemented and validated the next 15 graph-guided `base` regressions: `Arbiter`, `ClockDivider`, `Debouncer`, `Gearbox`, `Heartbeat`, `Mux`, `OneShot`, `RegisterVector`, `RstPipelineVector`, `Scrambler`, `WatchDogRst`, `SlvDelay`, `SlvFixedDelay`, `SynchronizerFifo`, and `SynchronizerOneShotCnt` (`41 passed`).
- 2026-03-21: Replaced the checked-in `Heartbeat`/`Debouncer` wrapper files with a shared generated-wrapper helper in `tests/common/regression_utils.py` and revalidated both the targeted tests (`6 passed`) and the full 15-module batch (`41 passed`).
