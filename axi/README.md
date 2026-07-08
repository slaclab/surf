# AXI

This tree contains reusable AXI-family RTL and wrappers. Top-level `axi/ruckus.tcl` loads the submodules used by SURF builds.

## Layout

- `axi-lite/`: AXI-Lite records, crossbars, endpoints, masters, slaves, monitors, and IP-integrator adapters.
- `axi-stream/`: AXI Stream records, FIFOs, muxes, monitors, protocol adapters, and stream wrappers.
- `axi4/`: full AXI4 support blocks and adapters.
- `bridge/`: bridges between AXI-family buses and SURF protocol records.
- `dma/`: DMA register, descriptor, FIFO, and stream integration cores.
- `simlink/`: simulator-link support and C/C++/VHDL pieces used by simulation flows (GHDL, VCS, and Vivado xsim backends). See [simlink/README.md](simlink/README.md) for the Rogue TCP/SideBand co-simulation usage guide.

Use existing package record types before adding flattened ports. Put durable adapter entities in `ip_integrator/` or `wrappers/`, and keep executable cocotb tests under `tests/axi/`.
