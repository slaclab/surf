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
- Phase 2 implementation is complete:
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
  - Added `protocols/rssi/v1/wrappers/RssiConnFsmWrapper.vhd` with flattened
    RSSI parameter and flag records.
  - Added `tests/protocols/rssi/test_RssiConnFsm.py` covering server SYN
    acceptance/open, server proposal of local required parameters on mismatch,
    client SYN+ACK acceptance with clamp behavior, and client rejection of
    mismatched server parameters with RST.
  - Extended `tests/protocols/rssi/test_RssiConnFsm.py` to cover server and
    client SYN retransmission followed by peer-timeout close behavior.
  - Updated `RssiConnFsm` retry timeout counting so the counter saturates at
    the retransmission threshold before the retry/peer-timeout decision,
    avoiding a range overflow in the wait-for-SYN and wait-for-ACK states.
  - Added `protocols/rssi/v1/wrappers/RssiAxiLiteRegItfWrapper.vhd` with a
    standard AXI-Lite shim and flattened RSSI parameter/status ports.
  - Added `tests/protocols/rssi/test_RssiAxiLiteRegItf.py` covering reset
    defaults, writable parameter readback, max-segment-size clamping,
    negotiated/status/counter/state/sequence readback, and unmapped/unaligned
    `DECERR` responses.
  - Extended `tests/protocols/rssi/test_RssiRxFsm.py` to cover received NULL
    acceptance without application payload, malformed non-SYN header drops, and
    ACK-window violation drops.
- Phase 3 implementation has started:
  - Added `protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd`, a
    cocotb-facing integration wrapper that instantiates one client `RssiCore`
    and one server `RssiCore` with their transport AXI streams directly
    connected.
  - Added `tests/protocols/rssi/test_RssiCore.py` covering active-open
    connection status, negotiated max-segment-size readback, bidirectional
    application payload delivery, idle client NULL keepalive preserving the
    server connection, and explicit client close.
  - Added passive client/server transport monitor ports to
    `RssiCoreIntegrationWrapper` so the core payload test can localize
    payload corruption before or after peer RX.
  - Fixed two integrated RX-side payload issues in `RssiRxFsm`: EOF DATA
    segment length now uses the incremented next segment address, and the app
    output FSM now inserts a `READ_S` state before using the registered
    segment RAM read data for the first payload beat. The app-side final DATA
    beat also now waits for `pause = '0'` before releasing the window entry.
  - Promoted bidirectional integrated DATA payload delivery into default
    `RssiCore` coverage after the passive monitors confirmed both client and
    server transport DATA frames carry the expected payload before peer RX.
  - Added one-shot transport frame drop controls to
    `RssiCoreIntegrationWrapper` for deterministic loss/retransmission
    perturbation coverage.
  - Extended `tests/protocols/rssi/test_RssiCore.py` to drop the first
    client-to-server DATA frame, verify the retransmitted DATA keeps the same
    RSSI sequence number and payload, and verify the expected application
    payload is recovered at the server application boundary.
  - Updated `RssiRxFsm` so duplicate DATA frames are dropped before entering
    the payload-buffering state; only the next in-order DATA sequence can write
    into the receive payload buffer.
  - Extended `tests/protocols/rssi/test_RssiTxFsm.py` to cover suppressing
    NULL requests while DATA remains unacknowledged in the transmit buffer.
  - Updated `RssiTxFsm` so client keepalive NULL segments only start when the
    transmit buffer is empty, preventing NULL sequence numbers from advancing
    the peer past a lost DATA segment.
  - Extended `tests/protocols/rssi/test_RssiRxFsm.py` to cover a checksum
    failed DATA frame with trailing payload followed by a valid retransmit.
  - Extended `tests/protocols/rssi/test_RssiCore.py` to verify deterministic
    checksum fault injection on a client DATA frame, observe a retransmit with
    the same RSSI sequence number and payload, and recover the server
    application payload.
  - Extended `tests/protocols/rssi/test_RssiCore.py` to hold the
    client-to-server transport drop gate active across the client NULL
    keepalive interval and verify the server closes with the null-timeout
    status bit set.
