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
- [tests/README.md](tests/README.md) for cocotb regression layout, methodology comments, helper reuse, and simulator conventions.

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

Checked-in cocotb regression files must also include the `Test methodology` block described in [tests/README.md](tests/README.md), immediately after the license header.

## Python Conventions

- Python support lives under `python/surf` and is packaged by `setup.py`. Most modules are PyRogue `pr.Device` descriptions of RTL register maps or support utilities.
- Keep the standard SLAC/SURF Python license banner at the top of Python files.
- Follow the existing module pattern: implementation files are usually private modules named `_Thing.py`, and package `__init__.py` files re-export them with aligned `from surf... import *` lines.
- Preserve the aligned keyword-argument style used in `pr.RemoteVariable`, `pr.LinkVariable`, `pr.RemoteCommand`, and `self.add(...)` blocks. Register offsets should remain explicit hex constants.
- Match PyRogue naming already used by the package: device classes in PascalCase, register names matching firmware/user documentation, local helpers in `_snake_case` where needed.
- `.flake8` intentionally relaxes many whitespace rules to support the existing aligned register-map style. Do not run an autoformatter that destroys that alignment unless the user explicitly asks for a larger formatting migration.
- Be cautious with `setup.py`: it appends a version string into `python/surf/__init__.py` as part of packaging. Do not run packaging commands casually during documentation or small-code tasks.

## Tests And Verification

- For RTL regressions, use the guidance in [tests/README.md](tests/README.md). The expected stack is `pytest + cocotb + GHDL + ruckus`.
- Run `make MODULES="$PWD" import` when the HDL import cache is missing or stale.
- For focused tests, prefer `./.venv/bin/python -m pytest -q tests/<subsystem-or-file>`. Use `-n 0` when serial simulator logs are needed.
- For edited VHDL, run the relevant pytest/cocotb target when practical and run `vsg` on changed files.
- Avoid hand-editing generated or cache directories such as `build/`, `tests/sim_build/`, `.pytest_cache/`, `docs/_build/`, and `docs/_generated/`.

## Documentation Updates

When adding a new subsystem, add or update the closest `README.md` if the layout or usage is not obvious. Keep README files short and navigational: describe what belongs in the folder, important subdirectories, and any local build/test conventions, then link upward through the parent README chain.
