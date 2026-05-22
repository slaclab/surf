# RSSI Regression Handoff

## Goal
Add focused cocotb regressions for `protocols/rssi/v1/` that verify RSSI/RUDP
protocol compliance for the SURF/Rogue RSSI profile.

## Resume Point
Read `plan.md`, `rtl-spec-review.md`, and `references/README.md` first. The
next step is the Phase 1 module-level header/checksum slice:
`tests/protocols/rssi/rssi_test_utils.py`,
`tests/protocols/rssi/test_RssiChksum.py`, and
`tests/protocols/rssi/test_RssiHeaderReg.py`.

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

## Validation
No RSSI tests have been run yet. This task has only created docs/reference
artifacts and a pre-implementation RTL/spec review.

## Current Attention Areas
- SURF RTL should be tested for out-of-order drop/retransmission recovery, not
  Rogue software out-of-order queue behavior.
- Likely high-value tests: illegal DATA flags, SYN flag combinations, server
  null timeout with ACK/BUSY-only traffic, parameter range/clamp behavior, RST
  retransmission policy, and AXI-Lite checksum fault-injection scope.
- Use direct cocotb DUT access for `RssiChksum`, try direct access first for
  `RssiHeaderReg`, and add thin wrappers for later record-heavy FSM/core tests
  only when they make the Python stimulus clearer.
