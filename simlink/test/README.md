# SimLink HDL Test Support

This directory contains HDL and SystemVerilog sources used exclusively by the
Python and cocotb regressions under [`tests/simlink`](../../tests/simlink/README.md).
The normal `simlink/ruckus.tcl` import does not load this directory; each test
runner supplies the sources it needs explicitly.

| Path | Purpose |
| --- | --- |
| `common/` | Backend-neutral flat and multi-instance harnesses driven by cocotb |
| `vcs/` | VCS-specific VPI test bridge |
| `xsim/` | Self-driving Vivado xsim testbench tops |

Names describe the source's role: a `Harness` is a passive structural test
top driven externally, a `Bridge` crosses a simulator/language boundary, and a
`Tb` owns its testbench sequencing and pass/fail behavior.
