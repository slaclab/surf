# PTP RTL readability guidelines

Apply the shared [SURF VHDL conventions](../../vhdl-conventions.md), especially
[registered boundaries](../../vhdl-conventions.md#registered-boundaries-are-the-default).
The [output-register survey](output-register-survey.md) records the actual
boundaries and justified exceptions. The timing contracts below supersede the
previous immediate-control implementation. Progress and verification remain in
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
state have distinct storage and lifetimes.

## CDC mailbox

Each direction uses the existing SURF FIFO and reset synchronizers. Registered
write strobes pulse with a gap for the registered acknowledgement and retry only
without acknowledgement; each pending request/response owns its payload.
The reader latches a returning FIFO word on its registered
take edge, publishes valid/sequence/data together, and admits a new request only
once that slot is free. Either domain's reset asynchronously clears the session,
including registered output valid with a stopped reader clock.
