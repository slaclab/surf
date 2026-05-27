# RSSI RTL Spec Review

## Purpose
This review captures likely compliance risks and high-value regression targets
before implementing RSSI cocotb tests. It compares the RSSI RTL in
`protocols/rssi/v1/rtl/` against the local protocol bundle under
`docs/plans/rssi-regression/references/`.

Use this file as a test-planning input, not as a final bug report. Each item
needs an executable regression before changing RTL behavior.

## Reference Baseline
- Primary protocol target: `references/confluence/reliable-slac-streaming-protocol-rssi.html`.
- RUDP/RDP background: `references/rfc/rfc908.txt`,
  `references/rfc/rfc1151.txt`, and
  `references/rfc/draft-ietf-sigtran-reliable-udp-00.txt`.
- Rogue software reference: `references/rogue/` and local Rogue RSSI sources
  under `/Users/bareese/rogue/`.

The SLAC RSSI page is the concrete hardware profile. It explicitly differs
from RUDP by omitting EACK/out-of-sequence acknowledgments and transfer-state
behavior.

## Findings And Attention Areas

### 1. RX legality checks appear to allow DATA without ACK, and DATA+BUSY
Spec rule: a segment carrying user data always has ACK set, and user data
cannot appear with NULL, BUSY, or RST.

RTL evidence:
- `RssiRxFsm` derives `rxF.data` from frame length, not from the ACK bit:
  `protocols/rssi/v1/rtl/RssiRxFsm.vhd:331`.
- Non-SYN validation checks checksum, 8-byte header length, sequence range, and
  ACK-number range, but does not require ACK for data:
  `protocols/rssi/v1/rtl/RssiRxFsm.vhd:393`.
- DATA is rejected when combined with NUL or RST, but BUSY is not included in
  that exclusion:
  `protocols/rssi/v1/rtl/RssiRxFsm.vhd:407`.

Regression target:
- Send DATA with ACK clear and expect drop/no application delivery.
- Send DATA+BUSY and expect drop/no application delivery.
- Also verify valid DATA with ACK set still accepts and advances sequence.

### 2. SYN flag combination filtering is narrow
Spec rule: SYN is used for connection establishment, carries the 24-byte SYN
parameter header, and must not be combined with user data. SYN, BUSY, and RST
are mutually exclusive.

RTL evidence:
- `RssiRxFsm` rejects SYN when EACK, RST, or BUSY is set, and validates
  24-byte length/checksum later:
  `protocols/rssi/v1/rtl/RssiRxFsm.vhd:370`.
- The first-stage SYN filter does not explicitly reject NUL, nor does it have
  an early explicit user-payload-with-SYN check:
  `protocols/rssi/v1/rtl/RssiRxFsm.vhd:381`.

Regression target:
- SYN+BUSY and SYN+RST should drop.
- SYN+NUL should be tested and either dropped or documented as an accepted RTL
  behavior if the spec interpretation is narrowed.
- SYN with extra payload beyond the 24-byte header should not become
  application data or a valid open.

### 3. Server NULL timeout resets on ACK/BUSY, not only DATA/NUL
Spec rule: if no DATA or NULL packets are received within Null Timeout, the
server detects inactivity and closes the connection.

RTL evidence:
- In server mode, `RssiMonitor` resets the null-timeout counter on DATA, NUL,
  ACK, or BUSY:
  `protocols/rssi/v1/rtl/RssiMonitor.vhd:309`.

Regression target:
- Keep a server open with only standalone ACK/BUSY frames and check whether it
  times out. The spec-shaped expectation is timeout unless the team decides
  ACK/BUSY should count as liveness for this hardware profile.

### 4. Parameter range validation is incomplete at runtime
Spec rule: timeout values have nonzero ranges; max outstanding segments and
max segment size are accepted from the peer but clamped to local capacity; some
fields are non-negotiable and must match exactly.

