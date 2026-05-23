# RSSI Regression Progress

## Current Status
- Task plan created.
- Local reference bundle created under `references/`.
- Pre-implementation RTL/spec review created in `rtl-spec-review.md`.
- Production RTL changes are now tracked in `rtl-changes.md`.
- Expected-behavior decisions, first implementation slice, and wrapper strategy
  have been written into `plan.md`.
- Phase 1 implementation has started:
  - Added shared RSSI protocol helpers in
    `tests/protocols/rssi/rssi_test_utils.py`.
  - Added direct `RssiChksum` cocotb coverage in
    `tests/protocols/rssi/test_RssiChksum.py`.
  - Added `RssiHeaderReg` cocotb coverage in
    `tests/protocols/rssi/test_RssiHeaderReg.py`.
  - Added `protocols/rssi/v1/wrappers/RssiHeaderRegWrapper.vhd` because GHDL
    cocotb did not expose the `RssiParamType` record port as Python child
    handles.
  - Updated `protocols/rssi/v1/ruckus.tcl` to include the wrapper directory as
    simulation-only VHDL.
- Phase 2 implementation has started:
  - Added `protocols/rssi/v1/wrappers/RssiRxFsmWrapper.vhd` with flattened
    transport/application SSI ports and a small behavioral segment buffer.
  - Added `tests/protocols/rssi/test_RssiRxFsm.py` covering in-order DATA
    acceptance and checksum-failure drops.
  - Renamed the `RssiRxFsmWrapper` flattened SSI ports to the shared
    `sAxis`/`mAxis` cocotb convention and refactored the RX test to reuse
    `tests/protocols/ssi/ssi_test_utils.py` for stream drive and quiet-output
    checks.
  - Added default `RssiRxFsm` coverage for DATA without ACK and DATA+BUSY
    drops after tightening the RTL legality check to use the current decoded
    header flags.
  - Fixed the `RssiRxFsmWrapper` segment RAM read timing and `TKEEP` wiring so
    full application payload delivery is now covered by the default RX FSM
    regression.
  - Added `protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd` with flattened
    application/transport SSI ports, a real `RssiHeaderReg` hookup, a
    deterministic checksum handshake, and a small behavioral segment RAM.
  - Added `tests/protocols/rssi/test_RssiTxFsm.py` covering standalone ACK
    emission and verifying that ACK-only segments do not consume the TX
    sequence number.
  - Extended `tests/protocols/rssi/test_RssiTxFsm.py` to cover SYN header
    emission, one-word DATA header/payload emission, DATA retransmit without
    sequence reallocation, ACK window release, NULL sequence consumption, and
    RST sequence consumption without buffering.
  - Fixed the `RssiTxFsmWrapper` application-side `TKEEP` wiring and promoted
    the one-word DATA `TKEEP` check into the default TX FSM regression.
  - Added default `RssiTxFsm` coverage for oversized application frame
    `lenErr_o` behavior and ACK/NULL/DATA one-shot checksum fault injection.
  - Updated `RssiTxFsm` checksum fault injection so ACK and NULL paths honor the
    documented one-shot injection behavior, and so injection corrupts the
    checksum field rather than inverting the whole header word.
  - Added an opt-in `RssiTxFsm` known-issue regression for multi-word DATA
    payload buffering and resend ordering.
  - Added `protocols/rssi/v1/wrappers/RssiMonitorWrapper.vhd` with flattened
    RSSI parameter and flag records.
  - Added `tests/protocols/rssi/test_RssiMonitor.py` covering received BUSY
    suppression of retransmission timeout progress and server null-timeout
    behavior under ACK/BUSY-only traffic.
  - Updated `RssiMonitor` server null-timeout accounting so only DATA or NULL
    receipt refreshes server liveness; standalone ACK/BUSY traffic no longer
    prevents the server null timeout.
  - Extended `tests/protocols/rssi/test_RssiMonitor.py` to cover local busy
    rising-edge ACK requests and periodic local-busy ACK requests.
  - Updated `RssiMonitor` ACK timeout counting so steady local BUSY can request
    periodic ACKs after each transmitted busy ACK, even when there is no newly
    pending cumulative ACK.
  - Extended `tests/protocols/rssi/test_RssiRxFsm.py` to cover valid SYN
    parameter capture, illegal SYN+EACK/BUSY/RST/NULL flag combinations, and
    SYN frames with extra payload.
  - Updated `RssiRxFsm` SYN handling so invalid SYN frames do not refresh the
    visible peer parameters and so a valid SYN must end cleanly at the expected
    parameter word.
  - Added `RssiRxFsm` coverage for the SURF RSSI hardware profile's
    out-of-order DATA behavior: an out-of-order DATA segment is dropped without
    application output, and the missing in-order retransmit is accepted.
  - Extended `RssiRxFsm` illegal DATA coverage to DATA+EACK and updated the RTL
    to drop unsupported non-SYN EACK segments explicitly.