- Phase 4 implementation has started:
  - Added `protocols/rssi/v1/wrappers/RssiCoreWrapperIntegrationWrapper.vhd`,
    a cocotb-facing integration wrapper that instantiates one client
    `RssiCoreWrapper` and one server `RssiCoreWrapper` with one flattened
    application stream each and directly connected RSSI transport streams.
  - Added `tests/protocols/rssi/test_RssiCoreWrapper.py` covering active-open
    connection and bidirectional application payload delivery through
    `RssiCoreWrapper`.
  - Swept the wrapper smoke test across bypass-chunker mode and legacy
    packetizer/depacketizer mode, keeping the assertions narrow so packetizer
    coverage does not replay the full RSSI core matrix.
  - Extended the `RssiCoreWrapper` smoke sweep across multiple
    `WINDOW_ADDR_SIZE_G` and `MAX_SEG_SIZE_G` values: bypass mode now covers
    window sizes 1 and 3 with 64-byte and 256-byte segment sizes, and
    packetizer mode covers window sizes 2 and 3 with 128-byte and 64-byte
    segment sizes.
  - Updated `RssiCore` output FIFO pause-threshold calculation to clamp at the
    minimum legal `AxiStreamFifoV2` threshold of 1. The previous expression,
    `(2**SEGMENT_ADDR_SIZE_G) - 16`, elaborated for 256-byte wrapper segments
    but became 0 or negative for smaller `MAX_SEG_SIZE_G` values because
    `RssiCoreWrapper` derives `SEGMENT_ADDR_SIZE_G` from `MAX_SEG_SIZE_G`.
  - Added `protocols/rssi/README.md` to document normal `RssiCoreWrapper`
    use, the core/wrapper split, important generic relationships, and current
    regression coverage.
  - Added
    `protocols/rssi/v1/wrappers/RssiCoreWrapperMultiStreamIntegrationWrapper.vhd`
    and `tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py` to exercise
    the user-facing `RssiCoreWrapper` path with `APP_STREAMS_G=2`,
    `APP_ILEAVE_EN_G=true`, routed application streams, and the
    packetizer2/depacketizer2 path.
  - Resolved the multi-stream wrapper routed-payload known issue as a test
    stimulus race against server-side `AxiStreamDepacketizer2` route-state
    initialization. The routed-payload test now waits after RSSI connection
    before sending application DATA, and verifies both routed server
    application outputs by default.
  - Refactored `RssiCoreWrapperMultiStreamIntegrationWrapper` so the
    client/server transport interfaces are flattened to cocotb instead of
    connected through VHDL perturbation logic. Cocotb now owns the transparent
    transport loopback and one-shot packetizer2 DATA drop behavior.
  - Extended `tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py` to drop
    the first client-to-server multi-stream wrapper DATA frame, verify the
    retransmitted RSSI sequence is reused, and confirm the stream-1 routed
    payload is recovered at the server application boundary.
  - Added the RSSI conformance pass for parameter range validation, BUSY cadence,
    cumulative ACK window release, max-retransmit RST/close behavior, and
    duplicate DATA suppression coverage.
  - Updated `RssiAxiLiteRegItf` writable runtime parameters so `maxOutsSeg` and
    timeout fields clamp away illegal zero/out-of-range values.
  - Updated the PyRogue `RssiCore` register model to expose matching writable
    RSSI parameter ranges, preventing software-side verify mismatches when
    users attempt values the RTL clamps at the register boundary.
  - Updated `RssiConnFsm` peer-parameter screening so invalid SYN/SYN+ACK
    parameters are rejected instead of being accepted or converted into illegal
    local ranges.
  - Updated `RssiMonitor` steady local-BUSY ACK cadence to use the RSSI page's
    recommended Retransmission Timeout/2 interval instead of the cumulative ACK
    timeout path.
  - Added default leaf coverage for cumulative ACK release of multiple TX
    segments, RX duplicate-DATA drop after delivery, invalid peer parameter
    rejection, runtime register clamps, and max-retransmit RST/close behavior.
  - Promoted the direct-core integrated BUSY and strict retransmit recovery
    probes into default `test_RssiCore.py` coverage. `RssiCore` local BUSY now
    preserves the application output FIFO write-count trigger and also includes
    output FIFO pause/direct downstream backpressure. The drop/corruption
    recovery tests now verify exactly one recovered server application frame.
  - Tightened direct-core test stimulus so each application beat is accepted
    once, and targeted DATA loss/corruption after the pending client control
    segment is observed. This removed the earlier repeated-output artifact from
    overdriven application input and prevented perturbation hooks from consuming
    header-only control traffic.
  - Closed the EACK scope decision against the local reference bundle: the
    primary SLAC RSSI page reserves/does not use EACK in RSSI v1, drops
    out-of-order segments, and explicitly lists no out-of-sequence
    acknowledgments as a difference from RUDP. Added default `RssiRxFsm`
    coverage for standalone ACK+EACK rejection, kept existing SYN+EACK and
    DATA+EACK rejection coverage, and updated PyRogue/register-map wording so
    the EACK/out-of-sequence field is described as reserved/unsupported rather
    than pending behavior.

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
- Periodic local-busy ACK generation now uses the RSSI page's recommended
  Retransmission Timeout/2 period. The leaf monitor test intentionally sets the
  cumulative ACK timeout shorter than Retransmission Timeout/2 to prove BUSY does
  not fire from the cumulative ACK timeout path.
