# Regression Test Layout

New SURF regressions should be organized by subsystem under `tests/`.

## Layout
- `tests/common/`: shared Python regression helpers
- `tests/legacy/`: archived flat tests that are superseded by subsystem tests and excluded from default pytest collection
- `tests/base/`: regressions for `base/*`
- `tests/axi/`: regressions for `axi/*`
- `tests/protocols/`: regressions for `protocols/*`
- `tests/ethernet/`: regressions for `ethernet/*`
- `tests/devices/`: regressions for `devices/*`
- `tests/xilinx/`: regressions for `xilinx/*`

Within each subsystem, keep tests grouped by functional area when useful, such as
`tests/base/fifo/` or `tests/axi/axi_stream/`.

## Policy
- All executable regression logic belongs in Python.
- VHDL is only for thin wrappers, shims, or required simulation models.
- New regressions should not be added as flat `tests/test_*.py` files.
- Flat tests with subsystem replacements should move to `tests/legacy/`; uncovered legacy tests can remain at the root until they are replaced.
