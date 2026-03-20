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

## Current Status
Planning is complete enough to start implementation. The agreed direction is a Python-only executable regression framework with tiered `smoke` and `functional` coverage. Existing VHDL TBs are reference material only and should be rewritten in Python when migrated, unless a thin wrapper is still useful for cocotb access.

The repo now has the initial handoff artifacts, a checked-in inventory scaffold at `docs/_meta/rtl_regression_inventory.yaml`, and local bootstrap helpers in `scripts/setup_regression_env.sh` plus `.vscode/tasks.json`. The first pilot modules are selected: `FifoAsync`, `AxiStreamFifoV2`, and `AxiLiteAsync`.

The local machine now has `ghdl`, a working `.venv`, the Python regression packages, a repo-local `ruckus` link to `~/ruckus`, and a successful `make MODULES="$PWD" import` run. Local environment bootstrap is no longer the blocker.

## Immediate Next Task
Define the shared Python regression helper structure, then implement the first pilot regression starting with `FifoAsync`.

## Read Order
1. `docs/_meta/rtl_regression_handoff.md`
2. `docs/_meta/rtl_regression_progress.md`
3. `docs/_meta/rtl_regression_plan.md`

## Important Repo Facts
- Current Python regressions live in `tests/`
- Many VHDL wrappers live under `*/tb/`
- The initial regression inventory lives in `docs/_meta/rtl_regression_inventory.yaml`
- Local bootstrap entrypoint: `scripts/setup_regression_env.sh`
- Local `ruckus` is linked from `~/ruckus`

## Resume Rule
If resuming implementation, update `docs/_meta/rtl_regression_progress.md` first.