## Notes
- Primary local spec source is now
  `references/confluence/reliable-slac-streaming-protocol-rssi.html`.
- Rogue `.rst` docs have been copied under `references/rogue/`.
- RFC 908, RFC 1151, and the RUDP Internet-Draft have been copied under
  `references/rfc/`.
- The requested `RSSI Discussions` Confluence page was attempted through the
  pretty URL, `viewpage.action`, and REST API. The available responses redirect
  to SLAC SSO or show rate limiting, so the actual discussion page content is
  not locally available yet.
- RFC/RUDP references remain background for spec-compliance intent; the concrete
  RTL target is the SLAC/SURF/Rogue RSSI profile.
- The plan now expects SURF RTL out-of-order DATA to be dropped and recovered by
  retransmission. Rogue software's out-of-order queue is noted as a software
  behavior, not a hardware test requirement.
- High-priority regression hypotheses include DATA without ACK, DATA+BUSY,
  runtime parameter range validation, RST non-retransmission, and checksum
  fault-injection scope. Server null-timeout reset on ACK/BUSY is now covered
  by `test_RssiMonitor.py` and fixed in `RssiMonitor`.
- First implementation target is now the module-level header/checksum slice:
  `rssi_test_utils.py`, `test_RssiChksum.py`, and `test_RssiHeaderReg.py`.
- `RssiHeaderReg` busy handling is tested by keeping `busyHeadSt_i` asserted as
  local status while selecting ACK/DATA/NULL/RST headers. Clearing that signal
  during header selection would not match how `RssiCore` connects local busy.
- The `RssiRxFsmWrapper` segment RAM model now uses a synchronous read path to
  match the core RAM latency closely enough for wrapper-level payload ordering
  checks.
- The first `RssiTxFsm` regression intentionally waits for
  `chksumStrobe_o` before driving `chksumValid_i`. Driving checksum-valid from
  reset can let the FSM sample the header path before `RssiHeaderReg` has
  produced the selected ACK header word, which hides the behavior under test.
- The default DATA transmit test now checks `TDATA`, `TKEEP`, `TLAST`, `SOF`,
  `EOFE`, sequence consumption, retransmit sequence reuse, and ACK window
  release. The original non-0/1 `TKEEP` symptom came from wrapper-level
  double-driving of the lower keep bits.
- The `RssiTxFsm` and `RssiRxFsm` regressions now include the live RTL files in
  `extra_vhdl_sources` with `force_compile=True` so they do not accidentally
  validate stale imported sources under `build/SRC_VHDL`.
- Before the TX wrapper RAM timing fix, the opt-in TX multi-word DATA
  known-issue test emitted payload words 2, 3, and 3 for a three-word
  application frame instead of words 1, 2, and 3. That first looked like
  `RssiTxFsm` application-side buffer write alignment, but later validation
  showed it was caused by the wrapper's combinational read model.
- The multi-word DATA issue was resolved as a `RssiTxFsmWrapper` memory-model
  mismatch, not a production `RssiTxFsm` bug. `RssiCore` uses registered-read
  RAMs for the TX segment buffer; the wrapper had modeled the read side
  combinationally. The wrapper now uses a registered read path, and the
  multi-word DATA/resend test is default coverage.
- `RssiMonitor` still treats received BUSY as a retransmission-timer reset, as
  required by the flow-control behavior. The server null-timeout fix is scoped
  only to liveness detection, where the spec describes DATA/NULL receipt as the
  keepalive condition.
- Periodic local-busy ACK generation remains tied to the cumulative ACK timeout
  path, matching the existing SURF/Rogue behavior. The RSSI page recommends a
  Retransmission Timeout/2 period, so this is now documented as a cadence
  difference rather than left uncharacterized.
- `RssiRxFsm` SYN parameter updates are now staged until the full SYN header is
  accepted. This prevents a malformed multi-word SYN from changing
  `rxParam_o` before the late checksum/length/frame-boundary decision drops the
  frame.

## Validation
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/rssi_test_utils.py tests/protocols/rssi/test_RssiChksum.py tests/protocols/rssi/test_RssiHeaderReg.py`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiChksum.py tests/protocols/rssi/test_RssiHeaderReg.py`
  passed.
- 2026-05-22:
  `./.venv/bin/vsg --configuration vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiHeaderRegWrapper.vhd`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/rssi_test_utils.py tests/protocols/rssi/test_RssiChksum.py tests/protocols/rssi/test_RssiHeaderReg.py tests/protocols/rssi/test_RssiRxFsm.py`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiTxFsm.py`
  passed after expanding TX FSM coverage.
