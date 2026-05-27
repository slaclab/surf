# RSSI RTL Changes

This file summarizes the current production RTL changes made while implementing
the RSSI regression plan. Keep it aligned with the actual implemented RTL state,
not as a chronological log. Update or replace entries when the production RTL
changes under `protocols/rssi/v1/rtl/`; simulation-only wrappers belong in
`progress.md` unless they change the intended DUT contract.

## 2026-05-22: `RssiMonitor` Server Null Timeout Liveness

File: `protocols/rssi/v1/rtl/RssiMonitor.vhd`

### What Changed

- Removed standalone ACK and BUSY receive events from the server null-timeout
  counter reset condition.
- Left DATA and NULL receive events as the liveness refreshes for server mode.
- Left received BUSY handling in the retransmission timeout path unchanged, so
  remote BUSY still suppresses retransmission timeout progress.

### Why

The RSSI protocol page describes the server null timeout as detecting the
absence of DATA or NULL packets. ACK/BUSY-only traffic should not keep the
server link alive indefinitely when the peer is no longer sending DATA or NULL
keepalive traffic.

### Validation

- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiMonitor.py`
  passed.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiMonitor.vhd protocols/rssi/v1/wrappers/RssiMonitorWrapper.vhd`
  passed.

### Related Tests

- `tests/protocols/rssi/test_RssiMonitor.py` verifies received BUSY suppresses
  retransmission timeout progress and verifies ACK/BUSY-only server traffic
  does not prevent null-timeout close.

## 2026-05-27: `RssiMonitor` Periodic Local Busy ACK Requests

File: `protocols/rssi/v1/rtl/RssiMonitor.vhd`

### What Changed

- Updated ACK timeout counter reset logic so local BUSY can keep the ACK
  timeout counter running after a busy ACK has already been transmitted.
- Added a steady local-BUSY ACK request at `Retransmission Timeout/2` when there
  is no newly pending receive sequence number to acknowledge.
- Restricted the ordinary cumulative ACK timeout request to cases where
  `rxLastSeqN_i` has advanced beyond the last ACKed receive sequence.

### Why

The RSSI BUSY flow-control behavior relies on the busy receiver periodically
advertising BUSY so the peer transmitter keeps resetting its retransmission
timer. Before this change, `RssiMonitor` requested an ACK on the local BUSY
rising edge, but once that ACK was transmitted the normal "nothing pending to
acknowledge" reset condition prevented further periodic busy ACK requests.

The RSSI protocol page recommends a Retransmission Timeout/2 cadence for BUSY
acknowledgments. Using that cadence also avoids generating BUSY ACKs through the
cumulative ACK timeout path when no new received sequence is pending.

### Validation

- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiMonitor.py`
  passed.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiConnFsm.vhd protocols/rssi/v1/rtl/RssiMonitor.vhd protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd`
  passed.

### Related Tests

- `tests/protocols/rssi/test_RssiMonitor.py` verifies a local BUSY rising edge
  requests an ACK immediately and verifies steady local BUSY requests another
  ACK at Retransmission Timeout/2 even when the cumulative ACK timeout is
  shorter.

## 2026-05-27: `RssiConnFsm` Peer Parameter Range Validation

File: `protocols/rssi/v1/rtl/RssiConnFsm.vhd`

### What Changed

- Added local helpers to validate peer RSSI parameters before negotiation uses
  them.
- Rejected peer SYN/SYN+ACK parameters where `maxOutsSeg`, `retransTout`,
  `cumulAckTout`, or `nullSegTout` are zero, or where `maxSegSize` is below the
  minimum 8-byte segment granularity used by the core.
- Clamped negotiated local window and buffer sizes to the legal implementation
  ranges before assigning integer state.
- Changed server-side mismatch handling so invalid peer parameters cause a full
  local-parameter proposal instead of accepting the peer record and then
  partially overwriting required matching fields.

### Why

Peer-provided connection parameters are protocol inputs and can arrive before
the local AXI-Lite register map has had a chance to constrain the peer's values.
The previous server path converted `maxOutsSeg` and `maxSegSize/8` directly into
integer state before checking for invalid zero or undersized values. That could
produce illegal window/buffer sizes or simulation range errors instead of the
RSSI negotiation behavior of rejecting/proposing valid parameters.

