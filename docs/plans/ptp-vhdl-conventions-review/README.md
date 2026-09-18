# PtpCore VHDL conventions review

## Goal and scope

Review and fix all 15 RTL/package files and seven wrappers in `ethernet/PtpCore`
against the current [SURF VHDL conventions](../../vhdl-conventions.md), including
the [PTP timing supplement](../ethernet-ptp/rtl-readability.md). Preserve public
interfaces and transaction timing while addressing the recorded findings.

## Status

Review completed against source revision
`c3170db49d74a16566a3b7a3e2feee12eeb2feee` on 2026-09-17. All 22 VHDL files
were read. The user subsequently authorized fixes, now implemented for R1-R6
and the scoped readability follow-up. Production interface names, generic
order/defaults and register ABI are preserved. Behavioral validation still
awaits maintainer VHDL approval. Findings below retain the original review
context and source line numbers; this document remains the validation handoff.

## Implemented changes

- R1: `EthMacPtpEndpoint` asserts the supported GMII/125 MHz and
  XGMII/156.25 MHz generic pairs; its clock-frequency comment states Hz.
- R2: `PtpTxLedger` asserts `DEPTH_G <= 255`, retaining depth-one support and
  the existing eight-bit occupancy/unresolved status fields.
- R3: PHC and port arithmetic request-valid fields are initialized and
  registered with their operands from resolved next state, then published from
  `r`. Shared cancellation and reset priorities remain in place.
- R4: Immediate controls are resolved in local variables or `v`, then published
  unconditionally. FIFO enables, overflow, response acceptance, lifecycle,
  snapshots and reset/event assembly retain their existing edge relationships.
- R5: Calculation-only fields moved from `RegType` to bounded process locals.
  Inspection checked assignment before use, including paths with whole-record
  initialization or cancellation; retained diagnostics and snapshots remain.
- R6: PHC-reader, port and servo ready controls belong to the owning record,
  are recomputed each evaluation, and publish from `v`. Disabled-servo draining,
  idle readiness and cancellation/reset suppression retain their priorities.
- Readability: Expanded RX headers and clock-domain grouping; reordered only
  the simulation register wrapper's ports after finding no VHDL instantiations;
  expanded command boundary wiring and snapshot associations; expressed timeout
  factors as multiplication with the original truncation widths. Kept public
  endpoint generic order for positional compatibility and documented that choice.

## Validation and constraints

