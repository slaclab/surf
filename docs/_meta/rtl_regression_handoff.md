# SURF RTL Regression Handoff

## Objective
- Build a repo-wide regression system for synthesizable SURF RTL.
- Keep all executable test logic in Python.
- Use `pytest + cocotb + GHDL + ruckus`.
- Keep VHDL only for wrappers, shims, and required simulation models.

## Chosen Constraints
- Python-only test logic
- VHDL wrappers allowed
- Whole-repo target
- Vendor-heavy modules deferred in phase 1
- Comment new Python regression code at a tutorial level, assuming the reader may be new to cocotb
- Treat VHDL packages as transitively covered unless a behavioral function/procedure needs a dedicated wrapper

## Current Status
Planning is complete enough to start implementation. The agreed direction is a Python-only executable regression framework with tiered `smoke` and `functional` coverage. Existing VHDL TBs are reference material only and should be rewritten in Python when migrated, unless a thin wrapper is still useful for cocotb access.

The repo now has the initial handoff artifacts, a checked-in inventory scaffold at `docs/_meta/rtl_regression_inventory.yaml`, and local bootstrap helpers in `scripts/setup_regression_env.sh` plus `.vscode/tasks.json`. The first pilot modules were `FifoAsync`, `AxiStreamFifoV2`, and `AxiLiteAsync`, and the work has since moved into a graph-guided bottom-up rollout across `base/`.

The local machine now has `ghdl`, a working `.venv`, the Python regression packages, a repo-local `ruckus` link to `~/ruckus`, and a successful `make MODULES="$PWD" import` run. Local environment bootstrap is no longer the blocker. The first shared-helper-based pilot regression now exists in `tests/base/fifo/test_FifoAsync.py` and passes locally.

New regressions are now being organized by subsystem under `tests/`, with shared helpers in `tests/common/`. The `FifoAsync` pilot lives in `tests/base/fifo/test_FifoAsync.py`, and `AxiStreamFifoV2` now lives in `tests/axi/axi_stream/test_AxiStreamFifoV2IpIntegrator.py`. New work should follow that package layout instead of adding more flat files under `tests/`.

`FifoAsync` now has a validated expanded 12-case matrix, `FifoSync` has a validated expanded 11-case matrix, `Synchronizer` and `SynchronizerVector` now each have validated 6-case matrices under `tests/base/sync/`, `RstPipeline` has a validated 4-case matrix under `tests/base/general/`, `SimpleDualPortRam` has a validated 5-case matrix under `tests/base/ram/`, `FifoOutputPipeline` has a validated 5-case matrix under `tests/base/fifo/`, and `FifoWrFsm` has a validated 4-case matrix under `tests/base/fifo/`.

The next graph-guided 10-module follow-on is also now in place: `Crc32Parallel`, `Crc32`, `CRC32Rtl`, `RstSync`, `PwrUpRst`, `SynchronizerEdge`, `SynchronizerOneShot`, `TrueDualPortRam`, `LutRam`, and `FifoRdFsm`. The combined validation command for that batch is `./.venv/bin/python -m pytest -v tests/base/crc/test_Crc32Parallel.py tests/base/crc/test_Crc32.py tests/base/crc/test_CRC32Rtl.py tests/base/sync/test_RstSync.py tests/base/general/test_PwrUpRst.py tests/base/sync/test_SynchronizerEdge.py tests/base/sync/test_SynchronizerOneShot.py tests/base/ram/test_TrueDualPortRam.py tests/base/ram/test_LutRam.py tests/base/fifo/test_FifoRdFsm.py`, and it currently passes with `38 passed`.