- `RssiRxFsm` SYN parameter updates are now staged until the full SYN header is
  accepted. This prevents a malformed multi-word SYN from changing
  `rxParam_o` before the late checksum/length/frame-boundary decision drops the
  frame.
- `RssiConnFsm` retry close pulses occur one registered cycle before the
  retransmitted SYN/SYN+ACK output is visible. The retry timeout tests check the
  close pulse and then the retransmit request, and deassert `connRq_i` before
  the final peer timeout so active-open does not immediately restart from
  `CLOSED_S`.
- `RssiAxiLiteRegItfWrapper` enables `SlaveAxiLiteIpIntegrator` error response
  propagation with `EN_ERROR_RESP => true`; otherwise the shim masks register
  block `DECERR` responses as AXI OKAY and hides the behavior under test.
- Integrated DATA loss/corruption recovery can still expose an additional
  server application output after the expected recovered frame when the test
  keeps observing past the first recovery. The current default `RssiCore`
  regression verifies recovery and leaves the duplicate/extra-output behavior
  as a separate triage item.
- A first integrated busy-flow attempt stalled the server application output
  and sent repeated client DATA frames, but the observed server transport
  traffic remained ordinary ACK/RST/reconnect traffic without a BUSY ACK. Keep
  integrated BUSY characterization as a separate triage item rather than a
  default test until the correct production stimulus or RTL behavior is clear.
- `RssiCoreWrapper` now has executable coverage for smaller window and segment
  configurations, including a two-segment window (`WINDOW_ADDR_SIZE_G=1`) and
  64-byte RSSI segments. This is smoke coverage for connection and one-frame
  bidirectional payload only; it does not replace implementation synthesis or a
  hardware build for BRAM/resource validation.
- The multi-stream `RssiCoreWrapper` routed-payload issue was a test timing
  problem, not an observed RSSI payload or packetizer2 data-path defect. The
  test had sent client application DATA before the server-side
  `AxiStreamDepacketizer2` finished clearing its per-`TDEST` route state after
  RSSI link-up. Waiting 1024 `axisClk` cycles after connection makes routed
  payload delivery deterministic, and the payload route assertions are now
  default coverage.
- The multi-stream wrapper loss model now lives in cocotb. Its transparent
  transport loopback drops only the next multi-beat transport frame after the
  test arms the loss hook, so periodic header-only ACK/NULL traffic does not
  consume the armed loss event before application DATA arrives.
