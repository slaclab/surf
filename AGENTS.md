# Agent Guidance For SURF

SURF is the SLAC Ultimate RTL Framework: a shared VHDL/IP, ruckus, cocotb, and PyRogue support library. Treat it as reusable infrastructure, not a single board project. Keep changes narrow, preserve existing public interfaces, and avoid broad style cleanups unless the user asks for them.

Do not stage files or make git commits unless the user explicitly asks for staging or committing.

## Repository Map

Start with [README.md](README.md) for user-facing links and the source tree index. The most useful local orientation files are:

- [axi/README.md](axi/README.md) for AXI-Lite, AXI4, AXI Stream, DMA, bridges, and simulation-link RTL.
- [base/README.md](base/README.md) for foundational RTL packages, FIFOs, RAMs, CDC, resets, CRCs, and generic helpers.
- [devices/README.md](devices/README.md) for vendor/device-specific RTL support blocks.
- [dsp/README.md](dsp/README.md) for generic and Xilinx-specific DSP support.
- [ethernet/README.md](ethernet/README.md) for MAC, UDP/IP, raw Ethernet, RoCEv2, and high-speed Ethernet cores.
- [protocols/README.md](protocols/README.md) for PGP, SSI, SRP, RSSI, CoaXPress, JESD204B, I2C/SPI/UART, and related protocol cores.
- [xilinx/README.md](xilinx/README.md) for Xilinx-family primitives, wrappers, and XVC UDP support.
- [python/README.md](python/README.md) for the PyRogue package under `python/surf`.
- [tests/README.md](tests/README.md) for the authoritative cocotb regression
  methodology, coding style, coverage expectations, layout, and simulator
  conventions.
- [tests/common/README.md](tests/common/README.md) for the shared pytest/GHDL
  runner, parameter and environment handling, build isolation, and reusable
  regression helpers.
- [tests/protocols/README.md](tests/protocols/README.md) for protocol-oracle,
  layering, malformed-traffic, ready/valid, and integration-test guidance; then
  read the nearest subsystem README, such as
  [tests/protocols/batcher/README.md](tests/protocols/batcher/README.md) or
  [tests/protocols/rssi/README.md](tests/protocols/rssi/README.md), when working
  in that area.
- [docs/plans/README.md](docs/plans/README.md) for substantial task planning, progress notes, and handoff conventions.

Top-level `ruckus.tcl` loads `axi`, `base`, `dsp`, `devices`, `ethernet`, `protocols`, and `xilinx`. Module-level `ruckus.tcl` files should continue to be the source of truth for which HDL files and submodules are part of a build.

## VHDL Conventions

Read and apply [SURF VHDL conventions](docs/vhdl-conventions.md) when adding,
reviewing or changing VHDL. That document is the authoritative repository-wide
guide for language/layout, two-process structure, output ownership, interface
timing, process variables, packages, arithmetic, reset/CDC, bus protocols,
AXI-Lite registers, wrappers, headers and RTL review.
Apply style changes within the authorized scope and preserve its explicit
memory, synchronizer and primitive implementation exceptions.

## Ruckus Conventions

- Treat `ruckus.tcl` files as build manifests. When adding, moving, or deleting HDL, update the closest manifest in the same change.
- Start maintained ruckus files with `source $::env(RUCKUS_PROC_TCL)` unless a nearby file shows a different established pattern.
- Use `loadSource -lib surf -dir "$::DIR_PATH/rtl"` or the local equivalent for source directories, and use `loadRuckusTcl "$::DIR_PATH/<subdir>"` when a child directory owns its own manifest.
- Keep parent manifests short. They should load subdirectories and apply coarse selection logic, not list every leaf file when a child manifest exists.
- Use `getFpgaArch` for family-specific source selection. Keep architecture guards readable and follow existing family strings such as `kintexu`, `virtexu`, `kintexuplus`, `zynquplus`, `zynquplusRFSOC`, `virtexuplus`, and `virtexuplusHBM`.
- Do not add generated simulator outputs, build products, waveform files, imported cache files, or temporary conversion artifacts to ruckus manifests.
- After changing ruckus structure, run `make MODULES="$PWD" import` when practical to confirm the import graph still resolves.

