# SURF Cocotb Regression Style Guide

This directory holds Python-authored regressions for synthesizable SURF RTL.
The default stack is `pytest + cocotb + GHDL + ruckus`; VHDL should only be
used for thin wrappers, shims, or required simulation models.

This README is the authoritative guide for new SURF regression work. Historical
task plans and module queues are not prerequisites and do not define the next
module that must be tested. Add or deepen coverage when a subsystem is being
changed, when a bug needs a permanent reproducer, or when a contributor chooses
an uncovered module to improve.

## Quick Start

If the local Python/GHDL/ruckus environment has not been prepared, run the
repository setup helper first:

```bash
./scripts/setup_regression_env.sh
```

The script checks the required host tools, creates `.venv`, installs the Python
requirements, and locates or clones ruckus. Review its output, activate the
environment if desired, and then follow the workflow below.

1. Read this README and the nearest subsystem README, if one exists.
2. Search the surrounding tests and helper modules before writing new drivers
   or protocol models.
3. Identify the externally visible contract and the smallest useful DUT or
   wrapper boundary.
4. Write the module-specific `Test methodology` block before implementing the
   test. It should make the intended sweep, stimulus, checks, and timing clear.
5. Import the HDL sources and run the narrowest useful pytest target:

   ```bash
   make MODULES="$PWD" import
   ./.venv/bin/python -m pytest -n 0 -q tests/<subsystem>/test_<Target>.py
   ```

6. Lint every edited VHDL file and run the relevant subsystem regression before
   handing the change off.

Additional references:

- [`tests/common/README.md`](common/README.md) documents the shared runner,
  parameter cases, environment parsing, and clock helpers.
- [`tests/protocols/README.md`](protocols/README.md) documents protocol-oracle,
  layering, malformed-frame, and integration-test practices.
- Subsystem READMEs may define protocol- or simulator-specific commands, but
  they should extend rather than replace this guide.

## Layout

- Keep executable tests under subsystem packages, such as `tests/base/fifo/`,
  `tests/axi/axi_stream/`, `tests/simlink/`, `tests/protocols/srp/`, or
  `tests/ethernet/UdpEngine/`.
- Do not add new flat `tests/test_*.py` files.
- Move superseded flat tests to `tests/legacy/` when they are replaced by
  subsystem tests. Uncovered legacy tests may stay at the root until migrated.
- Put reusable helpers in the nearest suitable helper module before adding
  another local copy of transaction code:
  - `tests/common/regression_utils.py` for repo-wide runner and environment
    helpers.
  - `tests/axi/utils.py` for AXI-family primitives shared across subsystems.
  - `*_test_utils.py` files beside subsystem tests for protocol-specific
    frames, scoreboards, setup, and source/sink helpers.
- Keep checked-in cocotb-facing VHDL wrappers beside the RTL family they adapt,
  usually in a local `wrappers/` or `ip_integrator/` directory. Do not hide
  durable wrappers under `tests/`.

## Directory-Scoped Feature CI

Feature-branch pushes compare `HEAD` with its merge base against
`origin/pre-release`. The changed paths are mapped to directory-owned pytest
suites, with `tests/common/` included in every selective run.

The Ethernet source routing follows the owned-suite relationships below:

| Changed source area | Selected Ethernet suites |
| --- | --- |
| `ethernet/EthMacCore/` | `EthMacCore`, `IpV4Engine`, `RoCEv2`, and `UdpEngine` |
| `ethernet/IpV4Engine/` | `IpV4Engine` and `UdpEngine` |
| Any other area with `tests/ethernet/<area>/` | Its matching owned suite |
| An area without an owned suite | Full regression |

A change within `tests/ethernet/<area>/` selects only that test directory.
Protocol source and test changes similarly select the matching
`tests/protocols/<area>/` directory when it exists, while DSP changes select
all of `tests/dsp/`. Selector errors, unknown paths, build-control changes,
deletions, and renames fail open to the full regression.