The client path already rejected required version/checksum/timeout-unit
mismatches; it now also rejects out-of-range peer values with a RST, matching the
same validity boundary.

### Validation

- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiConnFsm.py`
  passed.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiConnFsm.vhd protocols/rssi/v1/rtl/RssiMonitor.vhd protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd`
  passed.

### Related Tests

- `tests/protocols/rssi/test_RssiConnFsm.py` verifies server rejection/proposal
  for out-of-range SYN parameters and client rejection/RST for out-of-range
  SYN+ACK parameters.

## 2026-05-27: `RssiAxiLiteRegItf` Writable Parameter Clamps

File: `protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd`

### What Changed

- Added write-time clamping for `appRssiParam.maxOutsSeg` to the legal
  `1 .. MAX_NUM_OUTS_SEG_G` range.
- Added write-time minimum clamps for `retransTout`, `cumulAckTout`, and
  `nullSegTout` so software cannot program zero-timeout runtime values.
- Left the existing `maxSegSize` clamp behavior unchanged.

### Why

The AXI-Lite register interface is the software-facing source of local RSSI
parameters. Allowing zero outstanding segments or zero timeout fields creates
invalid negotiated parameters and can break the monitor/connection FSM timing
assumptions. Clamping at the register boundary keeps local runtime parameters in
the same valid range enforced during peer negotiation.

### Validation

- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiAxiLiteRegItf.py`
  passed.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiConnFsm.vhd protocols/rssi/v1/rtl/RssiMonitor.vhd protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd`
  passed.

### Related Tests

- `tests/protocols/rssi/test_RssiAxiLiteRegItf.py` verifies `maxOutsSeg` clamps
  at both ends and that the writable timeout fields clamp zero to one.

## 2026-05-22: `RssiTxFsm` Checksum Fault Injection

File: `protocols/rssi/v1/rtl/RssiTxFsm.vhd`

### What Changed

- Added `s_corruptHeader`, derived from the completed header plus checksum by
  XORing only the low 16-bit checksum field:

  ```vhdl
  s_corruptHeader <= s_headerAndChksum xor x"000000000000FFFF";
  ```

- Updated ACK and NULL transmit paths to honor `r.injectFaultReg`.
- Kept DATA and resend fault injection behavior one-shot, but changed the
  corruption target from the full 64-bit emitted header word to only the
  checksum field.
- Cleared `r.injectFaultReg` after the corrupted ACK, NULL, DATA, or resend
  header is emitted.

### Why

The AXI-Lite register comment and PyRogue model describe fault injection as a
one-shot corruption of the next packet header checksum. Before this change,
`RssiTxFsm` only applied the fault in DATA and resend paths, and those paths
inverted the whole 64-bit header word. That behavior could corrupt flags,
header length, sequence number, and acknowledgment number, which made the debug
feature broader than documented.

The new behavior keeps the header fields intact and makes the emitted segment
fail checksum validation only. It also brings ACK and NULL into the documented
fault-injection scope.

### Validation

- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiTxFsm.vhd`
  passed.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  passed with the multi-word DATA known-issue test skipped by default.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed.

### Related Tests

- `tests/protocols/rssi/test_RssiTxFsm.py` now verifies ACK, NULL, and DATA
  fault injection by checking that the packet fields are unchanged, the
  checksum is flipped from the deterministic test checksum, and the Python
  checksum oracle rejects the header.

## 2026-05-23: `RssiTxFsm` NULL Suppression With Unacknowledged DATA

File: `protocols/rssi/v1/rtl/RssiTxFsm.vhd`

### What Changed

- Changed the connected-state NULL request gate from `bufferFull = '0'` to
  `bufferEmpty = '1'`.
- A NULL segment can still be generated when idle, but it is no longer allowed
  to enter the transmit sequence while an earlier DATA/NULL/RST segment remains
  in the unacknowledged transmit buffer.

### Why

Integrated checksum-fault recovery exposed a sequence hazard: if a DATA segment
is lost or rejected by checksum, a later client NULL can consume the next RSSI
sequence number before the lost DATA is retransmitted. The peer can then advance
its in-order receive sequence with the NULL and treat the DATA retransmit as
old.

The RSSI page describes client NULL traffic as idle keepalive behavior. Blocking
NULL generation while the transmit buffer is non-empty preserves recovery order
for outstanding DATA.

### Validation

- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiTxFsm.vhd`
  passed.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed.