The next 15-module `base/` general/delay/sync batch is now also implemented and validated: `Arbiter`, `ClockDivider`, `Debouncer`, `Gearbox`, `Heartbeat`, `Mux`, `OneShot`, `RegisterVector`, `RstPipelineVector`, `Scrambler`, `WatchDogRst`, `SlvDelay`, `SlvFixedDelay`, `SynchronizerFifo`, and `SynchronizerOneShotCnt`. The combined validation command for that batch is `./.venv/bin/python -m pytest -n 0 -q tests/base/general/test_Arbiter.py tests/base/general/test_ClockDivider.py tests/base/general/test_Debouncer.py tests/base/general/test_Gearbox.py tests/base/general/test_Heartbeat.py tests/base/general/test_Mux.py tests/base/general/test_OneShot.py tests/base/general/test_RegisterVector.py tests/base/general/test_RstPipelineVector.py tests/base/general/test_Scrambler.py tests/base/general/test_WatchDogRst.py tests/base/delay/test_SlvDelay.py tests/base/delay/test_SlvFixedDelay.py tests/base/sync/test_SynchronizerFifo.py tests/base/sync/test_SynchronizerOneShotCnt.py`, and it currently passes with `41 passed`.

`Crc32` now covers multiple common 32-bit polynomials instead of only the default IEEE CRC-32 polynomial. That test uses a thin wrapper at `tests/base/crc/hdl/Crc32PolyWrapper.vhd` because the local GHDL flow rejects direct command-line overrides of the `CRC_POLY_G : slv(31 downto 0)` generic. Pytest still defaults to `-n auto --dist=worksteal` through `pytest.ini` so parameterized regressions fan out across worker processes by default.

The project now also has a shared generated-wrapper path in `tests/common/regression_utils.py` for cases where the DUT is fine but the local simulator does not handle a generic interface cleanly. `Heartbeat` and `Debouncer` were migrated away from checked-in one-off wrapper files to generated test-local wrappers, and future real-generic shim cases should follow that pattern by default.

A first-pass RTL instantiation graph is now checked in at `docs/_meta/rtl_instantiation_graph.md` and `docs/_meta/rtl_instantiation_graph.json`, generated by `scripts/build_rtl_instantiation_graph.py`. Use it to choose bottom-up targets and avoid repeating coverage at multiple hierarchy levels.

## Immediate Next Task
Choose the next `base/` leaf or shared primitive from the graph-guided candidate list and continue the bottom-up rollout from the now-validated FIFO, synchronizer, reset, RAM, CRC, general-control, delay, and lightweight stream-helper foundation. The immediate follow-on should come from the remaining high-reuse `base/` wrappers and helper blocks exposed by the checked-in graph rather than from memory.

## Read Order
1. `docs/_meta/rtl_regression_handoff.md`
2. `docs/_meta/rtl_regression_progress.md`
3. `docs/_meta/rtl_regression_plan.md`

## Important Repo Facts
- New Python regressions should be organized under subsystem packages in `tests/`
- Shared Python regression helper lives in `tests/common/regression_utils.py`
- `tests/common/regression_utils.py` now supports both test-local extra VHDL source lists and generated test-local wrapper emission for wrapper-based cases
- Default comment style for new cocotb tests is tutorial-style: explain what each coroutine step is doing and why, not just the non-obvious parts
- Many VHDL wrappers live under `*/tb/`
- The initial regression inventory lives in `docs/_meta/rtl_regression_inventory.yaml`
- The RTL instantiation graph lives in `docs/_meta/rtl_instantiation_graph.{md,json}`
- Use `./.venv/bin/python ...` for repo-local Python commands unless the virtualenv has already been activated in the current shell; do not assume a `python` shim exists on `PATH`
- If GHDL rejects a direct command-line override for a non-scalar or real generic, prefer a generated thin test-only wrapper over simulator-specific literal workarounds or another checked-in one-off HDL shim
- Regenerate the graph with `./.venv/bin/python scripts/build_rtl_instantiation_graph.py`
- Local bootstrap entrypoint: `scripts/setup_regression_env.sh`
- Local `ruckus` is linked from `~/ruckus`

## Resume Rule
If resuming implementation, update `docs/_meta/rtl_regression_progress.md` first.
