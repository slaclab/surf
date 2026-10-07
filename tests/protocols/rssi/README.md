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
- `test_RssiCoreRx.py` checks default core RX coverage with an independent wire
  peer: DATA+BUSY, duplicate suppression, sequence wrap, and close/reopen with
  unread data. It also checks real client/server negotiation.
- `test_RssiCore.py` covers direct client/server negotiation, payload transfer,
  backpressure, loss/retransmission, checksums, keepalive, close/reopen, BUSY,
  and AXI-Lite-controlled behavior.
- `test_RssiCoreKeepalive.py` covers sustained server DATA with an independent
  ACK-only wire peer and subsequent receive-liveness timeout through the real
  server core. It runs by default, independently of the gated core tests.
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

## Keepalive Compatibility Regression

The [implementation compatibility contract](../../../protocols/rssi/README.md#keepalive-compatibility-contract)
requires a server to remain connected while receiving valid ACKs, including
ACKs carrying BUSY. Rogue and the RTL client postpone NULL transmission while
transmitting ACKs. Requiring DATA/NULL-only reverse traffic would disconnect a
healthy server-to-client stream. ACKs need not advance the receive sequence to
demonstrate liveness.

| Layer | Required checks | Scope |
| --- | --- | --- |
| Monitor: `test_RssiMonitor.py` | Valid DATA, NULL, ACK and BUSY independently refresh liveness; silence and invalid flags time out; periodic BUSY ACK behavior remains covered. | Drives decoded inputs directly; does not validate wire frames. |
| Core: `test_RssiCoreKeepalive.py` | Negotiate SYN/SYN+ACK/ACK; verify every server DATA payload, sequence, checksum and SSI boundary; send only ACK replies for at least four negotiated NULL timeout periods; require continuous connection, then silence-triggered closure with the NULL-timeout status. | Production server TX/RX, checksum, monitor, connection FSM, FIFOs and RAM, using an independent Python wire peer. |
| Rogue/hardware acceptance | Sustain server-to-host traffic through the deployed Rogue, UDP/Ethernet and FPGA image; verify received data and absence of timeout/reconnect cycles, then verify recovery after peer loss. | Actual interoperability; the first two layers do not establish this result. |

The core regression checks ACK spacing below the nominal client NULL interval
and deliberately sends no client DATA/NULL after connection setup. It drains
the acknowledged transmit window before silence so retransmission failure
cannot substitute for a receive-liveness timeout. The unused RTL client in the
existing integration wrapper remains closed; the test does not claim to test
the client NULL generator or the Rogue executable. Payload or initialization
errors must fail the scenario, not be hidden by draining unexpected frames.

For a keepalive behavior change, run this regression against both the corrected
RTL and the known-bad monitor from `ce66ccf99` (the v2.75.0 monitor behavior).
Use a separate scratch source tree/build for the comparison, changing only
`RssiMonitor.vhd`; retain the same test and all other RTL. The bad monitor must
fail on connection continuity during ACK-only streaming, before the silence
phase. A passing monitor unit test alone is not enough evidence.

```bash
./.venv/bin/python -m pytest -n 0 -q \
    tests/protocols/rssi/test_RssiMonitor.py \
    tests/protocols/rssi/test_RssiCoreKeepalive.py
```

Historical RSSI prose is not a substitute for an interoperability check. When
it conflicts with the transmit/receive behavior of supported peers, record the
discrepancy and evidence before choosing a test expectation. In particular,
the DATA/NULL-only expectation introduced with #1454 was incorrect even though
its directed monitor test passed.

## Suite Organization And Commands

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
