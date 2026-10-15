# PTP interface and service contracts

Apply the shared [SURF VHDL conventions](../../docs/vhdl-conventions.md), especially
[registered boundaries](../../docs/vhdl-conventions.md#registered-boundaries-are-the-default).
The boundary ownership, justified exceptions and timing contracts below
supersede the previous immediate-control implementation. Progress and verification
remain in
[current validation](../../docs/plans/ethernet-ptp/README.md#current-validation).

## Parameter and implementation contracts

At `EthMacPtpEndpoint`, GMII requires 125 MHz and XGMII requires 156.25 MHz;
set both PHY and frequency generics when selecting GMII. The composition asserts
these pairs because a wrong nominal rate also invalidates the estimator's
acquisition envelope. This restriction does not set the clocks for standalone
PHC/arithmetic tests. `PtpTxLedger` supports depths 1 through 255 so its eight-bit
occupancy and unresolved fields remain representable, including depth one.

Use named generic association under PtpCore, following SURF conventions.
Calculation-only values belong in fully assigned local variables; retained diagnostics and snapshots
remain state. Resolve synchronous reset before `rin <= v` and publication,
without changing asynchronous reset templates or adding output pipeline stages
as a style edit. The remaining reverse-ready paths resolve through `v` beside
admission and retain explicit reset/cancellation suppression. The disabled servo
still drains measurements. Registering reverse ready requires a capacity and
buffering design, not a mechanical replacement of `v` with `r`.

These rules retain the decisions from the
[ownership and publication decisions](../../docs/plans/ethernet-ptp/history/decisions.md#keep-ownership-local-and-publish-at-explicit-edges).
Dated check results do not establish acceptance of later source.

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
The [endpoint numerical envelope](architecture.md#port-policy-and-numerical-envelope)
distinguishes the derived service floor from the actuator cap awaiting qualification.

## Arithmetic primitive contracts

The fixed-function architecture preserves exact integer semantics; the
[decision record](../../docs/plans/ethernet-ptp/history/decisions.md#fixed-function-arithmetic-architecture)
explains the choice over the retired word processor. Leaf entity comments own
cycle-level handshakes. Prototype timing budgets are conditional measurements,
not the replacement endpoint service proof.

`PtpConstDivide` takes a signed W-bit operand and a positive constant divisor.
Form its magnitude as **unsigned W bits**, including the signed minimum. Factor
`d = odd * 2^k` and split the magnitude as `m = h * 2^k + l`. Restoring division
of `h` maintains the prefix invariant `prefix = q * odd + r`, `0 <= r < odd`;
each next trial is below `2 * odd`, so one subtract suffices. Reconstruct the
exact remainder as `R = (r << k) | l`. Discarding `l` before rounding is incorrect.

| Converter | Divisor | k | Odd factor | Remainder bits |
| --- | ---: | ---: | ---: | ---: |
| SECOND (Q16 ns per second) | 65,536,000,000,000 | 25 | 1,953,125 | 46 |
| BILLION (ppb scale) | 1,000,000,000 | 9 | 1,953,125 | 30 |
| NOMINAL at 125 MHz | 34,359,738,368 | 35 | 1 | 35 |
| NOMINAL at 156.25 MHz | 27,487,790,694 | 1 | 13,743,895,347 | 35 |

Derive NOMINAL from the actual clock generic. The odd-factor-one case bypasses
the serial loop. Nearest rounding increments the magnitude quotient when
`R >= ceil(d/2)`, comparing at the full remainder width; using `floor(d/2)` is
wrong for odd divisors and doubling a narrow remainder can overflow. Apply the
operand sign afterward, giving ties away from zero. The published remainder
always belongs to truncation and has the dividend's sign. Only truncating mode
satisfies `operand = quotient*d + remainder`; a rounded quotient and this
remainder are not a division pair.

`PtpVariableDivide` uses signed128 dividends and positive unsigned80 divisors
for rate and E2E. Reject signed or wider divisors before narrowing; divide by
zero is an observable error. Preserve each capture's increment for calibration:
manual RATE commands are not restricted to the nominal oscillator-error envelope.

Keep full products until checking overflow. E2E's signed68-by-unsigned64 tree
produces 132 bits and rejects signed128 overflow before the 35-bit rounded elapsed
shift. PI's signed96-by-unsigned95 limb product retains 191 bits and rejects
signed128 overflow before its 62-bit rounded integral shift. Signed64 Q16 offset
times unsigned32 Q2.30 gain fits signed96. Narrowing only after a shift would
silently change which inputs are accepted.

`PtpEpochNormalize` factors seconds48 times SECOND into a 48-by-21 product,
then shifts its 69-bit product by 25 and adds subsecondQ16. All unsigned48
subsecond values fit the unsigned94 sum; the returned signed95 value has a zero
sign bit. Timestamp canonicality and signed corrections remain caller checks.

Manual PHASE retains all four signed128 submission words and checks sign
extension into signed96 before preparation through the shared SECOND128 service.
High-word mismatch rejects the command early without a PHC fault or generation
change. Representable adjustments that fail at the live commit epoch retain
late-fault behavior. Servo phase retains its full signed128 contract.

Shared services use round-robin arbitration, one outstanding transaction per
owner and independent held responses. A stalled response cannot retain the
arithmetic core and block another owner. Hold request payload/valid until transfer;
reset or owner-local cancellation excludes transfer and discards that owner's
pending/held work. PHC ACK commits servo state separately and holds no service.
These rules do not remove queue, history, publication or command costs from the
[complete service-bound obligation](#shared-service-bound).

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
| Configuration commit | `PtpConfigControlType`: `prepare`, `apply`, `busy`; coordinator broadcasts it. | Registered from resolved next state. Preparation freezes each bank's candidate; completion handshakes and independent validation votes qualify apply, and busy inhibits conflicting manual PHC commands. System reset resets the coordinator and every bank. |
| Register snapshots | `PtpSnapshotControlType`: `capture`, `publish`, `sequenceId`; coordinator broadcasts it. | Registered capture/sequence issue together. All banks freeze pre-edge state, then a common publication follows their completion votes. An issued snapshot is not withdrawn by later invalidation. Configuration and snapshots remain separate transactions. |
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
- Shared arithmetic uses operand/result handshakes on `PtpSecondService` and
  `PtpVariableDivide`. Each service owns two clients at endpoint scope, with
  round-robin admission, registered independently held responses and owner-local
  cancellation. Consumers exclude cancel/reset edges from transfers. Algorithm
  state stays local to the client; there is no shared addressed workspace.
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
itself is registered. Its [synchronous FWFT FIFO](architecture.md#rx-queue-storage)
delivers descriptors to the sparse wire-position decoder. Decoding latency depends
on fixed body length. Logical occupancy includes the pipeline/decoder/head, preserving configured
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

The rate estimator captures the complete Sync sample and minimum span on input
acceptance. Its registered `resultValid`, `sampleAccepted` and `ratioUpdate`
remain held until `resultReady`; input acceptance alone does not publish a
measurement. The protocol engine waits for completion, stores the combined
signed128 correction in history, and acknowledges after forwarding the result.
Rejected samples publish no history/forward measurement. A rejected rate
candidate still permits an otherwise accepted Sync to publish the retained
ratio; only `ratioUpdate` renews ratio freshness.

Chronology compares against the last accepted Sync, independently of the rate
anchor. A span shorter than `minimumSpan` raw cycles retains the anchor. Every
attempted rate interval advances the anchor, even if its candidate fails the
oscillator margin. Tick/phase spans use Q3 units; the minimum span is shifted by
three before comparison. Cancellation discards held completion and qualification
without changing the retained ratio payload.

The exact multi-hop boundaries are:

| Transfer | Detection and consumption edges |
| --- | --- |
| Port lifecycle to `PtpEndpointControl` | A cause sampled at N publishes after N; the controller consumes at N+1 and publishes its event for consumption at N+2. MAC-change restart therefore crosses two registered hops. |
| Delay response to ledger | Port RX stages and holds the response until a complete RAM scan acknowledges it. That handshake at H registers acceptance; the port consumes acceptance and the retained log interval at H+1. |
| Ledger allocation | Each completed scan can offer one registered capacity pulse. The handshake creates the first TX beat; a reservation already accepted on a cancellation-detection edge is preserved. |
| Ledger words/sample | Each synchronous word read takes two clocks. Scanning 22 words and evaluating each row takes 45*depth+2 clocks; allocation adds 22 writes. A request arriving mid-scan can require the next scan. Restart cancels eligibility/output while physical completions continue. |
| E2E request | Registered valid and frozen Sync/Delay/ratio/limit remain owned through result consumption or cancellation; no replacement request may overwrite the diagnostic exchange tag. |

Ledger samples, sample-valid, occupancy and counters remain registered;
sequence extension is fixed wiring. Allocation capacity derives from the
completed table scan and checked sequence candidate. Response acceptance is a registered one-cycle
completion, aligned with metadata retained by the caller.

The servo holds one measurement while its filter or PI child processes it;
child input acceptance does not release the parent's measurement ownership.
Filter ready remains asserted on its accepting edge and falls during sorting.
The parent resumes admission when the active child returns idle. Its rejection
counter includes provenance, filter and PI rejections without replaying samples.

Servo cancellation is resolved combinationally into both children's state
updates. This is a deliberate exception to registered child controls: the PHC
commits one clock after command admission, so inserting another register before
the PI child's registered command cancellation would miss the commit veto.
Filter median/count and PHC command/cancel remain registered at their owners.
Cancellation on a median publication edge suppresses that publication and keeps
the preceding median with count zero; cancellation after publication retains the
new median with count zero. Association expiry remains live while either child
owns a measurement, including the registered input holding stage.

The ledger shares one widened subtract/compare across its mutually exclusive
association-age, response-chronology and wire-age checks. Modulo-64 age handling
and the response's nonnegative chronology check remain distinct; every check
uses the same edge as before. Its live expiry checks remain local and are not
serialized across clocks.

Protocol pair/history scans can overlap after pair admission. Their row checks
share a separate 32-bit word ALU with round-robin arbitration at row boundaries.
Each client holds its row fields and admission-time ticks through the matching
DONE edge. Age subtraction discards the final borrow (modulo 64); history Q3
distance retains all 68 signed bits before optional word-wise negation. Limit
comparisons are inclusive, while best/oldest comparisons are strict to retain
the first physical slot on ties. Invalid rows skip the ALU. Cancellation clears
both clients and ALU ownership on the same edge, with final priority over DONE;
stale scratch cannot publish after a restart. These scans do not use the arithmetic services. See the [implementation record](../../docs/plans/ethernet-ptp/history/decisions.md#share-computation-and-word-storage-preserve-real-time-capture).

## Configuration and snapshots

`PtpConfigBank` has three 32-bit banks. Prepare pins the current shadow as an
immutable candidate, then clones it to the next shadow before accepting later
writes. Previously accepted writes drain before the copy. Initialization writes
three banks in `3*N+1` clocks; preparation, including a prior transaction, is
bounded by `4*N+8` clocks (N=48 port, 34 servo, 10 PHC manual operands).
Unfinished preparation is distinct from a negative validation vote. The endpoint
waits for port and servo `configPrepared`, checks all votes, then broadcasts one
registered apply. Active pointers and per-clock caches switch on that edge.

Scalar PHC configuration retains its local candidate. Manual command operands
use the same word-bank freeze/copy mechanism, independently of global config.
AXI-only reset cancels responses, preserving accepted writes, commands, copies,
active settings and coordination. A read/modify/write honors the original field
strobes; malformed strobes keep their DECERR behavior. Algorithm reads and AXI
requests arbitrate locally, with separate held responses.

Snapshots use two broadcasts: `capture` pins the common pre-edge cohort, and
`publish` exposes it after every `snapshotPrepared` reports completion. Result
records use five version banks per record (live, old snapshot, pending snapshot,
next result and retiring reader), with word writes and immutable ownership.
Changing scalars are latched at capture and copied into an inactive word bank.
Announce body and decoded metadata share one pinned record; only the seven
protocol counters need scalar latches. The largest scalar bank is the PHC's
10 words; publication occurs 13 clocks after capture.
The old snapshot and sequence remain readable while SnapshotBusy is high.

A result's registered publication event describes its already-visible public
record, so capture includes that event. A result becoming visible on the capture
edge belongs to the next cohort. Config apply, PHC commit and invalidation obey
the same pre-edge rule. Invalidation may defer capture but cannot withdraw an
issued cohort. Reads select the published bank at admission; an already admitted
read completes against that bank even if publication occurs while it is pending.
System reset invalidates ownership without clearing payload RAM.

Configuration and publication banks expose an appended `MEMORY_TYPE_G` selecting
`distributed` (default) or `block`, both with one synchronous read cycle. Production
protocol/servo configuration and protocol publication select block RAM; the PHC
operand and servo publication banks retain distributed mapping. Pair/history and
ledger default to block RAM through their existing generics. Mapping changes do
not change initialization, copy, snapshot, cancellation or ownership timing.

## Shared service bound

Each endpoint owns one `PtpSecondService` for the servo/manual PHC clients and
one `PtpVariableDivide` for the rate/E2E clients. E2E sequences its two
calibration planes through the same owner. Both services arbitrate round-robin,
hold each owner's response independently, and cancel only the selected owner.
Cancellation wins over completion. Clients retain their algorithm state locally;
waiting for PHC ACK holds no arithmetic service. The servo commits frequency
only after a successful PHC ACK.

The **70,347,776-raw-tick floor remains unchanged** during this migration.
The derivation below records the retired word-serial implementation's service
costs; it is not a latency claim for the replacement services. A complete new
bound including queues, history, filtering, configuration and commands remains
an acceptance item before reducing the floor.

### Retained floor derivation (word-serial implementation)

The following conservative bounds count clocks, not measured simulator latency:

- A division bit costs at most 34 clocks: four five-clock low-word trials,
  one three-clock high-word trial, five two-clock accepted-remainder copies and
  one bit-advance clock. All 128 bits plus at most 256 clocks for sign loads,
  normalization, scratch clearing, quotient-word loads, rounding, restoration
  and retirement fit **J=4,608**. Other operations are shorter: even a 127-bit
  format shift takes 508 two-clock word iterations plus bounded setup/restore.
- An eligible word request or admitted descriptor is served within
  **W=4*(J+8)=18,464** clocks, including its own retirement. At most four
  descriptor turns intervene, with at most four three-clock host reads. The
  extra per-turn clocks cover admission and registered response consumption.
  A blocked owner's response cannot extend another owner's bound.
- Count every operand/result word and descriptor as a W-sized service quantum.
  Conservative sequencer ceilings are rate **128**, E2E **128** (including
  history streaming and both calibrations), median **64**, servo forward/PI or
  phase preparation **256**, and manual PHC **32**. Rate uses at most 66 word
  transfers and 24 descriptors. E2E uses at most 80 word transfers and 27
  descriptors. Median uses 24 transfers and at most 36 compare/copy descriptors.
  PI permits 128 transfers and 96 descriptors, including clamp copies and
  initialization/holdover transitions; the 256-quantum ceiling covers both. PHC uses 16 transfers
  and one division. Each ceiling exceeds the corresponding actual path.

For a finite admitted burst, charge each of four RX records a complete
608-quantum chain, each of four ledger records an additional 192-quantum
E2E/median chain, and all current pipeline work another complete 608-quantum
chain. This overcounts mutually exclusive work. Reserve 4,096 local clocks for
each of those nine units for frame completion, pair/history/ledger scans,
configuration reads/copy, diagnostic writes and command commit. The resulting
floor is **70,347,776 raw ticks**:

```text
(4*608 + 4*192 + 608)*18,464 + 9*4,096 = 70,347,776
```

The protocol scan ALU adds bounded local work within that allowance. A pair row
uses 2 age, 2 limit and 2 oldest-comparison clocks plus grant and DONE: **8**.
A history row uses 2 age, 2 age-limit, 3 distance, at most 3 negation, 3
separation-limit and 3 nearest-comparison clocks plus grant and DONE: **18**.
Only two owners exist, so an eligible row waits for at most one competing row;
its combined wait/service fits **26 clocks**. Four rows plus RAM reads and row
advances take at most `4*(6+26+1)=132` pairing clocks or
`4*(8+26+1)=140` history clocks. Allow **256 local clocks per table transaction**
including pair duplicate reads/update/publication or the history fetch. Any
normalized-history transfer stalls are charged to E2E's existing shared-compute
quanta above. These local costs fit the existing 4,096-clock reserve; the floor
and register ABI are unchanged. This is a source-derived ceiling, not a measured
latency or timing-closure result.

`MinimumAssociationTicks` advertises this floor at protocol offset 0x0F8;
validation rejects smaller candidates. The two-second default remains valid at
125 and 156.25 MHz. For a slower standalone generic, initialization raises only
the association default to the floor when necessary. Other application timers
still require a suitable configuration. The floor is approximately 563 ms and 450 ms respectively.
It bounds processing after required packet inputs arrive; it does not cover
network delay, waiting for a future Follow_Up/Delay_Resp, an indefinitely paused
MAC, repeated configuration restarts or stalled external consumers. Age always
uses the original capture/creation ticks. A packet admitted already near expiry
can still expire; the floor does not refresh it.

At 10 complete chains per second, even charging every quantum the entire
single-operation J (including word transfers) consumes at most 28,016,640 clocks
per second plus local work, below 23% of a 125 MHz endpoint. This is a conservative
service-demand calculation, not measured latency or hardware performance. The
initial encoded master interval remains 8 Hz; packet admission imposes no new
frequency rule. Unlimited traffic/stalls have a bounded storage/overflow and
cancellation contract, not a promise of successful completion. Full RX overflow
flushes its cohort; unknown TX fate remains quarantined; rejected RX cannot
preempt an already completed E2E result indefinitely.

## CDC mailbox

Application ready/valid and both directions' FIFO strobes are registered.
Each direction uses the existing SURF FIFO and reset synchronizers. Registered
write strobes pulse with a gap for the registered acknowledgement and retry only
without acknowledgement; each pending request/response owns its payload.
The reader latches a returning FIFO word on its registered
take edge, publishes valid/sequence/data together, and admits a new request only
once that slot is free. Either domain's reset asynchronously clears the session,
including registered output valid with a stopped reader clock.
