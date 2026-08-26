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
        toplevel="surf.MyTargetWrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
```

Use `parameters` only for VHDL generics. Use `extra_env` for Python-side case
metadata. When one dictionary contains both, pass it through
`hdl_parameters_from()` before giving it to the simulator.

Use `extra_vhdl_sources` only for a cocotb-only wrapper or simulation model whose
design unit is absent from the ruckus import. Check the imported source tree
under `build/SRC_VHDL/` before adding a path. Production and reusable wrapper RTL
belongs in the nearest `ruckus.tcl`; do not use this argument to hide a missing
build-manifest entry or repeat an imported design unit. Compiling the same unit
from both paths can redefine it, make compile order significant, or leave a
cached build using a different source than the reviewer expects.

The default build path includes `parameters` and `extra_env`, and the shared
runner hashes path components that would be unsafe or excessively long. Use
`sim_build_key` only when a subsystem requires a deliberately stable or more
meaningful build identity. A custom key must still distinguish every
concurrently runnable compile configuration and selected cocotb scenario; never
point incompatible variants at the same build directory.

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
- `cocotb_test_filter()`, `cocotb_test_filter_excluding()`, and
  `cocotb_filtered_env()` build explicit scenario groups while preserving an
  externally requested focused selector in the simulation-build identity.
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
default build path, selected scenarios remain isolated under pytest-xdist. Give
the selector a deterministic default and make each pytest node run only the
scenario or coherent scenario group named by that node; do not use a bare return
inside an otherwise selected cocotb test to turn an inapplicable case into a
pass.

Retain every task returned by `cocotb.start_soon()`. Await finite producers,
consumers, and transactions before the entrypoint completes. Store monitors or
protocol peers intended to run for the whole test on the bench, document them as
lifetime agents, and provide cleanup when cancellation order matters or an
agent owns a socket, process, file, or other external resource.

## Compliance Audit And Preservation Reports

`compliance_audit.py` provides a read-only structural audit and a reproducible
inventory for cleanup work. The audit reports screening signals; ambiguous
items such as lifetime tasks, open-ended agent loops, and post-edge delays still
require review rather than mechanical replacement.

Run an audit for the whole active test tree or one subsystem:

```bash
./.venv/bin/python -m tests.common.compliance_audit audit tests
./.venv/bin/python -m tests.common.compliance_audit audit tests/protocols/batcher
```

Capture a preservation report before changing a subsystem, capture it again
afterward, and compare the two:

```bash
./.venv/bin/python -m tests.common.compliance_audit \
    inventory tests/protocols/batcher --output /tmp/batcher-before.json
./.venv/bin/python -m tests.common.compliance_audit \
    inventory tests/protocols/batcher --output /tmp/batcher-after.json
./.venv/bin/python -m tests.common.compliance_audit \
    compare /tmp/batcher-before.json /tmp/batcher-after.json
```

The comparison exits unsuccessfully when a pytest function, cocotb entrypoint,
parameter ID, environment gate/selector, skip, or decorator timeout disappears.
An intentional rename, move, split, or consolidation therefore remains visible
and needs an explicit before/after mapping in the change description. Added
coverage is reported but does not make the command fail.

The checked-in `compliance_baseline.json` ratchets the rules that are reliable
enough to enforce structurally: methodology presence, ordinary direct-runner
exceptions, literal VHDL sources duplicated from the ruckus import, and a bare
entrypoint return reached before any awaited simulator activity or assertion.
Returns after test activity remain report-only because they can be intentional
successful terminal paths and require semantic review. Run the check after
importing the HDL tree:

```bash
make MODULES="$PWD" import
./.venv/bin/python -m tests.common.compliance_audit check tests
```

The check fails when a file introduces a new finding or exceeds its existing
per-rule count. Removing a legacy finding is allowed and reported as a baseline
reduction; update the baseline in the same cleanup change so the violation
cannot return. Do not regenerate the whole baseline to accept an unrelated new
finding.