Source changes under `protocols/ssi/`, `protocols/rssi/`, or `protocols/srp/`
also force a full run because those cores have consumers outside their owned
protocol test directories. Changes confined to their matching test directories
remain selectively scoped.

### Full Runs And Coverage

Pushes to `pre-release` or `main`, tag pushes, and pull requests targeting
`main` run `pytest tests/`. This makes every current test directory a blocking
integration gate, including `tests/common/` and the `EthMacCore`,
`IpV4Engine`, and `RawEthFramer` Ethernet suites that were not named in the
previous explicit target list.

`tests/simlink/` is the one exception: it is excluded from that invocation and
run by its own workflow step, on every push, with a bounded worker count. Its
native ctypes libraries and multi-instance ZeroMQ traffic test are timing
sensitive, and an unbounded `-n auto` starves the peer handshake. Because no
changed path maps to `tests/simlink/`, the selector never selects it and the
dedicated step is what keeps it a blocking gate on feature branches.

Those integration and release-triggered full runs collect Python coverage and
upload it to Codecov. Feature-branch runs prioritize fast test feedback and do
not collect or upload coverage, including when the path selector conservatively
falls back to running the complete `tests/` tree.

## Python Test Files

Every new or substantially edited cocotb test file should start with the
standard SLAC/SURF license header followed immediately by a module-specific
`Test methodology` block. The concise form is:

```python
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## ...
##############################################################################

# Test methodology:
# - Sweep: Describe the curated parameter/configuration cases this file runs.
# - Stimulus: Describe the actual input sequences driven into the DUT.
# - Checks: Describe the outputs, state changes, sidebands, or errors asserted.
# - Timing: Describe latency, reset, handshake, backpressure, pulse, or timeout
#   behavior that the bench depends on or verifies.
```

Do not use generic methodology text. The block should tell a reader what this
specific bench proves and what it intentionally does not prove. Complex
protocol or integration tests may expand the headings (`Purpose`, `DUT shape`,
`Protocol checks`, `Parameter strategy`, and similar), but must still make the
scope/configuration, DUT boundary, stimulus, checks, and timing assumptions
easy to find. A prose methodology with the same information is acceptable in a
legacy file; use the labeled form for new work.

Use in-body comments at the major coroutine steps: clock startup, reset,
stimulus phases, backpressure, trigger waits, and result checks. Keep comments
tutorial-level for module tests, assuming the reader may not know cocotb well.
Shared helper modules may be denser, but non-obvious protocol or timing behavior
still needs a short explanation.

Common structure:

- Imports: standard library, cocotb/pytest, third-party helpers such as
  `cocotbext.axi`, then repo helpers.
- A small `TB` class when setup/reset/clocking is nontrivial.
- One or more `@cocotb.test()` coroutine entrypoints that each prove a clear
  behavior.
- A `PARAMETER_SWEEP` list using `pytest.param(..., id="readable_case_name")`
  or `parameter_case()`.
- A final pytest wrapper named for the RTL target, calling
  `run_surf_vhdl_test(test_file=__file__, ...)`.

Keep the cocotb entrypoints and the pytest wrapper in the same file unless a
subsystem has a documented reason to separate them. Pytest owns build
parameters and simulator launches; cocotb owns cycle-level stimulus and checks.

## Designing The Test

Start from the public contract, not the current implementation. Read the entity
ports and generics, the nearest package and README, and any applicable protocol
or register-map specification. Then choose the smallest boundary that can prove
the behavior:

- Test reusable leaves directly when their behavior is observable without a
  large integration topology.
- Use an integration test when arbitration, CDC, configuration propagation, or
  interaction between already-tested leaves is the actual contract.
- Do not replay a leaf's complete packet grammar or parameter matrix through
  every higher-level wrapper. Higher-level tests should focus on what that layer
  adds.
