# RSSI Regression Handoff

## Goal
Add focused cocotb regressions for `protocols/rssi/v1/` that verify RSSI/RUDP
protocol compliance for the SURF/Rogue RSSI profile.

## Resume Point
Read `progress.md`, `rtl-changes.md`, `plan.md`, `rtl-spec-review.md`, and
`references/README.md` first. Phase 1 is complete and Phase 2 leaf-FSM coverage
is in progress.

The previous `RssiTxFsm` multi-word DATA known issue has been resolved as a
test-wrapper memory-model mismatch. `RssiCore` uses registered-read RAMs for
the TX segment buffer, while `RssiTxFsmWrapper` had modeled the read side
combinationally. The wrapper now uses a registered read path, and
`multi_word_data_preserves_payload_keep_and_resend_test` is default TX coverage.
The next technical work should move on to remote busy behavior and the
remaining `rtl-spec-review.md` findings.

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
  2026-05-22 with four RSSI pytest wrappers.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiTxFsm.vhd protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd protocols/rssi/v1/wrappers/RssiRxFsmWrapper.vhd`
  passed on 2026-05-22.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  passed on 2026-05-22 after promoting the multi-word DATA/resend case into
  default coverage.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd`
  passed on 2026-05-22 after matching the wrapper RAM read timing to
  `RssiCore`.
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
- Extend `RssiTxFsm`/`RssiMonitor` coverage to remote busy behavior.
- Confirm whether EACK behavior is implemented enough to test or should remain
  explicitly out of scope.
- Decide which remaining `rtl-spec-review.md` findings should become
  expected-fail tests versus immediate RTL fixes.
