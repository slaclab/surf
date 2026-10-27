# AXI-Lite Regressions

This directory contains cocotb regressions for the reusable AXI-Lite cores in
[`axi/axi-lite/`](../../../axi/axi-lite/README.md). Tests use thin
IP-integrator wrappers where a flattened simulator interface is needed. Follow
the shared [test conventions](../../README.md) and
[runner guidance](../../common/README.md).

Run the directory with:

```bash
make MODULES="$PWD" import
./.venv/bin/python -m pytest -n auto --dist=worksteal -q tests/axi/axi_lite
```

Use `-n 0` with a single test file when serial simulator logs are useful.

## `AxiLiteCrossbar`

`test_AxiLiteCrossbar.py` groups scenarios by their integration fixture:

- `test_AxiLiteCrossbar` uses `AxiLiteCrossbarIpIntegrator` for direct/cascaded
  RAM accesses, decode errors, concurrent queued operations from one initiator,
  and directed read/write response backpressure.
- `test_AxiLiteCrossbarTermination` uses
  `AxiLiteCrossbarTerminationIpIntegrator` for two initiators, constant EMPTY
  responses, a cascaded crossbar, and RAM windows. It includes directed
  contention with independent read progress and reset with both R/B responses
  buffered, followed by recovery checks.

Both VHDL fixtures live in `axi/axi-lite/ip_integrator/` and are imported by
that subtree's ruckus manifest. They contain connectivity and real SURF cores;
stimulus and checking remain in Python. The raw source driver samples accepting
clock edges before the fixtures' 1 ns `TPD_G` updates and drives on falling
edges. It is needed to lower response READY immediately after request acceptance.

Run the complete module with:

```bash
./.venv/bin/python -m pytest -n 0 -q tests/axi/axi_lite/test_AxiLiteCrossbar.py
```

An external `COCOTB_TEST_FILTER` overrides the default scenario group. Select
the matching pytest node when using it, for example:

```bash
COCOTB_TEST_FILTER='termination_(stalled_owner|reset_buffered_responses)_test' \
  ./.venv/bin/python -m pytest -n 0 -q \
  tests/axi/axi_lite/test_AxiLiteCrossbar.py::test_AxiLiteCrossbarTermination
```

The random traffic oracle checks RAM data only for addresses previously written
by that worker; every response code and constant-target read is checked. The
directed scenarios check distinct known payloads. Reset uses the wrappers'
default synchronous reset configuration; no reset-generic sweep is implied.

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