- Treat compile/elaboration-only smoke coverage as useful but distinct from a
  functional regression. A functional test needs meaningful stimulus and
  assertions.
- Treat package declarations as transitively covered unless an important
  function or procedure needs a small wrapper and a direct behavioral test.

For a bug regression, verify when practical that the new test fails against the
known-bad RTL and passes with the fix. If that comparison cannot be run,
document why and identify the assertion that would catch the original defect.
Reaching the formerly failing code path without checking its externally visible
effect is not sufficient regression coverage.

A focused regression normally covers the relevant subset of:

- reset assertion, release, and recovery;
- nominal data or control flow;
- backpressure and accepted-handshake timing;
- frame, burst, or transaction boundaries;
- payload ordering and byte enables such as `TKEEP`/`TSTRB`;
- sidebands such as `TLAST`, `TDEST`, `TID`, SOF, and EOFE;
- invalid inputs, error responses, overflow, timeout, or recovery behavior;
- representative generic or clock-domain configurations.

Use deterministic directed cases for protocol rules and boundary conditions.
Randomized cases are valuable after a trustworthy reference model exists, but
they do not replace readable directed regressions for known contracts and bugs.
Seed every randomized case explicitly. Keep the seed fixed or pass it through a
named environment value, and include the effective seed in a failure message or
log so the exact stimulus can be reproduced.

## Parameter Sweeps

Prefer curated matrices over broad Cartesian products. A good sweep covers
representative behavior: default path, one or two interesting generic branches,
reset polarity/asynchronous reset when relevant, a narrow/wide data path if that
changes packing, and a backpressure or staged case when timing is part of the
contract.

Keep sweep IDs short and meaningful because they become pytest IDs and sim-build
directory names. Use `sim_build_key` when a case has enough metadata to create
fragile or overly long build paths.

Pass only HDL generics as `parameters`. Put Python-only case metadata in
`extra_env`, or use `hdl_parameters_from(parameters)` when a case dictionary
contains both.

Prefer a pytest node that names one cocotb scenario or one coherent scenario
group. Normally let cocotb run all applicable entrypoints in that group. When
separate pytest nodes intentionally select one cocotb scenario, pass a selector
through `extra_env` (for example `COCOTB_TESTCASE` or a documented
subsystem-specific variable), give the selector a deterministic default, and
make sure it participates in the simulation-build identity. A focused pytest
node should not silently rerun unrelated cocotb scenarios.

An entrypoint that is inapplicable to the current parameter set must be
explicitly skipped or excluded by pytest/cocotb selection. Do not return
successfully before exercising the behavior and assertions named by the test;
that records a no-op as a pass and obscures what the regression actually ran.

## Reuse And Helpers

Before writing transaction code, search nearby helpers and related subsystems.
Existing patterns include:

- AXI-Lite register helpers and common runner utilities in `tests/axi/utils.py`
  and `tests/common/regression_utils.py`.
- SSI beat/frame helpers in `tests/protocols/ssi/ssi_test_utils.py`.
- SRPv3 request/response models in `tests/protocols/srp/srp_test_utils.py`.
- Ethernet, UDP, IPv4, RawEth, PGP, and CoaXPress frame builders in their
  local `*_test_utils.py` files.

Prefer extending a helper with one narrow reusable primitive over duplicating
ready/valid loops, packet builders, register accesses, or frame receivers in a
new test file.

For AXI Stream, SSI, and other flattened ready/valid sources, hold the current
beat stable until a sampled accepting clock edge. Use
`wait_sampled_ready()` when a `cocotbext.axi` source is not appropriate. After
`wait_sampled_ready()` returns, the transfer has already completed; advance or
deassert the source immediately.

Use `start_lockstep_clocks()` for `COMMON_CLK_G` or similar wrappers that expect
truly shared clock edges. Do not start two independent same-period clock
coroutines when the DUT contract is common-clock behavior. Retain its returned
task on the bench (for example, `self._clock_task = start_lockstep_clocks(...)`)
so ownership remains explicit just like any other lifetime agent.

