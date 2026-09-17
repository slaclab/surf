# PTP RTL readability guidelines

Apply the shared [SURF VHDL conventions](../../vhdl-conventions.md) throughout
`ethernet/PtpCore`, including wrappers. They own the guidelines for process
structure, output records, registered interfaces, scratch variables, constants,
AXI-Lite ownership and review. The PTP-specific timing below supplements them.

Keep progress and verification results in the [task overview](README.md#current-validation).
The [output-register survey](output-register-survey.md) records applied fixes
and retained timing exceptions; [interface contracts](interface-records.md)
describe ownership and handshakes.

## Registered command and expiry interface

The servo-to-PHC interface has an explicit cancellation window. If the PHC
accepts a command at edge N, cancellation registered by the servo on that edge
can veto its pending commit at N+1. Cancellation first sampled at N+1 cannot
undo that commit. Both cancellation bits remain meaningful when valid is low,
and completion/error belong to the accepted command's owner.

A registered expiry level sampled at N is consumed by the PHC at N+1. Preserve
that latency for both assertion and release, including priority over
validity-setting commands and PPS. Do not move an immediate abort behind a
register without updating its consumers and contract.

## Immediate lifecycle and capture controls

RX overflow, port lifecycle and PHC capture invalidation must prevent stale
work from transferring or committing on the current edge. Snapshot capture is
qualified by the same capture invalidation at every bank. These intentional
exceptions are documented in the owning RTL and the output-register survey;
retiming them requires changing the connected protocol together.

Arithmetic results and ledger samples have registered valid outputs. Their
producers and consumers exclude shared cancel/restart and system-reset edges
from transfers even if valid and ready remain high before the edge.

## Configuration and snapshots

PTP configuration uses coordinated prepare, validate and apply phases. Each
bank's candidate and validation result must describe the same values. This
excerpt assumes `validConfig` returns a Boolean:

```vhdl
if configControl.prepare = '1' then
   v.candidate   := r.shadow;
   v.configValid := toSl(validConfig(r.shadow));
end if;

if configControl.apply = '1' then
   v.activeConfig := r.candidate;
end if;
```

Both preparation assignments use `r.shadow`. A simultaneous AXI write may
already have updated `v.shadow`, but that write belongs to a later candidate.
Later writes must not alter the pending candidate or its vote. Initialize the
vote consistently with the candidate's defaults. In this example, prepare and
apply are separate phases; the coordinator consumes the vote before issuing
apply on a later edge.

Keep bus-only reset separate from functional reset when their lifetimes differ.
Resetting bus responses must not discard an accepted command or active settings
that belong to the system-reset lifetime. Document which reset owns each
transaction and its side effects.

A coordinated snapshot samples the same agreed edge in each participating bank:

```vhdl
if snapshotControl.capture = '1' then
   v.snapshotStatus   := r.status;
   v.snapshotSequence := snapshotControl.sequenceId;
end if;
```

The snapshot is a copy of pre-edge live status, tagged with the common request's
identity. Matching sequence counters alone do not guarantee coherence. Specify
how reset, configuration changes and capture invalidation affect a pending
snapshot, especially if any values cross clock domains.
