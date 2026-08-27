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

- Keep the standard SLAC/SURF license banner at the top of maintained source files. Use the nearby file style when adding a new file.
- Target VHDL-2008 as used by the Makefile/GHDL flow. Do not modernize older files from `std_logic_arith`/`std_logic_unsigned` to `numeric_std` as an incidental change.
- Use three-space indentation. `vsg-linter.yml` is the style authority; run `./.venv/bin/vsg -c vsg-linter.yml path/to/file.vhd` for edited VHDL when practical.
- Prefer SURF package types and helpers, especially `surf.StdRtlPkg` aliases such as `sl` and `slv`, and established record types from AXI, AXI Stream, SSI, and related packages.
- Follow existing naming patterns: generics end in `_G`, constants in `_C`, record types use `Type`, and module names are PascalCase.
- For registered logic, match the local `RegType`, `REG_INIT_C`, `r`, `rin`, `comb`, and `seq` pattern. Preserve `TPD_G`, `RST_POLARITY_G`, and `RST_ASYNC_G` reset idioms when present.
- Use named association for component/entity instantiations and keep reset, clock, AXI, and stream ports grouped consistently with neighboring modules. On port maps, add aligned trailing direction comments using the instance port direction, for example `clk => axilClk, -- [in]` and `axiReadSlave => axiReadSlave); -- [out]`. Use `-- [inout]` when a port is bidirectional.
- Put synthesizable RTL in `rtl/`, simulation-only models in `sim/`, testbenches in `tb/`, flattened or tool-facing adapters in `wrappers/` or `ip_integrator/`, and FPGA-family specializations in family-named directories such as `gth7`, `gthUltraScale`, `gtyUltraScale+`, `7Series`, or `UltraScale`.
- Keep wrappers thin. Prefer existing SURF adapter entities for AXI/AXI Stream record flattening before hand-writing bus packing.
- Update the nearest `ruckus.tcl` when adding HDL. Use `loadRuckusTcl` for subdirectories and architecture guards such as `getFpgaArch` for family-specific sources.

## Two-Process VHDL Style

SURF RTL generally follows the two-process style popularized by Gaisler: one combinational process computes next state and outputs, and one sequential process registers the state.

- Put registered state in a `RegType` record. Use a `REG_INIT_C` constant for reset/default state, and declare `r` and `rin` signals for current and next state.
- Name the combinational process `comb` and the sequential process `seq` unless the surrounding file has a stronger local convention.
- At the top of `comb`, declare `variable v : RegType;` and immediately assign `v := r;`. Make all next-state updates to `v`.
- Minimize additional process variables. Prefer adding intermediate state or diagnostic values to `RegType` and operating on `v.<field>` directly, even when the registered value is not currently consumed. This keeps the next-state path uniform and makes a useful value straightforward to expose through AXI-Lite later.
- Use a process-local variable only when it is genuinely clearer or required by a helper, such as `AxiLiteEndpointType`. Give every such scratch variable an unconditional default immediately after `v := r;` before any conditional logic, unless the called helper initializes the complete object before its first use. Never depend on mutually exclusive branches to imply a combinational default; incomplete assignment can infer a latch in synthesis even when simulation and lint pass.
- Assign `rin <= v;` near the end of `comb`. Drive module outputs from `r` for registered outputs and from `v` only when the local design intentionally exposes next-cycle/combinational behavior.
- Include all combinational inputs read by the process in the sensitivity list. Existing files often use explicit lists rather than `process(all)`; match nearby style.
- Apply synchronous reset in `comb` by assigning `v := REG_INIT_C` when `RST_ASYNC_G = false` and reset is asserted.
- Apply asynchronous reset only in `seq`, before the rising-edge branch, by assigning `r <= REG_INIT_C after TPD_G`.
- In `seq`, update state with `r <= rin after TPD_G;` on the rising edge. Preserve `after TPD_G` in existing RTL.
- Avoid scattering registers across multiple unrelated clocked processes in a module that otherwise uses this style. If independent clock domains are required, use one `RegType`/`comb`/`seq` set per clock domain and make CDC boundaries explicit.
- Keep one-off concurrent assignments for simple wires acceptable, but keep state-machine decisions, counters, handshakes, and registered outputs inside the two-process structure.

## VHDL Package Conventions

