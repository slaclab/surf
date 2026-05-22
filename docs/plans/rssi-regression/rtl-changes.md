# RSSI RTL Change Log

This file records production RTL changes made while implementing the RSSI
regression plan. Keep entries factual and update this file whenever the task
changes files under `protocols/rssi/v1/rtl/`. Simulation-only wrappers belong in
`progress.md` unless they change the intended DUT contract.

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

## 2026-05-22: `RssiRxFsm` Illegal DATA Flag Filtering

File: `protocols/rssi/v1/rtl/RssiRxFsm.vhd`

### What Changed

- Tightened receive-side DATA legality checking to use the current decoded
  header flags when deciding whether a transport frame is valid DATA.

### Why

The RSSI protocol requires DATA segments to carry a valid ACK field, and user
data must not be combined with BUSY, NULL, RST, or EACK control semantics. The
regression plan treats DATA without ACK and DATA with BUSY as invalid frames
that must be dropped without application delivery.

Using the current decoded flags avoids accepting an illegal DATA frame because
of stale registered flag state from a prior segment.

### Validation

- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed with DATA-without-ACK and DATA-plus-BUSY checks in the default RX FSM
  suite.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd`
  passed as part of the focused RSSI VHDL lint run recorded in `progress.md`.

## Known RTL Issues Captured By Tests

### `RssiTxFsm` Multi-Word DATA Buffering

The opt-in test
`multi_word_data_preserves_payload_keep_and_resend_known_issue_test` currently
fails when `RUN_RSSI_KNOWN_ISSUE_TESTS=1`. For a three-word application frame,
the TX path emits payload words 2, 3, and 3 instead of words 1, 2, and 3.

This is not fixed yet. The failure points at application-side buffer write
alignment for multi-beat DATA frames. Keep this section updated when that bug is
fixed or deliberately reclassified.
