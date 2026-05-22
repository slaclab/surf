# RSSI Regression Progress

## Current Status
- Task plan created.
- Local reference bundle created under `references/`.
- Pre-implementation RTL/spec review created in `rtl-spec-review.md`.
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
  server null-timeout reset on ACK/BUSY, runtime parameter range validation,
  RST non-retransmission, and checksum fault-injection scope.
- First implementation target is now the module-level header/checksum slice:
  `rssi_test_utils.py`, `test_RssiChksum.py`, and `test_RssiHeaderReg.py`.
- `RssiHeaderReg` busy handling is tested by keeping `busyHeadSt_i` asserted as
  local status while selecting ACK/DATA/NULL/RST headers. Clearing that signal
  during header selection would not match how `RssiCore` connects local busy.

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
  `make MODULES=/Users/bareese/surf import` did not run because this checkout
  does not currently have `ruckus/system_ghdl.mk`.

## Open Items
- Re-run `make MODULES="$PWD" import` after the local ruckus support files are
  restored or initialized.
- Confirm whether any EACK behavior is implemented enough to test or should
  remain explicitly out of scope.
- Decide which `rtl-spec-review.md` findings should become expected-fail tests
  versus immediate RTL fixes after the first failing regressions exist.
