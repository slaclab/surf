# RSSI Regression Handoff

## Goal
Add focused cocotb regressions for `protocols/rssi/v1/` that verify RSSI/RUDP
protocol compliance for the SURF/Rogue RSSI profile.

## Resume Point
Read `progress.md`, `rtl-changes.md`, `plan.md`, `rtl-spec-review.md`, and
`references/README.md` first. Phase 1 and Phase 2 are complete. Phase 3
`RssiCore` integrated client/server coverage is in place for connection,
payload, retransmission, keepalive, missing-keepalive close, and explicit
close behavior. Phase 4 has started with narrow `RssiCoreWrapper` smoke
coverage.

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
of mismatched server parameters. It also covers server/client SYN retry followed
by peer-timeout close behavior; the RTL timeout counter now saturates at the
retry threshold so simulation does not overflow the constrained counter range
while waiting to retransmit or close. `RssiAxiLiteRegItf` now has register
boundary coverage for reset defaults, writable parameter readback,
max-segment-size clamping, negotiated/status/counter/state/sequence readback,
and AXI-Lite `DECERR` propagation through the test wrapper.
Phase 3 `RssiCore` integration coverage has started. The new
`RssiCoreIntegrationWrapper` instantiates a client and server `RssiCore` with
directly connected transport streams and passive transport monitor outputs.
Default `test_RssiCore.py` coverage now checks active-open connection status,
negotiated max-segment-size readback, bidirectional application payload
delivery with transport monitor checks, idle client NULL keepalive preserving
the server connection, missing client keepalives closing the server with the
null-timeout status bit set, explicit client close, and dropped/corrupted
client DATA frames recovering through retransmission with the same sequence
number and payload.
The latest Phase 3 RTL fixes are in `RssiRxFsm`: DATA EOF segment length now
uses the incremented next segment address, app output waits one registered RAM
read cycle before using the first payload word, and duplicate DATA is dropped
before entering the payload-buffering state. Phase 4 now adds
`RssiCoreWrapperIntegrationWrapper`, which instantiates one client and one
server `RssiCoreWrapper` with one flattened application stream each and direct
RSSI transport connection. `test_RssiCoreWrapper.py` verifies active-open
connection and bidirectional application payload delivery in both
bypass-chunker and legacy packetizer/depacketizer modes.

The next technical work should extend integrated coverage for reorder/drop,
additional retransmission/counter visibility, or busy behavior. Keep the
local-busy cadence decision against the RSSI page's Retransmission Timeout/2
recommendation and EACK scope as explicit review items. Also triage the
additional zero-valued server application frame observed during a longer
post-retransmission collection window; it may belong to integrated NULL
keepalive or output-FIFO reset/release behavior and is not yet a default
failure. A first integrated busy-flow attempt using stalled server application
output produced ordinary ACK/RST/reconnect traffic without a BUSY ACK, so
integrated BUSY coverage still needs a focused stimulus or RTL decision.

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
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiConnFsm.py`
  passed on 2026-05-22 after adding `RssiConnFsm` retry/timeout coverage.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiConnFsm.vhd`
  passed on 2026-05-22 after the retry timeout counter saturation update.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiConnFsm.py`
  passed on 2026-05-22 with server and client retry/timeout sweeps.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on
  2026-05-22 with seven RSSI pytest wrappers/parameter sweeps after the
  `RssiConnFsm` retry timeout update.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiAxiLiteRegItf.py`
  passed on 2026-05-22 after adding AXI-Lite register-interface coverage.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiAxiLiteRegItfWrapper.vhd`
  passed on 2026-05-22 after adding the AXI-Lite wrapper.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiAxiLiteRegItf.py`
  passed on 2026-05-22.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on
  2026-05-22 with eight RSSI pytest wrappers/parameter sweeps after adding
  `RssiAxiLiteRegItf` coverage.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py`
  passed on 2026-05-22 after adding final Phase 2 RX control/header-drop
  coverage.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed on 2026-05-22 after adding final Phase 2 RX control/header-drop
  coverage.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on
  2026-05-22 with eight RSSI pytest wrappers/parameter sweeps after closing
  Phase 2.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-22 after adding initial Phase 3 `RssiCore` coverage.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd`
  passed on 2026-05-22.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-22 with default Phase 3 coverage.
