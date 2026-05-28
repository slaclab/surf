# RSSI Regression Plan

## Objective
- Add focused cocotb regressions for the SURF RSSI RTL under
  `protocols/rssi/v1/`.
- Verify the RSSI/RUDP protocol contract, not only the behavior inferred from
  the current RTL.
- Keep executable stimulus and scoreboards in Python.
- Keep VHDL additions limited to thin cocotb-facing wrappers beside the RSSI
  RTL when existing record ports or integration topology make that necessary.

## Task Tracking
- Keep `progress.md` as the detailed chronological work log.
- Keep `handoff.md` current as the concise resume point for the next
  contributor. Update it whenever the active next step, validation status,
  known issues, or remaining attention areas change.
- Keep `rtl-changes.md` as a current-state summary of actual implemented
  production RTL changes under `protocols/rssi/v1/rtl/`, not as a chronological
  log. Update or replace entries as the RTL changes evolve. Track wrapper,
  testbench, test-model, and documentation changes in `progress.md` and
  `handoff.md` instead, unless a wrapper change deliberately changes the
  intended DUT contract.
- Before pausing substantial work on this task, check that `handoff.md` agrees
  with the latest validated state in `progress.md` and `rtl-changes.md`.

## Specification Sources
- Local reference bundle:
  `docs/plans/rssi-regression/references/README.md` is the index. Use this
  bundle first for protocol references so future work does not depend on
  network access or the current location of `~/rogue`.
- Primary SLAC RSSI protocol page:
  `references/confluence/reliable-slac-streaming-protocol-rssi.html`, with
  diagrams and the Word export under `references/confluence/attachments/`.
  This page defines the concrete RSSI header format, parameter negotiation,
  connection flow, data flow, retransmission, NULL segment, BUSY flow-control,
  and differences from RUDP.
- RSSI Discussions Confluence page:
  `references/confluence/rssi-discussions.html` and
  `references/confluence/rssi-discussions-viewpage.html` record retrieval
  attempts for the requested page. Both redirect to SLAC SSO from this
  environment, so the actual discussion content is not available locally yet.
- Rogue RSSI docs copied into `references/rogue/`:
  `built_in_protocols_rssi_index.rst` describes RSSI as the reliable, ordered,
  negotiated stream layer between UDP and upper protocols.
- Rogue network wrapper docs copied into `references/rogue/`:
  `built_in_protocols_network.rst` documents the deployed
  UDP/RSSI/packetizer stack and the `udp.maxPayload() - 8` segment-size
  convention.
- Rogue RSSI API/source docs:
  local `.rst` copies are under `references/rogue/`; source files remain useful
  when implementation detail is needed:
  `/Users/bareese/rogue/include/rogue/protocols/rssi/Header.h`,
  `/Users/bareese/rogue/src/rogue/protocols/rssi/Header.cpp`, and
  `/Users/bareese/rogue/include/rogue/protocols/rssi/Controller.h` provide the
  software-side header codec, negotiated fields, state machine roles, counters,
  and runtime controls.
- SURF RTL protocol comments:
  `protocols/rssi/v1/rtl/RssiCore.vhd`,
  `protocols/rssi/v1/rtl/RssiPkg.vhd`,
  `protocols/rssi/v1/rtl/RssiHeaderReg.vhd`,
  `protocols/rssi/v1/rtl/RssiRxFsm.vhd`,
  `protocols/rssi/v1/rtl/RssiTxFsm.vhd`,
  `protocols/rssi/v1/rtl/RssiMonitor.vhd`, and
  `protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd`.
- RFC/RUDP background for normative behavior:
  local copies are in `references/rfc/`:
  `rfc908.txt`, `rfc1151.txt`, and
  `draft-ietf-sigtran-reliable-udp-00.txt`. Treat these as the lineage and
  behavior model, while the SLAC/SURF/Rogue RSSI profile defines the concrete
  implemented subset.

## Protocol Understanding
- RSSI is a SLAC reliable streaming layer based on the RDP/RUDP lineage. It
  provides connection management, parameter negotiation, ordered delivery,
  acknowledgments, retransmission, keepalive NULL segments, and flow control
  over an unreliable lower layer such as UDP.
- The implemented SURF/Rogue profile uses an 8-byte non-SYN header and a
  24-byte SYN header. The fixed header carries flags, header length, sequence,
  acknowledgment, and checksum. SYN additionally carries version, checksum
  capability, maximum outstanding segments, maximum segment size, retransmit
  timeout, cumulative-ACK timeout, NULL timeout, maximum retransmissions,
  maximum cumulative ACK count, timeout unit, and connection ID.
