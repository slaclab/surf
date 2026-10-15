# Ethernet PTP workstream

The reusable fixed-source Layer-2 E2E TimeReceiver is implemented, with
one-/two-step Sync reception and autonomous numerical PHC/servo control.
Hardware accuracy and standards/profile acceptance remain open. Software
configures and observes the endpoint; it is outside the timing loop.

## Document map

| Question | Owning document |
| --- | --- |
| How does the implemented endpoint work, and why was it designed this way? | [Architecture and design decisions](../../../ethernet/PtpCore/architecture.md) |
| What are the exact ownership, clock-edge, RAM and scheduling contracts? | [Interface and service contracts](../../../ethernet/PtpCore/interfaces.md) |
| What does software configure and observe? | [Register map](../../../ethernet/PtpCore/register-map.md) |
| How do I compose the MAC/PHY and find sources or tests? | [PtpCore integration guide](../../../ethernet/PtpCore/README.md), [test guide](../../../tests/ethernet/PtpCore/README.md) |
| What is still unqualified or undecided? | [Acceptance and open decisions](acceptance.md), [specification coverage](../../../tests/ethernet/PtpCore/specification-coverage.md) |
| What would physical clock control require? | [Physical-clock requirements](../../../ethernet/PtpCore/physical-clock.md); prospective integration, not an implemented actuator |
| Why were alternatives rejected, and what evidence remains? | [Major design decisions and provenance](history/decisions.md), [validation milestones](history/verification.md), [deferred studies](history/design-studies.md) |

## Current validation

The baseline table was reconciled October 13, 2026, at SURF `68e5dbfaa`;
later rows identify their own source and test selection. Results do not
accumulate into qualification of the latest source automatically.