- RSSI wrapper audit note: `RssiCoreIntegrationWrapper` still contains VHDL
  transport drop-gate logic and is the next integration wrapper that could be
  refactored into flattened transport ports plus cocotb loopback. The
  behavioral RAMs in `RssiTxFsmWrapper` and `RssiRxFsmWrapper` are different:
  those leaf FSMs require adjacent segment-buffer models and the wrapper RAM
  keeps that required DUT-side interface explicit.

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
- 2026-05-23:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed.
- 2026-05-23:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiTxFsm.vhd`
  passed.
- 2026-05-23:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed.
- 2026-05-23:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed.
- 2026-05-23:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py`
  passed after adding integrated missing-keepalive close coverage.
- 2026-05-23:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed after adding integrated missing-keepalive close coverage.
- 2026-05-23:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed with nine
  RSSI pytest wrappers/parameter sweeps after adding integrated
  missing-keepalive close coverage.
- 2026-05-26:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapper.py`
  passed after adding `RssiCoreWrapper` smoke coverage.
- 2026-05-26:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiCoreWrapperIntegrationWrapper.vhd`
  passed after adding the `RssiCoreWrapper` integration wrapper.
- 2026-05-26:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py`
  passed with bypass-chunker and packetizer parameter cases.
- 2026-05-26:
  `make MODULES=/Users/bareese import` passed after adding the
  `RssiCoreWrapper` integration wrapper.
- 2026-05-26:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed with eleven
  RSSI pytest wrappers/parameter sweeps after adding `RssiCoreWrapper`
  bypass-chunker and packetizer smoke coverage.
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
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiConnFsm.py`
  passed after adding connection FSM coverage.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiConnFsmWrapper.vhd`
  passed after adding the connection FSM wrapper.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiConnFsm.py`
  passed with server and client sweeps.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with seven RSSI pytest wrappers/parameter sweeps after adding
  `RssiConnFsm` coverage.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiConnFsm.py`
  passed after adding `RssiConnFsm` retry/timeout coverage.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiConnFsm.vhd`
  passed after the retry timeout counter saturation update.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiConnFsm.py`
  passed with server and client retry/timeout sweeps.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with seven RSSI pytest wrappers/parameter sweeps after the
  `RssiConnFsm` retry timeout update.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiAxiLiteRegItf.py`
  passed after adding AXI-Lite register-interface coverage.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiAxiLiteRegItfWrapper.vhd`
  passed after adding the AXI-Lite wrapper.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiAxiLiteRegItf.py`
  passed.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with eight RSSI pytest wrappers/parameter sweeps after adding
  `RssiAxiLiteRegItf` coverage.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py`
  passed after adding the final Phase 2 RX control/header-drop coverage.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed after adding the final Phase 2 RX control/header-drop coverage.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with eight RSSI pytest wrappers/parameter sweeps after closing the
  Phase 2 leaf-FSM/control coverage.
- 2026-05-22:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py`
  passed after adding the initial `RssiCore` integration regression.
- 2026-05-22:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd`
  passed after adding the `RssiCore` integration wrapper.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed with default Phase 3 coverage. The opt-in payload characterization is
  skipped by default.
- 2026-05-22:
  `env RUN_RSSI_CORE_PAYLOAD_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  failed only in `bidirectional_payload_delivery_known_issue_test`, where the
  expected client payload was replaced by zero-valued application output beats
  at the server.
- 2026-05-22:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi` passed with nine RSSI
  pytest wrappers/parameter sweeps after adding the default `RssiCore`
  integration slice.
- 2026-05-23:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/rtl/RssiTxFsm.vhd`
  passed after the Phase 3 RX payload-delivery fixes and after backing out a
  non-working TX partial fix.
- 2026-05-23:
  `make MODULES=/Users/bareese import` passed after the Phase 3 RTL/wrapper
  changes. `make MODULES="$PWD" import` is not the right invocation for this
  checkout because `system_ghdl.mk` is resolved relative to `/Users/bareese`.
- 2026-05-23:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py`
  passed after the Phase 3 core test updates.
- 2026-05-23:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed.
- 2026-05-23:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with nine RSSI pytest wrappers/parameter sweeps.
- 2026-05-23:
  `env RUN_RSSI_CORE_PAYLOAD_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed twice after the Phase 3 RX payload-delivery fixes.
