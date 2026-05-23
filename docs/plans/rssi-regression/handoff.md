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

`RssiMonitor` coverage now verifies that received BUSY suppresses
retransmission timeout progress and that ACK/BUSY-only traffic does not refresh
server liveness. The server null-timeout RTL was updated so only DATA or NULL
receipt resets the server null-timeout counter. Local-busy ACK generation is
also covered now: rising local BUSY requests an ACK immediately, and steady
local BUSY requests periodic ACKs through the cumulative ACK timeout path. The
RX SYN coverage now verifies valid SYN parameter capture, rejects illegal
SYN+EACK/BUSY/RST/NULL flag combinations, and rejects SYN frames that continue
past the expected parameter word. `RssiRxFsm` stages SYN parameters until the
whole SYN is accepted, so malformed late-drop SYN frames do not update
`rxParam_o`. RX out-of-order DATA behavior is now characterized for the SURF
hardware profile: out-of-order DATA drops without application output, and the
missing in-order retransmit is accepted. Unsupported non-SYN EACK segments now
drop explicitly through the RX header-screen path. `RssiConnFsm` now has
server/client leaf coverage for SYN acceptance, required-parameter mismatch
handling, max outstanding/segment-size clamp behavior, and client RST rejection
of mismatched server parameters.
The next technical work should continue with the local-busy cadence decision
against the RSSI page's Retransmission Timeout/2 recommendation, EACK scope, or
the remaining `rtl-spec-review.md` findings.

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
  2026-05-22 with five RSSI pytest wrappers.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiTxFsm.vhd protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd protocols/rssi/v1/wrappers/RssiRxFsmWrapper.vhd`
  passed on 2026-05-22.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py`
  passed on 2026-05-22 after promoting the multi-word DATA/resend case into
  default coverage.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiTxFsmWrapper.vhd`
  passed on 2026-05-22 after matching the wrapper RAM read timing to
  `RssiCore`.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiMonitor.py`
  passed on 2026-05-22 after adding monitor coverage and the server
  null-timeout RTL update.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiMonitor.vhd protocols/rssi/v1/wrappers/RssiMonitorWrapper.vhd`
  passed on 2026-05-22.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiMonitor.py`
  passed on 2026-05-22 after adding local-busy ACK coverage and the periodic
  busy ACK counter update.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed on 2026-05-22 after adding RX SYN legality coverage and updating SYN
  parameter staging.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd`
  passed on 2026-05-22 after the RX SYN filtering update.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed on 2026-05-22 after adding RX out-of-order DATA characterization.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed on 2026-05-22 after adding DATA+EACK drop coverage and the explicit
  non-SYN EACK drop update.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiConnFsm.py`
  passed on 2026-05-22 with server and client parameter-negotiation sweeps.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiConnFsmWrapper.vhd`
  passed on 2026-05-22.
- `make MODULES="$PWD" import` has not been re-run successfully because this
  checkout is currently missing `ruckus/system_ghdl.mk`.

## Current Attention Areas
- SURF RTL out-of-order drop/retransmission recovery is now covered at the
  `RssiRxFsm` level; do not add tests that require Rogue software's
  out-of-order queue behavior.
- Default RSSI coverage is green for `RssiChksum`, `RssiHeaderReg`,
  `RssiRxFsm`, `RssiTxFsm`, `RssiMonitor`, and `RssiConnFsm`.
- Production RTL changes made so far are documented in `rtl-changes.md`:
  `RssiRxFsm` illegal DATA/EACK flag filtering and SYN filtering/parameter
  staging, `RssiTxFsm` checksum fault injection scope, and `RssiMonitor`
  server null-timeout liveness handling.
- Decide whether the local-busy ACK cadence should remain tied to cumulative
  ACK timeout or be changed to the RSSI page's recommended Retransmission
  Timeout/2 period.
- Keep EACK-specific behavior out of scope except for explicit rejection;
  SURF/Rogue RSSI does not implement EACK/out-of-sequence acknowledgment
  handling.
- Decide which remaining `rtl-spec-review.md` findings should become
  expected-fail tests versus immediate RTL fixes.