| Source/change | Recorded result | Boundary |
| --- | --- | --- |
| October 9 resumed baseline | 121 distinct cases passed after a fixture-timeout correction. [Evidence](history/verification.md#october-9-baseline) | Earlier source; later specification fixes have separate focused checks. |
| Connected compute/word-storage design, `52dfa266f` | 171 configurations passed across batches, including endpoint and real-MAC lifecycle in both PHYs/receive modes and raw/normalized E2E calibration. [Evidence](history/verification.md#connected-compute-and-subsequent-focused-checks) | Not one uninterrupted run; later optimizations were not part of this selection. |
| Counter/BRAM/interval pass, `0d27ddbba`, and subsequent scan ALU | 20 and 9 focused configurations passed respectively. [Evidence](history/verification.md#connected-compute-and-subsequent-focused-checks) | The milestone summary preserves scope; original patch provenance is recoverable through its Git source index. |
| Arithmetic/timing and RX/TX storage follow-ups | Selected SFP-only KCU105 source routes with WNS +0.247 ns and zero setup/hold/pulse-width failures; final RX leaf and real-MAC RX checks pass. [Evidence](history/verification.md#area-and-timing-evidence) | Final endpoint lifecycle, copper, constraint/CDC review and hardware acceptance remain open. |
| Compute arbiter, frame capacity and optional TLVs, `016771843` | 48 focused configurations pass. Matched synthesis reports -803 LUTs for arbiter indexing and -1,176 for 128-byte capacity. TLV rejection is implemented but not selected. [Evidence](history/verification.md#capacity-and-arbiter-follow-up) | Synthesis has PHY black boxes unbound. Final endpoint/MAC lifecycle and a routed build of the combined source remain outstanding. |
| October 15 servo lifecycle repair over `d4c78ad5b` | All three servo clock cases and the 125 MHz PHC command-lifecycle scenario pass; both edited RTL files pass VSG. [Evidence](history/verification.md#october-15-servo-lifecycle-repair) | Selected endpoint run was interrupted and remains incomplete; no new synthesis, routed timing or hardware qualification. |

Behavioral verification has been authorized since October 9, 2026. Use the
[focused test-selection policy](../../../tests/ethernet/PtpCore/README.md#selecting-tests);
the acceptance backlog does not require a full-suite replay after routine edits.
No new RTL/Python regression is implied by this documentation consolidation.

## PHY composition implementation

UltraScale GTH, UltraScale+ GTY and gigabit-only UltraScale LVDS/Marvell copper
compositions share `GigEthPtp` and the autonomous endpoint. The
[integration guide](../../../ethernet/PtpCore/README.md#1g-phy-compositions) owns
reference selection, address apertures, hierarchy and reset differences.
The dual-mode GTH checkpoint is present and has bound in the recorded KCU105
SFP-only routed build; the former missing-checkpoint task is resolved for that
build. This does not qualify all reference modes, PHY families or boards.

Copper PCS reset clears its PHC/configuration; the externally clocked GTH/GTY
compositions retain PHC time during PCS reset. Stopped-clock recovery requires
invalidation and reacquisition. RFMC board integration remains a consuming-project
scaffold. Pin/clock assumptions, oscillator programming and measurement outputs
belong in project target guides.

## Open decisions and next work

The [acceptance backlog](acceptance.md#next-acceptance-work) owns remaining
integration, normative, timing/CDC, external-master and hardware checks.
The October 14 [review response and simplification plan](acceptance.md#review-response-and-simplification-plan)
sets the development order. The [compute boundary review](../../../ethernet/PtpCore/architecture.md#compute-boundary-review)
now traces all four clients and sketches local algorithm state with shared
multiply/divide requests. The [math inventory](../../../ethernet/PtpCore/architecture.md#math-inventory-by-module)
separates actual operations and constant/variable divisions. The consuming
project's October 14 isolated arithmetic experiment now records width proofs,
exact converters and routed primitive/sharing measurements in
`firmware/benchmarks/ptp-constant-divide/`. The
[prototype sequence](acceptance.md#arithmetic-prototype-sequence) selects local
DSP products, serial constant converters, shared SECOND and a positive-divisor
restoring divider as its starting boundary. The consuming project now has matched legacy/candidate servo harnesses,
shared PHC/servo SECOND ownership, representative E2E/rate clients and a connected
arithmetic-chain fixture using real PHC ticks and ACKs. Initial connected timing
exposed a long rounding/clamp/anti-windup path; the revised servo stages those
equations. Numerical, sharing and actual-age tests pass; final matched physical
comparisons remain distinct from endpoint qualification. The maintainer has
asked to close architectural exploration and move toward integration: retain
local state, specialized arithmetic and the two narrow shared services. Implement
all clients and remove the old compute infrastructure in one pass, without
intermediate approval or commit checkpoints; validate the complete endpoint. No production RTL
or service floor changed. Keep70,347,776 ticks until a complete endpoint proof
and contention/expiry tests justify a separate change.
LUT savings alone do not settle the architecture choice; reviewability,
ownership/cancellation complexity, service latency and timing also matter.
Final endpoint/MAC integration and a matched routed build remain acceptance
requirements for the resulting source.
The 200,000-ppb actuator cap still needs physical/control rationale; the shared
service minimum has a documented derivation but needs deployment qualification.

Further area work is optional and measurement-driven. The PHC compute owner's
oversized loaded-word bookkeeping remains a candidate in the
[latest area record](history/verification.md#capacity-and-arbiter-follow-up).
Halving LUT usage was motivation, not an acceptance threshold. Shared MAC/checksum
changes, feedback estimation, floating-point servo arithmetic, additional protocol
modes and application/physical timing are deferred rather than prerequisites.

## Maintaining this workstream

Keep only status and unfinished acceptance here. Update the owning architecture,
interface or register guide when a task changes enduring behavior or rationale;
do not create another permanent sub-task plan. Preserve unique dated experiments,
source revisions, rejected alternatives and consequential test outcomes in the
three concise history records. Keep detailed transcripts in Git history and
generated logs outside maintained documentation; do not retain a separate review
file for each date or implementation increment.
See the parent [planning guide](../README.md).