## Code Header Formats

Use the existing header style for the file type and local subtree. Do not rewrite imported vendor, generated, or third-party headers unless the user explicitly asks for license repair.

VHDL descriptions and the standard banner are specified in
[VHDL headers](docs/vhdl-conventions.md#vhdl-headers).

Python files should use the hash-comment license banner. PyRogue modules may include `Title` and `Description` sections when the surrounding package uses them; simple helper scripts may use only the license block.

```python
#-----------------------------------------------------------------------------
# Title      : Optional short title
#-----------------------------------------------------------------------------
# Description:
# Optional one- or two-line description
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
```

C, C++, and C header files should use the same license text with `//` comment delimiters. Match the local file's separator style, either `//-----------------------------------------------------------------------------` or `//////////////////////////////////////////////////////////////////////////////`.

```c
//-----------------------------------------------------------------------------
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//-----------------------------------------------------------------------------
```

Tcl, shell, YAML, and other hash-comment files should use the Python-style `#-----------------------------------------------------------------------------` license block when they are maintained SURF source. For executable scripts with a shebang, keep the shebang first and place the license block immediately after it.

New or substantially edited cocotb regression files must also include the
module-specific `Test methodology` block described in
[tests/README.md](tests/README.md), immediately after the license header.

## Python Conventions

- Python support lives under `python/surf` and is packaged by `setup.py`. Most modules are PyRogue `pr.Device` descriptions of RTL register maps or support utilities.
- Keep the standard SLAC/SURF Python license banner at the top of Python files.
- Follow the existing module pattern: implementation files are usually private modules named `_Thing.py`, and package `__init__.py` files re-export them with aligned `from surf... import *` lines.
- Preserve the aligned keyword-argument style used in `pr.RemoteVariable`, `pr.LinkVariable`, `pr.RemoteCommand`, and `self.add(...)` blocks. Register offsets should remain explicit hex constants.
- Match PyRogue naming already used by the package: device classes in PascalCase, register names matching firmware/user documentation, local helpers in `_snake_case` where needed.
- `.flake8` intentionally relaxes many whitespace rules to support the existing aligned register-map style. Do not run an autoformatter that destroys that alignment unless the user explicitly asks for a larger formatting migration.
- Be cautious with `setup.py`: it appends a version string into `python/surf/__init__.py` as part of packaging. Do not run packaging commands casually during documentation or small-code tasks.

## PyRogue Register Maps

- PyRogue register maps must mirror the RTL-visible register layout exactly. Keep `offset`, `bitOffset`, `bitSize`, `mode`, endianness/base type, and reset assumptions synchronized with firmware.
- Use explicit offsets in hex and explicit bit fields. Avoid computed offsets unless the surrounding file already uses a clear repeated-register pattern.
- Preserve public variable names, command names, enum strings, and link-variable names unless the user explicitly wants an API change. Downstream scripts often depend on these names.
- Use `pr.RemoteVariable` for hardware-backed registers, `pr.RemoteCommand` for command strobes or command-like accesses, and `pr.LinkVariable` for derived display/state values.
- Keep descriptions hardware-specific and useful. Avoid generic descriptions that repeat the variable name without explaining the register meaning or side effect.
- Keep write guards, dependencies, polling behavior, and hidden/expert visibility consistent with neighboring PyRogue devices.
- When changing an RTL register map, update the matching PyRogue model and any cocotb register helpers/tests in the same change when practical.

## Generated And Vendor Code

- Treat vendor memory models, Xilinx stubs, XCI/DCP outputs, Bluespec/RoCE generated Verilog, imported third-party protocol support, and the imported I2C libraries with non-SLAC license headers under `protocols/i2c/rtl` as external code unless the user specifically asks to modify them.
- Do not reformat, license-normalize, rename signals, or modernize generated/vendor files as incidental cleanup.
- When a wrapper around vendor/generated code is needed, put project-maintained glue in a nearby SURF-owned `rtl/`, `wrappers/`, `ip_integrator/`, or family-specific directory rather than editing the imported source.
- Keep binary and generated artifacts out of source changes unless they are intentionally tracked release/build inputs already managed by the repository.

## Tests And Verification

- Honor the user's explicit verification limits before applying the defaults below. If regressions are paused pending VHDL approval, keep them stopped until approval; later code edits or style fixes do not authorize restarting them. When only build smoke checks are allowed, use lint and compile/link checks, and do not execute simulation regressions. Record what remains behaviorally unverified.
- For RTL regressions, start with [tests/README.md](tests/README.md). Use
  [tests/common/README.md](tests/common/README.md) for runner/build mechanics,
  [tests/protocols/README.md](tests/protocols/README.md) for protocol tests, and
  the nearest test-subsystem README for local commands or exceptions. The
  expected default stack is `pytest + cocotb + GHDL + ruckus`.
- For docs-only changes, no RTL or Python tests are required, but check links and headings if the edit adds navigation.
- For ruckus or source-list changes, run `make MODULES="$PWD" import` when practical.
- For edited VHDL, run `./.venv/bin/vsg -c vsg-linter.yml -f path/to/file.vhd` and the most focused relevant cocotb/pytest target when practical.
- For Python/PyRogue changes, run a focused import or pytest that exercises the changed module. Avoid packaging commands unless the task specifically requires packaging validation.
- For cocotb tests, prefer `./.venv/bin/python -m pytest -q tests/<subsystem-or-file>`. Use `-n 0` when serial simulator logs are needed.
- Select or explicitly skip cocotb scenarios that do not apply to a parameter case; do not return early and record an unexercised scenario as a pass.
- Use `extra_vhdl_sources` only for design units absent from the ruckus import, and keep finite cocotb tasks awaited or lifetime agents explicitly owned by the bench.
- For bug regressions, demonstrate failure on the known-bad RTL when practical, or document the defect-catching assertion and why the comparison could not be run.
- For protocol or bus behavior changes, include tests or a clear verification note covering sidebands, backpressure, reset behavior, and boundary/error cases relevant to the change.
- Avoid hand-editing generated or cache directories such as `build/`, `tests/sim_build/`, `.pytest_cache/`, `docs/_build/`, and `docs/_generated/`.

## RTL Review Checklist

Use the [RTL review checklist](docs/vhdl-conventions.md#rtl-review-checklist)
before considering an RTL change done. Follow the verification limits and test
methodology above; formatting or compilation alone does not establish behavior.

## Documentation Updates

When adding a new subsystem, add or update the closest `README.md` if the layout
or usage is not obvious. Keep README files short and navigational: describe what
belongs in the folder, important subdirectories, and any local build/test
conventions, then link upward through the parent README chain. Test-subsystem
READMEs should link to [tests/README.md](tests/README.md), and protocol-test
READMEs should also link to
[tests/protocols/README.md](tests/protocols/README.md), so local instructions
extend rather than duplicate the shared methodology.

Add deeper README files as substantial areas are touched, especially in high-traffic module families such as `axi/axi-stream`, `axi/axi-lite`, `protocols/pgp`, `protocols/coaxpress`, `protocols/ssi`, `protocols/srp`, `ethernet/IpV4Engine`, `ethernet/UdpEngine`, and `ethernet/EthMacCore`. Prefer adding the README in the same change that introduces new layout or conventions for that area.

## Task Tracking

For substantial feature work, debug efforts, refactors, or multi-step investigations, keep planning, progress, and handoff Markdown under `docs/plans/<task-name>/`. Use a short kebab-case task name, keep notes factual, and update the plan as the work changes.

Each task directory should include enough context for another contributor to resume without reconstructing the work from chat history. Capture the goal, current status, decisions made, files or modules involved, validation run, open risks, and next steps. Keep large logs, generated output, and simulator artifacts out of `docs/plans`; summarize them and link to durable locations instead.

## Pull Requests

When preparing pull request text, follow the repository template at [.github/pull_request_template.md](.github/pull_request_template.md). PRs should generally target the `pre-release` branch unless the user or maintainer specifies a different base. Keep the `Description` clean and release-note ready; the template notes that blank descriptions are not accepted and that this text feeds release notes. Use `Details`, `JIRA`, and `Related` only when they add useful context.
