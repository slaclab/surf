# SURF Cocotb Regression Style Guide

This directory holds Python-authored regressions for synthesizable SURF RTL.
The default stack is `pytest + cocotb + GHDL + ruckus`; VHDL should only be
used for thin wrappers, shims, or required simulation models.

## Layout

- Keep executable tests under subsystem packages, such as `tests/base/fifo/`,
  `tests/axi/axi_stream/`, `tests/protocols/srp/`, or
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

### Full Runs And Coverage

Pushes to `pre-release` or `main`, tag pushes, and pull requests targeting
`main` run `pytest tests/`. This makes every current test directory a blocking
integration gate, including `tests/common/` and the `EthMacCore`,
`IpV4Engine`, and `RawEthFramer` Ethernet suites that were not named in the
previous explicit target list.

Those integration and release-triggered full runs collect Python coverage and
upload it to Codecov. Feature-branch runs prioritize fast test feedback and do
not collect or upload coverage, including when the path selector conservatively
falls back to running the complete `tests/` tree.

## Python Test Files

Every checked-in cocotb test file should start with the standard SLAC/SURF
license header followed immediately by a module-specific `Test methodology`
block:

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
specific bench proves and what it intentionally does not prove.

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
coroutines when the DUT contract is common-clock behavior.

## Assertions And Timing

Assert externally visible behavior, not implementation accidents. Good checks
usually include payload bytes, `TKEEP`, `TLAST`, `TUSER`/SOF/EOFE bits, address
or ID sidebands, response codes, counters, or accepted-handshake timing.

Use bounded waits and explicit timeouts for protocol progress. Avoid
open-ended `while True` loops unless they are wrapped by `with_timeout()` or a
helper that has a cycle limit.

When a contract includes backpressure, burst length, sideband propagation, or
arbitration order, monitor accepted handshakes directly. Final memory contents
alone are not enough for timing-visible behavior.

Account for `TPD_G`, registered outputs, and GHDL scheduling. Sampling exactly
on a clock edge can create false failures; most helpers settle with a short
`Timer` after `RisingEdge()`.

Known RTL issues or intentionally open coverage should be explicit. If a bench
is checked in skipped or opt-in, document the condition and gate it with a clear
environment variable such as `RUN_KNOWN_ISSUE_TESTS`.

## Running Tests

Use the repo virtualenv interpreter unless the virtualenv is already activated:

```bash
make MODULES="$PWD" import
./.venv/bin/python -m pytest -n auto --dist=worksteal -q tests/<subsystem>
```

Run `make ... import` when the imported HDL source cache is missing or stale.
Use `-n 0` for focused debug runs when serial simulator logs matter.

After any command that launches pytest, cocotb, GHDL, or another simulator
runner, check for stale simulator child processes before starting another run.

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
