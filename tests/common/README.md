# Common Regression Infrastructure

The helpers in this directory provide the shared pytest/cocotb launch path for
SURF regressions. Start with the repository-wide [regression style
guide](../README.md) and use this page when wiring a new Python test into GHDL.

## Standard Runner

`run_surf_vhdl_test()` in `regression_utils.py` launches GHDL through
`cocotb-test`, loads the ruckus-imported SURF libraries, selects the cocotb
module from `test_file`, and gives each parameter case its own simulation build
directory.

A normal pytest wrapper looks like this:

```python
PARAMETER_SWEEP = [
    parameter_case("default", DATA_WIDTH_G=16, RST_ASYNC_G=False),
    parameter_case("async_reset", DATA_WIDTH_G=16, RST_ASYNC_G=True),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_my_target(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="MyTargetWrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
```

Use `parameters` only for VHDL generics. Use `extra_env` for Python-side case
metadata. When one dictionary contains both, pass it through
`hdl_parameters_from()` before giving it to the simulator.

Use `extra_vhdl_sources` for a wrapper or simulation model that is intentionally
outside the imported SURF source list. Production RTL belongs in the nearest
`ruckus.tcl`; do not use this argument to hide a missing build-manifest entry or
repeat a unit already supplied by the import, which can produce a library
redefinition error.

Use `sim_build_key` only when normal parameter-derived names would be too long
or when a subsystem requires a deliberately stable build location. The default
path already includes `parameters` and `extra_env`, which isolates parallel
cases. A custom key must preserve that isolation; never point concurrently
runnable variants at the same build directory.

Leave `force_compile=False` for normal regressions. Set it only when a
documented source-topology or simulator-cache limitation makes reuse unsafe;
it is not a substitute for a unique build identity.

The shared runner is the default for VHDL/GHDL regressions. A direct
`cocotb-test` or simulator-specific runner is justified only when the flow
needs capabilities the shared path cannot express, such as a mixed-language
top, a vendor simulator, precompiled libraries, or explicit external-process
lifecycle control. Document the exception beside the custom runner or in the
subsystem README, and retain the common source, compile-option, result-file,
and build-isolation conventions where they apply.

## Shared Helpers

- `parameter_case()` creates readable pytest IDs for curated cases.
- `hdl_parameters_from()` filters mixed case dictionaries to keys ending in
  `_G`.
- `env_flag()`, `env_sl()`, `env_int()`, `env_hex()`, and `env_float()` parse
  simulator environment values consistently inside cocotb coroutines.
- `start_lockstep_clocks()` drives multiple logically common clocks from one
  coroutine so their edges cannot drift.
- `build_vhdl_sources()` and `merge_vhdl_sources()` are runner plumbing; tests
  should normally reach them only through `run_surf_vhdl_test()`.

Bus and protocol transaction helpers live closer to their users:

- `tests/axi/utils.py` contains shared AXI-family handshake utilities.
- `tests/protocols/<protocol>/*_test_utils.py` contains protocol frames,
  reference models, sources, sinks, and scoreboards.
- Subsystem helpers should implement mechanics, while policy assertions remain
  visible in the module test.

## Build And Debug Workflow

Run the ruckus import after source-list changes or when `build/SRC_VHDL` is
missing or stale:

```bash
make MODULES="$PWD" import
```

Use a serial focused run for readable simulator logs:

```bash
./.venv/bin/python -m pytest -n 0 -q tests/<area>/test_<Target>.py
```

Use parallel execution for a stable subsystem suite:

```bash
./.venv/bin/python -m pytest -n auto --dist=worksteal -q tests/<area>
```

Do not call the runner directly from a cocotb coroutine. Pytest launches the
simulator; cocotb code runs inside it. Keep every protocol-progress wait bounded
so a broken handshake becomes a useful failure instead of a hung worker.

When a pytest wrapper selects one of several cocotb entrypoints, pass the
selector in `extra_env`. Because the shared runner includes `extra_env` in the
default build path, selected scenarios remain isolated under pytest-xdist.
