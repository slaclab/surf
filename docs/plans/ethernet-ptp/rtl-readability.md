# PTP RTL and interface contracts

Apply the shared [SURF VHDL conventions](../../vhdl-conventions.md), especially
[registered boundaries](../../vhdl-conventions.md#registered-boundaries-are-the-default).
The boundary ownership, justified exceptions and timing contracts below
supersede the previous immediate-control implementation. Progress and verification
remain in
[current validation](README.md#current-validation).

## Parameter and implementation contracts

At `EthMacPtpEndpoint`, GMII requires 125 MHz and XGMII requires 156.25 MHz;
set both PHY and frequency generics when selecting GMII. The composition asserts
these pairs because a wrong nominal rate also invalidates the estimator's
acquisition envelope. This restriction does not set the clocks for standalone
PHC/arithmetic tests. `PtpTxLedger` supports depths 1 through 255 so its eight-bit
occupancy and unresolved fields remain representable, including depth one.

Preserve public generic order for positional users. Calculation-only values
belong in fully assigned local variables; retained diagnostics and snapshots
remain state. Resolve synchronous reset before `rin <= v` and publication,
without changing asynchronous reset templates or adding output pipeline stages
as a style edit. The remaining reverse-ready paths resolve through `v` beside
admission and retain explicit reset/cancellation suppression. The disabled servo
still drains measurements. Registering reverse ready requires a capacity and
buffering design, not a mechanical replacement of `v` with `r`.

These rules retain the decisions from the
[completed RTL reviews](rtl-review.md#implemented-decisions); their implementation
does not lift the behavioral approval gate.

## Numeric definitions and layouts

`PtpPkg` owns shared EtherType byte orders, message lengths, profile encodings,
flags, fixed-point formats, separate nanoseconds-per-second and ppb scales,
IRQ bit names and message-specific body accessors. Preserve the distinction
between network-order EtherType and its low-byte-first stream/MAC representation,
exact accepted flag masks, and the units of each arithmetic conversion. Derive
compound shifts from the documented formats while keeping signed widening and
arithmetic widths explicit. Independent packet and measurement oracles must
remain independent of the RTL definitions.

Name values when their protocol meaning, units, policy or coupling would
otherwise be hidden. Explicit hex register offsets, commented wire positions,
ordinary byte arithmetic, zero/one tests and documented interface widths need
no additional names. The Delay_Req builder, RX header decoder and primary guard
intentionally retain explicit positions with field/range comments; shared sizes
and protocol values remain named. Delay_Req occupies 58 bytes before padding/FCS:
eight eight-byte stream beats, with only two valid bytes in the final beat.
CRC residue and physical framing symbols have local names and retain their
bit-order conventions; pause quanta derive from 512 bits divided by physical
bits per cycle.

Keep association/history depths distinct even when equal, and derive table and
median-filter bounds from their owning depth constants. Timer defaults retain
duration comments; LFSR taps retain their polynomial/bit-order explanation.
The 744-bit flattened RX width derives from the serialized fields; the PHC
mailbox has one private 209-bit pack/unpack layout and four-slot FIFOs for its
one-outstanding-request contract. AXI aperture constants also drive alignment
checks. `PtpMath`'s documented 128-step dimensions and `PtpTxTimestampTap`'s
signed-minimum check remain justified literals. Naming cleanup must preserve
values, accepted traffic, register maps, synthesis structure and handshake timing.
The [endpoint numerical envelope](autonomous-endpoint.md#port-policy-and-numerical-envelope)
records the two policy limits whose rationale remains unresolved.

## Output ownership and exceptions

Forward payload, valid, lifecycle and diagnostic outputs belong to registered
state. In addition to the detailed contracts below, `PtpPhc` registers time,
status, PPS and arithmetic requests; `PtpServo` registers command, cancellation,
expiry and status. `PtpMath` and `PtpE2e` register requests/operands and result
payload/valid; shared cancel/reset excludes a transfer at both producer and
consumer. `PtpRxTimestampAdapter` and `PtpPrimaryGuard` publish complete
registered forward records. `EthMacPtpEndpoint` and `PtpTxTimestampTap` compose
child boundaries with registered reset-completion tracking. `PtpEndpoint` is
structural, forwarding controller/core outputs and adapting TX. `PtpPkg`
defines the record contracts and has no module outputs.

The remaining exceptions are:

- `PtpRxFrontend` acknowledges its synchronous FWFT FIFO combinationally on
  the edge that captures the presented word into the registered head. This
  follows the SURF FIFO consumer pattern; delaying acknowledgement would need
  another reserved slot. FIFO writes and reset remain registered.
- Reverse ready in `PtpMath`, `PtpE2e`, `PtpPrimaryGuard`, `PtpProtocolEngine` and
  `PtpServo` expresses current capacity, simultaneous retirement or competing
  admission/cancellation. A timing break needs an additional reserved slot or
  an existing buffered SURF pipeline. This exception does not permit
  combinational forward payload, result or lifecycle outputs.
- Reset distribution and fixed polarity conversion remain combinational:
  endpoint AXI reset combines system/bus reset, mailbox reset joins its domains
  before `RstSync`, and the TX observer converts PHY-ready to active-high flush.
  The latter lets its frontend discard partial physical traffic on the same
  PHY-loss sampling edge as the adapter; published invalidation is registered.
  Adding a separate flush register would misalign those two consumers.
- Constants, fixed slices/extensions and structural forwarding preserve the
  underlying child/register ownership and need no extra stage.
- Simulation wrappers flatten/pack interfaces and inject fixture controls.
  `PtpRegWrapper` instantiates production `PtpEndpointControl`; its bank override
  and snapshot-inhibit injection remain test stimulus. It exposes actual
  configuration apply separately from delayed restart. The RX fixture combines
  its injected flush with PHY loss; these fixtures do not define a production
  timing boundary. The ledger fixture exposes registered response acceptance
  for independent timing checks.

## Interface records

`PtpPkg` owns the following directional records and initialization constants.
Units, owner and lifetime belong with each record; current timing below takes
precedence over the initial record-conversion equivalence comparison.

| Interface | Record and ownership | Contract |
| --- | --- | --- |
| Servo commands to PHC | `PtpPhcCommandMasterType`: `data`, `valid`, `cancel`, `stale`; servo produces it. | All fields are registered. Hold payload/valid through admission or withdrawal. Both cancellation bits gate admission and can revoke pending work independently of `valid`. Cancellation registered on the admission edge vetoes the following commit edge; a later sampled event cannot undo a committed command. |
| PHC command response | `PtpPhcCommandSlaveType`: `ready`, `ack`, `error`; PHC produces it. | All fields, including capacity-ready, are registered. Admission and completion are separate phases. Ownership lasts through acknowledgement, and `error` describes the acknowledged servo command. Manual command completion remains local to the PHC register bank. |
| Port lifecycle | `PtpPortLifecycleType`: `commandAbort`, `identityRestart`; port produces it. | A cause sampled at N is published after N and consumed at N+1. Command abort excludes the PHC command's own capture invalidation; identity restart enters registered endpoint flush assembly. No handshake. |
| Port diagnostics | `PtpPortStatusType`: activity/validity summaries, exchange, Announce metadata, ledger state and counters. | Registered output and local live AXI reads share the same state. Protocol-owned values update directly in the record; ratio/Announce validity and ledger observations are sampled each edge. Registered lifecycle controls are separate. Local snapshots retain their pre-edge capture contract. |
| Servo diagnostics | `PtpServoStatusType`: state, filtered delay, offset, computed rate, filter occupancy and rejection count. | The registered record owns these values; outputs and local reads use the same state. Delay/offset use signed Q16 ns; rate uses signed Q16 ppb, clamped before narrowing to its 64-bit field. The coordinator consumes only state and filter count. |
| Configuration commit | `PtpConfigControlType`: `prepare`, `apply`, `busy`; coordinator broadcasts it. | Registered from resolved next state without adding commit cycles. Preparation freezes each bank's candidate, independent scalar validation votes qualify apply, and busy inhibits conflicting manual PHC commands. System reset resets the coordinator and every bank. |
| Register snapshots | `PtpSnapshotControlType`: `capture`, `sequenceId`; coordinator broadcasts it. | Registered capture/sequence issue together. All banks sample pre-edge state on the following edge, when the coordinator also completes. An issued snapshot is not withdrawn by later invalidation. Configuration and snapshots remain separate transactions. |
| RX diagnostics | `PtpRxCountersType`: `accepted`, `dropped`, `overflow`; frontend produces it. | The registered record owns the saturating counters. Port snapshot/register offsets preserve their order. Counter semantics exclude frames lost before SOF or during flush from `dropped`. |
| PHC observation at timestamp adapter | Reuse `PtpPhcStatusType`. | Generation, increment, ticks and validity arrive as the existing PHC status record, alongside `PtpTimeType`. No new duplicate clock-status type is needed. |

The records have package initialization constants and comments covering units,
direction and lifetime. The existing measurement master/slave,
port status, time/capture and protocol payload records remain in use.

### Interfaces retained separately

- Clock/reset, AXI-Lite/AXI Stream, and GMII/XGMII interfaces retain their normal
  SURF conventions. These do not need another PTP-specific wrapper record.
- `restart`, `captureAbort`, `expireTime`, enables, IRQ, and per-bank validation
  votes remain independent controls. They have different owners or lifetimes.
  The coordinator receives explicitly named `phcConfigValid`, `portConfigValid`
  and `servoConfigValid` inputs; each leaf retains its scalar `configValid`
  output. There is no positional vote vector or dependency on AXI bank indices.
- The central register block still takes narrow status fields, rather than a
  whole diagnostic record that would blur local register ownership.
- RX messages and TX completion messages already have payload records. Their
  queue handshakes and abort signals remain explicit: RX queue
  invalidation and physical TX observation have distinct lifetime rules.
- Serialized math and ledger services retain their existing point-to-point
  payload ports. Their result-valid outputs are registered; consumers exclude
  shared cancel/restart and reset edges from transfers. Payloads and controls could form
  a later focused cleanup; they are not folded into endpoint-wide records.
- The asynchronous PHC reader keeps its explicit request/response pins and CDC
  boundary. Introducing a record would not itself make that crossing safe.

Wrappers flatten production records to their scalar Python DUT interfaces;
physical compositions forward RX counters and complete PHC status. Direct VHDL
users must adopt changed record ports; external MAC endpoint ports and software
offsets were unchanged by the record conversion. The register fixture copies
configuration-control records for explicit prepare/apply stimulus while retaining
busy. Current fixture behavior is described under output ownership above.

## Registered command and expiry interface

The servo publishes registered command payload, valid, cancel and stale. The
PHC publishes registered ready, acknowledgement and error. Ready promises the
available command slot; admission requires valid/ready and cancel/stale low.
Manual request priority is resolved before advertising that slot.

A command accepted at N commits at N+1. Cancellation registered by the servo or
port at N can veto that commit. Cancellation first detected by those producers
at N+1 reaches the PHC at N+2 and cannot undo an earlier commit. Completion and
error remain associated with the accepted owner. A held port abort cancels once,
allowing subsequent holdover control while the link remains unavailable.

SET/PHASE admission registers capture inhibition at N, before the N+1 commit.
It can conservatively inhibit captures even if the command is later rejected.
Fault/discontinuity also assert inhibition with the resulting clock state.
A command's own capture inhibition does not revoke its commit. Expiry remains a
registered level; its consumption overrides validity-setting commands and PPS.

## Registered lifecycle and queue boundaries

RX overflow/flush detection at N clears the queue and publishes registered
abort/overflow/epoch after N. A valid old head may transfer at N; consumers give
the now-visible abort priority at N+1 and discard pending work. The RX queue head
itself is registered. Its [synchronous FWFT FIFO](autonomous-endpoint.md#rx-queue-storage)
delivers a new completion to an available head three clocks after EOF. Logical
occupancy includes the write/read pipeline and head, preserving configured
capacity. Invalidation suppresses head capture while the registered FIFO reset
clears internal validity on the following edge.

Port lifecycle and measurement fields are registered together. A local cause
sampled at N is visible after N and consumed by PHC/servo/children at N+1.
`PtpEndpointControl` restart/flush assembly adds another register. It uses the
already published configuration apply; its IRQ status consumes the prior event
register. Consolidation from `PtpEndpoint` preserves these cycles. PHY and generation checks
remain local to the affected owner. These are bounded event-delivery latencies,
not retroactive cancellation of already committed operations.

The port's child requests and payloads are registered. Allocation is held until
the ledger accepts it; only then may TX begin. A reservation accepted on the
local cancellation-detection edge still owns a frame, which survives restart
and drains normally. E2E operands and the exchange diagnostic tag are frozen
until result consumption or cancellation. The port does not admit replacement
work while the registered child cancellation is being consumed.

The exact multi-hop boundaries are:

| Transfer | Detection and consumption edges |
| --- | --- |
| Port lifecycle to `PtpEndpointControl` | A cause sampled at N publishes after N; the controller consumes at N+1 and publishes its event for consumption at N+2. MAC-change restart therefore crosses two registered hops. |
| Delay response to ledger | Port RX at N stages the response; ledger consumption at N+1 registers acceptance; the port consumes that acceptance with retained log-interval metadata at N+2. |
| Ledger allocation | Registered capacity promises a slot to the sole allocator until shared cancellation/reset. The request handshake creates the first TX beat; a reservation already accepted on a cancellation-detection edge is preserved. |
| E2E request | Registered valid and frozen Sync/Delay/ratio/limit remain owned through result consumption or cancellation; no replacement request may overwrite the diagnostic exchange tag. |

Ledger samples, sample-valid, occupancy and counters remain registered;
sequence extension is fixed wiring. Allocation capacity derives from the
resolved table and next key. Response acceptance is a registered one-cycle
completion, aligned with metadata retained by the caller. Servo math-child
cancellation is registered too; local cancellation immediately clears the
parent's transaction and excludes results.

## Configuration and snapshots

Configuration prepare freezes each bank's pre-edge shadow and validation vote
together. Later AXI writes cannot alter that candidate. A later registered apply
activates the same candidate in every bank. AXI-only reset cancels bus responses,
not accepted commands, active configuration or snapshots.

A snapshot has separate registered issue and consumption edges. The coordinator
broadcasts capture and sequence at N; every bank snapshots pre-edge state at
N+1 and the coordinator reports completion on that edge. An invalidation can
defer a new issue, but cannot withdraw an issued snapshot. If a command commits
at N+1, the snapshot still describes coherent pre-command state; if it committed
at N, the snapshot describes the coherent resulting state. Live and frozen
state have distinct storage and lifetimes. `PtpEndpointControl` also registers
configuration control, IRQ and AXI responses; enable outputs are fixed slices
of active configuration.

## CDC mailbox

Application ready/valid and both directions' FIFO strobes are registered.
Each direction uses the existing SURF FIFO and reset synchronizers. Registered
write strobes pulse with a gap for the registered acknowledgement and retry only
without acknowledgement; each pending request/response owns its payload.
The reader latches a returning FIFO word on its registered
take edge, publishes valid/sequence/data together, and admits a new request only
once that slot is free. Either domain's reset asynchronously clears the session,
including registered output valid with a stopped reader clock.