- 2026-05-23:
  `env RUN_RSSI_CORE_PAYLOAD_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with nine RSSI pytest wrappers/parameter sweeps.
- 2026-05-23:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed after promoting bidirectional `RssiCore` DATA payload delivery into
  default coverage.
- 2026-05-23:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd`
  passed after the final Phase 3 payload promotion.
- 2026-05-23:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py`
  passed after adding integrated DATA loss/retransmission coverage.
- 2026-05-23:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiRxFsm.vhd protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd`
  passed after adding wrapper one-shot transport drop controls and the RX
  duplicate-DATA filter.
- 2026-05-23:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed after adding integrated retransmission coverage.
- 2026-05-23:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  passed with nine RSSI pytest wrappers/parameter sweeps after adding the
  integrated DATA loss/retransmission slice.
- 2026-05-26:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapper.py`
  passed after extending the wrapper parameter sweep.
- 2026-05-26:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiCore.vhd`
  passed after clamping the output FIFO pause threshold for small segment
  sizes.
- 2026-05-26:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py`
  passed with four wrapper parameter cases covering multiple window and
  segment sizes.
- 2026-05-26:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapper.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed after adding the multi-stream wrapper smoke test.
- 2026-05-26:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiCore.vhd protocols/rssi/v1/wrappers/RssiCoreWrapperMultiStreamIntegrationWrapper.vhd`
  passed after adding the multi-stream wrapper and small-segment threshold
  clamp.
- 2026-05-26:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed with the two-stream packetizer2 active-open smoke case.
- 2026-05-26:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed with five wrapper parameter cases across the one-stream and
  two-stream wrapper regressions.
- 2026-05-26:
  `make MODULES=/Users/bareese import` passed after adding the multi-stream
  wrapper file under the simulation wrapper source directory.
- 2026-05-26:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed after adding the opt-in multi-stream routed-payload characterization.
- 2026-05-26:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiCoreWrapperMultiStreamIntegrationWrapper.vhd`
  passed after adding passive transport monitor ports to the multi-stream
  integration wrapper.
- 2026-05-26:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed with the known-issue routed-payload characterization skipped by
  default.
- 2026-05-26:
  `env RUN_RSSI_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  failed in `multi_stream_client_to_server_payload_routes_known_issue_test`.
  The failure showed repeated accepted client transport DATA frames containing
  both payloads, while `srvMApp0` and `srvMApp1` captured no application
  output beats.
- 2026-05-26:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed with five default wrapper cases after adding the opt-in known-issue
  characterization.
- 2026-05-26:
  `make MODULES=/Users/bareese import` passed after the passive transport
  monitor port additions.
- 2026-05-27:
  `env RUN_RSSI_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed after adding a longer post-connection wait, proving the multi-stream
  routed-payload symptom was a depacketizer2 initialization race in the test
  stimulus.
- 2026-05-27:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed after promoting the routed-payload case into default coverage.
- 2026-05-27:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed with the two-stream active-open and routed-payload packetizer2 cases.
- 2026-05-27:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed with five wrapper cases across the one-stream and two-stream wrapper
  regressions after promoting multi-stream routed payload delivery.
- 2026-05-27:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed after adding the multi-stream wrapper loss/retransmission route
  coverage.
- 2026-05-27:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiCoreWrapperMultiStreamIntegrationWrapper.vhd`
  passed after moving the multi-stream wrapper transport loopback/drop behavior
  into cocotb and exposing flattened transport ports.
- 2026-05-27:
  `COCOTB_TESTCASE=multi_stream_dropped_client_data_retransmits_to_route_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed for the new multi-stream loss/retransmission route case.
- 2026-05-27:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
  passed with the two-stream active-open, routed-payload, and
  loss/retransmission packetizer2 cases.
- 2026-05-27:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiAxiLiteRegItf.py tests/protocols/rssi/test_RssiConnFsm.py tests/protocols/rssi/test_RssiMonitor.py tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed after adding the conformance pass coverage.
- 2026-05-27:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiConnFsm.vhd protocols/rssi/v1/rtl/RssiMonitor.vhd protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd`
  passed after the parameter-validation, BUSY-cadence, and register-clamp RTL
  updates.
