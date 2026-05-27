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
local BUSY requests periodic ACKs at the RSSI page's recommended
Retransmission Timeout/2 cadence. The RX SYN coverage now verifies valid SYN
parameter capture, rejects illegal
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
bypass-chunker and legacy packetizer/depacketizer modes. The wrapper smoke
sweep now covers multiple `WINDOW_ADDR_SIZE_G` and `MAX_SEG_SIZE_G` values:
bypass mode checks window sizes 1 and 3 with 64-byte and 256-byte segment
sizes, while packetizer mode checks window sizes 2 and 3 with 128-byte and
64-byte segment sizes. This exposed and fixed an elaboration failure for small
wrapper segment sizes: `RssiCore` now clamps its output FIFO pause threshold to
the minimum legal `AxiStreamFifoV2` value of 1 when
`SEGMENT_ADDR_SIZE_G` would otherwise make the old one-segment-minus-padding
threshold 0 or negative.
`protocols/rssi/README.md` now documents the normal `RssiCoreWrapper` use
case, the direct `RssiCore` use case, important generic relationships, and the
current regression coverage. A second cocotb-facing wrapper,
`RssiCoreWrapperMultiStreamIntegrationWrapper`, now covers the user-facing
wrapper path with two application streams, `APP_ILEAVE_EN_G=true`, explicit
stream routes, and the packetizer2/depacketizer2 path. The routed-payload
known issue has been resolved as a test stimulus race, not an observed RSSI or
packetizer2 payload defect. The test was sending application DATA before the
server-side `AxiStreamDepacketizer2` finished clearing its per-`TDEST` route
state after RSSI link-up. The routed-payload case now waits 1024 `axisClk`
cycles after connection and verifies both server application streams by
default. The multi-stream wrapper now also has deterministic loss coverage:
`RssiCoreWrapperMultiStreamIntegrationWrapper` exposes flattened transport
interfaces, cocotb owns the transparent transport loopback, and the default
cocotb regression drops a client-to-server packetizer2 DATA frame on stream 1,
verifies retransmission with the same RSSI sequence number, and checks that the
routed server stream 1 payload is recovered. The cocotb loss hook ignores
header-only ACK/NULL traffic by dropping only the next multi-beat transport
frame after the test arms it.

The latest conformance pass added default coverage and RTL updates for runtime
parameter validity, peer SYN/SYN+ACK range rejection, local-BUSY ACK cadence,
cumulative ACK window release, max-retransmit RST/close, and RX duplicate-DATA
drop after delivery. `RssiAxiLiteRegItf` now clamps writable `maxOutsSeg` and
timeout fields away from illegal zero/out-of-range values. `RssiConnFsm` now
rejects invalid peer parameters before converting negotiated window/buffer
sizes. `RssiMonitor` now uses Retransmission Timeout/2 for steady BUSY ACKs.
`RssiTxFsm` has a default cumulative-ACK test that frees multiple outstanding
segments, and `RssiCore` has default max-retransmit close/RST coverage.
The two direct-core conformance probes that were previously opt-in are now
default coverage. `RssiCore` local BUSY now reflects application output FIFO
write-count, pause, and direct downstream backpressure, so stalled server
application output is advertised back to the client with a BUSY ACK. The strict
direct-core drop/corruption retransmit checks now expect exactly one recovered server
application frame; the old repeated-output symptom was caused by test stimulus
holding the application source valid for multiple accepted beats and by arming
loss/corruption before pending control traffic instead of targeting DATA.

The RSSI wrapper audit found one similar remaining candidate:
`RssiCoreIntegrationWrapper` still contains VHDL transport drop-gate logic for
direct-core integration perturbations. `RssiTxFsmWrapper` and
`RssiRxFsmWrapper` also contain behavioral logic, but that is segment-buffer
RAM modeling required by those leaf-FSM interfaces rather than avoidable
traffic perturbation.

The next technical work should continue triaging the remaining
`rtl-spec-review.md` findings into default coverage, expected-fail
characterization, or narrow RTL fixes. EACK scope has been decided: EACK is
reserved/unsupported in the SURF RSSI v1 hardware profile, matching the primary
SLAC RSSI page. Tests should verify explicit rejection of received EACK flag
combinations, not EACK compliance. The local-busy cadence decision has been
made in favor of the RSSI page's Retransmission Timeout/2 recommendation, and
direct-core BUSY advertisement is now covered at the integrated `RssiCore`
level.

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
- `COCOTB_TESTCASE=dropped_client_data_retransmits_and_recovers_payload_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-27 after targeting the direct-core drop hook to DATA and
  enforcing exactly one recovered server application frame.
- `COCOTB_TESTCASE=corrupted_client_data_retransmits_and_recovers_payload_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-27 after targeting checksum injection to DATA and enforcing
  exactly one recovered server application frame.
