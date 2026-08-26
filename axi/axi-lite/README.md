# AXI-Lite

This directory contains reusable AXI-Lite records, interconnects, endpoints,
clock-domain bridges, and IP-integrator adapters.

## Layout

- `rtl/`: AXI-Lite packages and synthesizable cores.
- `ip_integrator/`: flattened wrappers for block-design and simulator-facing
  integration.
- `tb/`: legacy VHDL testbenches.

Executable cocotb regressions live under
[`tests/axi/axi_lite/`](../../tests/axi/axi_lite/README.md).

## `AxiLiteAsync` Contract

`AxiLiteAsync` directly connects the slave and master interfaces when
`COMMON_CLK_G = true`. Otherwise, five asynchronous FIFOs carry the read
request, read response, write address, write data, and write response channels.

The asynchronous bridge permits one read and one write in flight. The write
address and data channels remain independent, so either may arrive first, but
each channel accepts only one pending beat until the write response completes.
The bridge enforces this limit with its READY outputs. External masters that
pipeline requests are therefore backpressured rather than buffered to the FIFO
depth.

All five FIFOs share a registered reset request and are flushed when either AXI
domain resets. Reset handling follows these rules:

- A slave/source-domain reset abandons outstanding source transactions; no
  response is owed after that reset.
- A master/destination-domain reset while the slave domain remains active
  completes each accepted read locally with `AXI_ERROR_RESP_G`.
- A locally completed write returns `AXI_ERROR_RESP_G` only after both its AW
  and W beats have been accepted.
- Transactions discarded by reset are not replayed when the master domain
  recovers, and stale responses do not survive a slave-domain reset.

If a clock is unavailable, its corresponding reset must remain asserted. The
clock must be stable before reset is released, and traffic must remain inactive
until synchronized reset release completes.

`AxiLiteAsyncIpIntegrator.vhd` exposes the same clocks, resets, and response
codes through flattened AXI-Lite ports.
