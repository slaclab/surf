# SimLink Simulation Library

This directory contains reusable, simulator-neutral VHDL components intended
for downstream simulation designs. `simlink/ruckus.tcl` imports these files as
simulation-only SURF library sources before loading the selected backend.

The stable `RogueTcpStreamWrap`, `RogueTcpMemoryWrap`, and
`RogueSideBandWrap` entities adapt backend scalar leaves to SURF record or
application-facing interfaces. `RogueTcpStreamPacer` provides deterministic
simulated-time payload pacing used by the Stream interface.

Test-only flattening, stimulus, and mixed-language test tops belong under
[`../test/`](../test/README.md), not here.