- Active open is client-driven. The client sends SYN, the server replies with
  SYN+ACK, and the client sends ACK before both sides operate as open links.
- Sequence numbers are 8-bit in the RSSI profile. SYN, DATA, NULL, and RST
  consume sequence numbers; standalone ACK does not.
- DATA and NULL normally include ACK information. NULL is a keepalive segment
  and must not deliver application payload.
- Received DATA/NULL frames must be delivered in order. For the SLAC RSSI page
  and the SURF RTL profile, out-of-order DATA is dropped and recovered by
  retransmission; no EACK/out-of-sequence acknowledgment behavior is expected.
  Rogue software has an out-of-order queue, but the RTL regression should not
  require that software-private behavior unless the hardware profile changes.
- The ACK mechanism cumulatively frees transmitted segments up through the
  acknowledged sequence number. Retransmission should resend unacknowledged
  DATA/NULL segments after the negotiated retransmit timeout, stopping at the
  negotiated maximum retransmission count. RST retransmission is a review item
  because current RTL intentionally does not buffer RST.
- The busy flag is RSSI flow control. A remote busy indication should at least
  reset retransmission timing; whether the current RTL also suppresses new data
  requires explicit characterization.
- EACK and transfer-connection-state behavior exist in the RUDP lineage, but
  the SURF RTL comments and Rogue header API show they are not part of the
  current primary profile. Tests should document this as intentionally deferred
  rather than silently implying EACK compliance.
- Pre-implementation RTL/spec review lives in `rtl-spec-review.md`. Treat its
  findings as targeted regression hypotheses before making RTL behavior changes.

## Pre-Implementation Decisions
These decisions set the first regression expectations so the tests do not
encode ambiguous behavior accidentally.

| Area | First Test Expectation |
| --- | --- |
| DATA without ACK | Invalid; drop it and do not deliver application payload. |
| DATA+BUSY | Invalid; drop it and do not deliver application payload. |
| SYN+NUL | Invalid; drop it or fail connection establishment. |
| SYN with payload | Invalid; do not open the connection or deliver application payload. |
| Out-of-order DATA | Drop it and recover only after retransmission. |
| Server null timeout reset by ACK/BUSY | Spec-shaped expectation is timeout; ACK/BUSY-only traffic should not keep the server alive unless this is deliberately reclassified as a hardware-profile deviation. |
| RST retransmission | Characterize current RTL first because `RssiTxFsm` intentionally does not buffer RST. Do not treat a missing RST resend as a bug until the spec decision is explicit. |
| Checksum fault injection scope | Test the register-comment contract first: ACK, NULL, and DATA should be injectable. A DATA-only result should drive either an RTL fix or documentation correction. |
| BUSY data suppression | Characterize current RTL separately from the minimum spec requirement that received BUSY resets retransmission timing. |

Failures in clear spec cases should become candidate RTL bugs. Failures in
characterization cases should be recorded first, then converted into either
spec-shaped tests or current-contract tests after review.

## First Implementation Slice
Start with the smallest module-level tests that establish a trustworthy Python
protocol oracle before exercising the larger FSMs.

1. Create `tests/protocols/rssi/rssi_test_utils.py`.
   Include RSSI flag constants, header builder/parser helpers, SYN parameter
   packing/unpacking, one's-complement checksum calculation, and frame builders
   for ACK, DATA, NULL, RST, and SYN.
2. Add `tests/protocols/rssi/test_RssiChksum.py`.
   Cover known checksum vectors, multi-word SYN checksum, validation/check
   mode, reset, enable, and strobe timing.
3. Add `tests/protocols/rssi/test_RssiHeaderReg.py`.
   Cover ACK/DATA/NULL/RST/SYN field packing, ACK bit behavior, BUSY bit
   propagation, header lengths, sequence/ack numbers, and SYN parameter
   packing.

Only after this slice passes should the work move to `RssiRxFsm`,
`RssiTxFsm`, `RssiConnFsm`, and `RssiMonitor`.

## Wrapper Strategy
Use direct cocotb DUT access where scalar/vector ports are enough. Add thin
checked-in wrappers under `protocols/rssi/v1/wrappers/` only when record ports,
RAM-style side ports, or multi-core integration would otherwise make the Python
test unclear.

When a wrapper exposes SSI or AXI Stream traffic to cocotb, use the existing
flat test port convention before inventing RSSI-specific signal names:
`axisClk`/`axisRst`, `sAxis*` for source-side input traffic, and `mAxis*` for
sink-side output traffic. This lets RSSI tests reuse the shared SSI stream
drivers and scoreboards directly.

