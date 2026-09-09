# PTP interface record review

Status: implementation prepared for VHDL review. Regression simulations remain
on hold until maintainer approval. This pass groups existing interfaces without
adding state or changing the register map.

## Groups implemented

| Interface | Record and ownership | Contract |
| --- | --- | --- |
| Servo commands to PHC | `PtpPhcCommandMasterType`: `data`, `valid`, `cancel`, `stale`; servo produces it. | Hold the payload through admission. `cancel` gates admission; `stale` can revoke already accepted work. Both controls remain meaningful independently of `valid`. |
| PHC command response | `PtpPhcCommandSlaveType`: `ready`, `ack`, `error`; PHC produces it. | Admission and completion are separate phases. Ownership lasts through acknowledgement, and `error` describes the acknowledged servo command. Manual command completion remains local to the PHC register bank. |
| Servo diagnostics | `PtpServoStatusType`: state, filtered delay, offset, computed rate, filter occupancy and rejection count. | Live values from registered servo state. Delay/offset use signed Q16 ns; rate uses signed Q16 ppb. The coordinator still consumes only state and filter count. |
| Configuration commit | `PtpConfigControlType`: `prepare`, `apply`, `busy`; coordinator broadcasts it. | Preparation freezes each bank's candidate, independent scalar validation votes qualify apply, and busy inhibits conflicting manual PHC commands. |
| Register snapshots | `PtpSnapshotControlType`: `capture`, `sequenceId`; coordinator broadcasts it. | A capture samples pre-edge state and assigns the same sequence to every bank. Configuration commit and snapshot capture remain separate transactions. |
| RX diagnostics | `PtpRxCountersType`: `accepted`, `dropped`, `overflow`; frontend produces it. | Named saturating counters replace the anonymous three-word array. Port snapshot/register offsets preserve their previous order. Counter semantics exclude frames lost before SOF or during flush from `dropped`. |
| PHC observation at timestamp adapter | Reuse `PtpPhcStatusType`. | Generation, increment, ticks and validity now arrive as the existing PHC status record, alongside `PtpTimeType`. No new duplicate clock-status type is needed. |

All six new record types have package initialization constants and comments
covering units, direction and lifetime. The existing measurement master/slave,
port status, time/capture and protocol payload records remain in use.

## Boundaries retained

- Clock/reset, AXI-Lite/AXI Stream, and GMII/XGMII interfaces retain their normal
  SURF conventions. These do not need another PTP-specific wrapper record.
- `restart`, `captureAbort`, `expireTime`, enables, IRQ, and per-bank validation
  votes remain independent controls. They have different owners or lifetimes.
- The central register block still takes narrow status fields, rather than a
  whole diagnostic record that would blur local register ownership.
- RX messages and TX completion messages already have payload records. Their
  queue handshakes and abort signals remain explicit in this pass: RX queue
  invalidation and physical TX observation have distinct lifetime rules.
- Serialized math and ledger services retain their existing point-to-point
  handshakes. Their operand/result payloads and transaction controls could form
  a later focused cleanup; they are not folded into endpoint-wide records.
- The asynchronous PHC reader keeps its explicit request/response pins and CDC
  boundary. Introducing a record would not itself make that crossing safe.

## Integration and verification

`PtpEndpoint` and `PtpRegWrapper` connect complete command, configuration,
snapshot and servo-status records. The register fixture overrides prepare/apply
fields in a copied configuration-control record while preserving busy. Physical
compositions forward the named RX counters and complete PHC status.

Standalone cocotb wrappers flatten record fields at their DUT maps, preserving
the existing scalar Python interface. No new VHDL stimulus or protocol state
machine was added to a wrapper. Direct VHDL users of the changed entities must
adopt the new record ports; the external `EthMacPtpEndpoint` interface and
software register ABI are unchanged.

Validation: all 22 PTP VHDL files pass VSG, and all 21 RTL entities/wrappers
compile and link with GHDL; no simulator executable was run. Static comparison
confirms that command/servo/control/capture/frontend combinational equations
are preserved under the field renaming, apart from routing the PHC error into
its owner-specific command response. See the
[current validation record](rtl-readability.md#validation-and-next-step).
No regression result predating this pass establishes its behavioral correctness.
After approval, rerun command cancellation/ownership, distributed commit and
snapshot, and RX capture/counter checks before the endpoint regressions.
