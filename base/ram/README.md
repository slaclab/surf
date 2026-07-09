# RAM

This directory contains SURF RAM selectors and implementation backends. Prefer the selectors in `rtl/` for new portable designs, and use the inferred, Xilinx, Altera, and dummy files directly only when a design needs that specific implementation behavior.

## Preferred Wrappers

| Use case | Preferred module | Notes |
| --- | --- | --- |
| One write port and one read port | `surf.SimpleDualPortRam` | Portable selector for inferred, XPM, and Altera backends. This is the usual choice for RAM-backed FIFOs, lookup tables, status tables, and simple AXI-accessible storage. |
| Two writable ports | `surf.TrueDualPortRam` | Portable selector for true dual-port memories. Use this when both ports can write independently. |
| Legacy inferred one-write/two-read behavior or inferred distributed zero-latency behavior | `surf.DualPortRam` | Compatibility helper under `inferred/`. It is inferred-only and is not the preferred general selector for new code. |
| Explicit inferred implementation | `surf.SimpleDualPortRamInferred`, `surf.TrueDualPortRamInferred`, `surf.LutRam` | Backend modules for code that intentionally depends on inference style or LUTRAM behavior. |
| Explicit vendor primitive wrapper | `surf.SimpleDualPortRamXpm`, `surf.TrueDualPortRamXpm`, `surf.*AlteraMf` | Backend modules for code that intentionally targets a vendor primitive wrapper. |

## Latency Conventions

`SimpleDualPortRam` and `TrueDualPortRam` expose read-latency generics for selector-based code. The inferred backends generally support only the legacy synchronous RAM latency plus optional output-register behavior, while XPM supports a wider latency range. Wrappers that need a latency beyond the inferred RAM backend may add a local output register and should document that behavior at the wrapper.

`DOA_REG_G` and `DOB_REG_G` remain compatibility generics for older code that selected one extra output register. New selector-based code should prefer the explicit read-latency generics where they are available.
