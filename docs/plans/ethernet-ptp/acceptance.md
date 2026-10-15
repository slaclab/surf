# PTP acceptance and open decisions

This is the sole active acceptance backlog. The
[workstream](README.md#current-validation) summarizes source-specific results;
[validation milestones](history/verification.md) record source, scope and limits;
the [provenance index](history/decisions.md#source-provenance) locates full original
reports in Git. This list is not an instruction to rerun
every case after each edit. Behavioral verification has been authorized since
October 9, 2026; use the [focused selection policy](../../../tests/ethernet/PtpCore/README.md#selecting-tests).

## Next acceptance work

Development order is tracked in the [review response plan](#review-response-and-simplification-plan).
The following qualification obligations remain open across that work.

1. Validate final endpoint and real-MAC lifecycle integration after the latest
   arbiter/capacity/TLV changes (`016771843`); the 171-case connected-design run
   predates those changes. Preserve both receive modes and both PHY fixtures.
2. Obtain a routed build of that combined source in the consuming project.
   The earlier +0.247 ns SFP-only result does not qualify later source, copper,
   constraints, physical CDC or hardware accuracy.
3. Complete the [normative audit](../../../tests/ethernet/PtpCore/specification-coverage.md#remaining-normative-work):
   default multicast request distribution, sdoId/domain restrictions, configured
   port/profile behavior, TLV semantics and 2008/2019 compatibility boundaries.
4. Qualify the shared-service envelope and actuator cap, then establish external
   master, calibration, settling/error and holdover acceptance at a named plane.
5. Keep MAC checksum/EOFE correctness separate from PTP area work. Physical-clock
   integration and additional protocol modes remain future scope.

## Review response and simplification plan

Opened October 14, 2026, from the supplied code review and maintainer feedback.
Starting source: SURF `4d3439185`. Item 1's source trace and alternative-interface
sketch are complete in the [compute boundary review](../../../ethernet/PtpCore/architecture.md#compute-boundary-review).
The follow-up [math inventory](../../../ethernet/PtpCore/architecture.md#math-inventory-by-module)
itemizes operations, constant versus variable divides and DSP candidates.
The consuming project's October 14 arithmetic experiment now supplies exact
constant-conversion proofs, per-site widths and matched isolated RTL measurements;
see its `firmware/benchmarks/ptp-constant-divide/README.md` and `specification.md`.
The selected prototype boundary uses local fixed-function arithmetic, a shared
SECOND converter and a shared positive-divisor restoring divider. Connected
servo/PHC and endpoint validation, final area/timing choice and items 2--8 remain
pending. Isolated fixture results do not qualify production RTL. The goal is
an understandable autonomous endpoint with acceptable resource use and bounded service, including reconsideration of the
centralized compute architecture. Saving LUTs does not by itself justify the
resulting sequencing, workspace and cancellation complexity.

Keep capture bound to its frame, rate estimation based on unsteered ticks, PHC
generation separate from RX epoch, and TX keys retained until physical fate is
resolved. Preserve numerical precision, rounding/overflow behavior and public
interfaces unless a specific change is explicitly justified. The arithmetic
prototype direction is selected; production adoption and RX overflow policy
remain open.

1. **Reassess the shared compute boundary first.** Trace one rate, E2E, servo
   and manual-PHC transaction through `PtpEndpoint`, `PtpProtocolEngine`,
   `PtpE2e`, `PtpServo`, `PtpPhc` and `PtpCompute`. Identify complexity caused
   by word storage, operand movement, arbitration and cancellation separately
   from the control algorithm itself. Use the math inventory to remove
   unnecessary calculations, specialize constant divisions and derive operand
   widths before selecting a general compute interface. Prioritize DSP-backed
   products and suitable registered add/subtract stages, measuring mapped
   resources and timing. Preserve intermediate rounding and overflow rejection.
   Compare the current service with
   operation-level sharing (local state/simple arithmetic, shared expensive
   operations) and dedicated arithmetic per functional block. Use the
   [earlier studies](history/design-studies.md) and measured area evidence as
   inputs, not as a requirement to retain the current design. Produce a concrete
   interface/ownership sketch, identify the smallest representative prototype,
   and select focused behavioral and matched resource/timing comparisons.
   Record acceptable tradeoffs before choosing a replacement; state counts or
   source line counts alone are insufficient. **Done when:** the proposed
   boundary and its evidence requirements are reviewable, followed by a
   measured choice before broad migration.

2. **Make servo control math auditable.** Map the PI/bootstrap/phase equations,
   units, rounding, clamps and anti-windup rules to the current states and
   workspace values. Separate median/filter responsibility from PI and PHC
   command sequencing where it yields a clear interface, using the compute
   boundary selected in item 1. Keep candidate-versus-committed frequency,
   acknowledgement, cancellation, expiry and snapshot ownership explicit.
   Use the independent rational PI oracle and median tests; extend focused
   boundary coverage where the refactor changes ownership. **Done when:** a
   reviewer can follow each equation and lifecycle without reconstructing a
   90-state program, with numerical and cancellation behavior checked.

3. **Qualify service demand and association limits.** Establish a current-source
   baseline before changing compute, then repeat the relevant cases on the
   chosen implementation. Measure accepted-frame-to-result latency, queue
   occupancy, expiry, overflow and recovery under nominal 8/10 Hz Sync,
   bounded bursts and continuing competing traffic. Exercise reachable owner
   combinations; manual PHC steering and automatic servo operation are not
   freely concurrent. Extend endpoint tests beyond isolated compute arbitration.
   Keep analytical ceilings, observed maxima and hardware results distinct.
   Re-derive the association floor for changed scheduling/storage; do not lower
   it merely because measured cases are faster. **Done when:** supported traffic
   and stall assumptions have explicit bounds and executable checks at both
   endpoint clock rates. This baseline supports item 1's architecture decision.

4. **Decide RX overload behavior.** Compare current whole-cohort flush with
   dropping only the arriving complete record. Check frame-bank ownership,
   stalled-head stability, simultaneous consume/completion, partial Sync pairs,
   replay/expiry handling and downstream cancellation. Dropping an advertised
   head is a different policy and must not violate ready/valid stability.
   Use overload and recovery cases from item 3 to compare lost useful work and
   reacquisition. **Done when:** the owning architecture/interface guides explain
   the selected policy and tests exercise its detection/publication edges.

5. **Resolve composition options and reset guarantees.** Inventory leaf versus
   composition support for RX/ledger depth, `MAX_FRAME_G`, `TLV_EN_G` and
   `RST_ASYNC_G`. Expose useful deployment settings consistently or document
   fixed values; deeper queues require revisiting item 3's bound. Trace
   stopped-clock reset through KCU105 clock control, domain reset stretching,
   PHY/MAC and endpoint state, including outputs observed by running domains.
   Test stop/restart, reset held across clock resumption and PHC invalidation;
   retain hardware qualification as a separate gate. The existing asynchronous
   reset generator plus synchronous endpoint reset is not itself a demonstrated
   defect. **Done when:** supported configurations and reset obligations are
   explicit and focused composition tests cover them.

6. **Remove obsolete RX mode and reduce validator drift.** Check callers before
   removing `PtpRxFrontend.TX_OBSERVE_G`; retain TX observation in the adapter
   and dedicated `PtpDelayReqObserver`. Identify common pure framing/length/TLV
   validation that can be shared without merging RX/TX storage or flush policy.
   Use common malformed-frame vectors and focused RX/TX tests to protect both
   paths. **Done when:** the unreachable RX mode is removed and shared rules
   have one implementation where practical, with intentional differences clear.

7. **Finish localized maintenance.** Repair `PtpPkg`'s dead guide references;
   name PHC derived word-index windows without changing addresses or strobes.
   Prefer `process(all)` in touched combinational processes and check explicit
   lists for omissions; avoid an unrelated repository-wide formatting pass.
   Decide whether `PtpMath` remains a supported reusable leaf or should be
   retired after checking users; absence from this endpoint alone is not enough.
   **Done when:** references resolve, register-map checks preserve the ABI, and
   each retained helper/mode has a stated purpose.

8. **Integrate and close the affected acceptance items.** After focused checks,
   validate the changed endpoint/MAC interactions in both receive modes and PHY
   fixtures. Obtain matched synthesis/routed evidence for the selected source
   and configuration before claiming area or timing benefits. Update the
   architecture, interfaces and this backlog with actual outcomes; preserve
   outstanding normative, external-master and hardware qualification work.
   Follow the test-selection policy rather than replaying the full suite after
   every edit. **Done when:** the implemented changes and their evidence agree,
   with remaining limits explicitly recorded.

### Arithmetic prototype sequence

The consuming project's October 14 isolated measurements select these starting
points: serial constant converters (power-of-two specialization at 125 MHz),
one shared SECOND128 service for PHC/servo, a four-clock local E2E DSP product pipeline, a reused PI limb multiplier,
and one shared signed128-by-
unsigned80 quotient-only restoring divider for E2E/rate. Keep simple arithmetic
local, and retain native 156.25 MHz clocking. The consuming-project exploration now includes matched servo and connected
client fixtures. Keep this boundary and move toward production integration;
resolve concrete implementation failures without another broad operator study.
Resource/timing evidence still gates adoption, not the decision to stop exploring.

1. **Build the servo forward-update slice.** Use named candidate/committed state,
   frozen configuration and operation-level requests through real PHC rate ACK.
   Reuse the rational PI oracle at both clocks; cover clamps, anti-windup,
   pre-shift signed128 overflow, held commands, cancellation and holdover.
   Evaluate bootstrap only on the nonintegrating branch at the documented
   qualification edge; sweep stale transitions around that edge. Reuse local
   products across PI equations rather than adding a new instruction engine.
   **Initial consuming-project slice complete:** six focused tests pass at
   125/156.25 MHz through the real PHC. It injects known filtered delay and
   validated configuration, uses a local SECOND converter, and leaves median,
   phase acquisition and production interfaces unchanged. Complete matching
   harnesses and shared-service integration remain gates below.
2. **Measure matching harnesses.** Compare the slice with the current
   servo/compute boundary, including identical configuration, publication and
   response storage. Count actual operand muxes and constant converters. Record
   the included filter/configuration/publication boundary explicitly. The
   consuming project has implemented this pair with real PHC and equal dynamic
   configuration/known-filter boundaries. Initial connected PI equations failed
   timing; registered clamp/add/anti-windup stages are the targeted correction.
   Finish existing matched runs and retain their failed-revision evidence. The
   fresh consuming-project SFP-only synthesis baseline is an area reference;
   its unbound PHYs and unconstrained synthesis timing do not qualify a board.
3. **Verify shared ownership and remaining callers.** Add the E2E/rate divider
   owner wrapper and PHC/servo SECOND wrapper with held per-owner responses,
   owner-local cancel and no circular wait on PHC ACK. SECOND's two-owner fixture
   is measured. Shared/manual/servo lifecycle tests, representative E2E/rate
   equations and a connected arithmetic-chain fixture now pass. Actual PHC ticks
   drive expiry and conditional service-bound assertions. Packet/history/median
   admission remains outside that fixture; do not call it endpoint acceptance.
   Retain full128 servo phase; manual PHASE uses checked four-word submission
   with signed96 admission, rejecting high-word mismatch before narrowing.
   Update register map, PyRogue and schema tests together when that behavior is
   implemented; representable late epoch faults remain distinct.
4. **Implement and validate the complete architecture in one pass.** The
   maintainer chose no intermediate approval or commit checkpoints. Convert
   servo filtering/PI/acquisition, E2E/rate and manual PHC preparation together;
   wire both shared services and remove the obsolete production compute
   engine/workspaces. Update affected registers, software, tests and docs in
   the same implementation. Focused checks may run during development; final
   acceptance requires the numerical/lifecycle and endpoint regressions plus
   a matched whole-endpoint synthesis/routing comparison. Reconcile queue,
   history, filter, configuration and command costs with the retained floor;
   keep70,347,776 ticks and defer any reduction. The consuming project's main
   arithmetic design document owns the concrete implementation work list;
   no further prototype campaign or per-client approval gate is required.

The existing review items retain endpoint/MAC, normative, CDC and hardware gates.
Items 5--7 can proceed independently where they do not depend on the arithmetic
choice. Fold completed rationale into owning guides; this remains the sole
active acceptance backlog.

## Outstanding acceptance

- Existing MAC RX IPv4 error handling: a successful IP/transport checksum check
  can overwrite an incoming EOFE. Observed in the default-enabled checksum
  fixture while testing this increment; native-L2 error propagation and the
  experimental disabled-offload path passed. That experiment is now reverted.
  Fix and test combined FCS/checksum failures in a
  separate MAC correctness change; this finding does not authorize a broader
  MAC rewrite as part of PTP area optimization.

The shared-service derivation replaces the former unexplained 2,048-cycle
association floor; see the [current scheduling contract](../../../ethernet/PtpCore/interfaces.md#shared-service-bound).
Document and justify the existing 200,000-ppb actuator cap before treating it
as a qualified hardware bound. The
[endpoint numerical envelope](../../../ethernet/PtpCore/architecture.md#port-policy-and-numerical-envelope)
records their distinct purposes and remaining qualification limits.
This source/design follow-up is independent of simulation results.

With the October 9 authorization, use the [PTP test guide](../../../tests/ethernet/PtpCore/README.md)
and run focused leaf/register tests before port/servo and GMII/XGMII integration:

1. Accepted/rejected PHY/frequency pairs and ledger depths 1, 255 and 256;
   exercise assertion failures rather than treating compilation as coverage.
2. Command acceptance/commit ownership, registered cancel/expiry timing,
   between-edge ready/ack/error/capture-inhibition stability, math/E2E/ledger
   cancellation and result payload alignment.
3. RX queue head stability, empty enqueue/consume/refill and overflow at every
   configured depth. The reference frame/queue oracle remains detection-edge
   based; its scoreboard accounts for registered publication and abort latency.
4. Ledger capacity/response pulse timing, retained response metadata, accepted
   allocation coincident with abort, stalled TX beats, sequence wrap/quarantine
   and restart with unresolved physical fate.
5. Atomic configuration/candidate votes, coherent pre-edge snapshots, issued
   snapshots coincident with invalidation, AXI-only reset recovery and the
   two-hop MAC-change restart observation.
6. Servo status arithmetic, port/servo reset-qualified ready, disabled-servo
   draining, measurement backpressure and deterministic Delay_Req scheduling.
7. Mailbox resets and stopped-peer clocks, then physical endpoint/MAC acquisition,
   holdover, recovery and association on both supported PHYs.

No known-bad comparison was run for the registered-boundary change during the
earlier verification pause. Prepared between-edge assertions target the former
input-dependent controls; queue/metadata cases test the new storage ownership.
Record actual outcomes and source revisions in the linked evidence history.
Device timing, added register/resource cost, physical CDC, calibrated hardware
accuracy, external-master interoperability and live PyRogue transport remain
separate qualification work. Include the one-step and PHY acceptance below;
prepared fixtures are not passing results.

### Fixed-point width acceptance

The October 9 run passed `test_ptp_math.py` and `test_ptp_servo.py` before
starting PHC, E2E, port and endpoint checks. The additional acceptance below
is not all covered by those two passing fixtures.

- Covered by the current and pre-width-change comparison: math vectors distinguish unused shifted-out bits from selected high
  partial products, addition carry from signed-range overflow, both operand
  orders, zero, signed minimum and nonzero wrapped low products. Exact 128-work-
  cycle latency is checked alongside the existing remainder, stall and cancel
  checks. Both implementations passed the same result/error/latency assertions.
- Covered by the current and pre-width-change comparison: servo vectors retain the rational PI oracle and exercise both signs of the
  maximum 200,000-ppb limits, bootstrap subtraction and tracking sums approaching
  +/-400,000 ppb, anti-windup, fractional corrections and holdover. These cases
  would expose narrowing a sum to 35 bits before clamping.
- Extend interval/configuration boundary coverage to the largest accepted
  timeout, both supported endpoint clocks and standalone frequency generics.
  Include integral-product overflow rejection and full-range manual phase
  normalization; the ordinary default-interval cases do not cover those bounds.
- Obtain a Vivado before/after utilization and timing comparison at the same
  target/configuration before claiming LUT/FF savings or deciding whether
  operation-specific widths or DSP implementation are worthwhile.

## One-step receive acceptance

Run focused sample tests, physical port/RX checks, then endpoint and real-MAC
variants under the October 9 authorization, retaining existing two-step coverage.
Summarize consequential results in the validation milestones and retain detailed
run provenance with the evidence artifacts. The
[test guide](../../../tests/ethernet/PtpCore/README.md#autonomous-endpoint-tests)
indexes `test_ptp_port_samples.py`, `test_ptp_port.py`, RX fixtures,
`test_ptp_endpoint.py` and `test_ptp_endpoint_mac.py`; the evidence history records executions at their named revisions. Reconcile each
case with that source before deciding which additional run is needed.

| Case | Required observation |
| --- | --- |
| Valid one-step Sync with no Follow_Up | Completes once; enters the existing rate/history path; repeated valid exchanges enable E2E acquisition and servo operation. |
| Equivalent one-step and two-step exchanges | Equal remote time, capture and net correction produce equal numerical forward/E2E results. Account for different message arrival/completion latency; do not require cycle-identical publication. |
| Correction arithmetic | Positive, negative and fractional Q16 corrections, including crossing a second boundary; sum of two-step corrections equals the one-step correction in paired fixtures. No truncation or double application. |
| Timestamp validation | Nanoseconds 999,999,999 accepted; 1,000,000,000 and larger rejected; exercise nonzero upper seconds bits. Invalid one-step input cannot contaminate an existing association. Two-step Sync body remains non-authoritative. |
| Flags and source policy | Ignore reserved flag bits and controlField; accept either supported Sync mode after masking. Reject unsupported assigned flags, foreign source/domain and unsupported major versions. Accept any minor version with major=2. |
| Association collisions | Follow_Up before/after one-step Sync; duplicate one-step Sync; mixed-mode duplicate sequence; identical/conflicting Follow_Up. Assert counters, no unintended completion and unchanged accepted sample contents. |
| Lifecycle boundaries | Back-to-back mode changes on distinct sequences, 16-bit sequence wrap, stale/replayed messages, expiry, full table and completed-entry replacement. No resurrection or permanent table leak. |
| Stalls and invalidation | Measurement backpressure, rate-engine busy, RX overflow/abort, generation/epoch changes and reset/reconfiguration around admission/completion. Stable registered payloads; cancellation at the documented consumption edge. |
| Physical integration | Full-rate GMII 125 MHz and XGMII 156.25 MHz, including both XGMII start lanes. Bad FCS/truncation never publishes a sample. Preserve timestamp calibration and Delay_Req TX completion behavior. |
| Two-step compatibility | Existing Sync/Follow_Up arrival orders, duplicate policy, correction sum, acquisition, holdover/recovery and MAC-composition behavior remain covered. |

For equivalent-mode fixtures, explicitly split a known total correction between
Sync and Follow_Up in the two-step case. Check against the one-step total and an
independent expected result. Closed-loop fixtures must compare at corresponding
measurement times or use mode-specific timing expectations so that Follow_Up
latency is not mistaken for an arithmetic discrepancy.

One-step source timestamps are built from the scheduled physical edge using
independent simulator time, then checked against the observed edge; no DUT PHC
value generates the source timestamp. Direct port vectors compare Python integer
arithmetic at controlled capture times. Closed-loop modes compare each result
with the same independent path/phase expectation at its own acquisition point,
so Follow_Up latency is not treated as an arithmetic error.

## PHY and hardware acceptance

Exercise common/default and KCU105 address layouts through
the asynchronous management bus; AXI-only, PCS-only and system reset; link loss
with outstanding TX; concurrent application/PTP traffic; and independent endpoint
resets. Cover cable-absent initialization, gigabit-only negotiation, MDIO/PCS
readiness, copper watchdog/finite reset pulses, configuration recovery and PHC
invalidation. For oscillator programming, verify stopped-clock reset assertion
and synchronized/stretched release while other endpoints remain operational.
Controller checks must cover apply-to-restart/identity-restart latency, RX flush
and capture inhibition, IRQ event/W1C priority and bus-reset recovery through the
production controller.

The dedicated-reference GTH checkpoint has been bound in the recorded KCU105
SFP-only build. Qualify each selected PHY/checkpoint separately; review the current
`U_Phy/U_GigEthGthUltraScaleCore` and GTY hierarchy,
imported/external constraints, GT/fabric reference routes, clock continuity,
reset release and physical CDC. RFMC additionally needs verified RTM pins and
clock sources. Measure resources/timing per family and PHY, including capture
normalization, CRC/decode, PHC carry, fixed-point paths and queue storage. The
optional mailbox's historical GHDL RAM-width synthesis failure remains an open
device-synthesis/CDC gate, not a reason to alter shared RAM incidentally.

Freeze a pinned external-master release/commit, L2/E2E profile, source identity,
domain/minor version, multicast behavior and intervals, retaining packet captures
and instrument configuration. Exercise supported receive modes, malformed/profile
traffic, pause/primary contention and compatibility with existing EthMacCore,
IpV4Engine, UdpEngine and RoCEv2 users. Do not infer conformance from synthetic
fixtures or the endpoint's own reported offset.

Define quantitative resource, settling/overshoot, steady/peak error, observation
duration, temperature, reset sample count and holdover duration/error limits.
Measure MAC/PCS-to-connector ingress/egress calibration, cold-start/link-reset
latency modes and phase repeatability independently for each FPGA/GT/IP/rate/reset
combination. Separate fixed, reset-dependent and variable delay, network asymmetry
and packet-delay variation. Record hardware-calibrated versus compile-supported
status per wrapper. Physical clock/output qualification additionally follows the
[clock requirements](../../../ethernet/PtpCore/physical-clock.md#qualification-and-next-steps).
Live PyRogue transport is a separate acceptance item from static map checks.
