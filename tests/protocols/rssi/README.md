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
`RUN_RSSI_EXTENDED_TESTS=1`. Keep the skip reason beside each gated pytest entry
and promote the case to default coverage when its blocking RTL issue is fixed.

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