- 2026-05-22:
  `./.venv/bin/vsg --configuration vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd`
  passed after expanding TX FSM coverage.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  passed with default known-issue tests skipped.
- 2026-05-22:
  `/usr/bin/env RUN_RSSI_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  failed only in `one_word_data_tkeep_known_issue_test`, confirming DATA
  `TKEEP` contains non-0/1 values on a valid transfer.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py`
  passed after adding the opt-in RX payload-delivery characterization.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed with default known-issue tests skipped.
- 2026-05-22:
  `./.venv/bin/vsg --configuration vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiRxFsmWrapper.vhd`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed.
- 2026-05-22:
  `./.venv/bin/vsg --configuration vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiHeaderRegWrapper.vhd protocols/rssi/v1/wrappers/RssiRxFsmWrapper.vhd`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py`
  passed after refactoring the RX test onto the shared SSI helpers.
- 2026-05-22:
  `./.venv/bin/vsg --configuration vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiRxFsmWrapper.vhd`
  passed after renaming the flattened SSI wrapper ports.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed.
- 2026-05-22:
  `make MODULES=/Users/bareese/surf import` did not run because this checkout
  does not currently have `ruckus/system_ghdl.mk`.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiTxFsm.py`
  passed.
- 2026-05-22:
  `./.venv/bin/vsg --configuration vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed.
- 2026-05-22:
  `/usr/bin/env RUN_RSSI_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  passed after the TX DATA `TKEEP` fix.
- 2026-05-22:
  `/usr/bin/env RUN_RSSI_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed after the RX payload-delivery and illegal-DATA-flag fixes.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/common/regression_utils.py tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiRxFsm.py`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  passed with the resolved known-issue case promoted into the default TX FSM
  suite.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed with the resolved known-issue cases promoted into the default RX FSM
  suite.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiTxFsm.vhd protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd protocols/rssi/v1/wrappers/RssiRxFsmWrapper.vhd`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with four RSSI pytest wrappers.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiTxFsm.py`
  passed after adding TX length-error, checksum fault-injection, and opt-in
  multi-word DATA coverage.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiTxFsm.vhd`
  passed after the checksum fault-injection RTL update.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  passed with the multi-word DATA known-issue test skipped by default.
- 2026-05-22:
  `/usr/bin/env RUN_RSSI_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  failed only in `multi_word_data_preserves_payload_keep_and_resend_known_issue_test`,
  confirming the current DATA buffer emits payload words 2, 3, and 3 instead of
  1, 2, and 3 for a three-word frame.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  passed after matching the TX wrapper segment RAM read timing to `RssiCore`
  and promoting multi-word DATA/resend coverage into the default suite.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed after the TX wrapper RAM timing update.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd`
  passed after the TX wrapper RAM timing update.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiMonitor.py`
  passed after adding monitor coverage.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiMonitor.py`
  passed after the server null-timeout RTL update.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiMonitor.vhd protocols/rssi/v1/wrappers/RssiMonitorWrapper.vhd`
  passed after the monitor update.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with five RSSI pytest wrappers after adding `RssiMonitor` coverage.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiMonitor.py`
  passed after adding local-busy ACK coverage.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiMonitor.vhd protocols/rssi/v1/wrappers/RssiMonitorWrapper.vhd`
  passed after the local-busy ACK counter update.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiMonitor.py`
  passed after the local-busy ACK counter update.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with five RSSI pytest wrappers after the local-busy ACK counter
  update.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py`
  passed after adding RX SYN legality coverage.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd`
  passed after the RX SYN filtering update.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed after the RX SYN filtering update.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with five RSSI pytest wrappers after the RX SYN filtering update.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py`
  passed after adding RX out-of-order DATA characterization.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed after adding RX out-of-order DATA characterization.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with five RSSI pytest wrappers after adding RX out-of-order DATA
  characterization.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py`
  passed after adding DATA+EACK drop coverage.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd`
  passed after the non-SYN EACK drop update.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed after the non-SYN EACK drop update.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with five RSSI pytest wrappers after the non-SYN EACK drop update.

## Open Items
- Re-run `make MODULES="$PWD" import` after the local ruckus support files are
  restored or initialized.
- Confirm whether any EACK behavior is implemented enough to test or should
  remain explicitly out of scope.
- Decide whether the local-busy ACK cadence should remain tied to cumulative
  ACK timeout or be changed to the RSSI page's recommended Retransmission
  Timeout/2 period.
- Continue triaging the remaining `rtl-spec-review.md` findings into default
  coverage, expected-fail characterization, or immediate RTL fixes.
