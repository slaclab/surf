# RSSI Regressions

These tests follow the repository-wide [regression style guide](../../README.md)
and [protocol guidance](../README.md). The implementation and sizing guidance
is documented in [`protocols/rssi/README.md`](../../../protocols/rssi/README.md).

## Protocol Oracle And Layers

`rssi_test_utils.py` is the shared oracle for RSSI flags, header encoding,
checksum calculation, frame construction/parsing, SSI transport mechanics, and
common client/server setup. Keep protocol constants and mechanical helpers
there; keep assertions about RSSI policy in the test that names the behavior.

The suite progresses from leaves to integration:

- `test_RssiChksum.py` and `test_RssiHeaderReg.py` cover checksum and wire-header
  formatting.
- `test_RssiRxFsm.py`, `test_RssiTxFsm.py`, `test_RssiMonitor.py`, and
  `test_RssiConnFsm.py` cover receive/transmit legality, ACK/NULL/BUSY timing,
  retransmission, connection negotiation, close, and recovery.
- `test_RssiAxiLiteRegItf.py` covers the register map, range clamping,
  negotiated/current readback, counters, and visible controls/status.
- `test_RssiCore.py` covers direct client/server negotiation, payload transfer,
  backpressure, loss/retransmission, checksums, keepalive, close/reopen, BUSY,
  and AXI-Lite-controlled behavior.
- `test_RssiCoreWrapper.py` and `test_RssiCoreWrapperMultiStream.py` cover the
  packetizer/chunker boundary, segment/window configurations, routing,
  multi-stream loss recovery, and application-side sidebands.

Default CI runs the currently stable RSSI cases. Focused cases that still expose
unresolved RTL behavior are opt-in behind `RUN_RSSI_KNOWN_ISSUE_TESTS=1`, and a
smaller group of long-running integration cases additionally uses
`RUN_RSSI_EXTENDED_TESTS=1`. `COCOTB_TESTCASE` selects one named scenario, while
`COCOTB_TEST_FILTER` selects an applicable scenario group such as the client or
server connection-FSM cases. The `RUN_*` gates decide whether the corresponding
pytest node is eligible to launch a simulation. Keep these roles separate so an
enabled node cannot silently run unrelated scenarios.

Keep the skip reason beside each gated pytest entry. A known-issue case must
identify a durable defect reference or documented local issue, state the
expected failure, and say what change allows the gate to be removed. Promote the
case to default coverage in the same change that fixes the blocking RTL. Keep
stable-but-long coverage under the extended gate rather than calling it a known
issue.

## RSSI-Specific Expectations

The SURF RSSI profile uses 8-byte non-SYN headers, 24-byte SYN headers, 8-bit
sequence numbers, cumulative ACKs, ordered delivery, retransmission, NULL
keepalives, and BUSY flow control. Current hardware does not implement EACK
out-of-sequence delivery. Tests should use the SURF/Rogue profile as the
concrete contract and consult the RUDP lineage only where the profile leaves a
behavior unspecified.

Directed negative cases should verify that illegal flag combinations, malformed
headers, bad checksums, and out-of-order frames do not leak application payload.
Recovery cases should then send valid traffic and prove that the endpoint makes
forward progress without duplicate delivery.

When one methodology block can no longer describe a coherent set of scenarios,
split the integration suite by behavior while continuing to share the RSSI
oracle. Useful boundaries are negotiation and close, data and retransmission,
flow control and keepalive, connection lifecycle, AXI-Lite control, and
multi-stream integration. Preserve the existing pytest case names and gate
semantics during such a split so coverage does not disappear unnoticed.

Run the default suite with:

```bash
make MODULES="$PWD" import
./.venv/bin/python -m pytest -n auto --dist=worksteal -q tests/protocols/rssi
```

Run known-issue and extended cases explicitly with:

```bash
RUN_RSSI_KNOWN_ISSUE_TESTS=1 RUN_RSSI_EXTENDED_TESTS=1 \
    ./.venv/bin/python -m pytest -n 0 -q tests/protocols/rssi
```