| Module | Expected Strategy |
| --- | --- |
| `RssiChksum` | Direct cocotb DUT. Ports are scalar/vector only. |
| `RssiHeaderReg` | Try direct cocotb first; add a wrapper only if `RssiParamType` record access is awkward under GHDL/cocotb. |
| `RssiConnFsm` | Likely thin wrapper to flatten `RssiParamType` and `FlagsType`. |
| `RssiMonitor` | Likely thin wrapper to flatten `FlagsType` and expose status/timer outputs clearly. |
| `RssiRxFsm` | Wrapper likely needed for SSI records, checksum handshake, and buffer RAM ports. |
| `RssiTxFsm` | Wrapper likely needed for SSI records, RAM ports, and header/checksum handshake. |
| `RssiAxiLiteRegItf` | Wrapper likely useful to flatten AXI-Lite and RSSI parameter records. |
| `RssiCore` | Integration wrapper with one client and one server connected transport-to-transport. |
| `RssiCoreWrapper` | Wrapper/integration smoke only after `RssiCore` behavior is stable. |

## Parent Methodology
- Follow `docs/plans/rtl-regression/plan.md` and `tests/README.md`.
- New Python regression files need the standard SURF header, a module-specific
  `Test methodology` block, and in-body comments explaining major cocotb
  steps.
- RSSI regression comments should explain the reason for each non-obvious
  stimulus or timing choice: protocol byte order, checksum field treatment,
  registered control capture, `TPD_G` settle timing, wrapper-flattened record
  ports, and any current RTL behavior being pinned for later review.
- Checked-in VHDL wrappers need the standard SURF banner and short section
  comments for bus shims, DUT hookup, and flattened/status wiring.
- Validate edited VHDL with `./.venv/bin/vsg -c vsg-linter.yml ...`.
- Validate Python syntax with the repo virtualenv interpreter.
- After pytest/cocotb/GHDL runs, sweep for stale simulator processes.

## Helper And Reuse Directives
- Create `tests/protocols/rssi/rssi_test_utils.py` for shared RSSI helpers.
- Before adding a new RSSI-local cocotb helper, check the existing protocol and
  common test modules for a matching abstraction. Prefer reuse over parallel
  hand-written source/sink, AXI-Lite, or timing helpers.
- Reuse existing SSI helpers from `tests/protocols/ssi/ssi_test_utils.py` for
  SOF/EOF/EOFE-aware stream transaction handling. RSSI wrappers that expose
  SSI-facing ports should use the shared `axisClk`/`axisRst`, `sAxis*`, and
  `mAxis*` names so `setup_flat_ssi_testbench`, `SsiBeat`,
  `send_contiguous_frame`, `recv_frame`, and quiet-output helpers are usable
  without adapters.
- Reuse AXI-Lite helpers from `tests/axi/utils.py` where they fit the RSSI
  register tests, including sampled ready/valid timing helpers for any
  AXI-style side channels.
- Reuse `tests/common/regression_utils.py` for runner integration, environment
  parsing, parameter sweeps, and shared clock/reset utilities where applicable.
- Keep header byte construction and checksum calculation in shared helpers so
  every test uses one protocol oracle.
- Keep policy assertions visible in the tests. Helpers may build frames,
  compute checksums, and drive handshakes, but tests should state which RSSI
  rule they are proving.

## Module Inventory
| Module | Role | Planned Coverage |
| --- | --- | --- |
| `RssiHeaderReg` | Encodes RSSI headers from FSM/request fields | Direct header-format regression |
| `RssiChksum` | Computes/checks RSSI/RUDP header checksum | Direct checksum regression |
| `RssiRxFsm` | Decodes transport frames, validates headers, buffers/delivers ordered payload | Directed receive-path regression |
| `RssiTxFsm` | Accepts application frames, emits RSSI segments, tracks ACK/retransmit window | Directed transmit-path regression |
| `RssiMonitor` | ACK, NULL, retransmit, busy, status, and counters | Focused timeout/status regression |
| `RssiConnFsm` | Client/server open, parameter negotiation, retries, and close | Directed connection-state regression |
| `RssiParamSync` | Multi-field RSSI parameter CDC | Covered by AXI-Lite/Core CDC tests unless a defect requires direct coverage |
| `RssiAxiLiteRegItf` | Register map and parameter/status synchronization | Register-map regression |
| `RssiCore` | Integrated client/server RSSI endpoint | Main protocol-compliance integration regression |
| `RssiCoreWrapper` | RSSI plus packetizer/chunker wrapper | Thin wrapper/integration smoke after `RssiCore` coverage |

## Phase 1: Header And Checksum Contract
Target `RssiHeaderReg` and `RssiChksum` first.

