# PTP review and acceptance record

## Status and provenance

The conventions fixes, registered-boundary redesign and conventions follow-up
are implemented. **The maintainer authorized resuming behavioral verification
on October 9, 2026**, lifting the prior simulation/pytest pause under
[current validation](README.md#current-validation). Completion
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
`PtpProtocolEngine`; its fixture is now `PtpProtocolEngineWrapper` (renamed
October 12). Historical checks below retain the original `PtpPortWrapper` name.

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
VSG was unavailable. Simulation/pytest were paused at that checkpoint; no Vivado
or hardware validation ran. These static results and outstanding gates remain distinct.

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
and pure models were still paused during that static review. No Vivado resource/timing comparison was run;
declared bit-count reductions do not establish mapped FPGA savings.

## October 9 behavioral verification

The maintainer explicitly approved the proposed math/servo-first regression
sequence on October 9, 2026 and selected IEEE 1588-2019 with 2008 compatibility
for standards traceability. This authorizes simulation, pytest collection and
pure-model tests; it is not acceptance of results that have not run.

Baseline: SURF `f8e6ba1729a4ebf1faa2bf88b295c43bc9ed0ba4`, initially clean.
Tools: GHDL 6.0.0 / LLVM 22.1.0; Python 3.13.2; pytest 9.0.2;
cocotb 2.1.0; cocotb-test 0.2.6; cocotbext-axi 0.1.28; xdist 3.8.0.
Python uses the existing `/Users/bareese/surf/.venv/bin/python`; no environment
was installed or changed. Tests and HDL are from this consuming checkout,
not the sibling SURF source. The normal ruckus import succeeded with sandbox
escalation after reproducing the Tcl error-file permission failure.

From `firmware/submodules/surf` in the consuming project:

```sh
make MODULES=/Users/bareese/ptp-dev/firmware/submodules GIT_STATUS=skip-index-refresh import
/Users/bareese/surf/.venv/bin/python -m pytest -n 0 -q \
  tests/ethernet/PtpCore/test_ptp_math.py tests/ethernet/PtpCore/test_ptp_servo.py
```

The remaining selections used the same interpreter and `-q`, with these worker
counts (paths relative to `tests/ethernet/PtpCore`; JUnit/log-output flags omitted):

```text
-n 2: test_ptp_{phc,e2e,tx_ledger,reg,register_map,reference,rx_reference,endpoint_reference,rx_rtl}.py
-n 0: test_ptp_port_samples.py
-n 2: test_ptp_{port,rx_mac,mac_association}.py
-n 6 --dist=worksteal: test_ptp_{endpoint,endpoint_mac}.py
-n 0: test_ptp_wire_vectors.py
-n 2 --dist=worksteal: test_ptp_port.py  (after the fixture correction)
```

The final collection was reconciled against the union of JUnit node IDs, using
the corrected port results for repeated nodes: **121 distinct cases passed,
zero remaining failures, zero skips, zero missing/extra nodes**. This comprises
**24 cocotb/GHDL configurations and 97 Python/reference/static cases**, not 121
RTL simulations. The eight endpoint cases cover both PHYs and both receive modes
in the closed-loop and real-MAC fixtures. All four closed-loop cases passed
their independent phase/path-delay assertions at acquisition and reacquisition;
their accelerated simulation bounds are not hardware accuracy measurements.

| Batch | Result |
| --- | --- |
| Math and servo, serial | **2 passed in 64.62 s**, including current width-boundary vectors. |
| PHC, E2E, ledger, registers/map, all reference models and RX RTL, two workers | **99 passed in 105.35 s**. |
| Direct protocol samples, serial | **1 pytest case passed in 25.21 s**, containing all three cocotb scenarios. |
| Initial physical port/RX-MAC/MAC-association batch, two workers | **3 passed, 1 failed in 808.75 s**; GMII fixture timeout issue described below. |
| Corrected physical port fixtures, both PHYs in parallel | **2 passed in 468.84 s**, including both adversarial and one-step scenarios on each PHY. |
| Closed-loop endpoint and real-MAC lifecycle, six workers | **8 passed in 2359.23 s**. |
| New literal-wire / hand-worked arithmetic anchors, serial | **7 passed in 0.05 s**; pure Python checks only. |

The same current math and servo fixtures also passed with only `PtpMath.vhd`
and `PtpServo.vhd` replaced by their pre-width-change contents from
`4319702d0`. The comparison used the shared runner, the current imported
dependencies and separate `/tmp/ptp-20261009-before-width-{math,servo}` build
directories; it did not modify the checkout or imported source files. Both
versions satisfy the same exact result/error/128-cycle math assertions and PI
command expectations for these vectors. This is bounded regression evidence,
not formal equivalence over all inputs. An initial temporary launcher could
not import `tests` inside the simulator; exporting the absolute checkout path
through the runner's Python search path corrected that harness failure.

Following the maintainer's request for parallel execution, six endpoint workers
ran alongside the two port/MAC
workers on this eight-logical-CPU host; the corrected port fixtures also ran
concurrently with the endpoint batch. Build directories are isolated by
parameters and scenario metadata.
Logs/JUnit are local temporary evidence under `/tmp/ptp-20261009-*`; simulator
outputs remain in ignored `tests/sim_build/ethernet/PtpCore`. This summary is
the durable evidence, not a dependency on temporary files.

The initial GMII `adversarial_port` scenario failed at the conflicting Follow_Up
count (`2` instead of `1`). Its 1000-cycle Sync receipt timeout expired during
the rejected-message sequence: GMII serialization takes more cycles than XGMII,
and rejected traffic does not renew the accepted-Sync timestamp. The resulting
source timeout correctly flushed the retained association. XGMII passed that
sequence. The fixture now keeps the normal 10000-cycle timeout for association
policy, then separately commits the short timeout, acquires a fresh pair and
checks expiry. Rejection/count assertions remain, with an added reacquisition
count assertion. Both complete PHY fixtures passed on rerun.

Production RTL remains at the baseline revision. Executable changes are the
timeout isolation in `test_ptp_port.py` and the new Python-only
`test_ptp_wire_vectors.py`; no protocol policy or register interface was changed.
The [specification matrix](../../../tests/ethernet/PtpCore/specification-coverage.md)
records existing coverage and missing normative traceability. A green behavioral
suite does not establish whole-standard/profile conformance.

Changed Python passes flake8 and the structural compliance audit. Local Markdown
links/anchors and diff whitespace were checked. No production RTL was changed,
and no Vivado, physical CDC, device timing/resources, external-master or hardware
accuracy qualification ran. The additional generic-boundary, largest-interval,
overflow/manual-phase and standards/profile acceptance items below remain open;
passing the current fixture inventory does not close missing scenarios.

### October 9 directed specification checks

The maintainer supplied the authoritative IEEE 1588-2019 PDF; its provenance,
verified clauses and remaining gaps are in the
[specification matrix](../../../tests/ethernet/PtpCore/specification-coverage.md).
The changes below are working-tree changes on SURF
`ddf7aa41d7180852a40c00202c8502735cdee75f`, using the same Python/GHDL toolchain
as the baseline above. Imported sources are symlinks to this checkout.

The directed checks exposed and corrected five header/parser issues:

- RX now accepts every minor version with major=2 (19.2).
- Layer-2 controlField and reserved flag bits are ignored on reception
  (13.3.2.13, 13.2 and Table 37).
- The TLV walker rejects odd value lengths (5.3.8/14.1.2), preserving
  unknown-TLV skipping and recovery.
- Emitted Delay_Req control is zero in 2019 mode; the selected 2008 mode
  retains one. The short TX fixture compares all 58 pre-MAC bytes and
  stalled sidebands in both modes.

The RX reference model and conflicting old negative vectors were updated.
The direct correction fixture now excludes the overflow sentinel from ordinary
finite wire bounds. The physical-port expected request was updated to 2019
control=0; those long physical-port scenarios were not rerun.
`PtpPortWrapper` only adds flat TX observations/backpressure; production public
interfaces and manifests are unchanged.

| Focused selection | Result |
| --- | --- |
| Initial two literal-header / signed-correction specification cases | **2 passed in 19.44 s**, before production changes. |
| Four added receive-rule cases on previous RTL | **4 failed in 19.25 s**, detecting minor-version, ignored-control, reserved-flag and odd-TLV defects. |
| Seven specification cases, direct protocol samples, direct/GMII/XGMII RX frontend; four workers | **9 passed, 2 failed in 63.07 s**. Failures were new fixture setup issues: nonmonotonic remote time and unexpired reset quarantine. |
| Only those two corrected specification cases; two workers | **2 passed in 3.31 s**. No further RTL changes were needed. |
| Affected pure RX reference file; serial | **27 passed in 0.09 s**. |

The resulting union is **11 distinct cocotb/GHDL configurations plus 27 pure
Python cases passing**, with no remaining failures or skips in that selection.
The initial focused after-change command was:

```sh
/Users/bareese/surf/.venv/bin/python -m pytest -q -n 4 --dist=worksteal \
  tests/ethernet/PtpCore/test_ptp_specification.py \
  tests/ethernet/PtpCore/test_ptp_port_samples.py \
  tests/ethernet/PtpCore/test_ptp_rx_rtl.py
```

The two rerun node parameters were `reserved_flags` and
`delay_request_headers` under `test_ptp_specification_protocol_rules`.
Temporary evidence is `/tmp/ptp-spec-{before,after,rerun,model}.{log,xml}`.
Each specification node selects its own cocotb scenario and does not replay
the imported benches' tests.

VSG reported zero violations on both production RTL files and the fixture.
Changed Python passed flake8 and the structural audit with zero findings;
documentation links/anchors and whitespace were checked. The earlier 121-case
suite remains historical evidence. Closed-loop endpoints, physical port,
real-MAC lifecycle and hardware were not rerun for these changes.

Known open implementation issues include the default multicast request
distribution, correction overflow policy and sdoId=000 domain limits.
Profile/external-port, assigned flag/TLV, time-property and E2E/asymmetry
acceptance remain partial. These focused passes do not establish conformance.

### October 9 master and exchange checks

Working-tree follow-up on SURF `6db41ad53ed5d17491fcfddfcff30325755d244f`,
using the same existing Python/GHDL environment and imported source symlinks.
The three requested items are ordinary multicast master traffic, correction
field overflow handling and stronger response-association negative tests.
[Coverage and clauses](../../../tests/ethernet/PtpCore/specification-coverage.md#ordinary-master-and-exchange-checks)
describe the eight new configurations and their applicability.

`PtpProtocolEngine` retires overflowed Sync/Follow_Up keys before arithmetic;
`PtpTxLedger` retires matched overflow responses without accepting interval
metadata. Both preserve existing bounded key ownership. Production interfaces,
register layouts and manifests are unchanged. The thin `PtpPortWrapper` adds
body/interval inputs, explicit wire observations, snapshots and E2E result
outputs; it still contains no alternative protocol logic.

Before the fix, the Sync test published a measurement from the sentinel. After
correcting a mistyped test expectation (100.25 ns is Q16 **6569984**), the
ordinary 2019 two-step case passed on the old RTL, while Delay_Resp overflow
failed because the response's advertised interval poisoned later scheduling.
The initial new-fixture run had 1 pass/7 failures in 87.58 s, six caused by that
expected-value typo. The corrected two-case comparison had 1 pass/1 targeted
failure in 32.95 s. The test expectation, not E2E arithmetic, was corrected.
Temporary evidence is `/tmp/ptp-exchange-before{,-corrected}.{log,xml}`.

Focused after-change selection (four workers):

```sh
/Users/bareese/surf/.venv/bin/python -m pytest -q -n 4 --dist=worksteal \
  tests/ethernet/PtpCore/test_ptp_exchange.py \
  tests/ethernet/PtpCore/test_ptp_port_samples.py \
  tests/ethernet/PtpCore/test_ptp_tx_ledger.py
```

**10 configurations passed in 196.17 s (3 min 16 s), zero failures/skips**:
eight new exchange configurations plus the existing direct protocol and ledger
fixtures. Logs/XML are `/tmp/ptp-exchange-after.{log,xml}`.
The new ordinary-master fixture uses independent 1 Hz timestamp/raw-tick
advances, skips idle seconds and checks exact forward/delay values, full
exchange snapshots and stalled outputs. It does not simulate the PHY/PHC/servo
continuously at those rates. The original long closed-loop, physical-port and
real-MAC scenarios and the full suite were deliberately not rerun. External
master, hardware, timing/CDC and full profile acceptance remain open.

VSG reported zero violations on the three edited production files and wrapper.
New Python passed flake8 and the structural audit (zero findings). All 83 local
links/anchors in the five changed SURF guides and diff whitespace passed. The
RTL checklist review traced identity admission, same-edge wire retirement,
registered completion, retained-key replay and final cancellation priority; no
new state, clock crossing or public interface was introduced.

## October 9 LUT optimization checks

The working-tree optimization based on
`6db41ad53ed5d17491fcfddfcff30325755d244f` replaces the servo bubble sort with
nine fixed compare/swaps and changes RX prefix/header parsing and queue payload
storage. `PtpPkg` adds lossless 809-bit storage helpers; production interfaces
and the 744-bit verification representation remain stable. Independent protocol
and specification edits are present in the same tree and are not attributed to
this change. See the [implementation handoff](lut-optimization.md) and
[queue contract](autonomous-endpoint.md#rx-queue-storage).

Using the existing Python 3.13.2 / pytest 9.0.2 / cocotb 2.1.0 environment at
`/Users/bareese/surf/.venv/bin/python` and GHDL 6.0.0, the focused checks cover:

- `test_ptp_servo.py`: the independent PI/holdover checks plus a new median
  scenario covering all 120 orderings, startup counts, duplicates, signed64
  maximum, circular replacement, rejection and abort/reacquisition of history.
- `test_ptp_rx_rtl.py`: five configurations (direct depths one/two/three,
  XGMII depth four, GMII depth four with active-low asynchronous reset), keeping
  the cycle-exact queue/abort oracle and adding all partial beat widths and
  capture-increment checks through repeated fill/drain/wrap.
- `test_ptp_rx_storage.py`: two TX-observer configurations, depths two/three,
  including capture errors, PHC generation changes, full records through RAM,
  immediate consume/refill, full-before-edge overflow, reset/flush, sparse keeps
  and full-width malformed TLV lengths followed by recovery.
- `test_ptp_specification_rx_rules[tlv_suffix]`: selected structural TLV rules.
- `test_ptp_rx_mac.py`: real-MAC CRC/pressure/retained-head/overflow behavior,
  including 240 independently captured records while the MAC FIFO loses frames.

These ten production-RTL configurations passed. The separate historical
`test_ptp_mac_association.py` model/counterexample fixture also passed, bringing
the union to **11 distinct configurations**. It does not verify production TX
observation. The initial five-case batch passed in 57.70 seconds, the expanded
ten-case batch in 536.40 seconds, and the final two TX storage cases with added
malformed/refill checks in 1.05 seconds. Logs/JUnit are temporary local evidence under
`/tmp/ptp-lut-{initial,expanded,storage}.{log,xml}`; retained fixtures and this
record describe the durable assertions.

The subsequent synchronous-FIFO revision replaces that custom RAM queue with
SURF `Fifo` in synchronous FWFT mode, validated on
`2bb198b10efc964f1d861ebc34a33d214052afd7` plus the local optimization patch.
The registered-RAM intermediate passed
seven leaf configurations in 42.97 seconds before being superseded. For the
FIFO revision, the five RX configurations and two TX-storage configurations
passed in **46.58 seconds**. Their independent queue oracle now requires
three clocks from completion to head publication, counts records throughout
the pipeline and checks consumption/invalidation before write/read delivery.
TX storage sweeps reset/flush across all four completion/pipeline/head edges,
then refills and drains to detect surviving stale entries. Local logs/JUnit:
`/tmp/ptp-rx-sync-fifo.{log,xml}`.

Six additional configurations passed in **254.60 seconds**: the real-MAC RX
fixture, the XGMII port fixture (both adversarial and one-step/mixed-mode
scenarios), literal RX headers, both RX specification-rule cases, and ordinary
master header admission. These exercise shared RX-bench timing, physical RX/TX
observer integration, retained-head cancellation and MAC FIFO pressure.
The FIFO revision therefore passed **13 distinct configurations**, with zero
failures/skips. Local logs/JUnit:
`/tmp/ptp-rx-sync-fifo-integration.{log,xml}`. The GMII port integration and full
endpoint/servo settling suite were not rerun; GMII frontend/adapter behavior
is covered by the leaf configuration above.

VSG checked 689 rules with no violations on all five edited VHDL files
(three production files and two wrappers). Flake8 and the focused test
compliance audit passed on the three edited/added Python tests. No environment
was installed, no manifest was changed and no full PTP suite was run.
The FIFO follow-up also passed VSG on `PtpRxFrontend` and Flake8/compliance
checks on the two changed RX tests.

Vivado synthesis/implementation, actual distributed-RAM mapping, resource
savings and timing remain unmeasured. Compare the same device/tool/constraints
and parent hierarchy against the recorded baseline before claiming an area
improvement. This run does not close endpoint settling, every possible generic
combination, physical clock/CDC or external-master/hardware acceptance.

## October 11 ledger optimization checks

Working-tree source based on SURF `1bd476a89cac78f5945007b8975ef95755899a8d`.
`PtpTxLedger` replaces the wide register table with complete 636-bit RAM rows,
four ownership bits per slot and a shared read/modify/write scan. Completion
and response producers now hold their records through ready/valid acceptance.
The [storage contract](autonomous-endpoint.md#tx-ledger-storage) specifies the
scan timing, allocation and cancellation rules. The
[optimization handoff](lut-optimization.md#october-11-ledger-storage-and-counter-pass)
records the supplied Vivado placed reference and remaining area comparison.

The existing Python 3.13.2 / pytest 9.0.2 / cocotb 2.1.0 environment at
`/Users/bareese/surf/.venv/bin/python` and GHDL 6.0.0 were used without changing
installed environments. The existing ruckus inventory resolves to this checkout;
all modified entities and the RAM selector already belong to the manifests.

Selected behavioral coverage:

- Eleven ledger configurations: lifecycle; one-/four-slot timeout/rejection counts;
  full-row payloads at distributed depths one/three/four and block depth four;
  cancellation at every phase of a four-slot scan; one-slot reuse under a held
  output; and four occupied two-bit keys with collision search, stored identities,
  identical/conflicting response duplicates and unknown physical ownership;
  and wire/response duplicates arriving after scan start while output is released.
  The last case verifies that unscanned inputs block publication/reclamation.
  Storage checks include both arrival orders, simultaneous and consecutive inputs
  with valid held high, all capture fields, response metadata and output stalls.
  Logical restart retains the physical completion until its handshake, while
  MAC/system reset clears ownership and excludes stale RAM contents.
- `test_exchange_rejection[response_overflow]` and `[response_association]`:
  actual protocol/ledger/E2E rejection and same-request/fresh-exchange recovery.
  The latter now gives rejected responses a long log interval, checking that
  accepted metadata stays aligned through delayed ledger acknowledgement.
- Real-MAC lifecycle: two-step GMII and one-step XGMII, including paused TX,
  restart, late completion, stale-exchange rejection and fresh E2E recovery.
- Three pure request-ledger model cases passed in 0.02 seconds: early response
  and sequence wrap, bounded unknown fates, and stale response after restart.
  These are logical-model evidence, not additional cycle-accurate RTL runs.

Execution results:

| Selection | Result | Local evidence |
| --- | --- | --- |
| Initial full-RAM leaf selection | 9 passed, 24.71 s | `/tmp/ptp-area-ledger-full.{log,xml}` |
| Continuous-valid storage, scan cancellation, key/identity boundaries | 6 passed, 26.37 s | `/tmp/ptp-area-ledger-boundaries.{log,xml}` |
| Final whole-row RAM-port setting, distributed/block depth four | 2 passed, 13.82 s | `/tmp/ptp-area-ledger-ram-final.{log,xml}` |
| Protocol rejection plus GMII/XGMII real-MAC lifecycle | 4 passed, 928.86 s | `/tmp/ptp-area-ledger-full-integration.{log,xml}` |
| Strengthened response log-interval alignment | 1 passed, 200.67 s | `/tmp/ptp-area-ledger-metadata.{log,xml}` |
| Final pending-input ordering fix plus distributed/block payload regression | 3 passed, 16.70 s | `/tmp/ptp-area-ledger-pending-input.{log,xml}` |

The final pending-input guard was added after the integration simulations had
compiled. Its focused validation is the final three-case row and fresh GHDL
synthesis; the long real-MAC runs validate the scan/backpressure integration
before that last guard, and were not repeated for the guard alone.

An earlier capture-only iteration passed its leaf/protocol checks, but both
real-MAC cases stopped at an existing fixture mismatch: the monitor expected
legacy control byte 1 while explicitly checking a minor-version-1 frame.
The source-backed packet contract and current request builder use control byte
0 for that configuration; the monitor expectation is corrected. This changes
the test expectation, not the transmitted packet or protocol policy.

GHDL synthesis of the production ledger succeeds and reports RAM `mem`, width
636 bits, depth four. The initial attempt encountered the RAM selector's
unequal-width inactive byte-enable branch. Explicit whole-row `BYTE_WIDTH_G`
with byte enables disabled makes both branch widths one without modifying the
shared RAM implementation. GHDL ignores vendor mapping attributes; its RAM
recognition is not evidence of physical LUTRAM/BRAM placement or a resource saving.
Synthesis diagnostics/netlist are at `/tmp/ptp-area-ledger-synth.{log,vhd}`.

All eight edited VHDL entities pass VSG (689 rules each, zero violations).
The three edited Python files pass flake8. The changed ledger/exchange tests
have no enforced compliance baseline differences. Changed relative links,
anchors and diff whitespace pass. The endpoint helper retains five pre-existing audit
findings (one propagation-delay classification and four lifetime-loop
classifications), confirmed identical by comparing `audit_source()` results
against HEAD; its only behavior change is the literal control-byte expectation.

Counter saturation has an explicit bound: at most two local rejection events
feed a 33-bit sum, so carry cannot be lost. Tests exercise event multiplicity,
retirement and reset precedence; they do not force live 32-bit counters near
saturation. No full PTP suite, every-depth/reset-generic sweep, long servo
settling, Vivado implementation/timing or hardware check is claimed. Inferred
block/distributed simulations check the shared RAM timing interface only.

The October 12 [synthesis report review](lut-optimization.md#october-12-synthesis-report-review)
adds vendor mapping evidence: both ledgers contain 364 LUTRAMs, about 1,800 total
LUTs and 1,853 FFs. The earlier hierarchical reference is placed, so the observed
area reduction is not a controlled comparison at the same stage. The later
run supplies no placement/timing or additional behavioral evidence.

## October 12 protocol table checks

Working-tree checks based on SURF
`3f5b468ff3c0e99b33fa36c80850658d77c2e341` cover the
[protocol table conversion](lut-optimization.md#october-12-protocol-table-conversion).
The [storage contract](autonomous-endpoint.md#protocol-association-storage)
records synchronous read timing, RX acknowledgement, history arbitration,
scan-start expiry and cancellation. The implementation follows
[SURF VHDL conventions](../../vhdl-conventions.md); RAM controls are registered,
payload reset is replaced by ownership invalidation, and the raw-tick/Q3 limit
conversion uses named intermediate values without narrowing the arithmetic.

The focused selection exercises pairing and nearest-Sync behavior directly,
then their E2E, PHY and real-MAC consumers. It uses Python 3.13.2 from the existing
SURF virtual environment, cocotb 2.1.0 and GHDL 6.0.0 with four pytest workers.
The initial direct protocol run used the distributed default before adding its
explicit memory parameter. Both memory settings use production
`SimpleDualPortRam`, not a fixture-specific storage model.

| Selection | Result | Evidence |
| --- | --- | --- |
| Direct protocol sample suite, distributed default; ordinary 2019 one-step master | 2 passed in 30.47 s | `/tmp/ptp-tables-first.{log,xml}` |
| New nearest-history and pair cancellation/expiry scenarios, distributed | 2 passed in 44.99 s | `/tmp/ptp-tables-directed-first.{log,xml}` |
| Remaining history/pair cases in both memory settings, direct block-memory sample suite, three exchange rejection cases, ordinary 2019 two-step master, GMII/XGMII port, real-MAC GMII two-step | 12 passed in 1031.79 s | `/tmp/ptp-tables-consumers.{log,xml}` |
| Final publication-priority and nearest-history scenarios, both memory settings | 4 passed in 59.17 s | `/tmp/ptp-tables-priority-final.{log,xml}` |

These batches contain 20 successful configuration runs across 18 distinct
configurations, with no skips. The final batch repeats the two nearest-history
configurations after the publication-priority fix described below.

The new RAM fixture independently checks nearest samples on both sides of TX
capture, physical-slot ties after ring wrap, RX/TX fractional phases, age and
separation limits, concurrent append, exact t1/t2/t3/t4 and correction snapshots,
held measurements, scan-phase cancellation and recovery with high generation
bits. Pair checks target cancellation through the occupied-row reread and the
inclusive expiry boundary while raw time advances during a scan. Existing
sample tests retain finite correction bounds, upper timestamp seconds,
reordering, duplicate/mode collisions, table capacity, sequence wrap and
measurement backpressure coverage.

Final review identified starvation when continuous rejected Syncs repeatedly
reserved pairing scans ahead of a completed E2E result. The new
`history_publication_priority` case reproduces the failure without the guard
(`/tmp/ptp-tables-priority-before.log`). A pending result now takes priority over
starting another pairing scan. The final four-case row checks that guard;
the earlier consumer runs compiled before it and are not claimed as validation
of that last change.

GHDL synthesis of the final engine succeeds and recognizes four-row RAMs of
width 485, 549 and 636 bits (history, pairing and existing ledger respectively).
The emitted netlist includes the final E2E admission guard. Diagnostics and
netlist are in `/tmp/ptp-tables-synthesis/`. GHDL ignores vendor RAM attributes;
this verifies structure, not physical memory placement, area or timing.

Both edited VHDL files pass VSG (689 rules each, zero violations). The three
changed Python files pass flake8 and the compliance audit with zero findings.
Added relative links/anchors and diff whitespace pass.
No full PTP suite, all reset/generic combinations, real-MAC XGMII case, long
servo settling, Vivado implementation/timing or hardware validation was run
for this conversion. The retained text utilization reports predate it; the
subsequent [synthesis screenshot review](lut-optimization.md#october-12-protocol-table-synthesis-screenshot)
records a smaller copper protocol engine including its new RAM children.
That area evidence adds no behavioral, placement or timing acceptance.

The direct fixture was subsequently renamed to `PtpProtocolEngineWrapper`,
including its filename, entity and all pytest top-level references. A fresh
ruckus/GHDL import and `test_ptp_specification_protocol` pass (1 case, 21.27 s;
`/tmp/ptp-wrapper-rename{.xml,-test.log}`). The renamed wrapper passes VSG and
the four updated Python test files pass flake8. This naming-only follow-up does
not rerun the table/integration selection above.

## October 12 servo sharing checks

Baseline: SURF `191d733c1031e5b86643f67816f41adf958db130`. The
[servo implementation](lut-optimization.md#october-12-servo-arithmetic-and-median-implementation)
shares local clamp/rounding arithmetic and serializes the median. The production
interface and software ABI are unchanged. The direct wrapper adds lifecycle,
age and snapshot inputs for focused verification. Existing directory imports
already load the changed sources; no source-manifest change was needed.

Checks use the existing `/Users/bareese/surf/.venv` Python/cocotb environment
and GHDL 6.0.0 on `PC100431`. The staged arithmetic-only RTL passed
`test_ptp_servo.py` in **83.53 s**, including the extended rational PI comparison,
Q16 rate-state assertions, fractional ties, unsigned32 maximum gains and signed64
offset extrema. The combined version's numerical scenario then passed with
checked integral overflow and cancellation sweeps around the new arithmetic
states. Retained frequency is checked through a subsequent holdover command.

The new median checks cover all 120 distinct-value orderings, each population,
duplicates, signed64 maximum, circular replacement, rejection, exact nine-clock
publication, held-valid/backpressured inputs, and abort/restart/generation/reset/
staleness on every comparison edge. AXI-only reset and snapshots are checked
across publication. The first combined run exposed a final-edge cancellation
bug: count was cleared but the canceled value replaced the published median.
The current-edge cancellation guard fixes it; the focused median rerun passed
in **16.04 s**, including that regression.

Final combined selection: `test_ptp_servo.py` and
`test_ptp_endpoint.py::test_ptp_endpoint[two-step-GMII-False]`, run with two
workers. The endpoint case checks autonomous acquisition, numerical lock,
independent phase/delay, link loss, holdover and reacquisition. Both selected
pytest cases **passed in 572.26 s (9 min 32 s)**. The final servo scenarios also
report PASS individually (numerical control 92.45 s, median history 6.73 s
simulator wall time). No broader simulation selection was run after these passed.

GHDL synthesis of production `PtpServo` succeeds. Its generated VHDL contains
one median data comparator, one positive/negative clamp comparison pair, one
shared frequency/rate adder and one correction-rounding adder. It also reports
two 9-by-3-bit ROMs for the fixed comparator-pair indices. This verifies the
intended shared structure, not FPGA area or timing. VSG reports zero violations
for both edited entities; Python flake8, changed-document link/anchor checks
and diff whitespace checks pass.

Logs, the final JUnit report, generated structural netlist, and separate
baseline/arithmetic-only/final RTL plus arithmetic/median patches are temporary
artifacts under `/private/tmp/ptp-servo-20261012/`. The full PTP suite, XGMII,
one-step and real-MAC endpoint variants, vendor synthesis/implementation and
hardware tests are outside this selection. Vivado/VCS are unavailable on this
host; measured LUT/FF/carry changes and timing acceptance remain outstanding.

## October 12 E2E, PHC and math checks

Source baseline: SURF `26453ccedaa3968a7c6e08d3b56ffaa442f2ce1b` plus the
[E2E/PHC/math implementation](lut-optimization.md#october-12-e2e-phc-and-math-implementation)
working changes. Production ports and software ABI are unchanged. The E2E
wrapper adds generation, sequence and result-provenance ports for verification;
existing ruckus directory imports load all edited HDL.

The selection covers changed arithmetic at the leaves, PHC software submission
and affected consumers. Runs use the existing `/Users/bareese/surf/.venv`
Python 3.13.2/cocotb 2.1.0 environment and GHDL 6.0.0 on `PC100431`.

| Selection | Result | Temporary evidence |
| --- | --- | --- |
| Math default divisor width 128, bounded 46 and minimum 1 | 3 passed in 18.00 s | `/private/tmp/ptp-math-20261012-results.xml` |
| PHC at 125/156.25 MHz with both reset styles; register banks at zero/nonzero bases | 4 passed in 92.37 s with two workers | `/private/tmp/ptp-phc-20261012.xml` |
| E2E both-zero, each-single-zero and both-nonzero calibration | 4 passed in 51.25 s with two workers | `/private/tmp/ptp-e2e-20261012.xml` |
| E2E both-zero after explicit constant divide tie-off | 1 passed in 12.37 s | `/private/tmp/ptp-e2e-zero-final-20261012.xml` |
| Final combined Servo, distributed-memory direct protocol and two-step GMII endpoint | 3 passed in 571.85 s with two workers | `/private/tmp/ptp-arithmetic-20261012/final-consumers.xml` |

These completed batches cover 14 distinct pytest configurations and one
targeted repeat, with no failures or skips. The final consumer run compiled
the explicit E2E divide tie-off. It checks the Servo PI/median cases, protocol
correction/provenance and rate-estimator cases, and endpoint acquisition,
independent phase/delay, link loss, holdover and reacquisition. An earlier
consumer batch was interrupted to compile the final tie-off; it is not counted
as completed validation.

Math vectors check signed extrema, low result bits on overflow, nearest and
truncated quotients, signed truncation remainders, divisor-bound errors,
immutable operands, complete stalled outputs and cancellation through the final
iteration. Normal operations still require exactly 128 work clocks; invalid
divisors still terminate at admission with zero result/remainder and an error.

The PHC cycle oracle checks the smallest/largest accepted increments and zero,
negative and at-least-one-second rejection. It checks both the old-increment
commit-edge time and newly published increment. Manual PHASE vectors cover
signed fractional remainders, large epochs, frozen operands across AXI reset
and rewritten shadows, signed128 extrema, and the distinction between a
preparation quotient-fit error and a fitting signed64 quotient that faults at
the PHC epoch boundary. Fatal cases reset independently so earlier faults
cannot hide later behavior.

E2E vectors retain full epochs and signed128 correction extremes, modulo
arithmetic, half ties, exact path-delay bounds, reverse capture order and
independent capture increments. Tests assert successful latency of 136/396/656
clocks, immediate admission errors with calibration bypassed, elapsed-product
overflow, held payload/provenance and cancellation/reset at every added stage.
The final divide tie-off makes the both-zero specialization explicit at the
math child boundary; its focused rerun covers the changed branch.

GHDL structural synthesis succeeds for the edited arithmetic. E2E contains one
timestamp multiplier and one selected 129-bit addition encoding the signed128
sum/subtract carry; its both-zero child divide control is constant zero. PHC's
math specialization retains 46 remainder bits, a 47-bit shifted trial and one
48-bit subtraction with borrow. Its ordinary tick uses the stored increment;
nominal-plus-rate remains only in command processing. These are generic
structural observations, not mapped LUT/DSP/carry savings or timing evidence.
VSG, Python flake8 and diff whitespace checks pass for the edited files.
All 159 local links/anchors in the six changed guides pass. The changed-test
compliance audit reports the same two snapshot sampling-annotation findings
present in baseline `test_ptp_phc.py`; it finds no new violations.

The full PTP suite, other endpoint PHY/receive/MAC combinations, all generic
settings, local Vivado synthesis/implementation and hardware validation remain
unrun. Vivado/VCS are unavailable on this host. The subsequently supplied
[screenshot](lut-optimization.md#october-12-arithmetic-synthesis-screenshot) and
[full reports](lut-optimization.md#october-12-arithmetic-synthesis-comparison)
show area reductions after these changes. The reports provide recorded build
provenance and both lanes, but use a different tool version from their baseline
and differ from the screenshot's whole-design totals. Neither adds timing or
hardware acceptance or isolates exact per-patch savings.

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
Use static Python parsing/lint for checks that do not need execution.

## October 12 shared timestamp converter

The [area-plan increment](lut-optimization.md#first-implementation-increment-october-12)
records the implementation and focused checks. Review retained the registered
publication/cancellation priority, held measurement ownership, full-width
correction arithmetic, completion-edge association age and RAM-write alignment.
A normalized anchor replaces the retained full sample; the converter selects
remote/local inputs before arithmetic. The checksum-option experiment and its
capability ABI were reverted at the maintainer’s request; shared MAC logic stays
unchanged. Its independent checks and patches are archived in the consuming
project. The interrupted real-MAC batch produced no completed passing result.
No new timing-accuracy or mapped-area claim follows from simulation or lint.

## October 12 shared word processor prototype

`PtpCompute` is a standalone foundation for the
[shared measurement processor](lut-optimization.md#shared-word-processor-prototype-october-12),
not yet a production replacement. Review checked the single data ALU,
word-addressed operands/results/scratch, signed magnitude restoration and
overflow, registered RAM strobes/read latency, per-context cancellation and
result/read ownership. There is no endpoint or register ABI change.

Focused GHDL 6.0.0 / cocotb 2.1.0 verification on October 12:

- `test_ptp_compute.py`: **2 RAM configurations, 6 cocotb scenarios passed**
  in 30.57 s with two workers. Each configuration exercises 185 independent
  integer-oracle requests plus ownership, contention and cancellation cases.
  Result acknowledgement honors ready/valid even with an outstanding read;
  that read blocks context reuse until consumed. Reset and queued/active/held
  cancellation invalidate old operand ownership; other contexts continue.
- Largest isolated admission-to-result observations: add/subtract 26 clocks,
  multiply 196, divide 4,443. Tests impose conservative bounds, not an exhaustive
  maximum proof. Queueing, operand transport and complete measurement sequences
  still require budget/timeout analysis before client migration.
- VSG, Python flake8, ruckus import and diff whitespace pass. GHDL synthesis
  recognizes one 32-bit-by-128 RAM and completes; vendor memory attributes are
  ignored by that tool. Whole-word write configuration uses `BYTE_WIDTH_G=32`,
  also avoiding GHDL's inactive byte-enable branch width diagnostic.

Vivado is unavailable locally. No mapped LUT/BRAM/DSP or timing result exists
for the prototype, and no migrated-client, endpoint or full-suite regression
was run. Next acceptance includes rate/E2E adapters and existing leaf numerical
contracts, service deadlines/cancellation under bursts, engine-plus-adapter
area, and comparison with a shared existing-width divider. Configuration,
snapshots, median and ledger word storage remain unimplemented.

## October 12 servo divisor bound

The [arithmetic audit and area decision](lut-optimization.md#divide-and-multiply-audit-october-12)
retains only an elaboration-time bound on the servo's existing `PtpMath`
divider. Review traced every divide operand: nominal Q32 increment, one billion,
seconds Q16 and ppb Q16 scaling. The largest sets `DIVISOR_WIDTH_G`; normal
125/156.25 MHz clocks select 46 bits, while the standalone 31.25 kHz case
needs 47. The divisor bound reduces the remainder and trial-subtraction widths.
Full dividend/quotient precision, rounding, intermediate overflow checks and
the 128-iteration schedule remain intact. Servo `comb`, `seq` and output
publication are byte-identical to the preceding implementation. No runtime
shortcut, new state, public production interface, register-map or CDC change
is included.

Focused GHDL 6.0.0 / cocotb 2.1.0 verification on October 12:

- `test_ptp_servo.py`: **3 clock configurations / 6 cocotb scenarios passed**
  in 213.43 s with two workers. Independent rational PI checks cover both
  oscillator signs, rounded elapsed intervals, maximum gains/offsets, actuator
  limits and rejected integral overflow. Held commands, acknowledgement,
  cancellation, median history, AXI-only reset and snapshots also passed.
  The fixture now accepts the nominal frequency as a generic; raw ticks remain
  injected, so the low-frequency case is arithmetic coverage, not a PHY mode.
- VSG passes both edited VHDL files (689 rules each); Python flake8 and diff
  whitespace pass. The existing ruckus import resolves both files to current
  source. Temporary batch evidence: `/private/tmp/ptp-servo-divisor-20261012.log`
  and `/private/tmp/ptp-servo-divisor-20261012.xml`.

No endpoint/full-suite rerun was selected for this static width change. Vivado
is unavailable locally; mapped LUT/FF/DSP savings and timing remain unmeasured.
At that baseline, the shared-processor client and word-state migrations were
still outstanding; the following implementation replaces those private engines.

## October 13 connected compute and word storage

The [implementation record](lut-implementation.md) describes the completed change
against clean SURF baseline `75a49f427`, now recorded in SURF `52dfa266f`.
The preceding prototype and private-engine results are historical; the evidence
in this section applies to the connected production architecture.

`PtpEndpoint` instantiates one `PtpCompute`, serving rate, E2E, servo and PHC
preparation through private word/descriptor interfaces. Completed values remain
in addressed workspaces across chained operations. Pair/history, TX ledger and
median storage use word RAM; RX and the dedicated Delay_Req observer have
independent streaming stores. Configuration uses frozen candidate banks and
sequential validation. Snapshots pin immutable records and freeze changing
scalars on the common capture edge before coordinated publication.
The [storage inventory](lut-implementation.md#implemented-storage-inventory) and
[service contract](rtl-readability.md#shared-service-bound) describe retained wide
boundaries, ownership and the derived 70,347,776-tick association minimum.

The VHDL checklist review traced RAM issue/read/write edges, registered forward
outputs and held responses, bounded arbitration, cancellation priority, retained
frequency commit on successful PHC ACK, AXI-only reset, candidate cloning and
snapshot bank reuse. Announce body and decoded metadata share one twelve-word
immutable record, so capture during upload cannot mix versions. History streams
normalized values directly into E2E; only the selected public producer records
remain wide. All source additions use the existing ruckus directory manifests.
No PHY, clock-domain topology, vendor MAC or checkpoint implementation changed.

This substantial integration change selects the complete PTP regression,
executed in focused batches as interfaces became ready. The runner uses GHDL
6.0.0 LLVM with its normal `-O2` setting and cocotb 2.1.0 on `PC100431`; Python
3.12 is in a temporary regression environment. Late integration runs use the
per-process macOS `MallocNanoZone=1` setting to reduce allocator overhead; no
installed environment was changed. The real-MAC lifecycle fixtures select
`TPD_PS_G=0` in the simulation wrapper, preserving registered clock-cycle
boundaries and wire/FCS assertions while reducing delayed-event scheduling.
The wrapper defaults to 1000 ps; leaf and model-MAC endpoint timing checks retain
1 ns propagation delay. Filtered runs are counted only
when their cocotb summary confirms execution. Completed evidence includes:

| Selection | Result and temporary evidence |
| --- | --- |
| Independent reference, RX model and literal wire vectors | 93 passed; `/tmp/ptp-final-models.log`. |
| Shared compute, both memory/reset configurations | Both configurations passed arithmetic, chaining, contention and retained-cancellation checks; `/tmp/ptp-compute-retention.log`. |
| E2E calibration, PHC, physical RX/MAC, exchange and specification cases | 22 configurations passed across `/tmp/ptp-integrated-components.log` and the two corrected fixture reruns in `/tmp/ptp-component-rerun.log`. |
| Normalized-history E2E calibration | All four calibration configurations passed the same full-epoch, correction-wrap, captured-increment, rounding, stall and cancellation oracles; `/tmp/ptp-e2e-normalized.log` (97.24 s). Together with raw timestamp cases, E2E has eight configurations. |
| Additional PHC snapshot boundaries | Both reset/clock configurations passed capture coincident with SET/PHASE/RATE/VALID commit, invalidation and apply; `/tmp/ptp-phc-snapshot-edges.log`. |
| Ledger | All 11 configurations passed across `/tmp/ptp-ledger-all.log` and `/tmp/ptp-ledger-tests.log`. |
| RX and dedicated TX storage | All five RX configurations, GMII/XGMII minimum-spacing bursts and dedicated TX storage passed; `/tmp/ptp-rx-tests.log`, `/tmp/ptp-rx-spacing.log`, `/tmp/ptp-tx-store-tests.log`. |
| Protocol tables | All eight memory/scenario cases passed; `/tmp/ptp-protocol-ram-all.log`. Final normalized-stream selection and cancellation reruns also passed in `/tmp/ptp-final-interfaces.log`. |
| Direct port samples | Original four cocotb scenarios passed for each RAM type; `/tmp/ptp-port-full.log`, `/tmp/ptp-port-block-optimized.log`. New Announce cohort checks passed in both RAM settings; `/tmp/ptp-announce-snapshots.log` and `/tmp/ptp-announce-block.log`. |
| Servo | All three clock configurations passed both numerical and median scenarios; `/tmp/ptp-servo-config-numeric.log`, `/tmp/ptp-servo-125-median.log`, `/tmp/ptp-servo-156.log`, `/tmp/ptp-servo-snapshots.log`, `/tmp/ptp-servo-wide.log`. |
| Register/schema, legacy math and physical association | Schema (4), legacy math (3), association (1) and both register-base cases passed; `/tmp/ptp-final-interfaces.log` and `/tmp/ptp-reg-expanded.log`. The latter reruns the expanded snapshot index after its range was corrected to 31. |

Physical-port policy and adversarial scenarios passed on both PHYs. GMII ran
both scenarios in `/tmp/ptp-port-gmii-nano.log` (3276.84 s). XGMII's one-step
policy passed in `/tmp/ptp-physical-integration.log`; the corrected adversarial
rerun passed in `/tmp/ptp-port-adversarial-final.log` (5457.27 s).

All four real-MAC lifecycle configurations passed in
`/tmp/ptp-mac-cycle-complete.log` and its JUnit XML (3799.39 s, four workers).
Both receive modes and both PHYs passed application traffic/identity guarding,
pause/restart/late completion and fresh-exchange recovery.

All four model-MAC endpoint configurations also passed acquisition, holdover,
counter continuity and reacquisition with independent wire/time oracles. The
one-step XGMII run passed in `/tmp/ptp-endpoint-final.log` (9256.76 s), and the
one-step GMII run passed in `/tmp/ptp-endpoint-gmii-one-nano.log` (5133.92 s).
Both two-step configurations passed in `/tmp/ptp-endpoint-remaining.log`; that
batch reports two passes and one failure because its duplicate one-step GMII
run was deliberately interrupted in favor of the separate run. The interrupted
duplicate is not counted as a behavioral failure or a passing run.

Fixture changes account for serialized operand movement and scan
latency: bounded request/result waits, the association minimum, source spacing,
receipt expiry and pause duration. Exact packet bytes, independent numerical
oracles, queue capacities, expiry edges and cancellation checks remain asserted.
Interrupted runs are diagnostic evidence only and are not counted as passes.

The completed selection covers all **171 distinct configurations**: 74 RTL
configurations and 97 Python/static cases, across the recorded batches and
scenario-filtered reruns. This is not a claim of one uninterrupted pytest run;
failed fixture assumptions and the expanded register index were corrected and
their affected cases rerun. The latest collection is
`/tmp/ptp-final-collection.log`. VSG passes all 25 changed/new VHDL files
(`/tmp/ptp-final-complete-vsg.log`, with the final E2E wrapper recheck in
`/tmp/ptp-e2e-normalized-vsg.log`); flake8 passes all 19 changed Python files.
Changed Markdown links/anchors and diff whitespace also pass.

Vivado/VCS are unavailable on this host. The maintainer subsequently supplied the
first [synthesis screenshot](lut-optimization.md#october-13-connected-implementation-synthesis)
and identified Vivado 2025.2 / SURF remote `ethernet-ptp` head, independently
resolved to `52dfa266f`. The copper endpoint shows 18,483 LUTs, 13,618 registers,
0.5 BRAM tile and four DSPs; the shared compute child accounts for 2,223 LUTs,
826 registers and all that endpoint's BRAM/DSP use. This is synthesis evidence,
separate from the GHDL results above. Full reports and PHY linkage are not yet
supplied; the latest retained comparison uses Vivado 2025.1 and an earlier source
revision. A matched resource comparison and timing evidence remain outstanding.
Reproduce part, linked IP, constraints, generics, tool version, strategy and flow
stage, retaining source/build provenance. Existing hardware accuracy, timing and
standards acceptance below remains separate.

## October 13 optimization candidates 1-4

The initial pass against SURF `52dfa266f`, now committed as `0d27ddbba`, implements counter consolidation,
six deeper block-RAM selections per endpoint and constant interval decoding.
Candidate 3 is deliberately limited to the ledger's mutually exclusive age
checks; protocol pair/history word serialization is covered by the follow-up
below. The [implementation decisions and build comparison](lut-optimization.md#october-13-candidate-implementation)
record what changed, why further serialization was deferred and the four retained
RTL increments. No register ABI, scan latency, service bound, clock domain or
physical packet path changes in this pass.

The RTL checklist review traced every rejection update/reset override, RAM
read/enables and version ownership, all three ledger operand selections,
modulo-age versus response-borrow handling, negative exponent rounding and
concurrent RX/held-response completion. Counter saturation has a 33-bit range
proof; the new RTL test checks two events on one edge and reset retention, but
does not force a near-saturated diagnostic register. The full 68-bit history
comparison and existing three-point jitter algorithm remain unchanged.

Tools: GHDL 6.0.0, Python 3.13.2, pytest 9.0.2 and cocotb 2.1.0 from the existing
`/Users/bareese/surf/.venv`, without modifying that environment. An initial
collection with the checkout's Python 3.9 environment failed on existing union
annotations before simulation. Subsequent batches use the established 3.13
runtime; final batches set `MallocNanoZone=1` per process. All runs use production
RTL through the existing fixtures, with at most four simulator workers total.

Evidence is local and ignored under `.planning/lut-candidates-2026-10-13/` in
SURF. All **20 distinct final configurations passed** across the selections
below; overlapping runs are counted once. Final selections are:

| Selection | Result / evidence |
| --- | --- |
| Ledger lifecycle, counters, cancellation, slot reuse, keys and deferred duplicate | 7 passed in `03-ledger.log`. |
| Ledger storage at depths 1/3/4 and both RAM mappings; new full-width age cases in both mappings | 6 passed in `03-age-rerun.log` (17.91 s). Age cases cover 32-/63-bit boundaries, near-maximum ticks, response-before-wire, zero, inclusive lifetime and lifetime+1, and eventual reclamation. |
| Concurrent malformed RX plus rejected E2E, and four-entry block ledger storage | 2 passed in `03-smoke.log` (35.72 s); ledger storage overlaps the preceding row. The concurrent case requires an exact +2 on one edge, retention across restart/AXI reset/RX abort, and reset priority. |
| All 256 Announce interval encodings under two caps, selected Sync bounds, and register bank at base 0 | 2 passed in `04-interval-banks.log` (124.41 s). Timers are checked at the inclusive deadline and deadline+1; register checks cover configuration byte writes/freeze/apply and coherent snapshots. Interval sweep uses 125 MHz. |
| Direct protocol collisions, capacity/chronology/cancellation and Announce snapshots in both table mappings | 2 configurations passed in `05-protocol-consumers.log` (90.18 s), with all three selected cocotb scenarios confirmed in each XML result. |
| Nearest-history selection with block RAM; delayed-response association | Both passed in `05-association.log` (457.56 s); response association covers fourteen requester/source/domain/generation mismatches and recovery, including held log-interval metadata. |

The first counter-only direct protocol run also passed both memory configurations
(all five cocotb scenarios), before later candidates were applied. Its log
`01-pytest.log` includes a subsequent compile failure in the queued concurrent
case: the new ledger concatenation needed an explicit `slv` qualification. That
was corrected before `03-smoke.log`. The initial two age cases failed at time
zero because the new fixture sampled unresolved outputs before reset; moving its
large-time jump after reset fixed the fixture, and both reruns passed. These
failures are superseded, not counted as passes. An accidental `-k age` selection
also selected the four `storage` nodes; all six executed and passed.

VSG passes all five edited VHDL files (689 rules each), using `vsg.log` for the
three bank/servo files and `vsg-final.log` for protocol/ledger after declaration
alignment and concatenation fixes. The three edited/new Python tests pass flake8
and the compliance audit. All seven changed Markdown files pass local link/anchor checks, and diff
whitespace passes. Source patch hashes and final file hashes are retained in
`source-manifest.json`; applying the four patches in order reconstructs the final
five RTL files exactly before the checkpoint commit.

No full PTP, endpoint/PHY, routed timing, physical CDC or hardware regression is
claimed. Vivado/VCS are unavailable on this host. GHDL checks do not demonstrate
BRAM inference, cell-level LUT savings or timing improvement. The matched build
comparison is still required before crediting any area reduction; protocol
scan serialization and candidates 5–8 remain outside this pass.

## October 13 protocol scan word arithmetic

Follow-up to `0d27ddbba`: `PtpProtocolEngine` replaces its full-width pair/history
age, distance and ordering arithmetic with one local 32-bit word ALU. Two row
owners arbitrate round-robin; the table readers retain independent RAM ports and
held admission-time inputs. The [implementation notes](lut-optimization.md#protocol-scan-word-arithmetic)
and [service bound](rtl-readability.md#shared-service-bound) describe cancellation,
68-bit signed distance, strict tie handling and the additional local cycles.
The ledger's live expiry checks and public register ABI are unchanged.

The RTL checklist review traced grant/DONE ownership, both RAM scanners waiting
without overwriting operands, inverse-borrow propagation, modulo age truncation,
three-word negation, inclusive limits, first-slot ties and abort priority over
result consumption. Valid RAM rows remain pinned throughout history selection.
Each new grant initializes scratch/carry/zero state; cancellation makes old
scratch unreachable. At most one competing row can delay either owner. The
256-clock local table allowance fits the existing 4,096-clock reserve, preserving
the 70,347,776-tick floor. This is a source-derived service bound.

Focused simulation uses GHDL 6.0.0 and the existing Python 3.13.2 / pytest 9.0.2 /
cocotb 2.1.0 environment at `/Users/bareese/surf/.venv`, with per-process
`MallocNanoZone=1` and at most four simulator workers. Local ignored evidence is
under `.planning/lut-scan-2026-10-13/` in SURF. All **nine distinct final
configurations passed** (eight protocol configurations and one GMII consumer);
overlapping runs are counted once.

| Selection | Result / evidence |
| --- | --- |
| Existing nearest-history selection and pair expiry/cancellation, block RAM | 2 passed in `01-smoke.log` (178.99 s). |
| Concurrent pair/history completion and full-width pair ages/oldest replacement, block RAM | 2 passed in `05-boundary-rerun.log` (28.71 s); overlap is also included in the extended restart check below. |
| History word boundaries in both RAM mappings | 2 passed in `06-history-boundaries.log` (136.27 s). Covers fractional ties across Q3/tick-word carries, unsigned bit 63, near-maximum ticks, and inclusive `2^61`-tick separation versus separation+1. |
| History cancellation during reads and new arithmetic stages, block RAM | 1 passed in `03-cancellation.log` (512.86 s), covering 16 cancellation offsets through reads, grant, age, limit, distance, negation, nearest comparison and DONE, plus generation recovery. |
| GMII adversarial port consumer | 1 passed in `04-gmii.log` (1,012.01 s); XML confirms only `adversarial_port` was selected. Covers conflicts, completed-row reuse, receipt expiry, Announce cancellation and held TX across restart. |
| Concurrent scan restart/recovery and E2E publication under continuous rejected RX, block RAM | 2 passed in `07-overlap-priority.log` (70.43 s); overlap is counted once across its initial and extended runs. |

The initial boundary batch `02-boundaries.log` exposed three fixture mistakes:
a RAM-enable hierarchy path, constant master timestamps rejected by the existing
chronology guard, and configured timeouts outside the documented `<2^62` range.
The fixtures were corrected; no behavioral RTL change was needed. Initial
failures are retained and superseded by the corresponding reruns above.

VSG passes all 689 rules for `PtpProtocolEngine` (`vsg-final.log`). The edited
Python test passes flake8 and the test compliance audit. Documentation link and
diff-whitespace checks pass (six changed Markdown files). No new HDL source or
manifest change is required. `05-protocol-scan.patch` and `source-manifest.json`
retain the exact baseline and source hashes; patch reconstruction against the
baseline was checked byte-for-byte. The follow-up remains unstaged for review.

No full PTP suite, XGMII or real-MAC endpoint regression, Vivado/VCS, routed timing,
physical CDC or hardware measurement is claimed. The GMII test uses the production
validator and endpoint with its existing direct PHY fixture. The narrower ALU
adds mux/control/scratch state; matched synthesis against `0d27ddbba` is required
to establish any net LUT/FF/carry or timing improvement.

## Outstanding acceptance

- Existing MAC RX IPv4 error handling: a successful IP/transport checksum check
  can overwrite an incoming EOFE. Observed in the default-enabled checksum
  fixture while testing this increment; native-L2 error propagation and the
  experimental disabled-offload path passed. That experiment is now reverted.
  Fix and test combined FCS/checksum failures in a
  separate MAC correctness change; this finding does not authorize a broader
  MAC rewrite as part of PTP area optimization.

The shared-service derivation replaces the former unexplained 2,048-cycle
association floor; see the [current scheduling contract](rtl-readability.md#shared-service-bound).
Document and justify the existing 200,000-ppb actuator cap before treating it
as a qualified hardware bound. The
[endpoint numerical envelope](autonomous-endpoint.md#port-policy-and-numerical-envelope)
records their distinct purposes, introducing revision and missing rationale.
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

No known-bad comparison was run for the registered-boundary change under the
gate. Prepared between-edge assertions are intended to detect the former
input-dependent controls; queue/metadata cases test the new storage ownership.
Record actual outcomes and source revisions here when execution is authorized.
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
variants under the October 9 authorization, retaining existing two-step coverage. Record
commands, parameters, source revision and outcomes here. The
[test guide](../../../tests/ethernet/PtpCore/README.md#autonomous-endpoint-tests)
indexes `test_ptp_port_samples.py`, `test_ptp_port.py`, RX fixtures,
`test_ptp_endpoint.py` and `test_ptp_endpoint_mac.py`; all new scenarios are
prepared; execution results are recorded above.

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

## October 13 critical-path implementation

The consuming KCU105 SFP-only routed baseline at SURF `8c97ed404` failed
setup timing (WNS -8.039 ns, TNS -12062.381 ns). Its worst paths ended in
TX/RX validation, protocol rejection counting, PHC time state and servo
cancellation. The changes address the validator, protocol, PHC and servo paths:

- `PtpDelayReqObserver` and `PtpRxFrontend` use shared TLV header lookahead.
  An eight-byte beat can finish at most two four-byte headers and begin a
  third; body bytes skip in one operation. The full 16-bit length, even-length
  rule, message bounds and partial-header state are retained. No extra input
  or publication latency is introduced. Contiguous keep masks decode directly;
  malformed masks remain rejected. Sticky validation errors join at EOF rather
  than gating the TLV arithmetic.
- A valid completion that overflows the logical queue no longer vetoes a
  simultaneous FWFT descriptor pop. That descriptor's decoder ownership is
  canceled on the same edge; registered FIFO reset discards the remainder
  next edge. This removes frame validation from FIFO ready without delaying
  its acknowledgement or changing pre-edge overflow/capture/abort semantics.
- Protocol rejection multiplicity is registered before the saturating sum.
  All same-edge events retire together one clock later. Logical cancellation
  and AXI reset preserve both pending events and accumulated diagnostics;
  system reset clears both. Register addresses and widths are unchanged.
- The PHC combines a PHASE remainder with the unnormalized ordinary tick and
  normalizes once, including a possible two-second carry. Carry-select word
  arithmetic shortens wide additions. SET/PHASE admission-to-commit latency,
  RATE commit-edge semantics, exact captures and fault policy are unchanged.
  Epoch validity is checked in parallel with the seconds sums, so late
  normalization selection does not feed back through seconds arithmetic to
  every time register enable.
- Protocol/servo unsigned age differences use the same bounded carry-select
  helper. A carry-save reduction evaluates age against the limit without
  cascading a full subtraction and comparison. Modulo age, inclusive timeout
  boundaries and cancellation edges are
  unchanged. The passing shared compute datapath is unchanged.

The implementation is recorded in SURF commits `95072a228` (PHC and age
arithmetic), `f61c53dc1` (rejection diagnostics), and `807a52346` (wire validators).
All 18 selected final-pass regression configurations pass: RX/observer (6),
PHC (2), concurrent rejections (2), timing math (3), protocol expiry/word
boundaries (2), block-RAM port samples (1), signed Announce intervals (1), and
125 MHz servo (1). PHC coverage includes every normalization branch at both
epoch limits, mixed-sign whole/remainder operands, and ordinary epoch exhaustion.
Counter coverage checks delayed double increments and pending-event survival
across abort. Math uses independent integer boundary/random oracles.

Three RX compiles initially raced a source edit and passed on rerun. First-pass
counter/interval assertions were updated for the documented diagnostic latency
and passed. VSG reports zero violations in the six edited RTL files and new
wrapper; the normal ruckus GHDL import passes. The compliance audit still reports
pre-existing helper/test findings, including two PHC findings reproduced against
HEAD before these changes. The full PTP suite and final-pass endpoint/MAC
integration have not run. Previously launched first-pass endpoint simulations
were still running at this handoff and are not counted as passing evidence.

Both isolated comparisons use `rdsrv419`, Vivado 2025.2, `COPPER_EN=false`, and
four synthesis workers. Each starts from a clean recursive clone at consuming
project `6adf1d076` and SURF `8c97ed404`, then applies a recorded six-file RTL
patch. Run directories are
`/u1/bareese/agent-builds/ptp-dev/20261013-timing-fixes-r1` and
`/u1/bareese/agent-builds/ptp-dev/20261013-timing-fixes-r2`; local raw evidence is
under the consuming project's ignored `.planning/remote-builds/` with matching
run names. All six final RTL hashes match the second-pass source manifest;
committing the files did not change their contents. No clock constraints or PHY
implementations were changed. These are combined-pass comparisons, not isolated
per-commit timing attribution.

| Routed metric | Baseline | First pass | Final pass |
| --- | ---: | ---: | ---: |
| Setup WNS (ns) | -8.039 | -2.472 | -2.829 |
| Setup TNS (ns) | -12062.381 | -3204.606 | -3123.079 |
| Failing setup endpoints | 4120 | 3117 | 3587 |
| Hold WHS / THS (ns) | +0.030 / 0 | +0.030 / 0 | +0.030 / 0 |
| LUTs | 51824 | 53100 | 52066 |
| Registers | 58857 | 58840 | 58844 |
| BRAM tiles / DSPs | 33.5 / 9 | 33.5 / 9 | 33.5 / 9 |

Worst setup slack by destination hierarchy (paths can originate elsewhere):

| Destination | Baseline (ns) | First pass (ns) | Final pass (ns) |
| --- | ---: | ---: | ---: |
| TX validator | -8.039 | -2.472 | -2.715 |
| RX validator | -7.497 | -2.445 | -2.829 |
| Protocol | -4.675 | -2.429 | -2.482 |
| PHC | -1.477 | -1.258 | -0.599 |
| Servo | -0.248 | +0.005 | +0.134 |
| Compute | +1.107 | +0.933 | +1.095 |
| Host | +0.619 | +0.344 | +0.508 |

The final pass improves WNS by 5.210 ns and reduces TNS magnitude by 74.1%
against baseline, with 242 additional routed LUTs (0.47%). It improves PHC and
servo slack and reduces LUT count relative to the first pass, but worsens overall
WNS by 0.357 ns and increases failing endpoint count. **Timing remains failing**
(make exit 2); all 96,546 routable nets route with no routing errors or black
boxes. The final routed checkpoint SHA-256 is
`3bdd3b827c40a8edc4fcb68eb2b5ccea6fab565c4d5cc8257a801feb26af24e5`.
The native and independently generated routed timing summaries agree.

Next timing work is still validator completion/control: the worst RX path runs
from frame count to accepted-counter enable (36 logic levels, 10.576 ns data
delay), and TX from frame count to the FIFO-write register reset (33 levels).
Protocol's worst path now starts at the compute memory cursor and ends at
`announceValid` (24 levels); PHC still has a fraction-to-raw-tick-enable path
(17 levels). These are candidates for further control/arithmetic separation,
with the existing capture, cancellation and overflow contracts preserved.
`ptpAddFast` uses fabric arithmetic; DSP inference has not been implemented or
benchmarked. Constraint/CDC/DRC review, copper-enabled implementation, external
interoperability and hardware acceptance remain open.