- `COCOTB_TESTCASE=server_backpressure_advertises_busy_to_client_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-27 after extending `RssiCore` local BUSY to application
  output pause/backpressure while preserving the FIFO write-count trigger.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-27 with the direct-core BUSY and strict retransmit recovery
  probes in default coverage.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiCore.vhd`
  passed on 2026-05-27 after the direct-core local BUSY update.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed on
  2026-05-22 with five RSSI pytest wrappers.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-27 after adding multi-stream wrapper
  loss/retransmission route coverage.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiCoreWrapperMultiStreamIntegrationWrapper.vhd`
  passed on 2026-05-27 after moving multi-stream transport loopback/drop
  behavior into cocotb and exposing flattened transport ports.
- `COCOTB_TESTCASE=multi_stream_dropped_client_data_retransmits_to_route_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-27 for the new loss/retransmission route case.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-27 with the active-open, routed-payload, and
  loss/retransmission packetizer2 cases.
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
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapper.py`
  passed on 2026-05-26 after extending the `RssiCoreWrapper` parameter sweep.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiCore.vhd`
  passed on 2026-05-26 after clamping the output FIFO pause threshold for
  small segment sizes.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py`
  passed on 2026-05-26 with four wrapper parameter cases covering multiple
  window and segment sizes.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapper.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-26 after adding the multi-stream wrapper smoke test.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiCore.vhd protocols/rssi/v1/wrappers/RssiCoreWrapperMultiStreamIntegrationWrapper.vhd`
  passed on 2026-05-26 after adding the multi-stream wrapper and
  small-segment threshold clamp.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-26 with the two-stream packetizer2 active-open smoke case.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-26 with five wrapper parameter cases across the one-stream
  and two-stream wrapper regressions.
- `make MODULES=/Users/bareese import` passed on 2026-05-26 after adding the
  multi-stream wrapper file under the simulation wrapper source directory.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-26 after adding the opt-in multi-stream routed-payload
  characterization.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiCoreWrapperMultiStreamIntegrationWrapper.vhd`
  passed on 2026-05-26 after adding passive transport monitor ports to the
  multi-stream integration wrapper.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-26 with the known-issue routed-payload characterization
  skipped by default.
- `env RUN_RSSI_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  failed on 2026-05-26 in
  `multi_stream_client_to_server_payload_routes_known_issue_test`. The failure
  showed repeated accepted client transport DATA frames containing both
  payloads, while `srvMApp0` and `srvMApp1` captured no application output
  beats.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-26 with five default wrapper cases after adding the
  opt-in known-issue characterization.
- `make MODULES=/Users/bareese import` passed on 2026-05-26 after the passive
  transport monitor port additions.
- `env RUN_RSSI_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-27 after adding a longer post-connection wait, proving the
  multi-stream routed-payload symptom was a depacketizer2 initialization race
  in the test stimulus.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-27 after promoting the routed-payload case into default
  coverage.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-27 with the two-stream active-open and routed-payload
  packetizer2 cases.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed on 2026-05-27 with five wrapper cases across the one-stream and
  two-stream wrapper regressions after promoting multi-stream routed payload
  delivery.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiAxiLiteRegItf.py tests/protocols/rssi/test_RssiConnFsm.py tests/protocols/rssi/test_RssiMonitor.py tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-27 after the conformance pass coverage updates.
- `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiConnFsm.vhd protocols/rssi/v1/rtl/RssiMonitor.vhd protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd`
  passed on 2026-05-27 after the peer-parameter, BUSY-cadence, and register
  clamp RTL updates.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiAxiLiteRegItf.py tests/protocols/rssi/test_RssiConnFsm.py tests/protocols/rssi/test_RssiMonitor.py tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed on 2026-05-27 with seven focused RSSI pytest wrappers/parameter
  sweeps.
- `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py python/surf/protocols/rssi/_RssiCore.py`
  and `git diff --check` passed on 2026-05-27 after closing EACK as
  reserved/unsupported and updating the RX test, PyRogue wording, register-map
  comments, and task docs.
- `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed on 2026-05-27 after adding standalone ACK+EACK rejection coverage.

## Current Attention Areas
- SURF RTL out-of-order drop/retransmission recovery is now covered at the
  `RssiRxFsm` level; do not add tests that require Rogue software's
  out-of-order queue behavior.
- Default RSSI coverage is green for `RssiChksum`, `RssiHeaderReg`,
  `RssiRxFsm`, `RssiTxFsm`, `RssiMonitor`, `RssiConnFsm`,
  `RssiAxiLiteRegItf`, the current `RssiCore`
  connection/payload/retransmission/keepalive/missing-keepalive/close slice,
  and narrow `RssiCoreWrapper` bypass/packetizer smoke coverage with multiple
  window and segment sizes.
- The two-stream `RssiCoreWrapper` regression now proves active-open connection
  and routed client-to-server payload delivery for the packetizer2/interleave
  path. Keep the post-connection delay unless the wrapper exposes
  `AxiStreamDepacketizer2` `debug.initDone` or otherwise makes depacketizer
  route-state initialization directly observable.
- Direct-core integrated BUSY advertisement and strict no-extra-output behavior
  after drop/corruption retransmit recovery are now default `test_RssiCore.py`
  coverage.
- Production RTL changes made so far are documented in `rtl-changes.md`:
  `RssiRxFsm` illegal DATA/EACK flag filtering and SYN filtering/parameter
  staging, integrated DATA payload timing, and duplicate DATA payload
  filtering; `RssiTxFsm` checksum fault injection scope and cumulative ACK
  release; `RssiMonitor` server null-timeout liveness handling and BUSY cadence;
  `RssiConnFsm` retry timeout counter saturation and invalid peer-parameter
  rejection; `RssiAxiLiteRegItf` runtime parameter clamps; and `RssiCore`
  output FIFO pause-threshold clamping for small segment sizes and local BUSY
  advertisement from application output backpressure.
- EACK-specific behavior is closed as out of scope except for explicit
  rejection. SURF RSSI v1 does not implement EACK/out-of-sequence
  acknowledgment handling; SYN+EACK, DATA+EACK, and standalone ACK+EACK are
  default RX rejection coverage.
- Decide which remaining `rtl-spec-review.md` findings should become
  expected-fail tests versus immediate RTL fixes.