Planned checks:
- Non-SYN header layout for ACK, DATA, NULL, and RST: flags, busy bit, header
  length, sequence number, acknowledgment number, reserved bytes, and checksum
  placeholder.
- SYN header layout across all three 64-bit words: flags, version,
  checksum-enable bit, maximum outstanding segments, maximum segment size,
  retransmit timeout, cumulative-ACK timeout, NULL timeout, retransmit/ACK
  counters, timeout unit, and connection ID.
- Header lengths: 8-byte non-SYN headers and 24-byte SYN headers in the SURF
  RSSI profile.
- Checksum reference model aligned with the Rogue `Header::compSum()` behavior
  and the RFC 1151/RUDP use of a 16-bit one's-complement checksum.
- Invalid checksum detection and checksum-disabled behavior where the RTL
  exposes the control path.

Acceptance for Phase 1:
- Shared Python RSSI header builder/parser exists.
- Header and checksum tests can be run independently from the full core.
- Any deliberate divergence from RFC/RUDP format is documented in
  `progress.md`.

## Phase 2: Receive And Transmit FSMs
Target `RssiRxFsm` and `RssiTxFsm` through thin wrappers if direct driving of
record ports and internal buffer ports is too cumbersome.

Planned receive checks:
- Valid DATA in sequence is accepted, buffered, and delivered to the
  application side with payload and SSI sidebands preserved.
- NULL is accepted and acknowledged but does not deliver application payload.
- Duplicate, out-of-order, invalid checksum, malformed header, illegal flag
  combination, and out-of-window sequence cases increment/drop without
  corrupting later traffic.
- DATA with ACK clear and DATA combined with BUSY are treated as illegal unless
  a spec review decision explicitly narrows the hardware contract.
- SYN parsing captures negotiated parameters and connection ID.

Planned transmit checks:
- Application frames are segmented according to the active maximum segment
  size, carry the ACK bit, and consume sequence numbers.
- Standalone ACK emits without consuming a sequence number.
- SYN, DATA, NULL, and RST sequence-number consumption matches the RSSI profile.
- ACK processing frees transmitted window entries cumulatively.
- Retransmit path resends unacknowledged frames without allocating new sequence
  numbers.
- Remote busy resets retransmit accounting as specified; tests should also
  characterize whether current RTL suppresses new data or only prevents
  retransmit timeout progress.
- RST transmission behavior is captured explicitly because current RTL sends RST
  without buffering it for retransmission.

Additional connection-FSM checks:
- Client active-open and server passive-open state progress can be verified
  without a full `RssiCore` topology.
- Version, checksum-enable, and timeout-unit mismatches reject or reset as the
  spec requires.
- Peer max outstanding and max segment size are accepted/clamped to local
  capacity.
- Retry timeout and maximum retry behavior are deterministic with small test
  generics.

Acceptance for Phase 2:
- Leaf FSM behavior is covered without relying on a full client/server
  topology for every edge case.
- Tests explicitly distinguish protocol requirements from RTL implementation
  details such as internal state names.

## Phase 3: Integrated Client/Server Protocol
Target `RssiCore` with a cocotb-facing integration wrapper that instantiates one
client and one server, or two independently configurable cores connected at the
transport side.

Planned checks:
- Client active-open handshake: SYN, SYN+ACK, final ACK, and connection-active
  status.
- Negotiated parameter readback for max outstanding segments, max segment size,
  retransmit timeout, cumulative-ACK timeout, NULL timeout, maximum
  retransmissions, and maximum cumulative ACK count.
- Bidirectional payload delivery through the application side with in-order
  delivery under transport duplication and loss injection. Reordered DATA
  should be dropped and recovered through retransmission for the SURF RTL
  profile.
- Cumulative ACK timing/count behavior: delayed ACK under light traffic and
  immediate ACK when `maxCumAck` is reached.
- NULL keepalive behavior: client emits NULL after idle timeout and server
  treats missing NULL/DATA as link failure.
- Retransmission: dropped DATA segment is retransmitted, delivered once, and
  reflected in retransmit counters.
- Link failure/reset behavior: maximum retransmissions or explicit RST closes
  the connection and updates status/counters.
- Busy flow control: local busy sets the busy flag, peer records remote busy,
  and retransmit timing is held off without losing already-queued frames. New
  data suppression should be characterized against the RTL/spec decision.

Acceptance for Phase 3:
- Main user-visible reliable-stream behavior is tested at the `RssiCore`
  boundary.
- Transport perturbations are deterministic and bounded so failures are
  debuggable.
- Focused validation passes for the RSSI test slice.

