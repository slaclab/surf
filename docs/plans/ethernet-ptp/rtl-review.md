# PTP review and acceptance record

## Status and provenance

The conventions fixes, registered-boundary redesign and conventions follow-up
are implemented. **Behavioral acceptance is still pending maintainer VHDL
approval** under [current validation](README.md#current-validation). Completion
of a source review or compile/link check does not validate the changed timing.

This record consolidates the former `ptp-vhdl-conventions-review`,
`ptp-registered-boundaries` and `ptp-conventions-follow-up` plan directories.
Their full review findings and temporary-log references remain in Git history
at `015aa06f3` and earlier; obsolete source-line inventories and completed task
instructions have been removed from the active plans. The original conventions
review examined `c3170db49d74a16566a3b7a3e2feee12eeb2feee` on 2026-09-17.
The follow-up began at `a48b07ef1b96dee81b66a2a64c463e752173911f` on 2026-09-18.
All three reviews covered 15 RTL/package files and seven simulation wrappers.
The numeric-literal audit reviewed 15 RTL/package files on 2026-09-17 in the
working tree based on `d8f9c5867`, including pending readability edits. Its
cleanup was implemented in 13 files; `PtpMath` and `PtpTxTimestampTap` retained
justified literals. Its completed recommendations are consolidated here and
in the timing guide; the pre-cleanup literal inventory is no longer an active
checklist.

The maintained contracts are authoritative:

- [Endpoint composition and numerical envelope](autonomous-endpoint.md).
- [Registered timing and local implementation decisions](rtl-readability.md).
- [Output ownership and remaining exceptions](rtl-readability.md#output-ownership-and-exceptions).
- [Register ABI](register-map.md), [register ownership](register-map.md#register-ownership)
  and [directional interface records](rtl-readability.md#interface-records).
- [SURF VHDL conventions](../../vhdl-conventions.md), including the RTL checklist.

## Implemented decisions

| Area | Decision retained and reason |
| --- | --- |
| PHY/frequency contract (original R1) | `EthMacPtpEndpoint` asserts GMII at 125 MHz or XGMII at 156.25 MHz. Selecting GMII with the default XGMII frequency would advance the numerical clock at the wrong rate, outside the estimator's correction envelope. Standalone arithmetic/PHC tests may use other clocks; the assertion belongs at MAC composition. |
| Ledger depth (R2) | Support depths 1–255. The eight-bit occupancy/unresolved fields cannot represent 256; the upper-bound assertion preserves the diagnostic ABI. The original finding demonstrated a representation problem, not premature key reuse. |
| Arithmetic requests (R3) | PHC and port request-valid registers travel with their operands and derive from resolved next state. E2E follows the same rule. Registering an old-state decode instead would add an unintended issue cycle. |
| Functional boundaries (R4, superseded) | The first review only made immediate decisions publish unconditionally. The later redesign deliberately registered queue heads/events, ledger handshakes, lifecycle, snapshots, command responses and mailbox strobes. Its cycle contracts supersede the earlier instruction to preserve immediate controls. |
| Temporary calculations (R5) | Calculation-only fields moved from `RegType` to bounded process variables assigned before use. Retain real diagnostics, snapshots and transaction state. Source cleanup alone is not evidence of resource reduction. |
| Ready ownership (R6, partly superseded) | Remaining combinational reverse-ready controls resolve through the owning `v` record beside admission. PHC command-ready, ledger allocation-ready and mailbox application-ready became registered capacity promises in the redesign; do not restore the original broad exception. |
| Reset/publication follow-up | Eight processes moved the synchronous reset override and `rin <= v` before output publication: endpoint, PHC, port, coordinator, RX frontend, servo, TX ledger and register wrapper. Registered outputs still use `r`. Port and servo reverse-ready retain their explicit reset/cancellation suppression. |
| Layout and constants | Expanded declarations/initializers, headers and clock grouping; kept public generic order for positional callers. Wrapper-local constants use `_C`, message codes use package constants, timeout factors preserve widths, and unsigned divide-by-two preserves Delay_Req jitter rounding. No new protocol policy or ABI was intended. |
| Numeric definitions and layouts | `PtpPkg` owns shared protocol values, unit scales, format shifts, IRQ positions and body accessors. Local policy/depth constants and private mailbox layout centralize coupled values; commented wire positions remain explicit. Register offsets, provisional identification value, defaults and timing were preserved by this cleanup. See the [maintenance rules](rtl-readability.md#numeric-definitions-and-layouts). |
| Test integration | Removed stale `ROCE_ANALYSIS_SOURCES` imports from five tests; those sources belong to the normal ruckus inventory. This former collection prerequisite is resolved, not remaining work. Wrappers flatten production records and use real cores/bus adapters. |

Physical RX remains non-backpressurable. Logical restart preserves already
offered TX beats and unknown wire ownership. Local AXI banks, frozen candidates
and scalar validation votes retain their owners. Record conversion changed some
internal direct-instantiation interfaces; the subsequent reviews preserved
production entity declarations and the external endpoint/software ABI at their
respective baselines. Do not interpret that as compatibility with every earlier
prototype.

## Historical static evidence

These are recorded results from the September reviews, not fresh runs after
later merges or proof of behavioral equivalence:

- The numeric cleanup recorded VSG passing all 15 RTL/package files
  (689 rules per file) and GHDL 6.0.0 compiling/linking 21 entities/wrappers,
  with the package analyzed as a dependency. Shared-RAM, optional RoCE binding
  and wrapper open-association warnings remained. Diff whitespace passed;
  no simulator executable or pytest regression ran.
- The conventions, registered-boundary and follow-up reviews each recorded a
  final VSG pass for all 22 PTP VHDL files with
  `vsg-linter.yml`; GHDL 6.0.0 compiled/linked all 21 entities/wrappers,
  including `EthMacPtpEndpoint`. No built simulator executable was run.
- The registered-boundary pass checked ten edited Python files with flake8
  and AST parsing without imports/execution. It also checked declarations,
  alignment, links and whitespace. New boundary tests were prepared, not run.
- The final conventions follow-up compared all 21 entity declarations ignoring
  comments/whitespace. Other token changes were the eight reset/publication
  relocations, named constant substitutions and equivalent half-interval
  expressions. This was a scope check, not a behavioral test.
- Historical compile warnings involved dependency shared variables, elaboration
  and name hiding, the unchanged servo `maximum` parameter and a fixture's
  partial `open` association. They were not resolved by these reviews.
- The follow-up's fresh ruckus import was blocked by sandbox Tcl subprocess
  file creation and an attempted Git index refresh. It reused a source inventory
  from the earlier import, reading current source into a fresh GHDL library;
  it did not reuse compiled objects. Temporary logs/build trees are not durable
  dependencies for future verification.

Earlier behavioral milestones remain in the
[endpoint evidence](history/verification.md#autonomous-endpoint-milestone),
[register refactor evidence](history/verification.md#register-ownership-milestone)
and [RX proof](history/verification.md#rx-rtl-proof). They predate the final interface/control-flow
changes and cannot close the acceptance items below.

## One-step receive static evidence

Implemented October 6, 2026 in the tree based on
`fc75fe24ab1dfb3da77164843c71783ab1aa3ba8`. The original planning baseline was
`aa6b2c4084aafbea77761a5ff96b9605fbb952f9`; their comparison found no intervening
PTP RTL/fixture changes. The RTL was then named `PtpPort`; current naming is
`PtpProtocolEngine`, with the `PtpPortWrapper` fixture retained.

The following records the implementation-time checks, not new checks of today’s
source. Source review covered both arrival orders/collision directions, full-table
abort priority, accepted-sample immutability, signed128 correction assembly,
registered outputs, no new CDC and unchanged reset/AXI-only semantics. The
private `twoStep`/`syncSeen` state feeds the existing sample path; no exported
record, entity interface, register, default or counter definition changed.
The frontend already retained the required body/flags/correction. The package
later named `PTP_ONE_STEP_FLAGS_C` beside `PTP_TWO_STEP_FLAGS_C`; explicit
flag/control/timestamp rejection branches kept the same admission/counting rules.
Those readability follow-ups passed package/port VSG and port compile/link.

- VSG 3.35.0 with `vsg-linter.yml`: zero violations in `PtpPort.vhd` and the new
  `PtpPortWrapper.vhd`. Python AST parsing and flake8 pass for the eight changed/
  added Python fixture files. Static compliance screening against that baseline’s
  fixtures reported no new findings; no tests were imported or collected.
- Fresh ruckus source import passed with the checked-out sibling ruckus. Initial
  sandbox attempts failed in Tcl subprocess temporary-file creation; the same
  isolated import succeeded with sandbox escalation. The initial recipe's
  `MODULES="$PWD"` also needed adjustment for this workspace's sibling layout.
  `GIT_STATUS=skip-index-refresh` suppressed Make's incidental Git index refresh.
- GHDL 6.0.0 (LLVM 22.1.0) import and compile/link passed for `PtpPort`,
  `PtpPortWrapper`, `PtpEndpoint`, `PtpEndpointLoopbackWrapper`,
  `PtpRxFrontendWrapper`, and `EthMacPtpEndpoint`, using
  `--std=08 --ieee=synopsys -frelaxed-rules -fexplicit`. The current
  `ETHMAC_RTL_SOURCES` selection supplied MAC RTL plus `DspXor.vhd`; the imported
  `EthMacPkg` was not duplicated. Builds used checked-out sources and a fresh
  temporary library. No executable was run; run-time generics/assertions and
  behavior remain untested. Dependency warnings include shared variables,
  elaboration, port attributes and name hiding; the unchanged servo's
  `maximum` warning remains.
- Production entity declarations and the RTL AXI register calls matched the baseline;
  public package layouts and PyRogue sources are unchanged. Documentation links/
  anchors and diff whitespace were checked.

The recorded tools were GHDL 6.0.0 (LLVM 22.1.0), VSG 3.35.0 and Python 3.13.2;
Python/static tools came from the existing `/Users/bareese/surf/.venv/bin`, not
an environment installed by this task. That path is historical, not a portable
prerequisite. Use the compile/link procedure below and current tool paths.
No known-bad simulation ran under the gate; completion/count assertions are
intended to reject the old exact-two-step-only admission policy. Remaining risks
include fixture timing/expectations, mixed-mode collisions, bounded retained-key
reuse and registered cancellation/publication. Earlier endpoint passes do not
validate these changes.

## Controller and protocol naming evidence

The October 8, 2026 controller consolidation preserves global coordination and
the prior apply-to-restart and event-to-IRQ register hops; its contracts belong
in the endpoint/register/timing guides. Recorded checks were:

GHDL 6.0.0 analysis/link passed for the real
controller, endpoint and register fixture, including endpoint compositions with
the MAC TX format and synchronous active-high/asynchronous active-low resets.
MAC endpoint and loopback analysis uses the real PTP cores and a declaration-only
MAC. Source comparison confirms unchanged AXI/commit/snapshot/IRQ processing
after resolving its event input to the retained register, unchanged prior state
reset values, and the separate port-to-PHC command-abort connection. Changed
Python sources parse; mocked manifest loading selects the renamed controller;
local guide links and diff whitespace pass. This is not behavioral equivalence
or FPGA timing evidence.

The recorded full ruckus import failed before source loading with Tcl’s
error-file permission failure (`not owner`); VSG was unavailable. Pending
controller behavior is covered in the acceptance checklist below.

Rename checks on October 8, 2026: source comparison confirms only name/comment
and instance-label substitutions in the affected VHDL. GHDL analysis/link passes
for the real engine, endpoint and both register/protocol fixtures; MAC endpoint
and loopback analysis uses a declaration-only MAC. Python syntax, mocked source
manifest selection, local documentation links and whitespace checks pass.
The full-import and VSG limitations also applied to these checks; protocol and
endpoint regressions remain pending.

## PHY source-integration evidence

The October 6 status reconciliation used SURF
`66552564fd9a273e070e4925471f3661bcc5d4a9` and consuming project
`e964280287e19bb64fa68f467e67a7a3cde45b7e`. Later extension checks below are
recorded source-integration evidence; no exact revision was supplied for every
working-tree check. Real checkpoint binding and hardware acceptance remain open.

Static evidence for this change: GHDL analysis with real SURF packages and
current dependency entity declarations passes for the two PHYs, two PTP lanes,
common composition, both modified legacy lanes and KCU105 target. A structural
comparison against the pre-extraction legacy sources confirms unchanged public
interfaces and logic and identical composed checkpoint connections; GTY's
previously unassociated `gtpowergood` output is now explicitly open.
The actual GigEthCore/PtpCore manifests were evaluated with mocked Vivado
loading commands for `kintexu` and `zynquplusRFSOC`: each selected its expected
PTP lane and excluded the other family, with one copy of each common block.
Documentation links/anchors and diff whitespace pass. These checks do not bind
the DCPs or establish behavioral equivalence.

The normal ruckus `make import` attempt could not complete on this host: Tcl
failed to create a subprocess error file (`not owner`) before loading sources.
VSG is unavailable. Simulation/pytest remain paused; no Vivado or hardware
validation has run. Current checks and outstanding gates must remain distinct.

Static checks cover real-package/entity GHDL analysis of new adapters,
compositions and the board top, unchanged legacy LVDS public interface and
composed vendor pin mapping, source-manifest selection, target Tcl syntax and
Python syntax. These do not bind vendor IP or execute protocol behavior.
The GTH consolidation additionally passed static elaboration of both generic
modes with declaration-only checkpoint substitutes and an exact comparison of
each branch's vendor pin map against the former separate adapters. KCU105 uses
`USE_GTREFCLK_G=true`; existing ordinary Ethernet consumers keep the default.

These checks covered shared GTH/GTY and LVDS PHY extraction, common composition,
dedicated-reference selection, Marvell gigabit-only integration and stopped-clock
reset handling. No checkpoint was regenerated or converted; the dedicated GTH
asset remains missing. Register layouts and exact clock/reset/constraint paths
are maintained in the [composition guide](../../../ethernet/PtpCore/README.md#1g-phy-compositions).

## Fixed-point width static evidence

The October 9, 2026 working-tree change based on `4319702d0` follows the
[fixed-point width audit](autonomous-endpoint.md#fixed-point-width-audit).
`PtpServo` stores clamped Q16 ppb terms in 35 bits and elapsed Q32 seconds in
95 bits; 36-bit sums/differences precede rate clamping. `PtpMath` replaces two
256-bit multiplication registers with 128-bit low parts and sticky overflow
flags. The source review covers carry before narrowing, selected versus unused
shift overflow, signed minimum, rounding, cancellation/reset initialization,
registered result holding and the unchanged operation count. It is not a
behavioral-equivalence result.

GHDL 6.0.0 (LLVM 22.1.0) import and compile/link passed for `PtpMath`,
`PtpServoWrapper`, `PtpPhc`, `PtpE2eWrapper` and `PtpPortWrapper`, covering all
four math-engine consumers. An isolated temporary library used the current
`PtpCore/rtl` sources, those wrappers and their checked-out package, reset and
AXI adapter dependencies, with the flags below. No ruckus-wide import, vendor
stub, previous compiled library or simulator execution was used. An initial
`PtpPhcWrapper` link encountered its readback mailbox's `FifoAsync` dependency
outside this focused source inventory; the production `PtpPhc` leaf was linked
instead. PHC mailbox-wrapper coverage is not claimed. Warnings concern existing
package elaboration order, hidden declarations and AXI interface attributes.

Python syntax parsing (without imports), changed documentation links/anchors
and `git diff --check` passed. VSG was unavailable. Simulation, pytest collection
and pure models remain paused. No Vivado resource/timing comparison was run;
declared bit-count reductions do not establish mapped FPGA savings.

## Compile/link procedure

Inspect the current [runner conventions](../../../tests/common/README.md),
manifests and available tools before rebuilding. Use an isolated temporary output
directory and the checked-out source; do not alter installed environments or
invoke packaging. The earlier import used `make MODULES="$PWD" OUT_DIR=<temp> import` from the
SURF root. In this consuming workspace's sibling-ruckus layout, the one-step
import instead required `MODULES="$PWD/.."`, separate temporary `OUT_DIR` and
`IMAGES_DIR`, and `GIT_STATUS=skip-index-refresh` to suppress an incidental index
refresh. Inspect the target/setup before selecting the recipe. If import is
blocked, record that limitation and the source inventory's provenance; do not
reuse old compiled objects or depend on disposable `/private/tmp/ptp-one-step-*`
logs.

The non-Vivado inventory omits most MAC sources. Supplement it using the current
`ETHMAC_RTL_SOURCES` list in
[ethmac_test_utils.py](../../../tests/ethernet/EthMacCore/ethmac_test_utils.py),
including the required `EthMacCore/rtl` sources and `DspXor.vhd`, without importing
the same package twice. The recorded GHDL options were
`--std=08 --ieee=synopsys -frelaxed-rules -fexplicit`; only `ghdl -i` and
`ghdl -m` were used. Compile/link does not exercise run-time assertions.
Use static Python parsing/lint without importing tests while pytest is paused.

## Outstanding acceptance

Document and justify the existing 2048-cycle association floor and 200,000-ppb
actuator cap before treating them as qualified bounds. The
[endpoint numerical envelope](autonomous-endpoint.md#port-policy-and-numerical-envelope)
records their distinct purposes, introducing revision and missing rationale.
This source/design follow-up does not require restarting paused simulations.

After explicit VHDL approval, use the [PTP test guide](../../../tests/ethernet/PtpCore/README.md)
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

No known-bad comparison was run for the registered-boundary change under the
gate. Prepared between-edge assertions are intended to detect the former
input-dependent controls; queue/metadata cases test the new storage ownership.
Record actual outcomes and source revisions here when execution is authorized.
Device timing, added register/resource cost, physical CDC, calibrated hardware
accuracy, external-master interoperability and live PyRogue transport remain
separate qualification work. Include the one-step and PHY acceptance below;
prepared fixtures are not passing results.

### Fixed-point width acceptance

After explicit maintainer approval, run the prepared `test_ptp_math.py` and
`test_ptp_servo.py` fixtures before the existing PHC, E2E, port and endpoint
checks. None has been executed for this change.

- Math vectors now distinguish unused shifted-out bits from selected high
  partial products, addition carry from signed-range overflow, both operand
  orders, zero, signed minimum and nonzero wrapped low products. Exact 128-work-
  cycle latency is checked alongside the existing remainder, stall and cancel
  checks. Compare results/error/latency against the previous implementation.
- Servo vectors retain the rational PI oracle and exercise both signs of the
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
variants after explicit approval, retaining existing two-step coverage. Record
commands, parameters, source revision and outcomes here. The
[test guide](../../../tests/ethernet/PtpCore/README.md#autonomous-endpoint-tests)
indexes `test_ptp_port_samples.py`, `test_ptp_port.py`, RX fixtures,
`test_ptp_endpoint.py` and `test_ptp_endpoint_mac.py`; all new scenarios are
prepared, not executed.

| Case | Required observation |
| --- | --- |
| Valid one-step Sync with no Follow_Up | Completes once; enters the existing rate/history path; repeated valid exchanges enable E2E acquisition and servo operation. |
| Equivalent one-step and two-step exchanges | Equal remote time, capture and net correction produce equal numerical forward/E2E results. Account for different message arrival/completion latency; do not require cycle-identical publication. |
| Correction arithmetic | Positive, negative and fractional Q16 corrections, including crossing a second boundary; sum of two-step corrections equals the one-step correction in paired fixtures. No truncation or double application. |
| Timestamp validation | Nanoseconds 999,999,999 accepted; 1,000,000,000 and larger rejected; exercise nonzero upper seconds bits. Invalid one-step input cannot contaminate an existing association. Two-step Sync body remains non-authoritative. |
| Flags and source policy | Accept the two supported Sync flag values; reject other flags, wrong control, source, domain and unsupported versions as before. |
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

After RTL approval, exercise common/default and KCU105 address layouts through
the asynchronous management bus; AXI-only, PCS-only and system reset; link loss
with outstanding TX; concurrent application/PTP traffic; and independent endpoint
resets. Cover cable-absent initialization, gigabit-only negotiation, MDIO/PCS
readiness, copper watchdog/finite reset pulses, configuration recovery and PHC
invalidation. For oscillator programming, verify stopped-clock reset assertion
and synchronized/stretched release while other endpoints remain operational.
Controller checks must cover apply-to-restart/identity-restart latency, RX flush
and capture inhibition, IRQ event/W1C priority and bus-reset recovery through the
production controller.

Bind actual checkpoints in Vivado, including the missing dedicated-reference
GTH IP once supplied. Review exact `U_Phy/GEN_FABRIC_REF`/`GEN_GT_REF` hierarchy,
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
[clock requirements](physical-clock-integration.md#qualification-and-next-steps).
Live PyRogue transport is a separate acceptance item from static map checks.