RTL evidence:
- `RssiConnFsm` enforces version, checksum-enable, and timeout-unit equality:
  `protocols/rssi/v1/rtl/RssiConnFsm.vhd:239` and
  `protocols/rssi/v1/rtl/RssiConnFsm.vhd:354`.
- `RssiConnFsm` clamps max outstanding segments and max segment size against
  local values, but does not validate zero or illegal timeout/counter values:
  `protocols/rssi/v1/rtl/RssiConnFsm.vhd:250` and
  `protocols/rssi/v1/rtl/RssiConnFsm.vhd:333`.
- `RssiAxiLiteRegItf` clamps `maxSegSize`, but does not similarly clamp
  `maxOutsSeg`, `retransTout`, `cumulAckTout`, `nullSegTout`, or
  `maxCumAck`:
  `protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd:247`.

Regression target:
- Exercise non-matching version, CHK, and timeout unit.
- Exercise peer max outstanding larger than local capacity and verify clamp.
- Exercise zero/illegal AXI-Lite and SYN values to identify current simulator
  behavior and decide whether RTL should reject, clamp, or document them.

### 5. RST is transmitted with a sequence number but not buffered for resend
Spec rule: the transmitter buffers sent segments until acknowledged and
retransmits unacknowledged segments after timeout. The page later says a peer
closes by sending RST after maximum retransmissions.

RTL evidence:
- `RssiTxFsm` explicitly does not buffer RST and comments that RST will not be
  retransmitted:
  `protocols/rssi/v1/rtl/RssiTxFsm.vhd:1044` and
  `protocols/rssi/v1/rtl/RssiTxFsm.vhd:1097`.

Regression target:
- Treat this as a deliberate behavior candidate, not an automatic bug. Add a
  test that captures current RST behavior and decide whether the spec should
  require RST retransmission or whether immediate close is the hardware
  contract.

### 6. Checksum fault injection does not match the register comment
Register comment: fault injection acts on the next segment, listed as ACK,
NULL, or DATA.

RTL evidence:
- `RssiAxiLiteRegItf` documents one-shot injection for ACK, NULL, or DATA:
  `protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd:14`.
- `RssiTxFsm` applies the fault in the DATA header path and resend header path:
  `protocols/rssi/v1/rtl/RssiTxFsm.vhd:1268` and
  `protocols/rssi/v1/rtl/RssiTxFsm.vhd:1445`.
- Standalone ACK, NULL, and RST header paths add checksum without consulting
  `injectFaultReg`:
  `protocols/rssi/v1/rtl/RssiTxFsm.vhd:968`,
  `protocols/rssi/v1/rtl/RssiTxFsm.vhd:1056`, and
  `protocols/rssi/v1/rtl/RssiTxFsm.vhd:1140`.

Regression target:
- AXI-Lite/Core test: arm injection before ACK, NULL, and DATA separately.
  Expect either "next DATA/resend only" or update RTL/docs to honor the stated
  ACK/NULL/DATA contract.

### 7. Out-of-order behavior differs between SLAC RSSI RTL profile and Rogue
Spec rule: current RSSI drops out-of-order received segments and waits for
retransmission. No out-of-order acknowledgments are supported.

RTL evidence:
- `RssiRxFsm` accepts only duplicate/current or next sequence values in the
  first header screen, then only stores the next in-order sequence:
  `protocols/rssi/v1/rtl/RssiRxFsm.vhd:401` and
  `protocols/rssi/v1/rtl/RssiRxFsm.vhd:577`.
- Rogue software has an out-of-order queue:
  `/Users/bareese/rogue/src/rogue/protocols/rssi/Controller.cpp:262`.

Regression target:
- Hardware regression should follow the SLAC RSSI page and expect
  out-of-order DATA to be dropped, then recovered by retransmission.
- Do not write SURF RTL tests that require Rogue software's out-of-order queue.

