# Xilinx

This tree contains Xilinx-specific RTL wrappers, primitive integrations, and helper IP used by SURF.

## Layout

- Family folders such as `7Series/`, `Virtex5/`, `UltraScale/`, `UltraScale+/`, and `Versal/` hold family-specific wrappers and primitive integrations.
- `general/` contains Xilinx helpers that are not tied to a single family directory.
- `xvc-udp/` contains Xilinx Virtual Cable over UDP support and has its own [README.md](xvc-udp/README.md).
- `dummy/` contains placeholder or compatibility support used by build flows.

Keep Xilinx primitive details isolated here or in explicitly family-named subdirectories of a subsystem. When a generic SURF wrapper exists, use it from higher-level RTL instead of instantiating primitives directly.
