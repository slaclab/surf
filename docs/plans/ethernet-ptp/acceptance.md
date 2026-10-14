# PTP acceptance and open decisions

This is the sole active acceptance backlog. The
[workstream](README.md#current-validation) summarizes source-specific results;
[validation milestones](history/verification.md) record source, scope and limits;
the [provenance index](history/decisions.md#source-provenance) locates full original
reports in Git. This list is not an instruction to rerun
every case after each edit. Behavioral verification has been authorized since
October 9, 2026; use the [focused selection policy](../../../tests/ethernet/PtpCore/README.md#selecting-tests).

## Next acceptance work

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
