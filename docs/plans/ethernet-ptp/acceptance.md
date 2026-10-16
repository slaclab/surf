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

The October 15 follow-up completed all eight endpoint/real-MAC mode/PHY
configurations on the repaired source with shortened functional test settings.
Remaining work:

1. Review the constraint, DRC and CDC findings from the matched October 15
   SFP-only builds. The repaired source routes at +0.133 ns setup WNS; this
   does not qualify copper, physical CDC or hardware accuracy. See the
   [source-specific evidence](history/arithmetic.md#october-15-matched-production-comparison).
2. Complete the [normative audit](../../../tests/ethernet/PtpCore/specification-coverage.md#remaining-normative-work):
   default multicast request distribution, configured
   port/profile behavior, TLV semantics and 2008/2019 compatibility boundaries.
3. Qualify the shared-service envelope and actuator cap, then establish external
   master, calibration, settling/error and holdover acceptance at a named plane.
4. Keep MAC checksum/EOFE correctness separate from PTP area work. Physical-clock
   integration and additional protocol modes remain future scope.

## October 15 test-suite review

Reviewed production/test sources at `ed7d30cbe1e203618835ae94763dffcc0e7bc43d`
against the supplied IEEE 1588-2019 text and the
[specification matrix](../../../tests/ethernet/PtpCore/specification-coverage.md).
The suite is strongest in independent arithmetic, frame/capture ownership,
pair/history/ledger lifecycle, malformed-input recovery and registered stalls.
`PtpSyncPair`, `PtpSyncHistory`, `PtpTableScan` and the filter/PI children are
exercised through production parents; lack of a separately named leaf fixture
does not mean those modules are untested.

Inventory: **211 pytest cases in 30 test files**, comprising **114 simulation
configurations and 97 pure-model/static cases**. One simulation configuration
can run several cocotb scenarios. These counts are not RTL coverage or a
conformance percentage. CI's `pytest --cov` measures Python coverage; this review
did not produce RTL branch/FSM coverage or an exhaustive normative denominator.

The following findings extend the existing acceptance items, without closing
them or authorizing implementation of additional protocol modes:

| Priority / gap | Evidence and next acceptance |
| --- | --- |
| High: current-source integration | The latest recorded port-record migration has 59 focused passing configurations but excludes closed-loop endpoint/real-MAC tests. Revalidate the four endpoint and four real-MAC configurations on the selected final source, preserving both receive modes and PHYs. Earlier connected-design results do not establish this. |
| High: MAC dependency missing from selective CI | `python -m tests.common --changed-files-override ethernet/EthMacCore/rtl/EthMacTop.vhd` selected EthMacCore, IpV4Engine, RoCEv2 and UdpEngine, omitting PtpCore. Add the PTP consumer to `_ETHERNET_SOURCE_DEPENDENTS` in `tests/common/path_selector.py` and protect that selection with a selector test. Also review shared test-helper dependencies. Full integration runs remain separate protection. |
| High: normative contract and scheduler | Apply the profile/conformance gate in 20.2 and resolve the existing scheduler/domain departures. `test_ptp_intervals.py` exhausts Announce receipt encodings at 125 MHz; it does not test Delay_Req distribution. Add deterministic distribution/granularity and accepted-response interval-update checks, with separate physical-transmission timing under queueing. Existing rejection tests cover some interval-poisoning cases. |
| Medium: closed-loop disturbance and asymmetry | `test_ptp_endpoint.py` fixes a symmetric 100 ns path and ties oscillator sign and phase-step policy to PHY choice. PDV/operating-envelope sweeps in `test_ptp_endpoint_reference.py` exercise Python models. Add production rate/servo and selected endpoint cases for nonzero signed `DelayAsymmetry`, path variation/steps, oscillator drift, loss bursts and independent phase/holdover-error bounds. The real-MAC lifecycle fixture checks recovery, not a long accuracy/lock trajectory. |
| Medium: connected service and deployment envelope | Leaf contention and minimum-gap RX checks do not close the full endpoint queue/service bound. Exercise nominal 8/10 Hz and bounded bursts with continuing traffic, stalls and expiry; observe latency, occupancy and recovery. Add `GigEthPtp`/family composition management/reset cases, including stopped-clock recovery. The existing endpoint wrapper stops at GMII/XGMII and uses one management/endpoint clock; it does not instantiate the family compositions. See the existing service and PHY acceptance below. |
| Medium: register schema blind spot | An in-memory mutation of `_PtpPhc.py` changing `Seconds.bitSize` from 48 to 32 still passed `test_local_register_schema('PtpPhc', 'PtpPhc')`. The check compares field starts/access modes and uses widths only for overlap/aperture checks; it does not compare hardware width or signedness. Extend the independent schema to those properties and command semantics; keep live PyRogue transport acceptance separate. No source was mutated on disk. |

Additional parameter holes include the receipt-interval fixture's single clock,
the untested ledger upper-depth assertion boundaries, and composition-level
reset/frame-capacity/TLV choices. Add cases by supported deployment and risk;
an exhaustive Cartesian product is not required. Map Announce time properties,
assigned flags and recognized optional TLVs to the selected profile; do not
mistake metadata retention or a local rejection policy for normative semantics.
External-master interoperability and connector-plane calibration remain open.

Checks actually run for this review: Python 3.12.7/cocotb 2.1.0 preflight,
211-case collection, and **11 passing** tests from `test_ptp_wire_vectors.py`
and `test_ptp_register_map.py` (0.03 s), plus the selector and in-memory mutation
probes above. No RTL simulation, vendor build, external-master or hardware run
was performed. Standards comparison remains scoped to the supplied base 2019
edition with partial 2008 compatibility evidence; amendments/corrigenda and a
complete independent 2008 audit remain unreviewed.

### Review follow-up

The maintainer authorized the test-suite follow-up and requested retaining the
scheduler with acceptance tests. The subsequent working direction is to retain
it long term for controlled deployments and document the departure, rather than
create a custom profile or require replacement solely to close this clause.
Qualify intended masters, aggregate load with correlated/identical seeds, and
timing performance under disturbances. Reconsider the choice if deployment or
conformance requirements demand it. Profile selection and configured-source
applicability remain unresolved; do not claim 17.6/20.2 conformance through this
work or treat documentation as a waiver of a normative requirement.

- Selective CI now includes PtpCore for EthMacCore RTL and the shared MAC test
  helper. Selector regressions protect both dependencies.
- All four endpoint and four real-MAC mode/PHY configurations pass. The
  fixtures retain continuous physical clocks and independent phase/delay oracles
  while replacing inherited long waits with explicit cadence, short holdover
  settings and observed MAC/ledger completion. Their cycle costs fall about
  95–97% below the old fixed waits alone; these remain functional integration
  tests, not default-interval settling or hardware qualification.
- Register checks now compare exact field widths, signedness, access and
  touch-one commands against an independent documented ABI. Six mutation tests
  protect the checks themselves; live PyRogue transport remains separate.
- Domain candidate validation now rejects 128–255 for non-isolated sdoId=000.
  The 0/127/128/255 test failed before the guard and passes afterward, along
  with both register-base configurations. Valid active traffic survives an
  invalid candidate.
- Scheduler interval policy passes; the default multicast distribution check
  is a strict expected failure. The three-point implementation remains unchanged.
  Physical transmission spacing under MAC queueing/pause remains unqualified.
- Production disturbance tests exercise both Sync modes and oscillator signs,
  path variation/steps, drift, loss and ratio freshness. Servo tests exercise
  signed fractional delay asymmetry. These tests do not establish continuous
  closed-loop disturbance/holdover error bounds, a deployment envelope or
  hardware accuracy; retain those obligations below.

Source-specific execution results are recorded in the
[verification history](history/verification.md). Historical review findings
above describe the starting source, not the follow-up's final status.

## Review response and simplification plan

Opened October 14, 2026, from the supplied review of SURF `4d3439185`.
The fixed-function replacement is implemented through `44c85ff35`. The
[decision record](history/decisions.md#fixed-function-arithmetic-architecture)
explains the choice; [current ownership](../../../ethernet/PtpCore/architecture.md#compute-boundary-review)
and [arithmetic contracts](../../../ethernet/PtpCore/interfaces.md#arithmetic-primitive-contracts)
replace the completed execution checklist. Measured production area increased;
reviewability, numerical behavior and lifecycle correctness remain acceptance
criteria alongside resources and timing.

Keep capture bound to its frame, rate estimation based on unsteered ticks, PHC
generation separate from RX epoch, and TX keys retained until physical fate is
resolved. RX overflow policy and the integration/qualification items below remain
open; completing the arithmetic migration does not close them.

1. **Shared compute boundary: implemented.** Local named state replaces addressed
   arithmetic workspaces and descriptors. PHC/servo share SECOND; rate/E2E share
   a positive-divisor divider. Native local arithmetic, exact converters and
   selected product pipelines replace the general compute engine. Prototype
   and matched production evidence are retained in [arithmetic history](history/arithmetic.md).

2. **Auditable servo math: implemented, functional integration checked.** Filter and
   PI are separate children; candidate state commits only on PHC ACK. Production
   tests retain rational PI, median, overflow, held-result and cancellation checks.
   All eight endpoint/real-MAC configurations pass in the October 15 follow-up;
   service-envelope and hardware qualification remain separate.

3. **Qualify service demand and association limits.** Use the implemented fixed-function
   architecture and identify the tested source. Measure accepted-frame-to-result latency, queue
   occupancy, expiry, overflow and recovery under nominal 8/10 Hz Sync,
   bounded bursts and continuing competing traffic. Exercise reachable owner
   combinations; manual PHC steering and automatic servo operation are not
   freely concurrent. Extend endpoint tests beyond isolated compute arbitration.
   Keep analytical ceilings, observed maxima and hardware results distinct.
   Re-derive the association floor for changed scheduling/storage; do not lower
   it merely because measured cases are faster. **Done when:** supported traffic
   and stall assumptions have explicit bounds and executable checks at both
   endpoint clock rates. Retain this evidence with the selected architecture.

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

The October 14–15 prototype sequence is retired after production adoption.
Serial constant conversion, shared SECOND, shared variable division, reused PI
limb multiplication, the E2E product tree and local algorithm state are implemented.
The obsolete compute engine/workspaces and experiment-only harnesses are removed;
production arithmetic and lifecycle regressions remain. See the
[decision and recovery record](history/decisions.md#source-and-experiment-retirement).
No further broad prototype campaign is required.

Remaining arithmetic integration acceptance:

The repaired endpoint and real-MAC lifecycle checks now pass in both receive
modes and PHY fixtures. The [follow-up evidence](history/verification.md#october-15-test-suite-follow-up)
supersedes earlier incomplete integration runs without turning those runs into
passes. The shorter settings preserve functional assertions, not default-interval
settling claims.

1. Reconcile queue, history, filter, configuration, publication and command costs
   with a complete service proof and contention/expiry tests at both clocks.
   Keep **70,347,776 ticks** until that proof justifies a separate change;
   primitive or connected-chain timings alone do not justify lowering it.
2. Review matched production routing's constraint, DRC and CDC findings. Preserve
   the measured area increase and source/configuration limits when assessing the
   implementation; timing closure alone does not establish hardware acceptance.
3. Keep software/register behavior consistent with the implemented four-word
   manual PHASE guard and late epoch fault. Focused schema checks passed;
   retain command-lifecycle coverage through endpoint integration.

Review items 4–7 and normative, external-master and hardware obligations remain
independent unfinished work. This is the sole active acceptance backlog.

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