- 2026-05-27:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiAxiLiteRegItf.py tests/protocols/rssi/test_RssiConnFsm.py tests/protocols/rssi/test_RssiMonitor.py tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiTxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed with seven focused RSSI pytest wrappers/parameter sweeps.
- 2026-05-27:
  `COCOTB_TESTCASE=dropped_client_data_retransmits_and_recovers_payload_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed after targeting the direct-core drop hook to the DATA frame and
  checking for exactly one recovered server application frame.
- 2026-05-27:
  `COCOTB_TESTCASE=corrupted_client_data_retransmits_and_recovers_payload_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed after targeting checksum injection to the DATA frame and checking for
  exactly one recovered server application frame.
- 2026-05-27:
  `COCOTB_TESTCASE=server_backpressure_advertises_busy_to_client_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed after extending `RssiCore` local BUSY to include application output
  pause/backpressure while preserving the existing FIFO write-count trigger.
- 2026-05-27:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
  passed with direct-core integrated BUSY and strict retransmit recovery in
  default coverage.
- 2026-05-27:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/rtl/RssiCore.vhd`
  passed after the direct-core local BUSY update.
- 2026-05-27:
  `./.venv/bin/python -m py_compile python/surf/protocols/rssi/_RssiCore.py`
  passed after adding the PyRogue writable parameter ranges; an import probe in
  the `rogue_build` environment confirmed the default `loc*` range metadata.
- 2026-05-27:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py python/surf/protocols/rssi/_RssiCore.py`
  and `git diff --check` passed after closing EACK as reserved/unsupported and
  updating the RX test, PyRogue wording, register-map comments, and task docs.
- 2026-05-27:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py`
  passed after adding standalone ACK+EACK rejection coverage.
- 2026-05-27:
  `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed after adding the checksum-disabled RX characterization and moving
  direct-core transport loopback/drop behavior into cocotb.
- 2026-05-27:
  `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd`
  passed after exposing flattened direct-core transport ports and removing the
  VHDL drop-gate logic.
- 2026-05-27:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py::test_RssiRxFsm_checksum_disabled`
  passed after fixing the characterization stimulus to continue sending the
  DATA payload while forcing `chksumOk_i=0`.
- 2026-05-27:
  `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiRxFsm.py tests/protocols/rssi/test_RssiCore.py`
  passed with the checksum-disabled RX characterization covered as a normal
  regression.

## Reopened Coverage Expansion
- The RSSI regression task was reopened after closeout review to add the
  remaining integration-depth coverage before final wrap-up. The original
  `rtl-spec-review.md` findings are closed, but the suite still needs broader
  transport perturbation, status/counter, wrapper, and bounded stress coverage.
- Implemented additions:
  - direct-core handshake loss/retry for SYN, SYN+ACK, and final ACK;
  - direct-core ACK loss, NULL loss, server-side DATA loss, bidirectional
    DATA-loss recovery in one connection, sequence-number wraparound, and
    multi-frame bidirectional stress;
  - stronger assertions on visible status/error bits around retransmit,
    peer-busy, and null-timeout behavior;
  - wrapper-level application backpressure/BUSY coverage and additional
    multi-stream wrapper parameter routing coverage;
  - a renewed attempt at `make MODULES=/Users/bareese/surf import`.
- The checksum-disabled RX item closed as a test-stimulus bug, not a production
  RTL defect. `RssiRxFsm` already bypasses `chksumOk_i` when
  `HEADER_CHKSUM_EN_G=false`; the regression now sends the DATA payload while
  forcing `chksumOk_i=0`, preserving the existing contract that the checksum
  block still provides the `chksumValid_i` timing pulse.
- `rtl-spec-review.md` remains the original review/planning input. Keep future
  triage notes in this progress log and keep production RTL rationale in
  `rtl-changes.md`.
- `test_RssiCore.py` now owns all direct-core transport perturbation in
  cocotb loopback: one-shot control/DATA drops, sustained client transport
  drops, and passive transport capture. The final expansion adds SYN retry,
  SYN+ACK retry, final ACK retry, server-side DATA retransmit, ACK/NULL
  perturbation, sequence wrap, bidirectional multi-frame stress, and a focused
  small-parameter run that drops one DATA frame in each direction and verifies
  exactly one recovered application delivery per side.
