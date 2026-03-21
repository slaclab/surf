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
- Comment new Python regression code where intent or framework behavior is not obvious
- Treat VHDL packages as transitively covered unless a behavioral function/procedure needs a dedicated wrapper

## Current Status
Planning is complete enough to start implementation. The agreed direction is a Python-only executable regression framework with tiered `smoke` and `functional` coverage. Existing VHDL TBs are reference material only and should be rewritten in Python when migrated, unless a thin wrapper is still useful for cocotb access.

The repo now has the initial handoff artifacts, a checked-in inventory scaffold at `docs/_meta/rtl_regression_inventory.yaml`, and local bootstrap helpers in `scripts/setup_regression_env.sh` plus `.vscode/tasks.json`. The first pilot modules are selected: `FifoAsync`, `AxiStreamFifoV2`, and `AxiLiteAsync`.

The local machine now has `ghdl`, a working `.venv`, the Python regression packages, a repo-local `ruckus` link to `~/ruckus`, and a successful `make MODULES="$PWD" import` run. Local environment bootstrap is no longer the blocker. The first shared-helper-based pilot regression now exists in `tests/base/fifo/test_FifoAsync.py` and passes locally.

New regressions are now being organized by subsystem under `tests/`, with shared helpers in `tests/common/`. The `FifoAsync` pilot lives in `tests/base/fifo/test_FifoAsync.py`, and `AxiStreamFifoV2` now lives in `tests/axi/axi_stream/test_AxiStreamFifoV2IpIntegrator.py`. New work should follow that package layout instead of adding more flat files under `tests/`.

`FifoAsync` now has a validated expanded 12-case matrix, and pytest defaults to `-n auto --dist=worksteal` through `pytest.ini` so parameterized regressions fan out across worker processes by default.

## Immediate Next Task
Add a purpose-built thin wrapper for `AxiLiteAsync` and implement `tests/axi/axi_lite/test_AxiLiteAsync.py` with the shared helper structure.

## Read Order
1. `docs/_meta/rtl_regression_handoff.md`
2. `docs/_meta/rtl_regression_progress.md`
3. `docs/_meta/rtl_regression_plan.md`

## Important Repo Facts
- New Python regressions should be organized under subsystem packages in `tests/`
- Shared Python regression helper lives in `tests/common/regression_utils.py`
- Many VHDL wrappers live under `*/tb/`
- The initial regression inventory lives in `docs/_meta/rtl_regression_inventory.yaml`
- Local bootstrap entrypoint: `scripts/setup_regression_env.sh`
- Local `ruckus` is linked from `~/ruckus`

## Resume Rule
If resuming implementation, update `docs/_meta/rtl_regression_progress.md` first.
