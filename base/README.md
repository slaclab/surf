# Base

This tree contains the foundational RTL used by the rest of SURF. Top-level `base/ruckus.tcl` loads each base library area.

## Layout

- `general/`: common packages and generic utilities such as `StdRtlPkg`, arbiters, muxes, reset pipelines, gearboxes, counters, and watchdog/reset helpers.
- `sync/`: clock-domain crossing, synchronizers, reset synchronizers, trigger-rate, status, and frequency measurement helpers.
- `fifo/`: synchronous, asynchronous, muxing, cascade, FWFT, and output-pipeline FIFO blocks.
- `ram/`: RAM selectors and inferred/Xilinx/Altera backend implementations. See `ram/README.md` for wrapper selection guidance.
- `delay/`: fixed, RAM-backed, and FIFO-backed delay blocks.
- `crc/`: CRC packages and implementations.

Most modules use SURF package aliases such as `sl` and `slv`, `_G` generics, `_C` constants, and the local `RegType`/`REG_INIT_C` registered-process style. Reuse these base modules rather than duplicating CDC, FIFO, RAM, reset, or CRC logic in higher-level subsystems.
