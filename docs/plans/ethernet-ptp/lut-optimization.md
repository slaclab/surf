# PTP logic and storage optimization

October 9, 2026. Goal: reduce combinational logic while preserving numerical,
packet-validation, queue and cancellation behavior. The maintainer reported
high LUT use relative to registers; synthesis reports are on another machine.
Optimization baseline: SURF `6db41ad53ed5d17491fcfddfcff30325755d244f`. Subsequent
FIFO validation uses `2bb198b10efc964f1d861ebc34a33d214052afd7` plus the local
optimization patch. Independent protocol/specification changes are outside
this optimization. The October 11 placed reports provide the area reference.
The October 12 review of the later synthesis reports below confirms ledger
LUTRAM use and substantially smaller ledger counts; a controlled comparison
at the same implementation stage and timing acceptance remain outstanding.
The later October 12 synthesis screenshot shows a 28.64% reduction in the
copper protocol engine after the two table conversions; its analysis below
includes the RAM children and distinguishes whole-design changes.
The subsequent servo implementation below shares clamp/rounding arithmetic
and serializes the median; its FPGA area/timing comparison remains pending.

## Implemented changes

| Module | Change | Preserved behavior |
| --- | --- | --- |
| `PtpServo` | Nine fixed compare/swaps replace the five-pass, four-comparison-per-pass bubble sort | Same-cycle sample admission; lower median of populated samples; all Q16 bits; circular replacement |
| `PtpRxFrontend` parser | Align each beat once, write fixed prefix bytes, and compute frame byte count once | Contiguous partial beats of widths 0 through 8, sparse-keep rejection, saturated frame count and no input backpressure |
| `PtpRxFrontend` header/TLV | Cache base/message end before the first TLV; bound remaining count by frame capacity | Validate all 16 received length bits before narrowing; permit split headers, zero-length TLVs and multiple transitions per beat |
| `PtpRxFrontend` queue | SURF synchronous FWFT FIFO replaces the custom payload queue; register writes and retain the output head | Exact logical capacity including pipeline stages, stalls, simultaneous consume/enqueue, full-before-edge discard-all, reset/flush, generation and epoch rules; delivery now takes three clocks after completion |
| `PtpPkg` | Paired 809-bit lossless storage helpers | Existing 744-bit verification format stays unchanged; capture increment/error now survive memory transport |