### Related Tests

- `tests/protocols/rssi/test_RssiTxFsm.py` verifies a NULL request is ignored
  while a DATA segment is still unacknowledged.
- `tests/protocols/rssi/test_RssiCore.py` verifies dropped and
  checksum-corrupted client DATA frames are recovered by retransmission with
  the same RSSI sequence number and payload.

## 2026-05-22: `RssiRxFsm` Illegal DATA Flag Filtering

File: `protocols/rssi/v1/rtl/RssiRxFsm.vhd`

### What Changed

- Tightened receive-side DATA legality checking to use the current decoded
  header flags when deciding whether a transport frame is valid DATA.
- Changed non-SYN EACK handling from "do not enter the validation path" to an
  explicit validation failure, so unsupported EACK segments drop instead of
  leaving the RX FSM waiting for a decision.

### Why

The RSSI protocol requires DATA segments to carry a valid ACK field, and user
data must not be combined with BUSY, NULL, RST, or EACK control semantics. The
regression plan treats DATA without ACK and DATA with BUSY as invalid frames
that must be dropped without application delivery.

Using the current decoded flags avoids accepting an illegal DATA frame because
of stale registered flag state from a prior segment.

The SURF/Rogue RSSI hardware profile omits EACK support. Unsupported EACK
segments should be rejected explicitly rather than stalling in the receive
header screen.

### Validation

- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed with DATA-without-ACK, DATA-plus-BUSY, and DATA-plus-EACK checks in
  the default RX FSM suite.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd`
  passed.

## 2026-05-22: `RssiRxFsm` SYN Filtering And Parameter Staging

File: `protocols/rssi/v1/rtl/RssiRxFsm.vhd`

### What Changed

- Added staging registers for received SYN parameters.
- Committed staged SYN parameters to `rxParam_o` only after the SYN passes
  checksum, header-length, and frame-boundary checks.
- Rejected SYN frames combined with NULL, BUSY, RST, or EACK control flags.
- Required the final SYN parameter word to be a clean EOF without EOFE.

### Why

SYN carries connection parameters rather than application payload. A malformed
SYN should not partially update the visible peer parameters before being
dropped, and a SYN frame that continues past the expected 24-byte header should
not be accepted as a valid connection setup segment.

### Validation

- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py`
  passed.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd`
  passed.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed.

### Related Tests

- `tests/protocols/rssi/test_RssiRxFsm.py` verifies valid SYN parameter
  capture, SYN+EACK/BUSY/RST/NULL drops, and SYN-with-extra-payload drops
  without changing `rxParam_o` or producing application output.

## 2026-05-23: `RssiRxFsm` Integrated DATA Payload Timing

File: `protocols/rssi/v1/rtl/RssiRxFsm.vhd`

### What Changed

- Corrected DATA EOF segment length calculation to use the incremented
  next-state segment address.
- Added registered payload write-data staging for DATA RAM writes while
  preserving the existing checksum/header write path.
- Added an application-output `READ_S` state so the first DATA beat is emitted
  after the registered RAM read data is available.
- Made the final application DATA beat wait for `appSsiSlave_i.pause = '0'`
  before marking the segment sent and releasing the receive buffer.

### Why

The integrated RSSI core wrapper exposed receive-path timing that standalone
unit tests did not cover. A one-word DATA segment was recorded with a zero
payload length, and the application-output path read the registered payload RAM
one cycle too early, producing a zero first beat in the delivered application
frame.

The write-data staging keeps the DATA payload aligned with the delayed payload
write enable while leaving the checksum/SYN header words on the original
current-cycle data path.

### Validation

- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiTxFsm.vhd protocols/rssi/v1/rtl/RssiRxFsm.vhd`
  passed.
