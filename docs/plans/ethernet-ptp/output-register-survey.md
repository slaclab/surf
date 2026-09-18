# PtpCore output register survey

Scope: all 15 RTL/package files and seven wrappers in `ethernet/PtpCore`.
The [registered-boundary redesign](../ptp-registered-boundaries/README.md)
supersedes the earlier acceptance of immediate control and queue-selection
exceptions. These changes affect interface latency; previous simulation results
do not validate them. Simulation and pytest remain paused for VHDL review.

## Functional boundaries

| Owner | Registered boundary and transaction handling |
| --- | --- |
| `PtpRxFrontend` | `message` stores the selected next queue head alongside valid. Selection occurs before the register, using resolved queue data/pointers for empty enqueue and consume/refill. Queue capacity is unchanged; the output register holds a copy of the counted head. Overflow/abort register with queue invalidation and epoch. A detection-edge transfer may precede the event; downstream pending work is canceled when the event is consumed. |
| `PtpPort` | Complete measurement and lifecycle records publish from `r`. Allocation valid is held until the ledger handshake, which creates the first TX beat. A coincident local cancellation preserves an already accepted reservation/frame. Delay responses are staged with their payload; a metadata stage aligns the log interval with the ledger's registered acceptance. E2E stages Sync, Delay, ratio and limit together and owns the exchange until result consumption. Child cancellation is registered; local admission waits through its consumption edge. |
| `PtpTxLedger` | Allocation capacity is computed from the resolved table and next key, then registered. The sole allocator honors that promise until shared cancellation/reset. Response acceptance is a registered one-cycle completion; the caller retains submitted metadata. Samples, sample-valid, occupancy and counters remain registered. Sequence extension is fixed wiring. |
| `PtpPhc` | Command ready/ack/error publish as a complete registered response. Ready reserves the free slot against manual request priority; completion routes to the accepted owner before registration. SET/PHASE admission registers capture inhibition before commit, including conservative inhibition of rejected operations. Fault/discontinuity retain inhibition with the resulting PHC state. Time, status, PPS and arithmetic requests are registered. |
| `PtpReg` | Snapshot capture/sequence now form a registered broadcast. All banks sample pre-edge state on the next edge; the coordinator completes on that same edge. Invalidation defers issuance but cannot withdraw an issued observational snapshot. Config control, IRQ and AXI responses remain registered. Enable outputs are fixed slices of active configuration. |
| `PtpEndpoint` | Registers restart, RX flush and IRQ-event assembly. Child functional outputs are forwarded. Local generation/cancellation checks protect admission while endpoint-wide events traverse this added hop. |
| `PtpPhcRead` | Registers application ready/valid and both FIFO directions' strobes. Each write is pulsed and retried only without acknowledgement; pending ownership retains its payload. Reader data is latched on the actual registered FIFO-take edge. Existing asynchronous reset registers clear valid with a stopped clock; output qualification logic is removed. |
| `PtpServo` | Command, cancellation, expiry and status records are registered. The math child now consumes registered cancellation too; local cancellation still clears the parent's transaction immediately and excludes results. |
| `PtpMath`, `PtpE2e` | Operands/requests and result payload/valid are registered. Shared cancel/reset excludes a transfer at both producer and consumer. |
| `PtpRxTimestampAdapter`, `PtpPrimaryGuard` | Already publish complete registered forward records. |
| `EthMacPtpEndpoint`, `PtpTxTimestampTap` | Structural composition and registered reset-completion tracking; inherit the children’s forward boundaries. |
| `PtpPkg` | Documents registered measurement, lifecycle and snapshot contracts; no module outputs. |

## Remaining exceptions

- Reverse ready in `PtpMath`, `PtpE2e`, `PtpPrimaryGuard`, `PtpPort` and
  `PtpServo` expresses current capacity, simultaneous retirement or competing
  admission/cancellation. Registering these signals alone would advertise a
  slot that may not exist; a timing break needs an additional reserved slot or
  an existing buffered SURF pipeline. These are reverse handshakes, not
  permission for combinational forward payload, result or lifecycle outputs.
- Reset distribution and fixed polarity conversion remain combinational:
  endpoint AXI reset combines system/bus reset, mailbox reset joins its domains
  before `RstSync`, and the TX observer converts PHY-ready to active-high flush.
  The latter lets its frontend discard partial physical traffic on the same
  PHY-loss sampling edge as the adapter; published invalidation is registered.
  Adding a separate flush register would misalign those two consumers.
- Constants, fixed slices/extensions and structural forwarding preserve the
  underlying child/register ownership and need no extra stage.
- Simulation wrappers flatten/pack interfaces and inject fixture controls.
  `PtpRegWrapper` now registers restart/events like production; its explicit
  bank override and snapshot-inhibit injection remain test stimulus. It exposes
  actual configuration apply separately from delayed restart. The RX fixture
  combines its injected flush with PHY loss; these fixtures do not define a
  production timing boundary. The ledger fixture exposes registered response
  acceptance for independent timing checks.

## Validation

See the [redesign handoff](../ptp-registered-boundaries/README.md) for final lint,
compile/link evidence, authored behavioral checks and timing tables. No new
behavioral equivalence, FPGA timing/resource or physical CDC claim is made.