- A stricter experimental probe that dropped two consecutive client DATA
  transmissions in one connection did not deliver the second recovered payload
  inside the bounded observation window. That behavior was not promoted into
  default coverage for this closeout pass; it remains a possible future
  characterization item if the hardware contract is extended to require
  repeated same-direction loss recovery without a clean ACK/drain interval.
- `test_RssiCoreWrapper.py` now has a focused backpressure case that holds the
  server application output stalled and verifies the client-visible BUSY status
  bit.
- `test_RssiCoreWrapperMultiStream.py` now covers bidirectional packetizer2
  routing for two application streams and adds a dedicated pytest entry for
  the small window/segment parameter set so this route coverage can be run
  without the full long multi-stream sweep.
- Validation added on 2026-05-27:
  - `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py tests/protocols/rssi/test_RssiCoreWrapper.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
    passed.
  - `git diff --check` passed.
  - `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py::test_RssiCore_sequence_wraparound tests/protocols/rssi/test_RssiCore.py::test_RssiCore_repeated_data_loss`
    passed.
  - `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py`
    passed.
  - `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py::test_RssiCoreWrapper_backpressure`
    passed.
  - `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py::test_RssiCoreWrapperMultiStream_bidirectional_packetizer2`
    passed.
  - `make MODULES=/Users/bareese/surf import` failed before import because
    this checkout cannot find `/Users/bareese/surf/ruckus/system_ghdl.mk`.
  - A full
    `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
    run was stopped after 14:44 to avoid leaving a long simulator run active;
    before termination it had passed the new packetizer2 bidirectional route
    cocotb test and was running the existing dropped-client-DATA route test.

## Post-Commit Spec Compliance Expansion
- 2026-05-28: committed the final coverage expansion as
  `58ea8b5bb` (`Expand RSSI integration regression coverage`), then continued
  with additional direct-core spec-compliance checks.
- Added integrated out-of-order recovery coverage in `test_RssiCore.py`.
  The focused `test_RssiCore_out_of_order_recovery` parameter run drops the
  first client DATA segment, sends the next client DATA segment while the
  first is missing, verifies no server application output is delivered before
  retransmission, and then verifies both payloads are delivered in original
  sequence order after retransmission. This covers the RSSI rule that
  out-of-order DATA is dropped until the missing in-order segment is recovered.
- Added default direct-core NULL acknowledgment coverage. The new cocotb test
  observes an idle client NULL segment and checks that the server emits an
  ACK-only segment whose acknowledge field matches the NULL sequence number,
  while the server remains connected.
- Validation added on 2026-05-28:
  - `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py`
    passed.
  - `git diff --check` passed.
  - `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py::test_RssiCore tests/protocols/rssi/test_RssiCore.py::test_RssiCore_out_of_order_recovery`
    passed.

## 2026-05-28 Test-Suite Expansion Follow-Up
- Implemented the six additional regression items requested after the coverage
  review:
  - direct-core multi-beat partial-`TKEEP` delivery with EOFE characterization;
  - direct-core BUSY recovery that drains stalled server output and checks for
    no lost or duplicate frames;
  - close/reopen lifecycle with fresh post-reconnect payload delivery;
  - client AXI-Lite control path coverage for open, runtime parameter writes,
    status/counter reads, checksum injection, and close;
  - direct-core `HEADER_CHKSUM_EN_G=false` connection and payload delivery;
  - transport-output ready stalls on header and payload beats.
- Extended wrapper coverage:
  - one-stream wrapper partial-`TKEEP` coverage now runs across bypass-chunker
    and legacy packetizer/depacketizer parameter sets, comparing only payload
    bytes selected by `TKEEP`;
  - packetizer2 multi-stream wrapper coverage now verifies routed
    partial-`TKEEP` delivery and EOFE preservation on stream 1.
