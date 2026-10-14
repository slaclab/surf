# PTP design decision history

This record keeps the reasons for major architectural choices and rejected
alternatives. The [architecture](../../../../ethernet/PtpCore/architecture.md)
owns current behavior, [validation milestones](verification.md) own bounded
results, and [acceptance](../acceptance.md) owns unfinished work. Deferred
options are summarized in [design studies](design-studies.md).

## Source provenance

Condensed October 13, 2026 from the records present at SURF
`68e5dbfaab6d3b2cd486fe501211719044c1826d`. All original detail is recoverable
from that commit, under `docs/plans/ethernet-ptp/`:

| Original file | Retained purpose |
| --- | --- |
| `history/review-2026-09-08.md` | Initial failure modes and the resulting capture, numerical and lifecycle choices below. |
| `history/verification.md`, `rtl-review.md` | Decision-changing experiments and source-specific milestones in [verification](verification.md). |
| `lut-optimization.md`, `lut-implementation.md` | Area architecture, rejected optimizations and measurement limits. |
| `autonomous-endpoint.md`, `rtl-readability.md`, `register-map.md` | Current contracts now live with PtpCore; earlier width reasoning is retained below. |
| `history/design-studies.md` | Deferred options and the earlier literature/IP survey. |
| `PtpCoreArchitecture.svg` | Superseded composition drawing; the current architecture has the maintained diagram. |

For example, from the SURF root:

```sh
git show 68e5dbfaa:docs/plans/ethernet-ptp/history/review-2026-09-08.md
git show 68e5dbfaa:docs/plans/ethernet-ptp/lut-optimization.md
```

The September review originated at `39604a8aba78163c47d32e9de712f6942a2d1d4c`;
it described a planning baseline before PTP RTL. Its numbered findings, execution
order and open/closed labels are retired. The subsequent conventions reviews
are recoverable through `rtl-review.md` above and `015aa06f3` and earlier.
Temporary logs, per-run shell transcripts, superseded module inventories and
speculative register layouts are not maintained as separate history documents.

## Bind capture to the physical frame

**September review and Phase 0 experiments: selected passive validated RX.**
A header key identifies a protocol exchange, not a physical frame. Real-MAC
experiments reproduced a CRC-bad frame's capture being joined to a valid
same-key duplicate, and old buffered packets being joined to captures from a
new reset session. Aggregate CRC/FIFO-drop indications could not identify all
losses. More key bits or deeper lookup tables would not repair that boundary.