- Put shared interface records, constants, array types, configuration records, helper functions, and protocol encoders/decoders in the nearest appropriate `*Pkg.vhd`.
- Name record types with a `Type` suffix, arrays with an `Array` suffix, and initialization constants with an `_INIT_C` suffix, such as `Pgp2bRxOutType`, `Pgp2bRxOutArray`, and `PGP2B_RX_OUT_INIT_C`.
- Use package-specific constant prefixes for exported constants. Follow existing all-caps prefixes such as `AXI_`, `AXI_STREAM_`, `SSI_`, `PGP2B_`, `ROCE_`, or the local protocol/device prefix.
- Provide an init constant for every exported record type unless the record is intentionally never default-initialized.
- Define unconstrained arrays with `natural range <>` when the type is meant to scale across lanes, virtual channels, masters, or replicated devices.
- Keep protocol and bus semantics centralized in packages. Do not duplicate record definitions, init values, CRC functions, sideband constants, or stream configuration helpers inside leaf RTL files.
- Avoid package bloat. If a helper is only meaningful inside one entity and is not part of a shared interface, keep it local to that entity.
- Avoid circular package dependencies. Lower-level packages such as base, AXI, and Ethernet should not depend on higher-level protocol/device packages.
- Keep package body functions deterministic and synthesizable unless the package is explicitly simulation-only.

## Simulation And Testbench VHDL

- Prefer Python/cocotb for executable stimulus, scoreboards, transaction sequencing, and randomized or parameterized checks.
- Keep VHDL testbenches and wrappers thin. They should provide clocks/resets, flatten records, adapt simulator-facing ports, tie off unused fields, instantiate simple integration topologies, or host required vendor simulation models.
- Name the real RTL instance `U_DUT` in wrappers and testbenches unless the file intentionally contains multiple peer instances.
- Put reusable cocotb-facing wrappers beside the RTL family they adapt, usually under `wrappers/` or `ip_integrator/`, instead of hiding durable HDL under `tests/`.
- Put pure simulation models under `sim/` and legacy or VHDL-only benches under `tb/`.
- Keep wrapper port maps annotated with `-- [in]`, `-- [out]`, or `-- [inout]` comments just like production RTL.
- Do not put protocol stimulus or assertions in VHDL when an equivalent cocotb test can own them more clearly.

## Ruckus Conventions

- Treat `ruckus.tcl` files as build manifests. When adding, moving, or deleting HDL, update the closest manifest in the same change.
- Start maintained ruckus files with `source $::env(RUCKUS_PROC_TCL)` unless a nearby file shows a different established pattern.
- Use `loadSource -lib surf -dir "$::DIR_PATH/rtl"` or the local equivalent for source directories, and use `loadRuckusTcl "$::DIR_PATH/<subdir>"` when a child directory owns its own manifest.
- Keep parent manifests short. They should load subdirectories and apply coarse selection logic, not list every leaf file when a child manifest exists.
- Use `getFpgaArch` for family-specific source selection. Keep architecture guards readable and follow existing family strings such as `kintexu`, `virtexu`, `kintexuplus`, `zynquplus`, `zynquplusRFSOC`, `virtexuplus`, and `virtexuplusHBM`.
- Do not add generated simulator outputs, build products, waveform files, imported cache files, or temporary conversion artifacts to ruckus manifests.
- After changing ruckus structure, run `make MODULES="$PWD" import` when practical to confirm the import graph still resolves.

## Reset And CDC Rules

- Prefer existing `base/sync` primitives for clock-domain crossing, reset synchronization, pulse transfer, status synchronization, and frequency/rate measurement.
- Do not hand-roll synchronizers, async FIFOs, reset pipelines, or CDC pulse logic unless there is a specific reason the existing base module cannot cover.
- Preserve existing reset generics and semantics: `TPD_G`, `RST_POLARITY_G`, `RST_ASYNC_G`, active-high/active-low defaults, and optional reset ports should remain compatible.
- Keep asynchronous reset handling in the sequential process and synchronous reset handling in the combinational next-state path when following the common SURF `comb`/`seq` pattern.
- For multi-clock designs, make the crossing explicit in names and structure. Avoid passing unsynchronized control/status bits between clock domains through ordinary signals.
- For reset fanout or deassertion timing, reuse `RstPipeline`, `RstPipelineVector`, `RstSync`, or local established wrappers instead of creating ad hoc chains.

## Bus And Protocol Semantics

- Use existing SURF record types and package helpers for AXI-Lite, AXI4, AXI Stream, SSI, PGP, SRP, Ethernet, and related protocols. Do not create parallel bus records for the same interface.
- AXI-Lite register maps should use explicit offsets, stable reset values, deterministic read data, and clear write side effects. Preserve response behavior and alignment/error handling from existing helpers.
- Keep AXI-Lite read/write endpoint code consistent with local helper procedures such as `axiSlaveWaitTxn`, `axiSlaveRegister`, `axiSlaveDefault`, and related package utilities where they are already used.
- AXI Stream and SSI changes must preserve payload byte order, `TKEEP`, `TLAST`, `TDEST`, `TID`, and `TUSER` semantics. For SSI, be especially careful with SOF, EOF, and EOFE encodings.
- Do not treat final payload data alone as sufficient for timing-visible behavior. Backpressure, arbitration order, burst length, sideband propagation, and frame boundaries are part of the interface contract.
- Keep protocol status/control register names and bit meanings aligned across RTL packages, PyRogue models, cocotb tests, and any user-facing documentation.
- Prefer extending existing protocol helpers or packages over duplicating encoders, decoders, CRC logic, packet builders, or stream handshake code.