The existing [PTP validation gate](../ethernet-ptp/README.md#current-validation)
prohibits simulation and pytest regressions until maintainer VHDL approval.
All 22 files pass `./.venv/bin/vsg -c vsg-linter.yml -f <file>`. The final layout
and named-factor edits were checked again in their affected files. Full lint
output is temporarily available at `/private/tmp/ptp-conventions-final-vsg.log`.

GHDL 6.0.0 compiled/linked all 21 entities/wrappers, including
`EthMacPtpEndpoint`, using VHDL-2008, Synopsys IEEE and relaxed-rule options.
Sources were freshly imported with
`make MODULES="$PWD" OUT_DIR=/private/tmp/ptp-conventions-build-7cubpyge import`.
The non-Vivado import intentionally omits most MAC sources, so compile/link
also imported `EthMacCore/rtl` (excluding the already imported package) and
`DspXor.vhd`, matching the existing Ethernet test helper's MAC dependency list.
Only `ghdl -i` and `ghdl -m` were used; no built executable was run. Final
wrapper/factor edits were rechecked through the PHC wrapper and both endpoint
integration tops. Temporary build output and log:
`/private/tmp/ptp-conventions-build-7cubpyge/compile.log`.

Source inspection covered state/output ownership, process structure,
ready/valid and cancellation timing, reset/CDC, arithmetic, register-map
structure, wrapper boundaries and readability. Nearby `FifoAsync`, `RstSync`,
AXI adapter and existing test sources were inspected where relevant. Existing
PyRogue/RTL schema tests were read, not executed; this is not a fresh verification
of every software field. No simulation, pytest, synthesis, staging or commit was
performed. Lint/build checks do not establish behavioral equivalence, exercise
the new invalid-generic assertions, or qualify FPGA timing/resources.

While resolving build dependencies, static inspection also found a pre-existing
test-harness issue: five PTP tests import `ROCE_ANALYSIS_SOURCES` from
`tests/ethernet/EthMacCore/ethmac_test_utils.py`, which does not define that name.
This is outside the VHDL findings and remains a prerequisite to collecting those
tests after approval; the compile/link smoke checks did not import Python tests.

## Parameter-contract findings

### R1: Reject incompatible PHY and clock-frequency settings

[EthMacPtpEndpoint.vhd](../../../ethernet/PtpCore/rtl/EthMacPtpEndpoint.vhd),
lines 50-51 and 132, exposes independent `PHY_TYPE_G` and `CLK_FREQ_G` settings
but asserts only that the PHY name is recognized. The documented integration
contract requires 125 MHz for GMII and 156.25 MHz for XGMII.

Selecting only `PHY_TYPE_G => "GMII"` leaves the nominal frequency at
156250000. On the required 125 MHz GMII clock, the PHC then advances about
6.4 ns per 8 ns edge: about 0.8 seconds per real second. The port also builds
its rate-estimation acceptance window around that wrong nominal value, so its
200 ppm qualifier cannot recover this configuration. This follows directly
from `PtpPhc` line 119 and `PtpPort` lines 205-206 and 947-948; it was not
simulated. Existing MAC tests explicitly supply the matching frequency.

Add an elaboration assertion for the supported PHY/frequency pairs at the MAC
composition boundary. Preserve the existing generic interface/defaults and keep
standalone arithmetic/PHC test clock choices separate from this physical-MAC
constraint. This implements the conventions' [generic relationship checks](../../vhdl-conventions.md#source-layout-and-checks).

### R2: Bound ledger depth to its status representation

[PtpTxLedger.vhd](../../../ethernet/PtpCore/rtl/PtpTxLedger.vhd), line 52,
allows any positive `DEPTH_G`. Lines 303-309 count occupied and unresolved
entries into eight-bit status fields. With `DEPTH_G => 256` and the default
16-bit sequence space, 256 retained entries wrap either applicable count to
zero. Software can therefore observe zero unresolved entries while the ledger
is full. The allocator searches entries independently, so this finding concerns
incorrect diagnostic reporting, not demonstrated premature key reuse.

Constrain/assert the maximum supported depth to 255 while preserving the
existing status ABI, or explicitly define saturation if larger tables are
intended. Retain depth-one support. This follows the same generic-range rule
and the [arithmetic width/overflow guidance](../../vhdl-conventions.md#make-the-calculation-readable).

## Conformance findings

### R3: Register the remaining state-decoded arithmetic request-valid signals

[PtpPhc.vhd](../../../ethernet/PtpCore/rtl/PtpPhc.vhd), lines 252 and 330-334,
defaults `mathInputValid` low and asserts it while decoding `r.manualState`.
[PtpPort.vhd](../../../ethernet/PtpCore/rtl/PtpPort.vhd), lines 640 and 939-943,
does the same for `rateInput` and `r.state`. Neither signal has its own registered
field, although the operands are registered and these are internal interfaces
to `PtpMath`.

This is the exact state-decode pattern prohibited by
[signal assignments in comb](../../vhdl-conventions.md#signal-assignments-in-comb).
Add a valid field to each owning record and derive it from the resolved next
state before publishing it from `r`, as already done in `PtpE2e` lines 245-261
and `PtpServo` lines 685-690. Preserve the existing issue/acceptance edge,
operand alignment, cancellation and system-reset priority. Registering a decode
of old `r.state` would introduce an unwanted extra cycle. No existing handshake
failure is claimed solely from these combinational decodes.

### R4: Resolve immediate decisions before unconditional publication

The timing exceptions are documented, but the same convention explicitly says
that exceptions still require unconditional publication. These processes retain
default-and-override signal assignments or decisions on the right of `<=`:

| Source | Remaining pattern |
| --- | --- |
| [PtpPhcRead.vhd](../../../ethernet/PtpCore/rtl/PtpPhcRead.vhd), 223-249 and 269-279 | Conditional `readReady`, request/response FIFO enables, and reset-qualified `readValid` expression. |
| [PtpTxLedger.vhd](../../../ethernet/PtpCore/rtl/PtpTxLedger.vhd), 159, 230, 280 | Conditional response-acceptance output with a final restart override. |
| [PtpRxFrontend.vhd](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd), 201, 389 | Conditional overflow publication during queue admission. |
| [PtpPort.vhd](../../../ethernet/PtpCore/rtl/PtpPort.vhd), 635-640, 703-711, 761, 983-1001, 1039-1041 | Allocation, E2E admission/payload selection and ready controls assigned throughout the algorithm; lifecycle record default/override; Boolean-qualified measurement valid. |
| [PtpReg.vhd](../../../ethernet/PtpCore/rtl/PtpReg.vhd), 261 | `ptpSatInc(r.snapshotSequence)` performs arithmetic/saturation in the output assignment. |
| [PtpEndpoint.vhd](../../../ethernet/PtpCore/rtl/PtpEndpoint.vhd), 145-163 | Conditional AXI reset and servo-fault event, plus Boolean RX-flush composition in publication. |
| [PtpRegWrapper.vhd](../../../ethernet/PtpCore/wrappers/PtpRegWrapper.vhd), 149-171 | Conditional bank-control overrides, AXI reset and event assembly, plus snapshot-inhibit composition. |

Compute each control in `v` or justified, fully assigned local scratch, then
publish it once near the process end. Preserve same-edge overflow, lifecycle,
capture cancellation, FIFO transfer and snapshot semantics. For example,
moving `responseAccepted` or `queueOverflow` directly to `r` would change the
connected transaction; this finding does not authorize that retiming. The
structural endpoint and test wrapper need no artificial state record.

### R5: Separate temporary calculations from retained state

Several `RegType` blocks label fields as current-cycle calculations and
diagnostics, but the implementation never reads their registered `r` values:

| Source | Examples |
| --- | --- |
| [PtpMath.vhd](../../../ethernet/PtpCore/rtl/PtpMath.vhd), 70-73 | `magnitude`, `limitValue`. |
| [PtpServo.vhd](../../../ethernet/PtpCore/rtl/PtpServo.vhd), 202-208 | `sampleTickDelta`, `frequencyCandidate`, `integralDelta`, `stale`, `acceptSample`, `integrate`. |
| [PtpRxFrontend.vhd](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd), 97-105 | `completedMessage`, `frameComplete`, `byteCount`, `crcData`, `keepGap`. |
| [PtpRxTimestampAdapter.vhd](../../../ethernet/PtpCore/rtl/PtpRxTimestampAdapter.vhd), 77-80 | `byteCount`, `captureLane`. |
| [PtpTxLedger.vhd](../../../ethernet/PtpCore/rtl/PtpTxLedger.vhd), 117-120 | `freeSlot`, `collision`. |
| [PtpPrimaryGuard.vhd](../../../ethernet/PtpCore/rtl/PtpPrimaryGuard.vhd), 59-62 | `discard`. |
| [PtpReg.vhd](../../../ethernet/PtpCore/rtl/PtpReg.vhd), 77-79 | AXI submission scratch `commitRequest`, `snapshotRequest`, `irqClear`. |

The [state and process-variable guidance](../../vhdl-conventions.md#state-and-process-variables)
allows local scratch assigned before use and discourages storage added only to
eliminate temporaries. Move calculation-only fields to bounded local variables.
If specific fields are intentionally retained waveform diagnostics, identify
their purpose individually instead. `PtpPort.lastSync` already does this.

Keep real retained state, snapshots and the explicit combinational-ready
organization. Do not infer a resource saving from source alone: synthesis may
already eliminate unobserved registers, and useful diagnostic storage is an
allowed exception.

### R6: Finish applying the combinational-ready organization

[PtpPhcRead.vhd](../../../ethernet/PtpCore/rtl/PtpPhcRead.vhd), lines 223-228,
has no `readReady` record field. [PtpPort.vhd](../../../ethernet/PtpCore/rtl/PtpPort.vhd),
lines 718-727, publishes local `readyRx`; lines 983 and 1001 assign the reverse
ledger/E2E ready controls directly. [PtpServo.vhd](../../../ethernet/PtpCore/rtl/PtpServo.vhd),
lines 348, 413, 655-672 and 777, computes/publishes local `measurementReady`.

The [combinational-ready rule](../../vhdl-conventions.md#combinational-ready-outputs),
including its scalar-interface example, calls for keeping ready or its slave
record in the owning `RegType`, defaulting and resolving it through `v` beside
admission, then publishing it from `v`. `PtpMath`, `PtpE2e`, `PtpPrimaryGuard`
and `PtpTxLedger.allocateReady` already follow this organization.

Apply that pattern without changing idle readiness, disabled-servo draining,
reset/cancel suppression or holdover priority. This is a style/ownership gap;
it is not evidence that these existing ready signals are functionally late.
The documented owner-qualified PHC command-response projection is a separate
same-type control-record exception and should retain its shared completion owner.

## Lower-priority readability follow-up

- `PtpRxFrontend` and `PtpRxTimestampAdapter` still have one-line descriptions
  at line 4. Expand them with their processing stages and the already documented
  non-backpressurable byte input, capture alignment, queue and abort/reset
  contracts. The same header improvement applies to `PtpRxFrontendWrapper`.
- `PtpRegWrapper` lines 39-44 put synchronous fixture controls before `clk/rst`;
  `PtpPhcRead` lines 46-52 and `PtpPhcWrapper` lines 94-96 would benefit from
  explicit domain separators. Follow the clock/reset-first port guidance and
  check positional users before any reordering.
- `PtpEndpoint` and `EthMacPtpEndpoint` put `AXIL_BASE_ADDR_G` ahead of the common
  timing/reset generics. Reordering is lower priority and must account for public
  positional associations.
- `PtpPhcWrapper` line 130 compresses three nested initialization associations
  onto one line. `PtpPort` lines 1164-1165 similarly compress the snapshot-counter
  aggregate. Keep one association per line under the updated layout guidance.
- `PtpPort.receiptTimeout` line 469 expresses three intervals as addition plus
  a shift, and lines 880-881/1024 use a shift for the two-times Announce cap.
  Multiplication by the named duration factor would better match the arithmetic
  readability guidance; retain intermediate widths and overflow behavior.

## Patterns to preserve

- Behavioral domains have separate comb/seq pairs; `PtpPhcRead` has distinct
  reader and PHC records and reuses SURF FIFOs/reset synchronizers. Its naming
  differs from the guide's example, which is not itself a functional defect.
- AXI banks remain local to PHC, port and servo; endpoint helpers, explicit
  hexadecimal offsets and named crossbar destination indices are already used.
  Prepare captures candidate/vote together from pre-edge shadow values.
- Servo commands, math/E2E results and ledger sample-valid have registered
  ownership; preserve the shared cancellation contracts when addressing R3/R4.
- The port preserves already offered AXI TX beats across logical restart, and
  the primary guard preserves complete records through stalls. Physical RX is
  explicitly always consumed and does not pretend to provide backpressure.
- Immediate capture/overflow/lifecycle controls, queue-head selection, frozen
  snapshots, boundary flattening and primitive inference have documented
  reasons. Avoid adding pipeline stages or duplicate output storage to them.
- Wrappers use production cores and existing bus adapters; fixtures contain
  topology and record conversion rather than replacement protocol/arithmetic
  engines. Ruckus loads RTL and marks wrappers simulation-only.

## Next steps

After maintainer VHDL approval, repair the pre-existing test-helper imports and
run the focused regressions. R1/R2 need accepted/rejected PHY/frequency pairs and
ledger depths 1, 255 and 256 checked; R3/R4/R6 need handshake, cancellation,
reset, backpressure, overflow and snapshot/integration coverage. R5 needs the
existing arithmetic, RX and ledger regressions. The current simulation gate
remains in force; these fixes do not approve or execute those regressions.
Hardware timing, resources and physical CDC qualification remain open.
