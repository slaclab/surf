# PtpCore output register survey

Scope: all 15 files in `ethernet/PtpCore/rtl` (14 entities and `PtpPkg`) and
all seven files in `ethernet/PtpCore/wrappers`, reviewed against the same-type
output storage guidance in the [SURF VHDL conventions](../../vhdl-conventions.md#output-ownership-and-interface-timing).

## Disposition

Implemented the record consolidations and registered the state-derived outputs
listed below. Output records own their state; the changes do not add duplicate
copies of the former scalar registers. Normal processing and commit latency
are unchanged. Remaining combinational outputs have explicit handshake,
cancellation or boundary-representation reasons; these are exceptions to the
preferred registered interface, not templates for new control interfaces.

Arithmetic and ledger result-valid outputs now remain stable until the clock
edge when cancellation is sampled. Their consumers must exclude shared
cancel/restart and system-reset edges from transfers even when valid and ready
are high. Production consumers have been updated together with the producers.
Configuration prepare/apply/busy now come from a registered record; system
reset must reset the coordinator and all participating banks together.

## Module coverage

| File | Implemented changes and retained exceptions |
| --- | --- |
| [PtpServo](../../../ethernet/PtpCore/rtl/PtpServo.vhd) | `status` now owns quality, filtered delay, offset, rate, filter occupancy and rejection count. AXI reads/snapshots use that same state. Rate arithmetic stays 128 bits through clamping before storage in the 64-bit status field. Command, AXI, config vote and expiry were already registered. Measurement ready remains combinational backpressure. |
| [PtpRxFrontend](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd) | `counters` now owns all three saturating counters; `messageValid` is registered with resolved next queue fill. Message payload remains a selection from the authoritative queue and epoch a numeric conversion. Overflow/abort remain immediate so a coincident old-head transfer is canceled when the queue is discarded. |
| [PtpPort](../../../ethernet/PtpCore/rtl/PtpPort.vhd) | AXI, TX stream, status and config vote already have matching registered storage. Arithmetic/ledger consumers now explicitly reject results on the shared abort edge. `sharedConfig` remains a view of active configuration. Measurement payload/valid retain immediate abort qualification, and lifecycle controls retain immediate PHC/servo/queue cancellation; registering these independently would permit stale work to commit. RX ready remains backpressure. |
| [PtpPhc](../../../ethernet/PtpCore/rtl/PtpPhc.vhd) | `status.increment` now lives entirely in the authoritative status record, including nominal initialization and rate commits; no output override. `manualBusy` is registered with next manual state. The command response remains an owner-qualified projection of shared registered completion plus combinational ready, avoiding duplicate completion state. `captureAbort` remains immediate to reject an epoch invalidated on the current commit edge. Time, PPS and AXI are registered; config vote is constant. |
| [PtpReg](../../../ethernet/PtpCore/rtl/PtpReg.vhd) | `configControl` and IRQ are registered from resolved next state, preserving prepare/apply and event/mask alignment. AXI records remain registered and enables remain slices of active configuration. Snapshot capture stays qualified by current capture invalidation, with one common sequence for all banks. Retiming it requires a coordinated receiver-side veto/acknowledgement protocol. |
| [PtpMath](../../../ethernet/PtpCore/rtl/PtpMath.vhd) | `resultValid` is now registered alongside result/remainder/error. Caller and producer give shared cancel priority over transfer. Input ready remains combinational admission control. |
| [PtpE2e](../../../ethernet/PtpCore/rtl/PtpE2e.vhd) | `resultValid` is now registered alongside the complete result and error. Its internal math receiver and the port receiver honor shared cancellation. Input ready remains combinational admission control. |
| [PtpTxLedger](../../../ethernet/PtpCore/rtl/PtpTxLedger.vhd) | `sampleValid` now publishes its register directly under the shared restart/reset transfer contract. `ledgerStatus` owns startup/reset flags and counts resolved next entries, so allocation, wire completion and reset update the summary on the same edge. Sample/counters remain registered; allocation sequence is a conversion and ready is backpressure. `responseAccepted` remains a current-response handshake result: the port consumes it with that response's log interval, so delaying it alone would lose alignment. |
| [PtpPhcRead](../../../ethernet/PtpCore/rtl/PtpPhcRead.vhd) | Retained mailbox unpacking, sequence conversion and admission-ready exceptions. Immediate reset qualification of read-valid cancels sessions even with a stopped peer clock. No redundant decoded payload register added. |
| [PtpRxTimestampAdapter](../../../ethernet/PtpCore/rtl/PtpRxTimestampAdapter.vhd) | Already publishes complete registered stream and capture records. Local names differ from port names without fragmenting ownership. |
| [PtpPrimaryGuard](../../../ethernet/PtpCore/rtl/PtpPrimaryGuard.vhd) | Already publishes a complete registered stream and same-type drop counter. Upstream ready remains combinational backpressure. |
| [PtpEndpoint](../../../ethernet/PtpCore/rtl/PtpEndpoint.vhd) | Child outputs remain structural forwards. RX flush combines lifecycle/capture invalidation and must reach the queue on that same edge; its timing exception is documented. |
| [EthMacPtpEndpoint](../../../ethernet/PtpCore/rtl/EthMacPtpEndpoint.vhd) | Structural forwarding is appropriate; local state owns reset-completion tracking without duplicating child outputs. |
| [PtpTxTimestampTap](../../../ethernet/PtpCore/rtl/PtpTxTimestampTap.vhd) | Structural composition inherits adapter/frontend timing; no extra observer pipeline added. |
| [PtpPkg](../../../ethernet/PtpCore/rtl/PtpPkg.vhd) | No module outputs. Existing status/counter records support consolidation. Configuration-control comments now specify registered timing and common reset ownership. Immediate measurement/lifecycle contracts remain explicit. |

## Wrapper coverage

`PtpE2eWrapper`, `PtpEndpointLoopbackWrapper`, `PtpPhcWrapper`,
`PtpRegWrapper`, `PtpRxFrontendWrapper`, `PtpServoWrapper` and
`PtpTxLedgerWrapper` forward or flatten DUT ports. These boundary conversions
remain appropriate without artificial wrapper registers. The ledger wrapper
now also exposes its status word for occupancy-alignment checks.

## Validation and follow-up

All 22 RTL/package/wrapper files pass VSG; all 21 entities/wrappers compile and
link with GHDL. Changed Python tests pass flake8 and syntax checks. No simulation
or pytest regression was run: maintainer VHDL approval remains required.

Added checks cover arithmetic and ledger valid stability before cancellation
edges, cancellation of held E2E results, and ledger summary alignment through
allocation, completion and reset. Existing RX queue/counter, PHC increment,
servo arithmetic and coordinator commit/IRQ checks cover the other affected
behavior. Run these after approval, then endpoint integration regressions.
Build checks do not establish behavioral equivalence or FPGA timing.

Remaining immediate lifecycle/capture interfaces require a separate coordinated
protocol redesign if they are to become registered. Preserve the documented
exceptions until their producers and all consumers can change together. See
[current validation](README.md#current-validation) for the broader review gate
and device-mapped timing/resource work.