- `env RUN_RSSI_CORE_PAYLOAD_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  failed on 2026-05-22 only in the opt-in integrated bidirectional payload
  characterization, where zero-valued server application output beats replaced
  the expected client payload.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on
  2026-05-22 with nine RSSI pytest wrappers/parameter sweeps after adding the
  default `RssiCore` integration slice.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/rtl/RssiTxFsm.vhd`
  passed on 2026-05-23 after the Phase 3 RX payload-delivery fixes and after
  backing out a non-working TX partial fix.
- `make MODULES=/Users/bareese import` passed on 2026-05-23 after the Phase 3
  RTL/wrapper changes. `make MODULES="$PWD" import` is not the right invocation
  for this checkout because `system_ghdl.mk` is resolved relative to
  `/Users/bareese`.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-23 after the Phase 3 core test updates.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-23.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on
  2026-05-23 with nine RSSI pytest wrappers/parameter sweeps.
- `env RUN_RSSI_CORE_PAYLOAD_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed twice on 2026-05-23 after the Phase 3 RX payload-delivery fixes.
- `env RUN_RSSI_CORE_PAYLOAD_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed on 2026-05-23 with nine RSSI pytest wrappers/parameter sweeps.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on
  2026-05-23 after promoting bidirectional `RssiCore` DATA payload delivery
  into default coverage.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd`
  passed on 2026-05-23 after the final Phase 3 payload promotion.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-23 after adding integrated DATA loss/retransmission
  coverage.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd`
  passed on 2026-05-23 after adding wrapper one-shot transport drop controls
  and the RX duplicate-DATA filter.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-23 after adding integrated retransmission coverage.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on
  2026-05-23 with nine RSSI pytest wrappers/parameter sweeps after adding the
  integrated DATA loss/retransmission slice.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-23 after adding integrated missing-client-keepalive close
  coverage.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-23 after adding integrated missing-client-keepalive close
  coverage.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on 2026-05-23
  with nine RSSI pytest wrappers/parameter sweeps after adding integrated
  missing-client-keepalive close coverage.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapper.py`
  passed on 2026-05-26 after adding `RssiCoreWrapper` smoke coverage.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiCoreWrapperIntegrationWrapper.vhd`
  passed on 2026-05-26 after adding the `RssiCoreWrapper` integration wrapper.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py`
  passed on 2026-05-26 with bypass-chunker and packetizer parameter cases.
- `make MODULES=/Users/bareese import` passed on 2026-05-26 after adding the
  `RssiCoreWrapper` integration wrapper.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on 2026-05-26
  with eleven RSSI pytest wrappers/parameter sweeps after adding
  `RssiCoreWrapper` bypass-chunker and packetizer smoke coverage.

## Current Attention Areas
- SURF RTL out-of-order drop/retransmission recovery is now covered at the
  `RssiRxFsm` level; do not add tests that require Rogue software's
  out-of-order queue behavior.
- Default RSSI coverage is green for `RssiChksum`, `RssiHeaderReg`,
  `RssiRxFsm`, `RssiTxFsm`, `RssiMonitor`, `RssiConnFsm`,
  `RssiAxiLiteRegItf`, the current `RssiCore`
  connection/payload/retransmission/keepalive/missing-keepalive/close slice,
  and narrow `RssiCoreWrapper` bypass/packetizer smoke coverage.
- The next implementation slice should extend integrated coverage with
  perturbations such as corruption, reorder/drop, additional
  retransmission/counter visibility, or busy behavior.
- Production RTL changes made so far are documented in `rtl-changes.md`:
  `RssiRxFsm` illegal DATA/EACK flag filtering and SYN filtering/parameter
  staging, integrated DATA payload timing, and duplicate DATA payload
  filtering; `RssiTxFsm` checksum fault injection scope; `RssiMonitor` server
  null-timeout liveness handling; and `RssiConnFsm` retry timeout counter
  saturation.
- Triage the extra zero-valued server application frame observed during a
  longer post-retransmission collection window before deciding whether it is a
  bug, a wrapper/output-FIFO artifact, or a test setup issue.
- Decide whether the local-busy ACK cadence should remain tied to cumulative
  ACK timeout or be changed to the RSSI page's recommended Retransmission
  Timeout/2 period.
- Keep EACK-specific behavior out of scope except for explicit rejection;
  SURF/Rogue RSSI does not implement EACK/out-of-sequence acknowledgment
  handling.
- Decide which remaining `rtl-spec-review.md` findings should become
  expected-fail tests versus immediate RTL fixes.
