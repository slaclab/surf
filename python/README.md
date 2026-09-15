# Python

The Python package lives under `python/surf` and is installed as `surf`. It primarily contains PyRogue device descriptions and small support utilities that mirror SURF RTL register maps. Python 3.10 or newer is required, matching the supported range of current Rogue releases.

## Layout

- `surf/axi/`: PyRogue models for AXI register blocks, DMA, stream monitors, version blocks, and related AXI support.
- `surf/devices/`: vendor and component-specific PyRogue register maps.
- `surf/ethernet/`: Ethernet, MAC, UDP, RoCE, and high-speed Ethernet support models.
- `surf/protocols/`: protocol-specific PyRogue models such as CoaXPress, PGP, RSSI, SSI, and related blocks.
- `surf/xilinx/`: Xilinx register maps and helper devices.
- `surf/misc/` and `surf/dsp/`: smaller utilities and DSP-related support.

Implementation modules usually use private filenames such as `_AxiVersion.py` and are re-exported from package `__init__.py` files. Keep register names, offsets, bit offsets, modes, and descriptions synchronized with the corresponding RTL packages and user-facing hardware documentation.

## PyRogue API Style

New and substantially revised PyRogue modules should follow the current Rogue Python style:

- Add `from __future__ import annotations` and type all function and method parameters and return values, including private helpers. Use Python 3.10 union syntax such as `Node | None`, and use `Any` where PyRogue's dynamic node plumbing makes a more specific annotation misleading.
- Document public classes and functions with NumPy-style docstrings. Put constructor arguments in the class-level `Parameters` section and add `Returns`, `Raises`, and `Notes` sections when they clarify the interface.
- Keep private-method docstrings concise unless the method has a non-obvious contract.
- Use annotations to state accepted Python types. Runtime validation should focus on meaningful hardware constraints, such as supported lane counts and delay widths, instead of duplicating the type system.