Enduring interfaces and implementation rationale belong in the
[source guide](../../../ethernet/PtpCore/README.md) and
[RX queue contract](autonomous-endpoint.md#rx-queue-storage).
The public production ports, register ABI, arithmetic scaling and command
lifecycle are unchanged. No manifest change is required: all edited RTL and
the reused `Fifo` already belong to the source import.

The median sorts a scratch copy of the circular history. Unpopulated entries
use signed64 maximum, then counts one/two select index zero, three/four index
one, and five index two. A populated maximum-valued sample can tie the sentinel
without affecting the result. The network is:

```text
(0,3), (1,4), (0,2), (1,3), (0,1), (2,4), (1,2), (3,4), (2,3)
```

The queue accepts the synchronous FIFO's latency instead of retaining custom
asynchronous RAM control. A registered completion passes through the FIFO's
write and FWFT read before entering the head three clocks after EOF. Logical
occupancy includes all stages, independently of the FIFO's larger physical
allocation. Writes/reset publish from `r`; the read acknowledgement uses the
documented SURF FWFT consumer pattern. Reset clears validity without clearing
payload RAM. Include the write register, FIFO output register and head in
synthesis comparisons. The initial `LutRam` version and its registered-write
follow-up are superseded; preserving their immediate head delivery is no longer
a requirement. Public ready/valid, abort priority and capture timestamps remain
unchanged.

## October 11 ledger storage and counter pass

Source baseline: SURF `1bd476a89cac78f5945007b8975ef95755899a8d`. The consuming
`ptp-dev` repository preserves supplied reports in
`docs/reference/ptpkcu105-utilization-2026-10-11/`, added by `d4f94c9`.
They describe Vivado 2025.2, `xcku040-ffva1156-2-e`, after placement; routing did
not complete. They do not embed the exact source revision/patch or complete
strategy, so confirm those before attributing a later difference to this pass.

| Placed reference | LUTs | FFs | DSPs |
| --- | ---: | ---: | ---: |
| SFP lane, including MAC/PHY | 53,802 | 39,009 | 48 |
| SFP protocol engine, own logic | 15,954 | 11,827 | 30 |
| SFP TX ledger | 6,959 | 3,566 | 0 |
| SFP servo, own logic | 7,817 | 3,932 | 0 |
| Copper TX ledger | 6,931 | 3,566 | 0 |

These rows mix parent totals and explicitly exclusive own-logic rows; do not
sum them. Both ledger instances benefit from the same reusable source change.

`PtpTxLedger` now puts the entire 636-bit entry in synchronous
`SimpleDualPortRam`, distributed by default with an optional block setting at
the leaf. The wide `r.entries` array is removed. Four ownership bits per slot
remain in registers so restart/reset can invalidate associations immediately
without clearing memory. A shared scan replaces the parallel key comparisons,
age arithmetic, record updates and chained counter increments. Each row is
visited every `2*DEPTH_G+2` clocks, ten at the default depth four.

Wire and response records remain stable through explicit ready/valid handshakes
at the end of the scan. Completion readiness is wired through the protocol and
endpoint to the existing TX tap queue. The protocol holds a response and its
log interval until the ledger acknowledges it. Those low-level entity interfaces
now require ready wiring; the MAC/PHY wrapper interfaces, software ABI and
numeric precision are unchanged. The [ledger storage contract](autonomous-endpoint.md#tx-ledger-storage)
owns timing, capacity, simultaneous-event priority and cancellation rules.

Only one row contributes to each diagnostic update. Local rejection events are
summed before one 33-bit saturating addition; timeout has one increment site.
For initial count `c` and nonnegative events `e`, repeated saturation equals
`min(2^32-1, c+e)`. The local event bound is two, so the carry is retained at the
maximum count. This is an arithmetic bound, not a billions-of-events simulation
or a measured LUT saving.

The [October 11 checks](rtl-review.md#october-11-ledger-optimization-checks)
record leaf and consumer evidence. Existing ruckus manifests already load all
modified entities and the reused RAM selector; no source-list change is needed.

Next step: compare both ledgers in the same Vivado configuration, including
LUT-as-logic, LUTRAM, FF, carry, BRAM and critical paths. Account for the write
register, RAM read register and retained sample; 636 bits per slot is a storage
width, not a promised resource reduction. The later synthesis evidence below
confirms LUTRAM use; placement and timing remain to be compared.
The storage review below identifies the next RAM candidates. Shared protocol
timestamp conversion and the servo's local clamp/median logic remain separate
arithmetic follow-ups, outside this ledger pass.

## October 12 synthesis report review

`ptp-dev` commit `5061265` adds the October 11 23:42 synthesis summary and
23:44 hierarchy under
`docs/reference/ptpkcu105-utilization-2026-10-11/synth-gtrefclk1/`.
The report-bearing commit pins SURF `69c9e59f8a8bd456d831f6bb24fc875683bd5f5e`,
which includes the ledger conversion `80aa5fdee`. This is repository provenance;
the reports themselves do not embed the exact build revision/local patch.
The run uses the same Vivado 2025.2 and KU040 part as the earlier reports, but
also changes the GT reference selection/checkpoint and uses a clean project.

The whole-design totals can be compared at synthesis in both runs:

| Resource | Earlier synthesis | Later synthesis | Difference |
| --- | ---: | ---: | ---: |
| Total CLB LUTs | 133,016 | 121,455 | -11,561 (-8.69%) |
| Logic LUTs | 129,605 | 117,316 | -12,289 |
| Distributed RAM LUTs | 2,930 | 3,658 | +728 |
| Registers | 110,435 | 105,799 | -4,636 (-4.20%) |
| CARRY8 | 5,801 | 5,313 | -488 |
| Block RAM tiles | 32 | 32 | 0 |
| DSPs | 101 | 101 | 0 |

Both ledgers now contain 364 LUTRAMs and no BRAM. Their combined 728 LUTRAMs
match the design-wide distributed-RAM increase. The retained earlier hierarchy
is **placed**, while the new hierarchy is **synthesized**; the following ledger
comparison is therefore an observed difference across stages, not an isolated
measurement of the refactor:

| Ledger | Earlier placed LUTs / FFs | Later synthesis LUTs / FFs | LUT difference |
| --- | ---: | ---: | ---: |
| SFP | 6,959 / 3,566 | 1,804 / 1,853 | -5,155 (-74.08%) |
| Copper | 6,931 / 3,566 | 1,801 / 1,853 | -5,130 (-74.02%) |

Each ledger has 1,713 fewer reported FFs (-48.04%). The later LUT totals already
include RAM: SFP is 1,440 logic plus 364 LUTRAM; copper is 1,437 plus 364.
This supports the RAM/shared-scan architecture, but do not subtract the mixed
stage ledger difference from the synthesis-only design difference to attribute
the remainder. Neither report pair isolates the reference-clock, project-state
and RTL changes. Both synthesis summaries also retain three PHY/core black
boxes, so these totals are not a fully linked implementation result. No later
placement, routing or timing result is supplied.

The remaining targets are clearer in the new hierarchy:

| Later synthesis block | SFP LUTs / FFs | Copper LUTs / FFs |
| --- | ---: | ---: |
| Protocol engine, own logic only | 15,281 / 11,272 | 15,852 / 11,282 |
| Servo, own logic only | 7,868 / 3,935 | 7,865 / 3,935 |
| E2E, including its math child | 4,094 / 2,106 | 4,067 / 2,106 |
| RX timestamp tap, including validator/FIFO | 3,911 / 3,656 | 3,868 / 3,656 |

The protocol engine's own logic excludes ledger, E2E and rate math; the servo's
own logic excludes its math child. The two protocol engines and two servos'
exclusive logic together use 46,866 LUTs, 38.59% of the synthesis design total.
Both complete PTP lanes use 97,937 LUTs, 80.64% of that total. The ledger is no
longer a leading hotspot. Keep the next storage work ordered as Sync history,
then Sync/Follow_Up pairing; the servo remains a separate arithmetic-sharing
candidate. The following implementation section records the subsequent conversion;
these supplied reports predate it.

## October 11 remaining RAM and FIFO candidates

Reviewed source: SURF `80aa5fdee396fbe40a96cbb1291fb6fd5d1633fc`, after the ledger
conversion. This source/access-pattern review selected the first two changes
implemented on October 12 below. The later synthesis screenshot supplies area
evidence for the copper instance; timing remains open. The placed reference above attributes 15,954 LUTs
and 11,827 FFs to the SFP protocol engine's own logic, excluding its ledger,
E2E and rate-math children. It does not separate the arrays below, so those
totals are not an estimate of recoverable area.

| Status | Storage | Original declared payload/state | SURF approach and main tradeoff |
| --- | --- | --- | --- |
| Implemented October 12 | `PtpProtocolEngine.history` | Four 485-bit Sync samples: 1,940 bits, plus validity/pointer | `SimpleDualPortRam`, synchronous distributed RAM, with a shared nearest-sample scan; introduces lookup latency and writer arbitration |
| Implemented October 12 | `PtpProtocolEngine.pairs` | Four 682-bit records: 2,728 bits including flags and constant fields | `SimpleDualPortRam` with serial lookup/read-modify-write; keep ownership flags in registers and share expiry/key/replacement comparisons |
| Conditional | `PtpServo.delays` | Five signed64 samples: 320 bits | Serialize the median comparison work first; RAM requires changing the all-at-once access pattern and may not justify its staging/control cost at depth five |
| Lower | `PtpRxFrontend.frame.prefix` | 78 bytes: 624 bits per frontend | Banked/byte-enabled RAM plus staged decoding; must support partial beats, eight incoming bytes per clock and an unbackpressured wire input |

These are source widths, not predicted FF savings. Synthesis can discard
constant and unused fields; RAM read/write registers and retained results must
be included in comparisons. In particular, each pair's nested 128-bit
`sample.correction` stays zero: the two wire corrections live in separate
64-bit fields and are combined only when the pair completes. Excluding that
constant and the five flags leaves at most 549 payload bits per pair before
other pruning. Do not count removing the constant member as a new area saving.

### Existing FIFOs and lower-priority storage

Both RX and TX observation already instantiate the frontend's synchronous
distributed `surf.Fifo`. The SFP placed reference reports 454 LUTs for the RX
queue (440 LUTRAM, 14 logic) and 231 for the TX queue (216 LUTRAM, 15 logic).
The enclosing validators' own logic is 3,348 and 2,375 LUTs respectively;
another FIFO substitution would not address most of that logic. The portable
FIFO allocates at least 16 physical locations while logical capacities are
four RX and two TX records. Review physical allocation and retained pipeline
copies if measurements warrant it, preserving the documented capacity,
overflow/flush and output-stability contract. Shallower allocation alone does
not establish a LUTRAM reduction.

The servo median reads all five samples through nine compare/swaps. Its next
likely improvement is sharing that comparator work, even if the 320-bit history
initially stays in registers. The RX prefix similarly feeds simultaneous field
decoding and same-beat completion; a RAM design needs input banking and overlap
between decoding the old frame and receiving the next. Neither is a direct
array-to-RAM substitution. Configuration candidate/active banks and coherent
snapshots also have distinct lifetimes and simultaneous consumers; do not
merge them merely because their record types match.

## October 12 protocol table conversion

Implemented in SURF `191d733c1031e5b86643f67816f41adf958db130`, based on
`3f5b468ff3c0e99b33fa36c80850658d77c2e341`. `PtpProtocolEngine` now uses two
synchronous `SimpleDualPortRam` instances: 485 bits by four rows for completed
Sync history and 549 bits by four rows for pairing payloads. Both default to
distributed memory, with block selectable through engine generics. The history
array, pair array and parallel lookup/expiry/replacement functions are removed.
Only history validity/pointer and pair ownership/mode flags remain parallel.

Each shared evaluator processes one row every two clocks. Pairing acknowledges
RX after lookup, applies the existing collision/retirement policy to one row,
and writes the whole row. History reuses the existing held E2E sample for the
winner, while the last accepted Sync drives the history write port. Thus neither
conversion adds a second input payload queue. The
[association storage contract](autonomous-endpoint.md#protocol-association-storage)
owns the precise acknowledgement, append arbitration, scan-time expiry and
cancellation behavior. Public ports, register ABI and arithmetic precision stay
unchanged; optional memory generics are added at the engine and direct fixture.

The direct wrapper exposes raw capture phase for boundary verification. Existing
ruckus directory imports already contain both changed VHDL files; no new HDL
source or manifest entry is needed. The
[verification record](rtl-review.md#october-12-protocol-table-checks) records
focused checks and their limits. GHDL synthesis recognizes the two RAMs and the
existing 636-bit ledger RAM; ignored vendor attributes mean this is structural
evidence, not a Vivado utilization or timing result.

The subsequent screenshot below supplies a synthesis comparison. Retain its
full reports and build configuration next, including LUT-as-memory and timing
details. Keep servo and parser follow-ups separate so their savings can be
attributed independently.

## October 12 protocol-table synthesis screenshot

The maintainer supplied a newer Vivado hierarchy screenshot on October 12 and
confirmed it is **post-synthesis**, matching the stage of the October 11 23:42
baseline above. The consuming workspace records the supplied values in
`docs/reference/ptpkcu105-utilization-2026-10-11/README.md`. New text reports,
exact build revision/local patch, tool version/strategy, black-box status and
timing results are not present. SURF `191d733c1` contains the table changes;
that repository association is not a build identifier from the screenshot.

| Scope / resource | Earlier synthesis | New screenshot | Difference |
| --- | ---: | ---: | ---: |
| Whole design LUTs | 121,455 | 111,777 | -9,678 (-7.97%) |
| Whole design FFs | 105,799 | 108,479 | +2,680 (+2.53%) |
| Whole design CARRY8 | 5,313 | 5,001 | -312 (-5.87%) |
| Copper lane LUTs / FFs | 49,249 / 36,546 | 43,152 / 36,358 | -6,097 / -188 |
| Copper PtpEndpoint LUTs / FFs | 37,227 / 23,918 | 30,634 / 23,125 | -6,593 / -793 |
| Copper protocol engine, including children, LUTs | 23,532 | 16,792 | -6,740 (-28.64%) |
| Copper protocol engine, including children, FFs | 16,035 | 15,234 | -801 (-5.00%) |
| Copper engine own logic plus table RAMs, LUTs | 15,852 | 9,023 | -6,829 (-43.08%) |
| Copper engine own logic plus table RAMs, FFs | 11,282 | 10,420 | -862 (-7.64%) |

The last two rows subtract the E2E, rate-math and ledger children in each run.
They **include** the new RAM children and their output registers,
so moving cells into a child hierarchy cannot itself create the saving.
The new LUT calculation is `16,792 - 4,156 - 1,812 - 1,801 = 9,023`.
The ledger remains at 1,801 LUTs / 1,853 FFs and rate math at 1,812 / 794;
E2E increases by 89 LUTs / 61 FFs, accounting for the difference between the
protocol-total reduction and the own-logic-plus-tables reduction.

| New copper child | LUTs | FFs | BRAM tiles | CARRY8 |
| --- | ---: | ---: | ---: | ---: |
| `U_PairRam` | 316 | 549 | 0 | 0 |
| `U_HistoryRam` | 280 | 483 | 0 | 0 |
| Combined | 596 | 1,032 | 0 | 0 |

Both engine generics default to distributed RAM. The shared inferred RAM
implementation registers `doutBInt`, one word wide: 549 pair bits and 485
history bits before pruning. The observed 549/483 FF counts are consistent
with those read registers and two pruned history bits; the screenshot alone
does not identify the pruned bits or supply an exact LUTRAM/logic split.
The parent also retains write/operand/control registers. This explains why
the declared table widths are not a prediction of net FF savings.

Whole-design BRAM remains 32 tiles and DSP use 101. The whole-design FF
increase is outside the shrinking protocol engine: even the complete copper
lane loses 188 FFs, so the rest of the design grows by 2,868. Within copper,
the wrapper outside `GigEthPtp` grows from 94 to 588 LUTs and 173 to 776 FFs.
Other hierarchy changes are therefore visible, but their causes and the SFP
breakdown require the full reports. Do not extrapolate the copper saving to
both lanes or attribute the complete design delta solely to the table work.

The remaining copper protocol own logic is 8,427 LUTs after also subtracting
the 596 LUTs in its new memories. Servo is now comparable: 9,975 LUTs total,
of which 1,963 belong to `U_Math`, leaving 8,012 own-logic LUTs. Its own logic
was 7,865 in the prior synthesis. The next candidate is shared servo arithmetic:
the nine compare/swaps and repeated clamp/rounding paths deserve attribution
before another storage change. This is an optimization recommendation, not a
measured breakdown of those functions. Timing/placement and hardware acceptance
remain outstanding.

## October 12 E2E, servo and PHC arithmetic audit

Reviewed source: SURF `191d733c1031e5b86643f67816f41adf958db130`.
This is a source review against the latest copper synthesis screenshot, with
the older text hierarchy used only where explicitly identified. No RTL changes,
new simulation or synthesis results accompany this audit. Proposed savings need
measurement; function calls do not map one-for-one to independent hardware,
and synthesis can already remove constant/sign-extension bits.

| Block | Latest inclusive LUTs | Arithmetic outside its math child |
| --- | ---: | --- |
| `PtpServo` | 9,975 | 8,012 LUTs after subtracting its 1,963-LUT `U_Math` |
| `PtpE2e` | 4,156 | 2,488 LUTs after subtracting its 1,668-LUT `U_Math`; all 18 DSPs are outside that child |
| `PtpPhc` | 3,212 | Latest screenshot does not expand the child; the prior text report divides the same total into 1,776 own LUTs and 1,436 for `U_Phase` |

These three blocks total 17,343 LUTs in the screenshot. Their source presents
more opportunities to share arithmetic than to substitute another RAM. The
servo delay history is only five words; PHC live state and command ownership
need concurrent access and distinct lifetimes.

### Recommended implementation order

The subsequent servo implementation below addresses rows 1 and 2. The
[E2E, PHC and common-math implementation](#october-12-e2e-phc-and-math-implementation)
addresses rows 3 through 7.

| Order | Candidate | Concrete change and main constraint |
| --- | --- | --- |
| 1 | Servo clamp/rounding and anti-windup | Select operands into one staged add/round/clamp datapath. Preserve rounding points, saturation decisions and command-ACK ownership. |
| 2 | Servo median | Execute the existing nine compare/swaps through one signed64 comparator and swap unit. Allow busy backpressure; preserve circular replacement and lower-median selection. |
| 3 | E2E timestamp arithmetic | Reuse one seconds-to-Q16 converter and one add/subtract datapath for the corrected timestamps and final results. Retain full epoch/correction precision. |
| 4 | E2E zero-calibration specialization | Bypass each zero-latency multiply/divide pair at elaboration. Both-zero builds can make the math instance multiply-only. Preserve invalid-input rejection. |
| 5 | PHC active increment | Tick with the already committed `status.increment`; calculate nominal-plus-rate only when accepting a new RATE command. Preserve old-increment use on the commit edge. |
| 6 | PHC constant phase divider | Exploit the fixed `1e9 * 2^16` divisor to reduce remainder/trial-subtract width. Retain the full signed128 software operand and quotient-fit rejection. |
| 7 | Shared `PtpMath` implementation | Evaluate one trial subtraction with borrow for division, replacing separate compare/subtract expressions. Keep the 128-iteration schedule and exact result/error behavior. |

Implement and measure the first two separately so comparator sharing and clamp
sharing have attributable results. The PHC increment change is a small,
independent candidate that can be evaluated without changing clock-command
latency. Its likely scope is much smaller than the servo work.

### Servo: arithmetic remains parallel inside the sequencer

[PtpServo](../../../ethernet/PtpCore/rtl/PtpServo.vhd) already shares multiply
and divide operations, but calls `clamp` at eight sites. In `PROPORTIONAL_S`,
rounding/clamping the slew, clamping the bootstrap-minus-slew frequency and
clamping the final rate form one combinational chain. `INTEGRAL_TIME_S` similarly
combines rounded integration, frequency saturation, the trial final-rate clamp,
anti-windup selection and a second final-rate clamp. These are the primary
targets for additional states and an explicitly shared arithmetic unit.

The helper accepts signed128 values and unsigned32 limits. Configuration
validation limits all three actuator maxima to 200,000 ppb, so their active
integer magnitudes need only 18 bits. Make that bound explicit in the datapath
after full-width configuration validation; keep software shadows and atomic
prepare/apply semantics intact. Already-clamped terms remain signed35, and
their sum/difference remains signed36. A full-width incoming value must still
be range-checked before narrowing into a clamp.

There is also a specific narrower intermediate to prove and expose: rounding
a checked signed128 integral product right by 62 gives magnitude at most
`2^65`. Negating it and adding a clamped frequency of magnitude below `2^34`
therefore fits **signed67**. This can narrow the integral update after the
existing rounding point; it does not permit narrowing the checked product or
moving the rounding before multiplication. The
[existing width audit](autonomous-endpoint.md#fixed-point-width-audit) still
governs the larger integral product and public phase/epoch operands.

`medianDelay` is a separate nine-comparator network. A sequencer can use the
same nine pairs over nine comparison cycles, sorting a scratch copy while
retaining the circular history. Keep all fractional bits, population/sentinel
handling, duplicate values and signed64 maximum. Account for operand-selection
muxes and scratch registers in the area comparison. RAM at depth five is a
secondary choice after changing access to one comparison at a time.

Serialization changes admission/publication timing. Cancellation, stale-sample
detection and holdover expiry must remain active during every new state, and
snapshots must observe coherent published results. The current median test
explicitly requires same-edge publication/no admission bubble; a serialized
implementation needs a documented timing change and matching busy/stall tests.

### E2E: share conversion and final accumulation

The final state of [PtpE2e](../../../ethernet/PtpCore/rtl/PtpE2e.vhd) forms both
delay and forward offset using three distinct absolute timestamps: remote
Sync, local Sync capture and remote Delay_Resp. The remote Sync conversion is
also spelled twice, although synthesis may already share that identical
expression. Each [time conversion](../../../ethernet/PtpCore/rtl/PtpPkg.vhd)
multiplies 48-bit seconds by one billion before combining nanoseconds/fraction.
The 18 DSPs outside `U_Math` are consistent with these conversions, but a cell
report is needed to attribute them exactly.

Reuse one converter over successive clocks and retain the corrected Sync time
for both equations. A shared wide add/subtract unit can then form the two
results instead of the current same-cycle subtraction chains. Subtracting
timestamp fields before conversion is another option, provided seconds are
widened before subtraction and the full epoch difference is preserved.
Retain both result fields until the existing output handshake; test cancellation
at each new stage and include the added latency in the association budget.

Both KCU105 lanes default ingress and egress latency to zero in the checked-out
target, with no override in its local ruckus manifest. The screenshot does not
prove the build's generic values. Even with zero constants, the present FSM
issues five 128-iteration operations: elapsed scaling plus two calibration
multiply/divide pairs. Explicit specialization can reduce a both-zero build to
elapsed scaling alone and remove its need for division. Each nonzero plane
still uses its own capture increment and original rounding. Keep rejection of
zero increments, zero ratio and generation mismatch even when a plane is zero.
This is a conditional area opportunity and a clear latency opportunity; the
five operations already share one math instance, so skipping four does not
imply an 80% area saving. The current E2E leaf uses nonzero calibration; add
both-zero and each-single-zero cases for this specialization.

### PHC and common math: target the bounded arithmetic first

[PtpPhc](../../../ethernet/PtpCore/rtl/PtpPhc.vhd) initializes `status.increment`
to nominal and updates it with accepted RATE commands. The ordinary tick
nevertheless recomputes nominal plus the retained rate. Using the pre-edge
registered increment can remove that redundant calculation. An accepted RATE
must still publish the new increment alongside commit-edge time, while that
edge itself advances with the old increment. Rejected commands, reset,
fault behavior and exact capture metadata remain part of the check.

The manual phase path uses a separate, divide-only `PtpMath` with a constant
46-bit divisor `D = 1e9 * 2^16`. In restoring division, the stored remainder is
below `D`, so the shifted trial value needs 47 bits; an additional borrow bit
can implement its comparison/subtraction. A dedicated constant-divisor path
can expose this bound without shortening the signed128 dividend/quotient or
changing the 128 iterations. Preserve truncation toward zero, signed remainder,
`MIN_SIGNED`, quotient-fit errors and accepted manual work across AXI reset.
Confirm what the existing constant propagation already removes before claiming
a saving. Avoid changing the every-clock rollover/phase/PPS path in the first
pass; it has stricter edge semantics than the manual preparation engine.

The general [PtpMath](../../../ethernet/PtpCore/rtl/PtpMath.vhd) division loop
currently compares a 129-bit trial remainder and then conditionally subtracts.
One widened subtraction can supply both the borrow decision and new remainder.
This is worth a controlled experiment across rate, E2E, servo and PHC instances;
the constants and live outputs differ, so do not extrapolate one leaf's saving.
The existing contract and math test require 128 work iterations. Sharing input
absolute-value, result-sign or final-rounding hardware across extra cycles is
a separate latency-contract change, not part of this first experiment.

### Existing SURF arithmetic helpers

[DspAddSub](../../../dsp/generic/fixed/DspAddSub.vhd) supports registered
add/subtract at widths up to 48 bits, covering the servo's signed36 rate
sum/difference. [DspComparator](../../../dsp/generic/fixed/DspComparator.vhd)
supports widths through 96 bits, covering the median operands and narrowed
integral clamp comparisons. Both expose ready/valid and `USE_DSP_G`, and the
existing generic DSP manifest already loads them. Compare inferred logic and
DSP implementations after sharing operations; the screenshot uses only 101
of 1,920 DSPs, so this is a practical resource trade to measure.

The comparator zero-extends its `slv` inputs and therefore orders them as
unsigned. That agrees with the admitted nonnegative median samples/sentinel;
signed clamp inputs require explicit signed-order handling, such as sign-bit
biasing. `DspAddSub` returns only the configured width, so widen rate operands
before addition and keep range checks around wider arithmetic. Neither helper
directly replaces the full signed128 checked engine. Their registered latency
and cancellation/flush integration need to be included in the sequencer design;
`USE_DSP_G` requests mapping but does not prove it occurred.

### Validation for a subsequent implementation

Choose the affected leaf and independent reference cases using the
[test-selection guide](../../../tests/ethernet/PtpCore/README.md#selecting-tests):
servo/median changes need PI, saturation, anti-windup, startup/replacement,
backpressure, cancellation and one affected endpoint case; E2E changes need
full epochs/corrections, calibration/increment combinations and protocol
consumer timing; PHC changes need the cycle-by-cycle clock oracle plus manual
phase and command-boundary cases. A common math change needs its arithmetic,
overflow, rounding, stalled-result/cancel checks and affected consumers.

For each independent patch, compare the same integrated synthesis configuration
and retain total/own LUTs, carry, FFs, DSPs and critical paths. Latest full
reports and timing are still missing. The current host is `PC100431`, not a
configured `rdsrv` tool host; Vivado/VCS are unavailable here. This audit changes
documentation only and requires link/whitespace checks rather than RTL runs.

## October 12 servo arithmetic and median implementation

Source baseline: SURF `191d733c1031e5b86643f67816f41adf958db130`. This follow-up
implements the first two arithmetic-audit candidates in `PtpServo`, with
fixture controls and focused checks in `PtpServoWrapper` and
`test_ptp_servo.py`. Production ports, the software register map, math-engine
operations and acknowledged-frequency ownership are unchanged.

The first change replaces eight clamp call sites with one selected-operand
clamp, sharing a signed67 adder for frequency and rate candidates. Limit
magnitudes use the validated 18-bit actuator range. Proportional/integral
rounding selects a fixed-shift quotient and round-up bit, then shares one
signed67 sign-restoration/increment stage. Overflow is still checked on the
full signed128 product before either shift. Conditional integration retains
separate frequency-saturation and trial-rate decisions before the final clamp.
The arithmetic-only revision passed the expanded PI/median leaf in 83.53 s
before introducing median sequencing.

The second change retains circular history and sorts a 320-bit scratch copy
using one signed64 comparator, visiting the same nine pairs over nine clocks.
Ready is low during sorting; median and population publish together on the
last comparison edge. Cancellation on that edge suppresses publication.
The [servo sequencing contract](autonomous-endpoint.md#servo-arithmetic-and-filter-sequencing)
owns latency, age handling, reset, cancellation and snapshot behavior.

The changes add a signed67 correction register, scratch history and sequencing
flags. Measure those registers and operand-selection muxes along with the
removed parallel arithmetic. No payload RAM or DSP helper is added in this pass; its
purpose is explicit local sharing before evaluating further mapping changes.
Existing ruckus directory imports already load both edited entities; there
are no added/moved HDL files or manifest changes.

The [servo verification record](rtl-review.md#october-12-servo-sharing-checks)
records the selected simulations and their limits: the final servo leaf and
GMII two-step closed-loop endpoint both pass (572.26 s with two workers).
Same-configuration Vivado
synthesis, placement and timing are still required to measure LUT/FF/carry
changes. The earlier screenshot is the area baseline, not evidence of this
patch's savings. For separate comparisons, temporary baseline, arithmetic-only
and final RTL/patch artifacts are retained under
`/private/tmp/ptp-servo-20261012/` in the development workspace.

## October 12 E2E, PHC and math implementation

Source baseline: SURF `26453ccedaa3968a7c6e08d3b56ffaa442f2ce1b`, which includes
the preceding Servo work. Three coordinated module changes implement the
remaining concrete arithmetic candidates:

- `PtpE2e` selects three timestamp operands into one seconds-to-Q16 converter
  and shares a signed128 add/subtract path for capture separation, calibration
  accumulation and final equations. Retained corrected Sync and delay
  intermediates replace parallel timestamp subtraction chains. Six final clocks
  preserve full epoch/correction precision, rounding and registered results.
  Each generic-zero calibration plane skips its multiply/divide pair; with both
  zero, the math instance's divide input is statically zero. Invalid ratio,
  increment and generation checks remain active for every generic combination.
- `PtpPhc` advances with its committed increment, calculating nominal plus rate
  only for a RATE command. The commit edge still advances with the old value.
  Its manual phase instance selects the new math divisor-width generic at 46
  bits, derived from the constant billion-nanosecond divisor and Q16 scale.
- `PtpMath` uses one widened trial subtraction and its borrow bit for restoring
  division. `DIVISOR_WIDTH_G` defaults to 128 and bounds only divisor magnitude
  and remainder arithmetic; zero or out-of-range divisors return an error
  instead of being truncated. Multiplication stays full width. PHC uses a
  46-bit remainder, 47-bit shifted trial and 48-bit subtraction, with the full
  signed128 dividend/quotient and unchanged 128 work iterations.

The [E2E sequencing](autonomous-endpoint.md#e2e-arithmetic-sequencing) and
[PHC/math contracts](autonomous-endpoint.md#phc-increment-and-phase-normalization)
own the lasting timing and numeric rules. Production ports and software fields
are unchanged; the E2E wrapper exposes additional provenance for tests. Existing
directory manifests load all edited HDL, with no added source files.

The [verification record](rtl-review.md#october-12-e2e-phc-and-math-checks)
records 14 passing leaf/register/consumer configurations, including the final
Servo, protocol and GMII endpoint batch (571.85 s with two workers). Measure E2E's additional state and
operand muxes along with the shared converter, and compare PHC own logic
separately from `U_Phase`. A generic structural netlist cannot establish mapped
LUT/carry/DSP savings or timing. Same-configuration Vivado synthesis and timing
remain outstanding for all three changes.

## Evidence and remaining acceptance

The [acceptance record](rtl-review.md#october-9-lut-optimization-checks) owns
executed checks and limits. The initial algorithm exploration checked all 120
permutations of five distinct values and 9,330 populated-count/boundary cases;
those Python-only results are separate from RTL verification.

Focused RTL coverage comprises the servo leaf, direct/GMII/XGMII RX oracle,
TX storage and real-MAC RX fixture, plus the selected TLV rules. The new tests
cover median population/order/duplicates/full range/circular replacement,
RX depths one through four, TX depths two/three, full capture fields,
simultaneous consume/enqueue, three-clock delivery, invalidation throughout the
FIFO pipeline, overflow, reset/flush, malformed keeps and large TLV lengths.
The MAC association fixture is historical model/counterexample
coverage; it is not production TX-observer coverage. Full endpoint settling,
all generic combinations and hardware qualification remain outside this run.

## Vivado comparison

Next step: synthesize this source and the baseline with the same FPGA part,
Vivado version, clock constraints, generics, strategy and flattening. Record
the source revision and local patch, and distinguish post-synthesis results
from post-implementation results. Compare the median, parser and queue changes
separately when attributing improvements, then check the integrated result.

Capture LUT-as-logic, LUT-as-memory, FF, carry, DSP and BRAM use plus critical
path/slack. Judge absolute resources and timing rather than minimizing LUT/FF
ratio: eliminating registers can increase that ratio while reducing area.
AMD documents hierarchical and cell-scoped reports and changes across flow
stages in [UG906 Report Utilization](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Report-Utilization)
(2026.1; accessed October 9, 2026). Keep reports outside maintained sources.

Measure the servo's own logic separately from `U_Math`, and RX separately from
TX observation. At the baseline, the complete record contains 809 logical bits;
four register entries plus a head declare 4,045 payload bits, or 2,427 for the
two-entry TX queue. These are source counts, not measured FF savings. Distributed
RAM consumes LUTs, and synthesis can remove unused fields or constant bits.

The GMII adapter drives only byte lane zero. `GigEthPtp` selects GMII at 125 MHz,
so integrated synthesis may already remove seven parser lanes and the wider
CRC alternatives. An unconstrained standalone frontend is not representative
of that configuration. XGMII must continue accepting eight bytes every cycle.

## Deferred follow-ups

These remain conditional on measured attribution rather than part of the
current RTL change:

- Measure the implemented local sharing/width changes against the
  [arithmetic audit](#october-12-e2e-servo-and-phc-arithmetic-audit) before
  selecting further resource changes.
- Consider sharing math between clients or a DSP-based multiplier after local
  datapath changes have been measured. Arbitration must preserve independent
  cancellation/ownership and account for losing per-instance constant pruning.
  Multiplication/division is already serialized; an attribute alone does not
  replace its shift/add algorithm with a new architecture.
- Compare CRC sharing if the full-width alternatives survive synthesis and
  consume significant LUTs. The existing `Crc32Parallel` uses the same general
  parallel-transform selection and is not an automatic area improvement.

Verification follows the [focused selection policy](../../../tests/ethernet/PtpCore/README.md#selecting-tests).
Successful simulation does not establish memory mapping, LUT savings or timing
closure; retain the baseline comparison as the outstanding acceptance item.
