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
implemented on October 12 below; neither has vendor area/timing evidence yet. The placed reference above attributes 15,954 LUTs
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

Working-tree implementation based on SURF
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

Next step: synthesize against the retained ledger-only baseline with the same
part, clocks, project state, strategy and flow stage. Compare protocol-engine
total and exclusive logic, both new RAM children, FFs, carry and critical paths.
Include write/read registers and E2E operand storage. Keep servo and parser
follow-ups separate so the table savings can be attributed.

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

- Serialize the median through one comparator if the fixed network is still
  too expensive. This changes backpressure and publication latency and needs
  busy/cancellation/snapshot checks plus an affected endpoint integration case.
- Share clamp/rounding datapaths or prove narrower intermediate widths if the
  servo's own arithmetic dominates. Preserve anti-windup decisions and exact
  overflow/rounding behavior; the [existing width audit](autonomous-endpoint.md#fixed-point-width-audit)
  already narrowed rate state and does not authorize globally narrowing epochs.
- Redesign `PtpMath` sharing or DSP use if its child utilization dominates.
  Multiplication/division is already serialized; an attribute alone does not
  replace its shift/add algorithm with a new architecture.
- Compare CRC sharing if the full-width alternatives survive synthesis and
  consume significant LUTs. The existing `Crc32Parallel` uses the same general
  parallel-transform selection and is not an automatic area improvement.

Verification follows the [focused selection policy](../../../tests/ethernet/PtpCore/README.md#selecting-tests).
Successful simulation does not establish memory mapping, LUT savings or timing
closure; retain the baseline comparison as the outstanding acceptance item.