## Isolation And Coroutine Lifecycle

Each cocotb entrypoint must establish its own defined starting state. Initialize
every testbench-driven input, reset the DUT when it has a meaningful reset, and
clear Python-side queues, scoreboards, and monitor state. Do not depend on the
execution order of cocotb entrypoints or on state left by an earlier test.

Every finite transaction task started with `cocotb.start_soon()` must be awaited
before the test completes. A monitor, protocol peer, or other task intended to
run for the lifetime of the test should be retained by the bench, named for its
purpose, and documented as a lifetime agent. Give benches that own several such
agents an explicit cleanup method when they need orderly cancellation or can
hold an external resource. External processes, sockets, ports, and files always
require bounded setup/teardown and cleanup on assertion failure.

Use operation-specific cycle limits or `with_timeout()` for protocol progress.
Add `timeout_time`/`timeout_unit` to complex concurrent or integration
entrypoints as a final deadlock watchdog. Small finite leaf tests do not need a
decorator timeout when every possible wait is already bounded.

## Assertions And Timing

Assert externally visible behavior, not implementation accidents. Good checks
usually include payload bytes, `TKEEP`, `TLAST`, `TUSER`/SOF/EOFE bits, address
or ID sidebands, response codes, counters, or accepted-handshake timing.
For a complex or parameterized check, include enough context in the failure to
identify the case, transaction or beat index, expected value, observed value,
and random seed when applicable.

Initialize reset and every testbench-driven control/data input before the first
active clock edge, preferably with `setimmediatevalue()` during bench setup.
Hold reset for an explicit number of clock edges, release it on the intended
edge, and allow any documented pipeline settling time before sampling outputs.
This prevents unresolved startup values from turning into simulator-dependent
stimulus.

Use bounded waits and explicit timeouts for protocol progress. Avoid
open-ended `while True` loops unless they are wrapped by `with_timeout()` or a
helper that has a cycle limit.

When a contract includes backpressure, burst length, sideband propagation, or
arbitration order, monitor accepted handshakes directly. Final memory contents
alone are not enough for timing-visible behavior.

Account for `TPD_G`, registered outputs, and GHDL scheduling. After an edge, use
`ReadOnly()` when only delta-cycle settling is required. When the RTL schedules
a real nonzero `after TPD_G`, wait for that configured propagation delay and
then sample the stable value. Keep this distinction visible in a shared helper;
do not add an unexplained fixed delay merely to make a race disappear.

Keep skip reasons and opt-in coverage explicit, and distinguish why a case is
not in the default run:

- Gate a regression for an unresolved RTL defect with a clear variable such as
  `RUN_KNOWN_ISSUE_TESTS`. Name the tracked defect, expected failure, and
  condition for restoring the case to default coverage in the methodology or
  local README, and promote the case with the fix.
- Gate an unusually long soak or stress matrix with a separately named
  `RUN_*_EXTENDED_TESTS` variable; do not label stable-but-slow coverage as a
  known issue.
- Use `pytest.skip()` or `pytest.mark.skipif()` for genuinely optional external
  tools, licenses, platforms, or production libraries, and state the exact
  missing prerequisite. A required CI job should provision that prerequisite
  and treat an unexpected skip as a failure.

## Running Tests

Use the repo virtualenv interpreter unless the virtualenv is already activated:

```bash
make MODULES="$PWD" import
./.venv/bin/python -m pytest -n auto --dist=worksteal -q tests/<subsystem>
```

Run `make ... import` when the imported HDL source cache is missing or stale.
Use `-n 0` for focused debug runs when serial simulator logs matter.

