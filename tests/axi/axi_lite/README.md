# AXI-Lite Regressions

This directory contains cocotb regressions for the reusable AXI-Lite cores in
[`axi/axi-lite/`](../../../axi/axi-lite/README.md). Tests use thin
IP-integrator wrappers where a flattened simulator interface is needed.

Run the directory with:

```bash
make MODULES="$PWD" import
./.venv/bin/python -m pytest -n auto --dist=worksteal -q tests/axi/axi_lite
```

Use `-n 0` with a single test file when serial simulator logs are useful.

## `AxiLiteAsync`

`test_AxiLiteAsync.py` covers common-clock pass-through and four asynchronous
configurations: active-high reset, active-low reset, asynchronous reset, and
pipelined FIFO outputs. Its scenarios verify:

- ordinary read/write round trips and recovery after reset;
- local error responses while the master domain is reset;
- no replay of rejected or already queued requests after recovery;
- no stale response after a slave-domain reset;
- correct AW/W ordering when a reset splits a write transaction; and
- the one-pending-beat limit on AR, AW, and W, including VALID held while READY
  is low.

The asynchronous reset tests use a gateable master clock so the slave domain
can remain live while the remote domain is unavailable. Accepted handshakes are
monitored on both sides; final memory contents alone are not used to infer that
a rejected transaction stayed out of the downstream interface.