Resolution:
- Closed as an RSSI v1 hardware-profile decision on 2026-05-27.
- The primary SLAC RSSI page says the EACK bit is reserved/not used in this
  version, out-of-order segments are dropped, and no out-of-order
  acknowledgments are supported. Its RUDP differences section explicitly lists
  no out-of-sequence acknowledgments.
- RFC/RUDP EACK behavior remains background only. SURF RSSI tests should verify
  explicit rejection of received EACK flag combinations, not EACK compliance.
- Default RX coverage now rejects SYN+EACK, DATA+EACK, and standalone ACK+EACK.
- `maxOutofseq`/EACK-facing fields are kept only as reserved compatibility
  surface unless a future RSSI profile deliberately implements EACK.

### 8. BUSY behavior needs explicit characterization
Spec rule: BUSY on outgoing data/ACK tells the peer the receiver is busy; the
peer resets the retransmission timer. The page recommends periodic BUSY ACKs
at Retransmission Timeout/2 and notes firmware/server-client limitations.

RTL evidence:
- `RssiMonitor` resets retransmit accounting on received BUSY:
  `protocols/rssi/v1/rtl/RssiMonitor.vhd:217`.
- Local busy drives the transmitted BUSY flag through `RssiHeaderReg`:
  `protocols/rssi/v1/rtl/RssiCore.vhd:578`.
- ACK generation while busy is driven by cumulative-ACK timeout/local-busy
  logic, not a dedicated Retransmission Timeout/2 periodic timer:
  `protocols/rssi/v1/rtl/RssiMonitor.vhd:362` and
  `protocols/rssi/v1/rtl/RssiMonitor.vhd:390`.

Regression target:
- Verify received BUSY prevents retransmission timeout progress.
- Verify local busy appears on outgoing ACK/DATA headers.
- Measure periodic busy ACK behavior and document whether it is a recommendation
  deviation or a defect.

### 9. Header checksum is header-only and should be tested independently
Spec rule: RSSI uses the 16-bit one's-complement checksum over the RSSI header
only; payload checksum is not supported.

RTL evidence:
- `RssiChksum` sums four 16-bit lanes per 64-bit word and outputs one's
  complement:
  `protocols/rssi/v1/rtl/RssiChksum.vhd:97` and
  `protocols/rssi/v1/rtl/RssiChksum.vhd:130`.
- `RssiCore` feeds header words into checksum paths, not payload words:
  `protocols/rssi/v1/rtl/RssiCore.vhd:735`.

Regression target:
- Direct `RssiChksum` known-vector tests.
- Header encode/checksum round trips for ACK, NULL, DATA, RST, and SYN.
- Checksum-disabled path should still accept valid frames with zeroed checksum
  fields per current RTL contract.

## Module-Level Regression Implications
Before the integrated client/server tests, add focused leaf/module tests for:
- `RssiChksum`: known vectors, validation mode, reset/enable timing.
- `RssiHeaderReg`: every emitted segment type and legal flag/length fields.
- `RssiRxFsm`: legal/illegal header filtering, in-order acceptance,
  out-of-order drop, duplicate drop, checksum behavior, SYN parsing.
- `RssiTxFsm`: sequence consumption, ACK no-consume, transmit-window buffering,
  cumulative ACK freeing, retransmit without new sequence numbers, fault
  injection behavior.
- `RssiMonitor`: cumulative ACK requests, NUL generation at Null Timeout/3,
  server timeout, received BUSY timer reset, local busy ACK generation.
- `RssiConnFsm`: client/server handshake states, non-negotiable mismatch
  rejection, max segment/window clamp behavior, timeout/retry behavior.
- `RssiAxiLiteRegItf`: register defaults, write/readback, clamping,
  CDC-synchronized status/counter reads, DECERR behavior.

The `RssiCore` client/server regression should then prove interaction-level
protocol behavior rather than serving as the only way to test leaf edge cases.