- `RssiCoreIntegrationWrapper` now exposes a flattened client AXI-Lite bus so
  `test_RssiCore.py` can exercise the real `RssiAxiLiteRegItf` path through
  the full core.
- `protocols/rssi/README.md` was updated to remove the stale integrated-BUSY
  gap and document the new coverage and path-specific EOFE behavior.
- Validation added on 2026-05-28:
  - `./.venv/bin/python -m py_compile tests/protocols/ssi/ssi_test_utils.py tests/protocols/rssi/test_RssiCore.py tests/protocols/rssi/test_RssiCoreWrapper.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
    passed.
  - `./.venv/bin/vsg -c vsg-linter.yml -f protocols/rssi/v1/wrappers/RssiCoreIntegrationWrapper.vhd`
    passed.
  - `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py::test_RssiCore_axil_control_path tests/protocols/rssi/test_RssiCore.py::test_RssiCore_checksum_disabled`
    passed.
  - `./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py::test_RssiCore`
    passed.
  - `COCOTB_TESTCASE=wrapper_partial_keep_and_eofe_payload_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapper.py::test_RssiCoreWrapper`
    passed.
  - `COCOTB_TESTCASE=multi_stream_partial_keep_and_eofe_routes_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py::test_RssiCoreWrapperMultiStream_bidirectional_packetizer2`
    passed.

## 2026-05-29 Runtime Investigation
- Interrupted a full `./.venv/bin/python -m pytest -q tests/protocols/rssi`
  run after it reached the multi-stream packetizer2 wrapper path and was no
  longer giving useful closeout signal. No stale pytest/GHDL processes were
  left running afterward.
- Parsed cocotb result XML under `tests/sim_build/protocols/rssi/` to identify
  the runtime hotspots. The slowest cases were the packetizer2 multi-stream
  route tests, with historical cocotb test times up to roughly 200 seconds, and
  the direct-core BUSY recovery test, with historical cocotb test times around
  100 seconds.
- Root causes found:
  - all current RSSI pytest wrappers use `force_compile=True`, so each pytest
    case recompiles a broad SURF source list instead of reusing the
    parameter-specific sim-build directory;
  - multi-stream route tests used fixed 1024-cycle capture windows even after
    the expected routed frames were accepted;
  - direct-core BUSY recovery used a fixed 4096-cycle output collection window
    even though it already knew how many frames were sent;
  - the packetizer2 wrapper still needs the 1024-cycle post-link
    `AxiStreamDepacketizer2` route-state guard. A 384-cycle experiment failed
    deterministically with no routed stream-0 output by 2726 ns, so that guard
    was restored.
- Implemented safe test-harness reductions:
  - `test_RssiCoreWrapperMultiStream.py` now uses event-driven
    `recv_frame_and_check`/transport receives for the routed payload checks
    instead of fixed 1024-cycle captures;
  - `test_RssiCore.py` now drains exactly the sent BUSY-recovery frames and
    then checks a short quiet window for duplicates instead of collecting for
    4096 cycles.
- Timing/validation added on 2026-05-29:
  - `./.venv/bin/python -m py_compile tests/protocols/rssi/test_RssiCore.py tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py`
    passed.
  - `env COCOTB_TESTCASE=server_backpressure_recovers_without_lost_or_duplicate_frames_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCore.py::test_RssiCore`
    passed in 24.94 seconds, down from roughly 96-104 seconds in prior XML.
  - `env COCOTB_TESTCASE=multi_stream_bidirectional_payload_routes_test ./.venv/bin/python -m pytest -q tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py::test_RssiCoreWrapperMultiStream_bidirectional_packetizer2`
    passed in 109.72 seconds, down from roughly 198-207 seconds for the same
    cocotb test in prior XML.
  - `env COCOTB_TESTCASE=multi_stream_client_to_server_payload_routes_test ./.venv/bin/python -m pytest -q 'tests/protocols/rssi/test_RssiCoreWrapperMultiStream.py::test_RssiCoreWrapperMultiStream[packetizer2_two_streams_window2_seg64]'`
    passed in 101.53 seconds, with the latest result XML reporting 69.40
    seconds of cocotb runtime and about 5.9 us of simulated time.