- `make MODULES=/Users/bareese import` passed.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py`
  passed.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed.

### Related Tests

- `tests/protocols/rssi/test_RssiCore.py` includes default bidirectional
  payload delivery regression coverage with passive transport monitors that
  confirm both transport DATA frames carry the expected payload before peer RX.

## 2026-05-23: `RssiRxFsm` Duplicate DATA Payload Filtering

File: `protocols/rssi/v1/rtl/RssiRxFsm.vhd`

### What Changed

- Tightened DATA receive screening so only the next in-order sequence number can
  enter `DATA_S` and write into the receive payload buffer.
- Duplicate DATA frames are now dropped before payload buffering, instead of
  being allowed into `DATA_S` and then rejected later in `VALID_S`.

### Why

The integrated loss/retransmission regression showed that duplicate DATA can
arrive after a lost segment has already been retransmitted and delivered. The
previous broad sequence check allowed both the current and next sequence
numbers into the DATA payload path. The later `VALID_S` state did not advance
or mark a duplicate as occupied, but the duplicate had already been allowed to
touch payload-buffer side state.

Dropping duplicate DATA before payload buffering matches the SURF/Rogue RSSI
hardware profile: out-of-order or duplicate DATA is not queued, and recovery
comes from retransmission of the missing in-order segment.

### Validation

- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd`
  passed.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed.

### Related Tests

- `tests/protocols/rssi/test_RssiCore.py` now drops the first client DATA
  transport frame, observes retransmission with the same RSSI sequence number
  and payload, and verifies the recovered payload is delivered once at the
  server application boundary.

## 2026-05-26: `RssiCore` Small Segment FIFO Pause Threshold

File: `protocols/rssi/v1/rtl/RssiCore.vhd`

### What Changed

- Added `FIFO_PAUSE_THRESH_C` and clamped the output FIFO pause threshold to at
  least 1:

  ```vhdl
  constant FIFO_PAUSE_THRESH_C : positive := maximum(1, (2**SEGMENT_ADDR_SIZE_G) - 16);
  ```

- Used that constant for both application-side and transport-side output
  `AxiStreamFifoV2` instances.

### Why

`RssiCoreWrapper` derives `SEGMENT_ADDR_SIZE_G` from `MAX_SEG_SIZE_G`. The
previous pause-threshold expression, `(2**SEGMENT_ADDR_SIZE_G) - 16`,
elaborated for 256-byte wrapper segments but became 0 or negative for smaller
segment sizes such as 128 bytes and 64 bytes. `AxiStreamFifoV2` requires
`FIFO_PAUSE_THRESH_G` to be in the positive range, so these smaller segment
configurations failed during elaboration before the regression could exercise
the connection.

Clamping preserves the existing threshold for larger segment buffers and makes
small segment configurations legal to elaborate.

### Validation

- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiCore.vhd`
  passed.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py`
  passed with four wrapper parameter cases.

### Related Tests

- `tests/protocols/rssi/test_RssiCoreWrapper.py` now sweeps
  `WINDOW_ADDR_SIZE_G` values 1, 2, and 3 and `MAX_SEG_SIZE_G` values 64, 128,
  and 256 across bypass-chunker and packetizer modes.

## 2026-05-22: `RssiConnFsm` Retry Timeout Counter Saturation

File: `protocols/rssi/v1/rtl/RssiConnFsm.vhd`

### What Changed

- Updated the wait-for-SYN and wait-for-ACK states to stop incrementing
  `timeoutCntr` once it reaches the retransmission timeout threshold.
- Left the existing retry and peer-timeout decisions keyed to the saturated
  threshold value.

### Why

`timeoutCntr` is constrained to the retransmission timeout range. The retry
wait states previously incremented the counter before testing for retry or
peer-timeout, which could drive the counter past its declared range in
simulation at the exact timeout boundary.

Saturating the counter preserves the intended retry/close behavior while
keeping the registered value inside its declared bounds.

### Validation

- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiConnFsm.py`
  passed.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiConnFsm.vhd`
  passed.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiConnFsm.py`
  passed.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed.

### Related Tests

- `tests/protocols/rssi/test_RssiConnFsm.py` verifies server SYN+ACK retry and
  client SYN retry behavior, then verifies peer-timeout closure after the retry
  count is exhausted.
