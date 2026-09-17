# PTP interface record review

Status: implementation prepared for VHDL review. Regression simulations remain
on hold until maintainer approval. The register map is unchanged. The port
lifecycle/status follow-up separates immediate controls from clocked diagnostic
reporting and makes the status record own live diagnostic state.

## Groups implemented

| Interface | Record and ownership | Contract |
| --- | --- | --- |
| Servo commands to PHC | `PtpPhcCommandMasterType`: `data`, `valid`, `cancel`, `stale`; servo produces it. | All fields are registered. Hold payload/valid through admission or withdrawal. Both cancellation bits gate admission and can revoke pending work independently of `valid`. Cancellation registered on the admission edge vetoes the following commit edge; a later sampled event cannot undo a committed command. |
| PHC command response | `PtpPhcCommandSlaveType`: `ready`, `ack`, `error`; PHC produces it. | Admission and completion are separate phases. Ownership lasts through acknowledgement, and `error` describes the acknowledged servo command. Manual command completion remains local to the PHC register bank. |
| Port lifecycle | `PtpPortLifecycleType`: `commandAbort`, `identityRestart`; port produces it. | Combinational controls act before the next edge. Command abort excludes the PHC command's own capture invalidation; identity restart flushes on the same edge as a MAC-derived identity update. No handshake. |
| Port diagnostics | `PtpPortStatusType`: activity/validity summaries, exchange, Announce metadata, ledger state and counters. | Registered output and local live AXI reads share the same state. Protocol-owned values update directly in the record; ratio/Announce validity and ledger observations are sampled each edge. Immediate lifecycle controls are separate. Local snapshots retain their pre-edge capture contract. |
| Servo diagnostics | `PtpServoStatusType`: state, filtered delay, offset, computed rate, filter occupancy and rejection count. | The registered record owns these values; outputs and local reads use the same state. Delay/offset use signed Q16 ns; rate uses signed Q16 ppb, clamped before narrowing to its 64-bit field. The coordinator consumes only state and filter count. |
| Configuration commit | `PtpConfigControlType`: `prepare`, `apply`, `busy`; coordinator broadcasts it. | Registered from resolved next state without adding commit cycles. Preparation freezes each bank's candidate, independent scalar validation votes qualify apply, and busy inhibits conflicting manual PHC commands. System reset resets the coordinator and every bank. |
| Register snapshots | `PtpSnapshotControlType`: `capture`, `sequenceId`; coordinator broadcasts it. | A capture samples pre-edge state and assigns the same sequence to every bank. Configuration commit and snapshot capture remain separate transactions. |
| RX diagnostics | `PtpRxCountersType`: `accepted`, `dropped`, `overflow`; frontend produces it. | The registered record owns the saturating counters. Port snapshot/register offsets preserve their order. Counter semantics exclude frames lost before SOF or during flush from `dropped`. |
| PHC observation at timestamp adapter | Reuse `PtpPhcStatusType`. | Generation, increment, ticks and validity now arrive as the existing PHC status record, alongside `PtpTimeType`. No new duplicate clock-status type is needed. |

All seven new record types have package initialization constants and comments
covering units, direction and lifetime. The existing measurement master/slave,
port status, time/capture and protocol payload records remain in use.

## Boundaries retained

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
  queue handshakes and abort signals remain explicit in this pass: RX queue
  invalidation and physical TX observation have distinct lifetime rules.
- Serialized math and ledger services retain their existing point-to-point
  payload ports. Their result-valid outputs are registered; consumers exclude
  shared cancel/restart and reset edges from transfers. Payloads and controls could form
  a later focused cleanup; they are not folded into endpoint-wide records.
- The asynchronous PHC reader keeps its explicit request/response pins and CDC
  boundary. Introducing a record would not itself make that crossing safe.

## Integration and verification

`PtpEndpoint` and `PtpRegWrapper` connect complete command, configuration,
snapshot, lifecycle and status records. The register fixture overrides prepare/apply
fields in a copied configuration-control record while preserving busy. Physical
compositions forward the named RX counters and complete PHC status.

Standalone cocotb wrappers flatten record fields at their DUT maps, preserving
the existing scalar Python interface. No new VHDL stimulus or protocol state
machine was added to a wrapper. Direct VHDL users of the changed entities must
adopt the new record ports; the external `EthMacPtpEndpoint` interface and
software register ABI are unchanged.

At the initial record-conversion checkpoint, all 22 PTP VHDL files passed VSG, and all 21 RTL entities/wrappers
compile and link with GHDL; no simulator executable was run. Static comparison
confirms that command/servo/control/capture/frontend combinational equations
are preserved under the field renaming, apart from routing the PHC error into
its owner-specific command response. See the
[current validation record](README.md#current-validation).
No regression result predating this pass establishes its behavioral correctness.
After approval, rerun command cancellation/ownership, distributed commit and
snapshot, and RX capture/counter checks before the endpoint regressions.

The [registered command/expiry contract](rtl-readability.md#registered-command-and-expiry-interface)
changes servo command cancellation and expiry timing; the earlier equivalence
statement does not apply to that redesign. Command master fields and expiry
are registered, while measurement ready remains combinational. Expiry reaches
the PHC one clock after sampling; either registered cancellation bit can veto
the pending automatic command. Focused checks are authored but remain unrun
pending VHDL approval.