Assume the suite will run under pytest-xdist. Each case must have an isolated
simulation build directory and must not compete for a fixed port, ready file,
result file, or other process-global resource. Tests that launch peer processes
must use bounded startup/shutdown waits and clean them up in a `finally` block
or shared teardown helper, including after an assertion fails.

The runner or test fixture should clean up simulator children and external
peers during normal execution. After an interrupted or hung run, check for stale
processes before retrying so they cannot retain a build directory, port, or
license.

## VHDL Wrappers

Checked-in cocotb-facing wrappers are repo HDL and should be readable in the
same style as surrounding SURF files:

- Start with the standard SLAC/SURF VHDL banner and a concise description.
- Keep wrappers thin. They should flatten records, expose simulator-friendly
  generics, tie off unused fields deterministically, compose existing shim
  layers, or instantiate a small integration topology.
- Prefer `SlaveAxiStreamIpIntegrator`, `MasterAxiStreamIpIntegrator`,
  `SlaveAxiLiteIpIntegrator`, and `MasterAxiLiteIpIntegrator` for SURF record
  ports instead of hand-writing standard bus packing.
- Add short section comments for the major adapter regions. Typical sections
  are input flattening, output/status flattening, shim layer, DUT instantiation,
  and wrapper-specific topology.
- Name the real RTL instance `U_DUT` unless the wrapper intentionally contains
  more than one peer instance.
- Do not put executable stimulus, scoreboards, or test sequencing in VHDL.
  That belongs in Python.

For any VHDL file created or edited, run the same linter configuration used by
CI before considering the wrapper done:

```bash
./.venv/bin/vsg -c vsg-linter.yml path/to/Wrapper.vhd
```

If `vsg` reports fixable issues, run with `--fix` first, then rerun the lint
command to confirm the file is clean.

## Coverage Scope

VHDL packages are usually covered transitively through modules that use them.
Add a dedicated package wrapper only when a behavioral function or procedure is
important and not reached naturally through existing DUT coverage.

There is no active repository-wide queue of modules that must be completed in a
fixed order. When selecting new work, prefer high-reuse modules, code being
modified, untested bug fixes, and simulator-friendly leaves that establish
helpers useful to later integration tests. Vendor-heavy or mixed-language
blocks may be deferred when the standard GHDL flow cannot exercise their real
dependencies; document that limitation near the subsystem rather than adding a
test double that changes the DUT boundary.

## Completion Checklist

Before considering a new regression ready:

- The Python file has the standard license header, a specific methodology
  block, and comments around non-obvious cocotb sequencing.
- The test asserts behavior rather than merely reaching the end of simulation.
- A bug regression was shown to fail on known-bad RTL when practical, or the
  limitation and defect-catching assertion are documented.
- Inapplicable scenarios are selected out or reported as skipped; no entrypoint
  silently returns before exercising its named behavior.
- Every wait is bounded directly or by a helper with a cycle/time limit.
- Reset, backpressure, sidebands, and error/boundary cases relevant to the DUT
  are covered or explicitly documented as out of scope.
- Shared helpers were reused or extended instead of duplicated.
- Finite background tasks are awaited, lifetime agents have explicit ownership,
  and external resources are cleaned up on failure.
- Random stimulus is seeded and failures report enough information to replay
  the case.
- The case is safe under pytest-xdist: build artifacts and external resources
  are isolated, and child processes are cleaned up on failure.
- Any retained VHDL wrapper is thin, locally documented, clean under
  `vsg-linter.yml`, and reachable through its intended source path: the nearest
  ruckus manifest for build-facing HDL or `extra_vhdl_sources` for a
  cocotb-only wrapper.
- `extra_vhdl_sources` does not repeat production HDL already supplied by the
  ruckus import.
- The focused test and the nearest practical subsystem suite pass.
- `git diff --check` is clean; after an interrupted run, no stale simulator or
  peer process remains.
- The nearest README is updated if the test introduces a new layout, helper,
  simulator requirement, deferred dependency, or non-obvious invocation.