The selected frontend binds capture and bytes before the first lossy queue,
validates framing/FCS itself, then publishes one atomic record. This duplicates
validation but preserves the existing MAC interface and confines the new logic
to PtpCore. Carrying metadata through every MAC importer/filter/FIFO/reset was
a viable alternative, with a wider integration and maintenance cost. See the
[counterexamples and replacement proof](verification.md#capture-boundary-experiments).

The same review corrected two conventions: wire EtherType `88 F7` maps to the
MAC bypass literal `x"F788"`, and the timestamp plane is the first destination-MAC
octet after SFD. Independent wire oracles are necessary because an endpoint
loopback can conceal the same byte-order or timestamp-plane error at both ends.

## Separate numerical time from age and physical frequency

**Initial numerical/lifecycle review: selected raw ticks, generations and
rate-corrected E2E.** Stepping the PHC must not move watchdog deadlines or allow
old measurements to command another step. Captures and work therefore carry
generations, while ages use unsteered ticks. Capture-specific increments retain
the calibration units even when RX and TX straddle a rate command.

The equal-rate four-timestamp equation can bias mean delay by approximately
half the oscillator error accumulated between Sync RX and Delay_Req TX:
100 ppm over 10 ms gives 500 ns. A short link can then appear to have negative
delay. Requiring valid delay before estimating rate would prevent acquisition.
The selected estimator derives corrected master elapsed time over raw local
ticks independently of PHC validity/steering; E2E uses that qualified ratio.

Numerical PHC synchronization does not discipline a physical application clock.
Physical cleanup, clock-health policy and application epoch transfer remain
separate [integration requirements](../../../../ethernet/PtpCore/physical-clock.md).

## Retain unresolved TX fate across logical restart

**Initial MAC lifecycle review: selected a persistent keyed ledger.** Pause,
arbitration and MAC queues can retain a Delay_Req after protocol timeout or
reconfiguration. Canceling the logical exchange cannot withdraw an accepted AXI
frame or establish that it disappeared from the wire path.

Reserve the key before presenting TX, drain offered beats, and retain unknown
physical fate until confirmed MAC reset. Known completions retain a finite
network-lifetime quarantine; duplicates renew it. Response and wire completion
may arrive in either order. Exhausted unresolved slots intentionally stop new
requests rather than reuse an ambiguous key. This protects the declared lifetime
bound, not arbitrarily delayed/replayed traffic. The real paused-MAC experiment
made this distinction observable; the [ledger contract](../../../../ethernet/PtpCore/architecture.md#tx-ledger-storage)
defines current behavior.

## Keep ownership local and publish at explicit edges

**Register and registered-boundary redesigns: selected local banks with common
coordination.** A central bank of every core's wide configuration/diagnostics
obscured ownership and duplicated state. PHC, protocol and servo own their banks;
`PtpEndpointControl` exchanges narrow validation/status and broadcasts common
commit/snapshot controls. Manual operands and command arbitration stay with PHC.

Frozen candidates prevent shadow writes from changing an accepted transaction.
Pre-edge snapshot capture and common publication preserve a coherent cohort;
AXI-only reset cancels responses without undoing accepted operations. Registered
payload/valid/lifecycle boundaries make event order explicit. Reverse-ready and
FIFO acknowledgement retain documented combinational exceptions where registering
them would require another capacity reservation. Cancellation vetoes pending work
at a defined edge; it cannot undo an already committed command or consumed sample.
The [interface guide](../../../../ethernet/PtpCore/interfaces.md) replaces the
old review-specific exceptions and stage-by-stage refactoring instructions.

## Bound protocol scope without hiding restrictions

**Implemented endpoint policy:** fixed-source Layer-2 E2E, autonomous control,
and one-/two-step reception selected per Sync. Both modes use the same capture,
rate/history and E2E path. Conservative collision retirement prevents an
ambiguous live association from completing twice; it is implementation policy,
not a claim that the standard mandates those exact collision rules.

The October 9 standards audit corrected minor-version/control/reserved-flag/TLV
handling and Delay_Req control encoding, then added explicit correction-overflow
retirement. Passing these cases did not establish full profile conformance.
Default multicast request distribution and domain restrictions remain tracked in
[specification coverage](../../../../tests/ethernet/PtpCore/specification-coverage.md).
BMCA, VLAN/UDP, Pdelay, one-step transmit and application scheduling were not made
prerequisites for the first endpoint.

## Share computation and word storage, preserve real-time capture

**October 12–13 redesign, connected at `52dfa266f`: selected one RTL word
processor per endpoint.** Earlier private arithmetic engines, wide operand/result
copies, repeated timestamp conversion and wide shallow tables still consumed
substantial area after local sharing. Sharing only multipliers would retain much
of that mux and staging cost.

The selected design moves working/configuration/snapshot payloads into narrow
addressed RAM and chains full-precision operations in persistent workspaces.
Ownership flags and necessary public/capture records remain registered.
Deeper stores subsequently select block RAM; small banks retain distributed RAM.
A general-purpose soft CPU was not justified: it would add boot/program and
worst-case execution obligations without a demonstrated advantage.

PHC counting, PPS and physical capture remain dedicated. Sharing their
preparation arithmetic costs bounded service latency, not a changed timestamp
plane. Owner-local cancellation and held responses prevent one stalled consumer
from blocking all work; waiting for PHC ACK holds no compute slot. The derived
70,347,776-tick association floor replaces the unexplained 2,048-tick floor.
The 10 Hz sustained Sync envelope, initially encoded at 8 Hz, is a deployment
assumption rather than a new packet-rejection rule.

Protocol pair/history scans later share a separate word ALU to keep overlapping
row checks bounded without adding compute jobs. Ledger live expiry arithmetic
stays local because its observation edge matters. Halving LUT use was motivation,
not an acceptance threshold; whole-lane accounting includes arbitration, RAM,
MAC and retained boundary staging. See [measured milestones](verification.md#area-and-timing-evidence).

## Preserve numerical semantics before narrowing hardware

**Width and divide audits:** optimize from admitted ranges while retaining public
precision, rounding points and intermediate overflow rejection. The earlier
private-engine register counts are obsolete after migration to signed128 RAM
slots, but these range arguments remain useful:

| Quantity | Retained reasoning |
| --- | --- |
| Clamped Q16 rate | `200000 * 2^16 < 2^34`: signed35 suffices; adding two such terms can require signed36 before clamping. The physical/control rationale for the cap remains open. |
| Offset/gain | Signed64 Q16 offset times unsigned32 Q2.30 gain fits signed96. |
| Elapsed interval | Accepted ages are below `2^62` ticks; the generic nominal increment bounds the Q32-second interval below `2^94`, requiring signed95. |
| Integral update | The pre-shift product can overflow signed128 and must be rejected before the 62-bit rounded shift. After that shift, correction plus clamped frequency fits signed67. Earlier rounding would change behavior. |
| Rate conversion | Signed35 rate times nominal increment fits signed97 across supported positive clock generics; at 125 MHz the exact `2^35` increment permits signed70. |
| Epoch and phase | Full seconds48 epochs need about 95 signed Q16 bits; public manual-phase operands remain signed128 with quotient-fit checks. |
| E2E/rate | Tick-span, ratio and calibration products have independent checked bounds; a small final delay does not justify narrowing intermediate epoch differences. |

Removing or bypassing one divide does not remove shared divider hardware while
other clients still use it. Exact constant conversion needs corrected quotient,
remainder and rounding proofs; extra detection/mux/shift paths can cost more area
than they save. The pre-shared servo's bounded-divisor increment was an interim
optimization, not the current production architecture. Feedback estimation and
floating-point servo arithmetic remain [deferred](design-studies.md#arithmetic-alternatives).

## Measure timing and mux cost before choosing operators

**October 13 timing/area follow-ups:** native inferred add/subtract was retained
after matched KU040 experiments favored it over handwritten carry-select and
carry-save variants; DSP variants reduced LUTs but lengthened those critical
operators. Streaming TLVs use payload-run skipping and parallel fixed-lane header
checks instead of a serial variable-byte chain, preserving admission edges.

The selected RX store uses 65 useful bytes in a sparse 70-byte lane-preserving
layout. Removing an eight-byte gap avoids dynamic lane shuffling without growing
RAM depth; the 78-byte prototype needed extra decode groups and grew memory at
some queue depths. TX keeps only its 13-byte key and capture with a fixed-body
observer. The TX-only control was essential: unchanged hierarchies also moved
under synthesis, so the first whole-design comparison misattributed RX cost.

In `016771843`, compute memory eligibility moved to constant owner indices before
grant rotation. Netlist inspection located the cost in nested owner/address
selection, not output registration or owner priority. `ArbiterPkg` would not
remove upstream eligibility muxes, and its selection update would need adaptation
to preserve cursor advancement only on a taken grant under the memory/job interlock.

## Treat capacity and TLV removal as deployment restrictions

**October 13, `016771843`: expose frame capacity; retain TLVs by default.**
`MAX_FRAME_G` had not reached both observers through the composition. Exposing
it permits narrower parser counters. The KCU105 study selected 128 bytes; the
82-byte minimum offered less headroom and worse measured area. Mapping was not
monotonic with counter width, so selection follows measured cost and needed traffic.

`TLV_EN_G=false` removes suffix walking but rejects extended messages rather than
skipping their TLVs. The measured LUT saving did not justify selecting it for
KCU105: TLVs on Sync/Follow_Up/Delay_Resp would lose measurements, while rejected
Announce affects metadata. Defaults remain 1518 bytes and TLVs enabled. Neither
structural skipping nor the restricted mode implements TLV semantics or White
Rabbit. [Capacity evidence](verification.md#capacity-and-arbiter-follow-up) is
synthesis-only for that source; [current contracts](../../../../ethernet/PtpCore/architecture.md#frame-capacity-and-tlvs)
own the integration rules.

The shared MAC checksum-offload experiment was also deferred and reverted.
Keep Ethernet changes separate unless measured benefits justify their wider
compatibility scope; the independent checksum/EOFE correctness finding remains
in [acceptance](../acceptance.md#outstanding-acceptance).
