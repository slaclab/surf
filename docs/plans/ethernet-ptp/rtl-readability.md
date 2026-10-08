# PTP RTL readability guidelines

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
child boundaries with registered reset-completion tracking. `PtpEndpoint`
registers restart, RX flush and IRQ-event assembly and forwards child functional
outputs. `PtpPkg` defines the record contracts and has no module outputs.

The remaining exceptions are:

- Reverse ready in `PtpMath`, `PtpE2e`, `PtpPrimaryGuard`, `PtpPort` and
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
  `PtpRegWrapper` registers restart/events like production; its bank override
  and snapshot-inhibit injection remain test stimulus. It exposes actual
  configuration apply separately from delayed restart. The RX fixture combines
  its injected flush with PHY loss; these fixtures do not define a production
  timing boundary. The ledger fixture exposes registered response acceptance
  for independent timing checks.

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
itself is registered, including selection after enqueue or consume/refill.
It holds a copy of the counted head, so queue capacity is unchanged; selection
uses resolved queue data and pointers before the register.

Port lifecycle and measurement fields are registered together. A local cause
sampled at N is visible after N and consumed by PHC/servo/children at N+1.
Endpoint restart/flush assembly adds another register. PHY and generation checks
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
| Port lifecycle to endpoint assembly | A cause sampled at N publishes after N; endpoint assembly consumes at N+1 and publishes its event for consumption at N+2. MAC-change restart therefore crosses two registered hops. |
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
state have distinct storage and lifetimes. `PtpReg` also registers
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
