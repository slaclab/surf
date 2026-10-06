# PTP RTL review decisions and verification handoff

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

The maintained contracts are authoritative:

- [Endpoint composition and numerical envelope](autonomous-endpoint.md).
- [Registered timing and local implementation decisions](rtl-readability.md).
- [Per-module boundary ownership and remaining exceptions](output-register-survey.md).
- [Register ABI](register-map.md), [register ownership](register-ownership.md)
  and [directional interface records](interface-records.md).
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

- Each review's final VSG run passed all 22 PTP VHDL files with
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
[endpoint evidence](autonomous-endpoint.md#validation-and-handoff),
[register refactor evidence](register-ownership.md#validation-before-the-readability-cleanup)
and [RX proof](rx-rtl-proof.md). They predate the final interface/control-flow
changes and cannot close the acceptance items below.

## Compile/link procedure

Inspect the current [runner conventions](../../../tests/common/README.md),
manifests and available tools before rebuilding. Use an isolated temporary output
directory and the checked-out source; do not alter installed environments or
invoke packaging. The previous import used `make MODULES="$PWD" OUT_DIR=<temp>
import` from the SURF root. If import is blocked, document that limitation and
the provenance of any source inventory used instead.

The non-Vivado inventory omits most MAC sources. Supplement it using the current
`ETHMAC_RTL_SOURCES` list in
[ethmac_test_utils.py](../../../tests/ethernet/EthMacCore/ethmac_test_utils.py),
including the required `EthMacCore/rtl` sources and `DspXor.vhd`, without importing
the same package twice. The recorded GHDL options were
`--std=08 --ieee=synopsys -frelaxed-rules -fexplicit`; only `ghdl -i` and
`ghdl -m` were used. Compile/link does not exercise run-time assertions.
Use static Python parsing/lint without importing tests while pytest is paused.

## Outstanding acceptance

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
separate qualification work. One-step receive remains a separate
[pending implementation](one-step.md).
