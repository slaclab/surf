# JESD204B Regression Suite

This directory holds the checked-in cocotb regressions for the SURF JESD204B
protocol cores under `protocols/jesd204b/`.  The suite targets the 8B/10B
link layer as specified in JESD204B (July 2011).  Every bench cites the spec
clause it exercises, and DUT-facing tests assert spec-correct behavior rather
than working around non-compliance.

The suite covers all 8 link-layer areas: CGS, ILAS, character replacement,
frame/multiframe timing, SYSREF/deterministic latency, scrambling, error
reporting, and resync.

## Coverage Model

The benches in this directory fall into three categories:

- **Normative** — the test drives protocol-shaped traffic that closely matches
  the published JESD204B packet and framing layout; coverage is treated as
  spec evidence for the exercised subset.
- **Partial protocol** — the test uses spec-shaped stimulus and field ordering,
  but the current RTL only exposes or processes a reduced subset of the full
  wire protocol.  The limitation is intentional and documented.
- **RTL-contract** — the test is primarily verifying local assembly, buffering,
  arbitration, or transport behavior rather than proving full protocol legality.

When a bench is not full normative coverage, that is an intentional scoping
decision, not silent proof of complete spec compliance.

## Bench Map

| Test file | DUT surface | Spec relation | Status |
| --- | --- | --- | --- |
| `test_JesdLmfcGen.py` | `JesdLmfcGen` | LMFC period = K×F/4 device clocks; SYSREF-gated realignment (JESD204B §8.6.2, §8.8.3) | done |
| `test_JesdScramblerWrapper.py` | `JesdAlignChGen` → `JesdAlignFrRepCh` round-trip | 1+x^14+x^15 scrambler/descrambler data integrity (JESD204B §8.7) | done |
| `test_Jesd16bTo32b.py` | `Jesd16bTo32b` | 16→32-bit width adapter CDC contract: word order, valid alignment, dual-clock modes | done |
| `test_Jesd32bTo16b.py` | `Jesd32bTo16b` | 32→16-bit width adapter CDC contract: word order, valid pipeline, dual-clock modes | done |
| `test_JesdIlasGen.py` | `JesdIlasGen` | ILAS multiframe count, /R/ open, /A/ close, /Q/ + link-config octets (JESD204B §8.4, §8.5) | done |
| `test_JesdAlignChGen.py` | `JesdAlignChGen` | /F/ and /A/ character replacement rules for scrambled and non-scrambled modes (JESD204B §8.7.3) | covered-via `test_JesdTxLane.py` (character replacement in-context) and `test_JesdScramblerWrapper.py` (direct `JesdAlignChGen` round-trip); no standalone bench |
| `test_JesdSyncFsmTx.py` | `JesdSyncFsmTx` | CGS /K28.5/ emission; SYNC~→ILAS→DATA transition under Subclass 0 and 1 LMFC gating (JESD204B §7.1, §8.4) | done |
| `test_JesdTxLane.py` | `JesdTxLane` | Full TX lane path from data input through scrambler, character replacement, CGS/ILAS/DATA FSM | done |
| `test_JesdAlignFrRepCh.py` | `JesdAlignFrRepCh` | Character restoration for scrambled and non-scrambled modes; alignment error detection (JESD204B §8.7.3) | done |
| `test_JesdSyncFsmRx.py` | `JesdSyncFsmRx` | K-detection threshold, SYNC~ assertion/deassertion, DATA-state stable-K resync verdict (JESD204B §7.1, §7.6.3) | done |
| `test_JesdRxLane.py` | `JesdRxLane` | ILAS multiframe counting through ILA state; DATA phase entry; GT-reported error latching and clearErr behavior | done |
| `test_JesdTxReg.py` | `JesdTxReg` via `Jesd204bTx` | AXI-Lite enable, sysrefDly, commonCtrl, per-lane status fields and valid counters | done |
| `test_JesdRxReg.py` | `JesdRxReg` via `Jesd204bRx` | AXI-Lite enable, sysrefDly, linkErrMask, rawData capture, per-lane latency and status | done |
| `test_Jesd204bLoopback.py` | `Jesd204bLoopbackWrapper` | Full CGS→ILAS→DATA loopback: scrambler data integrity, deterministic latency, resync, error injection | done |
