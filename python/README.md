# Python

The Python package lives under `python/surf` and is installed as `surf`. It primarily contains PyRogue device descriptions and small support utilities that mirror SURF RTL register maps.

## Layout

- `surf/axi/`: PyRogue models for AXI register blocks, DMA, stream monitors, version blocks, and related AXI support.
- `surf/devices/`: vendor and component-specific PyRogue register maps.
- `surf/ethernet/`: Ethernet, MAC, UDP, RoCE, and high-speed Ethernet support models.
- `surf/protocols/`: protocol-specific PyRogue models such as CoaXPress, PGP, RSSI, SSI, and related blocks.
- `surf/xilinx/`: Xilinx register maps and helper devices.
- `surf/misc/` and `surf/dsp/`: smaller utilities and DSP-related support.

Implementation modules usually use private filenames such as `_AxiVersion.py` and are re-exported from package `__init__.py` files. Keep register names, offsets, bit offsets, modes, and descriptions synchronized with the corresponding RTL packages and user-facing hardware documentation.