## AXI-Lite Register Implementation Pattern

- Prefer the existing SURF AXI-Lite endpoint helpers over hand-written read/write channel state machines for simple register blocks.
- In two-process register blocks, keep AXI-Lite read/write slave records in `RegType` and initialize them from `AXI_LITE_*_INIT_C` constants.
- Use `axiSlaveWaitTxn(...)` once near the start of the register section to decode the current transaction into an endpoint/status variable.
- Use `axiSlaveRegister(...)` for read/write registers and `axiSlaveRegisterR(...)` for read-only status fields. Keep offsets explicit and aligned to the documented map.
- Use `axiSlaveDefault(...)` at the end of the map so unmapped accesses return the intended response, commonly `AXI_RESP_DECERR_C`.
- Apply write side effects deliberately. Pulse, clear-on-write, FIFO-write, and counter-reset behavior should be visible in the surrounding next-state logic and documented in PyRogue descriptions when user-visible.
- For status counters and sampled signals crossing clock domains, synchronize before exposing them on AXI-Lite. Do not read raw signals from another clock domain through a register map.
- Maintain readback behavior for writable registers unless the existing hardware contract intentionally differs.
- When changing offsets, fields, reset values, or access modes, update matching PyRogue variables and focused tests in the same change when practical.

## Code Header Formats

Use the existing header style for the file type and local subtree. Do not rewrite imported vendor, generated, or third-party headers unless the user explicitly asks for license repair.

VHDL source files should use the standard dashed banner with company, description, and license text:

```vhdl
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Short module description
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
```

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

- For RTL regressions, start with [tests/README.md](tests/README.md). Use
  [tests/common/README.md](tests/common/README.md) for runner/build mechanics,
  [tests/protocols/README.md](tests/protocols/README.md) for protocol tests, and
  the nearest test-subsystem README for local commands or exceptions. The
  expected default stack is `pytest + cocotb + GHDL + ruckus`.
- For docs-only changes, no RTL or Python tests are required, but check links and headings if the edit adds navigation.
- For ruckus or source-list changes, run `make MODULES="$PWD" import` when practical.
- For edited VHDL, run `./.venv/bin/vsg -c vsg-linter.yml path/to/file.vhd` and the most focused relevant cocotb/pytest target when practical.
- For Python/PyRogue changes, run a focused import or pytest that exercises the changed module. Avoid packaging commands unless the task specifically requires packaging validation.
- For cocotb tests, prefer `./.venv/bin/python -m pytest -q tests/<subsystem-or-file>`. Use `-n 0` when serial simulator logs are needed.
- Select or explicitly skip cocotb scenarios that do not apply to a parameter case; do not return early and record an unexercised scenario as a pass.
- Use `extra_vhdl_sources` only for design units absent from the ruckus import, and keep finite cocotb tasks awaited or lifetime agents explicitly owned by the bench.
- For bug regressions, demonstrate failure on the known-bad RTL when practical, or document the defect-catching assertion and why the comparison could not be run.
- For protocol or bus behavior changes, include tests or a clear verification note covering sidebands, backpressure, reset behavior, and boundary/error cases relevant to the change.
- Avoid hand-editing generated or cache directories such as `build/`, `tests/sim_build/`, `.pytest_cache/`, `docs/_build/`, and `docs/_generated/`.

## RTL Review Checklist

Before considering an RTL change done, check:

- Reset behavior remains compatible with existing `TPD_G`, `RST_POLARITY_G`, `RST_ASYNC_G`, and default reset values.
- CDC paths are explicit and use existing synchronizer, reset, FIFO, or status-crossing primitives.
- AXI-Lite, AXI Stream, SSI, Ethernet, PGP, and protocol sidebands are preserved, including error bits, SOF/EOF/EOFE flags, `TKEEP`, `TLAST`, `TDEST`, `TID`, and `TUSER`.
- State machines and counters follow the two-process style where the surrounding file uses it.
- New or moved HDL is included in the correct `ruckus.tcl`, and family-specific code is guarded appropriately.
- Register-map changes are reflected in PyRogue models, tests, and documentation.
- Simulation wrappers remain thin and do not hide production behavior changes.
- Generated/vendor files were not reformatted or modified incidentally.
- Verification notes identify what was run and what risk remains if focused tests or lint were not practical.

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
