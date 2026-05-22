# RSSI Regression Handoff

## Goal
Add focused cocotb regressions for `protocols/rssi/v1/` that verify RSSI/RUDP
protocol compliance for the SURF/Rogue RSSI profile.

## Resume Point
Read `progress.md`, `rtl-changes.md`, `plan.md`, `rtl-spec-review.md`, and
`references/README.md` first. Phase 1 is complete and Phase 2 leaf-FSM coverage
is in progress.

The immediate technical resume point is the `RssiTxFsm` multi-word DATA
buffering known issue. The opt-in regression
`multi_word_data_preserves_payload_keep_and_resend_known_issue_test` currently
fails when `RUN_RSSI_KNOWN_ISSUE_TESTS=1`: for a three-word application frame,
the TX path emits payload words 2, 3, and 3 instead of words 1, 2, and 3. The
failure points at application-side buffer write alignment for multi-beat DATA
frames.

## Key References
- SURF plan: `docs/plans/rssi-regression/plan.md`
- Local reference bundle: `docs/plans/rssi-regression/references/`
- RTL/spec review: `docs/plans/rssi-regression/rtl-spec-review.md`
- Primary SLAC RSSI protocol page:
  `docs/plans/rssi-regression/references/confluence/reliable-slac-streaming-protocol-rssi.html`
- Local RFC/RUDP references: `docs/plans/rssi-regression/references/rfc/`
- Local Rogue docs: `docs/plans/rssi-regression/references/rogue/`
- Regression style: `docs/plans/rtl-regression/plan.md`, `tests/README.md`
- Rogue header codec:
  `/Users/bareese/rogue/src/rogue/protocols/rssi/Header.cpp`
- SURF RSSI RTL:
  `protocols/rssi/v1/rtl/`
- Current RSSI cocotb tests:
  `tests/protocols/rssi/`

## Validation
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on
  2026-05-22 with the multi-word DATA known-issue test skipped by default.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiTxFsm.vhd protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd protocols/rssi/v1/wrappers/RssiRxFsmWrapper.vhd`
  passed on 2026-05-22.
- `/usr/bin/env RUN_RSSI_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  failed only in the multi-word DATA known-issue regression on 2026-05-22.
- `make MODULES="$PWD" import` has not been re-run successfully because this
  checkout is currently missing `ruckus/system_ghdl.mk`.

## Current Attention Areas
- SURF RTL should be tested for out-of-order drop/retransmission recovery, not
  Rogue software out-of-order queue behavior.
- Default RSSI coverage is green for `RssiChksum`, `RssiHeaderReg`,
  `RssiRxFsm`, and `RssiTxFsm`.
- Production RTL changes made so far are documented in `rtl-changes.md`:
  `RssiRxFsm` illegal DATA flag filtering and `RssiTxFsm` checksum fault
  injection scope.
- Fix or explicitly reclassify the `RssiTxFsm` multi-word DATA buffering issue.
- Extend `RssiTxFsm`/`RssiMonitor` coverage to remote busy behavior.
- Confirm whether EACK behavior is implemented enough to test or should remain
  explicitly out of scope.
- Decide which remaining `rtl-spec-review.md` findings should become
  expected-fail tests versus immediate RTL fixes.