## Phase 4: AXI-Lite And Wrapper Coverage
Target `RssiAxiLiteRegItf` and then `RssiCoreWrapper`.

Planned AXI-Lite checks:
- Control register reset/readback for open, close, mode, header checksum enable,
  and one-shot checksum fault injection.
- Local parameter writes and negotiated/current readback fields at documented
  offsets.
- `maxSegSize` clamping to the legal 8-byte minimum and buffer-size maximum.
- Status/counter readback for connection active, busy flags, valid/drop/resend/
  reconnect counters, state readbacks, and sequence/ack readbacks.
- Unaligned or unmapped accesses return the documented AXI-Lite error response.

Planned wrapper checks:
- `RssiCoreWrapper` preserves the core RSSI behavior while adding packetizer or
  chunker integration.
- Cover bypass-chunker and packetizer path only after `RssiCore` is stable.

Acceptance for Phase 4:
- Register-visible behavior is synchronized with
  `python/surf/protocols/rssi/_RssiCore.py`.
- Wrapper tests do not replay the full core matrix unless a wrapper-specific
  branch requires it.

## Final Coverage Expansion
The closeout expansion adds the remaining integration-depth checks without
changing production RSSI RTL.

Implemented direct-core checks:
- Handshake loss/retry for client SYN, server SYN+ACK, and client final ACK.
- DATA loss and retransmission in both directions, ACK/NULL perturbation,
  sequence-number wraparound, and multi-frame bidirectional payload stress.
- Focused status/error assertions for max retransmit close/RST, peer BUSY,
  missing keepalive close, and invalid/control-only traffic that should not
  refresh server liveness or duplicate application delivery.

Implemented wrapper checks:
- `RssiCoreWrapper` application-output backpressure advertises BUSY through the
  client-visible status path.
- `RssiCoreWrapperMultiStream` packetizer2 routing now covers bidirectional
  payload delivery for two application streams and has a dedicated small
  window/segment-size pytest entry for focused validation.

Closeout notes:
- The checksum-disabled RX finding is covered as valid current-contract
  behavior: checksum validation is bypassed when `HEADER_CHKSUM_EN_G=false`,
  but the checksum block still supplies the timing pulse.
- A stricter two-consecutive-client-DATA-loss experiment did not become default
  coverage because it exposes a new hardware-contract question. Current
  default coverage proves one recovered DATA loss per direction in a single
  connection.
- The ruckus import check is still environment-blocked if
  `ruckus/system_ghdl.mk` is absent from the checkout.

## Out Of Scope
- Exhaustive generic Cartesian sweeps.
- Full software Rogue interoperability in the first RTL regression pass.
- EACK/TCS compliance unless current RTL support is identified and scoped.
- Congestion control, which the RUDP draft explicitly does not provide.
- Vendor or mixed-language simulator dependencies.
- Rewriting RSSI RTL public interfaces or PyRogue APIs.

## Validation Commands
Planned focused commands:

```bash
./.venv/bin/vsg -c vsg-linter.yml protocols/rssi/v1/wrappers/*.vhd
PYTHONPYCACHEPREFIX=/private/tmp/surf-pycache ./.venv/bin/python -m py_compile tests/protocols/rssi/*.py
./.venv/bin/python -m pytest -n 0 -q tests/protocols/rssi
git diff --check
```

Run `make MODULES="$PWD" import` after adding wrappers or changing ruckus
structure.

## Risks
- The RTL and Rogue software do not expose identical internals. Use Rogue as a
  protocol oracle for header bytes and negotiated control semantics, not as a
  mandate to mirror its private queue implementation.
- RSSI uses 8-bit sequence numbers. Tests must include at least one wrap-aware
  case before claiming sequence-window coverage.
- Timeouts can be slow if default generics are used. Use test-specific small
  timeout generics while keeping ordering relationships valid.
- Out-of-order and retransmission tests can become nondeterministic if the
  transport perturbation layer is not single-threaded and cycle-bounded.
- `RssiCoreWrapper` brings in packetizer/chunker behavior. Keep wrapper
  assertions narrow so RSSI failures do not get hidden behind packetizer
  expectations.

## Done Criteria
- The RSSI task docs identify what is covered, what is intentionally deferred,
  and how to resume.
- Focused RSSI regressions pass locally.
- New wrappers and tests follow the RTL regression style rules.
- Spec-derived assertions are traceable to the Rogue docs, SURF RTL comments,
  or RFC/RUDP background.
- `docs/plans/rssi-regression/progress.md` and
  `docs/plans/rssi-regression/handoff.md` are updated after validated RSSI work
  changes the task state.
